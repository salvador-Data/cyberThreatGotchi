/**
 * Hacker Planet LLC - Cardputer / ecosystem firmware download catalog
 * URLs use GitHub releases/latest/download/<asset> when prebuilt .bin assets ship.
 */
window.HPL_FIRMWARE = {
  intro:
    "Flash M5 OS on the Cardputer first, then sideload app packages from this table or via the M5 OS Wi-Fi manifest. " +
    "Philadelphia SKUs ship pre-flashed. Verify SHA-256 digests in the manifest before OTA download.",
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
      asset: "Build from source or tagged release",
      downloadUrl: "",
      releasesUrl: "https://github.com/salvador-Data/M5_OS-Cardputer/releases",
      repoUrl: "https://github.com/salvador-Data/M5_OS-Cardputer",
      sdName: "m5_os (recovery flash)",
      accent: "m5",
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
    },
  ],
};
