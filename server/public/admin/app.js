// StitchMind — painel admin (SPA vanilla)
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const main = $("#main");

// ─── Auth: login admin próprio (email + senha) ──────────────────────
let TOKEN = localStorage.getItem("sm_admin_jwt") || null;
window.TOKEN = TOKEN;
async function getToken() { return TOKEN; }

async function api(path, opts = {}) {
  const token = await getToken();
  const res = await fetch("/v1" + path, {
    ...opts,
    headers: {
      ...(opts.body && !(opts.body instanceof FormData) ? { "Content-Type": "application/json" } : {}),
      ...(token ? { Authorization: "Bearer " + token } : {}),
      ...(opts.headers || {}),
    },
  });
  if (!res.ok) {
    // Sessão expirada/inválida → limpa o token e volta para o login.
    if (res.status === 401 && TOKEN) {
      TOKEN = null; window.TOKEN = null;
      localStorage.removeItem("sm_admin_jwt");
      try { showLogin(); } catch (_) {}
      throw new Error("Sessão expirada. Entre novamente.");
    }
    const e = await res.json().catch(() => ({}));
    throw new Error(e.error ? JSON.stringify(e.error) : "HTTP " + res.status);
  }
  return res.json();
}

function esc(s) { return String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])); }
function fmtDate(s) { return s ? new Date(s).toLocaleString("pt-BR") : "—"; }
function pct(v) { return Math.round(v || 0) + "%"; }

// ─── Ícones (SVG inline, traço em currentColor) ─────────────────────
const _P = (d) => `<svg class="ic" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
const ICONS = {
  overview: _P('<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/>'),
  live: _P('<circle cx="12" cy="12" r="2"/><path d="M16.24 7.76a6 6 0 0 1 0 8.49M7.76 16.24a6 6 0 0 1 0-8.49M19.07 4.93a10 10 0 0 1 0 14.14M4.93 19.07a10 10 0 0 1 0-14.14"/>'),
  lessons: _P('<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>'),
  tips: _P('<path d="M9 18h6M10 22h4"/><path d="M12 2a7 7 0 0 0-4 12.7c.6.5 1 1.3 1 2.1V18h6v-1.2c0-.8.4-1.6 1-2.1A7 7 0 0 0 12 2z"/>'),
  community: _P('<path d="M21 11.5a8.5 8.5 0 0 1-8.5 8.5 8.4 8.4 0 0 1-3.8-.9L3 21l1.9-5.7a8.4 8.4 0 0 1-.9-3.8A8.5 8.5 0 1 1 21 11.5z"/>'),
  users: _P('<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>'),
  notifications: _P('<path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/>'),
  analytics: _P('<path d="M23 6l-9.5 9.5-5-5L1 18"/><path d="M17 6h6v6"/>'),
  crashes: _P('<rect x="8" y="6" width="8" height="13" rx="4"/><path d="M19 8l-3 1.5M5 8l3 1.5M3 13h3M18 13h3M5 18l3-1.5M19 18l-3-1.5M12 19v2"/>'),
  ai: _P('<path d="M12 3l1.8 4.4L18.5 9l-4.7 1.6L12 15l-1.8-4.4L5.5 9l4.7-1.6z"/><path d="M19 14l.7 1.8 1.8.7-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.7z"/>'),
  chevron: _P('<path d="M6 9l6 6 6-6"/>'),
  random: _P('<path d="M16 3h5v5M21 3l-7 7M4 20l5-5M16 21h5v-5M15 15l6 6M4 4l5 5"/>'),
  clock: _P('<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>'),
  lock: _P('<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>'),
  send: _P('<path d="M22 2L11 13M22 2l-7 20-4-9-9-4z"/>'),
  yarn: _P('<circle cx="12" cy="12" r="9"/><path d="M5.2 9c4.4 2.2 9.2 2.2 13.6 0M4 13c5.2 3 10.8 3 16 0M8.5 4c2 5.2 2 10.8 0 16M14 4c-1.2 5.2-1.2 10.8 0 16"/>'),
  enter: _P('<path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4M10 17l5-5-5-5M15 12H3"/>'),
};
function icon(name, extra) { const s = ICONS[name] || ""; return extra ? s.replace('class="ic"', 'class="ic ' + extra + '"') : s; }

// ─── Auth: tela de login dedicada ───────────────────────────────────
let currentUser = null;
let CURRENT_ROLE = "admin"; // papel no painel: admin | editor

// Editor só enxerga conteúdo; o resto é só para admin.
const EDITOR_VIEWS = new Set(["lessons", "patterns", "stitches", "tips", "posts"]);
// Métricas redundantes com o Firebase Analytics saíram do painel; todo mundo
// entra direto no conteúdo (Aulas).
function defaultView() { return "lessons"; }
function applyRole() {
  $$("#nav a[data-view]").forEach((a) => {
    const allowed = CURRENT_ROLE !== "editor" || EDITOR_VIEWS.has(a.dataset.view);
    a.style.display = allowed ? "" : "none";
  });
  // esconde seções do nav que ficaram sem itens visíveis
  $$(".nav-group").forEach((g) => {
    const vis = [...g.querySelectorAll("a[data-view]")].some((a) => a.style.display !== "none");
    g.style.display = vis ? "" : "none";
  });
}

function showLogin() {
  $("#login-screen").style.display = "flex";
  $("#panel").style.display = "none";
}
function showPanel(user) {
  currentUser = user;
  CURRENT_ROLE = (user && user.panel_role) || "admin";
  applyRole();
  $("#login-screen").style.display = "none";
  $("#panel").style.display = "flex";
  const name = user?.name || user?.email || "admin";
  $("#user-name").textContent = name;
  $(".user-avatar").textContent = (name[0] || "A").toUpperCase();
}

async function checkAuth() {
  try {
    const r = await api("/auth/me");
    if (r.user.role !== "admin") return false;
    currentUser = r.user;
    return true;
  } catch (_) {
    return false;
  }
}

$("#login-form").addEventListener("submit", async (ev) => {
  ev.preventDefault();
  const email = $("#adm-email").value.trim();
  const password = $("#adm-pass").value;
  const btn = $("#adm-signin"), err = $("#login-error");
  err.textContent = "";
  btn.disabled = true; btn.textContent = "Entrando…";
  try {
    const res = await fetch("/v1/auth/admin-login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || "Falha no login");
    TOKEN = data.token;
    window.TOKEN = TOKEN;
    localStorage.setItem("sm_admin_jwt", TOKEN);
    $("#adm-pass").value = "";
    showPanel(data.user);
    render(defaultView());
  } catch (e) {
    err.textContent = e.message;
  } finally {
    btn.disabled = false; btn.textContent = "Entrar";
  }
});

$("#adm-signout").onclick = () => {
  TOKEN = null; window.TOKEN = null; currentUser = null;
  localStorage.removeItem("sm_admin_jwt");
  showLogin();
};

async function initAuth() {
  if (TOKEN && (await checkAuth())) {
    showPanel(currentUser);
    render(defaultView());
  } else {
    showLogin();
  }
}

// ─── Router ─────────────────────────────────────────────────────────
let currentView = "overview";
$$("#nav a").forEach((a) =>
  (a.onclick = () => {
    $$("#nav a").forEach((x) => x.classList.remove("active"));
    a.classList.add("active");
    currentView = a.dataset.view;
    render(currentView);
  }),
);

// Injeta o ícone SVG de cada item do nav (de data-icon).
$$("#nav a[data-icon]").forEach((a) => {
  a.insertAdjacentHTML("afterbegin", `${icon(a.dataset.icon)}<span class="nav-label">${a.textContent.trim()}</span>`);
  // remove o texto cru solto (sobrou fora do span)
  [...a.childNodes].forEach((n) => { if (n.nodeType === 3) a.removeChild(n); });
});

// Recolher/expandir seções (a setinha). Estado lembrado no localStorage.
const COLLAPSED = JSON.parse(localStorage.getItem("sm_nav_collapsed") || "{}");
$$(".nav-section").forEach((btn) => {
  const group = btn.dataset.group;
  if (group && COLLAPSED[group]) btn.closest(".nav-group").classList.add("collapsed");
  btn.onclick = () => {
    const g = btn.closest(".nav-group");
    g.classList.toggle("collapsed");
    if (group) {
      COLLAPSED[group] = g.classList.contains("collapsed");
      localStorage.setItem("sm_nav_collapsed", JSON.stringify(COLLAPSED));
    }
  };
});

const views = {};
let liveSocket = null; // WebSocket da aba "Ao vivo"
function closeLive() {
  if (liveSocket) {
    try { liveSocket.close(); } catch (_) {}
    liveSocket = null;
  }
}
async function render(view) {
  closeLive();
  main.innerHTML = '<div class="loading">Carregando…</div>';
  try {
    await views[view]();
  } catch (e) {
    main.innerHTML = `<h1>Erro</h1><div class="card">${esc(e.message)}</div>
      <div class="sub">Confira o token admin na barra lateral.</div>`;
  }
}

// ─── "Aba dentro da aba": Analytics agrupa 4 sub-views em sub-abas ───
const PRODUCT_SUBTABS = [
  { key: "analytics", label: "Telas & eventos" },
  { key: "heatmap", label: "Heatmaps" },
  { key: "replay", label: "Replay" },
  { key: "insights", label: "Insights" },
];
let productSub = "analytics";

window.showProductSub = async (key) => {
  productSub = key;
  closeLive();
  main.innerHTML = '<div class="loading">Carregando…</div>';
  try {
    await views[key](); // a sub-view preenche o #main normalmente
  } catch (e) {
    main.innerHTML = `<div class="card">${esc(e.message)}</div>`;
  }
  // injeta a barra de sub-abas no topo (acima do conteúdo da sub-view)
  const bar = `<div class="subtabs">${PRODUCT_SUBTABS.map((t) =>
    `<button class="subtab${t.key === productSub ? " active" : ""}" onclick="showProductSub('${t.key}')">${t.label}</button>`,
  ).join("")}</div>`;
  main.insertAdjacentHTML("afterbegin", bar);
};

views.product = async () => { await window.showProductSub(productSub); };

// ─── Notificações push (envio, agendadas, lista aleatória) ──────────
const DOW_LABELS = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"];

function schedDesc(s) {
  if (s.schedule_kind === "once") return "Uma vez · " + fmtDate(s.send_at);
  if (s.schedule_kind === "daily") return "Diária · " + (s.time_of_day || "");
  if (s.schedule_kind === "weekly") {
    const days = (s.days_of_week || []).map((d) => DOW_LABELS[d]).join(", ");
    return `Semanal (${days}) · ${s.time_of_day || ""}`;
  }
  if (s.schedule_kind === "interval") return `A cada ${s.interval_minutes} min`;
  return s.schedule_kind;
}

views.notifications = async () => {
  const [data, usersRes] = await Promise.all([
    api("/admin/notifications"),
    api("/admin/users"),
  ]);
  const { configured, history, scheduled, pool, regions, total_tokens } = data;
  const users = usersRes.users || [];

  const regionOpts = regions
    .map((r) => `<option value="${esc(r.country)}">${esc(r.country)} (${r.devices} aparelho${r.devices === 1 ? "" : "s"})</option>`)
    .join("") || `<option value="">(sem regiões registradas)</option>`;
  const userOpts = users
    .map((u) => `<option value="${u.id}">${esc(u.name || u.email || u.id)}</option>`)
    .join("");

  const warn = configured
    ? ""
    : `<div class="card" style="border-left:4px solid #e0a23a;background:#fff8ec;margin-bottom:14px">
        <b>Push ainda não configurado no servidor.</b> Falta o service account do
        Firebase (env <code>FIREBASE_SERVICE_ACCOUNT</code>).</div>`;

  // alvo (compartilhado entre "enviar agora" e "agendar")
  const targetBlock = (p) => `
      <label class="lbl">Enviar para</label>
      <select class="field" id="${p}-target">
        <option value="all">Todos os usuários</option>
        <option value="region">Por região (país)</option>
        <option value="user">Um usuário específico</option>
      </select>
      <div id="${p}-region-wrap" style="display:none">
        <label class="lbl">Região</label>
        <select class="field" id="${p}-region">${regionOpts}</select>
      </div>
      <div id="${p}-user-wrap" style="display:none">
        <label class="lbl">Usuário</label>
        <select class="field" id="${p}-user">${userOpts}</select>
      </div>`;

  const msgBlock = (p) => `
      <label class="lbl"><input type="checkbox" id="${p}-pool" style="width:auto">${icon('random')} Usar mensagem aleatória da lista</label>
      <div id="${p}-msg-wrap">
        <label class="lbl">Título</label>
        <input class="field" id="${p}-title" maxlength="120" placeholder="Novidade no StitchMind" />
        <label class="lbl">Mensagem</label>
        <textarea class="field" id="${p}-body" maxlength="500" placeholder="Conte o que há de novo…"></textarea>
      </div>`;

  const schedRows = scheduled
    .map((s) => `<tr>
      <td><b>${s.use_pool ? icon('random') + " aleatória" : esc(s.title || "")}</b>${s.use_pool ? "" : `<div class="sub">${esc((s.body || "").slice(0, 60))}</div>`}</td>
      <td>${esc(s.target_type)}${s.target_value ? " · " + esc(s.target_value) : ""}</td>
      <td>${esc(schedDesc(s))}</td>
      <td class="sub">${s.enabled ? fmtDate(s.next_run_at) : "—"}</td>
      <td class="sub">${fmtDate(s.last_sent_at)}</td>
      <td>${s.enabled ? '<span class="badge ok">ativa</span>' : '<span class="badge draft">pausada</span>'}</td>
      <td>
        <button class="btn ghost sm" onclick="schedToggle('${s.id}', ${!s.enabled})">${s.enabled ? "Pausar" : "Ativar"}</button>
        <button class="btn ghost sm" onclick="schedDelete('${s.id}')">Excluir</button>
      </td>
    </tr>`)
    .join("") || `<tr><td colspan="7" class="sub">Nenhum agendamento ainda.</td></tr>`;

  const poolRows = pool
    .map((m) => `<tr>
      <td><b>${esc(m.title)}</b></td>
      <td class="sub">${esc(m.body)}</td>
      <td>${m.enabled ? '<span class="badge ok">ativa</span>' : '<span class="badge draft">pausada</span>'}</td>
      <td>
        <button class="btn ghost sm" onclick="poolToggle('${m.id}', ${!m.enabled})">${m.enabled ? "Pausar" : "Ativar"}</button>
        <button class="btn ghost sm" onclick="poolDelete('${m.id}')">Excluir</button>
      </td>
    </tr>`)
    .join("") || `<tr><td colspan="4" class="sub">Lista vazia — adicione mensagens abaixo.</td></tr>`;

  const histRows = history
    .map((h) => `<tr>
      <td><b>${esc(h.title)}</b>${h.from_schedule ? ' ' + icon('clock', 'ic-sm') : ""}</td>
      <td class="sub">${esc(h.body)}</td>
      <td>${esc(h.target_type)}${h.target_value ? " · " + esc(h.target_value) : ""}</td>
      <td>${h.sent_count}</td>
      <td class="sub">${fmtDate(h.created_at)}</td>
    </tr>`)
    .join("") || `<tr><td colspan="5" class="sub">Nada enviado ainda.</td></tr>`;

  main.innerHTML = `<h1>Notificações push</h1>
    <div class="sub" style="margin-bottom:14px">${total_tokens} aparelho(s) com push ativo · servidor: ${configured ? '<span class="badge ok">configurado</span>' : '<span class="badge warn">não configurado</span>'}.</div>
    ${warn}

    <div class="row" style="align-items:flex-start;gap:16px;flex-wrap:wrap">
      <div class="card" style="flex:1;min-width:340px;max-width:520px">
        <h2 style="margin-top:0;font-size:15px">Enviar agora</h2>
        ${msgBlock("n")}
        ${targetBlock("n")}
        <div id="n-status" class="sub" style="margin-top:10px"></div>
        <div class="row" style="margin-top:14px"><button class="btn" id="n-send">Enviar agora</button></div>
      </div>

      <div class="card" style="flex:1;min-width:340px;max-width:520px">
        <h2 style="margin-top:0;font-size:15px">Agendar envio</h2>
        ${msgBlock("s")}
        ${targetBlock("s")}
        <label class="lbl">Quando</label>
        <select class="field" id="s-kind">
          <option value="once">Uma vez (data e hora)</option>
          <option value="daily">Todos os dias (horário)</option>
          <option value="weekly">Dias da semana (horário)</option>
          <option value="interval">A cada X minutos</option>
        </select>
        <div id="s-once-wrap">
          <label class="lbl">Data e hora</label>
          <input class="field" id="s-sendat" type="datetime-local" />
        </div>
        <div id="s-time-wrap" style="display:none">
          <label class="lbl">Horário</label>
          <input class="field" id="s-time" type="time" value="12:00" />
        </div>
        <div id="s-days-wrap" style="display:none">
          <label class="lbl">Dias</label>
          <div class="row" style="gap:8px;flex-wrap:wrap">
            ${DOW_LABELS.map((d, i) => `<label class="lbl" style="margin:0"><input type="checkbox" class="s-day" value="${i}" style="width:auto"> ${d}</label>`).join("")}
          </div>
        </div>
        <div id="s-interval-wrap" style="display:none">
          <label class="lbl">Intervalo (minutos)</label>
          <input class="field" id="s-minutes" type="number" min="1" placeholder="120" />
        </div>
        <div class="sub" style="margin-top:6px">Fuso: América/São Paulo</div>
        <div id="s-status" class="sub" style="margin-top:10px"></div>
        <div class="row" style="margin-top:14px"><button class="btn" id="s-save">Agendar</button></div>
      </div>
    </div>

    <h2 style="margin-top:26px;font-size:15px">Agendadas e recorrentes</h2>
    <div class="card"><table class="tbl">
      <thead><tr><th>Mensagem</th><th>Alvo</th><th>Recorrência</th><th>Próximo envio</th><th>Último</th><th>Status</th><th></th></tr></thead>
      <tbody>${schedRows}</tbody></table></div>

    <h2 style="margin-top:26px;font-size:15px">Lista de mensagens (sorteio aleatório)</h2>
    <div class="card">
      <div class="row" style="gap:10px;align-items:flex-end;flex-wrap:wrap">
        <div style="flex:1;min-width:160px"><label class="lbl">Título</label><input class="field" id="p-title" maxlength="120" /></div>
        <div style="flex:2;min-width:220px"><label class="lbl">Mensagem</label><input class="field" id="p-body" maxlength="500" /></div>
        <button class="btn" id="p-add">Adicionar</button>
      </div>
      <div id="p-status" class="sub" style="margin-top:8px"></div>
      <table class="tbl" style="margin-top:12px">
        <thead><tr><th>Título</th><th>Mensagem</th><th>Status</th><th></th></tr></thead>
        <tbody>${poolRows}</tbody></table>
    </div>

    <h2 style="margin-top:26px;font-size:15px">Histórico</h2>
    <div class="card"><table class="tbl">
      <thead><tr><th>Título</th><th>Mensagem</th><th>Alvo</th><th>Enviadas</th><th>Quando</th></tr></thead>
      <tbody>${histRows}</tbody></table></div>`;

  // ── comportamento dos formulários ──
  const wireTarget = (p) => {
    const sel = $(`#${p}-target`);
    sel.onchange = () => {
      $(`#${p}-region-wrap`).style.display = sel.value === "region" ? "" : "none";
      $(`#${p}-user-wrap`).style.display = sel.value === "user" ? "" : "none";
    };
  };
  const wirePool = (p) => {
    const cb = $(`#${p}-pool`);
    cb.onchange = () => {
      $(`#${p}-msg-wrap`).style.display = cb.checked ? "none" : "";
    };
  };
  wireTarget("n"); wireTarget("s"); wirePool("n"); wirePool("s");

  const targetOf = (p) => {
    const t = $(`#${p}-target`).value;
    return {
      target_type: t,
      target_value: t === "region" ? $(`#${p}-region`).value
        : t === "user" ? $(`#${p}-user`).value : undefined,
    };
  };

  $("#s-kind").onchange = () => {
    const k = $("#s-kind").value;
    $("#s-once-wrap").style.display = k === "once" ? "" : "none";
    $("#s-time-wrap").style.display = (k === "daily" || k === "weekly") ? "" : "none";
    $("#s-days-wrap").style.display = k === "weekly" ? "" : "none";
    $("#s-interval-wrap").style.display = k === "interval" ? "" : "none";
  };

  // enviar agora
  $("#n-send").onclick = async () => {
    const btn = $("#n-send");
    const usePool = $("#n-pool").checked;
    const title = $("#n-title").value.trim();
    const body = $("#n-body").value.trim();
    if (!usePool && (!title || !body)) {
      $("#n-status").textContent = "Preencha título e mensagem (ou use a lista).";
      return;
    }
    btn.disabled = true;
    $("#n-status").textContent = "Enviando…";
    try {
      const res = await api("/admin/notifications", {
        method: "POST",
        body: JSON.stringify({ title, body, use_pool: usePool, ...targetOf("n") }),
      });
      if (!res.configured) {
        $("#n-status").textContent = `${res.error || "Push não configurado no servidor."}`;
      } else if (!res.sent) {
        $("#n-status").textContent = `0 enviadas de ${res.candidates} aparelho(s).${res.error ? " Motivo: " + res.error : ""}`;
      } else {
        $("#n-status").textContent = `Enviadas: ${res.sent} (de ${res.candidates} aparelho(s), ${res.failed} falha(s)).`;
      }
      btn.disabled = false;
      setTimeout(() => render("notifications"), 1600);
    } catch (e) {
      btn.disabled = false;
      $("#n-status").textContent = "Erro: " + e.message;
    }
  };

  // agendar
  $("#s-save").onclick = async () => {
    const btn = $("#s-save");
    const kind = $("#s-kind").value;
    const usePool = $("#s-pool").checked;
    const payload = {
      title: $("#s-title").value.trim() || undefined,
      body: $("#s-body").value.trim() || undefined,
      use_pool: usePool,
      schedule_kind: kind,
      ...targetOf("s"),
    };
    if (kind === "once") {
      const v = $("#s-sendat").value;
      if (!v) { $("#s-status").textContent = "Informe a data e hora."; return; }
      payload.send_at = new Date(v).toISOString();
    }
    if (kind === "daily" || kind === "weekly") payload.time_of_day = $("#s-time").value;
    if (kind === "weekly") {
      payload.days_of_week = $$(".s-day").filter((x) => x.checked).map((x) => Number(x.value));
    }
    if (kind === "interval") payload.interval_minutes = Number($("#s-minutes").value) || 0;

    btn.disabled = true;
    $("#s-status").textContent = "Agendando…";
    try {
      await api("/admin/notifications/schedule", { method: "POST", body: JSON.stringify(payload) });
      render("notifications");
    } catch (e) {
      btn.disabled = false;
      $("#s-status").textContent = "Erro: " + e.message;
    }
  };

  // lista (pool)
  $("#p-add").onclick = async () => {
    const title = $("#p-title").value.trim();
    const body = $("#p-body").value.trim();
    if (!title || !body) { $("#p-status").textContent = "Preencha título e mensagem."; return; }
    try {
      await api("/admin/notifications/pool", { method: "POST", body: JSON.stringify({ title, body }) });
      render("notifications");
    } catch (e) {
      $("#p-status").textContent = "Erro: " + e.message;
    }
  };
};

