# Kali lab — Ethernet promiscuous vs WiFi monitor mode

**Author:** Andy Kowal · **Organization:** [Hacker Planet LLC](https://salvador-Data.github.io/cyberThreatGotchi/) (Philadelphia, PA)  
**Authorized use:** Networks and spectrum you own or have **written scope** to test. No third-party sniffing, illegal regdomain bypass, or jamming.

---

## Short answer (Andy’s question)

| Medium | Mode for full capture | What you get |
|--------|----------------------|--------------|
| **Ethernet (CAT5)** | **Classic promiscuous** (`ip link set dev eth0 promisc on`) when the cable is plugged and the link is **UP** | All Ethernet frames on that **LAN segment** (broadcast domain) — suitable for Wireshark on `eth0` |
| **WiFi (USB dongle)** | **`promisc` on wlan is often not enough** for 802.11 | Driver may ignore most over-the-air traffic; **monitor mode** (`airmon-ng start wlanX`) is required for meaningful **802.11** capture in Wireshark |
| **Both at once** | **Yes — different interfaces** | `eth0` promisc for wired lab sniff **and** `wlan1mon` (monitor) for wireless — not the same packet path, but both can be configured simultaneously |

---

## Ethernet (wired CAT5)

When a **cable is connected** to the VM’s wired NIC (`eth0`, `enp0s3`, etc.) and the link comes **UP**:

```bash
sudo ip link set dev eth0 promisc on
```

The NIC receives frames destined for other hosts on the same switched segment (within VLAN/broadcast domain limits). This is the traditional “promiscuous mode” taught for wired LAN analysis.

**CTG automation:** `ctg-wifi-lab-autorun.sh` detects a link-up wired interface and sets promisc automatically.

---

## WiFi (USB Realtek dongle)

### Promiscuous on `wlan` — usually insufficient

```bash
sudo ip link set wlan1 promisc on
```

On many WiFi drivers, **promiscuous** does **not** deliver full 802.11 management/data frames for off-SSID or non-associated traffic. You may only see traffic your station would normally process.

### Monitor mode — required for 802.11 capture

For **Wireshark 802.11** (beacons, probes, channel-wide lab capture on an **owned AP** segment):

```bash
sudo airmon-ng start wlan1
# Often creates wlan1mon — capture on that interface in Wireshark
```

Enable in CTG when lab capture is on:

```bash
sudo CTG_WIFI_MONITOR=1 bash /mnt/ctg/ctg-wifi-lab-autorun.sh --monitor
```

Or set `CTG_WIFI_MONITOR=1` in `/etc/ctg/lab-wifi.conf`.

---

## Running wired + wireless together

```mermaid
flowchart LR
    subgraph vm [Kali VM]
        ETH[eth0 promisc ON\nCAT5 lab LAN]
        WLAN[wlan1 + wlan1mon\nUSB Realtek]
    end
    ETH --> Wireshark1[Wired capture]
    WLAN --> Wireshark2[802.11 capture]
```

- **Wired:** classic promisc on `eth0` (or detected `enp*`) when cable present.
- **Wireless:** monitor via `airmon-ng` on USB `wlan` (not VirtualBox NAT `wlan0` if present).
- Frames on eth and wlan are **independent** — configure both; do not expect one interface to mirror the other.

---

## Lab WiFi config file

Copy the example on the host (staged to `C:\Users\Owner\Backups`) or in-repo:

```bash
sudo cp /mnt/ctg/lab-wifi.conf.example /etc/ctg/lab-wifi.conf
sudo chmod 600 /etc/ctg/lab-wifi.conf
sudo nano /etc/ctg/lab-wifi.conf
```

Set your **authorized lab SSID** and PSK. Prefer **WPA3 personal** (or WPA2/WPA3 transition) on the lab AP — see [WPA3 best practices](#wpa3-best-practices) below. Then:

```bash
sudo bash /mnt/ctg/ctg-wifi-lab-autorun.sh
```

**Log:** `/var/log/ctg-wifi-lab.log`  
**Boot service (optional):** `sudo bash /mnt/ctg/ctg-wifi-lab-autorun.sh --install` → `ctg-wifi-lab.service`

**Boot autopatch with WiFi:** `sudo bash /mnt/ctg/kali-boot-autopatch.sh --wifi-lab` (runs after Guest Additions fix).

---

## WPA3 best practices

**Preferred lab AP security:** WPA3 personal (SAE) or WPA2/WPA3 transition on your owned router/AP.

| Setting | Recommendation |
|---------|----------------|
| AP mode | WPA3 personal, or WPA2/WPA3 transition if older clients share the SSID |
| PMF (802.11w) | **Required** for WPA3-SAE — CTG autorun sets `ieee80211w=2` in wpa_supplicant |
| Config key | `CTG_LAB_WIFI_KEY_MGMT=wpa3` in `/etc/ctg/lab-wifi.conf` (default) |
| Driver limits | Realtek USB (`rtl8812au`) may not advertise SAE in `iw phy` — script logs and falls back to WPA2-PSK |

**Verify SAE on dongle (Kali):**

```bash
iw phy | grep -i SAE
```

**nmcli (manual WPA3-SAE test):**

```bash
sudo nmcli dev wifi connect "YourLabSSID" password "your-psk" ifname wlan1 \
  802-11-wireless-security.key-mgmt sae
```

If WPA3 fails, the autorun retries WPA2-PSK automatically (transition APs accept both). Set `CTG_LAB_WIFI_KEY_MGMT=wpa2` to skip WPA3 entirely on legacy hardware.

---

## Auto-reboot (Realtek DKMS / WPA3 driver)

Installing the **rtl8812au** DKMS module (`ctg-wifi-lab-autorun.sh` or bootstrap) may require a reboot before WPA3-SAE or monitor mode works reliably. The shared helper `ctg-reboot-if-needed.sh --mark` is set after a successful `dkms_install`.

Full lab one-shot (`ctg-lab-autorun.sh`) schedules **`shutdown -r +1`** when any reboot signal is present. Disable with **`CTG_NO_REBOOT=1`** (remote SSH). Log: `/var/log/ctg-reboot.log` · details: [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md#auto-reboot-after-autorun).

---

## DuckDuckGo DNS

By default the WiFi autorun **preserves** existing DuckDuckGo DNS (`94.140.14.14` / `94.140.15.15`) — same policy as iPhone/Windows lab docs. Use `--ddg-dns-only` only when you intentionally want Kali resolv.conf forced to DDG.

---

## Legal and scope

Use only on **Hacker Planet lab VLAN**, **owned AP**, or networks where you have **explicit authorization**. Document scope in `lab-targets.conf`. No rogue AP attacks, deauth, or regdomain hacks in this repo.

---

## Related docs

- [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md) — `Start-CTGLab.ps1` + `ctg-lab-autorun.sh`
- [KALI_LAB_ARCHITECTURE.md](KALI_LAB_ARCHITECTURE.md) — Realtek passthrough, Option 2 `company-lab`
- [scripts/kali/README_KALI_LAB.md](../scripts/kali/README_KALI_LAB.md)
