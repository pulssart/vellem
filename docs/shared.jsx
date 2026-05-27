// Shared data + small primitives for the three Vellem landing directions.

const MCP_TOOLS = [
  { name: "add_note",         verb: "create",  desc: "Drop a new Markdown note into Vellem." },
  { name: "append_to_daily",  verb: "append",  desc: "Tack a snippet onto today's daily note." },
  { name: "create_todo_list", verb: "create",  desc: "Spin up a checklist with interactive todos." },
  { name: "add_todo",         verb: "append",  desc: "Add one task to an existing note." },
  { name: "list_notes",       verb: "read",    desc: "List notes, most recent first." },
  { name: "search_notes",     verb: "read",    desc: "Full-text search title and body." },
  { name: "get_note",         verb: "read",    desc: "Pull a note's full content by id." },
  { name: "update_note",      verb: "write",   desc: "Replace a note's body in place." },
  { name: "delete_note",      verb: "destroy", desc: "Remove a note for good." },
  { name: "list_folders",     verb: "read",    desc: "Enumerate every folder + note count." },
  { name: "create_folder",    verb: "create",  desc: "Make a new folder, idempotently." },
  { name: "delete_folder",    verb: "destroy", desc: "Remove a folder, keep its notes." },
  { name: "set_folder_color", verb: "write",   desc: "Tint a folder yellow, blue, pink…" },
  { name: "move_note",        verb: "write",   desc: "Reshelf a note into another folder." },
];

// The "Claude writes a note" agent typing animation hook.
// Returns the currently visible substring of `text` and a `done` flag.
function useTyping(text, { speed = 28, delay = 600, loop = true, loopGap = 2200 } = {}) {
  const [i, setI] = React.useState(0);
  const [phase, setPhase] = React.useState("typing"); // typing | hold | erasing
  React.useEffect(() => {
    let t;
    if (phase === "typing") {
      if (i < text.length) {
        t = setTimeout(() => setI(i + 1), speed + (text[i] === "\n" ? 120 : 0) + (Math.random() * 30));
      } else {
        t = setTimeout(() => setPhase(loop ? "hold" : "done"), delay);
      }
    } else if (phase === "hold") {
      t = setTimeout(() => setPhase("erasing"), loopGap);
    } else if (phase === "erasing") {
      if (i > 0) {
        t = setTimeout(() => setI(i - 1), Math.max(6, speed / 3));
      } else {
        t = setTimeout(() => setPhase("typing"), 400);
      }
    }
    return () => clearTimeout(t);
  }, [i, phase, text, speed, delay, loop, loopGap]);
  return { shown: text.slice(0, i), done: phase === "done", phase };
}

// Tiny SF-ish caret used inside note bodies.
function Caret({ color = "currentColor" }) {
  return <span style={{
    display: "inline-block", width: 2, height: "1.05em", verticalAlign: "-0.15em",
    background: color, marginLeft: 1, borderRadius: 1,
    animation: "vlm-caret-blink 1s steps(2,end) infinite"
  }} />;
}

// macOS traffic lights.
function TrafficLights({ size = 12, gap = 8, dimmed = false }) {
  const colors = dimmed
    ? ["#3a3a3a", "#3a3a3a", "#3a3a3a"]
    : ["#FF5F57", "#FEBC2E", "#28C840"];
  return (
    <div style={{ display: "flex", gap, alignItems: "center" }}>
      {colors.map((c, i) => (
        <span key={i} style={{
          width: size, height: size, borderRadius: "50%",
          background: c, boxShadow: "inset 0 0 0 0.5px rgba(0,0,0,0.18)"
        }} />
      ))}
    </div>
  );
}