window.schedToggle = async (id, enabled) => {
  try {
    await api(`/admin/notifications/schedule/${id}`, { method: "PATCH", body: JSON.stringify({ enabled }) });
    render("notifications");
  } catch (e) { alert("Erro: " + e.message); }
};
window.schedDelete = async (id) => {
  if (!confirm("Excluir este agendamento?")) return;
  try {
    await api(`/admin/notifications/schedule/${id}`, { method: "DELETE" });
    render("notifications");
  } catch (e) { alert("Erro: " + e.message); }
};
window.poolToggle = async (id, enabled) => {
  try {
    await api(`/admin/notifications/pool/${id}`, { method: "PATCH", body: JSON.stringify({ enabled }) });
    render("notifications");
  } catch (e) { alert("Erro: " + e.message); }
};
window.poolDelete = async (id) => {
  if (!confirm("Excluir esta mensagem da lista?")) return;
  try {
    await api(`/admin/notifications/pool/${id}`, { method: "DELETE" });
    render("notifications");
  } catch (e) { alert("Erro: " + e.message); }
};

// ─── Overview ───────────────────────────────────────────────────────
views.overview = async () => {
  const d = await api("/admin/overview");
  const kpi = (label, value, cls = "") =>
    `<div class="kpi"><div class="label">${label}</div><div class="value ${cls}">${value}</div></div>`;
  const screenRows = d.top_screens.map((s) => `<tr><td>${esc(s.screen)}</td><td>${s.n}</td></tr>`).join("") || `<tr><td colspan=2 class="empty">sem dados ainda</td></tr>`;
  const lessonRows = d.top_lessons.map((l) => `<tr><td>${esc(l.title)}</td><td>${l.views}</td></tr>`).join("") || `<tr><td colspan=2 class="empty">sem dados ainda</td></tr>`;
  const maxDay = Math.max(1, ...d.usage_by_day.map((x) => x.events));
  const chart = d.usage_by_day.map((x) =>
    `<div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:4px">
       <div style="width:100%;background:var(--line);border-radius:4px;display:flex;align-items:flex-end;height:90px">
         <div style="width:100%;background:var(--accent);height:${(x.events / maxDay) * 100}%;border-radius:4px"></div></div>
       <div style="font-size:10px;color:var(--muted)">${new Date(x.day).getDate()}</div></div>`).join("");

  main.innerHTML = `
    <h1>Visão geral</h1>
    <div class="sub">Atividade da plataforma em tempo real</div>
    <div class="kpis">
      ${kpi("Usuários totais", d.total_users)}
      ${kpi("DAU", d.dau)}
      ${kpi("WAU", d.wau)}
      ${kpi("MAU", d.mau)}
      ${kpi("Sessões 24h", d.sessions_24h)}
      ${kpi("Crashes 24h", d.crashes_24h, d.crashes_24h > 0 ? "bad" : "")}
      ${kpi("Análises IA", d.total_analyses)}
    </div>
    <h2>Eventos por dia (14d)</h2>
    <div class="card"><div style="display:flex;gap:6px;align-items:flex-end">${chart || '<div class="empty">sem dados</div>'}</div></div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px">
      <div><h2>Telas mais vistas (7d)</h2><table><tr><th>Tela</th><th>Views</th></tr>${screenRows}</table></div>
      <div><h2>Aulas mais vistas (30d)</h2><table><tr><th>Aula</th><th>Views</th></tr>${lessonRows}</table></div>
    </div>`;
};

// ─── Ao vivo (WebSocket) ────────────────────────────────────────────
views.live = async () => {
  // snapshot inicial via REST
  const snap = await api('/live').catch(() => ({ total_online: 0, by_screen: {} }));
  main.innerHTML = `
    <h1>Ao vivo <span id="live-dot" style="color:var(--bad);font-size:14px">●</span></h1>
    <div class="sub">Presença em tempo real (WebSocket)</div>
    <div class="kpis"><div class="kpi"><div class="label">Usuários online agora</div>
      <div class="value" id="live-total">${snap.total_online}</div></div></div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-top:24px">
      <div><h2>Usuários por tela</h2><div id="live-screens" class="card"></div></div>
      <div><h2>Feed de eventos</h2><div id="live-feed" class="card" style="max-height:420px;overflow-y:auto"></div></div>
    </div>`;

  const renderScreens = (byScreen) => {
    const entries = Object.entries(byScreen).sort((a, b) => b[1] - a[1]);
    const max = Math.max(1, ...entries.map((e) => e[1]));
    $('#live-screens').innerHTML = entries.length === 0
      ? '<div class="empty">ninguém online</div>'
      : entries.map(([s, n]) =>
          `<div style="margin-bottom:12px"><div class="row" style="justify-content:space-between">
             <strong>${esc(s)}</strong><span>${n} ${n === 1 ? 'usuário' : 'usuários'}</span></div>
           <div class="bar" style="margin-top:6px"><span style="width:${(n / max) * 100}%"></span></div></div>`).join('');
  };
  renderScreens(snap.by_screen);

  const feed = $('#live-feed');
  const pushFeed = (m) => {
    const when = new Date(m.ts || Date.now()).toLocaleTimeString('pt-BR');
    const line = m.kind === 'screen'
      ? `<b>${esc(m.user || 'anônimo')}</b> entrou em <code>${esc(m.screen)}</code>`
      : `<b>${esc(m.user || 'sistema')}</b> · ${esc(m.name)} ${m.screen ? `<code>${esc(m.screen)}</code>` : ''}`;
    const div = document.createElement('div');
    div.style.cssText = 'padding:8px 0;border-bottom:1px dotted var(--line);font-size:13px';
    div.innerHTML = `<span style="color:var(--muted)">${when}</span> · ${line}`;
    feed.insertBefore(div, feed.firstChild);
    while (feed.children.length > 60) feed.removeChild(feed.lastChild);
  };

  // conecta WebSocket admin
  const tok = await getToken();
  const wsUrl = location.origin.replace(/^http/, 'ws') + '/v1/rt/admin?token=' + encodeURIComponent(tok || '');
  const sock = new WebSocket(wsUrl);
  liveSocket = sock;
  sock.onopen = () => { const d = $('#live-dot'); if (d) d.style.color = 'var(--ok)'; };
  sock.onclose = () => { const d = $('#live-dot'); if (d) d.style.color = 'var(--bad)'; };
  sock.onmessage = (e) => {
    let m; try { m = JSON.parse(e.data); } catch { return; }
    if (m.type === 'presence') {
      const t = $('#live-total'); if (t) t.textContent = m.total_online;
      renderScreens(m.by_screen || {});
    } else if (m.type === 'event') {
      pushFeed(m);
    }
  };
};

