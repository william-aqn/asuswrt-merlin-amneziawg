#!/bin/sh
# Network-namespace lab: does `TCPMSS --clamp-mss-to-pmtu` clamp a SYN-ACK that comes back
# from a POLICY-ROUTED tunnel? (the addon's old `-i awg0` rule) — and does `--set-mss` fix it?
#
# Manual, root-only, Linux (not part of CI):   sudo sh tests/lab/mss-netns.sh
# Needs iproute2 (netns, veth), iptables with the TCPMSS/MARK targets and python3.
# Measured 2026-11 on kernel 6.6 (and read off the 4.1 source the routers run):
#   old rule: the client learns MSS 1448 (1460 minus timestamps) — NOT clamped; with the
#             router's "fragmentation needed" filtered on the client the upload delivers 0 bytes;
#   new rule: the client learns 1328 (1340 minus timestamps); uploads pass either way and the
#             router's FragFails counter stays put.
# (A stray FragFails +1 in the last run is the black-holed connection of the second run
# still retransmitting in the background.)
#
#   C (LAN client) --- R (router) ===tunnel, MTU 1380=== V (VPN server) --- S (Internet host)
#                        \_________________ WAN, MTU 1500 _________________/
#
# R marks C's traffic to S with fwmark 0x100 -> table 300 -> the tunnel, exactly like the
# addon; R's MAIN table default route is the WAN. V forwards without touching the MSS.
# Everything lives in throwaway namespaces that are deleted on exit.
set -u
HERE=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
for t in ip iptables python3; do
    command -v "$t" >/dev/null 2>&1 || { echo "MISSING TOOL: $t"; exit 2; }
done
P="al$$"
C="${P}c"; R="${P}r"; V="${P}v"; S="${P}s"
SRVPID=""
cleanup(){
    [ -n "$SRVPID" ] && kill "$SRVPID" 2>/dev/null
    for n in "$C" "$R" "$V" "$S"; do ip netns del "$n" 2>/dev/null; done
}
trap cleanup EXIT INT TERM
x(){ _ns=$1; shift; ip netns exec "$_ns" "$@"; }

for n in "$C" "$R" "$V" "$S"; do ip netns add "$n" || exit 3; ip -n "$n" link set lo up; done
ip link add c0 netns "$C" type veth peer name lan netns "$R"
ip link add wan netns "$R" type veth peer name sw netns "$S"
ip link add tun netns "$R" type veth peer name vt netns "$V"
ip link add vs netns "$V" type veth peer name sv netns "$S"

ip -n "$C" addr add 192.168.10.2/24 dev c0;  ip -n "$C" link set c0 up
ip -n "$C" route add default via 192.168.10.1

ip -n "$R" addr add 192.168.10.1/24 dev lan; ip -n "$R" link set lan up
ip -n "$R" addr add 10.0.0.1/24 dev wan;     ip -n "$R" link set wan up
ip -n "$R" addr add 10.29.80.2/24 dev tun;   ip -n "$R" link set tun mtu 1380 up
ip -n "$R" route add default via 10.0.0.2 dev wan
ip -n "$R" route add default via 10.29.80.1 dev tun table 300
ip -n "$R" rule add fwmark 0x100 lookup 300 prio 98
x "$R" sysctl -qw net.ipv4.ip_forward=1
for f in all default lan wan tun; do x "$R" sysctl -qw "net.ipv4.conf.$f.rp_filter=2"; done

ip -n "$V" addr add 10.29.80.1/24 dev vt;    ip -n "$V" link set vt mtu 1380 up
ip -n "$V" addr add 10.9.0.1/24 dev vs;      ip -n "$V" link set vs up
ip -n "$V" route add 203.0.113.10/32 via 10.9.0.2
x "$V" sysctl -qw net.ipv4.ip_forward=1

ip -n "$S" addr add 10.0.0.2/24 dev sw;      ip -n "$S" link set sw up
ip -n "$S" addr add 10.9.0.2/24 dev sv;      ip -n "$S" link set sv up
ip -n "$S" addr add 203.0.113.10/32 dev lo
ip -n "$S" route add 10.29.80.0/24 via 10.9.0.1
for f in all default sw sv; do x "$S" sysctl -qw "net.ipv4.conf.$f.rp_filter=0"; done

# The addon's rules on R: per-packet mark, MASQUERADE out of the tunnel, the MSS pair.
x "$R" iptables -t mangle -A PREROUTING -s 192.168.10.2 -d 203.0.113.10 -j MARK --set-mark 0x100
x "$R" iptables -t nat -A POSTROUTING -o tun -j MASQUERADE
x "$R" iptables -t nat -A POSTROUTING -o wan -j MASQUERADE
x "$R" iptables -t mangle -A FORWARD -o tun -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

x "$S" python3 "$HERE/mss-netns.py" server 203.0.113.10 8080 &
SRVPID=$!
sleep 1

fragfails(){ x "$R" awk '$1 == "Ip:" { if (!h) { for (i = 2; i <= NF; i++) n[i] = $i; h = 1; next } for (i = 2; i <= NF; i++) if (n[i] == "FragFails") print $i }' /proc/net/snmp; }
unreach(){ x "$R" awk '$1 == "Icmp:" { if (!h) { for (i = 2; i <= NF; i++) n[i] = $i; h = 1; next } for (i = 2; i <= NF; i++) if (n[i] == "OutDestUnreachs") print $i }' /proc/net/snmp; }

run(){   # $1 = label
    _f0=$(fragfails); _u0=$(unreach)
    echo "--- $1"
    x "$C" ip route flush cache 2>/dev/null
    x "$C" python3 "$HERE/mss-netns.py" client 203.0.113.10 8080 300000
    sleep 7
    echo "    router: FragFails +$(( $(fragfails) - _f0 )), ICMP dest-unreachable sent +$(( $(unreach) - _u0 ))"
}

echo "kernel $(uname -r); path check: $(x "$C" ping -c 1 -W 2 203.0.113.10 >/dev/null 2>&1 && echo 'C reaches S through the tunnel' || echo 'NO CONNECTIVITY')"
echo "tunnel link MTU 1380 -> a fitting MSS is 1340 (reported as 1328 by TCP_MAXSEG with timestamps on)"
echo

echo "===== OLD: -i tun ... --clamp-mss-to-pmtu ====="
x "$R" iptables -t mangle -A FORWARD -i tun -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
run "client honours ICMP (PMTUD works)"
x "$C" iptables -A INPUT -p icmp --icmp-type destination-unreachable -j DROP
run "client never sees the ICMP (host firewall / DPI tool in the path)"
x "$C" iptables -D INPUT -p icmp --icmp-type destination-unreachable -j DROP
x "$R" iptables -t mangle -D FORWARD -i tun -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

echo
echo "===== NEW: -i tun ... --set-mss 1340 ====="
x "$R" iptables -t mangle -A FORWARD -i tun -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1340
run "client honours ICMP"
x "$C" iptables -A INPUT -p icmp --icmp-type destination-unreachable -j DROP
run "client never sees the ICMP"
echo
echo "rules on R at the end:"; x "$R" iptables -t mangle -S FORWARD
