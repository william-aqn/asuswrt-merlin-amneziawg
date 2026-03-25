#!/bin/sh
# =============================================================
# AmneziaWG addon backend for ASUS GT-AX11000 (Merlin 388.x)
# Refactored: unified firewall, MAC-based routing, no duplicates
# =============================================================

ADDON_DIR="/jffs/addons/amneziawg"
AWG_DIR="/opt/amneziawg"
CONF="$AWG_DIR/awg0.conf"
AWG_GO="$AWG_DIR/amneziawg-go"
AWG_BIN="$AWG_DIR/awg"
IFACE="awg0"
AWG_PID="/var/run/amneziawg/${IFACE}.pid"
STATUS_FILE="/www/user/awg_status.htm"
SETTINGS="/jffs/addons/custom_settings.txt"
CLIENTS_FILE="$AWG_DIR/clients.list"
GEO_DIR="$AWG_DIR/geo"
IPSET_NAME="awg_dst"
FWMARK="0x100"
DNSMASQ_AWG_CONF="$AWG_DIR/dnsmasq_awg.conf"
DNSMASQ_INCLUDE="/jffs/configs/dnsmasq.conf.add"
SCRIPT_NAME="amneziawg"
RT_TABLE=300
AWG_CHAIN="AWG"
V2FLY_GEOIP_BASE="https://raw.githubusercontent.com/Loyalsoldier/geoip/release/text"

# --- Helpers ---

log_msg(){
    logger -t "$SCRIPT_NAME" "$1"
}

get_setting(){
    awk -v key="$1" '$1==key{sub(/^[^ ]+ /,"");print;exit}' "$SETTINGS" 2>/dev/null
}

is_running(){
    ip link show "$IFACE" >/dev/null 2>&1
}

get_lan_net(){
    ip -4 route show dev br0 2>/dev/null | awk '$1 ~ /^[0-9]/ && $1 ~ /\// {print $1; exit}'
}

disable_rp_filter(){
    for iface in all awg0 br0; do
        echo 0 > "/proc/sys/net/ipv4/conf/$iface/rp_filter" 2>/dev/null
    done
}

human_size(){
    local bytes=$1
    if [ "$bytes" -ge 1073741824 ] 2>/dev/null; then
        awk "BEGIN{printf \"%.1f GiB\", $bytes/1073741824}"
    elif [ "$bytes" -ge 1048576 ] 2>/dev/null; then
        awk "BEGIN{printf \"%.1f MiB\", $bytes/1048576}"
    elif [ "$bytes" -ge 1024 ] 2>/dev/null; then
        awk "BEGIN{printf \"%.1f KiB\", $bytes/1024}"
    else
        echo "${bytes} B"
    fi
}

# --- Unified firewall setup ---

cleanup_firewall(){
    # Unhook from PREROUTING, flush and delete custom chain
    iptables -t mangle -D PREROUTING -j "$AWG_CHAIN" 2>/dev/null
    iptables -t mangle -F "$AWG_CHAIN" 2>/dev/null
    iptables -t mangle -X "$AWG_CHAIN" 2>/dev/null

    # Remove all ip rules for our table/fwmark
    while ip rule del lookup $RT_TABLE 2>/dev/null; do :; done
    while ip rule del fwmark "$FWMARK" 2>/dev/null; do :; done

    # Remove DNS interception rules
    local router_ip
    router_ip=$(ip -4 addr show br0 2>/dev/null | awk '/inet /{sub(/\/.*/, "", $2); print $2; exit}')
    [ -z "$router_ip" ] && router_ip="192.168.1.1"
    iptables -t nat -D PREROUTING -i br0 -p udp --dport 53 -j DNAT --to "$router_ip" 2>/dev/null
    iptables -t nat -D PREROUTING -i br0 -p tcp --dport 53 -j DNAT --to "$router_ip" 2>/dev/null
    iptables -D FORWARD -i br0 -p tcp --dport 853 -j REJECT 2>/dev/null
    local doh_ip
    for doh_ip in 8.8.8.8 8.8.4.4 1.1.1.1 1.0.0.1 9.9.9.9 149.112.112.112; do
        iptables -D FORWARD -i br0 -d "$doh_ip" -p tcp --dport 443 -j REJECT 2>/dev/null
        iptables -D FORWARD -i br0 -d "$doh_ip" -p udp --dport 443 -j REJECT 2>/dev/null
    done

    # Destroy ipset
    ipset flush "$IPSET_NAME" 2>/dev/null
    ipset destroy "$IPSET_NAME" 2>/dev/null

    # Remove dnsmasq config
    rm -f "$DNSMASQ_AWG_CONF"
    [ -f "$DNSMASQ_INCLUDE" ] && sed -i "\|${DNSMASQ_AWG_CONF}|d" "$DNSMASQ_INCLUDE"

    # Remove cron
    cru d awg_geo_update 2>/dev/null

    log_msg "Firewall rules cleaned"
}

