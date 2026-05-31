/**
 * Hacker Planet LLC - Cardputer / ecosystem firmware download catalog
 * URLs use GitHub releases/latest/download/<asset> when prebuilt .bin assets ship.
 */
window.HPL_FIRMWARE = {
  intro:
    "One place to grab M5 Cardputer firmware for the Hacker Planet ecosystem. Philadelphia SKUs ship pre-flashed.",
  steps: [
    {
      num: "1",
      title: "Flash M5 OS",
      detail:
        "Clone M5_OS-Cardputer to Programs\\Hacker Planet LLC\\M5_OS-Cardputer (repo root has platformio.ini - no platformio\\ subfolder). Build env m5stack-cardputer, then USB upload.",
    },
    {
      num: "2",
      title: "Download app .bin",
      detail: "Grab Remote Possibility or BLE Bot below, or pull from the M5 OS Wi-Fi manifest.",
    },
    {
      num: "3",
      title: "Verify & flash",
      detail: "Match SHA-256 in manifest.example.json before OTA or SD sideload.",
    },
  ],
  trustLine:
    "Verify every package SHA-256 digest in the M5 OS manifest before download or flash.",
  manifestUrl:
    "https://github.com/salvador-Data/M5_OS-Cardputer/blob/main/data/manifest.example.json",
  securityUrl: "https://github.com/salvador-Data/M5_OS-Cardputer/blob/main/SECURITY.md",
  cardputerDocsUrl: "cardputer.html#firmware",
  packages: [
    {
      id: "m5-os",
      name: "M5 OS Cardputer",
      device: "M5 Cardputer",
      role: "Launcher, SD catalog, OTA hub",
      asset: "Tagged release .bin",
      downloadUrl: "",
      releasesUrl: "https://github.com/salvador-Data/M5_OS-Cardputer/releases",
      repoUrl: "https://github.com/salvador-Data/M5_OS-Cardputer",
      sdName: "Recovery flash via USB",
      accent: "m5",
      ctaLabel: "M5 OS releases",
    },
    {
      id: "remote-possibility",
      name: "Remote Possibility",
      device: "M5 Cardputer",
      role: "Universal IR / RF remote",
      asset: "firmware.bin",
      downloadUrl:
        "https://github.com/salvador-Data/Remote-Possibility/releases/latest/download/firmware.bin",
      releasesUrl: "https://github.com/salvador-Data/Remote-Possibility/releases",
      repoUrl: "https://github.com/salvador-Data/Remote-Possibility",
      sdName: "remote_possibility.bin",
      accent: "m5",
      ctaLabel: "Download firmware.bin",
    },
    {
      id: "ble-bot",
      name: "BLE Bot",
      device: "M5 Cardputer",
      role: "Authorized BLE lab scout",
      asset: "ble_bot.bin",
      downloadUrl:
        "https://github.com/salvador-Data/BLE-Bot-Cardputer/releases/latest/download/ble_bot.bin",
      releasesUrl: "https://github.com/salvador-Data/BLE-Bot-Cardputer/releases",
      repoUrl: "https://github.com/salvador-Data/BLE-Bot-Cardputer",
      sdName: "ble_bot.bin",
      accent: "m5",
      ctaLabel: "Download ble_bot.bin",
    },
  ],
};