// ─── Aulas ──────────────────────────────────────────────────────────
// Lista de categorias usada pelos formulários (preenchida em views.lessons).
let _categories = [];
// Opções <option> para os selects de categoria. `selected` pré-seleciona um id.
function categoryOptions(selected) {
  return `<option value="">(sem categoria)</option>` +
    _categories.map((cat) => `<option value="${cat.id}"${cat.id === selected ? " selected" : ""}>${esc(cat.name)}</option>`).join("");
}

views.lessons = async () => {
  const [{ courses }, { lessons }, { categories }] = await Promise.all([
    api("/admin/courses"), api("/admin/lessons"), api("/admin/categories"),
  ]);
  _categories = categories;
  const courseRows = courses.map((c) =>
    `<tr><td>${esc(c.title)}</td><td>${esc(c.technique || "—")}</td><td>${c.lesson_count}</td>
      <td>${c.published ? '<span class="badge ok">publicado</span>' : '<span class="badge draft">rascunho</span>'}</td>
      <td><button class="btn ghost sm" onclick="togglePub('course','${c.id}',${!c.published})">${c.published ? "despublicar" : "publicar"}</button>
          <button class="btn danger sm" onclick="delItem('courses','${c.id}')">×</button></td></tr>`).join("") ||
    `<tr><td colspan=5 class="empty">nenhum curso</td></tr>`;

  const catRows = categories.map((cat) =>
    `<tr><td>${esc(cat.name)}</td><td><span class="badge">${esc(cat.slug)}</span></td><td>${cat.lesson_count} aulas</td>
      <td><button class="btn danger sm" onclick="delItem('categories','${cat.id}')">×</button></td></tr>`).join("") ||
    `<tr><td colspan=4 class="empty">nenhuma categoria</td></tr>`;

  // filtro client-side por categoria (slug); "" = todas.
  const filterOpts = `<option value="">Todas as categorias</option>` +
    categories.map((cat) => `<option value="${cat.slug}">${esc(cat.name)}</option>`).join("");

  const renderLessonRows = (slug) => (
    lessons.filter((l) => !slug || l.category_slug === slug).map((l) =>
      `<tr><td>${esc(l.title)}</td><td>${esc(l.course_title || "—")}</td><td>${esc(l.category || "—")}</td><td>${l.block_count} blocos</td><td>${l.views} views</td>
        <td>${l.status === "published" ? '<span class="badge ok">publicada</span>' : '<span class="badge draft">rascunho</span>'}</td>
        <td><button class="btn ghost sm" onclick="editFull('${l.id}')">editar</button>
            <button class="btn ghost sm" onclick="editBlocks('${l.id}','${esc(l.title)}')">blocos</button>
            <button class="btn ghost sm" onclick="togglePub('lesson','${l.id}','${l.status === "published" ? "draft" : "published"}')">${l.status === "published" ? "despublicar" : "publicar"}</button>
            <button class="btn danger sm" onclick="delItem('lessons','${l.id}')">×</button></td></tr>`).join("") ||
    `<tr><td colspan=7 class="empty">nenhuma aula</td></tr>`
  );

  main.innerHTML = `
    <h1>Aulas</h1><div class="sub">Crie cursos e aulas mistas (vídeo + texto + imagens)</div>
    <div class="row"><h2 style="margin:0">Cursos</h2><div class="spacer"></div><button class="btn sm" onclick="newCourse()">+ curso</button></div>
    <table style="margin-top:12px"><tr><th>Título</th><th>Técnica</th><th>Aulas</th><th>Status</th><th></th></tr>${courseRows}</table>
    <div class="row" style="margin-top:28px"><h2 style="margin:0">Categorias</h2><div class="spacer"></div>
      <input class="field" id="cat-new" placeholder="Nova categoria" style="width:auto;margin:0" />
      <button class="btn sm" onclick="addCategory()">+ categoria</button></div>
    <table style="margin-top:12px"><tr><th>Nome</th><th>Slug</th><th>Aulas</th><th></th></tr>${catRows}</table>
    <div class="row" style="margin-top:28px"><h2 style="margin:0">Aulas</h2><div class="spacer"></div>
      <select class="field" id="lesson-filter" style="width:auto;margin:0" onchange="filterLessons()">${filterOpts}</select>
      <button class="btn ghost sm" onclick="newLesson(${JSON.stringify(courses.map((c) => ({ id: c.id, title: c.title }))).replace(/"/g, "&quot;")})">+ aula simples</button>
      <button class="btn sm" onclick="newFullLesson(${JSON.stringify(courses.map((c) => ({ id: c.id, title: c.title }))).replace(/"/g, "&quot;")})">+ aula completa</button></div>
    <table style="margin-top:12px"><tr><th>Título</th><th>Curso</th><th>Categoria</th><th>Conteúdo</th><th>Views</th><th>Status</th><th></th></tr><tbody id="lesson-rows">${renderLessonRows("")}</tbody></table>`;

  // re-renderiza o corpo da tabela conforme o filtro de categoria selecionado.
  window.filterLessons = () => {
    const slug = $("#lesson-filter").value;
    $("#lesson-rows").innerHTML = renderLessonRows(slug);
  };
};

window.addCategory = async () => {
  const name = ($("#cat-new").value || "").trim();
  if (!name) return;
  try {
    await api("/admin/categories", { method: "POST", body: JSON.stringify({ name }) });
    render("lessons");
  } catch (e) { alert("Erro: " + e.message); }
};

window.togglePub = async (kind, id, value) => {
  if (kind === "course") await api(`/admin/courses/${id}`, { method: "PATCH", body: JSON.stringify({ published: value }) });
  else await api(`/admin/lessons/${id}`, { method: "PATCH", body: JSON.stringify({ status: value }) });
  render("lessons");
};
window.delItem = async (type, id) => {
  if (!confirm("Excluir?")) return;
  await api(`/admin/${type}/${id}`, { method: "DELETE" });
  render("lessons");
};

function modal(html) {
  const bg = document.createElement("div");
  bg.className = "modal-bg";
  bg.innerHTML = `<div class="modal">${html}</div>`;
  bg.onclick = (e) => { if (e.target === bg) bg.remove(); };
  document.body.appendChild(bg);
  return bg;
}

window.newCourse = () => {
  const m = modal(`<h3>Novo curso</h3>
    <label class="lbl">Título</label><input class="field" id="c-title" />
    <label class="lbl">Descrição</label><textarea class="field" id="c-desc"></textarea>
    <label class="lbl">Técnica</label><select class="field" id="c-tech"><option value="crochet">Crochê</option><option value="knit">Tricô</option></select>
    <label class="lbl">Nível</label><select class="field" id="c-level"><option value="beginner">Iniciante</option><option value="intermediate">Intermediário</option><option value="advanced">Avançado</option></select>
    <div class="row"><button class="btn" id="c-save">Criar</button><button class="btn ghost" onclick="this.closest('.modal-bg').remove()">Cancelar</button></div>`);
  $("#c-save", m).onclick = async () => {
    await api("/admin/courses", { method: "POST", body: JSON.stringify({
      title: $("#c-title", m).value, description: $("#c-desc", m).value,
      technique: $("#c-tech", m).value, level: $("#c-level", m).value, published: true }) });
    m.remove(); render("lessons");
  };
};

window.newLesson = (courses) => {
  const opts = `<option value="">(sem curso)</option>` + courses.map((c) => `<option value="${c.id}">${esc(c.title)}</option>`).join("");
  const m = modal(`<h3>Nova aula</h3>
    <label class="lbl">Título</label><input class="field" id="l-title" />
    <label class="lbl">Curso</label><select class="field" id="l-course">${opts}</select>
    <label class="lbl">Categoria</label><select class="field" id="l-category">${categoryOptions()}</select>
    <label class="lbl">Descrição</label><textarea class="field" id="l-desc"></textarea>
    <label class="lbl">Técnica</label><select class="field" id="l-tech"><option value="crochet">Crochê</option><option value="knit">Tricô</option></select>
    <label class="lbl">Duração (min)</label><input class="field" id="l-dur" type="number" />
    <label class="lbl" style="margin-top:8px"><input type="checkbox" id="l-premium" style="width:auto">${icon('lock')} Premium (só assinantes)</label>
    <div class="row"><button class="btn" id="l-save">Criar</button><button class="btn ghost" onclick="this.closest('.modal-bg').remove()">Cancelar</button></div>`);
  $("#l-save", m).onclick = async () => {
    await api("/admin/lessons", { method: "POST", body: JSON.stringify({
      title: $("#l-title", m).value, course_id: $("#l-course", m).value || null,
      description: $("#l-desc", m).value, technique: $("#l-tech", m).value,
      is_premium: $("#l-premium", m).checked,
      category_id: $("#l-category", m).value || null,
      duration_min: Number($("#l-dur", m).value) || null }) });
    m.remove(); render("lessons");
  };
};

// Envia um arquivo do PC para POST /admin/assets e devolve o asset criado
// (imagem → WebP, vídeo → MP4, feito no servidor).
async function uploadAsset(file) {
  const fd = new FormData();
  fd.append("file", file);
  const { asset } = await api("/admin/assets", { method: "POST", body: fd });
  return asset;
}

// ─── Sub-passos (mini-passos: Título + Descrição + Tempo no vídeo) ───
// mm:ss <-> segundos (pro vídeo com capítulos sincronizados).
function parseTime(s) {
  s = (s || "").trim();
  if (!s) return null;
  if (s.includes(":")) {
    const [m, sec] = s.split(":").map((x) => Number(x));
    if (Number.isFinite(m)) return Math.round(m * 60 + (Number(sec) || 0));
    return null;
  }
  const n = Number(s);
  return Number.isFinite(n) ? Math.round(n) : null;
}
function fmtTime(sec) {
  if (sec == null || sec === "") return "";
  const n = Number(sec);
  if (!Number.isFinite(n)) return "";
  return `${Math.floor(n / 60)}:${String(Math.floor(n % 60)).padStart(2, "0")}`;
}

function addSubstepRow(wrap, data = {}) {
  const n = wrap.children.length + 1;
  const row = document.createElement("div");
  row.className = "substep-row";
  row.style.cssText =
    "border:1px solid var(--line);border-radius:10px;padding:10px 12px;margin-top:8px";
  if (data.video_asset_id) row.dataset.videoAssetId = data.video_asset_id;
  row.innerHTML =
    `<div class="row" style="justify-content:space-between;align-items:center;margin-bottom:6px">` +
    `<strong class="ss-n" style="font-size:12px;color:var(--muted)">Mini-passo ${n}</strong>` +
    `<button class="btn danger sm" type="button" title="remover">remover</button></div>` +
    `<input class="field ss-st" placeholder="Título (ex.: 2 correntes)" value="${esc(data.title)}" />` +
    `<textarea class="field ss-sd" placeholder="Descrição (ex.: não contam como ponto)" style="margin-top:6px">${esc(data.description)}</textarea>` +
    `<label class="lbl" style="margin-top:6px">Vídeo do mini-passo (cole uma URL ou envie um arquivo)</label>` +
    `<input class="field ss-vurl" placeholder="https://… (opcional)" value="${esc(data.video_url)}" />` +
    `<input type="file" class="ss-vfile" accept="video/*" style="font-size:11px;margin-top:6px" />` +
    `<span class="ss-vst sub" style="font-size:10px;margin-left:8px">${data.video_asset_id ? "🎬 vídeo anexado ✓" : ""}</span>`;
  row.querySelector("button").onclick = () => {
    const w = row.parentElement;
    row.remove();
    renumberSubsteps(w);
  };
  row.querySelector(".ss-vfile").onchange = async (ev) => {
    const f = ev.target.files[0];
    if (!f) return;
    const st = row.querySelector(".ss-vst");
    st.textContent = "enviando vídeo… (pode demorar)";
    try {
      const asset = await uploadAsset(f);
      row.dataset.videoAssetId = asset.id;
      row.querySelector(".ss-vurl").value = "";
      st.textContent = "🎬 vídeo do mini-passo enviado ✓";
    } catch (e) {
      st.textContent = "erro: " + e.message;
    }
  };
  wrap.appendChild(row);
}
function renumberSubsteps(wrap) {
  [...wrap.querySelectorAll(".ss-n")].forEach((el, i) => (el.textContent = `Mini-passo ${i + 1}`));
}
function wireSubsteps(card, initial) {
  const wrap = card.querySelector(".substeps-wrap");
  if (!wrap) return;
  (initial || []).forEach((s) => addSubstepRow(wrap, s));
  const addBtn = card.querySelector('[data-act="add-substep"]');
  if (addBtn) addBtn.onclick = () => addSubstepRow(wrap);
}
function collectSubsteps(card) {
  return [...card.querySelectorAll(".substep-row")]
    .map((r) => ({
      title: r.querySelector(".ss-st").value.trim(),
      description: r.querySelector(".ss-sd").value.trim(),
      video_url: r.querySelector(".ss-vurl").value.trim() || undefined,
      video_asset_id: r.dataset.videoAssetId || undefined,
    }))
    .filter((s) => s.title || s.description || s.video_url || s.video_asset_id);
}

