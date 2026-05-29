/**
 * Hacker Planet LLC - Bruce-style firmware download hub (about.html)
 */
(function () {
  function cfg() {
    return (
      window.HPL_FIRMWARE || {
        intro: "",
        steps: [],
        trustLine: "",
        manifestUrl: "",
        securityUrl: "",
        cardputerDocsUrl: "",
        packages: [],
      }
    );
  }

  function el(tag, cls, html) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (html != null) node.innerHTML = html;
    return node;
  }

  function renderSteps(root, steps) {
    var row = el("ol", "firmware-steps");
    (steps || []).forEach(function (step) {
      var item = el("li", "firmware-step");
      item.appendChild(el("span", "firmware-step-num", step.num));
      var body = el("div", "firmware-step-body");
      body.appendChild(el("strong", "firmware-step-title", step.title));
      body.appendChild(el("span", "firmware-step-detail", step.detail));
      item.appendChild(body);
      row.appendChild(item);
    });
    root.appendChild(row);
  }

  function renderCard(pkg) {
    var card = el("article", "card card-compact firmware-card");
    card.appendChild(el("div", "card-icon card-accent-" + (pkg.accent || "m5"), "FW"));
    card.appendChild(el("h3", "", pkg.name));
    card.appendChild(el("p", "firmware-card-role", pkg.role || ""));
    card.appendChild(
      el(
        "p",
        "firmware-card-meta muted-inline",
        "Device: <strong>" +
          (pkg.device || "M5 Cardputer") +
          "</strong><br>SD / manifest: <code>" +
          (pkg.sdName || pkg.asset || "") +
          "</code>"
      )
    );

    var actions = el("div", "firmware-card-actions");
    if (pkg.downloadUrl) {
      var dl = el("a", "btn btn-primary", (pkg.ctaLabel || "Download") + " ->");
      dl.href = pkg.downloadUrl;
      dl.target = "_blank";
      dl.rel = "noopener noreferrer";
      actions.appendChild(dl);
    } else if (pkg.releasesUrl) {
      var rel = el("a", "btn btn-primary", (pkg.ctaLabel || "GitHub releases") + " ->");
      rel.href = pkg.releasesUrl;
      rel.target = "_blank";
      rel.rel = "noopener noreferrer";
      actions.appendChild(rel);
    }
    if (pkg.repoUrl) {
      var repo = el("a", "btn btn-ghost", "Source ->");
      repo.href = pkg.repoUrl;
      repo.target = "_blank";
      repo.rel = "noopener noreferrer";
      actions.appendChild(repo);
    }
    card.appendChild(actions);
    return card;
  }

  function render(root) {
    var data = cfg();
    root.innerHTML = "";

    var intro = el("p", "section-sub firmware-intro", data.intro);
    intro.style.maxWidth = "42rem";
    root.appendChild(intro);

    renderSteps(root, data.steps);

    var grid = el("div", "card-grid card-grid-tight firmware-card-grid");
    (data.packages || []).forEach(function (pkg) {
      grid.appendChild(renderCard(pkg));
    });
    root.appendChild(grid);

    if (data.trustLine) {
      var trust = el("p", "firmware-trust muted-inline", data.trustLine);
      root.appendChild(trust);
    }

    var links = el(
      "p",
      "section-sub muted-inline firmware-meta",
      'Manifest: <a href="' +
        data.manifestUrl +
        '" target="_blank" rel="noopener">manifest.example.json</a> | ' +
        '<a href="' +
        data.securityUrl +
        '" target="_blank" rel="noopener">SECURITY.md</a> | ' +
        '<a href="' +
        data.cardputerDocsUrl +
        '">Full Cardputer flash guide</a>'
    );
    links.style.maxWidth = "42rem";
    root.appendChild(links);
  }

  document.addEventListener("DOMContentLoaded", function () {
    var root = document.getElementById("firmware-download-root");
    if (root) render(root);
  });
})();
