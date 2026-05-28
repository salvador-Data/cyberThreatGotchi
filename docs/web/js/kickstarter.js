/** Hacker Planet LLC — Kickstarter page CTA wiring */

(function () {
  var PLACEHOLDER_SLUG = "hackerplanet/cyberthreatgotchi-edge-ips-tamagotchi";
  var NOTIFY_MAIL =
    "mailto:salvadorData@proton.me?subject=Kickstarter%20notify%20me";

  function cfg() {
    return window.HPL_KICKSTARTER || {};
  }

  function projectUrl() {
    var url = (cfg().kickstarterProjectUrl || "").trim();
    return url;
  }

  function isLive(url) {
    if (!url) return false;
    return url.indexOf(PLACEHOLDER_SLUG) === -1;
  }

  function setText(id, text) {
    var el = document.getElementById(id);
    if (el) el.textContent = text;
  }

  function wireHero(url, live) {
    var badge = document.getElementById("ks-live-badge");
    var label = document.getElementById("ks-hero-label");
    var primary = document.getElementById("ks-hero-primary");
    var banner = document.getElementById("ks-prelaunch-banner");
    var footerPrimary = document.getElementById("ks-footer-primary");

    if (live) {
      if (badge) badge.hidden = false;
      if (label) label.textContent = "Live on Kickstarter | Philadelphia PA";
      if (primary) {
        primary.textContent = "Back this project on Kickstarter";
        primary.href = url;
        primary.target = "_blank";
        primary.rel = "noopener noreferrer";
      }
      if (footerPrimary) {
        footerPrimary.textContent = "Back this project on Kickstarter";
        footerPrimary.href = url;
        footerPrimary.target = "_blank";
        footerPrimary.rel = "noopener noreferrer";
      }
      if (banner) banner.hidden = true;
    } else {
      if (badge) badge.hidden = true;
      if (label) label.textContent = "Kickstarter preview | Philadelphia PA";
      if (primary) {
        primary.textContent = "Notify me at launch";
        primary.href = NOTIFY_MAIL;
        primary.removeAttribute("target");
        primary.removeAttribute("rel");
      }
      if (footerPrimary) {
        footerPrimary.textContent = "Email notify me";
        footerPrimary.href = NOTIFY_MAIL;
        footerPrimary.removeAttribute("target");
        footerPrimary.removeAttribute("rel");
      }
      if (banner) banner.hidden = false;
    }
  }

  document.addEventListener("DOMContentLoaded", function () {
    var url = projectUrl();
    wireHero(url, isLive(url));
  });
})();
