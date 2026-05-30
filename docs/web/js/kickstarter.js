/** Hacker Planet LLC — Kickstarter campaign URL + CTA wiring (UTM-safe redirects) */

(function () {
  var NOTIFY_MAIL =
    "mailto:salvadorData@proton.me?subject=Kickstarter%20notify%20me";

  function cfg() {
    return window.HPL_KICKSTARTER || {};
  }

  function projectUrlRaw() {
    return String(cfg().kickstarterProjectUrl || "").trim();
  }

  function placeholderSlug() {
    return String(cfg().placeholderSlug || "hackerplanet/cyberthreatgotchi-edge-ips-tamagotchi");
  }

  function isCampaignLive(url) {
    url = url || projectUrlRaw();
    if (!url || url.indexOf("kickstarter.com/projects/") === -1) return false;
    return url.indexOf(placeholderSlug()) === -1;
  }

  function buildCampaignUrl(opts) {
    var base = projectUrlRaw();
    if (!base) return "";
    opts = opts || {};
    var utm = cfg().utm || {};
    var params = new URLSearchParams();
    params.set("utm_source", opts.source || utm.source || "hackerplanet");
    params.set("utm_medium", opts.medium || utm.medium || "site");
    params.set("utm_campaign", opts.campaign || utm.campaign || "cta");
    if (opts.content) params.set("utm_content", opts.content);
    var sep = base.indexOf("?") >= 0 ? "&" : "?";
    return base + sep + params.toString();
  }

  function redirectToCampaign(opts) {
    var url = buildCampaignUrl(opts);
    if (!url) {
      window.location.href = "kickstarter.html";
      return;
    }
    window.location.href = url;
  }

  function openCampaign(opts) {
    var url = buildCampaignUrl(opts);
    if (!url) return false;
    window.open(url, "_blank", "noopener,noreferrer");
    return true;
  }

  function isKickstarterSku(stripeKey) {
    if (!stripeKey) return false;
    var skus = cfg().kickstarterSkus || [];
    return skus.indexOf(stripeKey) >= 0;
  }

  function setText(id, text) {
    var el = document.getElementById(id);
    if (el) el.textContent = text;
  }

  function wireAnchor(el, url, live, labelLive, labelPreview) {
    if (!el) return;
    if (live && url) {
      el.textContent = labelLive;
      el.href = buildCampaignUrl({ content: el.id || "cta" });
      el.target = "_blank";
      el.rel = "noopener noreferrer";
    } else {
      el.textContent = labelPreview;
      el.href = NOTIFY_MAIL;
      el.removeAttribute("target");
      el.removeAttribute("rel");
    }
  }

  function wireHero(url, live) {
    var badge = document.getElementById("ks-live-badge");
    var label = document.getElementById("ks-hero-label");
    var primary = document.getElementById("ks-hero-primary");
    var secondary = document.getElementById("ks-hero-secondary");
    var banner = document.getElementById("ks-prelaunch-banner");
    var footerPrimary = document.getElementById("ks-footer-primary");
    var paymentNote = document.getElementById("ks-payment-live-note");

    if (live) {
      if (badge) badge.hidden = false;
      if (label) label.textContent = "Live on Kickstarter | Philadelphia PA";
      wireAnchor(
        primary,
        url,
        true,
        "Back this project on Kickstarter",
        "Notify me at launch"
      );
      wireAnchor(
        secondary,
        url,
        true,
        "Choose your reward tier",
        "Preview reward tiers"
      );
      wireAnchor(
        footerPrimary,
        url,
        true,
        "Back this project on Kickstarter",
        "Email notify me"
      );
      if (banner) banner.hidden = true;
      if (paymentNote) paymentNote.hidden = false;
    } else {
      if (badge) badge.hidden = true;
      if (label) label.textContent = "Kickstarter preview | Philadelphia PA";
      wireAnchor(primary, url, false, "", "Notify me at launch");
      if (secondary) {
        secondary.textContent = "Preview reward tiers";
        secondary.href = "#ks-rewards";
        secondary.removeAttribute("target");
        secondary.removeAttribute("rel");
      }
      wireAnchor(footerPrimary, url, false, "", "Email notify me");
      if (banner) banner.hidden = false;
      if (paymentNote) paymentNote.hidden = true;
    }

    document.querySelectorAll("[data-ks-tier-cta]").forEach(function (btn) {
      if (live && url) {
        btn.textContent = "Select on Kickstarter";
        btn.href = buildCampaignUrl({ content: btn.getAttribute("data-ks-tier-cta") || "tier" });
        btn.target = "_blank";
        btn.rel = "noopener noreferrer";
        btn.classList.remove("btn-ghost");
        btn.classList.add("btn-primary");
      } else {
        btn.textContent = "Notify me for this tier";
        btn.href = NOTIFY_MAIL;
        btn.removeAttribute("target");
        btn.removeAttribute("rel");
      }
    });
  }

  function wireShopKickstarterBar() {
    var bar = document.getElementById("shop-kickstarter-bar");
    if (!bar) return;
    var url = projectUrlRaw();
    var live = isCampaignLive(url);
    var btn = document.getElementById("shop-kickstarter-primary");
    var note = document.getElementById("shop-kickstarter-note");
    if (live && btn) {
      bar.classList.remove("prelaunch-banner");
      bar.classList.add("kickstarter-live-banner");
      btn.textContent = "Back on Kickstarter";
      btn.href = buildCampaignUrl({ medium: "site", campaign: "shop_banner" });
      btn.target = "_blank";
      btn.rel = "noopener noreferrer";
      if (note) {
        note.textContent =
          "Pledge on kickstarter.com — card data never touches hackerplanet.dev. Direct shop checkout stays available for non-campaign SKUs.";
      }
    } else if (btn) {
      btn.textContent = "Kickstarter preview & reward tiers";
      btn.href = "kickstarter.html";
      btn.removeAttribute("target");
      btn.removeAttribute("rel");
    }
  }

  function renderKickstarterCheckout(host, stripeKey) {
    if (!host) return false;
    host.innerHTML = "";
    var url = projectUrlRaw();
    var live = isCampaignLive(url);
    var previewLink = "kickstarter.html";

    if (live && isKickstarterSku(stripeKey)) {
      var ksBtn = document.createElement("button");
      ksBtn.type = "button";
      ksBtn.className = "pay-btn pay-btn-kickstarter btn btn-primary";
      ksBtn.textContent = "Back on Kickstarter";
      ksBtn.addEventListener("click", function () {
        redirectToCampaign({ medium: "site", campaign: "shop_sku", content: stripeKey });
      });
      host.appendChild(ksBtn);
      var note = document.createElement("p");
      note.className = "pay-kickstarter-note";
      note.textContent =
        "Pledge this tier on kickstarter.com. Payment is handled by Kickstarter — not Stripe on this site.";
      host.appendChild(note);
      return true;
    }

    if (isKickstarterSku(stripeKey)) {
      var previewBtn = document.createElement("a");
      previewBtn.className = "btn btn-ghost";
      previewBtn.href = previewLink;
      previewBtn.textContent = "Kickstarter early-bird tiers";
      host.appendChild(previewBtn);
      var pre = document.createElement("p");
      pre.className = "pay-kickstarter-note";
      pre.innerHTML =
        'Campaign preview — email <a href="' +
        NOTIFY_MAIL +
        '">salvadorData@proton.me</a> or visit <a href="kickstarter.html">reward tiers</a>.';
      host.appendChild(pre);
    }
    return false;
  }

  function initKickstarterPage() {
    if (!document.getElementById("ks-hero-primary")) return;
    var url = projectUrlRaw();
    wireHero(url, isCampaignLive(url));
  }

  function initShopKickstarter() {
    wireShopKickstarterBar();
  }

  window.HPL_KICKSTARTER_buildCampaignUrl = buildCampaignUrl;
  window.HPL_KICKSTARTER_redirect = redirectToCampaign;
  window.HPL_KICKSTARTER_open = openCampaign;
  window.HPL_KICKSTARTER_isLive = isCampaignLive;
  window.HPL_KICKSTARTER_isSku = isKickstarterSku;
  window.HPL_KICKSTARTER_renderCheckout = renderKickstarterCheckout;

  document.addEventListener("DOMContentLoaded", function () {
    initKickstarterPage();
    initShopKickstarter();
  });
})();