// Cream pill (re-used across directions for "the notebook for your AI agents").
function Pill({ children, style }) {
  return (
    <span style={{
      display: "inline-flex", alignItems: "center", gap: 8,
      padding: "8px 16px", borderRadius: 999,
      background: "#FBEFC0", color: "#9A7B12",
      fontSize: 11, fontWeight: 600, letterSpacing: "0.18em",
      textTransform: "uppercase", whiteSpace: "nowrap",
      border: "1px solid #F1DF8E",
      ...(style || {})
    }}>{children}</span>
  );
}

// ── GitHub releases — fetched once, shared across the page ────────────────
// We mirror the logic of the existing pulssart/vellem site: pull the latest
// 20 releases, filter drafts/prereleases, and pick the first DMG asset of
// the freshest one to wire the download CTA.

const GH_REPO = "pulssart/vellem";
let __releasesPromise = null;
function fetchReleasesOnce() {
  if (__releasesPromise) return __releasesPromise;
  __releasesPromise = fetch(
    `https://api.github.com/repos/${GH_REPO}/releases?per_page=20`,
    { headers: { Accept: "application/vnd.github+json" } }
  ).then((r) => {
    if (!r.ok) throw new Error("GitHub API " + r.status);
    return r.json();
  }).then((list) => {
    const visible = (list || []).filter((r) => !r.draft && !r.prerelease);
    return visible.map((r) => ({
      ...r,
      dmg: (r.assets || []).find((a) => /\.dmg$/i.test(a.name)) || null,
    }));
  });
  return __releasesPromise;
}

function useReleases() {
  const [state, setState] = React.useState({ releases: [], status: "loading" });
  React.useEffect(() => {
    let cancelled = false;
    fetchReleasesOnce()
      .then((releases) => { if (!cancelled) setState({ releases, status: "ready" }); })
      .catch(() => { if (!cancelled) setState({ releases: [], status: "error" }); });
    return () => { cancelled = true; };
  }, []);
  return {
    releases: state.releases,
    release: state.releases[0] || null,
    status: state.status,
  };
}

// ── Tiny markdown renderer for release bodies ────────────────────────────
// Same shape as the existing pulssart/vellem site: escape first, then
// apply a handful of patterns. Outputs HTML for use with
// dangerouslySetInnerHTML.

function escapeHTML(s) {
  return s.replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  }[c]));
}

