/**
 * Hacker Planet LLC - payment configuration
 *
 * Copy to payments.config.js and fill in my live links from Stripe / PayPal dashboards.
 * See docs/PAYMENTS.md and docs/PAYMENTS_RECURRING.md for setup steps.
 *
 * Safe to commit: Payment Link URLs, Customer Portal URL, and PayPal client IDs are publishable.
 * Never put Stripe secret keys or PayPal secrets in this file.
 */
window.HPL_PAYMENTS = {
  /** Set false when links below are configured */
  demoMode: true,

  /**
   * Stripe Customer Portal (Dashboard -> Settings -> Billing -> Customer portal).
   * Returning subscribers manage cards, invoices, and cancellations here - not on our site.
   */
  stripeCustomerPortal: "",

  /** Stripe Payment Links - cards, debit, Apple Pay, Google Pay, Link */
  /**
   * Stripe Payment Link metadata (Dashboard -> Payment link -> Metadata).
   * Required for auto-fulfillment via checkout.session.completed:
   *   Key: stripe_key   Value: same as the property name below (e.g. dsMeshtasticHeltec).
   * See docs/STRIPE_FULFILLMENT_METADATA.md for my Stripe Dashboard checklist.
   */
  stripePaymentLinkMetadataExamples: {
    dsMeshtasticHeltec: { stripe_key: "dsMeshtasticHeltec" },
    dsMeshtasticTBeam: { stripe_key: "dsMeshtasticTBeam" },
    dsMeshtasticRAK: { stripe_key: "dsMeshtasticRAK" },
    dsMeshtasticCase: { stripe_key: "dsMeshtasticCase" },
    dsKaliNetHunter: { stripe_key: "dsKaliNetHunter" },
    dsWiringLab: { stripe_key: "dsWiringLab" },
    dsRaspberryPi5: { stripe_key: "dsRaspberryPi5" },
    dsHackberryZero: { stripe_key: "dsHackberryZero" },
    dsEsp32Cyd: { stripe_key: "dsEsp32Cyd" },
    dsRtlSdrKit: { stripe_key: "dsRtlSdrKit" },
    dsNesdrSmart: { stripe_key: "dsNesdrSmart" },
    dsLanTap: { stripe_key: "dsLanTap" },
    dsThrowingStarKit: { stripe_key: "dsThrowingStarKit" },
    dsEsp32WifiLab: { stripe_key: "dsEsp32WifiLab" },
    dsUsbRubberDucky: { stripe_key: "dsUsbRubberDucky" },
    dsHak5WifiPineapple: { stripe_key: "dsHak5WifiPineapple" },
  },

  stripePaymentLinks: {
    digital: "",
    proMonthly: "",
    proYearly: "",
    mspMonitor: "",
    mspDefend: "",
    mspHarden: "",
    coreKit: "",
    fieldPack: "",
    boostFormulaCod: "",
    codStlPack: "",
    cydStandard: "",
    cydFieldCustom: "",
    crackbotBench: "",
    remotePossibility: "",
    bleBot: "",
    dsPwnagotchi: "",
    dsNetgotchi: "",
    dsNetgotchiPro: "",
    dsNightHunter: "",
    dsMeshtasticTBeam: "",
    dsMeshtasticHeltec: "",
    dsMeshtasticRAK: "",
    dsMeshtasticCase: "",
    dsHackberryZero: "",
    dsHackberryPi5: "",
    dsHackberryCM5: "",
    dsMarauderGps: "",
    dsMarauderBatteryMod: "",
    dsMarauderKoko: "",
    dsRaspberryPi5: "",
    dsOrangePi5: "",
    dsBananaPiR3: "",
    dsEsp32Cyd: "",
    dsWiringLab: "",
    dsKaliNetHunter: "",
    dsRtlSdrKit: "",
    dsNesdrSmart: "",
    dsLanTap: "",
    dsThrowingStarKit: "",
    dsEsp32WifiLab: "",
    dsUsbRubberDucky: "",
    dsHak5WifiPineapple: "",
  },

  /**
   * PayPal JavaScript SDK client ID (live or sandbox).
   * Enables PayPal + PayPal Credit + Venmo buttons on-page.
   * Create at https://developer.paypal.com/dashboard/applications
   */
  paypal: {
    clientId: "",
    currency: "USD",
  },

  /**
   * PayPal subscription plan IDs (Dashboard -> Subscriptions -> Plans).
   * Optional - when set, shop renders hosted PayPal subscription buttons.
   */
  paypalSubscriptions: {
    proMonthly: { planId: "" },
    proYearly: { planId: "" },
    mspMonitor: { planId: "" },
    mspDefend: { planId: "" },
    mspHarden: { planId: "" },
  },

  /** PayPal.Me or hosted payment links (fallback without SDK) */
  paypalMe: {
    username: "",
  },

  /** Cash App $Cashtag (no $ prefix) - opens Cash App pay flow */
  cashapp: {
    cashtag: "",
  },

  /** Venmo username (no @) - direct pay links + PayPal Venmo funding */
  venmo: {
    username: "",
  },

  supportEmail: "salvadorData@proton.me",

  /**
   * Kickstarter project URL - also in js/kickstarter.config.js (authoritative for kickstarter.html).
   * Replace placeholder after creating project on kickstarter.com.
   */
  kickstarterProjectUrl:
    "https://www.kickstarter.com/projects/hackerplanet/cyberthreatgotchi-edge-ips-tamagotchi",

  /** Returning customer localStorage (browser only - never PAN). */
  returningCustomer: {
    maxAgeDays: 365,
  },
};
