/**
 * Hacker Planet LLC - returning customer prefill (browser localStorage only).
 * Stores ship-to + email for checkout convenience. Never stores card data.
 */
(function () {
  var STORAGE_KEY = "hpl_customer_prefill_v1";

  function safeParse(raw) {
    try {
      return JSON.parse(raw);
    } catch (e) {
      return null;
    }
  }

  function sanitizeEmail(value) {
    return String(value || "")
      .trim()
      .slice(0, 254);
  }

  function sanitizeText(value, max) {
    return String(value || "")
      .trim()
      .slice(0, max || 120);
  }

  function load() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      var data = safeParse(raw);
      if (!data || typeof data !== "object") return {};
      return {
        email: sanitizeEmail(data.email),
        name: sanitizeText(data.name, 120),
        shipTo: {
          line1: sanitizeText(data.shipTo && data.shipTo.line1, 120),
          city: sanitizeText(data.shipTo && data.shipTo.city, 80),
          state: sanitizeText(data.shipTo && data.shipTo.state, 2).toUpperCase(),
          zip: sanitizeText(data.shipTo && data.shipTo.zip, 10),
        },
        updatedAt: data.updatedAt || "",
      };
    } catch (e) {
      return {};
    }
  }

  function save(data) {
    var payload = {
      email: sanitizeEmail(data && data.email),
      name: sanitizeText(data && data.name, 120),
      shipTo: {
        line1: sanitizeText(data && data.shipTo && data.shipTo.line1, 120),
        city: sanitizeText(data && data.shipTo && data.shipTo.city, 80),
        state: sanitizeText(data && data.shipTo && data.shipTo.state, 2).toUpperCase(),
        zip: sanitizeText(data && data.shipTo && data.shipTo.zip, 10),
      },
      updatedAt: new Date().toISOString(),
    };
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(payload));
    } catch (e) {
      /* quota / private mode */
    }
    return payload;
  }

  function clear() {
    try {
      localStorage.removeItem(STORAGE_KEY);
    } catch (e) {
      /* ignore */
    }
  }

  function appendStripePrefill(url, email) {
    if (!url || !email) return url;
    var sep = url.indexOf("?") >= 0 ? "&" : "?";
    return url + sep + "prefilled_email=" + encodeURIComponent(email);
  }

  window.HPL_customerPrefill = {
    STORAGE_KEY: STORAGE_KEY,
    load: load,
    save: save,
    clear: clear,
    appendStripePrefill: appendStripePrefill,
  };
})();
