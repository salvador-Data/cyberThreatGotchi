/**
 * Hacker Planet LLC — Kickstarter configuration (publishable only)
 *
 * Safe to commit. No secrets.
 * After you create and approve your project on kickstarter.com, replace
 * kickstarterProjectUrl with the exact URL Kickstarter assigns (slug may differ).
 */
window.HPL_KICKSTARTER = {
  /**
   * Live Kickstarter project URL.
   * Placeholder slug until project exists: hackerplanet/cyberthreatgotchi-edge-ips-tamagotchi
   */
  kickstarterProjectUrl:
    "https://www.kickstarter.com/projects/hackerplanet/cyberthreatgotchi-edge-ips-tamagotchi",

  /** Slug substring while project is still a draft / not yet approved on kickstarter.com */
  placeholderSlug: "hackerplanet/cyberthreatgotchi-edge-ips-tamagotchi",

  /** UTM params appended to every outbound campaign link from hackerplanet.dev */
  utm: {
    source: "hackerplanet",
    medium: "site",
    campaign: "cta",
  },

  /**
   * Shop stripeKey values that map to Kickstarter reward tiers when the campaign is live.
   * Checkout on hackerplanet.dev redirects to kickstarter.com — pledges are never Stripe here.
   */
  kickstarterSkus: [
    "digital",
    "coreKit",
    "fieldPack",
    "crackbotBench",
    "remotePossibility",
    "bleBot",
  ],
};
