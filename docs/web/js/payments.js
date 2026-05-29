/**
 * Hacker Planet LLC - checkout buttons
 * Stripe (hosted Payment Links + Customer Portal) | PayPal hosted | Venmo | Cash App
 * Never collects PAN/CVV on this site - cards vault on Stripe/PayPal only.
 */

(function () {
  var PRODUCTS = {
    digital: {
      id: "digital",
      name: "Digital Pack",
      price: 15,
      period: "one-time",
      desc: "GitHub bundle, STL zip, sprites, release assets",
      stripeKey: "digital",
    },
    proMonthly: {
      id: "proMonthly",
      name: "CTG Pro Feed",
      price: 9,
      period: "/month",
      recurring: true,
      desc: "Pro signatures, YARA, hash packs via API key",
      stripeKey: "proMonthly",
      paypalPlanKey: "proMonthly",
    },
    proYearly: {
      id: "proYearly",
      name: "CTG Pro Feed",
      price: 99,
      period: "/year",
      recurring: true,
      desc: "Pro feed - save vs monthly",
      stripeKey: "proYearly",
      paypalPlanKey: "proYearly",
    },
    mspMonitor: {
      id: "mspMonitor",
      name: "Blue Team MSP - Monitor",
      price: 1500,
      period: "/month",
      recurring: true,
      desc: "Log review, CTG edge health, patch advisory, quarterly review",
      stripeKey: "mspMonitor",
      paypalPlanKey: "mspMonitor",
    },
    mspDefend: {
      id: "mspDefend",
      name: "Blue Team MSP - Defend",
      price: 2750,
      period: "/month",
      recurring: true,
      desc: "Monitor + UTM policy, YARA cadence, business-hours triage",
      stripeKey: "mspDefend",
      paypalPlanKey: "mspDefend",
    },
    mspHarden: {
      id: "mspHarden",
      name: "Blue Team MSP - Harden",
      price: 4500,
      period: "/month",
      recurring: true,
      desc: "Defend + DDoS edge hardening, scrubbing liaison, on-call escalation",
      stripeKey: "mspHarden",
      paypalPlanKey: "mspHarden",
    },
    coreKit: {
      id: "coreKit",
      name: "CyberThreatGotchi",
      price: 219,
      period: "one-time",
      desc: "HPL direct ship | BPI-R3 Mini + e-ink + enclosure",
      stripeKey: "coreKit",
    },
    fieldPack: {
      id: "fieldPack",
      name: "Field Pack",
      price: 279,
      period: "one-time",
      desc: "HPL direct ship | core kit + M5 Cardputer",
      stripeKey: "fieldPack",
    },
    cydStandard: {
      id: "cydStandard",
      name: "CYD Field Build - Standard",
      price: 89.99,
      period: "one-time",
      desc: "CYD standard | Philly direct | + tax & shipping",
      stripeKey: "cydStandard",
    },
    cydFieldCustom: {
      id: "cydFieldCustom",
      name: "CYD Field Build - Custom",
      price: 189.99,
      period: "one-time",
      desc: "GPS | ext Wi-Fi/BLE | battery | switch | Philly direct",
      stripeKey: "cydFieldCustom",
    },
    crackbotBench: {
      id: "crackbotBench",
      name: "Mr. CrackBot AI Nano - Bench Lab",
      price: 499,
      period: "one-time",
      desc: "Jetson + CYD UI + GPU hashcat | difficult Philly assembly",
      stripeKey: "crackbotBench",
    },
    remotePossibility: {
      id: "remotePossibility",
      name: "Remote Possibility",
      price: 99.99,
      period: "one-time",
      desc: "M5 Cardputer | universal IR remote firmware",
      stripeKey: "remotePossibility",
    },
    bleBot: {
      id: "bleBot",
      name: "BLE Bot",
      price: 89.99,
      period: "one-time",
      desc: "M5 Cardputer | authorized BLE scout firmware",
      stripeKey: "bleBot",
    },
    boostFormulaCod: {
      id: "boostFormulaCod",
      name: "Boost Formula COD Field Kit",
      price: 99,
      period: "one-time",
      desc: "HPL direct ship | ESP32-S3 + antenna",
      stripeKey: "boostFormulaCod",
    },
    codStlPack: {
      id: "codStlPack",
      name: "COD STL + KSS print pack",
      price: 19,
      period: "one-time",
      desc: "Digital delivery | STL + slicer profiles",
      stripeKey: "codStlPack",
    },
    dsPwnagotchi: {
      id: "dsPwnagotchi",
      name: "Pwnagotchi wardrive pod",
      price: 169,
      period: "one-time",
      desc: "Partner fulfillment - assembled Pwnagotchi build",
      stripeKey: "dsPwnagotchi",
    },
    dsNetgotchi: {
      id: "dsNetgotchi",
      name: "Netgotchi defensive guardian",
      price: 99,
      period: "one-time",
      desc: "Partner fulfillment - from OlleAdventures",
      stripeKey: "dsNetgotchi",
    },
    dsNetgotchiPro: {
      id: "dsNetgotchiPro",
      name: "Netgotchi Pro",
      price: 129,
      period: "one-time",
      desc: "Partner fulfillment - Pro with keypad + buzzer",
      stripeKey: "dsNetgotchiPro",
    },
    dsNightHunter: {
      id: "dsNightHunter",
      name: "Night Hunter Kali-ready pod",
      price: 189,
      period: "one-time",
      desc: "Partner fulfillment - GPS wardrive field pod",
      stripeKey: "dsNightHunter",
    },
    dsMeshtasticTBeam: {
      id: "dsMeshtasticTBeam",
      name: "LilyGO T-Beam Meshtastic kit",
      price: 89,
      period: "one-time",
      desc: "Partner fulfillment - LoRa mesh node",
      stripeKey: "dsMeshtasticTBeam",
    },
    dsMeshtasticHeltec: {
      id: "dsMeshtasticHeltec",
      name: "Heltec V3 fully built Meshtastic",
      price: 129,
      period: "one-time",
      desc: "Partner fulfillment - Etsy turnkey mesh radio",
      stripeKey: "dsMeshtasticHeltec",
    },
    dsMeshtasticRAK: {
      id: "dsMeshtasticRAK",
      name: "RAK4631 Meshtastic starter",
      price: 119,
      period: "one-time",
      desc: "Partner fulfillment - WisBlock mesh kit",
      stripeKey: "dsMeshtasticRAK",
    },
    dsMeshtasticCase: {
      id: "dsMeshtasticCase",
      name: "Meshtastic field case",
      price: 34,
      period: "one-time",
      desc: "Partner fulfillment - 3D printed enclosure",
      stripeKey: "dsMeshtasticCase",
    },
    dsHackberryZero: {
      id: "dsHackberryZero",
      name: "Hackberry Pi Zero cyberdeck",
      price: 279,
      period: "one-time",
      desc: "Partner fulfillment - ZitaoTech pocket terminal",
      stripeKey: "dsHackberryZero",
    },
    dsHackberryPi5: {
      id: "dsHackberryPi5",
      name: "Hackberry Pi 5 cyberdeck",
      price: 449,
      period: "one-time",
      desc: "Partner fulfillment - full Pi 5 handheld",
      stripeKey: "dsHackberryPi5",
    },
    dsHackberryCM5: {
      id: "dsHackberryCM5",
      name: "Hackberry Pi CM5",
      price: 499,
      period: "one-time",
      desc: "Partner fulfillment - CM5 ultra portable",
      stripeKey: "dsHackberryCM5",
    },
    dsMarauderGps: {
      id: "dsMarauderGps",
      name: "Marauder pocket + GPS v2",
      price: 219,
      period: "one-time",
      desc: "Partner fulfillment - HoneyHoneyTrading build",
      stripeKey: "dsMarauderGps",
    },
    dsMarauderBatteryMod: {
      id: "dsMarauderBatteryMod",
      name: "CYD battery + GPS mod",
      price: 59,
      period: "one-time",
      desc: "Partner fulfillment - Biscuit Shop mod kit",
      stripeKey: "dsMarauderBatteryMod",
    },
    dsMarauderKoko: {
      id: "dsMarauderKoko",
      name: "Official Marauder Kit",
      price: 89,
      period: "one-time",
      desc: "Partner fulfillment - Koko PCB kit",
      stripeKey: "dsMarauderKoko",
    },
    dsRaspberryPi5: {
      id: "dsRaspberryPi5",
      name: "Raspberry Pi 5 starter kit",
      price: 159,
      period: "one-time",
      desc: "Partner fulfillment - authorized Pi 5 kit",
      stripeKey: "dsRaspberryPi5",
    },
    dsOrangePi5: {
      id: "dsOrangePi5",
      name: "Orange Pi 5 Plus kit",
      price: 119,
      period: "one-time",
      desc: "Partner fulfillment - RK3588 SBC kit",
      stripeKey: "dsOrangePi5",
    },
    dsBananaPiR3: {
      id: "dsBananaPiR3",
      name: "Banana Pi BPI-R3 Mini",
      price: 119,
      period: "one-time",
      desc: "Ops spare-board SKU - board ships inside coreKit; not standalone retail",
      stripeKey: "dsBananaPiR3",
    },
    dsEsp32Cyd: {
      id: "dsEsp32Cyd",
      name: "ESP32 CYD lab bundle",
      price: 49,
      period: "one-time",
      desc: "Partner fulfillment - 2x CYD boards",
      stripeKey: "dsEsp32Cyd",
    },
    dsWiringLab: {
      id: "dsWiringLab",
      name: "Breadboard + jumper wiring kit",
      price: 22,
      period: "one-time",
      desc: "Partner fulfillment - prototyping wire bundle",
      stripeKey: "dsWiringLab",
    },
    dsKaliNetHunter: {
      id: "dsKaliNetHunter",
      name: "Kali NetHunter lab phone",
      price: 399,
      period: "one-time",
      desc: "Partner fulfillment - pre-flashed lab handset",
      stripeKey: "dsKaliNetHunter",
    },
    dsRtlSdrKit: {
      id: "dsRtlSdrKit",
      name: "RTL-SDR Blog V3 starter kit",
      price: 99,
      period: "one-time",
      desc: "Partner fulfillment - receive-only SDR lab",
      stripeKey: "dsRtlSdrKit",
    },
    dsNesdrSmart: {
      id: "dsNesdrSmart",
      name: "NESDR SMArt v5 SDR bundle",
      price: 65,
      period: "one-time",
      desc: "Partner fulfillment - budget RTL-SDR kit",
      stripeKey: "dsNesdrSmart",
    },
    dsLanTap: {
      id: "dsLanTap",
      name: "Throwing Star LAN Tap Pro",
      price: 59,
      period: "one-time",
      desc: "Partner fulfillment - passive Ethernet tap",
      stripeKey: "dsLanTap",
    },
    dsThrowingStarKit: {
      id: "dsThrowingStarKit",
      name: "Throwing Star LAN Tap solder kit",
      price: 38,
      period: "one-time",
      desc: "Partner fulfillment - DIY passive tap kit",
      stripeKey: "dsThrowingStarKit",
    },
    dsEsp32WifiLab: {
      id: "dsEsp32WifiLab",
      name: "ESP32 WiFi lab dev board",
      price: 45,
      period: "one-time",
      desc: "Partner fulfillment - HUZZAH32 lab board",
      stripeKey: "dsEsp32WifiLab",
    },
    dsUsbRubberDucky: {
      id: "dsUsbRubberDucky",
      name: "USB Rubber Ducky training injector",
      price: 129,
      period: "one-time",
      desc: "Partner fulfillment - authorized training lab",
      stripeKey: "dsUsbRubberDucky",
    },
    dsHak5WifiPineapple: {
      id: "dsHak5WifiPineapple",
      name: "WiFi Pineapple Mark VII",
      price: 319,
      period: "one-time",
      desc: "Partner fulfillment - authorized wireless audit",
      stripeKey: "dsHak5WifiPineapple",
    },
  };

  function cfg() {
    return window.HPL_PAYMENTS || {};
  }

  function prefillApi() {
    return window.HPL_customerPrefill || null;
  }

  function stripeLink(key) {
    var links = cfg().stripePaymentLinks || {};
    return (links[key] || "").trim();
  }

  function hasAnyStripeLink() {
    var links = cfg().stripePaymentLinks || {};
    return Object.keys(links).some(function (k) {
      return stripeLink(k).indexOf("https://buy.stripe.com/") === 0;
    });
  }

  function isDemoMode() {
    var c = cfg();
    if (c.demoMode === false) return false;
    if (hasAnyStripeLink()) return false;
    return c.demoMode !== false;
  }

  function customerPortalUrl() {
    return String(cfg().stripeCustomerPortal || cfg().stripe?.customerPortalUrl || "").trim();
  }

  function isRecurringProduct(product) {
    return !!product.recurring || product.period === "/month" || product.period === "/year";
  }

  function loadCustomerProfile() {
    var api = prefillApi();
    if (!api) return {};
    var data = api.load() || {};
    return data.email ? data : {};
  }

  function saveCustomerProfile(profile) {
    var api = prefillApi();
    if (!api || !profile || !profile.email) return false;
    api.save({
      email: profile.email,
      name: profile.name || (profile.ship_to && profile.ship_to.name) || "",
      shipTo: {
        line1: (profile.ship_to && profile.ship_to.line1) || "",
        city: (profile.ship_to && profile.ship_to.city) || "",
        state: (profile.ship_to && profile.ship_to.state) || "",
        zip: (profile.ship_to && profile.ship_to.postal_code) || "",
      },
    });
    return true;
  }

  function clearCustomerProfile() {
    var api = prefillApi();
    if (api) api.clear();
  }

  function buildStripeCheckoutUrl(baseUrl, product) {
    if (!baseUrl || baseUrl.indexOf("https://buy.stripe.com/") !== 0) return "";
    var url = baseUrl;
    var api = prefillApi();
    var profile = loadCustomerProfile();
    if (api && profile.email) {
      url = api.appendStripePrefill(url, profile.email);
    }
    if (product && product.stripeKey) {
      var sep2 = url.indexOf("?") >= 0 ? "&" : "?";
      url += sep2 + "client_reference_id=" + encodeURIComponent(product.stripeKey);
    }
    return url;
  }

  function formatShipToPreview(profile) {
    if (!profile || !profile.email) return "";
    var ship = profile.shipTo || profile.ship_to || {};
    var parts = [];
    if (profile.name) parts.push(profile.name);
    if (ship.line1) parts.push(ship.line1);
    var cityLine = [ship.city, ship.state, ship.zip || ship.postal_code].filter(Boolean).join(" ");
    if (cityLine) parts.push(cityLine);
    return parts.join(", ");
  }

  function renderReturningCustomerBar() {
    var host = document.getElementById("returning-customer-bar");
    if (!host) return;
    host.innerHTML = "";
    var profile = loadCustomerProfile();
    var portal = customerPortalUrl();
    var demo = isDemoMode();

    if (!profile.email && !portal && demo) return;

    var box = el("div", "returning-customer-panel");
    if (profile && profile.email) {
      var preview = formatShipToPreview(profile);
      box.appendChild(
        el(
          "p",
          "returning-customer-greeting",
          "<strong>Welcome back.</strong> Checkout can prefill your email" +
            (preview ? " - last ship-to: " + escapeHtml(preview) : "") +
            ". Saved cards are managed in Stripe (not on this site)."
        )
      );
    } else if (!demo) {
      box.appendChild(
        el(
          "p",
          "returning-customer-greeting",
          "Returning customer? Your saved payment methods live in Stripe Customer Portal."
        )
      );
    }

    var actions = el("div", "returning-customer-actions");
    if (portal) {
      actions.appendChild(
        payBtn("Manage billing & saved cards", portal, "portal", "")
      );
    }
    if (profile.email) {
      var clearBtn = el("button", "returning-clear-btn", "Clear saved ship-to on this device");
      clearBtn.type = "button";
      clearBtn.addEventListener("click", function () {
        clearCustomerProfile();
        renderReturningCustomerBar();
      });
      actions.appendChild(clearBtn);
    }
    if (actions.childNodes.length) box.appendChild(actions);
    if (box.childNodes.length) host.appendChild(box);
  }

  function renderShipToSaveForm() {
    var host = document.getElementById("ship-to-save-form");
    if (!host) return;
    var profile = loadCustomerProfile();
    host.innerHTML =
      '<p class="pay-privacy-note">' +
      "<strong>Privacy:</strong> We never store card numbers on hackerplanet.dev. " +
      "Optional ship-to + email save only in <em>your browser</em> for faster checkout. " +
      "Payment methods vault on Stripe or PayPal hosted pages." +
      "</p>" +
      '<form class="ship-to-save-form" id="hpl-ship-profile-form" autocomplete="shipping">' +
      '<label>Email <input type="email" name="email" required maxlength="254" /></label>' +
      '<label>Name <input type="text" name="name" maxlength="120" autocomplete="name" /></label>' +
      '<label>Address <input type="text" name="line1" maxlength="200" autocomplete="address-line1" /></label>' +
      '<label>Apt / suite <input type="text" name="line2" maxlength="120" autocomplete="address-line2" /></label>' +
      '<label>City <input type="text" name="city" maxlength="80" autocomplete="address-level2" /></label>' +
      '<label>State <input type="text" name="state" maxlength="40" autocomplete="address-level1" /></label>' +
      '<label>ZIP <input type="text" name="postal_code" maxlength="20" autocomplete="postal-code" /></label>' +
      '<button type="submit" class="btn btn-ghost">Save ship-to for next visit</button>' +
      "</form>";

    var form = document.getElementById("hpl-ship-profile-form");
    if (!form) return;
    if (profile && profile.email) {
      form.email.value = profile.email || "";
      form.name.value = profile.name || "";
      var s = profile.shipTo || profile.ship_to || {};
      form.line1.value = s.line1 || "";
      form.line2.value = s.line2 || "";
      form.city.value = s.city || "";
      form.state.value = s.state || "";
      form.postal_code.value = s.zip || s.postal_code || "";
    }
    form.addEventListener("submit", function (ev) {
      ev.preventDefault();
      saveCustomerProfile({
        email: form.email.value,
        ship_to: {
          name: form.name.value,
          line1: form.line1.value,
          line2: form.line2.value,
          city: form.city.value,
          state: form.state.value,
          postal_code: form.postal_code.value,
          country: "US",
        },
      });
      renderReturningCustomerBar();
      alert("Ship-to saved on this device only. Use Stripe Portal to update saved cards.");
    });
  }

  function escapeHtml(str) {
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function updatePayTrustBar() {
    var bar = document.getElementById("pay-trust-bar");
    if (!bar) return;
    var demo = isDemoMode();
    var hasStripe = Object.keys(cfg().stripePaymentLinks || {}).some(function (k) {
      return !!stripeLink(k);
    });
    var portal = customerPortalUrl();
    if (demo && !hasStripe) {
      bar.className = "pay-trust-bar reveal pay-trust-bar--muted";
      bar.innerHTML =
        "<span>Checkout: demo mode</span>" +
        "<span>Stripe | PayPal | Venmo | Cash App</span>";
      return;
    }
    bar.className = "pay-trust-bar reveal";
    var parts = ["<span>Secure checkout</span>"];
    if (hasStripe) parts.push("<span>Stripe: cards, Apple Pay, Google Pay, Link</span>");
    if ((cfg().paypal || {}).clientId || (cfg().paypalMe || {}).username) {
      if (cfg().paypalSubscriptions) parts.push("<span>PayPal subscriptions</span>");
      else parts.push("<span>PayPal</span>");
    }
    if (portal) parts.push('<span><a href="' + escapeHtml(portal) + '" rel="noopener noreferrer">Billing portal</a></span>');
    bar.innerHTML = parts.join("");
  }

  function cashAppUrl(amount, note) {
    var tag = (cfg().cashapp || {}).cashtag || "";
    if (!tag) return "";
    var base = "https://cash.app/$" + encodeURIComponent(tag.replace(/^\$/));
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
      recipients: user.replace(/^@/),
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
    var demo = isDemoMode();
    var link = buildStripeCheckoutUrl(stripeLink(product.stripeKey), product);
    var hasStripe = !!link;
    var hasPayPalMe = !!(c.paypalMe && c.paypalMe.username);
    var hasCash = !!(c.cashapp && c.cashapp.cashtag);
    var hasVenmo = !!(c.venmo && c.venmo.username);
    var hasPayPalSdk = !!(c.paypal && c.paypal.clientId);
    var portal = customerPortalUrl();
    var recurring = isRecurringProduct(product);
    var cartEligible =
      !recurring &&
      product.stripeKey &&
      typeof window.HPL_showBuyModal === "function";

    if (recurring) {
      container.appendChild(
        el("p", "pay-recurring-badge", "Recurring subscription - cancel anytime via billing portal")
      );
    }

    var methods = el("div", "pay-methods");

    if (cartEligible) {
      var buyBtn = el("button", "pay-btn pay-btn-buy btn btn-primary", "Buy");
      buyBtn.type = "button";
      buyBtn.addEventListener("click", function () {
        window.HPL_showBuyModal(product);
      });
      methods.appendChild(buyBtn);
    } else if (hasStripe) {
      var label = recurring
        ? "Subscribe (Stripe)"
        : "Card | Debit | Apple Pay | Save for next time";
      methods.appendChild(payBtn(label, link, "stripe"));
    } else if (demo) {
      methods.appendChild(el("span", "pay-placeholder", "Stripe link - see docs/PAYMENTS.md"));
    }

    if (portal && recurring) {
      methods.appendChild(payBtn("Manage subscription", portal, "portal"));
    }

    if (hasPayPalMe && !recurring && !cartEligible) {
      methods.appendChild(payBtn("PayPal", paypalMeUrl(product.price), "paypal"));
    }

    if (hasVenmo && !recurring && !cartEligible) {
      methods.appendChild(payBtn("Venmo", venmoUrl(product.price, product.name), "venmo"));
    }

    if (hasCash && !recurring && !cartEligible) {
      var ca = cashAppUrl(product.price, product.name);
      if (ca) methods.appendChild(payBtn("Cash App", ca, "cashapp"));
    }

    container.appendChild(methods);

    if (hasPayPalSdk) {
      var sdkHost = el("div", "paypal-sdk-host");
      sdkHost.id = "paypal-" + product.id;
      sdkHost.dataset.amount = String(product.price);
      sdkHost.dataset.name = product.name;
      sdkHost.dataset.recurring = recurring ? "1" : "0";
      if (product.paypalPlanKey) sdkHost.dataset.paypalPlan = product.paypalPlanKey;
      container.appendChild(sdkHost);
    }

    if (demo && !hasStripe && !hasPayPalMe && !hasVenmo && !hasCash && !hasPayPalSdk) {
      container.appendChild(
        el(
          "p",
          "pay-demo-note",
          'Checkout is in <strong>demo mode</strong>. Configure <code>website/js/payments.config.js</code> - ' +
            '<a href="https://github.com/salvador-Data/cyberThreatGotchi/blob/main/docs/PAYMENTS.md" target="_blank" rel="noopener">setup guide -></a>'
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
    var intent = "";
    var subs = cfg().paypalSubscriptions || {};
    var needsSubs = Object.keys(subs).some(function (k) {
      var entry = subs[k];
      return entry && (entry.planId || (typeof entry === "string" && entry));
    });
    if (needsSubs) {
      intent = "&vault=true&intent=subscription";
    } else if (c.vault) {
      intent = "&intent=capture&vault=true";
    }
    var s = document.createElement("script");
    s.src =
      "https://www.paypal.com/sdk/js?client-id=" +
      encodeURIComponent(c.clientId) +
      "&currency=" +
      encodeURIComponent(c.currency || "USD") +
      "&enable-funding=venmo,paylater&disable-funding=credit" +
      intent;
    s.onload = function () {
      callback(true);
    };
    s.onerror = function () {
      callback(false);
    };
    document.head.appendChild(s);
  }

  function paypalPlanId(planKey) {
    var subs = cfg().paypalSubscriptions || {};
    var entry = subs[planKey];
    if (!entry) return "";
    return String(entry.planId || entry || "").trim();
  }

  function renderPayPalButtons() {
    if (!window.paypal) return;
    document.querySelectorAll(".paypal-sdk-host").forEach(function (host) {
      var amount = host.dataset.amount;
      var name = host.dataset.name || "Hacker Planet LLC";
      var recurring = host.dataset.recurring === "1";
      var planKey = host.dataset.paypalPlan || "";
      var planId = planKey ? paypalPlanId(planKey) : "";

      if (recurring && planId) {
        window.paypal
          .Buttons({
            fundingSource: window.paypal.FUNDING.PAYPAL,
            style: { label: "subscribe" },
            createSubscription: function (data, actions) {
              return actions.subscription.create({ plan_id: planId });
            },
            onApprove: function (data) {
              console.info("[paypal] subscription approved", data.subscriptionID);
            },
          })
          .render(host);
        return;
      }

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

      if (!recurring && window.paypal.FUNDING.VENMO) {
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
    renderReturningCustomerBar();
    renderShipToSaveForm();
    updatePayTrustBar();

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
  window.HPL_renderReturningCustomer = renderReturningCustomerBar;
  window.HPL_loadCustomerProfile = loadCustomerProfile;
  window.HPL_saveCustomerProfile = saveCustomerProfile;
  window.HPL_clearCustomerProfile = clearCustomerProfile;
  window.HPL_buildStripeCheckoutUrl = buildStripeCheckoutUrl;

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initShop);
  } else {
    initShop();
  }
})();
