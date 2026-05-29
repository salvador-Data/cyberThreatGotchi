/**
 * Hacker Planet LLC - PCI-safe shop cart (localStorage queue)
 * Card data never touches this site - checkout opens Stripe hosted Payment Links only.
 */
(function () {
  var STORAGE_KEY = "hpl_cart_v1";

  function cfg() {
    return window.HPL_PAYMENTS || {};
  }

  function products() {
    return window.HPL_PRODUCTS || {};
  }

  function el(tag, cls, html) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (html != null) node.innerHTML = html;
    return node;
  }

  function escapeHtml(str) {
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function isRecurring(product) {
    return !!(
      product &&
      (product.recurring || product.period === "/month" || product.period === "/year")
    );
  }

  function canAddToCart(stripeKey) {
    var product = products()[stripeKey];
    return !!(product && product.stripeKey && !isRecurring(product));
  }

  function readCart() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return [];
      var parsed = JSON.parse(raw);
      return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
      return [];
    }
  }

  function writeCart(items) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(items));
    renderCartUi();
  }

  function cartCount(items) {
    items = items || readCart();
    return items.reduce(function (sum, row) {
      return sum + (row.qty || 0);
    }, 0);
  }

  function cartSubtotal(items) {
    items = items || readCart();
    return items.reduce(function (sum, row) {
      var product = products()[row.stripeKey];
      if (!product) return sum;
      return sum + Number(product.price || 0) * (row.qty || 0);
    }, 0);
  }

  function addItem(stripeKey, qty) {
    if (!canAddToCart(stripeKey)) return false;
    qty = Math.max(1, Math.min(99, parseInt(qty, 10) || 1));
    var items = readCart();
    var found = false;
    items = items.map(function (row) {
      if (row.stripeKey !== stripeKey) return row;
      found = true;
      return { stripeKey: stripeKey, qty: Math.min(99, (row.qty || 0) + qty) };
    });
    if (!found) items.push({ stripeKey: stripeKey, qty: qty });
    writeCart(items);
    return true;
  }

  function setQty(stripeKey, qty) {
    qty = parseInt(qty, 10) || 0;
    var items = readCart().filter(function (row) {
      if (row.stripeKey !== stripeKey) return true;
      return qty > 0;
    });
    if (qty > 0) {
      var exists = items.some(function (row) {
        return row.stripeKey === stripeKey;
      });
      if (exists) {
        items = items.map(function (row) {
          return row.stripeKey === stripeKey ? { stripeKey: stripeKey, qty: Math.min(99, qty) } : row;
        });
      } else {
        items.push({ stripeKey: stripeKey, qty: Math.min(99, qty) });
      }
    }
    writeCart(items);
  }

  function removeItem(stripeKey) {
    writeCart(
      readCart().filter(function (row) {
        return row.stripeKey !== stripeKey;
      })
    );
  }

  function clearCart() {
    writeCart([]);
  }

  function stripeCheckoutUrl(stripeKey) {
    var product = products()[stripeKey];
    if (!product || typeof window.HPL_buildStripeCheckoutUrl !== "function") return "";
    var links = cfg().stripePaymentLinks || {};
    var base = String(links[stripeKey] || "").trim();
    if (base.indexOf("https://buy.stripe.com/") !== 0) return "";
    return window.HPL_buildStripeCheckoutUrl(base, product);
  }

  function isDemoMode() {
    if (typeof window.HPL_isDemoMode === "function") return window.HPL_isDemoMode();
    var c = cfg();
    if (c.demoMode === false) return false;
    var links = c.stripePaymentLinks || {};
    var hasAny = Object.keys(links).some(function (k) {
      var url = String(links[k] || "").trim();
      return url.indexOf("https://buy.stripe.com/") === 0;
    });
    if (hasAny) return false;
    if ((c.paypal || {}).clientId || (c.paypalMe || {}).username) return false;
    if ((c.cashapp || {}).cashtag || (c.venmo || {}).username) return false;
    return c.demoMode !== false;
  }

  function checkoutSequential() {
    var items = readCart();
    if (!items.length) return;

    var demo = isDemoMode();
    var queue = [];
    items.forEach(function (row) {
      var url = stripeCheckoutUrl(row.stripeKey);
      if (!url) return;
      var n = Math.max(1, row.qty || 1);
      for (var i = 0; i < n; i += 1) queue.push({ stripeKey: row.stripeKey, url: url });
    });

    if (!queue.length) {
      alert(
        demo
          ? "Cart checkout needs Stripe Payment Links in payments.config.js.\n\nRun:\npython scripts/stripe_bootstrap_payment_links.py --write-config --go-live\n\nSee docs/STRIPE_ADD_LINKS.md"
          : "No Stripe checkout links are configured for items in your cart."
      );
      return;
    }

    var msg =
      "You will complete " +
      queue.length +
      " separate Stripe hosted checkout" +
      (queue.length === 1 ? "" : "s") +
      " (one per unit). Card data stays on Stripe - never on hackerplanet.dev.";
    if (!window.confirm(msg)) return;

    var idx = 0;
    function openNext() {
      if (idx >= queue.length) {
        clearCart();
        closeCartPanel();
        return;
      }
      window.open(queue[idx].url, "_blank", "noopener,noreferrer");
      idx += 1;
      if (idx < queue.length) {
        window.setTimeout(openNext, 600);
      } else {
        window.setTimeout(function () {
          clearCart();
          closeCartPanel();
        }, 800);
      }
    }
    openNext();
  }

  function openCartPanel() {
    var panel = document.getElementById("hpl-cart-panel");
    if (panel) {
      panel.hidden = false;
      panel.setAttribute("aria-hidden", "false");
    }
    var backdrop = document.getElementById("hpl-cart-backdrop");
    if (backdrop) backdrop.hidden = false;
  }

  function closeCartPanel() {
    var panel = document.getElementById("hpl-cart-panel");
    if (panel) {
      panel.hidden = true;
      panel.setAttribute("aria-hidden", "true");
    }
    var backdrop = document.getElementById("hpl-cart-backdrop");
    if (backdrop) backdrop.hidden = true;
  }

  function renderCartPanel() {
    var panel = document.getElementById("hpl-cart-panel");
    if (!panel) return;
    var items = readCart();
    panel.innerHTML = "";

    var header = el("div", "hpl-cart-header");
    header.appendChild(el("h2", "hpl-cart-title", "Your cart"));
    var closeBtn = el("button", "hpl-cart-close", "Close");
    closeBtn.type = "button";
    closeBtn.setAttribute("aria-label", "Close cart");
    closeBtn.addEventListener("click", closeCartPanel);
    header.appendChild(closeBtn);
    panel.appendChild(header);

    panel.appendChild(
      el(
        "p",
        "hpl-cart-privacy",
        "<strong>PCI-safe:</strong> No card numbers on this site. Checkout opens Stripe hosted pages only."
      )
    );

    if (!items.length) {
      panel.appendChild(el("p", "hpl-cart-empty", "Cart is empty. Add partner or Philadelphia direct-ship SKUs from the shop."));
      var shopLink = el("a", "btn btn-primary hpl-cart-shop-link", "Browse shop");
      shopLink.href = "shop.html";
      panel.appendChild(shopLink);
      return;
    }

    var list = el("ul", "hpl-cart-lines");
    items.forEach(function (row) {
      var product = products()[row.stripeKey];
      if (!product) return;
      var li = el("li", "hpl-cart-line");
      li.innerHTML =
        '<div class="hpl-cart-line-info">' +
        "<strong>" +
        escapeHtml(product.name) +
        "</strong>" +
        '<span class="hpl-cart-line-price">$' +
        (Number(product.price) * (row.qty || 1)).toFixed(2) +
        "</span>" +
        (product.desc ? '<span class="hpl-cart-line-desc">' + escapeHtml(product.desc) + "</span>" : "") +
        "</div>";

      var qtyWrap = el("div", "hpl-cart-qty");
      var minus = el("button", "hpl-cart-qty-btn", "-");
      minus.type = "button";
      minus.setAttribute("aria-label", "Decrease quantity");
      var qtyInput = document.createElement("input");
      qtyInput.type = "number";
      qtyInput.min = "1";
      qtyInput.max = "99";
      qtyInput.value = String(row.qty || 1);
      qtyInput.className = "hpl-cart-qty-input";
      qtyInput.setAttribute("aria-label", "Quantity");
      var plus = el("button", "hpl-cart-qty-btn", "+");
      plus.type = "button";
      plus.setAttribute("aria-label", "Increase quantity");
      var removeBtn = el("button", "hpl-cart-remove", "Remove");
      removeBtn.type = "button";

      minus.addEventListener("click", function () {
        setQty(row.stripeKey, (row.qty || 1) - 1);
      });
      plus.addEventListener("click", function () {
        setQty(row.stripeKey, (row.qty || 1) + 1);
      });
      qtyInput.addEventListener("change", function () {
        setQty(row.stripeKey, qtyInput.value);
      });
      removeBtn.addEventListener("click", function () {
        removeItem(row.stripeKey);
      });

      qtyWrap.appendChild(minus);
      qtyWrap.appendChild(qtyInput);
      qtyWrap.appendChild(plus);
      li.appendChild(qtyWrap);
      li.appendChild(removeBtn);
      list.appendChild(li);
    });
    panel.appendChild(list);

    var subtotal = cartSubtotal(items);
    panel.appendChild(el("p", "hpl-cart-subtotal", "Subtotal: <strong>$" + subtotal.toFixed(2) + "</strong>"));
    panel.appendChild(
      el(
        "p",
        "hpl-cart-note",
        "Partner fulfillment and Philadelphia direct-ship items may complete as separate Stripe checkouts. Subscriptions use Subscribe on each product card."
      )
    );

    var actions = el("div", "hpl-cart-actions");
    var checkoutBtn = el("button", "btn btn-primary hpl-cart-checkout", "Checkout with Stripe");
    checkoutBtn.type = "button";
    checkoutBtn.addEventListener("click", checkoutSequential);
    var clearBtn = el("button", "btn btn-ghost hpl-cart-clear", "Clear cart");
    clearBtn.type = "button";
    clearBtn.addEventListener("click", function () {
      if (window.confirm("Remove all items from your cart?")) clearCart();
    });
    actions.appendChild(checkoutBtn);
    actions.appendChild(clearBtn);
    panel.appendChild(actions);
  }

  function renderCartUi() {
    var count = cartCount();
    document.querySelectorAll(".hpl-cart-badge").forEach(function (badge) {
      badge.textContent = String(count);
      badge.hidden = count === 0;
    });
    document.querySelectorAll(".hpl-nav-cart").forEach(function (btn) {
      btn.setAttribute("aria-label", count ? "Open cart (" + count + " items)" : "Open cart");
    });
    renderCartPanel();
  }

  function closeBuyModal() {
    var modal = document.getElementById("hpl-buy-modal");
    if (modal) {
      modal.hidden = true;
      modal.setAttribute("aria-hidden", "true");
    }
    var backdrop = document.getElementById("hpl-buy-backdrop");
    if (backdrop) backdrop.hidden = true;
  }

  function mountBuyModal() {
    if (document.getElementById("hpl-buy-modal")) return;

    var backdrop = el("div", "hpl-modal-backdrop");
    backdrop.id = "hpl-buy-backdrop";
    backdrop.hidden = true;
    backdrop.addEventListener("click", closeBuyModal);

    var modal = el("div", "hpl-buy-modal");
    modal.id = "hpl-buy-modal";
    modal.setAttribute("role", "dialog");
    modal.setAttribute("aria-modal", "true");
    modal.setAttribute("aria-labelledby", "hpl-buy-modal-title");
    modal.hidden = true;

    modal.appendChild(el("h2", "hpl-buy-modal-title", "Add to cart"));
    var productLine = el("p", "hpl-buy-modal-product");
    productLine.id = "hpl-buy-modal-product-name";
    modal.appendChild(productLine);
    var bodyHost = el("div", "hpl-buy-modal-body");
    bodyHost.id = "hpl-buy-modal-body";
    modal.appendChild(bodyHost);
    var actions = el("div", "hpl-buy-modal-actions");
    actions.id = "hpl-buy-modal-actions";
    modal.appendChild(actions);

    document.body.appendChild(backdrop);
    document.body.appendChild(modal);

    document.addEventListener("keydown", function (ev) {
      if (ev.key === "Escape") closeBuyModal();
    });
  }

  function showBuyModal(product) {
    if (!product || !product.stripeKey) return;
    mountBuyModal();

    var modal = document.getElementById("hpl-buy-modal");
    var body = document.getElementById("hpl-buy-modal-body");
    var nameEl = document.getElementById("hpl-buy-modal-product-name");
    if (!modal || !body || !nameEl) return;

    nameEl.innerHTML = "<strong>" + escapeHtml(product.name) + "</strong>";

    var priceLabel = "$" + Number(product.price || 0).toFixed(2);
    if (product.period && product.period !== "one-time") priceLabel += product.period;

    body.innerHTML =
      "<p class=\"hpl-buy-modal-price\">" +
      escapeHtml(priceLabel) +
      "</p>" +
      (product.desc ? "<p class=\"hpl-buy-modal-desc\">" + escapeHtml(product.desc) + "</p>" : "") +
      "<p class=\"hpl-buy-modal-note\">Partner fulfillment and Philadelphia direct-ship SKUs queue in your cart. Card data stays on Stripe hosted checkout only.</p>";

    var actions = document.getElementById("hpl-buy-modal-actions");
    if (!actions) return;
    actions.innerHTML = "";

    var addBtn = el("button", "btn btn-primary", "Add to cart");
    addBtn.type = "button";
    addBtn.addEventListener("click", function () {
      if (addItem(product.stripeKey, 1)) {
        closeBuyModal();
        openCartPanel();
      }
    });
    actions.appendChild(addBtn);

    var stripeUrl = stripeCheckoutUrl(product.stripeKey);
    if (stripeUrl) {
      var stripeBtn = el("a", "btn btn-ghost", "Checkout now (Stripe)");
      stripeBtn.href = stripeUrl;
      stripeBtn.target = "_blank";
      stripeBtn.rel = "noopener noreferrer";
      actions.appendChild(stripeBtn);
    }

    if (typeof window.HPL_buildAltPaymentLinks === "function") {
      var alt = window.HPL_buildAltPaymentLinks(product);
      if (alt.paypal) {
        var paypalBtn = el("a", "btn btn-ghost pay-btn-paypal", "PayPal");
        paypalBtn.href = alt.paypal;
        paypalBtn.target = "_blank";
        paypalBtn.rel = "noopener noreferrer";
        actions.appendChild(paypalBtn);
      }
      if (alt.venmo) {
        var venmoBtn = el("a", "btn btn-ghost pay-btn-venmo", "Venmo");
        venmoBtn.href = alt.venmo;
        venmoBtn.target = "_blank";
        venmoBtn.rel = "noopener noreferrer";
        actions.appendChild(venmoBtn);
      }
      if (alt.cashapp) {
        var cashBtn = el("a", "btn btn-ghost pay-btn-cashapp", "Cash App");
        cashBtn.href = alt.cashapp;
        cashBtn.target = "_blank";
        cashBtn.rel = "noopener noreferrer";
        actions.appendChild(cashBtn);
      }
    }

    if (!stripeUrl && isDemoMode() && typeof window.HPL_hasAnyCheckoutMethod === "function" &&
        !window.HPL_hasAnyCheckoutMethod()) {
      actions.appendChild(
        el(
          "span",
          "pay-placeholder",
          "Stripe Payment Link pending - email " +
            escapeHtml(cfg().supportEmail || "salvadorData@proton.me")
        )
      );
    }

    var cancelBtn = el("button", "btn btn-ghost hpl-buy-cancel", "Continue shopping");
    cancelBtn.type = "button";
    cancelBtn.addEventListener("click", closeBuyModal);
    actions.appendChild(cancelBtn);

    modal.hidden = false;
    modal.setAttribute("aria-hidden", "false");
    var backdrop = document.getElementById("hpl-buy-backdrop");
    if (backdrop) backdrop.hidden = false;
    addBtn.focus();
  }

  function mountCartChrome() {
    if (!document.getElementById("hpl-cart-panel")) {
      var backdrop = el("div", "hpl-cart-backdrop");
      backdrop.id = "hpl-cart-backdrop";
      backdrop.hidden = true;
      backdrop.addEventListener("click", closeCartPanel);

      var panel = el("aside", "hpl-cart-panel");
      panel.id = "hpl-cart-panel";
      panel.hidden = true;
      panel.setAttribute("aria-hidden", "true");
      panel.setAttribute("aria-label", "Shopping cart");

      document.body.appendChild(backdrop);
      document.body.appendChild(panel);
    }

    if (!document.querySelector(".hpl-nav-cart")) {
      var navLinks = document.querySelector(".nav-links");
      if (navLinks) {
        var li = el("li", "nav-cart-item");
        var btn = el("button", "hpl-nav-cart");
        btn.type = "button";
        btn.innerHTML =
          '<span class="hpl-cart-icon" aria-hidden="true"></span> Cart <span class="hpl-cart-badge" hidden>0</span>';
        btn.addEventListener("click", function () {
          var panel = document.getElementById("hpl-cart-panel");
          if (panel && panel.hidden) openCartPanel();
          else closeCartPanel();
        });
        li.appendChild(btn);
        var githubLi = navLinks.querySelector(".nav-cta");
        if (githubLi && githubLi.parentElement) {
          navLinks.insertBefore(li, githubLi.parentElement);
        } else {
          navLinks.appendChild(li);
        }
      }
    }

    renderCartUi();
  }

  function initCart() {
    mountCartChrome();
    window.setTimeout(mountCartChrome, 100);
  }

  window.HPL_CART = {
    add: addItem,
    remove: removeItem,
    setQty: setQty,
    clear: clearCart,
    items: readCart,
    count: cartCount,
    subtotal: cartSubtotal,
    checkout: checkoutSequential,
    openPanel: openCartPanel,
    closePanel: closeCartPanel,
  };
  window.HPL_showBuyModal = showBuyModal;
  window.HPL_initCart = initCart;

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initCart);
  } else {
    initCart();
  }
})();
