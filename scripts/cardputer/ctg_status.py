# CyberThreatGotchi remote status — M5Stack Cardputer (MicroPython)
# Copy to Cardputer alongside your M5 OS payload or run standalone.
#
# Edit CTG_HOST to your BPI-R3 Mini LAN IP before flashing.

try:
    import urequests as requests
except ImportError:
    import requests  # type: ignore

import time

CTG_HOST = "192.168.1.50"
CTG_PORT = 8765
POLL_SEC = 4

MOOD_LABEL = {
    "idle": "IDLE",
    "happy": "OK",
    "alert": "ALERT",
    "attack": "BLOCK",
    "sleep": "ZZZ",
    "feed": "FOOD",
    "defend": "DEF",
}


def fetch_status():
    url = "http://{}:{}/api/status".format(CTG_HOST, CTG_PORT)
    r = requests.get(url, timeout=5)
    return r.json()


def draw_screen(data, lcd):
    g = data.get("gotchi", {})
    mood = g.get("mood", "idle")
    threats = data.get("threats") or []
    last = threats[0] if threats else {}
    lcd.fill(lcd.BLACK)
    lcd.setTextColor(lcd.GREEN)
    lcd.setCursor(4, 4)
    lcd.print("CTG " + g.get("name", "Cipherhorn"))
    lcd.setCursor(4, 20)
    lcd.print(MOOD_LABEL.get(mood, mood) + " Lv" + str(g.get("level", 1)))
    lcd.setCursor(4, 36)
    lcd.print("Blk:" + str(g.get("threats_blocked", 0)))
    lcd.print(" See:" + str(g.get("threats_seen", 0)))
    lcd.setCursor(4, 52)
    line = g.get("status_line", "")[:28]
    lcd.print(line)
    lcd.setTextColor(lcd.YELLOW if mood in ("alert", "attack") else lcd.WHITE)
    lcd.setCursor(4, 72)
    if last:
        lcd.print(str(last.get("source_ip", "?"))[:16])
        lcd.setCursor(4, 88)
        lcd.print(str(last.get("severity", "")) + " " + str(last.get("action_taken", ""))[:12])
    else:
        lcd.print("No threats yet")


def main():
    # M5Stack Cardputer — adapt import to your M5Unified / LovyanGFX setup
    from machine import Pin
    try:
        from M5 import LCD
        lcd = LCD
    except ImportError:
        print("Run cardputer_status.py on desktop for testing:")
        print("  python scripts/cardputer_status.py --host", CTG_HOST, "--watch")
        return
    while True:
        try:
            data = fetch_status()
            draw_screen(data, lcd)
        except Exception as e:
            lcd.fill(lcd.BLACK)
            lcd.setCursor(4, 40)
            lcd.print("CTG offline")
        time.sleep(POLL_SEC)


if __name__ == "__main__":
    main()
