/**
 * Hacker Planet LLC — drop-ship catalog renderer
 * External links (Etsy, AliExpress, Tindie) + Stripe digital packs from catalog.config.js
 */

(function () {
  var SOURCE_LABELS = {
    etsy: { label: "Etsy", icon: "🛍️", class: "source-etsy" },
    aliexpress: { label: "AliExpress", icon: "📦", class: "source-ali" },
    tindie: { label: "Tindie", icon: "🔧", class: "source-tindie" },
    github: { label: "GitHub", icon: "⌨️", class: "source-github" },
    printables: { label: "Printables", icon: "🖨️", class: "source-printables" },
    hpl: { label: "Hacker Planet", icon: "🪐", class: "source-hpl" },
    direct: { label: "Philly ship", icon: "📍", class: "source-direct" },
    dropship: { label: "Drop-ship", icon: "📬", class: "source-dropship" },
  };

  function cfg() {
    return window.HPL_CATALOG || { sections: [] };
  }

  function el(tag, cls, html) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (html != null) node.innerHTML = html;
    return node;
  }

  function affiliateUrl(url, source) {
    if (!url) return "";
    var aff = cfg().affiliate || {};
    if (source === "aliexpress" && aff.aliexpress) {
      var sep = url.indexOf("?") >= 0 ? "&" : "?";
      return url + sep + aff.aliexpress;
    }
    if (source === "etsy" && aff.etsy) {
      return url + aff.etsy;
    }
    if (source === "tindie" && aff.tindie) {
      return url + aff.tindie;
    }
    return url;
  }

  function sourceBadge(source) {
    var meta = SOURCE_LABELS[source] || { label: source || "Partner", icon: "↗", class: "source-default" };
    return el("span", "catalog-source " + meta.class, meta.icon + " " + meta.label);
  }

  function renderStripeCheckout(host, product) {
    if (!window.HPL_PRODUCTS || !window.HPL_initShop) {
      host.appendChild(el("p", "pay-demo-note", "Load payments.js for checkout buttons."));
      return;
    }
    var payProduct = window.HPL_PRODUCTS[product.stripeKey];
    if (!payProduct) {
      host.appendChild(el("p", "pay-demo-note", "Configure Stripe key: <code>" + product.stripeKey + "</code>"));
      return;
    }
    host.className = "product-checkout";
    host.setAttribute("data-product", product.stripeKey);
    if (typeof window.HPL_renderCheckout === "function") {
      window.HPL_renderCheckout(host, payProduct);
    }
  }

  function renderBuyButton(product) {
    var url = affiliateUrl(product.buyUrl, product.source);
    if (product.fulfillment === "dropship" || product.fulfillment === "stripe") {
      return null;
    }
    if (!url) {
      return el("span", "pay-placeholder", "Add buyUrl in catalog.config.js");
    }
    var meta = SOURCE_LABELS[product.source] || { label: "Shop" };
    var a = el("a", "pay-btn pay-btn-external", "Buy on " + meta.label + " ↗");
    a.href = url;
    a.target = "_blank";
    a.rel = "noopener noreferrer sponsored";
    return a;
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
    var card = el("article", "shop-card catalog-card");
    var imgWrap = renderProductImage(product);
    if (imgWrap) card.appendChild(imgWrap);
    if (product.badge) {
      card.appendChild(el("div", "shop-badge", product.badge));
    }
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
    if ((product.fulfillment === "dropship" || product.fulfillment === "stripe") && product.stripeKey) {
      renderStripeCheckout(checkout, product);
    } else {
      var btn = renderBuyButton(product);
      if (btn) checkout.appendChild(btn);
    }
    card.appendChild(checkout);

    if (product.stripeKey && typeof window.HPL_preselectCalculator === "function") {
      var estBtn = el("button", "ship-calc-link", "Estimate shipping & tax");
      estBtn.type = "button";
      estBtn.addEventListener("click", function () {
        window.HPL_preselectCalculator(product.stripeKey);
      });
      card.appendChild(estBtn);
    }

    var note = el("p", "catalog-ship-note", cfg().dropshipNote || "Drop-ship · 5–14 business days");
    if (product.source === "github" || product.source === "printables") {
      note.textContent = "Instant download · remix allowed where license permits";
    } else if (product.fulfillment === "dropship") {
      note.textContent =
        (cfg().dropshipNote || "Drop-ship · 5–14 business days") +
        (product.supplier ? " · via " + product.supplier : "");
    }
    card.appendChild(note);

    return card;
  }

  function renderSectionBanner(section) {
    if (!section.banner) return null;
    var wrap = el("div", "hero-visual cybertech-frame catalog-section-banner");
    var img = document.createElement("img");
    img.src = section.banner;
    img.alt = section.title || section.label || "Catalog section";
    img.loading = "lazy";
    img.decoding = "async";
    wrap.appendChild(img);
    return wrap;
  }

  function renderSection(section) {
    var wrap = el("section", "reveal catalog-section");
    wrap.id = "catalog-" + section.id;
    wrap.appendChild(el("p", "section-label", section.label));
    wrap.appendChild(el("h2", "section-title", section.title));
    var banner = renderSectionBanner(section);
    if (banner) wrap.appendChild(banner);
    if (section.intro) {
      wrap.appendChild(el("p", "section-sub catalog-intro", section.intro));
    }
    var grid = el("div", "shop-grid catalog-grid");
    (section.products || []).forEach(function (product) {
      grid.appendChild(renderProductCard(product));
    });
    wrap.appendChild(grid);
    return wrap;
  }

  function initCatalog() {
    var host = document.getElementById("dropship-catalog");
    if (!host) return;

    cfg().sections.forEach(function (section) {
      host.appendChild(renderSection(section));
    });

    if (typeof window.HPL_initShop === "function") {
      document.querySelectorAll("#dropship-catalog [data-product]").forEach(function (card) {
        var id = card.getAttribute("data-product");
        var product = window.HPL_PRODUCTS && window.HPL_PRODUCTS[id];
        if (product && typeof window.HPL_renderCheckout === "function") {
          window.HPL_renderCheckout(card, product);
        }
      });
    }
  }

  window.HPL_initCatalog = initCatalog;

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initCatalog);
  } else {
    initCatalog();
  }
})();
