/** Live config - Andy: paste Stripe Payment Link URLs here (publishable, safe to commit).
 *
 * GO LIVE (credit card checkout):
 * 1. Stripe Dashboard -> Developers -> API keys -> copy Secret key (sk_test_ or sk_live_).
 * 2. PowerShell (one command per block):
 *    cd C:\Users\Owner\Projects\cyberThreatGotchi
 *    $env:CTG_STRIPE_SECRET_KEY = "sk_test_..."
 *    python scripts/stripe_bootstrap_payment_links.py --write-config --go-live
 * 3. Or manual: create Payment Links in Dashboard, paste https://buy.stripe.com/... below.
 * 4. Apple Pay / Google Pay: enable in Stripe Dashboard -> Settings -> Payment methods (auto on Payment Links).
 * 5. PayPal / Venmo / Cash App (hosted — no secrets in this file):
 *    paypal.clientId OR paypalMe.username | venmo.username | cashapp.cashtag
 * 6. When every stripePaymentLinks key is non-empty, demoMode auto-flips to false below.
 * 7. Sync site: python scripts/sync_website_to_docs.py
 * 8. Verify: python scripts/check_payments.py  (exit 0 = live)
 *
 * Never put sk_ secret keys in this file. See docs/STRIPE_ADD_LINKS.md
 */
window.HPL_PAYMENTS = {
  /** Set false when all stripePaymentLinks URLs are filled (auto below when complete). */
  demoMode: true,
  stripeCustomerPortal: "",
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
  paypal: { clientId: "", currency: "USD" },
  paypalSubscriptions: {
    proMonthly: { planId: "" },
    proYearly: { planId: "" },
    mspMonitor: { planId: "" },
    mspDefend: { planId: "" },
    mspHarden: { planId: "" },
  },
  paypalMe: { username: "" },
  cashapp: { cashtag: "" },
  venmo: { username: "" },
  supportEmail: "salvadorData@proton.me",
};

(function applyStripeLiveMode() {
  var p = window.HPL_PAYMENTS;
  if (!p || !p.stripePaymentLinks) return;
  var keys = Object.keys(p.stripePaymentLinks);
  var filled = keys.filter(function (k) {
    return String(p.stripePaymentLinks[k] || "").trim().indexOf("https://buy.stripe.com/") === 0;
  });
  p.stripeLinksConfigured = filled.length;
  var altConfigured =
    !!(p.paypal && p.paypal.clientId) ||
    !!(p.paypalMe && p.paypalMe.username) ||
    !!(p.cashapp && p.cashapp.cashtag) ||
    !!(p.venmo && p.venmo.username);
  p.altPaymentsConfigured = altConfigured;
  if (filled.length === keys.length && keys.length > 0) {
    p.demoMode = false;
  }
})();
