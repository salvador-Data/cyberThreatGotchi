#!/usr/bin/env bash
# CTG nmap-ask — adaptive defensive nmap wrapper for authorized lab recon.
# Hacker Planet LLC · Philadelphia, PA · https://github.com/salvador-Data/cyberThreatGotchi
#
# Usage:
#   ctg-nmap-ask.sh <target>          # IP, CIDR, hostname, or - for last target
#   ctg-nmap-ask.sh --reconnect       # same as target -
#   ctg-nmap-ask.sh --dump <target>   # identifiers only (no full scan)
#   ctg-nmap-ask.sh --list            # saved targets
#   ctg-nmap-ask.sh -i <target>       # ignore lab-targets gate (warning)
#
# Invoke as a$k after install: sudo bash kali-boot-autopatch.sh --install
#   /usr/local/bin/ctg-nmap-ask   or   /usr/local/bin/a\$k
set -euo pipefail

SCRIPT_NAME="ctg-nmap-ask"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="1.0.0"

LAB_TARGETS="/etc/ctg/lab-targets.conf"
STATE_ROOT=""
LOG_FILE=""
LAST_TARGET_FILE=""
FORCE_IGNORE_LAB=false
MODE="scan"
TARGET=""
NMAP_BIN="nmap"

log() { printf '[%s] %s\n' "$(date -Iseconds)" "$*" | tee -a "$LOG_FILE"; }
warn() { printf '[%s] WARNING: %s\n' "$(date -Iseconds)" "$*" | tee -a "$LOG_FILE" >&2; }
err() { printf '[%s] ERROR: %s\n' "$(date -Iseconds)" "$*" | tee -a "$LOG_FILE" >&2; exit 1; }

usage() {
    cat <<EOF
${SCRIPT_NAME} v${VERSION} — adaptive defensive nmap for authorized lab use only.

Usage:
  ctg-nmap-ask.sh <target>           Scan IP, CIDR, or hostname
  ctg-nmap-ask.sh -                  Reconnect last target (reload identifiers + scan)
  ctg-nmap-ask.sh --reconnect        Same as -
  ctg-nmap-ask.sh --dump <target>    Print saved IP/MAC/identifiers (no scan)
  ctg-nmap-ask.sh --list             List saved target state files
  ctg-nmap-ask.sh -i <target>        Override lab-targets gate (explicit warning)
  ctg-nmap-ask.sh --help

Shell alias (after install):
  a\$k <target>    → /usr/local/bin/ctg-nmap-ask

State: \${STATE_ROOT}/<target-key>.json
Output: \${STATE_ROOT}/scans/<target-key>-<timestamp>

Authorized Hacker Planet lab / owned systems only. See docs/NMAP_ASK_ANALYSIS.md
EOF
}

init_paths() {
    if [[ "$(id -u)" -eq 0 ]]; then
        STATE_ROOT="/var/log/ctg/nmap-ask"
        LOG_FILE="/var/log/ctg/nmap-ask.log"
    else
        STATE_ROOT="${HOME}/.config/ctg/nmap-ask"
        LOG_FILE="${STATE_ROOT}/nmap-ask.log"
    fi
    LAST_TARGET_FILE="${STATE_ROOT}/last-target"
    mkdir -p "${STATE_ROOT}/scans" "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE" 2>/dev/null || true
}

resolve_script_src() {
    local candidate
    for candidate in \
        "${SCRIPT_DIR}/ctg-nmap-ask.sh" \
        "/opt/ctg/nmap-ask/ctg-nmap-ask.sh" \
        "/mnt/ctg/ctg-nmap-ask.sh" \
        "/media/sf_ctg-backups/ctg-nmap-ask.sh"; do
        if [[ -f "$candidate" ]]; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    return 1
}

target_key() {
    printf '%s' "$1" | tr '/:' '__' | tr -cd 'a-zA-Z0-9._-'
}

state_json_path() {
    printf '%s/%s.json' "$STATE_ROOT" "$(target_key "$1")"
}

save_last_target() {
    printf '%s\n' "$1" >"$LAST_TARGET_FILE"
}

load_last_target() {
    [[ -f "$LAST_TARGET_FILE" ]] || err "No last target — run a scan first or pass an explicit target"
    tr -d '[:space:]' <"$LAST_TARGET_FILE"
}

read_lab_targets_file() {
    local f=""
    for f in "$LAB_TARGETS" "/mnt/ctg/lab-targets.example" "${SCRIPT_DIR}/lab-targets.example"; do
        if [[ -f "$f" ]]; then
            grep -vE '^\s*(#|$)' "$f" | sed 's/#.*//' | tr -d '[:space:]' | grep -v '^$' || true
            return 0
        fi
    done
    return 1
}

