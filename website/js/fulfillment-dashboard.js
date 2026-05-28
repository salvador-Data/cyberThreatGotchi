/**
 * Hacker Planet LLC — operator fulfillment dashboard helpers
 * PCI-safe: queue display, clipboard, status updates — no marketplace checkout automation.
 */
(function (global) {
  "use strict";

  var STATUS_LABELS = {
    pending: "Pending — place supplier order",
    ordered: "Ordered at supplier",
    shipped: "Shipped",
    delivered: "Delivered",
    exception: "Exception / RMA",
  };

  function escapeHtml(text) {
    return String(text || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function formatShipTo(order) {
    if (order.ship_to_text) return order.ship_to_text;
    var s = order.ship_to || {};
    var lines = [];
    if (s.name) lines.push(s.name);
    if (s.line1) lines.push(s.line1);
    if (s.line2) lines.push(s.line2);
    var cityLine = [s.city, s.state, s.postal_code].filter(Boolean).join(", ");
    if (cityLine) lines.push(cityLine);
    if (s.country && s.country !== "US") lines.push(s.country);
    return lines.join("\n");
  }

  function copyToClipboard(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(text);
    }
    return new Promise(function (resolve, reject) {
      try {
        var ta = document.createElement("textarea");
        ta.value = text;
        ta.setAttribute("readonly", "");
        ta.style.position = "absolute";
        ta.style.left = "-9999px";
        document.body.appendChild(ta);
        ta.select();
        document.execCommand("copy");
        document.body.removeChild(ta);
        resolve();
      } catch (err) {
        reject(err);
      }
    });
  }

  function statusClass(status) {
    return "status-pill status-" + (status || "pending");
  }

  function buildTrackingUrl(order, carrier, trackingNumber) {
    var trk = global.HPLShippingTracker;
    if (!trk) return order.tracking_url || "";
    if (order.tracking_url) return order.tracking_url;
    return trk.buildTrackingUrl(carrier || "generic", trackingNumber || order.tracking_number);
  }

  function renderOrderCard(order) {
    var trk = global.HPLShippingTracker || {};
    var checklist = order.checklist || trk.orderChecklist(order.stripe_key) || [];
    var supplierUrl = order.supplier_url || "";
    var shipText = formatShipTo(order);
    var status = order.status || "pending";
    var statusOpts = ["pending", "ordered", "shipped", "delivered", "exception"];

    var checklistHtml = checklist
      .map(function (item) {
        return "<li>" + escapeHtml(item) + "</li>";
      })
      .join("");

    var optHtml = statusOpts
      .map(function (s) {
        return (
          '<option value="' +
          s +
          '"' +
          (s === status ? " selected" : "") +
          ">" +
          escapeHtml(STATUS_LABELS[s] || s) +
          "</option>"
        );
      })
      .join("");

    return (
      '<article class="order-card" data-order-id="' +
      escapeHtml(order.id) +
      '">' +
      "<h3>" +
      escapeHtml(order.product_name || order.stripe_key) +
      "</h3>" +
      '<div class="order-meta">' +
      '<span class="' +
      statusClass(status) +
      '">' +
      escapeHtml(STATUS_LABELS[status] || status) +
      "</span>" +
      "<span>SKU: <code>" +
      escapeHtml(order.stripe_key) +
      "</code></span>" +
      (order.retail_usd != null ? "<span>Retail: $" + escapeHtml(order.retail_usd) + "</span>" : "") +
      (order.supplier ? "<span>Supplier: " + escapeHtml(order.supplier) + "</span>" : "") +
      (order.channel ? "<span>Channel: " + escapeHtml(order.channel) + "</span>" : "") +
      "</div>" +
      '<div class="btn-row">' +
      (supplierUrl
        ? '<a href="' +
          escapeHtml(supplierUrl) +
          '" target="_blank" rel="noopener noreferrer">Open supplier listing ↗</a>'
        : "") +
      '<button type="button" class="copy-ship">Copy ship-to</button>' +
      '<button type="button" class="copy-packet">Copy order packet</button>' +
      "</div>" +
      '<div class="ship-block" aria-label="Ship to">' +
      escapeHtml(shipText || "[no address — paste from Stripe]") +
      "</div>" +
      (checklist.length ? '<ol class="checklist">' + checklistHtml + "</ol>" : "") +
      '<div class="update-row">' +
      '<div><label>Status<select class="order-status">' +
      optHtml +
      "</select></label></div>" +
      '<div><label>Tracking URL<input class="tracking-url" type="url" placeholder="https://..." value="' +
      escapeHtml(order.tracking_url || "") +
      '"/></label></div>' +
      '<button type="button" class="save-status primary">Save</button>' +
      "</div>" +
      (order.supplier_order_id
        ? '<p style="font-size:0.8rem;opacity:0.8;margin-top:0.5rem">Supplier order ID: ' +
          escapeHtml(order.supplier_order_id) +
          "</p>"
        : "") +
      "</article>"
    );
  }

  function authHeaders(token) {
    var headers = { Accept: "application/json" };
    if (token) headers.Authorization = "Bearer " + token;
    return headers;
  }

  function fetchQueue(apiBase, token) {
    return fetch(apiBase.replace(/\/$/, "") + "/api/fulfillment/queue?pending=true", {
      headers: authHeaders(token),
    }).then(function (resp) {
      if (!resp.ok) throw new Error("API " + resp.status);
      return resp.json();
    });
  }

  function patchOrder(apiBase, token, orderId, body) {
    return fetch(apiBase.replace(/\/$/, "") + "/api/fulfillment/queue/" + encodeURIComponent(orderId), {
      method: "PATCH",
      headers: Object.assign({ "Content-Type": "application/json" }, authHeaders(token)),
      body: JSON.stringify(body),
    }).then(function (resp) {
      if (!resp.ok) throw new Error("Update failed " + resp.status);
      return resp.json();
    });
  }

  function bindDashboard() {
    var apiBaseEl = document.getElementById("api-base");
    var tokenEl = document.getElementById("api-token");
    var listEl = document.getElementById("order-list");
    var statusEl = document.getElementById("status-msg");
    var refreshBtn = document.getElementById("btn-refresh");

    if (!apiBaseEl || !listEl) return;

    if (!apiBaseEl.value) {
      apiBaseEl.value = global.location.origin;
    }

    function setStatus(msg, isError) {
      if (!statusEl) return;
      statusEl.textContent = msg || "";
      statusEl.style.color = isError ? "#ef5350" : "";
    }

    function loadQueue() {
      setStatus("Loading…");
      fetchQueue(apiBaseEl.value, tokenEl.value)
        .then(function (data) {
          var orders = data.orders || [];
          if (!orders.length) {
            listEl.innerHTML = '<p class="empty-state">No pending drop-ship orders in queue.</p>';
          } else {
            listEl.innerHTML = orders.map(renderOrderCard).join("");
          }
          setStatus(orders.length + " order(s) loaded.");
        })
        .catch(function (err) {
          listEl.innerHTML = "";
          setStatus(err.message || "Failed to load queue", true);
        });
    }

    listEl.addEventListener("click", function (ev) {
      var card = ev.target.closest(".order-card");
      if (!card) return;
      var orderId = card.getAttribute("data-order-id");

      if (ev.target.classList.contains("copy-ship")) {
        var shipBlock = card.querySelector(".ship-block");
        var ship = shipBlock ? shipBlock.textContent : "";
        copyToClipboard(ship.trim())
          .then(function () {
            setStatus("Ship-to copied.");
          })
          .catch(function () {
            setStatus("Clipboard failed — select text manually.", true);
          });
        return;
      }

      if (ev.target.classList.contains("copy-packet")) {
        var title = card.querySelector("h3");
        var shipBlock = card.querySelector(".ship-block");
        var trk = global.HPLShippingTracker;
        var packet = trk
          ? trk.formatFulfillmentPacket({
              sku: orderId,
              productName: title ? title.textContent : "",
              stripeKey: card.querySelector("code") ? card.querySelector("code").textContent : "",
              shipTo: shipBlock ? shipBlock.textContent : "",
              status: card.querySelector(".order-status") ? card.querySelector(".order-status").value : "",
              checklist: [],
            })
          : shipBlock ? shipBlock.textContent : "";
        copyToClipboard(packet).then(function () {
          setStatus("Order packet copied.");
        });
        return;
      }

      if (ev.target.classList.contains("save-status")) {
        var statusSel = card.querySelector(".order-status");
        var trackingInput = card.querySelector(".tracking-url");
        var body = {
          status: statusSel ? statusSel.value : "pending",
          tracking_url: trackingInput ? trackingInput.value.trim() : "",
        };
        if (body.tracking_url) {
          var num = body.tracking_url.split("/").pop() || "";
          body.tracking_number = num;
        }
        setStatus("Saving…");
        patchOrder(apiBaseEl.value, tokenEl.value, orderId, body)
          .then(function () {
            setStatus("Order updated.");
            loadQueue();
          })
          .catch(function (err) {
            setStatus(err.message || "Save failed", true);
          });
      }
    });

    refreshBtn.addEventListener("click", loadQueue);
    loadQueue();
  }

  global.HPLFulfillmentDashboard = {
    escapeHtml: escapeHtml,
    formatShipTo: formatShipTo,
    copyToClipboard: copyToClipboard,
    statusClass: statusClass,
    buildTrackingUrl: buildTrackingUrl,
    renderOrderCard: renderOrderCard,
    fetchQueue: fetchQueue,
    patchOrder: patchOrder,
    STATUS_LABELS: STATUS_LABELS,
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", bindDashboard);
  } else {
    bindDashboard();
  }
})(typeof window !== "undefined" ? window : globalThis);