// ─── Aula completa (modelo rico) ────────────────────────────────────
// Formulário do modelo da análise: metadados estruturados + passos detalhados.
// Envia tudo de uma vez para POST /admin/lessons/full.
window.newFullLesson = (courses) => {
  const opts = `<option value="">(sem curso)</option>` +
    courses.map((c) => `<option value="${c.id}">${esc(c.title)}</option>`).join("");

  const m = modal(`<h3>Nova aula completa</h3>
    <div class="sub" style="margin-bottom:14px">Preencha os metadados e os passos. Materiais e pontos: um por linha.</div>

    <label class="lbl">Título / Nome do produto *</label><input class="field" id="f-title" placeholder="Manta Listrada Texturizada Arco-Íris Pastel" />
    <div class="row" style="gap:12px">
      <div style="flex:1"><label class="lbl">Técnica</label><select class="field" id="f-tech"><option value="crochet">Crochê</option><option value="knit">Tricô</option></select></div>
      <div style="flex:1"><label class="lbl">Dificuldade</label><select class="field" id="f-dif"><option value="beginner">Iniciante</option><option value="intermediate">Intermediário</option><option value="advanced">Avançado</option></select></div>
    </div>
    <div class="row" style="gap:12px">
      <div style="flex:1"><label class="lbl">Curso</label><select class="field" id="f-course">${opts}</select></div>
      <div style="flex:1"><label class="lbl">Categoria</label><select class="field" id="f-category">${categoryOptions()}</select></div>
      <div style="flex:1"><label class="lbl">Duração (min)</label><input class="field" id="f-dur" type="number" placeholder="opcional" /></div>
    </div>
    <label class="lbl">Capa (cole uma URL ou envie um arquivo)</label><input class="field" id="f-cover" placeholder="https://…" />
    <input type="file" id="f-cover-file" accept="image/*" style="font-size:11px;margin-top:6px" /><span id="f-cover-st" class="sub" style="font-size:10px;margin-left:8px"></span>
    <label class="lbl">Vídeo da aula (capítulos = passos com tempo)</label><input class="field" id="f-lvideo" placeholder="cole uma URL ou envie um arquivo" />
    <input type="file" id="f-lvideo-file" accept="video/*" style="font-size:11px;margin-top:6px" /><span id="f-lvideo-st" class="sub" style="font-size:10px;margin-left:8px"></span>
    <label class="lbl">Fio</label><input class="field" id="f-yarn" placeholder="ex.: Fio worsted #4 (acrílico)" />
    <label class="lbl">Cor principal</label><input class="field" id="f-color" placeholder="ex.: Rosa pastel" />
    <label class="lbl">Agulha de crochê</label><input class="field" id="f-hook" placeholder="ex.: 5,0 mm (H/8)" />
    <label class="lbl">Materiais (um por linha)</label><textarea class="field" id="f-materials" placeholder="Fio worsted #4&#10;Agulha 5,0 mm&#10;Tesoura"></textarea>
    <label class="lbl">Pontos usados (um por linha: nome | confiança)</label><textarea class="field" id="f-stitches" placeholder="Ponto baixo | Alta&#10;Ponto alto | Alta"></textarea>

    <div class="row" style="margin-top:18px"><h2 style="margin:0;font-size:15px">Passos</h2><div class="spacer"></div>
      <button class="btn ghost sm" type="button" id="f-add-step">+ passo</button></div>
    <div id="f-steps"></div>

    <label class="lbl" style="margin-top:12px"><input type="checkbox" id="f-pub" checked style="width:auto"> Publicar imediatamente</label>
    <label class="lbl"><input type="checkbox" id="f-premium" style="width:auto">${icon('lock')} Premium (só assinantes)</label>
    <div id="f-status" class="sub" style="margin-top:10px"></div>
    <div class="row" style="margin-top:16px">
      <button class="btn" id="f-save">Criar aula</button>
      <button class="btn ghost" type="button" id="f-preview">👁 Pré-visualizar</button>
      <button class="btn ghost" onclick="this.closest('.modal-bg').remove()">Cancelar</button>
    </div>`);

  const stepsWrap = $("#f-steps", m);
  const addStep = (data = {}) => {
    const idx = stepsWrap.children.length + 1;
    const card = document.createElement("div");
    card.className = "step-card";
    card.style.cssText = "border:1px solid var(--line);border-radius:10px;padding:12px;margin-top:10px";
    card.innerHTML = `
      <div class="row" style="justify-content:space-between"><strong class="step-n">Passo ${idx}</strong>
        <button class="btn danger sm" type="button" onclick="this.closest('.step-card').remove();window._renumSteps&&window._renumSteps()">remover</button></div>
      <label class="lbl">Título</label><input class="field s-title" value="${esc(data.title)}" />
      <label class="lbl">Tempo no vídeo da aula (mm:ss, opcional — vira capítulo)</label><input class="field s-time" value="${esc(fmtTime(data.time))}" placeholder="ex.: 2:40" />
      <label class="lbl">Sub-passos (mini-passos: título + descrição + vídeo próprio)</label>
      <div class="substeps-wrap"></div>
      <button class="btn ghost sm" type="button" data-act="add-substep" style="margin-top:6px">+ mini-passo</button>
      <label class="lbl" style="margin-top:12px">Total (ex.: 12 pontos)</label><input class="field s-total" value="${esc(data.total)}" />
      <label class="lbl">Pontos usados</label><textarea class="field s-stitches">${esc(data.stitches_used)}</textarea>
      <label class="lbl">Imagem do passo (cole uma URL ou envie um arquivo)</label><input class="field s-image" value="${esc(data.image_url)}" />
      <input type="file" class="s-file" accept="image/*" style="font-size:11px;margin-top:6px" /><span class="s-upst sub" style="font-size:10px;margin-left:8px"></span>`;
    stepsWrap.appendChild(card);
    wireSubsteps(card, data.substeps);
    // upload da imagem do passo (arquivo do PC → asset)
    $(".s-file", card).onchange = async (ev) => {
      const f = ev.target.files[0]; if (!f) return;
      const st = $(".s-upst", card); st.textContent = "enviando…";
      try {
        const asset = await uploadAsset(f);
        card.dataset.assetId = asset.id;
        $(".s-image", card).value = "";
        st.textContent = "enviada ✓";
      } catch (e) { st.textContent = "erro: " + e.message; }
    };
  };
  window._renumSteps = () => $$(".step-card .step-n", m).forEach((el, i) => (el.textContent = `Passo ${i + 1}`));
  $("#f-add-step", m).onclick = () => addStep();
  addStep(); // começa com 1 passo

  // Upload da capa (arquivo do PC → asset). Arquivo tem prioridade sobre a URL.
  let coverAssetId = null;
  $("#f-cover-file", m).onchange = async (ev) => {
    const f = ev.target.files[0]; if (!f) return;
    const st = $("#f-cover-st", m); st.textContent = "enviando…";
    try {
      const asset = await uploadAsset(f);
      coverAssetId = asset.id;
      $("#f-cover", m).value = "";
      st.textContent = "capa enviada ✓";
    } catch (e) { st.textContent = "erro: " + e.message; }
  };

  let lessonVideoAssetId = null;
  $("#f-lvideo-file", m).onchange = async (ev) => {
    const f = ev.target.files[0]; if (!f) return;
    const st = $("#f-lvideo-st", m); st.textContent = "enviando vídeo… (pode demorar)";
    try {
      const asset = await uploadAsset(f);
      lessonVideoAssetId = asset.id;
      $("#f-lvideo", m).value = "";
      st.textContent = "vídeo da aula enviado ✓";
    } catch (e) { st.textContent = "erro: " + e.message; }
  };

  const lines = (id) => $(`#${id}`, m).value.split("\n").map((x) => x.trim()).filter(Boolean);

  $("#f-preview", m).onclick = () => openLessonPreview(collectPreviewData(m, "f"));
  $("#f-save", m).onclick = async () => {
    const title = $("#f-title", m).value.trim();
    if (!title) { $("#f-status", m).textContent = "Informe o título."; return; }
    const stitches = lines("f-stitches").map((l) => {
      const [name, confidence] = l.split("|").map((x) => x.trim());
      return confidence ? { name, confidence } : { name };
    });
    const steps = $$(".step-card", m).map((c) => ({
      title: $(".s-title", c).value.trim() || undefined,
      time: parseTime($(".s-time", c).value),
      substeps: collectSubsteps(c),
      total: $(".s-total", c).value.trim() || undefined,
      stitches_used: $(".s-stitches", c).value.trim() || undefined,
      image_url: $(".s-image", c).value.trim() || undefined,
      image_asset_id: c.dataset.assetId || undefined,
    }));
    const payload = {
      title,
      course_id: $("#f-course", m).value || null,
      category_id: $("#f-category", m).value || null,
      technique: $("#f-tech", m).value,
      difficulty: $("#f-dif", m).value,
      duration_min: Number($("#f-dur", m).value) || null,
      cover_url: $("#f-cover", m).value.trim() || undefined,
      cover_asset_id: coverAssetId || undefined,
      status: $("#f-pub", m).checked ? "published" : "draft",
      is_premium: $("#f-premium", m).checked,
      meta: {
        product_name: $("#f-title", m).value.trim() || undefined,
        materials: lines("f-materials"),
        yarn: $("#f-yarn", m).value.trim() || undefined,
        main_color: $("#f-color", m).value.trim() || undefined,
        crochet_hook: $("#f-hook", m).value.trim() || undefined,
        video_url: $("#f-lvideo", m).value.trim() || undefined,
        video_asset_id: lessonVideoAssetId || undefined,
        stitches,
      },
      steps,
    };
    const btn = $("#f-save", m);
    btn.disabled = true; $("#f-status", m).textContent = "Criando…";
    try {
      await api("/admin/lessons/full", { method: "POST", body: JSON.stringify(payload) });
      m.remove(); render("lessons");
    } catch (e) {
      btn.disabled = false; $("#f-status", m).textContent = "Erro: " + e.message;
    }
  };
};

