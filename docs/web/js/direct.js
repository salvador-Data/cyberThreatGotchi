/**
 * Hacker Planet LLC — direct-ship catalog (Philadelphia fulfillment)
 */
(function () {
  var SOURCE_LABELS = {
    direct: { label: "Philly ship", icon: "📍", class: "source-direct" },
  };

  function cfg() {
    return window.HPL_DIRECT || { products: [] };
  }

  function el(tag, cls, html) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (html != null) node.innerHTML = html;
    return node;
  }

  function sourceBadge(source) {
    var meta = SOURCE_LABELS[source] || SOURCE_LABELS.direct;
    return el("span", "catalog-source " + meta.class, meta.icon + " " + meta.label);
  }

  function renderStripeCheckout(host, product) {
    if (typeof window.HPL_renderCheckout !== "function") return;
    host.className = "product-checkout";
    host.setAttribute("data-product", product.stripeKey);
    var payProduct = window.HPL_PRODUCTS && window.HPL_PRODUCTS[product.stripeKey];
    if (payProduct) window.HPL_renderCheckout(host, payProduct);
  }

  function renderProductImage(product) {
    if (!product.image) return null;
    var wrap = el("div", "shop-card-img-wrap");
    var img = document.createElement("img");
    img.className = "shop-card-img";
    img.src = product.image;
    img.alt = product.name || "Product";
    img.loading = "lazy";
    img.decoding = "async";
    wrap.appendChild(img);
    return wrap;
  }

  function renderProductCard(product) {
    var card = el("article", "shop-card catalog-card shop-card-featured");
    card.setAttribute("data-fulfillment", product.fulfillment || "direct");
    if (product.id) card.id = product.id === "crackbotCyd" ? "crackbot-cyd" : product.id;
    var imgWrap = renderProductImage(product);
    if (imgWrap) card.appendChild(imgWrap);
    if (product.badge) card.appendChild(el("div", "shop-badge", product.badge));
    card.appendChild(sourceBadge(product.source));
    card.appendChild(el("h3", "", product.name));
    if (product.tagline) {
      card.appendChild(el("p", "shop-tagline", product.tagline));
    }
    card.appendChild(el("div", "shop-price catalog-price", product.priceDisplay || ""));
    card.appendChild(el("p", "", product.description || ""));

    if (product.includes && product.includes.length) {
      var ul = el("ul", "shop-features");
      product.includes.forEach(function (item) {
        ul.appendChild(el("li", "", item));
      });
      card.appendChild(ul);
    }

    var checkout = el("div", "catalog-checkout");
    if (product.stripeKey) renderStripeCheckout(checkout, product);
    card.appendChild(checkout);

    if (product.stripeKey && typeof window.HPL_preselectCalculator === "function") {
      var estBtn = el("button", "ship-calc-link", "Estimate shipping & tax");
      estBtn.type = "button";
      estBtn.addEventListener("click", function () {
        window.HPL_preselectCalculator(product.stripeKey);
      });
      card.appendChild(estBtn);
    }

    var note = el("p", "catalog-ship-note", cfg().directNote || "Ships from Philadelphia, PA");
    if (product.fulfillment === "digital") {
      note.textContent = "Digital delivery · no shipping charge";
    }
    card.appendChild(note);
    return card;
  }

  function initDirect() {
    var host = document.getElementById("direct-catalog");
    if (!host) return;

    var wrap = el("section", "reveal catalog-section");
    wrap.id = "catalog-hpl-direct";
    wrap.appendChild(el("p", "section-label", "Made in Philadelphia"));
    wrap.appendChild(el("h2", "section-title", "HackerPlanet builds — direct ship"));
    wrap.appendChild(
      el(
        "p",
        "section-sub catalog-intro",
        "Sabreto Akachi, Mr. CrackBot AI Nano on CYD, CyberThreatGotchi kits, and custom field builds — " +
          "assembled in Philadelphia. Customization is the only rendezvous option on these SKUs. Use the calculator above for shipping & tax."
      )
    );

    var grid = el("div", "shop-grid catalog-grid");
    (cfg().products || []).forEach(function (product) {
      grid.appendChild(renderProductCard(product));
    });
    wrap.appendChild(grid);
    host.appendChild(wrap);
  }

  window.HPL_initDirect = initDirect;

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initDirect);
  } else {
    initDirect();
  }
})();
