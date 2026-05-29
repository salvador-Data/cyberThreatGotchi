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
    return window.HPL_buildStripeCheckoutUrl(base, product);
  }

  function checkoutSequential() {
    var items = readCart();
    if (!items.length) return;

    var demo = cfg().demoMode !== false;
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
          ? "Cart checkout is in demo mode. Configure Stripe Payment Links in payments.config.js first."
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
        return;
      }
      window.open(queue[idx].url, "_blank", "noopener,noreferrer");
      idx += 1;
      if (idx < queue.length) {
        window.setTimeout(openNext, 600);
      } else {
        window.setTimeout(clearCart, 800);
      }
    }
    openNext();
  }

  function renderCartPanel() {
    var panel = document.getElementById("hpl-cart-panel");
    if (!panel) return;
    var items = readCart();
    panel.innerHTML = "";

    panel.appendChild(el("h2", "hpl-cart-title", "Your cart"));
    panel.appendChild(
      el(
        "p",
        "hpl-cart-privacy",
        "<strong>PCI-safe:</strong> No card numbers on this site. Checkout opens Stripe hosted pages only."
      )
    );

    if (!items.length) {
      panel.appendChild(el("p", "hpl-cart-empty", "Cart is empty. Add partner or direct-ship SKUs below."));
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
        "Partner fulfillment and Philadelphia direct-ship items may complete as separate Stripe checkouts. Subscriptions use Buy Now on each card."
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
    var toggle = document.getElementById("hpl-cart-toggle");
    if (toggle) {
      toggle.setAttribute("aria-label", count ? "Open cart (" + count + " items)" : "Open cart");
      var badge = toggle.querySelector(".hpl-cart-badge");
      if (badge) {
        badge.textContent = String(count);
        badge.hidden = count === 0;
      }
    }
    renderCartPanel();
  }

  function attachAddToCart(host, stripeKey) {
    if (!host || !canAddToCart(stripeKey)) return;
    if (host.querySelector(".cart-add-btn")) return;
    var btn = el("button", "cart-add-btn btn btn-ghost", "Add to cart");
    btn.type = "button";
    btn.addEventListener("click", function () {
      addItem(stripeKey, 1);
      var panel = document.getElementById("hpl-cart-panel");
      if (panel) panel.scrollIntoView({ behavior: "smooth", block: "nearest" });
    });
    host.appendChild(btn);
  }

  function scanProductCards() {
    document.querySelectorAll(".shop-card").forEach(function (card) {
      var checkoutHost = card.querySelector(".catalog-checkout") || card.querySelector(".product-checkout");
      if (!checkoutHost) return;
      var keyHost = card.querySelector("[data-product]");
      var key = keyHost && keyHost.getAttribute("data-product");
      if (!key) return;
      attachAddToCart(checkoutHost, key);
    });
  }

  function mountCartChrome() {
    if (document.getElementById("hpl-cart-root")) return;

    var root = el("div", "hpl-cart-root");
    root.id = "hpl-cart-root";

    var toggle = el("button", "hpl-cart-toggle");
    toggle.id = "hpl-cart-toggle";
    toggle.type = "button";
    toggle.innerHTML = 'Cart <span class="hpl-cart-badge" hidden>0</span>';
    toggle.addEventListener("click", function () {
      var panel = document.getElementById("hpl-cart-panel");
      if (panel) panel.hidden = !panel.hidden;
    });

    var panel = el("aside", "hpl-cart-panel reveal");
    panel.id = "hpl-cart-panel";
    panel.hidden = true;

    root.appendChild(toggle);
    root.appendChild(panel);
    document.body.appendChild(root);
    renderCartUi();
  }

  function initCart() {
    mountCartChrome();
    scanProductCards();
    window.setTimeout(scanProductCards, 300);
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
  };
  window.HPL_attachAddToCart = attachAddToCart;
  window.HPL_initCart = initCart;

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initCart);
  } else {
    initCart();
  }
})();