// ─── Editor de aula completa (metadados + passos + upload por passo) ─
window.editFull = async (lessonId) => {
  const [{ lesson }, { blocks }] = await Promise.all([
    api(`/admin/lessons/${lessonId}`),
    api(`/admin/lessons/${lessonId}/blocks`),
  ]);
  const meta = lesson.meta || {};
  const steps = blocks.filter((b) => b.type === "step");
  const matText = (meta.materials || []).join("\n");
  const stitchText = (meta.stitches || []).map((s) => (s.confidence ? `${s.name} | ${s.confidence}` : s.name)).join("\n");
  const sel = (v, opt) => (v === opt ? " selected" : "");

  const m = modal(`<h3>Editar aula</h3>
    <label class="lbl">Título / Nome do produto *</label><input class="field" id="e-title" value="${esc(lesson.title)}" />
    <div class="row" style="gap:12px">
      <div style="flex:1"><label class="lbl">Técnica</label><select class="field" id="e-tech"><option value="crochet"${sel(lesson.technique,"crochet")}>Crochê</option><option value="knit"${sel(lesson.technique,"knit")}>Tricô</option></select></div>
      <div style="flex:1"><label class="lbl">Dificuldade</label><select class="field" id="e-dif"><option value="beginner"${sel(lesson.difficulty,"beginner")}>Iniciante</option><option value="intermediate"${sel(lesson.difficulty,"intermediate")}>Intermediário</option><option value="advanced"${sel(lesson.difficulty,"advanced")}>Avançado</option></select></div>
    </div>
    <div class="row" style="gap:12px">
      <div style="flex:1"><label class="lbl">Duração (min)</label><input class="field" id="e-dur" type="number" value="${esc(lesson.duration_min ?? "")}" /></div>
      <div style="flex:1"><label class="lbl">Categoria</label><select class="field" id="e-category">${categoryOptions(lesson.category_id)}</select></div>
    </div>
    <label class="lbl">Capa (cole uma URL ou envie um arquivo)</label><input class="field" id="e-cover" value="${esc(lesson.cover_url)}" />
    <input type="file" id="e-cover-file" accept="image/*" style="font-size:11px;margin-top:6px" /><span id="e-cover-st" class="sub" style="font-size:10px;margin-left:8px"></span>
    <label class="lbl">Vídeo da aula (capítulos = passos com tempo)</label><input class="field" id="e-lvideo" value="${esc(meta.video_url)}" placeholder="cole uma URL ou envie um arquivo" />
    <input type="file" id="e-lvideo-file" accept="video/*" style="font-size:11px;margin-top:6px" /><span id="e-lvideo-st" class="sub" style="font-size:10px;margin-left:8px">${meta.video_asset_id ? "🎬 vídeo anexado ✓" : ""}</span>
    <label class="lbl">Fio</label><input class="field" id="e-yarn" value="${esc(meta.yarn || meta.pattern_analysis)}" />
    <label class="lbl">Cor principal</label><input class="field" id="e-color" value="${esc(meta.main_color || meta.color_sequence)}" />
    <label class="lbl">Agulha de crochê</label><input class="field" id="e-hook" value="${esc(meta.crochet_hook)}" />
    <label class="lbl">Materiais (um por linha)</label><textarea class="field" id="e-materials">${esc(matText)}</textarea>
    <label class="lbl">Pontos usados (nome | confiança)</label><textarea class="field" id="e-stitches">${esc(stitchText)}</textarea>

    <div class="row" style="margin-top:18px"><h2 style="margin:0;font-size:15px">Passos</h2><div class="spacer"></div>
      <button class="btn ghost sm" type="button" id="e-add-step">+ passo</button></div>
    <div id="e-steps"></div>

    <label class="lbl" style="margin-top:12px"><input type="checkbox" id="e-pub" ${lesson.status === "published" ? "checked" : ""} style="width:auto"> Publicada</label>
    <label class="lbl"><input type="checkbox" id="e-premium" ${lesson.is_premium ? "checked" : ""} style="width:auto">${icon('lock')} Premium (só assinantes)</label>
    <div id="e-status" class="sub" style="margin-top:10px"></div>
    <div class="row" style="margin-top:16px">
      <button class="btn" id="e-save">Salvar alterações</button>
      <button class="btn ghost" type="button" id="e-preview">👁 Pré-visualizar</button>
      <button class="btn ghost" onclick="this.closest('.modal-bg').remove()">Fechar</button>
    </div>`);

  const stepsWrap = $("#e-steps", m);

  // Upload da capa (arquivo do PC → asset). Arquivo tem prioridade sobre a URL.
  let coverAssetId = null;
  $("#e-cover-file", m).onchange = async (ev) => {
    const f = ev.target.files[0]; if (!f) return;
    const st = $("#e-cover-st", m); st.textContent = "enviando…";
    try {
      const asset = await uploadAsset(f);
      coverAssetId = asset.id;
      $("#e-cover", m).value = "";
      st.textContent = "capa enviada ✓ (salve para aplicar)";
    } catch (e) { st.textContent = "erro: " + e.message; }
  };

  let lessonVideoAssetId = meta.video_asset_id || null;
  $("#e-lvideo-file", m).onchange = async (ev) => {
    const f = ev.target.files[0]; if (!f) return;
    const st = $("#e-lvideo-st", m); st.textContent = "enviando vídeo… (pode demorar)";
    try {
      const asset = await uploadAsset(f);
      lessonVideoAssetId = asset.id;
      $("#e-lvideo", m).value = "";
      st.textContent = "🎬 vídeo da aula enviado ✓ (salve para aplicar)";
    } catch (e) { st.textContent = "erro: " + e.message; }
  };

  const buildStepContent = (card, n) => {
    const v = (cls) => $(cls, card).value.trim();
    const substeps = collectSubsteps(card);
    return {
      number: n,
      title: v(".s-title") || null,
      time: parseTime(v(".s-time")),
      substeps,
      total: v(".s-total") || null,
      stitches_used: v(".s-stitches") || null,
      image_url: v(".s-image") || null, // URL colada tem prioridade; vazio = usa imagem enviada
    };
  };

  const renderCard = (block) => {
    const ct = block.content || {};
    const preview = ct.image_url || block.url || "";
    const card = document.createElement("div");
    card.className = "step-card";
    card.dataset.id = block.id;
    card.dataset.assetId = block.asset_id || "";
    card.style.cssText = "border:1px solid var(--line);border-radius:10px;padding:12px;margin-top:10px";
    card.innerHTML = `
      <div class="row" style="justify-content:space-between"><strong class="step-n"></strong>
        <button class="btn danger sm" type="button" data-act="remove">remover</button></div>
      <div class="row" style="gap:12px;align-items:flex-start">
        <div style="width:96px;flex:none">
          <div class="s-preview" style="width:96px;height:96px;border-radius:8px;background:var(--bg) center/cover no-repeat;border:1px solid var(--line)${preview ? `;background-image:url('${preview.replace(/'/g, "%27")}')` : ""}"></div>
          <input type="file" class="s-file" accept="image/*" style="font-size:11px;margin-top:6px;width:96px" />
          <div class="s-upst sub" style="font-size:10px"></div>
        </div>
        <div style="flex:1">
          <label class="lbl">Título</label><input class="field s-title" value="${esc(ct.title)}" />
        </div>
      </div>
      <label class="lbl">Tempo no vídeo da aula (mm:ss, opcional — vira capítulo)</label><input class="field s-time" value="${esc(fmtTime(ct.time))}" placeholder="ex.: 2:40" />
      <label class="lbl">Sub-passos (mini-passos: título + descrição + vídeo próprio)</label>
      <div class="substeps-wrap"></div>
      <button class="btn ghost sm" type="button" data-act="add-substep" style="margin-top:6px">+ mini-passo</button>
      <label class="lbl" style="margin-top:12px">Total (ex.: 12 pontos)</label><input class="field s-total" value="${esc(ct.total)}" />
      <label class="lbl">Pontos usados</label><textarea class="field s-stitches">${esc(ct.stitches_used)}</textarea>
      <label class="lbl">URL da imagem (ou envie um arquivo acima)</label><input class="field s-image" value="${esc(ct.image_url)}" />`;

    // remover passo
    $('[data-act="remove"]', card).onclick = async () => {
      if (!confirm("Remover este passo?")) return;
      await api(`/admin/blocks/${block.id}`, { method: "DELETE" });
      editFull(lessonId);
    };
    // upload de imagem do passo (vira WebP no servidor) → anexa ao bloco
    $(".s-file", card).onchange = async (ev) => {
      const f = ev.target.files[0]; if (!f) return;
      const st = $(".s-upst", card); st.textContent = "enviando…";
      try {
        const fd = new FormData(); fd.append("file", f);
        const { asset } = await api("/admin/assets", { method: "POST", body: fd });
        card.dataset.assetId = asset.id;
        $(".s-image", card).value = ""; // limpa URL → app usa a imagem enviada
        $(".s-preview", card).style.backgroundImage = `url('${URL.createObjectURL(f)}')`;
        st.textContent = "enviada ✓ (salve para aplicar)";
      } catch (e) { st.textContent = "erro: " + e.message; }
    };
    stepsWrap.appendChild(card);
    wireSubsteps(card, ct.substeps);
  };

  const renumber = () => $$(".step-card .step-n", m).forEach((el, i) => (el.textContent = `Passo ${i + 1}`));
  steps.forEach(renderCard);
  renumber();

  const lines = (id) => $(`#${id}`, m).value.split("\n").map((x) => x.trim()).filter(Boolean);

  const saveAll = async () => {
    const stitches = lines("e-stitches").map((l) => {
      const [name, confidence] = l.split("|").map((x) => x.trim());
      return confidence ? { name, confidence } : { name };
    });
    await api(`/admin/lessons/${lessonId}`, { method: "PATCH", body: JSON.stringify({
      title: $("#e-title", m).value.trim(),
      technique: $("#e-tech", m).value,
      difficulty: $("#e-dif", m).value,
      duration_min: Number($("#e-dur", m).value) || null,
      cover_url: coverAssetId ? "" : $("#e-cover", m).value.trim(),
      cover_asset_id: coverAssetId || null,
      status: $("#e-pub", m).checked ? "published" : "draft",
      is_premium: $("#e-premium", m).checked,
      category_id: $("#e-category", m).value || null,
      meta: {
        product_name: $("#e-title", m).value.trim(),
        materials: lines("e-materials"),
        yarn: $("#e-yarn", m).value.trim(),
        main_color: $("#e-color", m).value.trim(),
        crochet_hook: $("#e-hook", m).value.trim(),
        video_url: $("#e-lvideo", m).value.trim() || null,
        video_asset_id: lessonVideoAssetId || null,
        stitches,
      },
    }) });
    const cards = $$(".step-card", m);
    for (let i = 0; i < cards.length; i++) {
      const card = cards[i];
      await api(`/admin/blocks/${card.dataset.id}`, { method: "PATCH", body: JSON.stringify({
        content: buildStepContent(card, i + 1),
        asset_id: card.dataset.assetId || null,
        position: i,
      }) });
    }
  };

  $("#e-add-step", m).onclick = async () => {
    $("#e-status", m).textContent = "salvando e adicionando…";
    try {
      await saveAll();
      await api(`/admin/lessons/${lessonId}/blocks`, { method: "POST", body: JSON.stringify({ type: "step", content: {} }) });
      editFull(lessonId);
    } catch (e) { $("#e-status", m).textContent = "erro: " + e.message; }
  };

  $("#e-preview", m).onclick = () => previewSavedLesson(lesson.slug, m);
  $("#e-save", m).onclick = async () => {
    const btn = $("#e-save", m); btn.disabled = true; $("#e-status", m).textContent = "salvando…";
    try { await saveAll(); m.remove(); render("lessons"); }
    catch (e) { btn.disabled = false; $("#e-status", m).textContent = "erro: " + e.message; }
  };
};

// Editor de blocos (conteúdo misto + upload)
window.editBlocks = async (lessonId, title) => {
  const { blocks } = await api(`/admin/lessons/${lessonId}/blocks`);
  const list = blocks.map((b) =>
    `<div class="block-item"><span class="type">${b.type}</span>
       <span style="flex:1;font-size:13px">${esc(b.content?.text || b.kind || b.storage_key || "")}</span>
       <button class="btn danger sm" onclick="delBlock('${b.id}','${lessonId}','${esc(title)}')">×</button></div>`).join("") ||
    `<div class="empty">nenhum bloco ainda</div>`;
  const m = modal(`<h3>Conteúdo · ${esc(title)}</h3>
    <div id="blocklist">${list}</div>
    <h2 style="margin-top:18px">Adicionar bloco</h2>
    <label class="lbl">Texto</label><textarea class="field" id="b-text" placeholder="parágrafo da aula"></textarea>
    <button class="btn sm" id="b-add-text">+ texto</button>
    <hr style="border:0;border-top:1px solid var(--line);margin:16px 0">
    <label class="lbl">Mídia (vídeo / imagem / pdf)</label>
    <input class="field" type="file" id="b-file" accept="video/*,image/*,application/pdf" />
    <button class="btn sm" id="b-add-media">+ enviar mídia</button>
    <div id="b-status" class="sub" style="margin-top:10px"></div>
    <div class="row" style="margin-top:16px"><button class="btn ghost" onclick="this.closest('.modal-bg').remove()">Fechar</button></div>`);

  $("#b-add-text", m).onclick = async () => {
    const text = $("#b-text", m).value.trim();
    if (!text) return;
    await api(`/admin/lessons/${lessonId}/blocks`, { method: "POST", body: JSON.stringify({ type: "text", content: { text } }) });
    m.remove(); editBlocks(lessonId, title);
  };
  $("#b-add-media", m).onclick = async () => {
    const f = $("#b-file", m).files[0];
    if (!f) return;
    $("#b-status", m).textContent = "enviando…";
    const fd = new FormData(); fd.append("file", f);
    const { asset } = await api("/admin/assets", { method: "POST", body: fd });
    const type = asset.kind === "video" ? "video" : asset.kind === "image" ? "image" : "material";
    await api(`/admin/lessons/${lessonId}/blocks`, { method: "POST", body: JSON.stringify({ type, asset_id: asset.id, content: { filename: asset.filename } }) });
    m.remove(); editBlocks(lessonId, title);
  };
};
window.delBlock = async (id, lessonId, title) => {
  await api(`/admin/blocks/${id}`, { method: "DELETE" });
  const bg = $(".modal-bg"); if (bg) bg.remove();
  editBlocks(lessonId, title);
};

// ─── Dicas ──────────────────────────────────────────────────────────
views.tips = async () => {
  const { tips } = await api('/admin/tips');
  const rows = tips.map((t) =>
    `<tr><td style="font-size:22px">${esc(t.emoji)}</td><td><strong>${esc(t.title)}</strong><br><span style="color:var(--muted);font-size:13px">${esc(t.body)}</span></td>
      <td><button class="btn danger sm" onclick="delTip('${t.id}')">×</button></td></tr>`).join('') ||
    `<tr><td colspan=3 class="empty">nenhuma dica</td></tr>`;
  main.innerHTML = `<h1>Dicas</h1><div class="sub">Aparecem na tela inicial do app</div>
    <div class="row" style="margin-bottom:12px"><div class="spacer"></div><button class="btn sm" onclick="newTip()">+ dica</button></div>
    <table><tr><th></th><th>Conteúdo</th><th></th></tr>${rows}</table>`;
};
window.newTip = () => {
  const m = modal(`<h3>Nova dica</h3>
    <label class="lbl">Emoji</label><input class="field" id="t-emoji" value="" placeholder="(opcional)" />
    <label class="lbl">Título</label><input class="field" id="t-title" />
    <label class="lbl">Texto</label><textarea class="field" id="t-body"></textarea>
    <div class="row"><button class="btn" id="t-save">Criar</button><button class="btn ghost" onclick="this.closest('.modal-bg').remove()">Cancelar</button></div>`);
  $('#t-save', m).onclick = async () => {
    await api('/admin/tips', { method: 'POST', body: JSON.stringify({
      emoji: $('#t-emoji', m).value, title: $('#t-title', m).value, body: $('#t-body', m).value }) });
    m.remove(); render('tips');
  };
};
window.delTip = async (id) => { await api('/admin/tips/' + id, { method: 'DELETE' }); render('tips'); };

// ─── Receitas / Patterns (biblioteca curada do app) ─────────────────
views.patterns = async () => {
  const { patterns } = await api('/admin/patterns');
  const rows = patterns.map((p) =>
    `<tr>
      <td><strong>${esc(p.name)}</strong><br><span style="color:var(--muted);font-size:13px">${esc(p.author || '')} · ${esc(p.technique)} · ${esc(p.difficulty)}</span></td>
      <td style="text-align:center">${p.section_count ?? 0}</td>
      <td><span class="badge ${p.status === 'published' ? 'ok' : 'warn'}">${esc(p.status)}</span></td>
      <td class="row"><button class="btn ghost sm" onclick="editPattern('${p.id}')">editar</button>
        <button class="btn danger sm" onclick="delPattern('${p.id}')">×</button></td>
    </tr>`).join('') || `<tr><td colspan=4 class="empty">nenhuma receita</td></tr>`;
  main.innerHTML = `<h1>Receitas</h1><div class="sub">Biblioteca mostrada no app (Tools → Pattern library)</div>
    <div class="row" style="margin-bottom:12px"><div class="spacer"></div><button class="btn sm" onclick="newPattern()">+ receita</button></div>
    <table><tr><th>Receita</th><th>Seções</th><th>Status</th><th></th></tr>${rows}</table>`;
};

const PATTERN_SECTIONS_EXAMPLE = `[
  {
    "title": "Section title",
    "subtitle": "(optional)",
    "rows": [
      { "row": 1, "instruction": "Magic ring with 6 sc.", "stitch_count": 6 }
    ]
  }
]`;

