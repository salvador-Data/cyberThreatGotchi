/**
 * Hacker Planet LLC — checkout buttons
 * Stripe (cards, debit, Apple Pay) · PayPal · Venmo · Cash App
 */

(function () {
  var PRODUCTS = {
    digital: {
      id: "digital",
      name: "Digital Pack",
      price: 15,
      period: "one-time",
      desc: "Repo access, STL zip, sprites, release assets",
      stripeKey: "digital",
    },
    proMonthly: {
      id: "proMonthly",
      name: "CTG Pro Feed",
      price: 9,
      period: "/month",
      desc: "Pro signatures, YARA, hash packs via API key",
      stripeKey: "proMonthly",
    },
    proYearly: {
      id: "proYearly",
      name: "CTG Pro Feed",
      price: 99,
      period: "/year",
      desc: "Pro feed — save vs monthly",
      stripeKey: "proYearly",
    },
    coreKit: {
      id: "coreKit",
      name: "Cipherhorn Core Kit",
      price: 169,
      period: "one-time",
      desc: "BPI-R3 Mini + e-ink + enclosure + SD + PSU",
      stripeKey: "coreKit",
    },
    fieldPack: {
      id: "fieldPack",
      name: "Field Pack",
      price: 219,
      period: "one-time",
      desc: "Core kit + M5 Cardputer + quick-start guide",
      stripeKey: "fieldPack",
    },
  };

  function cfg() {
    return window.HPL_PAYMENTS || {};
  }

  function stripeLink(key) {
    var links = cfg().stripePaymentLinks || {};
    return (links[key] || "").trim();
  }

  function cashAppUrl(amount, note) {
    var tag = (cfg().cashapp || {}).cashtag || "";
    if (!tag) return "";
    var base = "https://cash.app/$" + encodeURIComponent(tag.replace(/^\$/, ""));
    if (amount) base += "/" + amount;
    return base;
  }

  function venmoUrl(amount, note) {
    var user = (cfg().venmo || {}).username || "";
    if (!user) return "";
    var params = new URLSearchParams({
      audience: "private",
      amount: String(amount),
      note: note || "Hacker Planet LLC",
      recipients: user.replace(/^@/, ""),
    });
    return "https://account.venmo.com/pay?" + params.toString();
  }

  function paypalMeUrl(amount) {
    var user = (cfg().paypalMe || {}).username || "";
    if (!user) return "";
    return "https://paypal.me/" + encodeURIComponent(user) + "/" + amount;
  }

  function el(tag, cls, html) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (html != null) node.innerHTML = html;
    return node;
  }

  function payBtn(label, href, variant, icon) {
    var a = el("a", "pay-btn pay-btn-" + (variant || "default"));
    a.href = href;
    a.target = "_blank";
    a.rel = "noopener noreferrer";
    a.innerHTML = (icon ? '<span class="pay-icon">' + icon + "</span>" : "") + label;
    return a;
  }

  function renderProductPayments(container, product) {
    container.innerHTML = "";
    var c = cfg();
    var demo = c.demoMode !== false;
    var hasStripe = !!stripeLink(product.stripeKey);
    var hasPayPalMe = !!(c.paypalMe && c.paypalMe.username);
    var hasCash = !!(c.cashapp && c.cashapp.cashtag);
    var hasVenmo = !!(c.venmo && c.venmo.username);
    var hasPayPalSdk = !!(c.paypal && c.paypal.clientId);

    var methods = el("div", "pay-methods");

    if (hasStripe) {
      methods.appendChild(
        payBtn("Card · Debit · Apple Pay", stripeLink(product.stripeKey), "stripe", "💳")
      );
    } else if (demo) {
      methods.appendChild(el("span", "pay-placeholder", "Stripe link — see docs/PAYMENTS.md"));
    }

    if (hasPayPalMe) {
      methods.appendChild(
        payBtn("PayPal", paypalMeUrl(product.price), "paypal", "🅿️")
      );
    }

    if (hasVenmo) {
      methods.appendChild(
        payBtn("Venmo", venmoUrl(product.price, product.name), "venmo", "📱")
      );
    }

    if (hasCash) {
      var ca = cashAppUrl(product.price, product.name);
      if (ca) methods.appendChild(payBtn("Cash App", ca, "cashapp", "💵"));
    }

    container.appendChild(methods);

    if (hasPayPalSdk) {
      var sdkHost = el("div", "paypal-sdk-host");
      sdkHost.id = "paypal-" + product.id;
      sdkHost.dataset.amount = String(product.price);
      sdkHost.dataset.name = product.name;
      container.appendChild(sdkHost);
    }

    if (demo && !hasStripe && !hasPayPalMe && !hasVenmo && !hasCash && !hasPayPalSdk) {
      container.appendChild(
        el(
          "p",
          "pay-demo-note",
          'Checkout is in <strong>demo mode</strong>. Configure <code>website/js/payments.config.js</code> — ' +
            '<a href="https://github.com/salvador-Data/cyberThreatGotchi/blob/main/docs/PAYMENTS.md" target="_blank" rel="noopener">setup guide ↗</a>'
        )
      );
    }
  }

  function loadPayPalSdk(callback) {
    var c = cfg().paypal || {};
    if (!c.clientId) {
      callback(false);
      return;
    }
    if (window.paypal) {
      callback(true);
      return;
    }
    var s = document.createElement("script");
    s.src =
      "https://www.paypal.com/sdk/js?client-id=" +
      encodeURIComponent(c.clientId) +
      "&currency=" +
      encodeURIComponent(c.currency || "USD") +
      "&enable-funding=venmo,paylater&disable-funding=credit";
    s.onload = function () {
      callback(true);
    };
    s.onerror = function () {
      callback(false);
    };
    document.head.appendChild(s);
  }

  function renderPayPalButtons() {
    if (!window.paypal) return;
    document.querySelectorAll(".paypal-sdk-host").forEach(function (host) {
      var amount = host.dataset.amount;
      var name = host.dataset.name || "Hacker Planet LLC";
      window.paypal
        .Buttons({
          fundingSource: window.paypal.FUNDING.PAYPAL,
          createOrder: function (data, actions) {
            return actions.order.create({
              purchase_units: [
                {
                  amount: { value: amount, currency_code: cfg().paypal.currency || "USD" },
                  description: name,
                },
              ],
            });
          },
          onApprove: function (data, actions) {
            return actions.order.capture();
          },
        })
        .render(host);

      if (window.paypal.FUNDING.VENMO) {
        var venmoHost = document.createElement("div");
        venmoHost.className = "paypal-venmo-host";
        host.parentNode.appendChild(venmoHost);
        window.paypal
          .Buttons({
            fundingSource: window.paypal.FUNDING.VENMO,
            createOrder: function (data, actions) {
              return actions.order.create({
                purchase_units: [
                  {
                    amount: { value: amount, currency_code: cfg().paypal.currency || "USD" },
                    description: name,
                  },
                ],
              });
            },
            onApprove: function (data, actions) {
              return actions.order.capture();
            },
          })
          .render(venmoHost);
      }
    });
  }

  function initShop() {
    document.querySelectorAll("[data-product]").forEach(function (card) {
      var id = card.getAttribute("data-product");
      var product = PRODUCTS[id];
      if (!product) return;
      var host = card.querySelector(".product-checkout");
      if (host) renderProductPayments(host, product);
    });

    loadPayPalSdk(function (ok) {
      if (ok) renderPayPalButtons();
    });
  }

  window.HPL_PRODUCTS = PRODUCTS;
  window.HPL_initShop = initShop;

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initShop);
  } else {
    initShop();
  }
})();
