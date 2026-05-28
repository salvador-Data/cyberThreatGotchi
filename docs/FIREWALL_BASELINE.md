# Firewall baseline — CyberThreatGotchi (BPI-R3 Mini)

Default-deny **iptables** allow-list for field devices running CyberThreatGotchi on Debian or OpenWrt. This is a **static** baseline; the CTG **IPS** adds **dynamic** blocks on top at runtime.

## Static baseline vs CTG IPS

| Layer | Source | Mechanism | Persists reboot? |
|-------|--------|-----------|------------------|
| **Baseline** | `scripts/firewall-baseline.sh` | Custom chain `CTG_BASELINE` + INPUT jump; policy `DROP` | Only if you save (see below) |
| **IPS blocks** | `core/ips.py` | `iptables -I INPUT -s <ip> -j DROP` (inserted at **top** of INPUT) | Lost on reboot unless saved |

IPS rules are evaluated **before** the baseline jump because `-I INPUT` inserts at position 1. Re-running the baseline script **flushes and rebuilds `CTG_BASELINE` only** — it does **not** remove IPS DROP rules.

```91:98:core/ips.py
    def _apply_firewall_rule(self, ip: str, add: bool) -> bool:
        if platform.system() == "Linux":
            cmd = ["iptables", "-D" if not add else "-I", "INPUT", "-s", ip, "-j", "DROP"]
            if not add:
                cmd = ["iptables", "-D", "INPUT", "-s", ip, "-j", "DROP"]
            try:
                subprocess.run(cmd, check=False, capture_output=True, timeout=10)
```

## Port reference (BPI-R3 Mini)

| Port / proto | Service | Notes |
|--------------|---------|-------|
| **8765/tcp** | CTG web dashboard | Default from `install.sh` / `config/default.yaml`; override with `CTG_WEB_PORT` |
| **3310/tcp** | ClamAV | **Localhost only** in baseline (`127.0.0.1`); matches `CLAMAV_PORT` in `/etc/cyberthreatgotchi/env` |
| 22/tcp | SSH | Optional LAN-only via `CTG_SSH_LAN_ONLY=1` |
| 25, 465/tcp | SMTP / SMTPS | Mail relay if enabled on device |
| 53/tcp, udp | DNS | Resolver / local DNS |
| 80, 443/tcp | HTTP / HTTPS | Web services on gateway |
| 5222, 5269, 5280/tcp | XMPP / BOSH | Messaging stack (if deployed) |
| 8999–9003/tcp | Auxiliary services | Sample baseline range (adjust via `CTG_EXTRA_TCP_PORTS`) |
| ICMP | Ping | Disable with `CTG_ALLOW_ICMP=0` |

Add ad-hoc ports: `CTG_EXTRA_TCP_PORTS=9090,9091` (Stripe provisioner, webhooks, etc.).

## Quick start

```bash
cd /opt/cyberThreatGotchi
sudo ./scripts/firewall-baseline.sh --dry-run    # preview commands
sudo ./scripts/firewall-baseline.sh              # apply
sudo ./scripts/firewall-baseline-save.sh         # persist (Debian: /etc/iptables/rules.v4)
```

During install:

```bash
sudo CTG_FIREWALL_BASELINE=1 ./scripts/install.sh
```

Or answer **yes** when the installer prompts interactively.

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `CTG_WEB_PORT` | `8765` | CTG dashboard TCP port in allow-list |
| `CTG_EXTRA_TCP_PORTS` | *(empty)* | Comma-separated extra TCP ports |
| `CTG_ALLOW_ICMP` | `1` | Set `0` to drop inbound ping |
| `CTG_SSH_LAN_ONLY` | `0` | Set `1` to allow SSH only from RFC1918 + link-local |
| `CTG_IPTABLES_SAVE_PATH` | `/etc/iptables/rules.v4` | Output path for save script |

## Debian vs OpenWrt

### Debian (BPI-R3 Mini image)

```bash
apt-get install -y iptables iptables-persistent
sudo ./scripts/firewall-baseline.sh
sudo ./scripts/firewall-baseline-save.sh
# Confirm netfilter-persistent loads rules.v4 on boot
```

Restore a saved ruleset:

```bash
sudo ./scripts/firewall-baseline.sh --restore /etc/iptables/rules.v4
```

### OpenWrt

OpenWrt often uses **fw4** / UCI firewall. Options:

1. Run `firewall-baseline.sh` after boot from `/etc/firewall.user` (legacy iptables) or a procd init script.
2. Mirror the same port list in UCI if you prefer native fw4 — keep CTG IPS compatible (`iptables` or `nft` backend must accept `-I INPUT`).

Test from LAN before disconnecting console: `curl http://<device-ip>:8765/api/status`.

## Security notes

- **SSH from LAN only:** `sudo CTG_SSH_LAN_ONLY=1 ./scripts/firewall-baseline.sh` — blocks WAN SSH while keeping other allowed ports. Prefer key-based auth and disable password login in `sshd_config`.
- **Web dashboard:** Bind to LAN only in production if possible; set `CTG_WEB_API_TOKEN` for mutating API routes (see [SECURITY_HARDENING.md](SECURITY_HARDENING.md)).
- **ClamAV:** Port 3310 is not exposed on all interfaces — local socket only via iptables source match.
- **Authorized use:** Apply only on networks you own or have written permission to monitor.

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Locked out after apply | Serial/console access; `iptables -P INPUT ACCEPT` from console |
| Dashboard unreachable | `CTG_WEB_PORT`, `curl -v localhost:8765`, `iptables -L CTG_BASELINE -n -v` |
| IPS block stuck | `iptables -L INPUT -n --line-numbers`; CTG expires blocks automatically |
| Rules lost on reboot | Run `firewall-baseline-save.sh`; enable `iptables-persistent` |

See also [SECURITY_HARDENING.md](SECURITY_HARDENING.md) · [WEB.md](WEB.md).
