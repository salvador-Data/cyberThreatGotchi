/**
 * Hacker Planet LLC — shipping & tax configuration
 * Estimates only — enable Stripe Tax at checkout for live compliance.
 */
window.HPL_SHIPPING = {
  /** Internal fulfillment only — never render line1 on public HTML. */
  shipFrom: {
    company: "Hacker Planet LLC",
    line1: "664 Walker Street",
    city: "Philadelphia",
    state: "PA",
    zip: "11135",
    country: "US",
  },
  /** Origin for calculator zones; publicLabel is the only field shown on-site. */
  origin: {
    line1: "664 Walker Street",
    city: "Philadelphia",
    state: "PA",
    zip: "11135",
    country: "US",
    publicLabel: "Philadelphia, PA",
  },
  disclaimer:
    "Shipping and tax shown are estimates. Final amounts are confirmed at checkout. " +
    "Hacker Planet LLC is registered in Pennsylvania.",
  /** States where HPL collects sales tax (expand as you register elsewhere). */
  nexusStates: ["PA"],
  /** PA state rate; Philadelphia +2% local on tangible goods (191xx ZIPs). */
  paStateRate: 0.06,
  phillyLocalRate: 0.02,
  phillyZipPrefixes: ["191"],
  /** Flat rates when ship-to state is in nexus (non-PA uses state rate below). */
  stateTaxRates: {
    PA: 0.06,
    NJ: 0.06625,
    DE: 0,
    NY: 0.04,
    MD: 0.06,
    OH: 0.0575,
    VA: 0.053,
    WV: 0.06,
    CT: 0.0635,
    DC: 0.06,
  },
  dropship: {
    shippingIncluded: true,
    label: "Shipping included",
    leadTime: "5–14 business days",
  },
  digital: {
    shipping: 0,
    label: "Digital delivery — no shipping",
    taxableInPa: true,
  },
  /** Direct ship from Philadelphia — zone flat rates (USD). */
  directZones: [
    { id: "near", label: "PA · NJ · DE · NY", states: ["PA", "NJ", "DE", "NY"], base: 8.95 },
    { id: "mid", label: "Mid-Atlantic & Midwest", states: ["MD", "VA", "WV", "OH", "NC", "SC", "GA", "FL", "MI", "IN", "KY", "TN", "IL", "WI", "MN", "IA", "MO"], base: 11.95 },
    { id: "central", label: "South & Plains", states: ["AL", "MS", "LA", "AR", "OK", "KS", "NE", "TX", "SD", "ND", "CO", "NM"], base: 14.95 },
    { id: "west", label: "West & Pacific", states: ["MT", "WY", "ID", "UT", "AZ", "NV", "CA", "OR", "WA", "AK", "HI"], base: 17.95 },
  ],
  defaultDirectZone: { base: 14.95 },
  weightSurchargePer8Oz: 2.5,
  freeShippingDigital: true,
  products: {
    sabretoAkachi: { fulfillment: "direct", weightOz: 28, category: "hardware" },
    crackbotCyd: { fulfillment: "direct", weightOz: 22, category: "hardware" },
    coreKit: { fulfillment: "direct", weightOz: 48, category: "hardware" },
    fieldPack: { fulfillment: "direct", weightOz: 64, category: "hardware" },
    boostFormulaCod: { fulfillment: "direct", weightOz: 12, category: "hardware" },
    marauderCustom175: { fulfillment: "direct", weightOz: 26, category: "hardware" },
    digital: { fulfillment: "digital", weightOz: 0, category: "digital" },
    codStlPack: { fulfillment: "digital", weightOz: 0, category: "digital" },
    proMonthly: { fulfillment: "digital", weightOz: 0, category: "service" },
    proYearly: { fulfillment: "digital", weightOz: 0, category: "service" },
    dsPwnagotchi: { fulfillment: "dropship", weightOz: 0, category: "hardware" },
    dsNetgotchi: { fulfillment: "dropship", weightOz: 0, category: "hardware" },
    dsNetgotchiPro: { fulfillment: "dropship", weightOz: 0, category: "hardware" },
    dsNightHunter: { fulfillment: "dropship", weightOz: 0, category: "hardware" },
    dsMeshtasticTBeam: { fulfillment: "dropship", weightOz: 0, category: "hardware" },
    dsMeshtasticHeltec: { fulfillment: "dropship", weightOz: 0, category: "hardware" },
    dsMeshtasticRAK: { fulfillment: "dropship", weightOz: 0, category: "hardware" },
    dsMeshtasticCase: { fulfillment: "dropship", weightOz: 0, category: "hardware" },
    dsHackberryZero: { fulfillment: "dropship", weightOz: 0, category: "hardware" },
    dsHackberryPi5: { fulfillment: "dropship", weightOz: 0, category: "hardware" },
    dsHackberryCM5: { fulfillment: "dropship", weightOz: 0, category: "hardware" },
    dsMarauderGps: { fulfillment: "dropship", weightOz: 0, category: "hardware" },
    dsMarauderBatteryMod: { fulfillment: "dropship", weightOz: 0, category: "hardware" },
    dsMarauderKoko: { fulfillment: "dropship", weightOz: 0, category: "hardware" },
    dsRaspberryPi5: { fulfillment: "dropship", weightOz: 0, category: "hardware" },
    dsOrangePi5: { fulfillment: "dropship", weightOz: 0, category: "hardware" },
    dsBananaPiR3: { fulfillment: "dropship", weightOz: 0, category: "hardware" },
    dsEsp32Cyd: { fulfillment: "dropship", weightOz: 0, category: "hardware" },
  },
};
