# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AmneziaWG userspace VPN (the `amneziawg-go` daemon + `awg` CLI) + web UI addon for ASUS routers running Asuswrt-Merlin 388.x firmware. Provides DPI-obfuscated WireGuard VPN with per-device policy routing and GeoIP/GeoSite selective routing. All documentation and UI text is in Russian.

**Target:** ARM64 (aarch64) and ARM32 ASUS routers. Fully userspace — no kernel module, works on any kernel version (only the stock `tun` device is needed).

## Build

Pure userspace — **no kernel module**. Packages are built and published by CI on tag push (`.github/workflows/release.yml`):
- `amneziawg-go` daemon built with Go (`GOARCH=arm64`, plus `arm` GOARM=5/7),
- `awg` CLI built as a **static-musl** binary per arch (Alpine for aarch64/armv7; `dockcross/linux-armv5-musl` **soft-float** for VFP-less Cortex-A9 like RT-AC68U),
- `./build-ipk.sh` assembles the `.ipk`s into `output/`.

Build locally by replicating those steps (or run `./build-ipk.sh` once the binaries are in `output/`). Install on a router with `install-online.sh` (`curl … | sh` → `opkg`) or `opkg install <pkg>.ipk`.

## Architecture

### Build pipeline (`.github/workflows/release.yml`)
Userspace-only: builds `amneziawg-go` (Go) and the static-musl `awg` CLI per architecture, then `build-ipk.sh` packs them into `.ipk`s. On a `v*` tag the workflow publishes a GitHub Release (notes pulled from the matching `CHANGELOG.md` section) and registers the tag with jsDelivr (the router resolves updates via jsDelivr when api.github.com is region-blocked).

### Router-side components

**`addon/amneziawg.sh`** — Main backend script (runs on router). Handles:
- Interface lifecycle: `start`/`stop`/`restart` (launch `amneziawg-go` userspace daemon, ip link, awg setconf, iptables, ip rule)
- Config generation from Merlin's `custom_settings.txt` (key prefix: `awg_*`)
- Per-device routing policy: `vpn_all`, `vpn_geo`, `direct` via ip rules + iptables mangle marks
- GeoIP/GeoSite: downloads country CIDR lists, domain lists; populates ipset (`awg_dst`) + dnsmasq ipset rules
- Web UI addon mounting via Merlin Addons API (`am_get_webui_page`, menuTree.js bind mount)
- Service event dispatch (called from `/jffs/scripts/service-event`)

**`addon/amneziawg_page.asp`** — Web UI page (ROG-styled ASP). Communicates with backend via Merlin's `httpApi` custom settings and service events (`awgstart`, `awgstop`, `awgsaveconf`, `awgupdategeo`). Reads status from `/www/user/awg_status.htm` (JSON).

**`install-online.sh`** — On-router installer (`curl … | sh`): resolves the latest release (GitHub API → jsDelivr fallback), downloads the arch-matched `.ipk`, verifies its SHA256, and `opkg install`s it. The `.ipk` (built by `build-ipk.sh`) ships the `S99amneziawg` CLI entry-point and its postinst registers the addon page.

### Key paths on router
- `/opt/amneziawg/` — daemon (`amneziawg-go`), tool (`awg`), config, client list, geo data
- `/jffs/addons/amneziawg/` — addon script + ASP page
- `/jffs/configs/dnsmasq.conf.add` — domain-based routing rules (tagged with `### AmneziaWG`)
- `/jffs/addons/custom_settings.txt` — Merlin settings store (all keys prefixed `awg_`)

### Routing model
Three policies per device: `vpn_all` (ip rule → table 200), `vpn_geo` (iptables fwmark 0x100 + ipset match → table 200), `direct`. Default policy applies to unlisted devices. Route table 200, priority 100, fwmark 0x100.

## Shell scripting notes

All router-side scripts must be POSIX sh (busybox ash) — no bashisms. The router runs BusyBox with limited coreutils.