function mdInline(s) {
  s = escapeHTML(s);
  s = s.replace(/`([^`]+)`/g, "<code>$1</code>");
  s = s.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  s = s.replace(/\[([^\]]+)\]\((https?:[^)]+)\)/g,
    '<a href="$2" target="_blank" rel="noopener">$1</a>');
  return s;
}

function renderMarkdown(md) {
  if (!md) return "";
  const lines = md.split(/\r?\n/);
  let html = "";
  let inList = false;
  const flushList = () => { if (inList) { html += "</ul>"; inList = false; } };
  for (const raw of lines) {
    const line = raw.trimEnd();
    if (!line.trim()) { flushList(); continue; }
    const bullet  = line.match(/^\s*[-*]\s+(.*)$/);
    const heading = line.match(/^#{1,6}\s+(.*)$/);
    if (heading) { flushList(); html += `<p><strong>${mdInline(heading[1])}</strong></p>`; continue; }
    if (bullet) {
      if (!inList) { html += "<ul>"; inList = true; }
      html += `<li>${mdInline(bullet[1])}</li>`;
      continue;
    }
    flushList();
    html += `<p>${mdInline(line)}</p>`;
  }
  flushList();
  return html;
}

function formatReleaseDate(iso) {
  if (!iso) return "";
  try {
    return new Date(iso).toLocaleDateString(undefined, {
      year: "numeric", month: "short", day: "numeric"
    });
  } catch { return ""; }
}

// Reusable download CTA (black pill, matches existing site).
function DownloadCTA({ tone = "dark", caption = "Universal · macOS 26+ · Signed & notarized" }) {
  const dark = tone === "dark";
  const { release, status } = useReleases();
  const tag = release?.tag_name || "v1.0.8";
  const size = release?.dmg
    ? `${(release.dmg.size / (1024 * 1024)).toFixed(1)} MB`
    : "5.9 MB";
  const href = release?.dmg?.browser_download_url
    || "https://github.com/pulssart/vellem/releases/latest";
  return (
    <div style={{ textAlign: "center" }}>
      <div style={{
        fontSize: 13, color: dark ? "rgba(255,255,255,0.55)" : "#8a7a48",
        marginBottom: 14, letterSpacing: "0.02em"
      }}>
        {tag}  ·  {size}
      </div>
      <a href={href} target="_blank" rel="noopener" style={{
        display: "inline-flex", alignItems: "center", gap: 10,
        padding: "14px 26px", borderRadius: 14,
        background: dark ? "#0E0E0E" : "#111",
        color: "#fff", border: "none", cursor: "pointer",
        fontSize: 15, fontWeight: 600, fontFamily: "inherit",
        textDecoration: "none",
        boxShadow: "0 1px 0 rgba(255,255,255,0.06) inset, 0 12px 28px -12px rgba(0,0,0,0.55)"
      }}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M12 3v12" /><path d="m7 10 5 5 5-5" /><path d="M5 21h14" />
        </svg>
        Download for macOS
      </a>
      <div style={{
        marginTop: 14, fontSize: 12,
        color: dark ? "rgba(255,255,255,0.45)" : "#8a7a48",
        letterSpacing: "0.02em"
      }}>{caption}{status === "error" ? " · (offline)" : ""}</div>
    </div>
  );
}

// Vellem icon — uses the actual PNG with optional soft halo.
function VellemIcon({ size = 80, halo = false }) {
  return (
    <div style={{
      width: size, height: size,
      borderRadius: size * 0.22,
      position: "relative", display: "inline-block",
      boxShadow: halo
        ? "0 24px 60px -20px rgba(213,170,40,0.45), 0 6px 14px -6px rgba(0,0,0,0.25)"
        : "0 6px 14px -6px rgba(0,0,0,0.2)"
    }}>
      <img src="assets/vellem-icon@2x.png" width={size} height={size}
           style={{ display: "block", borderRadius: "inherit" }} alt="Vellem" />
    </div>
  );
}

// Inject one keyframes block, once.
(function injectGlobals() {
  if (document.getElementById("__vlm_globals")) return;
  const s = document.createElement("style");
  s.id = "__vlm_globals";
  s.textContent = `
    @keyframes vlm-caret-blink { 0%, 50% { opacity: 1 } 50.01%, 100% { opacity: 0 } }
    @keyframes vlm-pulse-dot { 0%, 100% { transform: scale(1); opacity: 1 } 50% { transform: scale(1.6); opacity: 0.4 } }
    @keyframes vlm-drift { 0% { transform: translateY(0) } 50% { transform: translateY(-8px) } 100% { transform: translateY(0) } }
    @keyframes vlm-orbit { from { transform: rotate(0deg) } to { transform: rotate(360deg) } }
    @keyframes vlm-fade-erase {
      0%, 70% { opacity: 1; filter: blur(0); letter-spacing: normal; }
      85% { opacity: 0.25; filter: blur(2px); letter-spacing: 0.2em; }
      100% { opacity: 0; filter: blur(6px); letter-spacing: 0.4em; }
    }
    @keyframes vlm-spin-slow { from { transform: rotate(0) } to { transform: rotate(360deg) } }
    .vlm-mask-fade-out {
      mask-image: linear-gradient(180deg, #000 0%, #000 60%, transparent 100%);
      -webkit-mask-image: linear-gradient(180deg, #000 0%, #000 60%, transparent 100%);
    }
  `;
  document.head.appendChild(s);
})();

Object.assign(window, {
  MCP_TOOLS, useTyping, Caret, TrafficLights, Pill, DownloadCTA, VellemIcon,
  useReleases, renderMarkdown, formatReleaseDate,
});
