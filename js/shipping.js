/**
 * Hacker Planet LLC - shipping & tax estimator
 */
(function () {
  var US_STATES = [
    "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", "GA", "HI", "ID", "IL", "IN", "IA",
    "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM",
    "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA",
    "WV", "WI", "WY",
  ];

  function cfg() {
    return window.HPL_SHIPPING || {};
  }

  function money(n) {
    return "$" + (Math.round(n * 100) / 100).toFixed(2);
  }

  function productMeta(id) {
    var c = cfg();
    return (c.products && c.products[id]) || { fulfillment: "dropship", weightOz: 0 };
  }

  function getZone(state) {
    var zones = cfg().directZones || [];
    var upper = (state || "").toUpperCase();
    for (var i = 0; i < zones.length; i++) {
      if (zones[i].states.indexOf(upper) >= 0) return zones[i];
    }
    return cfg().defaultDirectZone || { base: 14.95, label: "US" };
  }

  function isPhillyZip(zip) {
    var prefixes = cfg().phillyZipPrefixes || ["191"];
    var z = (zip || "").trim();
    return prefixes.some(function (p) {
      return z.indexOf(p) === 0;
    });
  }

  function taxRate(state, zip) {
    var upper = (state || "").toUpperCase();
    var nexus = cfg().nexusStates || ["PA"];
    if (nexus.indexOf(upper) < 0) return 0;
    var rates = cfg().stateTaxRates || {};
    var rate = rates[upper] != null ? rates[upper] : cfg().paStateRate || 0.06;
    if (upper === "PA" && isPhillyZip(zip)) {
      rate += cfg().phillyLocalRate || 0.02;
    }
    return rate;
  }

  function directShipping(state, weightOz) {
    var zone = getZone(state);
    var base = zone.base || 14.95;
    var w = weightOz || 16;
    var extra = Math.max(0, Math.ceil((w - 16) / 8));
    var surcharge = extra * (cfg().weightSurchargePer8Oz || 2.5);
    return {
      amount: base + surcharge,
      label: "Direct ship | " + (zone.label || "US") + (surcharge > 0 ? " | weight adj." : ""),
    };
  }

  function estimate(productId, state, zip) {
    var products = window.HPL_PRODUCTS || {};
    var p = products[productId];
    if (!p) return null;

    var meta = productMeta(productId);
    var subtotal = p.price;
    var shipping = 0;
    var shippingLabel = "";
    var fulfillment = meta.fulfillment || "dropship";

    if (fulfillment === "digital") {
      shippingLabel = (cfg().digital && cfg().digital.label) || "Digital delivery";
    } else if (fulfillment === "dropship") {
      shippingLabel =
        (cfg().dropship && cfg().dropship.label) || "Shipping included in partner catalog price";
    } else if (fulfillment === "direct") {
      var ship = directShipping(state, meta.weightOz);
      shipping = ship.amount;
      var originLabel =
        (cfg().origin && cfg().origin.publicLabel) || "Philadelphia, PA";
      shippingLabel = ship.label + " | from " + originLabel;
    }

    var rate = taxRate(state, zip);
    var taxable = subtotal + (fulfillment === "direct" ? shipping : 0);
    var tax = taxable * rate;
    var total = subtotal + shipping + tax;

    return {
      productId: productId,
      name: p.name,
      fulfillment: fulfillment,
      subtotal: subtotal,
      shipping: shipping,
      shippingLabel: shippingLabel,
      taxRate: rate,
      tax: tax,
      total: total,
      state: (state || "").toUpperCase(),
    };
  }

  function el(tag, cls, html) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (html != null) node.innerHTML = html;
    return node;
  }

  function renderCalculator() {
    var host = document.getElementById("shipping-calculator");
    if (!host) return;

    var products = window.HPL_PRODUCTS || {};
    var keys = Object.keys(products).filter(function (k) {
      return products[k].period !== "/month" && products[k].period !== "/year";
    });
    keys.sort(function (a, b) {
      return products[a].name.localeCompare(products[b].name);
    });

    var panel = el("div", "ship-calc-panel reveal");
    panel.appendChild(el("p", "section-label", "Estimator"));
    panel.appendChild(el("h2", "section-title", "Shipping & tax calculator"));
    panel.appendChild(
      el(
        "p",
        "section-sub",
        "Separate logic for <strong>Philadelphia direct ship</strong> (your builds) vs " +
          "<strong>partner fulfillment</strong> (shipping included). Not legal advice - see tax guide."
      )
    );

    var form = el("div", "ship-calc-form");
    var row1 = el("div", "ship-calc-row");

    var prodLabel = el("label", "Product");
    prodLabel.setAttribute("for", "ship-calc-product");
    var prodSelect = el("select", "ship-calc-input");
    prodSelect.id = "ship-calc-product";
    keys.forEach(function (k) {
      var opt = document.createElement("option");
      opt.value = k;
      var meta = productMeta(k);
      var tag =
        meta.fulfillment === "direct"
          ? " [Philly ship]"
          : meta.fulfillment === "digital"
            ? " [digital]"
            : " [partner]";
      opt.textContent = products[k].name + tag + " - " + money(products[k].price);
      prodSelect.appendChild(opt);
    });

    row1.appendChild(prodLabel);
    row1.appendChild(prodSelect);

    var row2 = el("div", "ship-calc-row");
    var stateLabel = el("label", "Ship-to state");
    stateLabel.setAttribute("for", "ship-calc-state");
    var stateSelect = el("select", "ship-calc-input");
    stateSelect.id = "ship-calc-state";
    var empty = document.createElement("option");
    empty.value = "";
    empty.textContent = "Select state...";
    stateSelect.appendChild(empty);
    US_STATES.forEach(function (s) {
      var opt = document.createElement("option");
      opt.value = s;
      opt.textContent = s;
      stateSelect.appendChild(opt);
    });

    var zipLabel = el("label", "ZIP (optional, Philly local tax)");
    zipLabel.setAttribute("for", "ship-calc-zip");
    var zipInput = el("input", "ship-calc-input");
    zipInput.type = "text";
    zipInput.id = "ship-calc-zip";
    zipInput.placeholder = "19107";
    zipInput.maxLength = 10;
    zipInput.inputMode = "numeric";

    row2.appendChild(stateLabel);
    row2.appendChild(stateSelect);
    row2.appendChild(zipLabel);
    row2.appendChild(zipInput);

    form.appendChild(row1);
    form.appendChild(row2);

    var btn = el("button", "btn btn-primary ship-calc-btn", "Calculate total");
    btn.type = "button";
    var result = el("div", "ship-calc-result");
    result.setAttribute("aria-live", "polite");

    btn.addEventListener("click", function () {
      var id = prodSelect.value;
      var state = stateSelect.value;
      var zip = zipInput.value;
      if (!state) {
        result.innerHTML = '<p class="ship-calc-error">Select a ship-to state.</p>';
        return;
      }
      var r = estimate(id, state, zip);
      if (!r) {
        result.innerHTML = '<p class="ship-calc-error">Unknown product.</p>';
        return;
      }
      var fulfill =
        r.fulfillment === "direct"
          ? "Ships from " +
            ((cfg().origin && cfg().origin.publicLabel) || "Philadelphia, PA")
          : r.fulfillment === "digital"
            ? "Digital / no shipping"
            : "Partner fulfillment (shipping included)";

      result.innerHTML =
        '<dl class="ship-calc-breakdown">' +
        "<dt>Fulfillment</dt><dd>" +
        fulfill +
        "</dd>" +
        "<dt>Subtotal</dt><dd>" +
        money(r.subtotal) +
        "</dd>" +
        "<dt>Shipping</dt><dd>" +
        (r.shipping > 0 ? money(r.shipping) : "$0.00") +
        " <span class='muted'>" +
        r.shippingLabel +
        "</span></dd>" +
        "<dt>Est. sales tax (" +
        (r.state || "") +
        (r.taxRate ? " | " + (r.taxRate * 100).toFixed(2) + "%" : "") +
        ")</dt><dd>" +
        money(r.tax) +
        "</dd>" +
        "<dt class='ship-calc-total'>Estimated total</dt><dd class='ship-calc-total'>" +
        money(r.total) +
        "</dd>" +
        "</dl>" +
        "<p class='ship-calc-disclaimer'>" +
        (cfg().disclaimer || "") +
        "</p>";
    });

    panel.appendChild(form);
    panel.appendChild(btn);
    panel.appendChild(result);
    host.appendChild(panel);

    window.HPL_preselectCalculator = function (productId) {
      if (products[productId]) prodSelect.value = productId;
      host.scrollIntoView({ behavior: "smooth", block: "start" });
      if (stateSelect.value) btn.click();
    };

    document.querySelectorAll("[data-estimate]").forEach(function (el) {
      el.addEventListener("click", function () {
        window.HPL_preselectCalculator(el.getAttribute("data-estimate"));
      });
    });
  }

  window.HPL_estimateShipping = estimate;
  window.HPL_initShippingCalculator = renderCalculator;

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", renderCalculator);
  } else {
    renderCalculator();
  }
})();