lab_target_allowed() {
    local target="$1"
    local entries
    entries="$(read_lab_targets_file 2>/dev/null || true)"
    [[ -n "$entries" ]] || return 1
    printf '%s\n' "$entries" | python3 - "$target" <<'PY'
import ipaddress, sys
target = sys.argv[1].strip()
lines = sys.stdin.read().splitlines()
try:
    if "/" in target:
        net = ipaddress.ip_network(target, strict=False)
        for line in lines:
            try:
                if "/" in line:
                    if net.subnet_of(ipaddress.ip_network(line, strict=False)) or net.overlaps(ipaddress.ip_network(line, strict=False)):
                        sys.exit(0)
                else:
                    if ipaddress.ip_address(line) in net:
                        sys.exit(0)
            except ValueError:
                continue
    else:
        try:
            ip = ipaddress.ip_address(target)
        except ValueError:
            # hostname — allow if any RFC1918/lab CIDR listed (operator responsibility)
            sys.exit(0 if lines else 1)
        for line in lines:
            try:
                if "/" in line:
                    if ip in ipaddress.ip_network(line, strict=False):
                        sys.exit(0)
                elif ip == ipaddress.ip_address(line):
                    sys.exit(0)
            except ValueError:
                continue
except ValueError:
    pass
sys.exit(1)
PY
}

enforce_lab_scope() {
    local target="$1"
    if $FORCE_IGNORE_LAB; then
        warn "Lab-targets gate bypassed (-i). Ensure written authorization for: $target"
        return 0
    fi
    if lab_target_allowed "$target"; then
        log "Target $target is within lab-targets scope"
        return 0
    fi
    err "Target '$target' not in ${LAB_TARGETS}. Add to lab-targets.conf or use -i with explicit authorization."
}