setup_firewall(){
    cleanup_firewall

    local default_policy=$(get_setting awg_default_policy)
    [ -z "$default_policy" ] && default_policy="direct"
    local has_geo=false

    # --- Create ipset (always, needed for geo rules) ---
    ipset create "$IPSET_NAME" hash:net family inet hashsize 4096 maxelem 131072 timeout 86400 2>/dev/null

    # --- Load GeoIP subnets into ipset ---
    local ip_count=0
    for f in "$GEO_DIR"/geoip/*.cidr; do
        [ ! -f "$f" ] && continue
        while read -r cidr; do
            cidr=$(echo "$cidr" | tr -d ' \r')
            [ -z "$cidr" ] && continue
            echo "$cidr" | grep -q '^#' && continue
            ipset add "$IPSET_NAME" "$cidr" timeout 0 2>/dev/null
            ip_count=$((ip_count + 1))
        done < "$f"
    done

    # --- Extract v2fly domains from downloaded database ---
    local geo_v2fly=$(get_setting awg_geo_v2fly)
    if [ -n "$geo_v2fly" ] && [ -f "$GEO_DIR/v2fly_all.yml" ]; then
        rm -f "$GEO_DIR/domains/v2fly_"*.txt
        for svc in $(echo "$geo_v2fly" | tr ',' ' '); do
            svc=$(echo "$svc" | tr -d ' ')
            [ -z "$svc" ] && continue
            awk -v cat="$svc" '
                /^  - name: / { name=$NF; found=(name==cat); next }
                found && /^      - "domain:/ { sub(/.*"domain:/,""); sub(/".*/,""); print }
                found && /^      - "full:/ { sub(/.*"full:/,""); sub(/".*/,""); print }
                found && /^  - name: / { if(found) exit }
            ' "$GEO_DIR/v2fly_all.yml" > "$GEO_DIR/domains/v2fly_${svc}.txt"
        done
    fi

    # --- Save custom domains/IPs ---
    local custom_domains=$(get_setting awg_geo_custom_domains)
    if [ -n "$custom_domains" ]; then
        mkdir -p "$GEO_DIR/domains"
        echo "$custom_domains" | tr ',' '\n' > "$GEO_DIR/domains/custom.txt"
    fi
    local custom_ips=$(get_setting awg_geo_custom_ips)
    if [ -n "$custom_ips" ]; then
        mkdir -p "$GEO_DIR/geoip"
        echo "$custom_ips" | tr ',' '\n' | while read -r cidr; do
            cidr=$(echo "$cidr" | tr -d ' \r')
            [ -n "$cidr" ] && ipset add "$IPSET_NAME" "$cidr" timeout 0 2>/dev/null
        done
    fi

    # --- Build dnsmasq config for domain-based routing ---
    local domain_count=0
    echo "# AmneziaWG domain routing - auto-generated" > "$DNSMASQ_AWG_CONF"
    for f in "$GEO_DIR"/domains/*.txt "$GEO_DIR"/domains/*.lst; do
        [ ! -f "$f" ] && continue
        local chunk_line="ipset=/"
        local chunk_count=0
        while read -r domain; do
            domain=$(echo "$domain" | tr -d ' \r')
            [ -z "$domain" ] && continue
            echo "$domain" | grep -q '^#' && continue
            domain=$(echo "$domain" | sed 's/^\.//;s/:@[^ ]*$//')
            echo "$domain" | grep -q '[^a-zA-Z0-9._-]' && continue
            chunk_line="${chunk_line}${domain}/"
            chunk_count=$((chunk_count + 1))
            domain_count=$((domain_count + 1))
            if [ $chunk_count -ge 20 ]; then
                echo "${chunk_line}${IPSET_NAME}" >> "$DNSMASQ_AWG_CONF"
                chunk_line="ipset=/"
                chunk_count=0
            fi
        done < "$f"
        [ $chunk_count -gt 0 ] && echo "${chunk_line}${IPSET_NAME}" >> "$DNSMASQ_AWG_CONF"
    done

    # Add conf-file include to dnsmasq (idempotent)
    if [ $domain_count -gt 0 ]; then
        if ! grep -qF "conf-file=$DNSMASQ_AWG_CONF" "$DNSMASQ_INCLUDE" 2>/dev/null; then
            echo "conf-file=$DNSMASQ_AWG_CONF" >> "$DNSMASQ_INCLUDE"
        fi
    fi

    # --- Create custom chain in mangle table ---
    iptables -t mangle -N "$AWG_CHAIN" 2>/dev/null || iptables -t mangle -F "$AWG_CHAIN"

    # --- Exclusion rules (evaluated first — protect system traffic) ---
    local lan_net
    lan_net=$(get_lan_net)
    local endpoint
    endpoint=$(grep "^Endpoint" "$CONF" 2>/dev/null | cut -d= -f2 | tr -d ' ' | cut -d: -f1)

    iptables -t mangle -A "$AWG_CHAIN" -m addrtype --dst-type LOCAL -j RETURN
    [ -n "$lan_net" ] && iptables -t mangle -A "$AWG_CHAIN" -d "$lan_net" -j RETURN
    iptables -t mangle -A "$AWG_CHAIN" -p udp -m multiport --dports 67,68,123 -j RETURN
    iptables -t mangle -A "$AWG_CHAIN" -d 224.0.0.0/4 -j RETURN
    [ -n "$endpoint" ] && iptables -t mangle -A "$AWG_CHAIN" -d "$endpoint" -j RETURN

    # --- Per-device rules (two passes for correct ordering) ---
    save_clients
    if [ -f "$CLIENTS_FILE" ] && [ -s "$CLIENTS_FILE" ]; then

        # Pass 1: "direct" exclusions (RETURN rules must come before MARK rules)
        while IFS=',' read -r dev_id name policy mac || [ -n "$dev_id" ]; do
            dev_id=$(echo "$dev_id" | tr -d ' ')
            policy=$(echo "$policy" | tr -d ' ')
            mac=$(echo "$mac" | tr -d ' ')
            [ -z "$dev_id" ] && continue
            [ "$policy" != "direct" ] && continue

            if [ "$default_policy" != "direct" ]; then
                if [ -n "$mac" ]; then
                    iptables -t mangle -A "$AWG_CHAIN" -m mac --mac-source "$mac" -j RETURN
                else
                    ip rule add from "$dev_id" lookup main prio 99
                fi
                log_msg "Route: $dev_id ($name) -> Direct (excluded)"
            else
                log_msg "Route: $dev_id ($name) -> Direct"
            fi
        done < "$CLIENTS_FILE"

        # Pass 2: vpn_all and vpn_geo rules
        while IFS=',' read -r dev_id name policy mac || [ -n "$dev_id" ]; do
            dev_id=$(echo "$dev_id" | tr -d ' ')
            policy=$(echo "$policy" | tr -d ' ')
            mac=$(echo "$mac" | tr -d ' ')
            [ -z "$dev_id" ] && continue

            case "$policy" in
                vpn_all)
                    if [ -n "$mac" ]; then
                        iptables -t mangle -A "$AWG_CHAIN" -m mac --mac-source "$mac" -j MARK --set-mark "$FWMARK"
                    else
                        ip rule add from "$dev_id" lookup $RT_TABLE prio 100
                    fi
                    log_msg "Route: $dev_id ($name) -> VPN (all)"
                    ;;
                vpn_geo)
                    if [ -n "$mac" ]; then
                        iptables -t mangle -A "$AWG_CHAIN" -m mac --mac-source "$mac" \
                            -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark "$FWMARK"
                    else
                        iptables -t mangle -A "$AWG_CHAIN" -s "$dev_id" \
                            -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark "$FWMARK"
                    fi
                    has_geo=true
                    log_msg "Route: $dev_id ($name) -> VPN (geo)"
                    ;;
            esac
        done < "$CLIENTS_FILE"
    fi

    # --- Default policy (last rules in chain) ---
    case "$default_policy" in
        vpn_all)
            iptables -t mangle -A "$AWG_CHAIN" -j MARK --set-mark "$FWMARK"
            log_msg "Default: all -> VPN"
            ;;
        vpn_geo)
            iptables -t mangle -A "$AWG_CHAIN" \
                -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark "$FWMARK"
            has_geo=true
            log_msg "Default: geo -> VPN"
            ;;
        direct|*)
            log_msg "Default: direct"
            ;;
    esac

    # --- Hook chain into PREROUTING ---
    iptables -t mangle -C PREROUTING -j "$AWG_CHAIN" 2>/dev/null || \
        iptables -t mangle -A PREROUTING -j "$AWG_CHAIN"

    # --- Single fwmark rule for all marked traffic ---
    ip rule add fwmark "$FWMARK" lookup $RT_TABLE prio 98

    # --- Force DNS through dnsmasq (defeat DoH/DoT on devices) ---
    if [ "$has_geo" = true ]; then
        local router_ip
        router_ip=$(ip -4 addr show br0 2>/dev/null | awk '/inet /{sub(/\/.*/, "", $2); print $2; exit}')
        [ -z "$router_ip" ] && router_ip="192.168.1.1"
        # Redirect all DNS to router
        iptables -t nat -I PREROUTING -i br0 -p udp --dport 53 -j DNAT --to "$router_ip"
        iptables -t nat -I PREROUTING -i br0 -p tcp --dport 53 -j DNAT --to "$router_ip"
        # Block DNS-over-TLS
        iptables -I FORWARD -i br0 -p tcp --dport 853 -j REJECT
        # Block DNS-over-HTTPS to known providers
        local doh_ip
        for doh_ip in 8.8.8.8 8.8.4.4 1.1.1.1 1.0.0.1 9.9.9.9 149.112.112.112; do
            iptables -I FORWARD -i br0 -d "$doh_ip" -p tcp --dport 443 -j REJECT
            iptables -I FORWARD -i br0 -d "$doh_ip" -p udp --dport 443 -j REJECT
        done
        log_msg "DNS interception enabled"
    fi

    # --- Restart dnsmasq if geo active ---
    if [ $domain_count -gt 0 ] || [ "$has_geo" = true ]; then
        service restart_dnsmasq >/dev/null 2>&1
        sleep 5
        # Pre-resolve all configured domains to populate ipset immediately
        if [ -f "$DNSMASQ_AWG_CONF" ]; then
            awk -F/ '/^ipset=/{for(i=2;i<NF;i++)print $i}' "$DNSMASQ_AWG_CONF" | while read -r domain; do
                [ -n "$domain" ] && nslookup "$domain" 127.0.0.1 >/dev/null 2>&1
            done
        fi
    fi

    # --- Setup auto-update cron ---
    if [ "$(get_setting awg_geo_autoupdate)" = "1" ]; then
        cru a awg_geo_update "0 4 * * * $ADDON_DIR/amneziawg.sh update_geo"
    fi

    log_msg "Firewall configured: $ip_count IPs, $domain_count domains"
}