function patternModal(p) {
  const sel = (v, opts) => opts.map((o) => `<option value="${o}"${v === o ? ' selected' : ''}>${o}</option>`).join('');
  const m = modal(`<h3>${p && p.id ? 'Editar receita' : 'Nova receita'}</h3>
    <label class="lbl">ID (slug)</label><input class="field" id="p-id" value="${esc(p?.id || '')}" placeholder="auto se vazio" ${p && p.id ? 'readonly' : ''} />
    <label class="lbl">Nome</label><input class="field" id="p-name" value="${esc(p?.name || '')}" />
    <label class="lbl">Autor</label><input class="field" id="p-author" value="${esc(p?.author || 'StitchMind')}" />
    <div class="row">
      <div style="flex:1"><label class="lbl">Técnica</label><select class="field" id="p-tech">${sel(p?.technique || 'crochet', ['crochet', 'knit'])}</select></div>
      <div style="flex:1"><label class="lbl">Dificuldade</label><select class="field" id="p-diff">${sel(p?.difficulty || 'beginner', ['beginner', 'intermediate', 'advanced'])}</select></div>
    </div>
    <label class="lbl">Fio (yarn)</label><input class="field" id="p-yarn" value="${esc(p?.yarn_requirement || '')}" />
    <div class="row">
      <div style="flex:1"><label class="lbl">Horas estimadas</label><input class="field" id="p-hours" type="number" value="${p?.estimated_hours ?? 0}" /></div>
      <div style="flex:1"><label class="lbl">Agulha sugerida</label><input class="field" id="p-needle" value="${esc(p?.suggested_needle || '')}" /></div>
    </div>
    <label class="lbl">Descrição</label><textarea class="field" id="p-desc">${esc(p?.description || '')}</textarea>
    <label class="lbl">Status</label><select class="field" id="p-status">${sel(p?.status || 'published', ['published', 'draft'])}</select>
    <label class="lbl">Seções (JSON)</label><textarea class="field" id="p-sections" style="min-height:200px;font-family:monospace;font-size:12px">${esc(p?.sections ? JSON.stringify(p.sections, null, 2) : PATTERN_SECTIONS_EXAMPLE)}</textarea>
    <div class="row"><button class="btn" id="p-save">Salvar</button><button class="btn ghost" onclick="this.closest('.modal-bg').remove()">Cancelar</button></div>`);
  $('#p-save', m).onclick = async () => {
    let sections;
    try { sections = JSON.parse($('#p-sections', m).value || '[]'); }
    catch (e) { alert('JSON das seções inválido: ' + e.message); return; }
    const body = {
      id: $('#p-id', m).value.trim() || undefined,
      name: $('#p-name', m).value.trim(),
      author: $('#p-author', m).value.trim() || 'StitchMind',
      technique: $('#p-tech', m).value,
      difficulty: $('#p-diff', m).value,
      yarn_requirement: $('#p-yarn', m).value,
      estimated_hours: Number($('#p-hours', m).value) || 0,
      suggested_needle: $('#p-needle', m).value || null,
      description: $('#p-desc', m).value,
      status: $('#p-status', m).value,
      sections,
    };
    if (!body.name) { alert('Informe o nome da receita.'); return; }
    try { await api('/admin/patterns', { method: 'POST', body: JSON.stringify(body) }); }
    catch (e) { alert('Falha ao salvar: ' + e.message); return; }
    m.remove(); render('patterns');
  };
}

window.newPattern = () => patternModal(null);
window.editPattern = async (id) => { const { pattern } = await api('/admin/patterns/' + id); patternModal(pattern); };
window.delPattern = async (id) => { if (!confirm('Excluir esta receita?')) return; await api('/admin/patterns/' + id, { method: 'DELETE' }); render('patterns'); };

// ─── Pontos (stitches) ──────────────────────────────────────────────
views.stitches = async () => {
  const { stitches } = await api('/admin/stitches');
  const rows = stitches.map((s) =>
    `<tr>
      <td><strong>${esc(s.name_pt)}</strong> <span style="color:var(--muted)">${esc(s.abbrev || '')}</span><br><span style="color:var(--muted);font-size:13px">${esc(s.technique)} · ${esc(s.difficulty)}</span></td>
      <td style="text-align:center">${s.video_url ? '🎬 sim' : '—'}</td>
      <td class="row"><button class="btn ghost sm" onclick="editStitch('${s.id}')">editar</button>
        <button class="btn danger sm" onclick="delStitch('${s.id}')">×</button></td>
    </tr>`).join('') || `<tr><td colspan=3 class="empty">nenhum ponto</td></tr>`;
  main.innerHTML = `<h1>Pontos</h1><div class="sub">Biblioteca de pontos do app — anexe o vídeo da técnica em cada um</div>
    <div class="row" style="margin-bottom:12px"><div class="spacer"></div><button class="btn sm" onclick="newStitch()">+ ponto</button></div>
    <table><tr><th>Ponto</th><th>Vídeo</th><th></th></tr>${rows}</table>`;
};

function stitchModal(s) {
  const sel = (v, opts) => opts.map((o) => `<option value="${o}"${v === o ? ' selected' : ''}>${o}</option>`).join('');
  let videoAssetId = s?.video_asset_id || '';
  const m = modal(`<h3>${s && s.id ? 'Editar ponto' : 'Novo ponto'}</h3>
    <label class="lbl">ID (slug)</label><input class="field" id="t-id" value="${esc(s?.id || '')}" placeholder="ex.: st-cr-023" ${s && s.id ? 'readonly' : ''} />
    <div class="row">
      <div style="flex:1"><label class="lbl">Nome (PT)</label><input class="field" id="t-pt" value="${esc(s?.name_pt || '')}" /></div>
      <div style="flex:1"><label class="lbl">Nome (EN)</label><input class="field" id="t-en" value="${esc(s?.name_en || '')}" /></div>
    </div>
    <label class="lbl">Abreviação</label><input class="field" id="t-abbrev" value="${esc(s?.abbrev || '')}" placeholder="ex.: corr / ch" />
    <div class="row">
      <div style="flex:1"><label class="lbl">Técnica</label><select class="field" id="t-tech">${sel(s?.technique || 'crochet', ['crochet', 'knit'])}</select></div>
      <div style="flex:1"><label class="lbl">Dificuldade</label><select class="field" id="t-diff">${sel(s?.difficulty || 'beginner', ['beginner', 'intermediate', 'advanced'])}</select></div>
    </div>
    <label class="lbl">Categorias (uma por linha)</label><textarea class="field" id="t-cats">${esc((s?.categories || []).join('\n'))}</textarea>
    <label class="lbl">Descrição</label><textarea class="field" id="t-desc">${esc(s?.description || '')}</textarea>
    <label class="lbl">Passos (um por linha)</label><textarea class="field" id="t-steps" style="min-height:120px">${esc((s?.steps || []).join('\n'))}</textarea>
    <label class="lbl">Vídeo da técnica (envie um arquivo)</label>
    <input type="file" id="t-vfile" accept="video/*" style="font-size:11px" />
    <span id="t-vst" class="sub" style="font-size:11px;margin-left:8px">${videoAssetId ? '🎬 vídeo anexado ✓ — envie outro p/ trocar' : 'nenhum vídeo'}</span>
    ${videoAssetId ? `<div style="margin-top:4px"><button class="btn ghost sm" type="button" id="t-vrm">remover vídeo</button></div>` : ''}
    <div class="row" style="margin-top:12px"><button class="btn" id="t-save">Salvar</button><button class="btn ghost" onclick="this.closest('.modal-bg').remove()">Cancelar</button></div>`);
  $('#t-vfile', m).onchange = async (ev) => {
    const f = ev.target.files[0]; if (!f) return;
    const st = $('#t-vst', m); st.textContent = 'enviando vídeo… (pode demorar)';
    try {
      const fd = new FormData(); fd.append('file', f);
      const { asset } = await api('/admin/assets', { method: 'POST', body: fd });
      videoAssetId = asset.id;
      st.textContent = '🎬 vídeo enviado ✓';
    } catch (e) { st.textContent = 'erro: ' + e.message; }
  };
  if ($('#t-vrm', m)) $('#t-vrm', m).onclick = () => { videoAssetId = ''; $('#t-vst', m).textContent = 'vídeo removido (salve para aplicar)'; };
  const lines = (id) => $('#' + id, m).value.split('\n').map((x) => x.trim()).filter(Boolean);
  $('#t-save', m).onclick = async () => {
    const body = {
      id: $('#t-id', m).value.trim(),
      name_pt: $('#t-pt', m).value.trim(),
      name_en: $('#t-en', m).value.trim() || $('#t-pt', m).value.trim(),
      abbrev: $('#t-abbrev', m).value.trim(),
      technique: $('#t-tech', m).value,
      difficulty: $('#t-diff', m).value,
      categories: lines('t-cats'),
      description: $('#t-desc', m).value.trim(),
      steps: lines('t-steps'),
      video_asset_id: videoAssetId || null,
    };
    if (!body.id || !body.name_pt) { alert('Informe ID e Nome (PT).'); return; }
    try { await api('/admin/stitches', { method: 'POST', body: JSON.stringify(body) }); }
    catch (e) { alert('Falha ao salvar: ' + e.message); return; }
    m.remove(); render('stitches');
  };
}
window.newStitch = () => stitchModal(null);
window.editStitch = async (id) => { const { stitch } = await api('/admin/stitches/' + id); stitchModal(stitch); };
window.delStitch = async (id) => { if (!confirm('Excluir este ponto?')) return; await api('/admin/stitches/' + id, { method: 'DELETE' }); render('stitches'); };

// ─── Comunidade (moderação) ─────────────────────────────────────────
views.posts = async () => {
  const { posts } = await api('/admin/posts');
  const cards = posts.map((p) => {
    return `<div class="card" style="display:flex;gap:14px;align-items:center">
      ${p.image_asset_id ? `<img src="/v1/media/${p.image_asset_id}" style="width:70px;height:70px;border-radius:12px;object-fit:cover" />` : `<div style="width:70px;height:70px;border-radius:12px;background:var(--bg);display:flex;align-items:center;justify-content:center;color:var(--muted)">${icon('community')}</div>`}
      <div style="flex:1">
        <strong>${esc(p.author || 'anônimo')}</strong> · <span style="color:var(--muted)">${p.likes_count} curtidas</span><br>
        <span style="font-size:14px">${esc(p.caption || '(sem legenda)')}</span><br>
        <span class="badge ${p.status === 'approved' ? 'ok' : p.status === 'hidden' ? 'bad' : 'warn'}">${esc(p.status)}</span>
        <span class="sub" style="font-size:11px">${fmtDate(p.created_at)}</span>
      </div>
      <div class="row">
        ${p.status === 'approved'
          ? `<button class="btn ghost sm" onclick="modPost('${p.id}','hidden')">ocultar</button>`
          : `<button class="btn ghost sm" onclick="modPost('${p.id}','approved')">aprovar</button>`}
        <button class="btn danger sm" onclick="delPost('${p.id}')">excluir</button>
      </div>
    </div>`;
  }).join('') || '<div class="card empty">Nenhuma publicação ainda.</div>';
  main.innerHTML = `<h1>Comunidade</h1><div class="sub">Publicações dos usuários (moderação)</div>${cards}`;
};
window.modPost = async (id, status) => {
  await api('/admin/posts/' + id, { method: 'PATCH', body: JSON.stringify({ status }) });
  render('posts');
};
window.delPost = async (id) => {
  if (!confirm('Excluir publicação?')) return;
  await api('/admin/posts/' + id, { method: 'DELETE' });
  render('posts');
};

// ─── Usuários ───────────────────────────────────────────────────────
views.users = async () => {
  const { users } = await api("/admin/users");
  const rows = users.map((u) =>
    `<tr class="clickable" onclick="userDetail('${u.id}')"><td>${esc(u.name || "—")}</td><td>${esc(u.email || "—")}</td>
      <td>${u.role === "admin" ? '<span class="badge warn">admin</span>' : "user"}</td>
      <td>${u.is_premium ? '<span class="badge ok">Premium</span>' : '<span class="badge draft">Free</span>'}</td>
      <td>${fmtDate(u.last_seen_at)}</td></tr>`).join("") ||
    `<tr><td colspan=5 class="empty">nenhum usuário ainda</td></tr>`;
  main.innerHTML = `<h1>Usuários</h1><div class="sub">${users.length} contas</div>
    <table><tr><th>Nome</th><th>Email</th><th>Papel</th><th>Plano</th><th>Visto por último</th></tr>${rows}</table>`;
};
window.userDetail = async (id) => {
  const d = await api(`/admin/users/${id}`);
  const ev = d.events.map((e) => `<tr><td>${esc(e.name)}</td><td>${esc(e.screen || "—")}</td><td>${fmtDate(e.ts)}</td></tr>`).join("") || `<tr><td colspan=3 class="empty">—</td></tr>`;
  const le = d.lessons.map((l) => `<tr><td>${esc(l.title)}</td><td>${esc(l.status)}</td><td>${pct(l.progress_pct)}</td></tr>`).join("") || `<tr><td colspan=3 class="empty">—</td></tr>`;
  modal(`<h3>${esc(d.user.name || d.user.email)}</h3>
    <div class="sub">${esc(d.user.email)} · ${d.user.role} · ${d.sessions.length} sessões</div>
    <div class="card" style="display:flex;align-items:center;gap:12px;margin-top:12px">
      <span class="lbl" style="margin:0">Plano:</span>
      ${d.user.is_premium ? '<span class="badge ok">Premium</span>' : '<span class="badge draft">Free</span>'}
      <div class="spacer"></div>
      <button class="btn sm" onclick="setUserPremium('${id}', ${!d.user.is_premium})">
        ${d.user.is_premium ? "Tornar Free" : "Tornar Premium"}
      </button>
    </div>
    <h2>Aulas</h2><table><tr><th>Aula</th><th>Status</th><th>%</th></tr>${le}</table>
    <h2>Eventos recentes</h2><table><tr><th>Evento</th><th>Tela</th><th>Quando</th></tr>${ev}</table>
    <div class="row" style="margin-top:16px"><button class="btn ghost" onclick="this.closest('.modal-bg').remove()">Fechar</button></div>`);
};

window.setUserPremium = async (id, value) => {
  try {
    await api(`/admin/users/${id}`, { method: "PATCH", body: JSON.stringify({ is_premium: value }) });
    document.querySelector(".modal-bg")?.remove();
    userDetail(id); // reabre o modal com o plano atualizado
    if (currentView === "users") render("users"); // atualiza a coluna na lista
  } catch (e) { alert("Erro: " + e.message); }
};

