// Direction A — "The Forgetting"
// Editorial manifesto. Cream paper. Words that physically erase themselves.

(function () {
  const { useTyping, Caret, TrafficLights, Pill, DownloadCTA, VellemIcon, MCP_TOOLS,
          useReleases, renderMarkdown, formatReleaseDate } = window;

  // --- Local palette --------------------------------------------------------
  const CREAM = "#F7EFD7";
  const CREAM_DEEP = "#F0E3B0";
  const PAPER = "#FBF7E8";
  const INK = "#15140F";
  const INK_SOFT = "#3a352a";
  const RULE = "#E6D9A6";
  const ACCENT = "#E8C547";

  // --- Hero typing demo -----------------------------------------------------
  const NOTE_BODY = `Update on Storybook integration

I'm sorry for the lateness — temp in my room is 32°C.
Found my Storybook champion on the eng side: Hugo.
Setting up our first sync at the end of the week.

Goal: understand how Storybook is used today, then
hook it into Claude as a real context layer for design.`;

  function NotebookDemo() {
    const { shown } = useTyping(NOTE_BODY, { speed: 22, delay: 800, loopGap: 2600 });
    return (
      <div style={{
        background: "#FFFDF4",
        border: `1px solid ${RULE}`,
        borderRadius: 18,
        boxShadow: "0 1px 0 #fff inset, 0 30px 80px -40px rgba(60,40,0,0.35), 0 2px 0 rgba(0,0,0,0.02)",
        overflow: "hidden",
        width: 720,
        margin: "0 auto",
      }}>
        {/* Window chrome */}
        <div style={{
          display: "flex", alignItems: "center", justifyContent: "space-between",
          padding: "12px 16px",
          background: "linear-gradient(180deg, #FBEFC0, #F6E5A2)",
          borderBottom: `1px solid ${RULE}`
        }}>
          <TrafficLights />
          <div style={{
            fontSize: 12, fontWeight: 600, color: "#7A6520", letterSpacing: "0.02em"
          }}>Vellem · Claude is writing…</div>
          <div style={{ display: "flex", gap: 6 }}>
            <span style={{ width: 22, height: 22, borderRadius: 6, background: "rgba(0,0,0,0.04)" }} />
            <span style={{ width: 22, height: 22, borderRadius: 6, background: "rgba(0,0,0,0.04)" }} />
          </div>
        </div>
        {/* Body */}
        <div style={{
          display: "grid",
          gridTemplateColumns: "200px 1fr",
          minHeight: 360,
        }}>
          {/* Sidebar */}
          <div style={{
            background: "#FAF3D9",
            borderRight: `1px solid ${RULE}`,
            padding: "16px 12px",
            fontSize: 13,
            color: INK_SOFT,
          }}>
            <div style={{
              fontSize: 10, fontWeight: 700, letterSpacing: "0.16em",
              color: "#A38B2C", textTransform: "uppercase", marginBottom: 12
            }}>Smart folders</div>
            {[
              { icon: "📅", label: "Today", count: 3, active: false },
              { icon: "▶_", label: "Claude", count: 6, active: true, mono: true },
              { icon: "▶_", label: "Codex", count: 11, mono: true },
              { icon: "📚", label: "Prompt Library" },
              { icon: "⚙︎", label: "Services" },
            ].map((r, i) => (
              <div key={i} style={{
                display: "flex", alignItems: "center", gap: 8,
                padding: "8px 10px",
                borderRadius: 8,
                background: r.active ? "#F1DF8E" : "transparent",
                color: r.active ? INK : INK_SOFT,
                fontWeight: r.active ? 600 : 500,
                marginBottom: 2,
              }}>
                <span style={{
                  width: 16, textAlign: "center", fontSize: 11,
                  fontFamily: r.mono ? "'JetBrains Mono', monospace" : "inherit",
                }}>{r.icon}</span>
                <span style={{ flex: 1 }}>{r.label}</span>
                {r.count != null && <span style={{ fontSize: 11, color: "#A89248" }}>{r.count}</span>}
              </div>
            ))}
          </div>
          {/* Note */}
          <div style={{ padding: "22px 28px", position: "relative", background: "#FFFDF4" }}>
            <div style={{
              display: "flex", alignItems: "center", gap: 8,
              fontSize: 11, color: "#A38B2C", fontFamily: "'JetBrains Mono', monospace",
              marginBottom: 14
            }}>
              <span style={{
                width: 6, height: 6, borderRadius: 999, background: "#37C95E",
                animation: "vlm-pulse-dot 1.6s ease-in-out infinite"
              }} />
              claude · via mcp · add_note
            </div>
            <pre style={{
              margin: 0,
              fontFamily: "inherit",
              fontSize: 15,
              lineHeight: 1.6,
              color: INK,
              whiteSpace: "pre-wrap",
              wordBreak: "break-word",
              minHeight: 240,
              textWrap: "pretty",
            }}>
              {shown.split("\n").map((line, idx, arr) => (
                <React.Fragment key={idx}>
                  {idx === 0 ? <strong style={{ fontWeight: 700, fontSize: 17 }}>{line}</strong> : line}
                  {idx === arr.length - 1 ? <Caret color={INK} /> : "\n"}
                </React.Fragment>
              ))}
            </pre>
          </div>
        </div>
      </div>
    );
  }

  // --- Hero -----------------------------------------------------------------
  function Hero({ heroWord = "forget" }) {
    return (
      <section style={{
        position: "relative",
        background: `radial-gradient(circle at 50% -10%, ${CREAM_DEEP} 0%, ${CREAM} 35%, ${PAPER} 80%)`,
        padding: "72px 80px 80px",
        overflow: "hidden",
      }}>
        {/* Top bar */}
        <div style={{
          display: "flex", alignItems: "center", justifyContent: "space-between",
          marginBottom: 72,
        }}>
          <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
            <VellemIcon size={36} />
            <span style={{ fontSize: 19, fontWeight: 700, letterSpacing: "-0.01em", color: INK }}>Vellem</span>
          </div>
          <nav style={{ display: "flex", gap: 28, fontSize: 14, color: INK_SOFT }}>
            <span>Manifesto</span><span>How it works</span><span>14 tools</span><span>Download</span>
          </nav>
        </div>

        {/* Manifesto */}
        <div style={{ position: "relative", maxWidth: 1100, margin: "0 auto" }}>
          <div style={{ display: "flex", justifyContent: "center", marginBottom: 26 }}>
            <Pill>The notebook for your AI agents</Pill>
          </div>
          <h1 style={{
            margin: 0, textAlign: "center",
            fontFamily: "'Instrument Serif', 'Times New Roman', serif",
            fontWeight: 400, fontStyle: "normal",
            fontSize: 168, lineHeight: 0.95,
            letterSpacing: "-0.045em", color: INK,
          }}>
            They read.
            <br />
            They write.
            <br />
            <span style={{ display: "inline-block", position: "relative" }}>
              They <em style={{ fontStyle: "italic", color: "#9A7B12" }}>{heroWord}</em>.
              <span aria-hidden style={{
                position: "absolute",
                left: -10, right: -10, top: "52%", height: 6,
                background: "#9A7B12",
                transform: "rotate(-1.5deg)",
                opacity: 0.85,
              }} />
            </span>
          </h1>

          <p style={{
            margin: "44px auto 0", maxWidth: 640, textAlign: "center",
            fontSize: 20, lineHeight: 1.55, color: INK_SOFT, letterSpacing: "-0.005em",
          }}>
            Every session with Claude or Codex ends in a closed window —
            and a fog where the research, the plans, the half-finished thoughts used to be.
            <br /><br />
            <strong style={{ color: INK }}>Vellem is the notebook they keep.</strong>
            {" "}A native macOS app, MCP-native, local-first. Notes your agents own forever — and so do you.
          </p>

          <div style={{ marginTop: 56 }}>
            <DownloadCTA tone="light" />
          </div>
        </div>

        {/* Decorative torn paper edge */}
        <svg style={{ position: "absolute", left: 0, right: 0, bottom: -1, width: "100%", height: 24 }}
             viewBox="0 0 1280 24" preserveAspectRatio="none">
          <path d="M0 24 L0 8 L80 14 L160 6 L240 18 L320 8 L400 16 L480 4 L560 12 L640 18 L720 6 L800 14 L880 8 L960 18 L1040 10 L1120 16 L1200 6 L1280 14 L1280 24 Z"
                fill="#FFFDF4" />
        </svg>
      </section>
    );
  }

  // --- Live demo strip ------------------------------------------------------
  function LiveDemo() {
    return (
      <section style={{ background: "#FFFDF4", padding: "80px 80px 100px" }}>
        <div style={{ textAlign: "center", marginBottom: 40 }}>
          <div style={{
            fontSize: 11, fontWeight: 700, letterSpacing: "0.22em",
            color: "#A38B2C", textTransform: "uppercase", marginBottom: 14
          }}>Live, right now</div>
          <h2 style={{
            margin: 0,
            fontFamily: "'Instrument Serif', serif",
            fontSize: 64, lineHeight: 1, letterSpacing: "-0.03em",
            color: INK, fontWeight: 400,
          }}>
            Watch Claude write a note <em>into your notebook</em>.
          </h2>
        </div>
        <NotebookDemo />
        <p style={{
          textAlign: "center", marginTop: 32, fontSize: 14,
          color: INK_SOFT, fontFamily: "'JetBrains Mono', monospace",
          letterSpacing: "0.02em"
        }}>
          $ claude → vellem.add_note(folder: "Claude") → ✓ saved locally
        </p>
      </section>
    );
  }

  // --- The Problem ---------------------------------------------------------
  function Problem() {
    return (
      <section style={{
        background: `linear-gradient(180deg, #FFFDF4 0%, ${CREAM} 100%)`,
        padding: "100px 80px 120px"
      }}>
        <div style={{
          maxWidth: 920, margin: "0 auto",
        }}>
          <div style={{
            fontSize: 11, fontWeight: 700, letterSpacing: "0.22em",
            color: "#A38B2C", textTransform: "uppercase", marginBottom: 18
          }}>The problem</div>

          <h2 style={{
            margin: 0,
            fontFamily: "'Instrument Serif', serif",
            fontSize: 88, lineHeight: 1, letterSpacing: "-0.035em",
            color: INK, fontWeight: 400,
            textWrap: "balance",
          }}>
            Your agent finishes a brilliant piece of work,
            then{" "}
            <span style={{ position: "relative", display: "inline-block" }}>
              <em style={{ fontStyle: "italic", color: "#9A7B12" }}>vanishes</em>
              <svg style={{ position: "absolute", left: 0, right: 0, bottom: -8, width: "100%", height: 14 }}
                   viewBox="0 0 200 14" preserveAspectRatio="none">
                <path d="M2 8 C 60 2, 140 14, 198 6" stroke="#9A7B12" strokeWidth="2.5" fill="none" strokeLinecap="round" />
              </svg>
            </span>{" "}
            with it.
          </h2>

          <div style={{
            display: "grid", gridTemplateColumns: "1fr 1fr",
            gap: 56, marginTop: 64,
            fontSize: 17, lineHeight: 1.6, color: INK_SOFT, letterSpacing: "-0.005em",
          }}>
            <p style={{ margin: 0 }}>
              You wrote a 12-step migration plan with Claude on Tuesday.
              On Friday you ask "where were we?" and a fresh context window
              stares back, blank and polite.
            </p>
            <p style={{ margin: 0 }}>
              Codex shipped a code review you can't find. The chat is gone.
              The decisions are gone. The reasoning is gone. The reproducibility
              budget you thought you had — gone with it.
            </p>
          </div>

          {/* Erasing words demonstration */}
          <div style={{
            marginTop: 80, padding: "36px 40px",
            background: "#FFFDF4",
            border: `1px solid ${RULE}`,
            borderRadius: 18,
            position: "relative",
          }}>
            <div style={{
              fontSize: 11, fontWeight: 700, letterSpacing: "0.22em",
              color: "#A38B2C", textTransform: "uppercase", marginBottom: 16,
              fontFamily: "'JetBrains Mono', monospace"
            }}>~/last-session.txt</div>
            <pre style={{
              margin: 0, fontFamily: "'JetBrains Mono', monospace",
              fontSize: 15, lineHeight: 1.7, color: INK, whiteSpace: "pre-wrap"
            }}>
{`> the migration steps were `}<span style={{ animation: "vlm-fade-erase 4s ease-in-out infinite" }}>{`[redacted by amnesia]`}</span>{`
> the candidate's strengths were `}<span style={{ animation: "vlm-fade-erase 4s ease-in-out 0.6s infinite" }}>{`[redacted by amnesia]`}</span>{`
> the bug was in `}<span style={{ animation: "vlm-fade-erase 4s ease-in-out 1.2s infinite" }}>{`[redacted by amnesia]`}</span>
            </pre>
          </div>
        </div>
      </section>
    );
  }

  // --- 14 tools grid -------------------------------------------------------
  function ToolsGrid() {
    return (
      <section style={{
        background: CREAM, padding: "120px 80px",
        backgroundImage: `repeating-linear-gradient(0deg, transparent 0, transparent 31px, rgba(154,123,18,0.07) 31px, rgba(154,123,18,0.07) 32px)`,
      }}>
        <div style={{ maxWidth: 1120, margin: "0 auto" }}>
          <div style={{ display: "flex", alignItems: "end", justifyContent: "space-between", marginBottom: 56 }}>
            <div>
              <div style={{
                fontSize: 11, fontWeight: 700, letterSpacing: "0.22em",
                color: "#A38B2C", textTransform: "uppercase", marginBottom: 18,
              }}>The MCP server</div>
              <h2 style={{
                margin: 0,
                fontFamily: "'Instrument Serif', serif",
                fontSize: 76, lineHeight: 0.95, letterSpacing: "-0.035em",
                color: INK, fontWeight: 400,
              }}>
                Fourteen verbs.
                <br /><em style={{ color: "#9A7B12" }}>One notebook.</em>
              </h2>
            </div>
            <div style={{
              fontFamily: "'JetBrains Mono', monospace",
              fontSize: 12, color: INK_SOFT, textAlign: "right",
              maxWidth: 280, lineHeight: 1.6
            }}>
              $ which vellem-mcp<br />
              <span style={{ color: "#9A7B12" }}>/Applications/Vellem.app/<br />Contents/Resources/<br />vellem-mcp</span>
            </div>
          </div>

          <div style={{
            display: "grid",
            gridTemplateColumns: "repeat(2, 1fr)",
            gap: 16,
          }}>
            {MCP_TOOLS.map((t, i) => (
              <div key={t.name} style={{
                background: "#FFFDF4",
                border: `1px solid ${RULE}`,
                borderRadius: 14,
                padding: "20px 22px",
                display: "grid",
                gridTemplateColumns: "44px 1fr auto",
                gap: 18, alignItems: "center",
                position: "relative",
              }}>
                {/* Index */}
                <div style={{
                  fontFamily: "'JetBrains Mono', monospace",
                  fontSize: 11, color: "#A89248", fontWeight: 600,
                  letterSpacing: "0.06em",
                }}>{String(i + 1).padStart(2, "0")}</div>
                {/* Name + desc */}
                <div>
                  <div style={{
                    fontFamily: "'JetBrains Mono', monospace",
                    fontSize: 15, fontWeight: 600, color: INK, letterSpacing: "-0.01em",
                    marginBottom: 4,
                  }}>{t.name}<span style={{ color: "#A89248" }}>()</span></div>
                  <div style={{ fontSize: 13, color: INK_SOFT, lineHeight: 1.45 }}>{t.desc}</div>
                </div>
                {/* Verb badge */}
                <div style={{
                  fontSize: 10, fontWeight: 700, letterSpacing: "0.16em",
                  textTransform: "uppercase", color: verbColor(t.verb),
                  border: `1px solid ${verbColor(t.verb)}40`,
                  background: `${verbColor(t.verb)}14`,
                  padding: "4px 8px", borderRadius: 6,
                }}>{t.verb}</div>
              </div>
            ))}
          </div>
        </div>
      </section>
    );
  }

  function verbColor(v) {
    return {
      create:  "#1f8a5b",
      read:    "#3b6fc4",
      write:   "#9A7B12",
      append:  "#b07020",
      destroy: "#b03a3a",
    }[v] || "#666";
  }

  // --- Quick capture + Widgets + Today --------------------------------------
  function NativeStrip() {
    return (
      <section style={{
        background: "#FFFDF4", padding: "120px 80px",
      }}>
        <div style={{
          maxWidth: 1120, margin: "0 auto",
          textAlign: "center", marginBottom: 80,
        }}>
          <div style={{
            fontSize: 11, fontWeight: 700, letterSpacing: "0.22em",
            color: "#A38B2C", textTransform: "uppercase", marginBottom: 18
          }}>It's a real Mac app, not a webview</div>
          <h2 style={{
            margin: 0,
            fontFamily: "'Instrument Serif', serif",
            fontSize: 80, lineHeight: 0.95, letterSpacing: "-0.035em",
            color: INK, fontWeight: 400, maxWidth: 900, marginInline: "auto",
            textWrap: "balance"
          }}>
            Quick capture. <em style={{ color: "#9A7B12" }}>Widgets.</em> A Today view that actually starts your day.
          </h2>
        </div>

        <div style={{
          display: "grid",
          gridTemplateColumns: "1fr 1fr 1fr",
          gap: 24, maxWidth: 1120, margin: "0 auto",
        }}>
          {/* Quick capture sticky */}
          <div style={{
            background: "linear-gradient(180deg, #FBEFC0, #F6E5A2)",
            border: `1px solid ${RULE}`,
            borderRadius: 14,
            padding: "16px 18px",
            transform: "rotate(-1.4deg)",
            boxShadow: "0 30px 40px -28px rgba(120,90,10,0.4)",
            minHeight: 220, position: "relative",
          }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 }}>
              <TrafficLights size={10} />
              <div style={{ fontSize: 11, color: "#7A6520", fontWeight: 600 }}>Quick capture</div>
              <div style={{ width: 22 }} />
            </div>
            <div style={{ fontSize: 15, fontWeight: 600, color: INK, marginBottom: 6 }}>
              call Hugo re: storybook
            </div>
            <div style={{ fontSize: 14, color: INK_SOFT, lineHeight: 1.55 }}>
              after 16h. ask if eng has bandwidth before EOW.
              <Caret color={INK} />
            </div>
            <div style={{
              position: "absolute", bottom: 14, left: 16, right: 16,
              display: "flex", justifyContent: "space-between", alignItems: "center",
              fontSize: 11, color: "#7A6520"
            }}>
              <span>⌥⌘N</span><span>Save · ↩</span>
            </div>
          </div>

          {/* Today widget */}
          <div style={{
            background: "#fff",
            border: `1px solid ${RULE}`,
            borderRadius: 22,
            padding: "20px 22px",
            boxShadow: "0 30px 40px -28px rgba(40,30,0,0.25)",
            minHeight: 220,
          }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 14 }}>
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <VellemIcon size={20} />
                <span style={{ fontSize: 13, fontWeight: 600, color: INK }}>Today</span>
              </div>
              <span style={{ fontSize: 11, color: "#A89248" }}>3 notes</span>
            </div>
            {[
              { t: "15:00", title: "Rapport · Adrien <> James", words: 771 },
              { t: "10:50", title: "Standup. 27 mai 2026", words: 422 },
              { t: "09:05", title: "Update on Storybook", words: 243, active: true },
            ].map((n, i) => (
              <div key={i} style={{
                display: "flex", gap: 12, padding: "8px 10px",
                borderRadius: 8, marginBottom: 4,
                background: n.active ? "#FBEFC0" : "transparent",
              }}>
                <div style={{
                  fontSize: 11, fontFamily: "'JetBrains Mono', monospace",
                  color: "#A89248", width: 40, paddingTop: 2
                }}>{n.t}</div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 13, fontWeight: 600, color: INK }}>{n.title}</div>
                  <div style={{ fontSize: 11, color: "#A89248", marginTop: 2 }}>{n.words} words</div>
                </div>
              </div>
            ))}
          </div>

          {/* WidgetKit widget */}
          <div style={{
            background: "linear-gradient(160deg, #FBEFC0, #F6E5A2)",
            border: `1px solid ${RULE}`,
            borderRadius: 22,
            padding: "20px 22px",
            boxShadow: "0 30px 40px -28px rgba(120,90,10,0.4)",
            minHeight: 220, position: "relative",
          }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 14 }}>
              <span style={{ fontSize: 11, color: "#7A6520", fontWeight: 600, letterSpacing: "0.06em", textTransform: "uppercase" }}>Latest from Claude</span>
              <VellemIcon size={20} />
            </div>
            <div style={{ fontSize: 16, fontWeight: 700, color: INK, marginBottom: 8, letterSpacing: "-0.01em" }}>
              Migration · Supanote → Vellem
            </div>
            <div style={{ fontSize: 12, color: INK_SOFT, lineHeight: 1.5 }}>
              Migration complete. All Supanote app group entries replaced by Vellem in code &amp; project. Tous les Supanote…
            </div>
            <div style={{
              position: "absolute", bottom: 16, left: 22, right: 22,
              display: "flex", justifyContent: "space-between", alignItems: "center",
              fontSize: 11, color: "#7A6520"
            }}>
              <span>27 mai · 09:05</span>
              <span>medium · macOS widget</span>
            </div>
          </div>
        </div>

        <div style={{ marginTop: 60, textAlign: "center", fontSize: 13, color: INK_SOFT }}>
          Menu bar app · global hotkey · WidgetKit (all sizes) · Markdown rendering with interactive todos
        </div>
      </section>
    );
  }

  // --- Setup snippet --------------------------------------------------------
  function Setup() {
    return (
      <section style={{ background: "#1A170E", padding: "100px 80px", color: "#F0E8C8" }}>
        <div style={{ maxWidth: 920, margin: "0 auto" }}>
          <div style={{ textAlign: "center", marginBottom: 40 }}>
            <div style={{
              fontSize: 11, fontWeight: 700, letterSpacing: "0.22em",
              color: "#D9B84A", textTransform: "uppercase", marginBottom: 18,
            }}>Two minutes to connect</div>
            <h2 style={{
              margin: 0,
              fontFamily: "'Instrument Serif', serif",
              fontSize: 64, lineHeight: 1, letterSpacing: "-0.03em",
              color: "#FBEFC0", fontWeight: 400,
            }}>
              Add this to <code style={{
                fontFamily: "'JetBrains Mono', monospace", fontSize: 38, color: "#E8C547"
              }}>claude_desktop_config.json</code>
            </h2>
          </div>

          <div style={{
            background: "#0E0C06",
            border: "1px solid rgba(232,197,71,0.18)",
            borderRadius: 14,
            padding: "20px 24px",
            fontFamily: "'JetBrains Mono', monospace",
            fontSize: 14, lineHeight: 1.6,
            color: "#F0E8C8",
            position: "relative",
          }}>
            <div style={{
              position: "absolute", top: 12, right: 12,
              fontSize: 10, fontWeight: 600, letterSpacing: "0.18em",
              color: "#7d6a2a", textTransform: "uppercase",
            }}>json</div>
            <pre style={{ margin: 0, whiteSpace: "pre-wrap" }}>
{`{
  "mcpServers": {
    "vellem": {
      "command": "/Applications/Vellem.app/Contents/Resources/vellem-mcp"
    }
  }
}`}
            </pre>
          </div>

          <p style={{
            textAlign: "center", marginTop: 32, fontSize: 16,
            color: "#D9CD9A", lineHeight: 1.6, maxWidth: 620, marginInline: "auto"
          }}>
            Restart Claude. Ask it to <em style={{ color: "#FBEFC0" }}>"save that to Vellem"</em>.
            It lands in the <code style={{ background: "rgba(232,197,71,0.12)", padding: "2px 6px", borderRadius: 4, color: "#E8C547" }}>Claude</code> smart folder automatically.
          </p>
        </div>
      </section>
    );
  }

  // --- What's new (live from GitHub releases) -------------------------------
  function WhatsNew() {
    const { releases, status } = useReleases();
    const [expanded, setExpanded] = React.useState(false);
    const visible = expanded ? releases : releases.slice(0, 3);

    return (
      <section style={{
        background: PAPER, padding: "120px 80px",
        backgroundImage: `repeating-linear-gradient(0deg, transparent 0, transparent 31px, rgba(154,123,18,0.06) 31px, rgba(154,123,18,0.06) 32px)`,
        borderTop: `1px solid ${RULE}`,
      }}>
        <style>{`
          .vlm-release-body { font-size: 15px; line-height: 1.65; color: ${INK_SOFT}; }
          .vlm-release-body p { margin: 0 0 10px; }
          .vlm-release-body ul { margin: 8px 0 12px; padding-left: 20px; }
          .vlm-release-body li { margin-bottom: 6px; }
          .vlm-release-body strong { color: ${INK}; font-weight: 600; }
          .vlm-release-body code {
            background: #FBEFC0; color: #6A540C;
            padding: 1px 6px; border-radius: 4px;
            font-family: 'JetBrains Mono', monospace; font-size: 0.88em;
          }
          .vlm-release-body a {
            color: #9A7B12; text-decoration: none;
            border-bottom: 1px solid #E6D9A6;
          }
          .vlm-release-body a:hover { border-bottom-color: #9A7B12; }
        `}</style>

        <div style={{ maxWidth: 920, margin: "0 auto" }}>
          {/* Section head */}
          <div style={{
            display: "flex", alignItems: "end", justifyContent: "space-between",
            marginBottom: 56, gap: 40,
          }}>
            <div>
              <div style={{
                fontSize: 11, fontWeight: 700, letterSpacing: "0.22em",
                color: "#A38B2C", textTransform: "uppercase", marginBottom: 18,
              }}>What's new · live from GitHub</div>
              <h2 style={{
                margin: 0,
                fontFamily: "'Instrument Serif', serif",
                fontSize: 76, lineHeight: 0.95, letterSpacing: "-0.035em",
                color: INK, fontWeight: 400,
              }}>
                The diary of a<br />
                <em style={{ color: "#9A7B12" }}>quiet little app</em>.
              </h2>
            </div>
            <div style={{
              fontSize: 13, color: INK_SOFT, maxWidth: 280, lineHeight: 1.6, textAlign: "right"
            }}>
              Auto-updates from <strong style={{ color: INK }}>1.0.3</strong> onward.<br />
              Pulled live from{" "}
              <a href="https://github.com/pulssart/vellem/releases"
                 target="_blank" rel="noopener"
                 style={{ color: "#9A7B12", borderBottom: `1px solid #E6D9A6`, textDecoration: "none" }}>
                pulssart/vellem
              </a>.
            </div>
          </div>

          {/* States */}
          {status === "loading" && (
            <div style={{
              padding: "60px 0", textAlign: "center", color: INK_SOFT,
              fontFamily: "'JetBrains Mono', monospace", fontSize: 14,
            }}>
              <span style={{
                display: "inline-block", width: 6, height: 6, borderRadius: 999,
                background: "#37C95E", marginRight: 10, verticalAlign: "middle",
                animation: "vlm-pulse-dot 1.6s ease-in-out infinite"
              }} />
              Fetching release notes from GitHub…
            </div>
          )}

          {status === "error" && (
            <div style={{
              padding: "32px 28px", background: "#FFFDF4",
              border: `1px dashed ${RULE}`, borderRadius: 14,
              color: INK_SOFT, fontSize: 14, textAlign: "center",
            }}>
              Couldn't reach GitHub right now. Head straight to{" "}
              <a href={`https://github.com/pulssart/vellem/releases`}
                 target="_blank" rel="noopener"
                 style={{ color: "#9A7B12", borderBottom: `1px solid #E6D9A6`, textDecoration: "none" }}>
                the releases page
              </a>{" "}
              for the latest notes.
            </div>
          )}

          {/* Releases */}
          {status === "ready" && visible.length === 0 && (
            <div style={{
              padding: "40px 28px", background: "#FFFDF4",
              border: `1px solid ${RULE}`, borderRadius: 14,
              color: INK_SOFT, fontStyle: "italic", textAlign: "center",
            }}>
              No releases published yet.
            </div>
          )}

          {status === "ready" && visible.map((r) => (
            <article key={r.id || r.tag_name} style={{
              background: "#FFFDF4",
              border: `1px solid ${RULE}`,
              borderRadius: 16,
              padding: "26px 30px",
              marginBottom: 16,
              position: "relative",
              boxShadow: "0 1px 0 #fff inset",
            }}>
              {/* Header row */}
              <div style={{
                display: "flex", alignItems: "baseline", gap: 16,
                marginBottom: 14, flexWrap: "wrap",
              }}>
                <span style={{
                  display: "inline-flex", alignItems: "center", gap: 6,
                  padding: "4px 12px", borderRadius: 999,
                  background: "#FBEFC0", color: "#9A7B12",
                  fontSize: 12, fontWeight: 700, letterSpacing: "0.04em",
                  border: `1px solid #F1DF8E`,
                  fontFamily: "'JetBrains Mono', monospace",
                }}>{r.tag_name}</span>
                <span style={{
                  fontFamily: "'Instrument Serif', serif", fontSize: 28,
                  lineHeight: 1, color: INK, letterSpacing: "-0.02em",
                }}>{(r.name || r.tag_name || "").replace(/^Vellem\s*/i, "") || "Release"}</span>
                <span style={{
                  marginLeft: "auto", fontSize: 12, color: "#A89248",
                  fontFamily: "'JetBrains Mono', monospace",
                }}>{formatReleaseDate(r.published_at)}</span>
              </div>

              {/* Body */}
              <div
                className="vlm-release-body"
                dangerouslySetInnerHTML={{
                  __html: renderMarkdown(r.body || "") || "<p><em>No notes provided.</em></p>"
                }}
              />

              {/* Footer: download */}
              {r.dmg && (
                <div style={{
                  marginTop: 18, paddingTop: 16,
                  borderTop: `1px dashed ${RULE}`,
                  display: "flex", justifyContent: "space-between", alignItems: "center",
                  fontSize: 12, color: INK_SOFT,
                  fontFamily: "'JetBrains Mono', monospace",
                }}>
                  <span>{r.dmg.name} · {(r.dmg.size / (1024 * 1024)).toFixed(1)} MB</span>
                  <a href={r.dmg.browser_download_url}
                     target="_blank" rel="noopener"
                     style={{ color: "#9A7B12", borderBottom: `1px solid #E6D9A6`, textDecoration: "none" }}>
                    download dmg ↓
                  </a>
                </div>
              )}
            </article>
          ))}

          {/* Expand / GitHub link */}
          {status === "ready" && releases.length > 3 && !expanded && (
            <div style={{ textAlign: "center", marginTop: 28 }}>
              <button onClick={() => setExpanded(true)} style={{
                background: "transparent", border: `1px solid ${RULE}`,
                color: INK_SOFT, padding: "10px 18px", borderRadius: 999,
                fontSize: 13, fontWeight: 500, cursor: "pointer", fontFamily: "inherit",
              }}>
                Show {releases.length - 3} earlier release{releases.length - 3 === 1 ? "" : "s"}
              </button>
            </div>
          )}

          {status === "ready" && releases.length > 0 && (
            <div style={{ textAlign: "center", marginTop: 32, fontSize: 13, color: INK_SOFT }}>
              <a href="https://github.com/pulssart/vellem/releases"
                 target="_blank" rel="noopener"
                 style={{ color: "#9A7B12", borderBottom: `1px solid #E6D9A6`, textDecoration: "none" }}>
                See full release history on GitHub →
              </a>
            </div>
          )}
        </div>
      </section>
    );
  }

  // --- Footer ---------------------------------------------------------------
  function Footer() {
    return (
      <section style={{
        background: PAPER, padding: "80px 80px 60px", borderTop: `1px solid ${RULE}`,
      }}>
        <div style={{
          maxWidth: 1120, margin: "0 auto",
          display: "flex", justifyContent: "space-between", alignItems: "end",
        }}>
          <div>
            <h3 style={{
              margin: 0,
              fontFamily: "'Instrument Serif', serif",
              fontSize: 56, lineHeight: 0.95, letterSpacing: "-0.03em",
              color: INK, fontWeight: 400, maxWidth: 520,
            }}>
              Beautiful. Native. <em style={{ color: "#9A7B12" }}>Yours.</em>
            </h3>
            <p style={{ marginTop: 16, fontSize: 15, color: INK_SOFT, maxWidth: 520, lineHeight: 1.6 }}>
              Everything lives in your Apple App Group container.
              No cloud, no sync server, no telemetry. Apple Foundation Models on macOS 26+.
            </p>
          </div>
          <div style={{ textAlign: "right", fontSize: 13, color: INK_SOFT }}>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "end", gap: 10, marginBottom: 12 }}>
              <VellemIcon size={32} />
              <span style={{ fontSize: 16, fontWeight: 700, color: INK }}>Vellem</span>
            </div>
            <div>MIT · made in France · v1.0.8</div>
            <div style={{ marginTop: 4, color: "#A89248" }}>github · all releases · privacy</div>
          </div>
        </div>
      </section>
    );
  }

  function DirectionA({ width = 1280, tweaks = {} } = {}) {
    const t = {
      heroWord: tweaks.heroWord ?? "forget",
      showLiveDemo: tweaks.showLiveDemo ?? true,
      showProblem: tweaks.showProblem ?? true,
      showTools: tweaks.showTools ?? true,
      showNative: tweaks.showNative ?? true,
      showSetup: tweaks.showSetup ?? true,
      showWhatsNew: tweaks.showWhatsNew ?? true,
      showFooter: tweaks.showFooter ?? true,
    };
    return (
      <div style={{ width, color: INK, fontFamily: "'Inter Tight', system-ui, sans-serif" }}>
        <Hero heroWord={t.heroWord} />
        {t.showLiveDemo && <LiveDemo />}
        {t.showProblem && <Problem />}
        {t.showTools && <ToolsGrid />}
        {t.showNative && <NativeStrip />}
        {t.showSetup && <Setup />}
        {t.showWhatsNew && <WhatsNew />}
        {t.showFooter && <Footer />}
      </div>
    );
  }

  window.DirectionA = DirectionA;
})();