save_clients(){
    local clients=$(get_setting awg_clients)
    if [ -n "$clients" ]; then
        echo "$clients" | tr ';' '\n' > "$CLIENTS_FILE"
    else
        > "$CLIENTS_FILE"
    fi
}

# --- Download only missing geo lists (on Apply) ---

update_geo_if_needed(){
    mkdir -p "$GEO_DIR/geoip" "$GEO_DIR/domains"
    local needed=false

    # Check GeoIP service lists
    local geo_v2fly_ip=$(get_setting awg_geo_v2fly_ip)
    if [ -n "$geo_v2fly_ip" ]; then
        for svc in $(echo "$geo_v2fly_ip" | tr ',' ' '); do
            svc=$(echo "$svc" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
            [ -z "$svc" ] && continue
            if [ ! -f "$GEO_DIR/geoip/v2fly_${svc}.cidr" ] || [ ! -s "$GEO_DIR/geoip/v2fly_${svc}.cidr" ]; then
                log_msg "Downloading missing GeoIP: $svc"
                curl -sfL "${V2FLY_GEOIP_BASE}/${svc}.txt" -o "$GEO_DIR/geoip/v2fly_${svc}.cidr" 2>/dev/null
                [ -f "$GEO_DIR/geoip/v2fly_${svc}.cidr" ] && grep -v ":" "$GEO_DIR/geoip/v2fly_${svc}.cidr" > "$GEO_DIR/geoip/v2fly_${svc}.tmp" && mv "$GEO_DIR/geoip/v2fly_${svc}.tmp" "$GEO_DIR/geoip/v2fly_${svc}.cidr"
                needed=true
            fi
        done
    fi

    # Check v2fly domain database
    local geo_v2fly=$(get_setting awg_geo_v2fly)
    if [ -n "$geo_v2fly" ] && [ ! -f "$GEO_DIR/v2fly_all.yml" ]; then
        log_msg "Downloading missing v2fly domain database..."
        curl -sfL "https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat_plain.yml" \
            -o "$GEO_DIR/v2fly_all.yml" 2>/dev/null
        if [ -f "$GEO_DIR/v2fly_all.yml" ] && [ -s "$GEO_DIR/v2fly_all.yml" ]; then
            grep '  - name: ' "$GEO_DIR/v2fly_all.yml" | sed 's/.*- name: //' | sort > "$GEO_DIR/v2fly_categories.txt"
            cp "$GEO_DIR/v2fly_categories.txt" /www/user/v2fly_categories.htm 2>/dev/null
        fi
        needed=true
    fi

    [ "$needed" = true ] && log_msg "Missing geo lists downloaded"
}

# --- Download all geo lists (Update Now — force refresh) ---

update_geo_lists(){
    mkdir -p "$GEO_DIR/geoip" "$GEO_DIR/domains"

    log_msg "Updating geo lists..."

    # GeoIP service lists from Loyalsoldier/geoip (Telegram, Google, etc.)
    local geo_v2fly_ip=$(get_setting awg_geo_v2fly_ip)
    if [ -n "$geo_v2fly_ip" ]; then
        for svc in $(echo "$geo_v2fly_ip" | tr ',' ' '); do
            svc=$(echo "$svc" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
            [ -z "$svc" ] && continue
            log_msg "Downloading GeoIP: $svc"
            curl -sfL "${V2FLY_GEOIP_BASE}/${svc}.txt" -o "$GEO_DIR/geoip/v2fly_${svc}.cidr" 2>/dev/null
            # Keep only IPv4
            if [ -f "$GEO_DIR/geoip/v2fly_${svc}.cidr" ]; then
                grep -v ":" "$GEO_DIR/geoip/v2fly_${svc}.cidr" > "$GEO_DIR/geoip/v2fly_${svc}.tmp"
                mv "$GEO_DIR/geoip/v2fly_${svc}.tmp" "$GEO_DIR/geoip/v2fly_${svc}.cidr"
            fi
        done
    fi

    # v2fly domain database (3MB, all domains)
    log_msg "Downloading v2fly domain database..."
    curl -sfL "https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat_plain.yml" \
        -o "$GEO_DIR/v2fly_all.yml" 2>/dev/null
    if [ -f "$GEO_DIR/v2fly_all.yml" ] && [ -s "$GEO_DIR/v2fly_all.yml" ]; then
        grep '  - name: ' "$GEO_DIR/v2fly_all.yml" | sed 's/.*- name: //' | sort > "$GEO_DIR/v2fly_categories.txt"
        cp "$GEO_DIR/v2fly_categories.txt" /www/user/v2fly_categories.htm 2>/dev/null
        log_msg "v2fly domains: $(wc -l < "$GEO_DIR/v2fly_categories.txt") categories"
    else
        log_msg "WARNING: v2fly domain download failed"
    fi

    log_msg "Geo lists updated"
}

# --- Generate awg0.conf ---

generate_config(){
    mkdir -p "$AWG_DIR"

    local privkey=$(get_setting awg_privatekey)
    local listenport=$(get_setting awg_listenport)
    local jc=$(get_setting awg_jc)
    local jmin=$(get_setting awg_jmin)
    local jmax=$(get_setting awg_jmax)
    local s1=$(get_setting awg_s1)
    local s2=$(get_setting awg_s2)
    local s3=$(get_setting awg_s3)
    local s4=$(get_setting awg_s4)
    local h1=$(get_setting awg_h1)
    local h2=$(get_setting awg_h2)
    local h3=$(get_setting awg_h3)
    local h4=$(get_setting awg_h4)

    # I1-I5 from base64-encoded setting (contains HTML-unsafe chars)
    local i1="" i2="" i3="" i4="" i5=""
    local initdata=$(get_setting awg_initdata)
    if [ -n "$initdata" ]; then
        local decoded
        decoded=$(echo "$initdata" | base64 -d 2>/dev/null)
        i1=$(echo "$decoded" | awk '/^I1 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
        i2=$(echo "$decoded" | awk '/^I2 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
        i3=$(echo "$decoded" | awk '/^I3 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
        i4=$(echo "$decoded" | awk '/^I4 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
        i5=$(echo "$decoded" | awk '/^I5 /{sub(/^[^=]+=[ ]?/,"");print;exit}')
    fi

    local peer_pubkey=$(get_setting awg_peer_pubkey)
    local peer_psk=$(get_setting awg_peer_psk)
    local peer_endpoint=$(get_setting awg_peer_endpoint)
    local peer_allowedips=$(get_setting awg_peer_allowedips | sed 's/,[[:space:]]*$//;s/,/, /g')
    local peer_keepalive=$(get_setting awg_peer_keepalive)

    if [ -z "$privkey" ] || [ -z "$peer_pubkey" ] || [ -z "$peer_endpoint" ]; then
        log_msg "ERROR: Missing required config"
        return 1
    fi

    {
        echo "[Interface]"
        echo "PrivateKey = $privkey"
        [ -n "$listenport" ] && echo "ListenPort = $listenport"
        [ -n "$jc" ] && echo "Jc = $jc"
        [ -n "$jmin" ] && echo "Jmin = $jmin"
        [ -n "$jmax" ] && echo "Jmax = $jmax"
        [ -n "$s1" ] && echo "S1 = $s1"
        [ -n "$s2" ] && echo "S2 = $s2"
        [ -n "$s3" ] && echo "S3 = $s3"
        [ -n "$s4" ] && echo "S4 = $s4"
        [ -n "$h1" ] && echo "H1 = $h1"
        [ -n "$h2" ] && echo "H2 = $h2"
        [ -n "$h3" ] && echo "H3 = $h3"
        [ -n "$h4" ] && echo "H4 = $h4"
        [ -n "$i1" ] && echo "I1 = $i1"
        [ -n "$i2" ] && echo "I2 = $i2"
        [ -n "$i3" ] && echo "I3 = $i3"
        [ -n "$i4" ] && echo "I4 = $i4"
        [ -n "$i5" ] && echo "I5 = $i5"
        echo ""
        echo "[Peer]"
        echo "PublicKey = $peer_pubkey"
        [ -n "$peer_psk" ] && echo "PresharedKey = $peer_psk"
        [ -n "$peer_endpoint" ] && echo "Endpoint = $peer_endpoint"
        echo "AllowedIPs = ${peer_allowedips:-0.0.0.0/0}"
        [ -n "$peer_keepalive" ] && echo "PersistentKeepalive = $peer_keepalive"
    } > "$CONF"

    chmod 600 "$CONF"

    # Save address and DNS separately
    local address=$(get_setting awg_address)
    [ -n "$address" ] && echo "$address" > "$AWG_DIR/awg0.addr"
    local dns=$(get_setting awg_dns)
    [ -n "$dns" ] && echo "$dns" > "$AWG_DIR/awg0.dns"

    log_msg "Config saved"
    return 0
}

# --- Start ---

do_start(){
    if is_running; then
        log_msg "Already running"
        update_status
        return 0
    fi

    # Generate config
    generate_config || { update_status; return 1; }
    [ ! -f "$CONF" ] && { log_msg "ERROR: No config"; update_status; return 1; }
    [ ! -f "$AWG_GO" ] && { log_msg "ERROR: amneziawg-go not found"; update_status; return 1; }

    # Ensure TUN device exists
    mkdir -p /dev/net
    [ ! -c /dev/net/tun ] && mknod /dev/net/tun c 10 200
    chmod 600 /dev/net/tun

    # Start userspace daemon (creates TUN interface)
    mkdir -p /var/run/amneziawg
    "$AWG_GO" "$IFACE" >/dev/null 2>&1
    sleep 1
    if ! ip link show "$IFACE" >/dev/null 2>&1; then
        log_msg "ERROR: amneziawg-go failed to create interface"
        update_status; return 1
    fi
    log_msg "Userspace daemon started"

    # Configure interface
    "$AWG_BIN" setconf "$IFACE" "$CONF" || { log_msg "ERROR: setconf failed"; ip link del "$IFACE" 2>/dev/null; update_status; return 1; }

    [ -f "$AWG_DIR/awg0.addr" ] && ip addr add "$(cat "$AWG_DIR/awg0.addr")" dev "$IFACE"
    ip link set "$IFACE" mtu 1280
    ip link set "$IFACE" up

    # DNS: ensure queries go through dnsmasq for ipset population
    if ! grep -q "^nameserver 127.0.0.1" /tmp/resolv.conf 2>/dev/null; then
        local old_dns=$(cat /tmp/resolv.conf 2>/dev/null)
        echo "nameserver 127.0.0.1" > /tmp/resolv.conf
        echo "$old_dns" >> /tmp/resolv.conf
    fi

    # Routing table: split routes + LAN return + endpoint exclusion
    local gw=$(ip route | grep "^default" | awk '{print $3}' | head -1)
    local endpoint=$(grep "^Endpoint" "$CONF" | cut -d= -f2 | tr -d ' ' | cut -d: -f1)
    [ -n "$endpoint" ] && [ -n "$gw" ] && ip route add "$endpoint" via "$gw" 2>/dev/null
    ip route add 0.0.0.0/1 dev "$IFACE" table $RT_TABLE 2>/dev/null
    ip route add 128.0.0.0/1 dev "$IFACE" table $RT_TABLE 2>/dev/null
    local lan_net
    lan_net=$(get_lan_net)
    [ -n "$lan_net" ] && ip route add "$lan_net" dev br0 table $RT_TABLE 2>/dev/null

    # Disable rp_filter for VPN interfaces
    disable_rp_filter

    # Base iptables
    iptables -I INPUT -i "$IFACE" -j ACCEPT
    iptables -I FORWARD -i "$IFACE" -j ACCEPT
    iptables -I FORWARD -o "$IFACE" -j ACCEPT
    # MSS clamping — prevent TCP breakage due to tunnel MTU overhead
    iptables -t mangle -A FORWARD -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    iptables -t mangle -A FORWARD -i "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    local masq_src
    masq_src=$(get_lan_net)
    if [ -n "$masq_src" ]; then
        iptables -t nat -I POSTROUTING -s "$masq_src" -o "$IFACE" -j MASQUERADE
    else
        iptables -t nat -I POSTROUTING -o "$IFACE" -j MASQUERADE
    fi

    # Setup all routing/firewall rules
    setup_firewall

    # Route for router-originated traffic through tunnel (after setup_firewall which cleans ip rules)
    local awg_addr
    awg_addr=$(ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet /{sub(/\/.*/, "", $2); print $2; exit}')
    [ -n "$awg_addr" ] && ip rule add from "$awg_addr" lookup $RT_TABLE prio 100

    log_msg "Started"
    update_status
}

# --- Stop ---

do_stop(){
    # Remove iptables base rules
    iptables -D INPUT -i "$IFACE" -j ACCEPT 2>/dev/null
    iptables -D FORWARD -i "$IFACE" -j ACCEPT 2>/dev/null
    iptables -D FORWARD -o "$IFACE" -j ACCEPT 2>/dev/null
    # Remove MSS clamping
    iptables -t mangle -D FORWARD -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null
    iptables -t mangle -D FORWARD -i "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null
    # Remove MASQUERADE (both restricted and unrestricted variants)
    local lan_net
    lan_net=$(get_lan_net)
    [ -n "$lan_net" ] && iptables -t nat -D POSTROUTING -s "$lan_net" -o "$IFACE" -j MASQUERADE 2>/dev/null
    iptables -t nat -D POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null

    # Cleanup firewall (flushes AWG chain atomically)
    cleanup_firewall

    # Remove routes
    ip route flush table $RT_TABLE 2>/dev/null
    local endpoint=$(grep "^Endpoint" "$CONF" 2>/dev/null | cut -d= -f2 | tr -d ' ' | cut -d: -f1)
    [ -n "$endpoint" ] && ip route del "$endpoint" 2>/dev/null

    # Remove interface and stop daemon
    ip link set "$IFACE" down 2>/dev/null
    ip link del "$IFACE" 2>/dev/null
    # Kill userspace daemon if running
    local awg_pid
    awg_pid=$(pidof amneziawg-go 2>/dev/null)
    [ -n "$awg_pid" ] && kill "$awg_pid" 2>/dev/null
    rm -f /var/run/amneziawg/"$IFACE".sock

    # Restart dnsmasq to clean up
    service restart_dnsmasq >/dev/null 2>&1

    log_msg "Stopped"
    update_status
}

# --- Status JSON for web UI ---

update_status(){
    local running=false
    local pub_key=""
    local listen_port=""
    local iface_addr=""
    local peers_json="[]"
    local log_text=""

    if is_running; then
        running=true
        iface_addr=$(ip -4 addr show "$IFACE" 2>/dev/null | grep inet | awk '{print $2}')
        listen_port=$("$AWG_BIN" show "$IFACE" listen-port 2>/dev/null)
        pub_key=$("$AWG_BIN" show "$IFACE" public-key 2>/dev/null)

        # Parse peers (avoid subshell variable loss)
        local dump=$("$AWG_BIN" show "$IFACE" dump 2>/dev/null | tail -n +2)
        if [ -n "$dump" ]; then
            local p_items=""
            while IFS='	' read -r pkey psk endpoint aips handshake rx tx keepalive; do
                local hs_text="never"
                if [ "$handshake" != "0" ] && [ -n "$handshake" ]; then
                    local ago=$(( $(date +%s) - handshake ))
                    if [ $ago -lt 60 ]; then hs_text="${ago}s ago"
                    elif [ $ago -lt 3600 ]; then hs_text="$(( ago / 60 ))m ago"
                    else hs_text="$(( ago / 3600 ))h ago"; fi
                fi
                local rx_h=$(human_size "${rx:-0}")
                local tx_h=$(human_size "${tx:-0}")
                local item="{\"endpoint\":\"${endpoint}\",\"allowed_ips\":\"${aips}\",\"transfer_rx\":\"${rx_h}\",\"transfer_tx\":\"${tx_h}\",\"latest_handshake\":\"${hs_text}\"}"
                [ -n "$p_items" ] && p_items="${p_items},${item}" || p_items="$item"
            done <<EOF
$dump
EOF
            peers_json="[${p_items}]"
        fi
    fi

    # Log
    log_text=$(dmesg 2>/dev/null | grep -i "amneziawg\|awg" | tail -10 | sed 's/"/\\"/g' | tr '\n' '|' | sed 's/|/\\n/g')

    # Settings
    local default_policy=$(get_setting awg_default_policy)
    [ -z "$default_policy" ] && default_policy="direct"
    local clients_data=$(get_setting awg_clients | sed 's/"/\\"/g')
    local active_rules=$(ip rule show 2>/dev/null | grep "lookup $RT_TABLE\|fwmark $FWMARK" | wc -l)

    local ipset_count=0
    ipset list "$IPSET_NAME" -t 2>/dev/null | grep -q "Number of entries" && \
        ipset_count=$(ipset list "$IPSET_NAME" -t 2>/dev/null | grep "Number of entries" | awk '{print $NF}')

    local geo_domains=0
    [ -f "$DNSMASQ_AWG_CONF" ] && geo_domains=$(grep -c "^ipset=" "$DNSMASQ_AWG_CONF" 2>/dev/null)
    [ -z "$geo_domains" ] && geo_domains=0

    cat > "$STATUS_FILE" << STATUSEOF
{"running":${running},"public_key":"${pub_key}","listen_port":"${listen_port}","interface_addr":"${iface_addr}","peers":${peers_json},"default_policy":"${default_policy}","clients":"${clients_data}","active_rules":${active_rules},"ipset_count":${ipset_count},"geo_domains":${geo_domains},"log":"${log_text}"}
STATUSEOF
}

# --- Install/Mount/Uninstall ---

do_install_page(){
    source /usr/sbin/helper.sh
    nvram get rc_support | grep -q am_addons || { log_msg "ERROR: Addons not supported"; return 1; }

    mkdir -p "$ADDON_DIR"
    cp "$0" "$ADDON_DIR/amneziawg.sh"
    chmod +x "$ADDON_DIR/amneziawg.sh"

    [ -f "/tmp/amneziawg_page.asp" ] && cp /tmp/amneziawg_page.asp "$ADDON_DIR/amneziawg_page.asp"

    am_get_webui_page "$ADDON_DIR/amneziawg_page.asp"
    [ "$am_webui_page" = "none" ] && { log_msg "ERROR: No page slot"; return 1; }

    cp "$ADDON_DIR/amneziawg_page.asp" "/www/user/$am_webui_page"

    [ ! -f /tmp/menuTree.js ] && cp /www/require/modules/menuTree.js /tmp/
    sed -i '/AmneziaWG/d' /tmp/menuTree.js
    sed -i "/url: \"Advanced_VPN_OpenVPN.asp\"/a {url: \"$am_webui_page\", tabName: \"AmneziaWG\"}," /tmp/menuTree.js
    umount /www/require/modules/menuTree.js 2>/dev/null
    mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js

    echo '{"running":false,"peers":[],"log":"Installed."}' > "$STATUS_FILE"

    # service-event handler
    [ ! -f /jffs/scripts/service-event ] && echo "#!/bin/sh" > /jffs/scripts/service-event && chmod +x /jffs/scripts/service-event
    if ! grep -q "amneziawg" /jffs/scripts/service-event; then
        echo 'echo "$2" | grep -q "^awg" && /jffs/addons/amneziawg/amneziawg.sh "service_event" "$1" "$2"' >> /jffs/scripts/service-event
    fi

    # Boot mount
    [ ! -f /jffs/scripts/services-start ] && echo "#!/bin/sh" > /jffs/scripts/services-start && chmod +x /jffs/scripts/services-start
    grep -q "amneziawg" /jffs/scripts/services-start || echo "/jffs/addons/amneziawg/amneziawg.sh mount_ui &" >> /jffs/scripts/services-start

    # Restore v2fly categories if available
    [ -f "$GEO_DIR/v2fly_categories.txt" ] && cp "$GEO_DIR/v2fly_categories.txt" /www/user/v2fly_categories.htm 2>/dev/null

    log_msg "Page installed: $am_webui_page"
    echo "Installed. Access: VPN > AmneziaWG"
}

do_mount_ui(){
    source /usr/sbin/helper.sh
    am_get_webui_page "$ADDON_DIR/amneziawg_page.asp"
    if [ "$am_webui_page" != "none" ]; then
        cp "$ADDON_DIR/amneziawg_page.asp" "/www/user/$am_webui_page"
        [ ! -f /tmp/menuTree.js ] && cp /www/require/modules/menuTree.js /tmp/
        sed -i '/AmneziaWG/d' /tmp/menuTree.js
        sed -i "/url: \"Advanced_VPN_OpenVPN.asp\"/a {url: \"$am_webui_page\", tabName: \"AmneziaWG\"}," /tmp/menuTree.js
        umount /www/require/modules/menuTree.js 2>/dev/null
        mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
    fi

    # Restore v2fly categories
    [ -f "$GEO_DIR/v2fly_categories.txt" ] && cp "$GEO_DIR/v2fly_categories.txt" /www/user/v2fly_categories.htm 2>/dev/null

    update_status

    # Auto-start
    if [ "$(get_setting awg_autostart)" = "1" ]; then
        sleep 10
        do_start
    fi
}

do_uninstall(){
    do_stop

    [ -f /jffs/scripts/service-event ] && sed -i '/amneziawg/d' /jffs/scripts/service-event
    [ -f /jffs/scripts/services-start ] && sed -i '/amneziawg/d' /jffs/scripts/services-start

    local page=$(ls /www/user/ 2>/dev/null | while read f; do grep -l "AmneziaWG" "/www/user/$f" 2>/dev/null; done | head -1)
    [ -n "$page" ] && rm -f "$page"
    rm -f "$STATUS_FILE" /www/user/v2fly_categories.htm

    rm -rf "$ADDON_DIR"

    if [ -f /tmp/menuTree.js ]; then
        sed -i '/AmneziaWG/d' /tmp/menuTree.js
        umount /www/require/modules/menuTree.js 2>/dev/null
        mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
    fi

    log_msg "Uninstalled"
}

# --- Service event dispatcher ---

do_service_event(){
    local event="$2"
    case "$event" in
        awgstart)       do_start ;;
        awgstop)        do_stop ;;
        awgrestart)     do_stop; sleep 5; do_start ;;
        awgsaveconf)
            generate_config
            update_geo_if_needed
            is_running && setup_firewall
            update_status
            ;;
        awgupdategeo)
            update_geo_lists
            is_running && setup_firewall
            update_status
            ;;
    esac
}

# --- Main ---

case "$1" in
    start)          do_start ;;
    stop)           do_stop ;;
    restart)        do_stop; sleep 5; do_start ;;
    status)         update_status ;;
    update_geo)     update_geo_lists; is_running && setup_firewall; update_status ;;
    install_page)   do_install_page ;;
    mount_ui)       do_mount_ui ;;
    uninstall)      do_uninstall ;;
    service_event)  do_service_event "$2" "$3" ;;
    *)              echo "Usage: $0 {start|stop|restart|status|update_geo|install_page|uninstall}" ;;
esac
