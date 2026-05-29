/**
 * Hacker Planet LLC - unified firmware download table (about.html)
 */
(function () {
  function cfg() {
    return (
      window.HPL_FIRMWARE || {
        intro: "",
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

  function downloadCell(pkg) {
    if (pkg.downloadUrl) {
      var a = el("a", "firmware-dl-link", "Download " + pkg.asset + " ->");
      a.href = pkg.downloadUrl;
      a.target = "_blank";
      a.rel = "noopener noreferrer";
      return a;
    }
    var span = el("span", "muted-inline", "Tagged releases on GitHub");
    if (pkg.releasesUrl) {
      var rel = el("a", "", "Releases ->");
      rel.href = pkg.releasesUrl;
      rel.target = "_blank";
      rel.rel = "noopener noreferrer";
      span.appendChild(document.createTextNode(" "));
      span.appendChild(rel);
    }
    return span;
  }

  function render(root) {
    var data = cfg();
    root.innerHTML = "";

    var intro = el("p", "section-sub firmware-intro", data.intro);
    intro.style.maxWidth = "42rem";
    root.appendChild(intro);

    var links = el(
      "p",
      "section-sub muted-inline firmware-meta",
      'M5 OS manifest template: <a href="' +
        data.manifestUrl +
        '" target="_blank" rel="noopener">manifest.example.json</a> | ' +
        '<a href="' +
        data.securityUrl +
        '" target="_blank" rel="noopener">SECURITY.md</a> | ' +
        '<a href="' +
        data.cardputerDocsUrl +
        '">Cardputer flash guide</a>'
    );
    links.style.maxWidth = "42rem";
    root.appendChild(links);

    var scroll = el("div", "table-scroll");
    var table = el("table", "pricing-table firmware-table");
    table.innerHTML =
      "<thead><tr>" +
      "<th>Package</th>" +
      "<th>Device</th>" +
      "<th>SD / manifest name</th>" +
      "<th>Download</th>" +
      "<th>Source</th>" +
      "</tr></thead>";
    var tbody = el("tbody");

    (data.packages || []).forEach(function (pkg) {
      var tr = el("tr");
      tr.appendChild(
        el(
          "td",
          "",
          "<strong>" +
            pkg.name +
            "</strong><br><span class=\"muted-inline\">" +
            (pkg.role || "") +
            "</span>"
        )
      );
      tr.appendChild(el("td", "", pkg.device || ""));
      tr.appendChild(el("td", "", "<code>" + (pkg.sdName || pkg.asset || "") + "</code>"));
      var dlTd = el("td", "");
      dlTd.appendChild(downloadCell(pkg));
      tr.appendChild(dlTd);
      var src = el("td", "");
      if (pkg.repoUrl) {
        var repo = el("a", "", "GitHub ->");
        repo.href = pkg.repoUrl;
        repo.target = "_blank";
        repo.rel = "noopener noreferrer";
        src.appendChild(repo);
      }
      tr.appendChild(src);
      tbody.appendChild(tr);
    });

    table.appendChild(tbody);
    scroll.appendChild(table);
    root.appendChild(scroll);
  }

  document.addEventListener("DOMContentLoaded", function () {
    var root = document.getElementById("firmware-download-root");
    if (root) render(root);
  });
})();
