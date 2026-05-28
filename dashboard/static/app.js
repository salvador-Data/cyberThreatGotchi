const $ = (id) => document.getElementById(id);

function applySnapshot(data) {
  const g = data.gotchi;
  $("g-name").textContent = g.name;
  $("g-status").textContent = g.status_line;
  $("m-hunger").value = g.hunger;
  $("m-happy").value = g.happiness;
  $("g-level").textContent = g.level;
  $("g-xp").textContent = g.security_xp;
  $("g-blocked").textContent = g.threats_blocked;
  $("g-seen").textContent = g.threats_seen;
  $("sprite").src = `/api/sprite/${g.mood}.png?t=${Date.now()}`;

  const tbody = $("threat-rows");
  tbody.innerHTML = "";
  const threats = data.threats || [];
  if (!threats.length) {
    const tr = document.createElement("tr");
    tr.innerHTML = "<td colspan='5'>Awaiting traffic…</td>";
    tbody.appendChild(tr);
  } else {
    threats.forEach((t) => {
      const tr = document.createElement("tr");
      const sev = (t.severity || "").toLowerCase();
      tr.innerHTML = `
        <td class="sev-${sev}">${t.severity || "?"}</td>
        <td>${t.source_ip || ""}</td>
        <td>${t.category || ""}</td>
        <td>${t.action_taken || ""}</td>
        <td>${(t.description || "").slice(0, 80)}</td>`;
      tbody.appendChild(tr);
    });
  }

  const rt = data.runtime || {};
  $("runtime-info").innerHTML = `
    <li>Mode: <strong>${rt.mode}</strong></li>
    <li>Interface: ${rt.interface || "—"}</li>
    <li>Scanned: ${rt.packets_scanned ?? 0}</li>
    <li>Detected: ${rt.threats_detected ?? 0}</li>
    <li>AV: ${JSON.stringify(rt.av || {})}</li>`;

  const blocks = data.blocks || [];
  $("block-list").innerHTML = blocks.length
    ? blocks.map((b) => `<li>${b.ip} — ${b.reason?.slice(0, 40) || "blocked"}</li>`).join("")
    : "<li>No active blocks</li>";
}

function connectSSE() {
  const es = new EventSource("/api/stream");
  es.onmessage = (ev) => {
    try {
      applySnapshot(JSON.parse(ev.data));
    } catch (e) {
      console.warn(e);
    }
  };
  es.onerror = () => {
    es.close();
    setTimeout(connectSSE, 3000);
  };
}

async function postAction(path) {
  await fetch(path, { method: "POST" });
}

$("btn-feed").addEventListener("click", () => postAction("/api/feed"));
$("btn-pet").addEventListener("click", () => postAction("/api/pet"));

fetch("/api/status")
  .then((r) => r.json())
  .then(applySnapshot)
  .catch(console.error);

connectSSE();