// ─── Analytics ──────────────────────────────────────────────────────
views.analytics = async () => {
  const [{ screens }, { events }] = await Promise.all([api("/admin/analytics/screens"), api("/admin/analytics/events")]);
  const sRows = screens.map((s) => `<tr><td>${esc(s.screen)}</td><td>${s.views}</td><td>${s.users}</td></tr>`).join("") || `<tr><td colspan=3 class="empty">sem dados</td></tr>`;
  const eRows = events.map((e) => `<tr><td>${esc(e.name)}</td><td>${e.n}</td><td>${e.users}</td></tr>`).join("") || `<tr><td colspan=3 class="empty">sem dados</td></tr>`;
  main.innerHTML = `<h1>Analytics</h1><div class="sub">O que os usuários fazem em cada tela (30d)</div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px">
      <div><h2>Telas</h2><table><tr><th>Tela</th><th>Views</th><th>Usuários</th></tr>${sRows}</table></div>
      <div><h2>Eventos</h2><table><tr><th>Evento</th><th>Total</th><th>Usuários</th></tr>${eRows}</table></div>
    </div>`;
};

// ─── Heatmaps ───────────────────────────────────────────────────────
views.heatmap = async () => {
  const { screens } = await api('/admin/screens-with-taps');
  const opts = screens.map((s) => `<option value="${esc(s.screen)}">${esc(s.screen)} (${s.taps} toques)</option>`).join('');
  main.innerHTML = `<h1>Heatmaps</h1><div class="sub">Mapa de toques por tela (30d) — vermelho = rage tap</div>
    ${screens.length === 0 ? '<div class="card empty">Nenhum toque capturado ainda. Use o app para gerar dados.</div>' : `
    <div class="row" style="margin-bottom:16px"><label class="lbl" style="margin:0">Tela:</label>
      <select class="field" id="hm-screen" style="width:auto;margin:0">${opts}</select></div>
    <div class="card" style="display:flex;justify-content:center">
      <div id="hm-frame" style="position:relative;width:300px;height:600px;background:#1f1c18;border-radius:28px;overflow:hidden">
        <canvas id="hm-canvas" width="300" height="600" style="position:absolute;inset:0"></canvas>
      </div>
    </div>
    <div id="hm-stats" class="sub" style="text-align:center"></div>`}`;
  if (screens.length === 0) return;

  const draw = async (screen) => {
    const { points } = await api('/admin/heatmap/' + encodeURIComponent(screen));
    const cv = $('#hm-canvas'), ctx = cv.getContext('2d');
    ctx.clearRect(0, 0, cv.width, cv.height);
    // blobs de calor
    points.forEach((p) => {
      const px = p.x * cv.width, py = p.y * cv.height;
      const g = ctx.createRadialGradient(px, py, 0, px, py, 26);
      if (p.is_rage) { g.addColorStop(0, 'rgba(220,60,40,.55)'); g.addColorStop(1, 'rgba(220,60,40,0)'); }
      else { g.addColorStop(0, 'rgba(255,180,40,.32)'); g.addColorStop(1, 'rgba(255,180,40,0)'); }
      ctx.fillStyle = g; ctx.beginPath(); ctx.arc(px, py, 26, 0, Math.PI * 2); ctx.fill();
    });
    const rage = points.filter((p) => p.is_rage).length;
    $('#hm-stats').textContent = `${points.length} toques · ${rage} rage taps`;
  };
  $('#hm-screen').onchange = (e) => draw(e.target.value);
  draw(screens[0].screen);
};

// ─── Replay (timeline de sessão) ────────────────────────────────────
views.replay = async () => {
  const { sessions } = await api('/admin/sessions');
  const rows = sessions.map((s) =>
    `<tr class="clickable" onclick="openReplay('${s.id}')">
      <td>${esc(s.email || s.name || 'anônimo')}</td>
      <td>${s.events} ev · ${s.taps} toques</td>
      <td>${s.duration_s ? s.duration_s + 's' : '—'}</td>
      <td>${s.has_crash ? '<span class="badge bad">crash</span>' : ''}</td>
      <td>${fmtDate(s.started_at)}</td></tr>`).join('') ||
    `<tr><td colspan=5 class="empty">nenhuma sessão</td></tr>`;
  main.innerHTML = `<h1>Replay de sessões</h1><div class="sub">Reconstrução da jornada (timeline)</div>
    <table><tr><th>Usuário</th><th>Atividade</th><th>Duração</th><th></th><th>Início</th></tr>${rows}</table>`;
};
window.openReplay = async (id) => {
  const { session, timeline } = await api(`/admin/sessions/${id}/timeline`);
  const t0 = timeline.length ? new Date(timeline[0].ts).getTime() : 0;
  const items = timeline.map((ev) => {
    const dt = ((new Date(ev.ts).getTime() - t0) / 1000).toFixed(1);
    let label, color = 'var(--ink)';
    if (ev.kind === 'event' && ev.name === 'screen_view') { label = `entrou em <code>${esc(ev.screen)}</code>`; color = 'var(--terracotta)'; }
    else if (ev.kind === 'event') label = `${esc(ev.name)} ${ev.screen ? `<code>${esc(ev.screen)}</code>` : ''}`;
    else if (ev.kind === 'tap') label = `${ev.is_rage ? 'rage tap' : ev.is_dead ? 'dead tap' : 'toque'} em <code>${esc(ev.screen || '?')}</code>`;
    else if (ev.kind === 'crash') { label = `crash: ${esc(ev.error_type || '')}`; color = 'var(--bad)'; }
    return `<div style="display:flex;gap:12px;padding:7px 0;border-bottom:1px dotted var(--line)">
      <span class="mono" style="color:var(--muted);width:50px;text-align:right">${dt}s</span>
      <span style="color:${color}">${label}</span></div>`;
  }).join('') || '<div class="empty">sessão vazia</div>';
  modal(`<h3>Replay · ${esc(session.email || session.name || 'anônimo')}</h3>
    <div class="sub">${esc(session.platform || '?')} · app ${esc(session.app_version || '?')} · ${timeline.length} passos</div>
    <div style="max-height:60vh;overflow-y:auto;margin-top:12px">${items}</div>
    <div class="row" style="margin-top:16px"><button class="btn ghost" onclick="this.closest('.modal-bg').remove()">Fechar</button></div>`);
};

// ─── Insights (funil, retenção, frustração) ─────────────────────────
views.insights = async () => {
  const [funnel, ret, frus, ins] = await Promise.all([
    api('/admin/funnel'), api('/admin/retention'),
    api('/admin/frustration'), api('/admin/insights'),
  ]);
  const maxF = Math.max(1, ...funnel.steps.map((s) => s.users));
  const funnelHtml = funnel.steps.map((s) =>
    `<div style="margin-bottom:10px"><div class="row" style="justify-content:space-between">
       <strong>${esc(s.label)}</strong><span>${s.users}</span></div>
     <div class="bar" style="margin-top:6px"><span style="width:${(s.users / maxF) * 100}%"></span></div></div>`).join('');
  const retPct = (n) => ret.total ? Math.round((n / ret.total) * 100) : 0;
  const dwellRows = ins.dwell.map((d) => `<tr><td>${esc(d.screen)}</td><td>${d.avg_seconds}s</td></tr>`).join('') || `<tr><td colspan=2 class="empty">—</td></tr>`;
  const rageRows = ins.rage_screens.map((r) => `<tr><td>${esc(r.screen)}</td><td>${r.rage}</td></tr>`).join('') || `<tr><td colspan=2 class="empty">nenhum</td></tr>`;
  const qbRows = frus.quick_backs.map((q) => `<tr><td>${esc(q.screen)}</td><td>${q.quick_backs}</td></tr>`).join('') || `<tr><td colspan=2 class="empty">—</td></tr>`;

  main.innerHTML = `<h1>Insights</h1><div class="sub">Funil, retenção e sinais de frustração (30d)</div>
    <h2>Funil de conversão</h2><div class="card">${funnelHtml}</div>
    <h2>Retenção</h2><div class="kpis">
      <div class="kpi"><div class="label">D1</div><div class="value">${retPct(ret.d1)}%</div></div>
      <div class="kpi"><div class="label">D7</div><div class="value">${retPct(ret.d7)}%</div></div>
      <div class="kpi"><div class="label">D30</div><div class="value">${retPct(ret.d30)}%</div></div>
      <div class="kpi"><div class="label">Base</div><div class="value">${ret.total}</div></div></div>
    <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:16px;margin-top:8px">
      <div><h2>Tempo por tela</h2><table><tr><th>Tela</th><th>Média</th></tr>${dwellRows}</table></div>
      <div><h2>Telas com rage tap</h2><table><tr><th>Tela</th><th>Rage</th></tr>${rageRows}</table></div>
      <div><h2>Quick-backs</h2><table><tr><th>Tela</th><th>Saídas &lt;3s</th></tr>${qbRows}</table></div>
    </div>`;
};

// ─── Crashes ────────────────────────────────────────────────────────
views.crashes = async () => {
  const { crashes } = await api("/admin/crashes");
  const rows = crashes.map((c) =>
    `<tr class="clickable" onclick="crashDetail('${c.fingerprint}')">
      <td>${c.fatal ? '<span class="badge bad">fatal</span> ' : ""}${esc(c.error_type || "Error")}</td>
      <td style="max-width:340px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(c.message || "")}</td>
      <td>${c.occurrences}×</td><td>${c.users}</td><td>${fmtDate(c.last_seen)}</td></tr>`).join("") ||
    `<tr><td colspan=5 class="empty">nenhum crash</td></tr>`;
  main.innerHTML = `<h1>Crashes</h1><div class="sub">Agrupados por assinatura (30d)</div>
    <table><tr><th>Tipo</th><th>Mensagem</th><th>Ocorrências</th><th>Usuários</th><th>Último</th></tr>${rows}</table>`;
};
window.crashDetail = async (fp) => {
  const { crashes } = await api(`/admin/crashes/${fp}`);
  const c = crashes[0];
  modal(`<h3>${esc(c.error_type || "Error")}</h3>
    <div class="sub">${esc(c.message || "")}</div>
    <div class="sub">${c.platform || "?"} · app ${c.app_version || "?"} · OS ${c.os_version || "?"} · ${fmtDate(c.ts)}</div>
    <h2>Stack trace</h2><pre class="stack">${esc(c.stack_trace || "(sem stack)")}</pre>
    <div class="row" style="margin-top:16px"><button class="btn ghost" onclick="this.closest('.modal-bg').remove()">Fechar</button></div>`);
};

// ─── IA ─────────────────────────────────────────────────────────────
views.ai = async () => {
  const { events } = await api("/admin/analytics/events").catch(() => ({ events: [] }));
  main.innerHTML = `<h1>IA</h1><div class="sub">Análises de imagem e feedback</div>
    <div class="card">As análises agora são gravadas no banco (tabela <code>analyses</code>) e o feedback em <code>feedback</code>.
    Veja o total na Visão geral. (Detalhamento por análise entra na próxima iteração.)</div>`;
};

// ─── Equipe: usuários que acessam só o painel (admin/editor) ────────
views.team = async () => {
  const { team } = await api("/admin/team");
  const badge = (r) =>
    r === "admin"
      ? `<span style="background:#FBEDE8;color:#DB4631;border-radius:20px;padding:3px 11px;font-size:12px;font-weight:700">Admin</span>`
      : `<span style="background:#EDF1E8;color:#5b7a49;border-radius:20px;padding:3px 11px;font-size:12px;font-weight:700">Editor</span>`;
  const me = currentUser && currentUser.email;
  const rows = (team || []).map((u) => `
    <tr>
      <td><strong>${esc(u.name || "—")}</strong><br><span class="sub">${esc(u.email)}</span></td>
      <td>${badge(u.panel_role)}</td>
      <td class="sub">${u.last_seen_at ? fmtDate(u.last_seen_at) : "nunca"}</td>
      <td style="text-align:right">${
        u.email === me
          ? `<span class="sub">você</span>`
          : `<button class="btn danger sm" data-del="${u.id}">remover</button>`
      }</td>
    </tr>`).join("");
  main.innerHTML = `
    <h1>Equipe</h1>
    <div class="sub">Pessoas que acessam <strong>somente o painel</strong>.
      <strong>Admin</strong> = acesso total. <strong>Editor</strong> = só conteúdo
      (Aulas, Receitas, Pontos, Dicas, Comunidade).</div>
    <div class="card" style="margin-top:16px">
      <h2 style="margin:0 0 12px;font-size:15px">Novo acesso</h2>
      <div class="row" style="gap:10px;flex-wrap:wrap;align-items:flex-end">
        <input class="field" id="t-name" placeholder="Nome" style="flex:1;min-width:130px" />
        <input class="field" id="t-email" type="email" placeholder="email@exemplo.com" style="flex:1.4;min-width:180px" />
        <input class="field" id="t-pass" type="password" placeholder="Senha (mín. 8)" style="flex:1;min-width:140px" />
        <select class="field" id="t-role" style="flex:0 0 130px">
          <option value="editor">Editor</option>
          <option value="admin">Admin</option>
        </select>
        <button class="btn" id="t-add">Criar acesso</button>
      </div>
      <div id="t-status" class="sub" style="margin-top:8px"></div>
    </div>
    <table class="tbl" style="margin-top:18px">
      <thead><tr><th>Pessoa</th><th>Papel</th><th>Último acesso</th><th></th></tr></thead>
      <tbody>${rows || `<tr><td colspan="4" class="empty">ninguém ainda</td></tr>`}</tbody>
    </table>`;
  $("#t-add", main).onclick = async () => {
    const st = $("#t-status", main);
    st.textContent = "criando…";
    try {
      await api("/admin/team", {
        method: "POST",
        body: JSON.stringify({
          name: $("#t-name", main).value.trim() || undefined,
          email: $("#t-email", main).value.trim(),
          password: $("#t-pass", main).value,
          panel_role: $("#t-role", main).value,
        }),
      });
      render("team");
    } catch (e) {
      st.textContent = "erro: " + e.message;
    }
  };
  main.querySelectorAll("[data-del]").forEach((b) => {
    b.onclick = async () => {
      if (!confirm("Remover o acesso desta pessoa ao painel?")) return;
      try {
        await api("/admin/team/" + b.dataset.del, { method: "DELETE" });
        render("team");
      } catch (e) {
        alert(e.message);
      }
    };
  });
};

// ─── Preview da aula (mockups iOS + Android — réplica fiel do app) ───
// Espelha o lib/presentation/pages/painel/lesson_detail_page.dart:
// capa 248, título 31/w600, chips, "Step by step", botão coral "Play full
// lesson", cards de passo (nº 30 coral, título 17/w700, sub-passos, total,
// thumbnail de vídeo + "N capítulos"). Tokens iguais ao AppColors/AppTheme.
const DIF_LABEL = { beginner: "Beginner", intermediate: "Intermediate", advanced: "Advanced" };

