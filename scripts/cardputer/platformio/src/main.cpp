/**
 * CyberThreatGotchi Cardputer status — native firmware (PlatformIO)
 *
 * Build:  cd scripts/cardputer/platformio && pio run
 * Flash:  pio run -t upload
 *
 * Edit CTG_HOST / CTG_PORT in platformio.ini build_flags before flashing.
 */

#include <M5Unified.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

#ifndef CTG_HOST
#define CTG_HOST "192.168.1.50"
#endif
#ifndef CTG_PORT
#define CTG_PORT 8765
#endif
#ifndef POLL_MS
#define POLL_MS 4000
#endif

// Set in platformio.ini or override here for quick tests
#ifndef WIFI_SSID
#define WIFI_SSID "YOUR_SSID"
#endif
#ifndef WIFI_PASS
#define WIFI_PASS "YOUR_PASSWORD"
#endif

static const char* moodLabel(const char* mood) {
  if (!mood) return "IDLE";
  if (strcmp(mood, "happy") == 0) return "OK";
  if (strcmp(mood, "alert") == 0) return "ALERT";
  if (strcmp(mood, "attack") == 0) return "BLOCK";
  if (strcmp(mood, "sleep") == 0) return "ZZZ";
  if (strcmp(mood, "defend") == 0) return "DEF";
  return mood;
}

static bool fetchStatus(String& mood, int& level, int& blocked, int& seen, String& statusLine,
                        String& lastIp, String& lastSev, String& lastAction) {
  WiFiClient client;
  HTTPClient http;
  String url = String("http://") + CTG_HOST + ":" + String(CTG_PORT) + "/api/status";
  if (!http.begin(client, url)) return false;
  int code = http.GET();
  if (code != 200) {
    http.end();
    return false;
  }
  String body = http.getString();
  http.end();

  JsonDocument doc;
  if (deserializeJson(doc, body)) return false;

  JsonObject g = doc["gotchi"].as<JsonObject>();
  mood = g["mood"] | "idle";
  level = g["level"] | 1;
  blocked = g["threats_blocked"] | 0;
  seen = g["threats_seen"] | 0;
  statusLine = g["status_line"] | "";

  JsonArray threats = doc["threats"].as<JsonArray>();
  if (!threats.isNull() && threats.size() > 0) {
    JsonObject t = threats[0].as<JsonObject>();
    lastIp = t["source_ip"] | "?";
    lastSev = t["severity"] | "";
    lastAction = t["action_taken"] | "";
  } else {
    lastIp = "";
    lastSev = "";
    lastAction = "";
  }
  return true;
}

static void drawScreen(const String& mood, int level, int blocked, int seen,
                       const String& statusLine, const String& lastIp,
                       const String& lastSev, const String& lastAction, bool ok) {
  auto& d = M5.Display;
  d.fillScreen(TFT_BLACK);
  d.setTextSize(1);
  d.setTextColor(ok ? TFT_GREEN : TFT_RED);
  d.setCursor(4, 4);
  d.printf("CTG Cipherhorn");
  d.setCursor(4, 20);
  d.printf("%s Lv%d", moodLabel(mood.c_str()), level);
  d.setCursor(4, 36);
  d.printf("Blk:%d See:%d", blocked, seen);
  d.setTextColor(TFT_WHITE);
  d.setCursor(4, 52);
  String line = statusLine;
  if (line.length() > 28) line = line.substring(0, 28);
  d.print(line);
  if (lastIp.length()) {
    d.setTextColor((mood == "alert" || mood == "attack") ? TFT_YELLOW : TFT_WHITE);
    d.setCursor(4, 72);
    d.print(lastIp);
    d.setCursor(4, 88);
    d.printf("%s %s", lastSev.c_str(), lastAction.c_str());
  } else {
    d.setCursor(4, 72);
    d.print("No threats yet");
  }
}

void setup() {
  auto cfg = M5.config();
  M5.begin(cfg);
  M5.Display.setRotation(1);
  M5.Display.fillScreen(TFT_BLACK);
  M5.Display.setCursor(4, 40);
  M5.Display.print("WiFi connect...");

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000) {
    delay(250);
  }
}

void loop() {
  String mood, statusLine, lastIp, lastSev, lastAction;
  int level = 1, blocked = 0, seen = 0;
  bool ok = fetchStatus(mood, level, blocked, seen, statusLine, lastIp, lastSev, lastAction);
  if (!ok) {
    drawScreen("idle", 0, 0, 0, "CTG unreachable", "", "", "", false);
  } else {
    drawScreen(mood, level, blocked, seen, statusLine, lastIp, lastSev, lastAction, true);
  }
  delay(POLL_MS);
}
