// Direction B — "Live Desk"
// Apple-grade macOS diorama. Dark wallpaper. Claude writes a note in real time.

(function () {
  const { useTyping, Caret, TrafficLights, Pill, DownloadCTA, VellemIcon, MCP_TOOLS } = window;

  const BG = "#0E1014";
  const PANEL = "#15171D";
  const CARD = "#1B1E25";
  const HAIR = "rgba(255,255,255,0.08)";
  const HAIR_STRONG = "rgba(255,255,255,0.14)";
  const TXT = "#F3F1EA";
  const TXT_SOFT = "rgba(243,241,234,0.62)";
  const TXT_MUTE = "rgba(243,241,234,0.42)";
  const ACCENT = "#F6E5A2";
  const ACCENT_DEEP = "#E8C547";

  // ---------------- Hero diorama -------------------------------------------
  const HERO_NOTE = `Storybook integration · checklist

- [x] find an eng champion (Hugo)
- [x] inventory existing stories
- [ ] wire MCP → storybook search
- [ ] draft 1-week proposal w/ Hugo
- [ ] sync w/ design before Friday`;

  function ClaudeTyping() {
    const { shown } = useTyping(HERO_NOTE, { speed: 26, delay: 1000, loopGap: 3000 });
    const lines = shown.split("\n");
    return (
      <pre style={{
        margin: 0, fontFamily: "inherit", fontSize: 15, lineHeight: 1.7,
        color: TXT, whiteSpace: "pre-wrap", minHeight: 240, textWrap: "pretty",
      }}>
        {lines.map((line, idx) => {
          const last = idx === lines.length - 1;
          if (idx === 0) {
            return <React.Fragment key={idx}>
              <strong style={{ fontWeight: 700, fontSize: 18, letterSpacing: "-0.01em" }}>{line}</strong>
              {last ? <Caret color={TXT} /> : "\n"}
            </React.Fragment>;
          }
          // Render todo markers visually
          const m = line.match(/^- \[(x| )\] (.*)$/);
          if (m) {
            const checked = m[1] === "x";
            return <React.Fragment key={idx}>
              <span style={{ display: "inline-flex", alignItems: "center", gap: 10 }}>
                <span style={{
                  width: 14, height: 14, borderRadius: 4,
                  border: `1.5px solid ${checked ? ACCENT_DEEP : HAIR_STRONG}`,
                  background: checked ? ACCENT_DEEP : "transparent",
                  display: "inline-flex", alignItems: "center", justifyContent: "center",
                  verticalAlign: "-2px",
                }}>
                  {checked && <svg width="9" height="9" viewBox="0 0 12 12" fill="none">
                    <path d="M2.5 6.5l2.5 2.5 4.5-5" stroke="#1A170E" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>}
                </span>
                <span style={{
                  color: checked ? TXT_MUTE : TXT,
                  textDecoration: checked ? "line-through" : "none",
                }}>{m[2]}</span>
              </span>
              {last ? <Caret color={TXT} /> : "\n"}
            </React.Fragment>;
          }
          return <React.Fragment key={idx}>
            <span style={{ color: TXT_SOFT }}>{line}</span>{last ? <Caret color={TXT} /> : "\n"}
          </React.Fragment>;
        })}
      </pre>
    );
  }

  function HeroDiorama() {
    return (
      <div style={{
        position: "relative", width: 1120, height: 640, margin: "0 auto",
      }}>
        {/* Main Vellem window */}
        <div style={{
          position: "absolute", inset: "20px 80px 20px 80px",
          background: PANEL,
          border: `1px solid ${HAIR_STRONG}`,
          borderRadius: 18,
          boxShadow: "0 60px 120px -40px rgba(0,0,0,0.7), 0 0 0 1px rgba(255,255,255,0.04) inset",
          overflow: "hidden",
        }}>
          {/* Toolbar */}
          <div style={{
            display: "flex", alignItems: "center", justifyContent: "space-between",
            padding: "12px 18px",
            background: "linear-gradient(180deg, #FBEFC0 0%, #F6E5A2 100%)",
            borderBottom: `1px solid ${HAIR}`,
            color: "#1A170E",
          }}>
            <div style={{ display: "flex", alignItems: "center", gap: 16 }}>
              <TrafficLights />
              <button style={{
                background: "rgba(255,255,255,0.55)", border: "1px solid rgba(0,0,0,0.08)",
                width: 26, height: 26, borderRadius: 7, fontSize: 13, cursor: "pointer"
              }}>📁</button>
              <button style={{
                background: "rgba(255,255,255,0.55)", border: "1px solid rgba(0,0,0,0.08)",
                width: 26, height: 26, borderRadius: 7, fontSize: 13, cursor: "pointer"
              }}>◧</button>
              <div style={{ fontSize: 13, fontWeight: 600, marginLeft: 6 }}>Today</div>
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <button style={{
                background: "rgba(255,255,255,0.55)", border: "1px solid rgba(0,0,0,0.08)",
                width: 26, height: 26, borderRadius: 7, fontSize: 13, cursor: "pointer"
              }}>✎</button>
              <button style={{
                background: "rgba(255,255,255,0.55)", border: "1px solid rgba(0,0,0,0.08)",
                width: 26, height: 26, borderRadius: 7, fontSize: 13, cursor: "pointer"
              }}>⚙︎</button>
            </div>
          </div>
          {/* Body */}
          <div style={{ display: "grid", gridTemplateColumns: "190px 260px 1fr", height: "calc(100% - 50px)" }}>
            {/* Sidebar */}
            <div style={{ background: "#191B22", borderRight: `1px solid ${HAIR}`, padding: "14px 10px" }}>
              <div style={{
                background: "#23262E", borderRadius: 8, padding: "6px 10px",
                fontSize: 12, color: TXT_MUTE, marginBottom: 12,
              }}>🔍 Search notes</div>
              {[
                { ic: "📅", lab: "Today", n: 3, active: true },
                { ic: "▶_", lab: "Claude", n: 6, mono: true, dot: "#F6E5A2" },
                { ic: "▶_", lab: "Codex", n: 11, mono: true, dot: "#8FB7FF" },
                { ic: "▥", lab: "Prompt Library" },
                { ic: "⚙︎", lab: "Services" },
              ].map((r, i) => (
                <div key={i} style={{
                  display: "flex", alignItems: "center", gap: 8,
                  padding: "7px 10px", borderRadius: 7, marginBottom: 1,
                  background: r.active ? "rgba(246,229,162,0.15)" : "transparent",
                  color: r.active ? ACCENT : TXT_SOFT, fontSize: 13,
                  fontWeight: r.active ? 600 : 500,
                }}>
                  <span style={{
                    width: 14, textAlign: "center", fontSize: 11,
                    fontFamily: r.mono ? "'JetBrains Mono', monospace" : "inherit",
                    color: r.dot || "inherit",
                  }}>{r.ic}</span>
                  <span style={{ flex: 1 }}>{r.lab}</span>
                  {r.n != null && <span style={{ fontSize: 11, color: TXT_MUTE }}>{r.n}</span>}
                </div>
              ))}
              <div style={{
                marginTop: 16, padding: "0 10px", fontSize: 10, fontWeight: 700,
                letterSpacing: "0.16em", color: TXT_MUTE, textTransform: "uppercase",
              }}>Folders</div>
              {["Build reports", "Dotfile candidats", "Veille X", "User interviews"].map((f, i) => (
                <div key={i} style={{
                  display: "flex", alignItems: "center", gap: 8, padding: "7px 10px",
                  fontSize: 13, color: TXT_SOFT, marginTop: 2,
                }}>
                  <span style={{ width: 8, height: 8, borderRadius: 2, background: ["#F6E5A2","#A6E0C9","#F3B0CF","#D8C7FF"][i] }} />
                  {f}
                </div>
              ))}
            </div>
            {/* Notes list */}
            <div style={{ background: PANEL, borderRight: `1px solid ${HAIR}`, padding: "16px 14px" }}>
              <div style={{
                display: "flex", alignItems: "center", gap: 8, marginBottom: 14,
              }}>
                <span style={{
                  width: 28, height: 28, borderRadius: 8,
                  background: "rgba(246,229,162,0.12)", color: ACCENT,
                  display: "inline-flex", alignItems: "center", justifyContent: "center", fontSize: 14
                }}>📅</span>
                <div>
                  <div style={{ fontSize: 13, fontWeight: 600, color: TXT }}>Today</div>
                  <div style={{ fontSize: 11, color: TXT_MUTE }}>3 notes</div>
                </div>
              </div>
              {[
                { t: "15:00", title: "Rapport · Adrien <> James", body: "Rapport meeting 27 mai 2026. Source: notes Granola (transcript verb...", words: 771, min: 24 },
                { t: "10:50", title: "Standup. 27 mai 2026", body: "Participants : Adrien, Alexis, James, Tech avance Autonomy v2 & back...", words: 422, min: 8, hr: 4 },
                { t: "09:05", title: "Storybook integration", body: "Storybook integration · checklist. - [x] find an eng champion. - [ ]...", words: 243, min: 1, active: true },
              ].map((n, i) => (
                <div key={i} style={{ display: "flex", gap: 10, marginBottom: 14 }}>
                  <div style={{ width: 36, paddingTop: 4, textAlign: "right", flexShrink: 0 }}>
                    <div style={{
                      fontSize: 11, fontFamily: "'JetBrains Mono', monospace",
                      color: n.active ? ACCENT : TXT_MUTE
                    }}>{n.t}</div>
                  </div>
                  <div style={{ position: "relative", paddingLeft: 14, flex: 1 }}>
                    <span style={{
                      position: "absolute", left: 4, top: 8, width: 6, height: 6, borderRadius: 999,
                      background: n.active ? ACCENT_DEEP : HAIR_STRONG,
                      boxShadow: n.active ? `0 0 0 4px rgba(232,197,71,0.18)` : "none",
                    }} />
                    <div style={{
                      background: n.active ? "rgba(246,229,162,0.08)" : "transparent",
                      borderRadius: 8, padding: n.active ? "8px 10px" : "0",
                      border: n.active ? `1px solid rgba(246,229,162,0.18)` : "none",
                    }}>
                      <div style={{ fontSize: 13, fontWeight: 600, color: TXT, marginBottom: 4 }}>{n.title}</div>
                      <div style={{ fontSize: 11, color: TXT_MUTE, lineHeight: 1.45, marginBottom: 6 }}>{n.body}</div>
                      <div style={{ fontSize: 10, color: TXT_MUTE, fontFamily: "'JetBrains Mono', monospace" }}>
                        {n.hr ? `${n.hr}h ` : ""}{n.min} min · {n.words} words
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
            {/* Editor */}
            <div style={{ padding: "20px 26px", position: "relative" }}>
              <div style={{
                display: "flex", alignItems: "center", gap: 8,
                fontSize: 11, color: ACCENT, fontFamily: "'JetBrains Mono', monospace",
                marginBottom: 14
              }}>
                <span style={{
                  width: 6, height: 6, borderRadius: 999, background: "#37C95E",
                  animation: "vlm-pulse-dot 1.6s ease-in-out infinite"
                }} />
                claude · via mcp · create_todo_list
              </div>
              <ClaudeTyping />
            </div>
          </div>
        </div>

        {/* Floating Quick capture sticky */}
        <div style={{
          position: "absolute", left: 0, top: 170, width: 230,
          background: "linear-gradient(180deg, #FBEFC0, #F6E5A2)",
          color: "#1A170E",
          borderRadius: 14, padding: "14px 16px",
          transform: "rotate(-4deg)",
          boxShadow: "0 30px 60px -20px rgba(0,0,0,0.55)",
          animation: "vlm-drift 4s ease-in-out infinite",
        }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
            <TrafficLights size={9} />
            <div style={{ fontSize: 10, fontWeight: 600, color: "#7A6520" }}>Quick capture</div>
          </div>
          <div style={{ fontSize: 13, fontWeight: 600, marginBottom: 4 }}>idea: weekly digest</div>
          <div style={{ fontSize: 12, lineHeight: 1.45, color: "#3a352a" }}>
            ask Claude every Friday to summarize what landed in the
            <em> Codex</em> folder this week.
          </div>
          <div style={{ marginTop: 8, fontSize: 10, color: "#7A6520" }}>⌥⌘N to capture · ↩ to save</div>
        </div>

        {/* Floating widget */}
        <div style={{
          position: "absolute", right: 0, top: 360, width: 240,
          background: PANEL, border: `1px solid ${HAIR_STRONG}`,
          borderRadius: 18, padding: "16px 18px",
          boxShadow: "0 30px 60px -20px rgba(0,0,0,0.55)",
          transform: "rotate(3deg)",
          animation: "vlm-drift 5s ease-in-out -1s infinite",
        }}>
          <div style={{
            display: "flex", justifyContent: "space-between", alignItems: "center",
            marginBottom: 10, fontSize: 11,
          }}>
            <span style={{ color: TXT_MUTE, fontWeight: 600, letterSpacing: "0.06em", textTransform: "uppercase" }}>Today</span>
            <VellemIcon size={18} />
          </div>
          <div style={{ fontSize: 14, fontWeight: 700, color: TXT, marginBottom: 8 }}>3 notes today</div>
          <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
            {["Rapport · Adrien <> James", "Standup. 27 mai", "Storybook integration"].map((t, i) => (
              <div key={i} style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <span style={{ width: 4, height: 4, borderRadius: 999, background: ACCENT_DEEP }} />
                <span style={{ fontSize: 11, color: TXT_SOFT }}>{t}</span>
              </div>
            ))}
          </div>
          <div style={{
            marginTop: 12, paddingTop: 10, borderTop: `1px solid ${HAIR}`,
            fontSize: 10, color: TXT_MUTE
          }}>WidgetKit · medium</div>
        </div>
      </div>
    );
  }

  // ---------------- Hero ---------------------------------------------------
  function Hero() {
    return (
      <section style={{
        background: `radial-gradient(ellipse at 50% 0%, #1F2129 0%, ${BG} 60%)`,
        color: TXT, padding: "32px 56px 80px", position: "relative",
        overflow: "hidden",
      }}>
        {/* Top bar */}
        <div style={{
          display: "flex", alignItems: "center", justifyContent: "space-between",
          marginBottom: 56,
        }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <VellemIcon size={30} />
            <span style={{ fontSize: 17, fontWeight: 700 }}>Vellem</span>
            <span style={{
              marginLeft: 10, fontSize: 11, color: TXT_MUTE,
              fontFamily: "'JetBrains Mono', monospace"
            }}>v1.0.8</span>
          </div>
          <nav style={{
            display: "flex", gap: 28, fontSize: 13, color: TXT_SOFT,
            fontFeatureSettings: "'ss01' on",
          }}>
            <span>Tour</span><span>14 tools</span><span>Setup</span><span>Changelog</span>
          </nav>
          <div style={{
            display: "inline-flex", alignItems: "center", gap: 8,
            padding: "8px 14px", borderRadius: 999,
            background: "rgba(246,229,162,0.10)",
            border: `1px solid rgba(246,229,162,0.22)`,
            fontSize: 12, color: ACCENT,
          }}>
            <span style={{ width: 6, height: 6, borderRadius: 999, background: "#37C95E", animation: "vlm-pulse-dot 1.6s ease-in-out infinite" }} />
            mcp · 14 tools live
          </div>
        </div>

        {/* Headline */}
        <div style={{ textAlign: "center", maxWidth: 980, margin: "0 auto 48px" }}>
          <Pill style={{ background: "rgba(246,229,162,0.10)", color: ACCENT, border: `1px solid rgba(246,229,162,0.25)` }}>
            The notebook for your AI agents
          </Pill>
          <h1 style={{
            margin: "26px 0 0",
            fontSize: 108, lineHeight: 0.95, letterSpacing: "-0.04em",
            fontWeight: 700, color: TXT,
          }}>
            A real desk for the work<br />
            your agents <em style={{ color: ACCENT, fontStyle: "italic", fontWeight: 500, fontFamily: "'Instrument Serif', serif" }}>actually do</em>.
          </h1>
          <p style={{
            margin: "26px auto 0", maxWidth: 620,
            fontSize: 18, lineHeight: 1.55, color: TXT_SOFT,
          }}>
            Vellem is a native macOS notebook that Claude, Codex and any MCP client write into
            — alongside your own notes. Local-first. Foldered. Yours.
          </p>
        </div>

        {/* Diorama */}
        <HeroDiorama />

        {/* CTA */}
        <div style={{ marginTop: 64 }}>
          <DownloadCTA tone="dark" />
        </div>

        {/* Hairline gradient ring at bottom */}
        <div style={{
          position: "absolute", left: 0, right: 0, bottom: 0, height: 1,
          background: "linear-gradient(90deg, transparent, rgba(246,229,162,0.4), transparent)"
        }} />
      </section>
    );
  }

  // ---------------- Problem ------------------------------------------------
  function Problem() {
    return (
      <section style={{ background: BG, color: TXT, padding: "120px 80px" }}>
        <div style={{ maxWidth: 1120, margin: "0 auto" }}>
          <div style={{ display: "grid", gridTemplateColumns: "1.1fr 1fr", gap: 80, alignItems: "center" }}>
            <div>
              <div style={{
                fontSize: 11, fontWeight: 700, letterSpacing: "0.22em",
                color: ACCENT, textTransform: "uppercase", marginBottom: 18,
              }}>The problem</div>
              <h2 style={{
                margin: 0, fontSize: 80, lineHeight: 0.95, letterSpacing: "-0.035em",
                color: TXT, fontWeight: 700,
              }}>
                Agents have <em style={{ fontStyle: "italic", color: ACCENT, fontFamily: "'Instrument Serif', serif", fontWeight: 500 }}>perfect recall</em><br />
                <span style={{ color: TXT_MUTE }}>— inside one window.</span>
              </h2>
              <p style={{ marginTop: 28, fontSize: 17, lineHeight: 1.6, color: TXT_SOFT, maxWidth: 520 }}>
                Close the tab and it's all gone: the 12-step migration plan, the code review,
                the candidate debrief, the way you finally got it to think the right way.
                Your agent walks home with empty pockets.
              </p>
              <div style={{
                marginTop: 32, fontSize: 12, color: TXT_MUTE,
                fontFamily: "'JetBrains Mono', monospace",
              }}>
                ❯ context_window.length<br />
                <span style={{ color: "#FF8A6B" }}>0</span> · cleared on quit
              </div>
            </div>

            {/* Visual: a fading transcript */}
            <div style={{
              background: PANEL, border: `1px solid ${HAIR_STRONG}`,
              borderRadius: 18, padding: "22px 24px",
              boxShadow: "0 40px 80px -40px rgba(0,0,0,0.6)",
              position: "relative", overflow: "hidden",
            }}>
              <div style={{
                display: "flex", alignItems: "center", gap: 10,
                paddingBottom: 14, borderBottom: `1px solid ${HAIR}`,
                marginBottom: 18, fontSize: 12, color: TXT_MUTE,
                fontFamily: "'JetBrains Mono', monospace",
              }}>
                <span style={{ width: 6, height: 6, borderRadius: 999, background: "#FF8A6B" }} />
                claude · session expired · context lost
              </div>
              <div className="vlm-mask-fade-out" style={{ fontSize: 14, lineHeight: 1.7, color: TXT_SOFT }}>
                <div style={{ marginBottom: 12 }}><strong style={{ color: TXT }}>You</strong>: where were we on the storybook migration?</div>
                <div style={{ marginBottom: 12, opacity: 0.8 }}><strong style={{ color: TXT }}>You</strong>: also — what were the top 3 reasons we picked Hugo?</div>
                <div style={{ marginBottom: 12, opacity: 0.6 }}><strong style={{ color: TXT }}>You</strong>: and the candidate debrief from yesterday?</div>
                <div style={{ marginBottom: 12, opacity: 0.4 }}><strong style={{ color: TXT }}>You</strong>: ok forget it. start over.</div>
                <div style={{ marginBottom: 12, opacity: 0.25 }}><strong style={{ color: ACCENT }}>Claude</strong>: I don't have access to prior conversations…</div>
              </div>
              <div style={{
                position: "absolute", bottom: 18, left: 24, right: 24,
                padding: "10px 14px", borderRadius: 10,
                background: "rgba(246,229,162,0.12)", border: `1px solid rgba(246,229,162,0.22)`,
                fontSize: 12, color: ACCENT, display: "flex", alignItems: "center", gap: 8,
                fontFamily: "'JetBrains Mono', monospace",
              }}>
                ✓ with vellem: claude.search_notes("storybook") → 3 hits, 0 amnesia
              </div>
            </div>
          </div>
        </div>
      </section>
    );
  }

  // ---------------- Tools grid ---------------------------------------------
  function ToolsGrid() {
    return (
      <section style={{ background: "#0A0B0E", color: TXT, padding: "120px 80px" }}>
        <div style={{ maxWidth: 1160, margin: "0 auto" }}>
          <div style={{ display: "flex", alignItems: "end", justifyContent: "space-between", marginBottom: 64 }}>
            <div>
              <div style={{
                fontSize: 11, fontWeight: 700, letterSpacing: "0.22em",
                color: ACCENT, textTransform: "uppercase", marginBottom: 18,
              }}>vellem-mcp · 14 tools</div>
              <h2 style={{
                margin: 0, fontSize: 76, lineHeight: 0.95, letterSpacing: "-0.035em",
                fontWeight: 700,
              }}>
                Everything an agent<br />
                needs to <em style={{ color: ACCENT, fontFamily: "'Instrument Serif', serif", fontWeight: 500, fontStyle: "italic" }}>actually take notes</em>.
              </h2>
            </div>
            <div style={{
              fontSize: 12, color: TXT_MUTE, fontFamily: "'JetBrains Mono', monospace",
              textAlign: "right", maxWidth: 280, lineHeight: 1.7,
            }}>
              <span style={{ color: TXT_SOFT }}>$ claude mcp list</span><br />
              vellem ➝ 14 tools<br />
              <span style={{ color: "#37C95E" }}>✓ ready</span>
            </div>
          </div>

          <div style={{
            display: "grid", gridTemplateColumns: "repeat(7, 1fr)", gap: 1,
            background: HAIR, border: `1px solid ${HAIR}`, borderRadius: 14, overflow: "hidden",
          }}>
            {MCP_TOOLS.map((t, i) => {
              return (
                <div key={t.name} style={{
                  background: CARD, padding: "18px 16px",
                  gridColumn: i < 14 ? "span 2" : "span 2",
                  position: "relative",
                  minHeight: 130,
                }}>
                  <div style={{
                    fontSize: 10, fontFamily: "'JetBrains Mono', monospace",
                    color: TXT_MUTE, marginBottom: 8, letterSpacing: "0.04em",
                  }}>{String(i + 1).padStart(2, "0")} / 14</div>
                  <div style={{
                    fontFamily: "'JetBrains Mono', monospace",
                    fontSize: 14, fontWeight: 600, color: TXT, marginBottom: 6,
                    letterSpacing: "-0.01em", lineHeight: 1.2,
                  }}>
                    {t.name}<span style={{ color: TXT_MUTE }}>()</span>
                  </div>
                  <div style={{ fontSize: 12, color: TXT_SOFT, lineHeight: 1.45 }}>{t.desc}</div>
                  <div style={{
                    position: "absolute", top: 16, right: 14,
                    fontSize: 9, fontWeight: 700, letterSpacing: "0.16em",
                    textTransform: "uppercase", color: verbColor(t.verb),
                  }}>{t.verb}</div>
                </div>
              );
            })}
          </div>

          <div style={{
            marginTop: 28, fontSize: 12, color: TXT_MUTE,
            fontFamily: "'JetBrains Mono', monospace", textAlign: "center"
          }}>
            create · append · read · write · destroy — every CRUD verb your agent needs
          </div>
        </div>
      </section>
    );
  }

  function verbColor(v) {
    return {
      create:  "#A6E0C9",
      read:    "#8FB7FF",
      write:   "#F6E5A2",
      append:  "#E0B98F",
      destroy: "#FF8A6B",
    }[v] || TXT_MUTE;
  }

  // ---------------- Native strip -------------------------------------------
  function NativeStrip() {
    return (
      <section style={{ background: BG, color: TXT, padding: "120px 80px" }}>
        <div style={{ maxWidth: 1120, margin: "0 auto" }}>
          <div style={{ textAlign: "center", marginBottom: 72 }}>
            <div style={{
              fontSize: 11, fontWeight: 700, letterSpacing: "0.22em",
              color: ACCENT, textTransform: "uppercase", marginBottom: 18,
            }}>Native, all the way down</div>
            <h2 style={{
              margin: 0, fontSize: 76, lineHeight: 0.95, letterSpacing: "-0.035em",
              fontWeight: 700, maxWidth: 920, marginInline: "auto",
            }}>
              Quick capture. Widgets. A Today view that <em style={{
                color: ACCENT, fontFamily: "'Instrument Serif', serif", fontWeight: 500, fontStyle: "italic"
              }}>actually opens</em>.
            </h2>
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1.4fr 1fr", gap: 24, alignItems: "stretch" }}>
            {/* Quick capture */}
            <div style={{
              background: "linear-gradient(180deg, #FBEFC0, #F6E5A2)",
              borderRadius: 16, padding: "18px 20px", color: "#1A170E",
              boxShadow: "0 30px 60px -30px rgba(232,197,71,0.4)",
            }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 14 }}>
                <TrafficLights size={9} />
                <div style={{ fontSize: 11, fontWeight: 600, color: "#7A6520" }}>⌥⌘N · Quick capture</div>
              </div>
              <div style={{ fontSize: 14, fontWeight: 600, marginBottom: 8, letterSpacing: "-0.01em" }}>
                idea: weekly Codex digest
              </div>
              <div style={{ fontSize: 13, lineHeight: 1.55, color: "#3a352a" }}>
                ask Claude every Friday to summarize what landed in
                <em> Codex</em> this week<Caret color="#1A170E" />
              </div>
              <div style={{
                marginTop: 36, paddingTop: 12, borderTop: "1px solid rgba(0,0,0,0.08)",
                display: "flex", justifyContent: "space-between", fontSize: 11, color: "#7A6520"
              }}>
                <span>⌥⌘N anywhere</span><span>↩ to save</span>
              </div>
            </div>

            {/* Today */}
            <div style={{
              background: PANEL, border: `1px solid ${HAIR_STRONG}`,
              borderRadius: 16, padding: "22px 26px",
              boxShadow: "0 30px 60px -30px rgba(0,0,0,0.5)",
            }}>
              <div style={{
                display: "flex", justifyContent: "space-between", alignItems: "center",
                marginBottom: 18,
              }}>
                <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                  <VellemIcon size={22} />
                  <div>
                    <div style={{ fontSize: 14, fontWeight: 700 }}>Today</div>
                    <div style={{ fontSize: 11, color: TXT_MUTE }}>Wednesday, 27 May 2026</div>
                  </div>
                </div>
                <span style={{ fontSize: 11, color: TXT_MUTE }}>3 notes · 1,436 words</span>
              </div>
              {[
                { t: "15:00", title: "Rapport · Adrien <> James", folder: "Build reports", dot: "#F6E5A2" },
                { t: "10:50", title: "Standup. 27 mai 2026", folder: "Dotfile meetings", dot: "#A6E0C9" },
                { t: "09:05", title: "Storybook integration", folder: "Claude", dot: "#8FB7FF", active: true },
              ].map((n, i) => (
                <div key={i} style={{
                  display: "flex", gap: 14, alignItems: "center",
                  padding: "10px 12px", borderRadius: 10, marginBottom: 4,
                  background: n.active ? "rgba(246,229,162,0.10)" : "transparent",
                  border: n.active ? `1px solid rgba(246,229,162,0.22)` : "1px solid transparent",
                }}>
                  <div style={{ fontSize: 11, color: n.active ? ACCENT : TXT_MUTE, fontFamily: "'JetBrains Mono', monospace", width: 36 }}>{n.t}</div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 13, fontWeight: 600, color: TXT }}>{n.title}</div>
                    <div style={{ fontSize: 11, color: TXT_MUTE, marginTop: 2, display: "flex", alignItems: "center", gap: 6 }}>
                      <span style={{ width: 6, height: 6, borderRadius: 2, background: n.dot }} /> {n.folder}
                    </div>
                  </div>
                  {n.active && <span style={{
                    fontSize: 10, color: ACCENT, fontFamily: "'JetBrains Mono', monospace",
                    fontWeight: 600
                  }}>↩</span>}
                </div>
              ))}
            </div>

            {/* Widget */}
            <div style={{
              background: "linear-gradient(165deg, #2A2D36, #15171D)",
              border: `1px solid ${HAIR_STRONG}`,
              borderRadius: 22, padding: "18px 20px",
              boxShadow: "0 30px 60px -30px rgba(0,0,0,0.5)",
              position: "relative",
            }}>
              <div style={{
                display: "flex", justifyContent: "space-between", alignItems: "center",
                marginBottom: 12, fontSize: 10,
              }}>
                <span style={{ color: TXT_MUTE, fontWeight: 700, letterSpacing: "0.16em", textTransform: "uppercase" }}>Widget · medium</span>
                <VellemIcon size={20} />
              </div>
              <div style={{ fontSize: 15, fontWeight: 700, color: TXT, marginBottom: 8, letterSpacing: "-0.01em" }}>
                Latest from Claude
              </div>
              <div style={{ fontSize: 12, color: TXT_SOFT, lineHeight: 1.5, marginBottom: 12 }}>
                Migration · Supanote → Vellem. All app-group entries replaced. Tous les Supanote remplacés en mémoire.
              </div>
              <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
                {["Storybook integration", "Standup. 27 mai 2026", "Rapport Adrien <> James"].map((t, i) => (
                  <div key={i} style={{ display: "flex", alignItems: "center", gap: 6 }}>
                    <span style={{ width: 4, height: 4, borderRadius: 999, background: ACCENT_DEEP }} />
                    <span style={{ fontSize: 11, color: TXT_SOFT }}>{t}</span>
                  </div>
                ))}
              </div>
              <div style={{
                position: "absolute", bottom: 16, left: 20, right: 20,
                fontSize: 10, color: TXT_MUTE, fontFamily: "'JetBrains Mono', monospace",
                display: "flex", justifyContent: "space-between"
              }}>
                <span>WidgetKit</span><span>all sizes</span>
              </div>
            </div>
          </div>

          <div style={{ marginTop: 60, textAlign: "center", fontSize: 13, color: TXT_MUTE }}>
            Menu bar · global hotkey · Today · WidgetKit (S/M/L/XL) · interactive todos · Apple Foundation Models on 26+
          </div>
        </div>
      </section>
    );
  }

  // ---------------- Setup --------------------------------------------------
  function Setup() {
    return (
      <section style={{
        background: `linear-gradient(180deg, ${BG} 0%, #07080B 100%)`,
        color: TXT, padding: "120px 80px",
      }}>
        <div style={{ maxWidth: 920, margin: "0 auto" }}>
          <div style={{ textAlign: "center", marginBottom: 48 }}>
            <div style={{
              fontSize: 11, fontWeight: 700, letterSpacing: "0.22em",
              color: ACCENT, textTransform: "uppercase", marginBottom: 18,
            }}>Two minutes to connect</div>
            <h2 style={{
              margin: 0, fontSize: 64, lineHeight: 0.95, letterSpacing: "-0.035em",
              fontWeight: 700,
            }}>
              Paste this into Claude.<br />
              <em style={{ color: ACCENT, fontFamily: "'Instrument Serif', serif", fontWeight: 500, fontStyle: "italic" }}>You're done.</em>
            </h2>
          </div>
          <div style={{
            background: "#08090C", border: `1px solid ${HAIR_STRONG}`,
            borderRadius: 14, padding: "20px 24px",
            fontFamily: "'JetBrains Mono', monospace",
            fontSize: 14, lineHeight: 1.6, color: TXT,
            position: "relative",
          }}>
            <div style={{
              position: "absolute", top: 12, right: 12,
              fontSize: 10, fontWeight: 600, letterSpacing: "0.18em",
              color: TXT_MUTE, textTransform: "uppercase",
            }}>claude_desktop_config.json</div>
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
            textAlign: "center", marginTop: 28, fontSize: 15, color: TXT_SOFT,
            maxWidth: 620, marginInline: "auto", lineHeight: 1.6
          }}>
            Same shape for Codex or any MCP client. Restart, ask <em style={{ color: ACCENT }}>"save that to Vellem"</em>,
            watch the note land in the <span style={{ color: ACCENT }}>Claude</span> smart folder.
          </p>
        </div>
      </section>
    );
  }

  // ---------------- Footer -------------------------------------------------
  function Footer() {
    return (
      <section style={{ background: "#07080B", color: TXT, padding: "60px 80px 40px", borderTop: `1px solid ${HAIR}` }}>
        <div style={{
          maxWidth: 1120, margin: "0 auto",
          display: "flex", justifyContent: "space-between", alignItems: "center",
        }}>
          <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
            <VellemIcon size={32} />
            <div>
              <div style={{ fontSize: 16, fontWeight: 700 }}>Vellem</div>
              <div style={{ fontSize: 11, color: TXT_MUTE }}>Local-first · MIT · v1.0.8</div>
            </div>
          </div>
          <div style={{ fontSize: 13, color: TXT_MUTE, display: "flex", gap: 22 }}>
            <span>GitHub</span><span>Releases</span><span>Privacy</span><span>support@vellem.app</span>
          </div>
        </div>
      </section>
    );
  }

  function DirectionB() {
    return (
      <div style={{
        width: 1280, background: BG, color: TXT,
        fontFamily: "'Inter Tight', system-ui, sans-serif",
        fontFeatureSettings: "'ss01' on, 'cv11' on",
      }}>
        <Hero />
        <Problem />
        <ToolsGrid />
        <NativeStrip />
        <Setup />
        <Footer />
      </div>
    );
  }

  window.DirectionB = DirectionB;
})();
