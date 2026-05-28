/**
 * Hacker Planet LLC — shipping locator / fulfillment status helpers (operator-facing)
 *
 * PCI-safe: builds tracking URLs and checklists only; does not call Etsy/AliExpress APIs or marketplace checkout.
 */
(function (global) {
  "use strict";

  function trackerCfg() {
    return global.HPL_SHIPPING_TRACKER || { products: {}, trackingUrlTemplates: {} };
  }

  function productMeta(stripeKey) {
    var cfg = trackerCfg();
    return (cfg.products && cfg.products[stripeKey]) || null;
  }

  function buildTrackingUrl(carrier, trackingNumber) {
    var templates = trackerCfg().trackingUrlTemplates || {};
    var key = (carrier || "").toLowerCase();
    var tpl = templates[key] || templates.generic || "";
    if (!tpl || !trackingNumber) return "";
    return tpl.replace(/\{tracking\}/g, encodeURIComponent(String(trackingNumber).trim()));
  }

  function leadTimeLabel(stripeKey) {
    var meta = productMeta(stripeKey);
    if (!meta || !meta.leadTimeDays) return "";
    var d = meta.leadTimeDays;
    return d.min + "–" + d.max + " business days";
  }

  function orderChecklist(stripeKey) {
    var meta = productMeta(stripeKey);
    return (meta && meta.orderChecklist) || [];
  }

  function supplierPortalUrl(stripeKey) {
    var meta = productMeta(stripeKey);
    if (!meta) return "";
    var channels = trackerCfg().channels || {};
    var ch = channels[meta.channel];
    if (ch && ch.orderPortal) return ch.orderPortal;
    return meta.supplierUrl || "";
  }

  function fulfillmentStatusOptions() {
    return (trackerCfg().fulfillmentStatuses || []).slice();
  }

  function formatFulfillmentPacket(row) {
    var lines = [
      "Hacker Planet LLC — partner fulfillment order packet",
      "SKU: " + (row.sku || ""),
      "Product: " + (row.productName || ""),
      "Stripe key: " + (row.stripeKey || ""),
      "Retail: $" + (row.retailUsd != null ? row.retailUsd : ""),
      "Est. supplier cost: $" + (row.supplierCostUsd != null ? row.supplierCostUsd : ""),
      "Supplier: " + (row.supplier || ""),
      "Channel: " + (row.channel || ""),
      "Build: " + (row.buildType || ""),
      "Lead time: " + (row.leadTime || ""),
      "Supplier URL: " + (row.supplierUrl || ""),
      "Customer ship-to: " + (row.shipTo || "[from Stripe]"),
      "Fulfillment status: " + (row.status || "ready_to_order"),
      "Tracking: " + (row.tracking || ""),
      "Tracking URL: " + (row.trackingUrl || ""),
      "",
      "Order checklist:",
    ];
    (row.checklist || []).forEach(function (item, i) {
      lines.push("  " + (i + 1) + ". " + item);
    });
    return lines.join("\n");
  }

  global.HPLShippingTracker = {
    productMeta: productMeta,
    buildTrackingUrl: buildTrackingUrl,
    leadTimeLabel: leadTimeLabel,
    orderChecklist: orderChecklist,
    supplierPortalUrl: supplierPortalUrl,
    fulfillmentStatusOptions: fulfillmentStatusOptions,
    formatFulfillmentPacket: formatFulfillmentPacket,
  };
})(typeof window !== "undefined" ? window : globalThis);