function collectPreviewData(m, p) {
  const val = (id) => { const el = $(`#${p}-${id}`, m); return el ? el.value.trim() : ""; };
  const stStr = ($(`#${p}-lvideo-st`, m)?.textContent || "");
  const lessonVideo = !!val("lvideo") || stStr.includes("✓");
  const steps = $$(".step-card", m).map((c) => {
    const sv = ($(".s-video", c)?.value || "").trim();
    return {
      title: ($(".s-title", c)?.value || "").trim(),
      time: parseTime($(".s-time", c)?.value || ""),
      total: ($(".s-total", c)?.value || "").trim(),
      image_url: ($(".s-image", c)?.value || "").trim(),
      has_video: !!sv || !!c.dataset.videoAssetId,
      substeps: collectSubsteps(c),
    };
  });
  return {
    title: val("title") || "Sem título",
    difficulty: val("dif") || "beginner",
    duration_min: Number(val("dur")) || 10,
    cover_url: val("cover"),
    lesson_video: lessonVideo,
    steps,
  };
}

function smpVideoThumb(imageUrl, badge) {
  return `<div class="smp-video">` +
    (imageUrl ? `<img src="${esc(imageUrl)}" />` : `<div class="smp-ph">🧶</div>`) +
    `<div class="smp-vscrim"></div><div class="smp-playbtn">▶</div>` +
    (badge ? `<div class="smp-chap">≋ ${esc(badge)}</div>` : "") + `</div>`;
}

// Cada mini-passo é um card com VÍDEO PRÓPRIO (quando houver) + título + descrição.
function smpSubstep(ss, n) {
  const poster = ss.video_poster_url || "";
  const hasVid = poster || ss.video_url;
  const vid = hasVid ? `<div style="margin-bottom:10px">${smpVideoThumb(poster, "")}</div>` : "";
  return `<div style="border:1px solid #EBDCCE;border-radius:14px;padding:12px;margin-top:10px">${vid}` +
    `<div class="smp-sub" style="padding:0"><div class="smp-subnum">${n}</div><div class="smp-subtxt">` +
    (ss.title ? `<div class="smp-subt">${esc(ss.title)}</div>` : "") +
    (ss.description ? `<div class="smp-subd">${esc(ss.description)}</div>` : "") +
    `</div></div></div>`;
}

function smpStep(s, n) {
  const titleRow = `<div class="smp-srow"><div class="smp-snum">${n}</div>` +
    `<div class="smp-stitle">${esc(s.title || ("Passo " + n))}</div></div>`;
  const instr = s.instruction ? `<div class="smp-instr">${esc(s.instruction)}</div>` : "";
  const total = s.total ? `<div class="smp-total">Total: ${esc(s.total)}</div>` : "";
  const banner = `<div class="smp-banner">${s.image_url ? `<img src="${esc(s.image_url)}"/>` : `<div class="smp-ph">🧶</div>`}</div>`;
  const subs = s.substeps.length
    ? `<div class="smp-gap"></div>` + s.substeps.map((ss, i) => smpSubstep(ss, i + 1)).join("")
    : "";
  return `<div class="smp-step">${banner}<div class="smp-spad">${titleRow}${instr}${subs}${total}</div></div>`;
}

// Mapeia a aula RESOLVIDA (/v1/lessons/:slug — mesmo dado do app) para o
// formato do preview, com imagens reais (capa, imagem do passo = block.url,
// poster de vídeo) e instrução. Espelha LessonBlock.stepImageUrl do app
// (content.image_url ?? block.url).
function lessonDataFromApi(json) {
  const L = json.lesson || {};
  const meta = L.meta || {};
  const blocks = (json.blocks || []).filter((b) => b.type === "step");
  const steps = blocks.map((b) => {
    const c = b.content || {};
    const subs = (c.substeps || []).map((s) =>
      typeof s === "object"
        ? {
            title: (s.title || s.highlight || ""),
            description: (s.description || s.detail || ""),
            video_url: s.video_url || "",
            video_poster_url: s.video_poster_url || "",
          }
        : { title: String(s), description: "", video_url: "", video_poster_url: "" });
    return {
      title: c.title || "",
      instruction: c.instruction || "",
      time: c.time ?? null, // usado só pelos capítulos do vídeo da aula
      total: c.total || "",
      image_url: c.image_url || b.url || "",
      substeps: subs,
    };
  });
  return {
    title: L.title || "Sem título",
    difficulty: L.difficulty || "beginner",
    duration_min: L.duration_min || 10,
    cover_url: L.cover_url || "",
    lesson_video: !!meta.video_url,
    steps,
  };
}

// Preview da aula SALVA (resolvida, com imagens). Cai pro form se falhar
// (rascunho não publicado / sem slug).
async function previewSavedLesson(slug, m) {
  try {
    if (!slug) throw new Error("sem slug");
    const json = await api("/lessons/" + slug);
    openLessonPreview(lessonDataFromApi(json));
  } catch (_) {
    openLessonPreview(collectPreviewData(m, "e"));
  }
}

function lessonScreenHTML(d) {
  const dif = DIF_LABEL[d.difficulty] || "Beginner";
  const showPlay = d.lesson_video && d.steps.some((s) => s.time != null);
  const cover = d.cover_url
    ? `<img src="${esc(d.cover_url)}" />`
    : `<div class="smp-ph" style="font-size:48px">🧶</div>`;
  return `
    <div class="smp-coverwrap">${cover}<div class="smp-coverscrim"></div>
      <div class="smp-backbtn">‹</div></div>
    <div class="smp-content">
      <div class="smp-ltitle">${esc(d.title)}</div>
      <div class="smp-chips">
        <span class="smp-chip">▟ ${dif}</span>
        <span class="smp-chip">◷ ${d.duration_min} min</span>
        <span class="smp-chip">≣ ${d.steps.length} steps</span>
      </div>
      <div class="smp-h2">Step by step</div>
      ${showPlay ? `<div class="smp-playfull">▶&nbsp; Play full lesson</div>` : ""}
      ${d.steps.map((s, i) => smpStep(s, i + 1)).join("")}
      <div class="smp-done">✓ Concluir</div>
    </div>`;
}

let _smpStyled = false;
function injectPreviewStyles() {
  if (_smpStyled) return;
  _smpStyled = true;
  const css = `
  @import url('https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700;800&display=swap');
  .smp-overlay{position:fixed;inset:0;background:rgba(20,14,10,.6);backdrop-filter:blur(3px);
    z-index:9999;display:flex;flex-direction:column;align-items:center;gap:18px;padding:28px;overflow:auto}
  .smp-bar{display:flex;align-items:center;gap:14px;color:#fff;font-family:Poppins,sans-serif}
  .smp-bar h3{margin:0;font-size:18px;font-weight:700}
  .smp-close{margin-left:auto;background:#fff;border:none;border-radius:20px;padding:8px 16px;
    font-family:Poppins;font-weight:600;cursor:pointer}
  .smp-row{display:flex;gap:34px;flex-wrap:wrap;justify-content:center;align-items:flex-start}
  .smp-dev{font-family:Poppins,sans-serif}
  .smp-devlabel{color:#fff;text-align:center;font-family:Poppins;font-size:13px;font-weight:600;
    margin-bottom:10px;opacity:.9}
  /* Frame iPhone */
  .smp-ios{width:390px;border:12px solid #0e0e0e;border-radius:54px;overflow:hidden;
    box-shadow:0 24px 60px rgba(0,0,0,.45);position:relative;background:#000}
  .smp-ios .smp-notch{position:absolute;top:10px;left:50%;transform:translateX(-50%);
    width:120px;height:30px;background:#0e0e0e;border-radius:18px;z-index:5}
  /* Frame Android */
  .smp-and{width:360px;border:9px solid #0e0e0e;border-radius:34px;overflow:hidden;
    box-shadow:0 24px 60px rgba(0,0,0,.45);position:relative;background:#000}
  .smp-and .smp-hole{position:absolute;top:12px;left:50%;transform:translateX(-50%);
    width:11px;height:11px;background:#0e0e0e;border-radius:50%;z-index:5}
  /* Tela (conteúdo do app) */
  .smp-screen{height:660px;overflow-y:auto;background:#FAFAFA;color:#2B211B;
    font-family:Poppins,sans-serif;-webkit-font-smoothing:antialiased}
  .smp-statusbar{height:44px;display:flex;align-items:flex-end;justify-content:space-between;
    padding:0 22px 6px;font-size:13px;font-weight:600;color:#2B211B}
  .smp-statusbar.dark{color:#2B211B}
  /* Capa */
  .smp-coverwrap{position:relative;height:248px;background:#F7E4D7}
  .smp-coverwrap img{width:100%;height:100%;object-fit:cover;display:block}
  .smp-ph{width:100%;height:100%;display:flex;align-items:center;justify-content:center;
    background:#F7E4D7;font-size:40px}
  .smp-coverscrim{position:absolute;top:0;left:0;right:0;height:110px;
    background:linear-gradient(to bottom,rgba(0,0,0,.28),transparent)}
  .smp-backbtn{position:absolute;top:14px;left:16px;width:40px;height:40px;border-radius:50%;
    background:#fff;display:flex;align-items:center;justify-content:center;font-size:22px;
    color:#2B211B;box-shadow:0 2px 8px rgba(0,0,0,.15)}
  /* Conteúdo */
  .smp-content{padding:20px 24px 40px}
  .smp-ltitle{font-size:31px;font-weight:600;line-height:1.08;letter-spacing:-.5px;color:#2B211B}
  .smp-chips{display:flex;flex-wrap:wrap;gap:12px;margin-top:16px}
  .smp-chip{background:#fff;border:1px solid #ECECEC;border-radius:20px;padding:7px 13px;
    font-size:13px;font-weight:500;color:#2B211B}
  .smp-h2{font-size:21px;font-weight:600;letter-spacing:-.3px;margin-top:24px;color:#2B211B}
  .smp-playfull{margin-top:14px;background:#F2604E;color:#fff;border-radius:16px;height:56px;
    display:flex;align-items:center;justify-content:center;font-size:16px;font-weight:700;
    box-shadow:0 6px 16px rgba(242,96,78,.35)}
  /* Card de passo */
  .smp-step{background:#fff;border-radius:22px;margin-top:16px;overflow:hidden;
    box-shadow:0 6px 18px rgba(74,53,38,.06)}
  .smp-banner{height:197px;background:#F7E4D7}
  .smp-banner img{width:100%;height:100%;object-fit:cover;display:block}
  .smp-spad{padding:18px}
  .smp-gap{height:14px}
  .smp-srow{display:flex;align-items:flex-start;gap:12px}
  .smp-snum{width:30px;height:30px;border-radius:50%;background:#F2604E;color:#fff;flex:0 0 30px;
    display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:800}
  .smp-stitle{font-size:17px;font-weight:700;letter-spacing:-.2px;line-height:1.25;color:#2B211B;padding-top:3px}
  .smp-sub{display:flex;align-items:flex-start;gap:12px;padding:7px 0}
  .smp-subnum{width:26px;height:26px;border-radius:50%;background:#F7E4D7;color:#6B5D53;flex:0 0 26px;
    display:flex;align-items:center;justify-content:center;font-size:13px;font-weight:700}
  .smp-subt{font-size:15px;font-weight:700;line-height:1.35;color:#2B211B}
  .smp-subd{font-size:15px;line-height:1.4;color:#6B5D53;margin-top:2px}
  .smp-instr{margin-top:12px;font-size:15px;line-height:1.5;color:#2B211B}
  .smp-total{margin-top:12px;font-size:13px;font-weight:600;color:#A89A8E}
  /* Thumbnail de vídeo */
  .smp-video{position:relative;border-radius:16px;overflow:hidden;aspect-ratio:16/9;background:#F7E4D7}
  .smp-video img{width:100%;height:100%;object-fit:cover;display:block}
  .smp-vscrim{position:absolute;inset:0;background:rgba(0,0,0,.18)}
  .smp-playbtn{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);width:58px;height:58px;
    border-radius:50%;background:#F2604E;color:#fff;display:flex;align-items:center;justify-content:center;
    font-size:24px;box-shadow:0 4px 12px rgba(0,0,0,.25)}
  .smp-chap{position:absolute;left:10px;bottom:10px;background:rgba(0,0,0,.55);color:#fff;
    border-radius:20px;padding:5px 10px;font-size:12px;font-weight:600}
  .smp-done{margin:28px 0 0;background:#F2604E;color:#fff;border-radius:16px;height:52px;
    display:flex;align-items:center;justify-content:center;font-size:16px;font-weight:700}
  `;
  const el = document.createElement("style");
  el.textContent = css;
  document.head.appendChild(el);
}

function deviceFrame(kind, screenInner) {
  const isIos = kind === "ios";
  const chrome = isIos
    ? `<div class="smp-notch"></div><div class="smp-statusbar"><span>9:41</span><span>📶 􀙇 100%</span></div>`
    : `<div class="smp-hole"></div><div class="smp-statusbar"><span>9:41</span><span>📶 ▮ 100%</span></div>`;
  return `<div class="smp-dev">
    <div class="smp-devlabel">${isIos ? "iPhone (iOS)" : "Android"}</div>
    <div class="smp-${isIos ? "ios" : "and"}">
      <div class="smp-screen">${chrome}${screenInner}</div>
    </div></div>`;
}

function openLessonPreview(d) {
  injectPreviewStyles();
  const inner = lessonScreenHTML(d);
  const ov = document.createElement("div");
  ov.className = "smp-overlay";
  ov.innerHTML = `
    <div class="smp-bar" style="width:100%;max-width:820px">
      <h3>Pré-visualização da aula</h3>
      <span style="opacity:.8;font-size:13px">Como fica no app (iOS e Android)</span>
      <button class="smp-close">Fechar</button>
    </div>
    <div class="smp-row">
      ${deviceFrame("ios", inner)}
      ${deviceFrame("and", inner)}
    </div>`;
  ov.querySelector(".smp-close").onclick = () => ov.remove();
  ov.onclick = (e) => { if (e.target === ov) ov.remove(); };
  document.body.appendChild(ov);
}

// ─── Boot ───────────────────────────────────────────────────────────
initAuth();