is_cidr() {
    [[ "$1" == */* ]]
}

is_root() {
    [[ "$(id -u)" -eq 0 ]]
}

pick_interface() {
    ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}' || \
        ip -br link 2>/dev/null | awk '/UP/ && !/lo/ {print $1; exit}'
}

is_local_lan() {
    local target="$1"
    python3 - "$target" <<'PY'
import ipaddress, sys
t = sys.argv[1]
try:
    ip = ipaddress.ip_address(t.split("/")[0])
except ValueError:
    sys.exit(1)
for net in (ipaddress.ip_network("10.0.0.0/8"), ipaddress.ip_network("172.16.0.0/12"), ipaddress.ip_network("192.168.0.0/16")):
    if ip in net:
        sys.exit(0)
sys.exit(1)
PY
}

write_state_json() {
    local target="$1" xml_file="$2" iface="$3"
    local out
    out="$(state_json_path "$target")"
    python3 - "$target" "$xml_file" "$iface" "$out" <<'PY'
import json, sys, xml.etree.ElementTree as ET
from datetime import datetime, timezone

target, xml_path, iface, out_path = sys.argv[1:5]
data = {
    "target": target,
    "ip": None,
    "mac": None,
    "hostname": None,
    "vendor": None,
    "os_guess": None,
    "open_ports": [],
    "last_scan_iso": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "interface_used": iface,
    "scan_xml": xml_path,
}

try:
    tree = ET.parse(xml_path)
    root = tree.getroot()
except (ET.ParseError, FileNotFoundError):
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    sys.exit(0)

ns = {"n": "http://www.insecure.org/nmaprun"}
host = root.find("n:host", ns)
if host is not None:
    addr_ip = host.find("n:address[@addrtype='ipv4']", ns)
    addr_mac = host.find("n:address[@addrtype='mac']", ns)
    if addr_ip is not None:
        data["ip"] = addr_ip.get("addr")
    if addr_mac is not None:
        data["mac"] = addr_mac.get("addr")
        data["vendor"] = addr_mac.get("vendor")
    hn = host.find("n:hostnames/n:hostname", ns)
    if hn is not None:
        data["hostname"] = hn.get("name")
    osm = host.find("n:os/n:osmatch", ns)
    if osm is not None:
        data["os_guess"] = osm.get("name")
    ports = host.find("n:ports", ns)
    if ports is not None:
        for p in ports.findall("n:port", ns):
            state = p.find("n:state", ns)
            if state is not None and state.get("state") == "open":
                svc = p.find("n:service", ns)
                entry = {"port": p.get("portid"), "proto": p.get("protocol")}
                if svc is not None:
                    if svc.get("name"):
                        entry["service"] = svc.get("name")
                    if svc.get("product"):
                        entry["product"] = svc.get("product")
                data["open_ports"].append(entry)

with open(out_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
PY
    log "State saved: $out"
}

dump_state() {
    local target="$1"
    local f
    f="$(state_json_path "$target")"
    [[ -f "$f" ]] || err "No state for target: $target (run a scan first)"
    python3 - "$f" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
print("=== CTG nmap-ask identifiers ===")
for k in ("target", "ip", "mac", "hostname", "vendor", "os_guess", "interface_used", "last_scan_iso"):
    print(f"  {k}: {d.get(k) or '-'}")
ports = d.get("open_ports") or []
if ports:
    print("  open_ports:")
    for p in ports:
        svc = p.get("service", "")
        print(f"    {p.get('proto')}/{p.get('port')} {svc}")
else:
    print("  open_ports: (none recorded)")
PY
}

list_states() {
    shopt -s nullglob
    local files=("${STATE_ROOT}"/*.json)
    if [[ ${#files[@]} -eq 0 ]]; then
        log "No saved targets in ${STATE_ROOT}"
        return 0
    fi
    printf '%-24s %-16s %-18s %s\n' "TARGET" "IP" "MAC" "LAST_SCAN"
    for f in "${files[@]}"; do
        python3 - "$f" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
print("{target:<24} {ip:<16} {mac:<18} {ts}".format(
    target=(d.get("target") or "?")[:24],
    ip=(d.get("ip") or "-")[:16],
    mac=(d.get("mac") or "-")[:18],
    ts=d.get("last_scan_iso") or "-",
))
PY
    done
}

run_adaptive_scan() {
    local target="$1"
    local iface scan_base ts key xml_out
    iface="$(pick_interface)"
    key="$(target_key "$target")"
    ts="$(date +%Y%m%d-%H%M%S)"
    scan_base="${STATE_ROOT}/scans/${key}-${ts}"

    command -v "$NMAP_BIN" >/dev/null 2>&1 || err "nmap not installed — apt install nmap"

    local syn_flag="-sS"
    is_root || syn_flag="-sT"

    log "=== CTG nmap-ask adaptive scan: $target (iface=${iface:-auto}) ==="

    if is_cidr "$target"; then
        log "Phase 1: host discovery (-sn) on $target"
        "$NMAP_BIN" -sn -oA "${scan_base}-discover" --reason "$target" || warn "Discovery phase returned non-zero"
    fi

    log "Phase 2–5: consolidated scan (ports, services, OS, safe NSE)"
    local -a scan_args=("$syn_flag" -T4 --top-ports 1000 -sV --version-intensity 5)
    if is_local_lan "$target" && is_root; then
        log "  + ARP ping (-PR) on local LAN"
        scan_args+=(-PR)
    fi
    if is_root; then
        log "  + OS detection (-O)"
        scan_args+=(-O --osscan-guess)
    else
        warn "OS detection skipped (requires root / sudo)"
    fi
    local nse_dir=""
    for candidate in \
        "/opt/ctg/nmap-ask/nse" \
        "${SCRIPT_DIR}/nse" \
        "/mnt/ctg/nse"; do
        if [[ -d "$candidate" && -f "${candidate}/ctg-ask-recon.nse" ]]; then
            nse_dir="$candidate"
            break
        fi
    done
    scan_args+=(--script=default,safe,vuln --script-timeout=120s)
    [[ -n "$nse_dir" ]] && scan_args+=(--script-dir="$nse_dir")

    "$NMAP_BIN" "${scan_args[@]}" -oA "$scan_base" --reason "$target" || warn "Consolidated scan returned non-zero"

    xml_out="${scan_base}.xml"
    [[ -f "$xml_out" ]] || err "Expected nmap XML output missing: $xml_out"

    write_state_json "$target" "$xml_out" "${iface:-unknown}"
    save_last_target "$target"

    log "--- Human summary ---"
    dump_state "$target"
    log "Full output: ${scan_base}.{xml,gnmap,nmap,normal}"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h) usage; exit 0 ;;
            --list) MODE="list"; shift ;;
            --dump) MODE="dump"; shift; TARGET="${1:-}"; shift || true ;;
            --reconnect|-) MODE="scan"; TARGET="-"; shift ;;
            -i) FORCE_IGNORE_LAB=true; shift ;;
            --*) err "Unknown option: $1" ;;
            *)
                if [[ -z "$TARGET" ]]; then
                    TARGET="$1"
                else
                    err "Unexpected argument: $1"
                fi
                shift
                ;;
        esac
    done
}

main() {
    init_paths
    parse_args "$@"

    case "$MODE" in
        list)
            list_states
            exit 0
            ;;
        dump)
            [[ -n "$TARGET" ]] || err "--dump requires a target"
            if [[ "$TARGET" == "-" ]]; then
                TARGET="$(load_last_target)"
            fi
            enforce_lab_scope "$TARGET"
            dump_state "$TARGET"
            exit 0
            ;;
        scan)
            if [[ -z "$TARGET" ]]; then
                usage
                exit 1
            fi
            if [[ "$TARGET" == "-" ]]; then
                TARGET="$(load_last_target)"
                log "Reconnecting to last target: $TARGET"
            fi
            enforce_lab_scope "$TARGET"
            run_adaptive_scan "$TARGET"
            ;;
    esac
}

main "$@"
