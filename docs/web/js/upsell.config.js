/**
 * Hacker Planet LLC - shop upsell rules (Often bought together)
 * Margins aligned to eBay supplier floor + Philly assembly / curation value.
 */
window.HPL_UPSELL = {
  label: "Often bought together",
  note: "Curated partner hardware ships separately (5-14 business days).",
  rules: [
    {
      when: "coreKit",
      suggest: ["fieldPack", "proYearly", "dsRtlSdrKit", "dsLanTap"],
      reason: "Desk + pocket bundle, Pro feed, RF spectrum lab, and passive tap for edge validation.",
    },
    {
      when: "fieldPack",
      suggest: ["proYearly", "dsRtlSdrKit"],
      reason: "Pro feed plus receive-only SDR for RF visibility alongside field Cardputer.",
    },
    {
      when: "cydStandard",
      suggest: ["dsWiringLab"],
      reason: "Breadboard + jumpers for CYD, Pi, and ESP32 lab bring-up.",
    },
    {
      when: "cydFieldCustom",
      suggest: ["dsWiringLab", "dsMarauderBatteryMod"],
      reason: "Bench wiring plus GPS/battery mod parts for wardrive builds.",
    },
    {
      when: "dsEsp32Cyd",
      suggest: ["dsWiringLab", "dsMarauderKoko"],
      reason: "Prototype on breadboard, then flash Marauder on your own Huzzah32.",
    },
    {
      when: "dsMeshtasticHeltec",
      suggest: ["dsMeshtasticCase"],
      reason: "Field case matched to Heltec V3 board fit.",
    },
    {
      when: "dsMeshtasticTBeam",
      suggest: ["dsMeshtasticCase"],
      reason: "Printed enclosure for T-Beam backpack nodes.",
    },
    {
      when: "dsMeshtasticRAK",
      suggest: ["dsMeshtasticCase"],
      reason: "Protect WisBlock base in the field.",
    },
    {
      when: "dsPwnagotchi",
      suggest: ["dsNetgotchi"],
      reason: "Pair offensive wardrive pod with defensive Netgotchi honeypot.",
    },
    {
      when: "crackbotBench",
      suggest: ["dsRtlSdrKit", "dsLanTap"],
      reason: "SDR sidecar and passive tap for Jetson bench lab visibility.",
    },
    {
      when: "dsRtlSdrKit",
      suggest: ["dsLanTap", "dsNesdrSmart"],
      reason: "Pair spectrum monitoring with inline Ethernet capture.",
    },
    {
      when: "dsRaspberryPi5",
      suggest: ["dsWiringLab"],
      reason: "Homelab IDS bench wiring for Pi 5 bring-up.",
    },
  ],
  productHints: {
    fieldPack: {
      name: "Field Pack",
      priceDisplay: "$279",
      href: "shop.html#fieldPack",
      blurb: "Core kit + M5 Cardputer bundle",
    },
    proYearly: {
      name: "Pro Yearly",
      priceDisplay: "$99/yr",
      href: "shop.html#pro-feed",
      blurb: "CTG Pro threat feed API",
    },
    proMonthly: {
      name: "Pro Monthly",
      priceDisplay: "$9/mo",
      href: "shop.html#pro-feed",
      blurb: "CTG Pro threat feed API",
    },
    dsWiringLab: {
      name: "Breadboard + jumper lab kit",
      priceDisplay: "$22",
      href: "shop.html#catalog-sbc-hacker",
      blurb: "Partner fulfillment | lab essentials",
    },
    dsMarauderBatteryMod: {
      name: "CYD battery + GPS mod kit",
      priceDisplay: "$59",
      href: "shop.html#catalog-marauder-wifi",
      blurb: "Partner fulfillment | Biscuit Shop mod",
    },
    dsMarauderKoko: {
      name: "Official Marauder Kit (Koko PCB)",
      priceDisplay: "$89",
      href: "shop.html#catalog-marauder-wifi",
      blurb: "Partner fulfillment | you supply Huzzah32",
    },
    dsMeshtasticCase: {
      name: "Meshtastic 3D-printed field case",
      priceDisplay: "$34",
      href: "shop.html#catalog-meshtastic",
      blurb: "Partner fulfillment | board-fit case",
    },
    dsNetgotchi: {
      name: "Netgotchi defensive guardian",
      priceDisplay: "$99",
      href: "shop.html#catalog-gotchi-pods",
      blurb: "Partner fulfillment | honeypot sibling",
    },
    dsRtlSdrKit: {
      name: "RTL-SDR Blog V3 starter kit",
      priceDisplay: "$99",
      href: "shop.html#catalog-rf-network-lab",
      blurb: "Partner fulfillment | receive-only SDR lab",
    },
    dsLanTap: {
      name: "Throwing Star LAN Tap Pro",
      priceDisplay: "$59",
      href: "shop.html#catalog-rf-network-lab",
      blurb: "Partner fulfillment | passive Ethernet tap",
    },
    dsNesdrSmart: {
      name: "NESDR SMArt v5 bundle",
      priceDisplay: "$65",
      href: "shop.html#catalog-rf-network-lab",
      blurb: "Partner fulfillment | budget RTL-SDR",
    },
  },
};
