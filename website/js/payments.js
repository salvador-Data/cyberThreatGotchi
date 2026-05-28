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
      name: "CyberThreatGotchi",
      price: 169,
      period: "one-time",
      desc: "HPL direct ship · BPI-R3 Mini + e-ink + enclosure",
      stripeKey: "coreKit",
    },
    fieldPack: {
      id: "fieldPack",
      name: "Field Pack",
      price: 219,
      period: "one-time",
      desc: "HPL direct ship · core kit + M5 Cardputer",
      stripeKey: "fieldPack",
    },
    sabretoAkachi: {
      id: "sabretoAkachi",
      name: "CYD Field Build — Standard",
      price: 79.99,
      period: "one-time",
      desc: "Sabreto Akachi CYD · Philly direct · + tax & shipping",
      stripeKey: "sabretoAkachi",
    },
    cydFieldCustom: {
      id: "cydFieldCustom",
      name: "CYD Field Build — Custom",
      price: 174.99,
      period: "one-time",
      desc: "GPS · ext Wi-Fi/BLE · battery · switch · Philly direct",
      stripeKey: "cydFieldCustom",
    },
    crackbotBench: {
      id: "crackbotBench",
      name: "Mr. CrackBot AI Nano — Bench Lab",
      price: 449,
      period: "one-time",
      desc: "Jetson + CYD UI + GPU hashcat · difficult Philly assembly",
      stripeKey: "crackbotBench",
    },
    remotePossibility: {
      id: "remotePossibility",
      name: "Remote Possibility",
      price: 89.99,
      period: "one-time",
      desc: "M5 Cardputer · CTG remote status client",
      stripeKey: "remotePossibility",
    },
    bleBot: {
      id: "bleBot",
      name: "BLE Bot",
      price: 79.99,
      period: "one-time",
      desc: "M5 Cardputer · authorized BLE scout firmware",
      stripeKey: "bleBot",
    },
    boostFormulaCod: {
      id: "boostFormulaCod",
      name: "Boost Formula COD Field Kit",
      price: 99,
      period: "one-time",
      desc: "HPL direct ship · ESP32-S3 + antenna",
      stripeKey: "boostFormulaCod",
    },
    codStlPack: {
      id: "codStlPack",
      name: "COD STL + KSS print pack",
      price: 19,
      period: "one-time",
      desc: "Digital delivery · STL + slicer profiles",
      stripeKey: "codStlPack",
    },
    dsPwnagotchi: {
      id: "dsPwnagotchi",
      name: "Pwnagotchi wardrive pod",
      price: 169,
      period: "one-time",
      desc: "Drop-ship assembled Pwnagotchi build",
      stripeKey: "dsPwnagotchi",
    },
    dsNetgotchi: {
      id: "dsNetgotchi",
      name: "Netgotchi defensive guardian",
      price: 99,
      period: "one-time",
      desc: "Drop-ship from OlleAdventures",
      stripeKey: "dsNetgotchi",
    },
    dsNetgotchiPro: {
      id: "dsNetgotchiPro",
      name: "Netgotchi Pro",
      price: 129,
      period: "one-time",
      desc: "Drop-ship Pro with keypad + buzzer",
      stripeKey: "dsNetgotchiPro",
    },
    dsNightHunter: {
      id: "dsNightHunter",
      name: "Night Hunter Kali-ready pod",
      price: 189,
      period: "one-time",
      desc: "Drop-ship GPS wardrive field pod",
      stripeKey: "dsNightHunter",
    },
    dsMeshtasticTBeam: {
      id: "dsMeshtasticTBeam",
      name: "LilyGO T-Beam Meshtastic kit",
      price: 89,
      period: "one-time",
      desc: "Drop-ship LoRa mesh node",
      stripeKey: "dsMeshtasticTBeam",
    },
    dsMeshtasticHeltec: {
      id: "dsMeshtasticHeltec",
      name: "Heltec V3 Meshtastic node",
      price: 79,
      period: "one-time",
      desc: "Drop-ship compact mesh radio",
      stripeKey: "dsMeshtasticHeltec",
    },
    dsMeshtasticRAK: {
      id: "dsMeshtasticRAK",
      name: "RAK4631 Meshtastic starter",
      price: 119,
      period: "one-time",
      desc: "Drop-ship WisBlock mesh kit",
      stripeKey: "dsMeshtasticRAK",
    },
    dsMeshtasticCase: {
      id: "dsMeshtasticCase",
      name: "Meshtastic field case",
      price: 34,
      period: "one-time",
      desc: "Drop-ship 3D printed enclosure",
      stripeKey: "dsMeshtasticCase",
    },
    dsHackberryZero: {
      id: "dsHackberryZero",
      name: "Hackberry Pi Zero cyberdeck",
      price: 279,
      period: "one-time",
      desc: "Drop-ship ZitaoTech pocket terminal",
      stripeKey: "dsHackberryZero",
    },
    dsHackberryPi5: {
      id: "dsHackberryPi5",
      name: "Hackberry Pi 5 cyberdeck",
      price: 449,
      period: "one-time",
      desc: "Drop-ship full Pi 5 handheld",
      stripeKey: "dsHackberryPi5",
    },
    dsHackberryCM5: {
      id: "dsHackberryCM5",
      name: "Hackberry Pi CM5",
      price: 499,
      period: "one-time",
      desc: "Drop-ship CM5 ultra portable",
      stripeKey: "dsHackberryCM5",
    },
    dsMarauderGps: {
      id: "dsMarauderGps",
      name: "Marauder pocket + GPS v2",
      price: 219,
      period: "one-time",
      desc: "Drop-ship HoneyHoneyTrading build",
      stripeKey: "dsMarauderGps",
    },
    dsMarauderBatteryMod: {
      id: "dsMarauderBatteryMod",
      name: "CYD battery + GPS mod",
      price: 59,
      period: "one-time",
      desc: "Drop-ship Biscuit Shop mod kit",
      stripeKey: "dsMarauderBatteryMod",
    },
    dsMarauderKoko: {
      id: "dsMarauderKoko",
      name: "Official Marauder Kit",
      price: 89,
      period: "one-time",
      desc: "Drop-ship Koko PCB kit",
      stripeKey: "dsMarauderKoko",
    },
    dsRaspberryPi5: {
      id: "dsRaspberryPi5",
      name: "Raspberry Pi 5 starter kit",
      price: 139,
      period: "one-time",
      desc: "Drop-ship Pi 5 homelab kit",
      stripeKey: "dsRaspberryPi5",
    },
    dsOrangePi5: {
      id: "dsOrangePi5",
      name: "Orange Pi 5 Plus kit",
      price: 119,
      period: "one-time",
      desc: "Drop-ship RK3588 SBC kit",
      stripeKey: "dsOrangePi5",
    },
    dsBananaPiR3: {
      id: "dsBananaPiR3",
      name: "Banana Pi BPI-R3 Mini",
      price: 109,
      period: "one-time",
      desc: "Drop-ship edge router SBC",
      stripeKey: "dsBananaPiR3",
    },
    dsEsp32Cyd: {
      id: "dsEsp32Cyd",
      name: "ESP32 CYD lab bundle",
      price: 49,
      period: "one-time",
      desc: "Drop-ship 2× CYD boards",
      stripeKey: "dsEsp32Cyd",
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
    return renderCheckout(container, product);
  }

  function renderCheckout(container, product) {
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
  window.HPL_renderCheckout = renderCheckout;
  window.HPL_initShop = initShop;

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initShop);
  } else {
    initShop();
  }
})();
