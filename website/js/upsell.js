/**
 * Hacker Planet LLC - shop upsell strip ("Often bought together")
 */
(function (global) {
  "use strict";

  function cfg() {
    return global.HPL_UPSELL || { rules: [], productHints: {} };
  }

  function el(tag, cls, html) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (html != null) node.innerHTML = html;
    return node;
  }

  function rulesFor(stripeKey) {
    var rules = cfg().rules || [];
    return rules.filter(function (rule) {
      return rule.when === stripeKey;
    });
  }

  function hintFor(sku) {
    var hints = cfg().productHints || {};
    if (hints[sku]) return hints[sku];
    var pay = global.HPL_PRODUCTS && global.HPL_PRODUCTS[sku];
    if (pay) {
      return {
        name: pay.name || sku,
        priceDisplay: pay.priceDisplay || (pay.price != null ? "$" + pay.price : ""),
        href: "shop.html",
        blurb: pay.desc || "",
      };
    }
    return { name: sku, priceDisplay: "", href: "shop.html", blurb: "" };
  }

  function renderUpsellStrip(stripeKey) {
    var matched = rulesFor(stripeKey);
    if (!matched.length) return null;

    var seen = {};
    var items = [];
    matched.forEach(function (rule) {
      (rule.suggest || []).forEach(function (sku) {
        if (seen[sku]) return;
        seen[sku] = true;
        items.push({ sku: sku, reason: rule.reason || "" });
      });
    });
    if (!items.length) return null;

    var wrap = el("aside", "upsell-strip");
    wrap.setAttribute("aria-label", cfg().label || "Often bought together");
    wrap.appendChild(el("p", "upsell-label", cfg().label || "Often bought together"));

    var grid = el("div", "upsell-grid");
    items.forEach(function (item) {
      var hint = hintFor(item.sku);
      var card = el("a", "upsell-card");
      card.href = hint.href || "shop.html";
      card.innerHTML =
        "<span class=\"upsell-price\">" +
        (hint.priceDisplay || "") +
        "</span>" +
        "<span class=\"upsell-name\">" +
        (hint.name || item.sku) +
        "</span>" +
        (hint.blurb ? "<span class=\"upsell-blurb\">" + hint.blurb + "</span>" : "");
      grid.appendChild(card);
    });
    wrap.appendChild(grid);

    var reason = matched[0].reason;
    if (reason) {
      wrap.appendChild(el("p", "upsell-reason", reason));
    }
    if (cfg().note) {
      wrap.appendChild(el("p", "upsell-note", cfg().note));
    }
    return wrap;
  }

  function attachUpsells(root) {
    if (!root) return;
    var cards = root.querySelectorAll("[data-product], .catalog-card[data-product]");
    if (!cards.length) {
      cards = root.querySelectorAll(".shop-card[data-product], .catalog-card");
    }
    cards.forEach(function (card) {
      var stripeKey =
        card.getAttribute("data-product") ||
        (card.querySelector("[data-product]") && card.querySelector("[data-product]").getAttribute("data-product"));
      if (!stripeKey) {
        var checkout = card.querySelector(".product-checkout[data-product]");
        if (checkout) stripeKey = checkout.getAttribute("data-product");
      }
      if (!stripeKey || card.querySelector(".upsell-strip")) return;
      var strip = renderUpsellStrip(stripeKey);
      if (strip) card.appendChild(strip);
    });
  }

  function initUpsells() {
    attachUpsells(document.getElementById("direct-catalog"));
    attachUpsells(document.getElementById("dropship-catalog"));
  }

  global.HPL_initUpsells = initUpsells;
  global.HPL_renderUpsellStrip = renderUpsellStrip;

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function () {
      setTimeout(initUpsells, 0);
    });
  } else {
    setTimeout(initUpsells, 0);
  }
})(typeof window !== "undefined" ? window : globalThis);
