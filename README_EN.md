# AmneziaWG for Asuswrt-Merlin

[[русский]](README.md) [[english]](README_EN.md)

💬 Discussion & help — [community Telegram chat](https://t.me/asusxray/26094)

DPI-obfuscated WireGuard VPN client with web UI for ASUS routers running [Asuswrt-Merlin](https://www.asuswrt-merlin.net/) firmware. Provides per-device policy routing and GeoIP/GeoSite selective routing using [AmneziaWG](https://github.com/amnezia-vpn/amneziawg-go) protocol.

Fully userspace implementation -- no kernel module required, works on any kernel version.

> **About:** originally a fork of [r0otx/asuswrt-merlin-amneziawg](https://github.com/r0otx/asuswrt-merlin-amneziawg), but the project has changed substantially since forking and is now maintained independently. Thanks to r0otx for the original foundation.

<details>
    <summary>Supported devices</summary>

All aarch64 (ARM64) routers running Asuswrt-Merlin (`384.15` or later, `3006.x`) with Entware installed:

- GT-AX11000
- GT-AXE11000
- GT-AX6000
- RT-AX86U
- RT-AX86U Pro
- RT-AX88U
- RT-AX88U Pro
- RT-AX58U
- RT-AX56U
- TUF-AX5400

Other aarch64 Merlin routers should also work.

</details>

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full changelog.

## Features

- **AmneziaWG protocol** -- WireGuard with DPI obfuscation (Jc, Jmin, Jmax, S1-S4, H1-H4, I1-I5)
- **Userspace daemon** -- based on [amneziawg-go](https://github.com/amnezia-vpn/amneziawg-go), no kernel module needed
- **Web UI** -- ROG-styled addon page integrated into router admin panel (VPN > AmneziaWG)
- **Config import** -- upload `.conf` file exported from Amnezia VPN client
- **Per-device routing** -- assign a policy per device: `VPN: all traffic`, any geo policy, `Direct`
- **Multiple geo policies** -- independent geo policies as tabs (up to 8); each with its own GeoIP / GeoSite / GeoCustom / Antifilter set, chosen per device. Shared lists download once into a common pool
- **Policy mode** -- *include* (route the lists via VPN) or *exclude* (route everything via VPN **except** the lists)
- **Pointwise exclusions** -- own domains/IPs/files/URLs carved out of a policy (or, in exclude mode, carved back in)
- **GeoIP service routing** -- IP ranges for Telegram, Google, Netflix, Twitter, etc. via [Loyalsoldier/geoip](https://github.com/Loyalsoldier/geoip)
- **GeoSite domain routing** -- domain lists via [v2fly/domain-list-community](https://github.com/v2fly/domain-list-community) + dnsmasq ipset
- **GeoCustom — own entries** -- manual domains, CIDR subnets, own files and URL sources
- **Traffic analyzer** -- per device, see which domains/connections go via VPN vs direct; add captured items to a chosen geo policy in one click
- **DNS interception** -- forces DNS through dnsmasq, blocks DoH/DoT for reliable geo routing
- **DNS via tunnel** -- optionally the whole LAN resolves through the config's DNS servers inside the tunnel (provider-internal resolvers like `100.64.0.1` work too); ISP DNS poisoning is out of the picture, and the firmware DNS returns automatically when the tunnel goes down
- **Self-healing** -- a post-start health check (ping/TCP/handshake through the tunnel) with auto-rollback of a dead tunnel, a 5-minute watchdog (revives a fallen tunnel, repairs rules after firewall restarts), and a deadman guard against losing the LAN
- **Conflict warnings** -- on-page banners for co-resident DPI/proxy tools (zapret/Xray/b4), XRAYUI in "redirect all" mode, and the firmware's own VPN client (wgc/VPN Fusion) whose rules outrank the addon's
- **MSS clamping** -- automatic TCP MSS fix for tunnel traffic
- **Auto-update** -- daily cron for geo list refresh

## Requirements

- [Asuswrt-Merlin firmware](https://www.asuswrt-merlin.net/download) (`384.15` or later, `3006.x`)
- [Entware](https://github.com/Entware/Entware/wiki/Install-on-Asus-stock-firmware) installed (use [amtm](https://diversion.ch/amtm.html) to install)
- SSH access to the router
- AmneziaWG server (self-hosted) -- for quick server setup: [amneziawg-installer](https://github.com/bivlked/amneziawg-installer)

## Installation

### Quick install (one command)

```shell
curl -sfL https://raw.githubusercontent.com/william-aqn/asuswrt-merlin-amneziawg/main/install-online.sh | sh
```

The script auto-detects router architecture, downloads the latest package from GitHub releases and installs it.

**If GitHub is blocked:** install via the jsDelivr mirror —

```shell
curl -sfL https://cdn.jsdelivr.net/gh/william-aqn/asuswrt-merlin-amneziawg@main/install-online.sh | sh
```

The script downloads the `.ipk` through proxy mirrors. The SHA256 checksum is verified when the GitHub API is reachable; with GitHub fully blocked the check is skipped (jsDelivr serves only repo files and cannot attest release-asset hashes).

### From .ipk package

Copy the package to the router and install:

```shell
scp amneziawg_1.0.0-1_aarch64-3.10.ipk admin@<router-ip>:/tmp/
```

```shell
ssh admin@<router-ip>
opkg install /tmp/amneziawg_1.0.0-1_aarch64-3.10.ipk
```

### Manual installation

The project is fully **userspace**: the `amneziawg-go` daemon + the `awg` tool, with no custom kernel module (only the stock `tun` is needed). For a clean install the simplest path is to build the `.ipk` (`./build-ipk.sh`) and install it via `opkg` (see "From .ipk package") — the package lays out the binaries in `/opt/amneziawg`, the addon in `/jffs/addons/amneziawg`, creates the `S99amneziawg` init script and registers the page.

To quickly update **only the addon** (backend script and web page) without rebuilding the binaries, copy the files straight into `/jffs/addons/amneziawg/` and restart:

```shell
scp addon/amneziawg.sh addon/amneziawg_page.asp addon/amneziawg_widget.js admin@<router-ip>:/jffs/addons/amneziawg/
ssh admin@<router-ip>
/jffs/addons/amneziawg/amneziawg.sh install_page   # re-register the page in the router menu
/jffs/addons/amneziawg/amneziawg.sh restart         # restart the tunnel with the new code
```

> GUI SCP clients: for Windows — [WinSCP](https://winscp.net/eng/download.php), for macOS — [MacSCP](https://www.macscp.co/).

### Post-installation

1. Log out and log back in to the router web UI
2. Navigate to **VPN > AmneziaWG**
3. Click **Import Config** and upload your `.conf` file from Amnezia VPN client
4. Click **Apply**

## Usage

### Quick start

1. Export config from Amnezia VPN client (`.conf` file)
2. In router UI: **VPN > AmneziaWG > Import Config** -- upload the file
3. Click **Apply** -- tunnel starts automatically
4. Add devices in **Device Rules** section with desired policy

### Routing policies

Each device in **Device Rules** picks a policy:

| Policy | Description |
|--------|-------------|
| **VPN: all traffic** | All device traffic goes through VPN |
| **VPN: \<geo policy name\>** | Routed by the chosen geo policy (see below). One entry per geo policy you create |
| **Direct** | Device bypasses VPN entirely |

### Geo policies (tabs)

You can create several geo policies (up to 8) as **tabs** ("+ Add geo policy"). Each tab has its own independent set of sources: **GeoIP**, **GeoSite**, **GeoCustom** (own domains/IPs/files/URLs) and **Geo Antifilter**. Which device uses which policy is set in Device Rules.

All policies route into **one** tunnel — only *which* destinations enter it differs (each policy has its own `ipset`). Identical lists across policies are downloaded and stored **once** (a shared pool); each policy's tunnel only gets what that policy selected. On low-RAM routers the total `ipset` budget is split across policies to avoid OOM.

**Policy mode** — a switch at the top of each tab:

| Mode | Behavior |
|------|----------|
| **Route lists via VPN** (include) | Only list matches go through the tunnel; everything else is direct |
| **Lists go direct** (exclude) | The opposite: all the device's traffic goes through the tunnel **except** the lists |

> Exclude mode pulls most traffic into the tunnel (like "all traffic", but with carve-outs) — mind this when coexisting with zapret/Xray/b4.

**Pointwise exclusions** — a block at the bottom of each tab (own domains/IPs/subnets/files/URLs). Entries act as exceptions per the mode: in include mode they go **direct** (carved out of the VPN), in exclude mode they go **via VPN**. Handy when a broad list (e.g. a GeoSite category) pulls in more than you want.

### GeoIP Service Lists

Add service names (comma-separated) to route their IP ranges through VPN:

```
telegram,google,facebook,twitter,netflix,cloudflare
```

These are IP-based -- work without DNS, ideal for Telegram and other apps that connect by IP directly.

### GeoSite Service Lists

Add service names for domain-based routing via dnsmasq:

```
youtube,google,discord,netflix,spotify,instagram
```

Requires devices to use the router as DNS server. For iPhones: **Settings > Wi-Fi > (i) > DNS > Manual > router IP only**.

### GeoCustom — own entries

- **Custom domains** -- comma/newline-separated domains (e.g. `example.com,service.org`)
- **Custom IPs / subnets** -- comma-separated IPs/CIDRs (e.g. `8.8.8.8,1.1.1.0/24`)
- **Custom files** -- named lists you can paste/edit in the UI or load from a file (domain → DNS, IP/subnet → ipset; lines starting with `#` are comments)
- **URL sources** -- links to downloadable lists in the same format

The same fields appear in the **Pointwise exclusions** block — there they act as exclusions (see [Geo policies](#geo-policies-tabs)).

## Building from source

### Prerequisites

- Docker Desktop
- Go (recent stable; the `armv7-2.6` package additionally needs the Go 1.23 toolchain — see below)
- GNU tar (`brew install gnu-tar` on macOS)

### Build amneziawg-go (userspace daemon)

```shell
git clone --depth 1 --branch v0.2.19 https://github.com/amnezia-vpn/amneziawg-go.git
cd amneziawg-go

# ARM64 (aarch64-3.10) — GT-AX11000, RT-AX86U, RT-AX88U
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -ldflags="-s -w" -o ../output/amneziawg-go

# ARM32 (armv7-3.2) — RT-AX56U, RT-AX58U, newer HND routers
CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 go build -ldflags="-s -w" -o ../output/amneziawg-go-arm
```

**ARM32 `armv7-2.6` (RT-AC68U, RT-AC66U and other kernel-2.6.36 routers) is built differently.** Go ≥ 1.24 supports only Linux kernel ≥ 3.2 — a regular build dies silently right after launch on those routers. The daemon for this package is therefore built with the **Go 1.23** toolchain (supports kernels from 2.6.32) with the dependencies downgraded to the newest 1.23-compatible line:

```shell
go get golang.org/x/sys@v0.35.0 golang.org/x/net@v0.43.0 golang.org/x/crypto@v0.41.0
go mod edit -go=1.23.0 -toolchain=none
GOTOOLCHAIN=go1.23.12 CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=5 \
  go build -ldflags="-s -w" -o ../output/amneziawg-go-arm5
```

The canonical commands (including the version patch so `--version` reports `v0.2.19-legacy26`) live in `.github/workflows/release.yml`, step "Build amneziawg-go-arm5 (legacy Go 1.23…)".

### Build awg CLI tool (static musl)

`awg` is linked statically against musl (to run on the router's older glibc). The canonical commands for every variant live in `.github/workflows/release.yml` (the "Build awg…" steps); CI builds `awg`/`awg-arm`/`awg-arm5` and publishes the `.ipk`s. Locally, for ARM64:

```shell
docker run --rm --platform linux/arm64 -v "$PWD/output:/out" alpine:3.19 sh -c \
  'apk add --no-cache build-base linux-headers git && \
   git clone --depth 1 --branch v1.0.20260223 https://github.com/amnezia-vpn/amneziawg-tools.git /t && \
   cd /t/src && make LDFLAGS=-static PLATFORM_CFLAGS= && cp awg /out/awg'
```

> ARM32: `armv7` — same with `--platform linux/arm/v7`; the old `armv5` (RT-AC68U) **must** be soft-float (`dockcross/linux-armv5-musl`) or it SIGILLs on VFP-less cores. Exact commands are in `release.yml`.

### Build .ipk package

```shell
./build-ipk.sh
```

Output: `output/amneziawg_1.0.0-1_aarch64-3.10.ipk`

## CLI usage

```shell
# Start/stop/restart
/opt/etc/init.d/S99amneziawg start
/opt/etc/init.d/S99amneziawg stop
/opt/etc/init.d/S99amneziawg restart

# Update the program to the latest version
/opt/etc/init.d/S99amneziawg update

# Install a specific version (e.g. rollback or pin)
/opt/etc/init.d/S99amneziawg update 1.1.50

# Show tunnel status
awg show

# Update geo lists
/jffs/addons/amneziawg/amneziawg.sh update_geo

# Diagnostics — full report (version, platform, binaries + live probes, daemon exit code,
# coreutils self-test, network/TUN, routing, rule copy counts, lock & watchdog state,
# per-policy geo ipsets, dnsmasq, firmware VPN client, system logs, generated config with
# secrets redacted) for a bug report
/jffs/addons/amneziawg/amneziawg.sh diag
```

> `S99amneziawg start` is the boot path (the system invokes it at router startup): it honors the **"Autostart"** checkbox in the web UI and will not bring the tunnel up when the checkbox is off. To start manually regardless of the checkbox: `/jffs/addons/amneziawg/amneziawg.sh start`.

> The same report is available in the web UI via the **"Получить диагностические данные"** button in the "Журнал" (Log) block — you can **download it as a `.txt` file** or **copy it** to the clipboard with the 📋 mini-button (fenced in a code block, ready to paste into Telegram).

## How to uninstall

```shell
/jffs/addons/amneziawg/amneziawg.sh uninstall
opkg remove amneziawg
```

## Architecture

```
Internet <-- awg0 (tunnel) <-- iptables mangle AWG chain <-- br0 (LAN devices)
                                        |
                            per-geo-policy ipset: awg_dst, awg_dst2, …
                            (GeoIP/Antifilter CIDRs + DNS-resolved IPs; a policy
                             with exclusions also gets its own awg_dst<id>_x)
                                        |
                                fwmark 0x100 -> routing table 300 -> awg0
```

| Component | Role |
|-----------|------|
| **amneziawg-go** | Userspace WireGuard daemon with AmneziaWG extensions |
| **awg** | CLI tool for tunnel management (works with kernel and userspace) |
| **amneziawg.sh** | Backend: lifecycle, firewall, routing, geo lists, DNS interception |
| **amneziawg_page.asp** | Web UI addon page (**VPN > AmneziaWG**) |
| **amneziawg_widget.js** | Global header widget: ● AWG status indicator on every firmware page + a mini-panel to toggle the tunnel (served as `/www/user/awg_widget.js`, loaded via `menuTree.js`) |

## FAQ

**Q: Telegram doesn't work through VPN?**

A: Add `telegram` to GeoIP Service Lists. Telegram connects by IP, not DNS -- domain lists alone won't work.

**Q: Sites don't open on iPhone with a geo policy?**

A: iPhone uses encrypted DNS (DoH) which bypasses the router's dnsmasq. Set DNS manually: Settings > Wi-Fi > (i) > DNS > Manual > router IP only.

**Q: Is ARM32 (RT-AC68U) supported?**

A: Yes — there's a dedicated `armv7-2.6` .ipk. Since **1.2.32** its daemon is built with a special legacy toolchain (Go 1.23): regular Go ≥ 1.24 builds don't support these routers' 2.6.36 kernel and died silently with `ERROR: amneziawg-go failed to create interface`. To verify you have the right build: `/opt/amneziawg/amneziawg-go --version` should report `v0.2.19-legacy26 (…)`.

**Q: The tunnel stops by itself a minute or two after starting (or loops "works 2 minutes → drop → reconnect")?**

A: Update to **1.2.32+**. Previously the health check and the watchdog probed the tunnel with ping (and TCP) against the `awg_watchdog_hosts` targets — and if those hosts answer neither ICMP nor TCP:443 (Cloudflare WARP, provider-internal gateways like `100.64.0.1`), a fully working tunnel was falsely declared dead and rolled back. Now a fresh **WireGuard handshake** counts as proof of life (our own probe packets force it to refresh), so silent probe hosts no longer cause rollbacks. Still, leave the probe-hosts field empty (defaults to `8.8.8.8 1.1.1.1`) or point it at genuinely ping-able hosts — checks pass faster that way.

**Q: Tunnel works for ping but not for websites?**

A: Restart the tunnel with a pause: `/jffs/addons/amneziawg/amneziawg.sh stop; sleep 5; /jffs/addons/amneziawg/amneziawg.sh start`

**Q: How to add a custom service by IP?**

A: Add CIDR ranges in the "Custom IPs / subnets" field (GeoCustom), e.g. `149.154.160.0/20,91.108.4.0/22` for Telegram.

**Q: How do I temporarily disable the tunnel so it doesn't come back up after a reboot (without uninstalling the addon)?**

A: Since **1.2.52** — natively: stop the tunnel with the "Stop" button and untick the **"Autostart"** checkbox in the settings (Apply). After a reboot the tunnel stays stopped and your working config is fully preserved; when you need it again — "Start", and re-tick the checkbox if you like. Handy while debugging co-resident tools (zapret2, Xray, etc.).

**Q: Can it run alongside zapret2 or Xray (XRAYUI)?**

A: Yes, with caveats. The addon auto-detects a co-resident DPI-bypass/proxy tool (zapret2/bol-van, Xray/XRAYUI, v2ray, sing-box, **b4**, or NFQUEUE/TPROXY rules in iptables or nftables) and in that case **does not enable DNS interception** (the :53 DNAT), to avoid colliding with them -- otherwise the network can lose internet access. This is controlled by **Compatibility mode** (formerly the "Don't intercept DNS" checkbox): it is **on by default for fresh installs** so even an unknown tool can't leave the network without internet; existing installs keep their previous behavior until you enable it.

Important: this only resolves the DNS-layer conflict. With the default **"VPN -- All Traffic"** policy, routing still pulls the neighbor proxy's traffic into the tunnel, so for coexistence choose the **"Direct"** or **"VPN -- Geo Only"** policy, not "all". Geo routing by IP keeps working.

**Reverse case — XRAYUI captures AmneziaWG's traffic.** If XRAYUI runs in transparent-proxy "redirect all traffic" mode (TPROXY), it also grabs the router's own egress — including AmneziaWG's handshake — so the tunnel comes up but passes no traffic (the health check rolls it back after ~60s). The addon detects this and shows a **red banner** on the page. Fix: in XRAYUI turn off "redirect all" / transparent routing, or exclude AmneziaWG's endpoint and the `awg0` interface from its capture, or keep only one VPN active at a time.

**Q: Is the addon compatible with QoS (Adaptive QoS / Cake / Traditional)?**

A: Yes. Live-tested on a GT-AX6000 with Adaptive QoS (Trend Micro): to QoS the tunnel is a single encrypted UDP flow from the router — it gets classified and shaped as a whole (the bwdpi mark shows up right on the tunnel's conntrack entry), and tunnel throughput did not change with QoS on (22.7 → 22.2 MB/s — within noise). Toggling QoS restarts the firewall — the addon's rules are re-applied automatically (the firewall-start hook), the tunnel stays up.

Honest limitations:
- **per-app and per-device QoS priorities do not apply to traffic inside the tunnel** — QoS can't see that it's YouTube from the TV in there; that's a property of any router-side VPN, not of the addon. Prioritizing/limiting the tunnel as a whole works; direct devices are classified as usual;
- on weaker routers mind the combined CPU load: the QoS DPI engine plus amneziawg-go's userspace crypto;
- an unlikely-but-possible packet-mark conflict applies mainly to **Traditional QoS** (Adaptive on HND platforms marks at the kernel/conntrack level and doesn't insert iptables rules ahead of our chain). The symptom is unambiguous: geo devices stop going through the tunnel right after enabling QoS — grab the diag report (it shows the AWG chain and its counters) and report it.

**Q: `ipset` prints `Warning: Kernel support protocol versions 6-6 while userspace supports protocol versions 6-7`?**

A: It's a harmless warning, not an error. The `ipset` userspace tool (both the firmware's `/usr/sbin/ipset` and Entware's `/opt/sbin/ipset`) is built from newer sources and supports protocol versions 6 and 7, while the ipset module in the router's old kernel (4.1.51) implements only version 6. The ranges overlap at version 6, so the tool automatically falls back to it and works fine. Nothing to do here; geo routing via ipset (`awg_dst` and the geo ipsets) works fully on version 6.

## Credits

- [AmneziaWG](https://github.com/amnezia-vpn) -- protocol and implementations
- [Loyalsoldier/geoip](https://github.com/Loyalsoldier/geoip) -- GeoIP service CIDR lists
- [v2fly/domain-list-community](https://github.com/v2fly/domain-list-community) -- domain lists
- [antifilter.download](https://antifilter.download/) -- RKN block lists (IPs/subnets and domains)
- [Asuswrt-Merlin](https://www.asuswrt-merlin.net/) -- router firmware
- [DanielLavrushin/asuswrt-merlin-xrayui](https://github.com/DanielLavrushin/asuswrt-merlin-xrayui) -- routing architecture reference

## Authors

- **DCRM** -- fork maintainer and author, [github.com/william-aqn](https://github.com/william-aqn)
- **r0otx** -- original project author, [github.com/r0otx](https://github.com/r0otx)

## Support the project

If you find this project useful, you can support its development:

**USDT (TRC-20):** `TC9MSnePyR6MBfSGU6WRCNEmCa5iyzmWUr`

## Disclaimer

This project is a technical tool for network security and privacy. The author is not responsible for any use of this software that violates the laws of any jurisdiction. Users are solely responsible for compliance with applicable legislation.

## License

MIT License
