// Direction C — "Agent Atelier"
// Playful. Agents as colored orbs scribbling into their folders.
// Flower-petal motif from the Vellem icon used as decoration.

(function () {
  const { useTyping, Caret, TrafficLights, Pill, DownloadCTA, VellemIcon, MCP_TOOLS } = window;

  const CREAM = "#FBF5DD";
  const CREAM_DEEP = "#F5E8AE";
  const INK = "#1A170E";
  const INK_SOFT = "#4d4632";
  const INK_MUTE = "#8A7E50";
  const ACCENT = "#E8C547";

  const AGENTS = [
    { name: "claude",  color: "#E8C547", deep: "#9A7B12", glyph: "✦",  folder: "Claude",     count: 6 },
    { name: "codex",   color: "#A6E0C9", deep: "#2E7D5B", glyph: "λ",  folder: "Codex",      count: 11 },
    { name: "cursor",  color: "#F3B0CF", deep: "#9A3A6E", glyph: "⌘",  folder: "Cursor",     count: 4 },
    { name: "you",     color: "#1A170E", deep: "#1A170E", glyph: "♥",  folder: "Today",      count: 3, you: true },
  ];

  // ---------------- Petal motif (used as decoration) -----------------------
  function PetalRing({ size = 140, opacity = 0.18, color = ACCENT }) {
    // 8 petals like the icon's flower
    const petals = Array.from({ length: 8 }, (_, i) => (i * 360) / 8);
    return (
      <svg width={size} height={size} viewBox="-50 -50 100 100" style={{ opacity }}>
        {petals.map((a) => (
          <g key={a} transform={`rotate(${a})`}>
            <path d="M0 -38 C 8 -28, 8 -10, 0 -2 C -8 -10, -8 -28, 0 -38 Z"
                  fill={color} stroke={color} strokeWidth="0.5" />
          </g>
        ))}
        <circle r="6" fill={color} opacity="0.6" />
      </svg>
    );
  }

  // ---------------- Hero — agent orbs writing -------------------------------
  function AgentOrb({ a, x, y, delay, line }) {
    const { shown } = useTyping(line, { speed: 36, delay: 1500, loopGap: 3200 });
    const text = a.you ? line : shown;
    return (
      <div style={{
        position: "absolute", left: x, top: y,
        display: "flex", alignItems: "flex-start", gap: 12,
        animation: `vlm-drift 6s ease-in-out ${delay}s infinite`,
        width: 260,
      }}>
        <div style={{
          width: 56, height: 56, borderRadius: "50%",
          background: `radial-gradient(circle at 35% 30%, #fff, ${a.color} 50%, ${a.deep} 100%)`,
          boxShadow: `0 12px 30px -10px ${a.deep}66, 0 0 0 6px ${a.color}22`,
          display: "flex", alignItems: "center", justifyContent: "center",
          color: a.you ? "#fff" : "#1A170E",
          fontSize: 24, fontWeight: 700, flexShrink: 0,
          fontFamily: "'Instrument Serif', serif",
          position: "relative",
        }}>
          {a.glyph}
        </div>
        <div style={{
          background: "#FFFDF4",
          border: `1px solid ${a.color}80`,
          borderRadius: 12,
          borderTopLeftRadius: 4,
          padding: "10px 14px",
          fontSize: 13, color: INK, lineHeight: 1.45,
          boxShadow: "0 10px 30px -16px rgba(60,40,0,0.3)",
          maxWidth: 200,
        }}>
          <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 4 }}>
            <span style={{
              fontSize: 10, fontFamily: "'JetBrains Mono', monospace",
              color: a.deep, fontWeight: 600,
            }}>{a.name}.add_note</span>
            <span style={{ fontSize: 10, color: INK_MUTE }}>→ {a.folder}</span>
          </div>
          <div>{text}{!a.you && <Caret color={INK} />}</div>
        </div>
      </div>
    );
  }

  function HeroOrbField() {
    return (
      <div style={{
        position: "relative", height: 380, width: 1100, margin: "0 auto",
      }}>
        {/* Center: Vellem as the bowl they pour into */}
        <div style={{
          position: "absolute", left: "50%", top: "50%",
          transform: "translate(-50%, -50%)",
          width: 200, height: 200,
          display: "flex", alignItems: "center", justifyContent: "center",
        }}>
          <div style={{
            position: "absolute", inset: 0,
            animation: "vlm-spin-slow 60s linear infinite",
          }}>
            <PetalRing size={200} opacity={0.35} />
          </div>
          <div style={{
            position: "relative", textAlign: "center",
          }}>
            <VellemIcon size={88} halo />
            <div style={{
              fontSize: 11, fontFamily: "'JetBrains Mono', monospace",
              color: INK_MUTE, marginTop: 10, letterSpacing: "0.06em",
            }}>~/vellem · local-first</div>
          </div>
        </div>

        {/* Connecting strings */}
        <svg style={{ position: "absolute", inset: 0, width: "100%", height: "100%", pointerEvents: "none" }}
             viewBox="0 0 1100 380">
          <defs>
            <linearGradient id="line-claude" x1="0" x2="1">
              <stop offset="0" stopColor="#E8C547" stopOpacity="0.6" />
              <stop offset="1" stopColor="#E8C547" stopOpacity="0" />
            </linearGradient>
            <linearGradient id="line-codex" x1="0" x2="1">
              <stop offset="0" stopColor="#2E7D5B" stopOpacity="0.6" />
              <stop offset="1" stopColor="#2E7D5B" stopOpacity="0" />
            </linearGradient>
            <linearGradient id="line-cursor" x1="0" x2="1">
              <stop offset="0" stopColor="#9A3A6E" stopOpacity="0.6" />
              <stop offset="1" stopColor="#9A3A6E" stopOpacity="0" />
            </linearGradient>
            <linearGradient id="line-you" x1="0" x2="1">
              <stop offset="0" stopColor="#1A170E" stopOpacity="0.4" />
              <stop offset="1" stopColor="#1A170E" stopOpacity="0" />
            </linearGradient>
          </defs>
          <path d="M 200 80 Q 380 140, 510 180" stroke="url(#line-claude)" strokeWidth="2" fill="none" strokeDasharray="2 6" />
          <path d="M 900 80 Q 720 140, 590 180" stroke="url(#line-codex)" strokeWidth="2" fill="none" strokeDasharray="2 6" />
          <path d="M 200 290 Q 380 230, 510 200" stroke="url(#line-cursor)" strokeWidth="2" fill="none" strokeDasharray="2 6" />
          <path d="M 900 290 Q 720 230, 590 200" stroke="url(#line-you)" strokeWidth="2" fill="none" strokeDasharray="2 6" />
        </svg>

        {/* Orbs */}
        <AgentOrb a={AGENTS[0]} x={0}   y={20}  delay={0}    line="Hugo champion ✓. Sync vendredi." />
        <AgentOrb a={AGENTS[1]} x={780} y={20}  delay={0.6}  line="Refactor MCPServer.swift L240" />
        <AgentOrb a={AGENTS[2]} x={0}   y={260} delay={1.2}  line="Renamed Supanote → Vellem (43 files)" />
        <AgentOrb a={AGENTS[3]} x={780} y={260} delay={1.8}  line="Don't forget: appcast.xml v1.0.8" />
      </div>
    );
  }

  // ---------------- Hero ---------------------------------------------------
  function Hero() {
    return (
      <section style={{
        background: `radial-gradient(ellipse at 50% -10%, ${CREAM_DEEP} 0%, ${CREAM} 50%, #FFFDF4 100%)`,
        padding: "44px 64px 80px", position: "relative", overflow: "hidden",
      }}>
        {/* Decorative petals in corners */}
        <div style={{ position: "absolute", left: -40, top: -40, animation: "vlm-spin-slow 80s linear infinite" }}>
          <PetalRing size={220} opacity={0.12} />
        </div>
        <div style={{ position: "absolute", right: -50, top: 60, animation: "vlm-spin-slow 120s linear infinite reverse" }}>
          <PetalRing size={160} opacity={0.10} color="#9A3A6E" />
        </div>
        <div style={{ position: "absolute", right: 200, bottom: -30, animation: "vlm-spin-slow 90s linear infinite" }}>
          <PetalRing size={140} opacity={0.08} color="#2E7D5B" />
        </div>

        {/* Top bar */}
        <div style={{
          display: "flex", alignItems: "center", justifyContent: "space-between",
          marginBottom: 64, position: "relative",
        }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <VellemIcon size={32} />
            <span style={{ fontSize: 18, fontWeight: 700, color: INK }}>Vellem</span>
          </div>
          <nav style={{ display: "flex", gap: 26, fontSize: 13, color: INK_SOFT }}>
            <span>Meet the agents</span><span>14 tools</span><span>Native bits</span><span>Setup</span>
          </nav>
          <Pill>v1.0.8 · for macOS</Pill>
        </div>

        {/* Headline */}
        <div style={{ textAlign: "center", maxWidth: 900, margin: "0 auto 56px", position: "relative" }}>
          <h1 style={{
            margin: 0,
            fontFamily: "'Instrument Serif', 'Times New Roman', serif",
            fontWeight: 400, color: INK,
            fontSize: 132, lineHeight: 0.95, letterSpacing: "-0.04em",
          }}>
            Every agent gets <em style={{ color: "#9A7B12" }}>a desk</em>,<br />
            a <span style={{
              background: "linear-gradient(180deg, transparent 65%, #F6E5A2 65%)",
              padding: "0 8px",
            }}>folder</span>, and a pen.
          </h1>
          <p style={{
            margin: "30px auto 0", maxWidth: 580,
            fontSize: 18, lineHeight: 1.55, color: INK_SOFT,
          }}>
            Vellem is a tiny, native macOS notebook your AI agents share with you.
            Claude, Codex, Cursor, you — same folder system, same Markdown,
            <em> none of the amnesia</em>.
          </p>
        </div>

        {/* Orbs */}
        <HeroOrbField />

        <div style={{ marginTop: 56, position: "relative" }}>
          <DownloadCTA tone="light" />
        </div>
      </section>
    );
  }

  // ---------------- Problem ------------------------------------------------
  function Problem() {
    return (
      <section style={{
        background: "#FFFDF4", padding: "100px 80px", position: "relative", overflow: "hidden",
      }}>
        <div style={{ maxWidth: 1080, margin: "0 auto", display: "grid", gridTemplateColumns: "1fr 1.2fr", gap: 60, alignItems: "center" }}>
          <div>
            <div style={{
              fontSize: 11, fontWeight: 700, letterSpacing: "0.22em",
              color: "#9A7B12", textTransform: "uppercase", marginBottom: 18,
            }}>The problem</div>
            <h2 style={{
              margin: 0,
              fontFamily: "'Instrument Serif', serif",
              fontSize: 80, lineHeight: 0.95, letterSpacing: "-0.035em",
              color: INK, fontWeight: 400,
            }}>
              Right now your<br />
              agents are <em style={{ color: "#9A7B12" }}>fish</em>.
            </h2>
            <p style={{
              marginTop: 24, fontSize: 17, lineHeight: 1.6, color: INK_SOFT, maxWidth: 460,
            }}>
              Three-second memories. Brilliant for the duration of one chat, blank by Tuesday.
              You repeat yourself, re-explain context, re-derive decisions you already made.
            </p>
            <p style={{ marginTop: 18, fontSize: 17, lineHeight: 1.6, color: INK_SOFT, maxWidth: 460 }}>
              Vellem hands them a notebook. <strong style={{ color: INK }}>One they can re-open tomorrow.</strong>
            </p>
          </div>

          {/* Visual: agents going round in circles vs. landing on the page */}
          <div style={{
            position: "relative",
            background: CREAM,
            border: "1px solid #F1DF8E",
            borderRadius: 22,
            padding: "32px 32px",
            minHeight: 380,
          }}>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 20 }}>
              {/* Without Vellem */}
              <div style={{
                background: "#FFFDF4", borderRadius: 14, padding: "16px 18px",
                border: "1px dashed #D8C57E", textAlign: "center",
              }}>
                <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: "0.16em", color: "#A89248", textTransform: "uppercase", marginBottom: 14 }}>Without</div>
                <div style={{
                  width: 120, height: 120, margin: "0 auto",
                  borderRadius: "50%",
                  border: "2px dashed #D8C57E",
                  display: "flex", alignItems: "center", justifyContent: "center",
                  position: "relative",
                }}>
                  <div style={{
                    position: "absolute", inset: -8,
                    animation: "vlm-spin-slow 8s linear infinite",
                  }}>
                    <div style={{
                      position: "absolute", top: -10, left: "50%", transform: "translateX(-50%)",
                      width: 24, height: 24, borderRadius: "50%",
                      background: "radial-gradient(circle at 35% 30%, #fff, #E8C547 60%, #9A7B12)",
                      boxShadow: "0 4px 10px -4px #9A7B1280"
                    }} />
                  </div>
                  <span style={{
                    fontSize: 11, color: INK_MUTE,
                    fontFamily: "'JetBrains Mono', monospace", textAlign: "center"
                  }}>amnesia<br />loop</span>
                </div>
                <div style={{ marginTop: 14, fontSize: 12, color: INK_MUTE }}>
                  Re-explains everything every session.
                </div>
              </div>

              {/* With Vellem */}
              <div style={{
                background: "#FFFDF4", borderRadius: 14, padding: "16px 18px",
                border: `2px solid ${ACCENT}`, textAlign: "center",
                boxShadow: `0 20px 40px -24px ${ACCENT}80`,
              }}>
                <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: "0.16em", color: "#9A7B12", textTransform: "uppercase", marginBottom: 14 }}>With Vellem</div>
                <div style={{
                  width: 120, height: 120, margin: "0 auto",
                  display: "flex", alignItems: "center", justifyContent: "center",
                  position: "relative",
                }}>
                  <VellemIcon size={80} halo />
                  <div style={{ position: "absolute", inset: 0, animation: "vlm-spin-slow 40s linear infinite" }}>
                    <PetalRing size={120} opacity={0.4} />
                  </div>
                </div>
                <div style={{ marginTop: 14, fontSize: 12, color: INK_SOFT }}>
                  Notes persist. Searchable. Yours.
                </div>
              </div>
            </div>

            {/* Quotes */}
            <div style={{ marginTop: 22, textAlign: "center", fontSize: 13, color: INK_SOFT, fontStyle: "italic" }}>
              "Where were we?" — said no Vellem user, ever.
            </div>
          </div>
        </div>
      </section>
    );
  }

  // ---------------- Tools grid as collectible cards ------------------------
  function ToolsGrid() {
    const verbBg = {
      create:  { bg: "#E9F6EE", border: "#A6E0C9", text: "#2E7D5B" },
      read:    { bg: "#EAF2FF", border: "#B6CFFF", text: "#3B6FC4" },
      write:   { bg: "#FBF1C7", border: "#F1DF8E", text: "#9A7B12" },
      append:  { bg: "#FAEBD7", border: "#E6C99A", text: "#B07020" },
      destroy: { bg: "#FBE3DC", border: "#F0B8A5", text: "#B03A3A" },
    };
    return (
      <section style={{
        background: `linear-gradient(180deg, #FFFDF4 0%, ${CREAM} 100%)`,
        padding: "120px 60px", position: "relative", overflow: "hidden",
      }}>
        <div style={{ position: "absolute", left: -40, top: 80, animation: "vlm-spin-slow 100s linear infinite" }}>
          <PetalRing size={180} opacity={0.1} color="#9A3A6E" />
        </div>
        <div style={{ position: "absolute", right: -40, bottom: 80, animation: "vlm-spin-slow 120s linear infinite reverse" }}>
          <PetalRing size={200} opacity={0.1} color="#2E7D5B" />
        </div>

        <div style={{ maxWidth: 1160, margin: "0 auto", position: "relative" }}>
          <div style={{ textAlign: "center", marginBottom: 56 }}>
            <div style={{
              fontSize: 11, fontWeight: 700, letterSpacing: "0.22em",
              color: "#9A7B12", textTransform: "uppercase", marginBottom: 18,
            }}>14 tools, no plumbing</div>
            <h2 style={{
              margin: 0,
              fontFamily: "'Instrument Serif', serif",
              fontSize: 76, lineHeight: 0.95, letterSpacing: "-0.035em",
              color: INK, fontWeight: 400,
            }}>
              Your agents' <em style={{ color: "#9A7B12" }}>spellbook</em>.
            </h2>
            <p style={{
              margin: "20px auto 0", maxWidth: 580,
              fontSize: 16, color: INK_SOFT, lineHeight: 1.6,
            }}>
              Every verb your AI needs to keep a real notebook. Bundled with the app.
              The MCP server boots when Vellem boots.
            </p>
          </div>

          <div style={{
            display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 14,
          }}>
            {MCP_TOOLS.map((t, i) => {
              const c = verbBg[t.verb];
              return (
                <div key={t.name} style={{
                  background: c.bg,
                  border: `1.5px solid ${c.border}`,
                  borderRadius: 16,
                  padding: "16px 16px 14px",
                  position: "relative",
                  transform: `rotate(${(i % 3 - 1) * 0.6}deg)`,
                  boxShadow: "0 6px 18px -10px rgba(60,40,0,0.25)",
                }}>
                  <div style={{
                    display: "flex", justifyContent: "space-between", alignItems: "center",
                    marginBottom: 10,
                  }}>
                    <span style={{
                      fontSize: 10, fontWeight: 700, letterSpacing: "0.16em",
                      textTransform: "uppercase", color: c.text,
                    }}>{t.verb}</span>
                    <span style={{
                      fontSize: 10, fontFamily: "'JetBrains Mono', monospace",
                      color: c.text, opacity: 0.6,
                    }}>{String(i + 1).padStart(2, "0")}</span>
                  </div>
                  <div style={{
                    fontFamily: "'JetBrains Mono', monospace",
                    fontSize: 14, fontWeight: 600, color: INK,
                    marginBottom: 6, letterSpacing: "-0.01em",
                  }}>
                    {t.name}<span style={{ color: c.text, opacity: 0.7 }}>()</span>
                  </div>
                  <div style={{ fontSize: 12, color: INK_SOFT, lineHeight: 1.45 }}>{t.desc}</div>
                </div>
              );
            })}
          </div>
        </div>
      </section>
    );
  }

  // ---------------- Native strip — desk with scattered papers --------------
  function NativeStrip() {
    return (
      <section style={{
        background: CREAM,
        padding: "120px 60px",
        position: "relative", overflow: "hidden",
      }}>
        <div style={{ maxWidth: 1160, margin: "0 auto", position: "relative" }}>
          <div style={{ textAlign: "center", marginBottom: 72 }}>
            <div style={{
              fontSize: 11, fontWeight: 700, letterSpacing: "0.22em",
              color: "#9A7B12", textTransform: "uppercase", marginBottom: 18,
            }}>On your desk, not in the cloud</div>
            <h2 style={{
              margin: 0,
              fontFamily: "'Instrument Serif', serif",
              fontSize: 76, lineHeight: 0.95, letterSpacing: "-0.035em",
              color: INK, fontWeight: 400, maxWidth: 880, marginInline: "auto",
            }}>
              A pile of <em style={{ color: "#9A7B12" }}>tiny native things</em>.
            </h2>
          </div>

          {/* Desk scene */}
          <div style={{
            position: "relative", height: 460,
            background: "linear-gradient(180deg, #FFFDF4, #F8EFC8)",
            border: "1px solid #F1DF8E",
            borderRadius: 22,
            padding: 24,
            boxShadow: "0 40px 80px -50px rgba(60,40,0,0.4) inset",
          }}>
            {/* Quick capture sticky */}
            <div style={{
              position: "absolute", left: 60, top: 56, width: 240,
              background: "linear-gradient(180deg, #FBEFC0, #F6E5A2)",
              borderRadius: 12, padding: "14px 16px",
              transform: "rotate(-5deg)",
              boxShadow: "0 30px 50px -24px rgba(120,90,10,0.5)",
              animation: "vlm-drift 6s ease-in-out infinite",
            }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
                <TrafficLights size={9} />
                <span style={{ fontSize: 10, color: "#7A6520", fontWeight: 600 }}>Quick capture</span>
              </div>
              <div style={{ fontSize: 13, fontWeight: 600, color: INK, marginBottom: 4 }}>weekly digest idea</div>
              <div style={{ fontSize: 12, color: INK_SOFT, lineHeight: 1.5 }}>
                ask Claude to summarize the Codex folder every Friday<Caret color={INK} />
              </div>
              <div style={{
                marginTop: 12, fontSize: 10, color: "#7A6520",
                display: "flex", justifyContent: "space-between"
              }}>
                <span>⌥⌘N</span><span>↩ save</span>
              </div>
            </div>

            {/* Today widget center */}
            <div style={{
              position: "absolute", left: "50%", top: 50, transform: "translateX(-50%) rotate(1.2deg)",
              width: 320,
              background: "#FFFDF4",
              border: "1px solid #F1DF8E",
              borderRadius: 18,
              padding: "20px 22px",
              boxShadow: "0 30px 60px -24px rgba(60,40,0,0.35)",
            }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 14 }}>
                <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                  <VellemIcon size={22} />
                  <span style={{ fontSize: 14, fontWeight: 700, color: INK }}>Today</span>
                </div>
                <span style={{ fontSize: 11, color: INK_MUTE }}>3 notes</span>
              </div>
              {[
                { t: "15:00", title: "Rapport · Adrien <> James", dot: "#F6E5A2" },
                { t: "10:50", title: "Standup. 27 mai 2026", dot: "#A6E0C9" },
                { t: "09:05", title: "Storybook integration", dot: "#8FB7FF", active: true },
              ].map((n, i) => (
                <div key={i} style={{
                  display: "flex", gap: 12, alignItems: "center",
                  padding: "8px 10px", marginBottom: 2, borderRadius: 8,
                  background: n.active ? "#FBEFC0" : "transparent",
                }}>
                  <span style={{ fontSize: 11, color: INK_MUTE, fontFamily: "'JetBrains Mono', monospace", width: 36 }}>{n.t}</span>
                  <span style={{ width: 6, height: 6, borderRadius: 2, background: n.dot }} />
                  <span style={{ fontSize: 13, color: INK, fontWeight: 500, flex: 1 }}>{n.title}</span>
                </div>
              ))}
            </div>

            {/* Widget */}
            <div style={{
              position: "absolute", right: 60, top: 70, width: 230,
              background: "linear-gradient(165deg, #FBEFC0, #F6E5A2)",
              borderRadius: 22, padding: "18px 20px",
              transform: "rotate(4deg)",
              boxShadow: "0 30px 60px -24px rgba(120,90,10,0.5)",
              animation: "vlm-drift 5s ease-in-out -1s infinite",
            }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 10 }}>
                <span style={{ fontSize: 10, color: "#7A6520", fontWeight: 700, letterSpacing: "0.14em", textTransform: "uppercase" }}>Widget · md</span>
                <VellemIcon size={18} />
              </div>
              <div style={{ fontSize: 14, fontWeight: 700, color: INK, marginBottom: 6 }}>Latest from Claude</div>
              <div style={{ fontSize: 12, color: INK_SOFT, lineHeight: 1.5 }}>
                Migration · Supanote → Vellem. All app group entries replaced. Tous les Supanote…
              </div>
              <div style={{ marginTop: 12, fontSize: 10, color: "#7A6520", fontFamily: "'JetBrains Mono', monospace" }}>
                WidgetKit · all sizes
              </div>
            </div>

            {/* Menu bar capture popover */}
            <div style={{
              position: "absolute", left: 130, bottom: 40, width: 280,
              background: "#FFFDF4",
              border: "1px solid #F1DF8E",
              borderRadius: 14,
              padding: "12px 14px",
              transform: "rotate(-2deg)",
              boxShadow: "0 30px 50px -24px rgba(60,40,0,0.4)",
            }}>
              <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 8 }}>
                <VellemIcon size={18} />
                <span style={{ fontSize: 12, fontWeight: 700, color: INK }}>Menu bar</span>
                <span style={{ marginLeft: "auto", fontSize: 10, color: INK_MUTE, fontFamily: "'JetBrains Mono', monospace" }}>⌃⌘V</span>
              </div>
              <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
                {["New note", "Today", "Search", "Claude folder", "Codex folder"].map((c, i) => (
                  <span key={i} style={{
                    fontSize: 11, padding: "4px 9px", borderRadius: 999,
                    background: i === 0 ? "#F1DF8E" : "#FAF3D9",
                    color: i === 0 ? "#7A6520" : INK_SOFT,
                    fontWeight: 500,
                  }}>{c}</span>
                ))}
              </div>
            </div>

            {/* Apple FM badge */}
            <div style={{
              position: "absolute", right: 80, bottom: 50, width: 230,
              background: "#FFFDF4", borderRadius: 14,
              border: "1px solid #F1DF8E", padding: "14px 16px",
              transform: "rotate(3deg)",
              boxShadow: "0 30px 50px -24px rgba(60,40,0,0.35)",
            }}>
              <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 6 }}>
                <span style={{ fontSize: 18 }}>🍎</span>
                <span style={{ fontSize: 12, fontWeight: 700, color: INK }}>Foundation Models</span>
              </div>
              <div style={{ fontSize: 11, color: INK_SOFT, lineHeight: 1.45 }}>
                On macOS 26+ capable Macs, on-device editing actions — rewrite, summarize, list-ify.
              </div>
            </div>
          </div>

          <div style={{ marginTop: 50, textAlign: "center", fontSize: 13, color: INK_SOFT }}>
            All native. Menu bar · global hotkey · widgets all sizes · interactive todos · zero telemetry.
          </div>
        </div>
      </section>
    );
  }

  // ---------------- Setup --------------------------------------------------
  function Setup() {
    return (
      <section style={{
        background: "#FFFDF4", padding: "100px 80px", position: "relative",
      }}>
        <div style={{ maxWidth: 920, margin: "0 auto" }}>
          <div style={{ textAlign: "center", marginBottom: 40 }}>
            <div style={{
              fontSize: 11, fontWeight: 700, letterSpacing: "0.22em",
              color: "#9A7B12", textTransform: "uppercase", marginBottom: 18,
            }}>Setup · 30 seconds</div>
            <h2 style={{
              margin: 0,
              fontFamily: "'Instrument Serif', serif",
              fontSize: 64, lineHeight: 1, letterSpacing: "-0.03em",
              color: INK, fontWeight: 400,
            }}>
              Hand Claude its <em style={{ color: "#9A7B12" }}>library card</em>.
            </h2>
          </div>
          <div style={{
            background: "#1A170E", color: "#F0E8C8",
            border: "1px solid rgba(232,197,71,0.18)",
            borderRadius: 14, padding: "20px 24px",
            fontFamily: "'JetBrains Mono', monospace",
            fontSize: 14, lineHeight: 1.6, position: "relative",
          }}>
            <div style={{
              position: "absolute", top: 12, right: 14,
              fontSize: 10, fontWeight: 600, letterSpacing: "0.18em",
              color: "#7d6a2a", textTransform: "uppercase",
            }}>~/Library/Application Support/Claude/</div>
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
            textAlign: "center", marginTop: 32, fontSize: 16, color: INK_SOFT,
            maxWidth: 540, marginInline: "auto", lineHeight: 1.6,
          }}>
            Restart Claude. Say <em style={{ color: "#9A7B12" }}>"save that to Vellem"</em>.
            Watch the note arrive in the <strong>Claude</strong> folder — automatic, foldered, forever.
          </p>
        </div>
      </section>
    );
  }

  // ---------------- Footer -------------------------------------------------
  function Footer() {
    return (
      <section style={{
        background: CREAM, padding: "60px 80px",
        borderTop: "1px solid #F1DF8E", position: "relative", overflow: "hidden",
      }}>
        <div style={{ position: "absolute", right: 80, top: -60, animation: "vlm-spin-slow 80s linear infinite" }}>
          <PetalRing size={180} opacity={0.15} />
        </div>
        <div style={{
          maxWidth: 1120, margin: "0 auto", position: "relative",
          display: "flex", alignItems: "end", justifyContent: "space-between",
        }}>
          <div style={{ maxWidth: 480 }}>
            <h3 style={{
              margin: 0,
              fontFamily: "'Instrument Serif', serif",
              fontSize: 48, lineHeight: 1, color: INK, fontWeight: 400,
            }}>
              Beautiful. Native. <em style={{ color: "#9A7B12" }}>Yours.</em>
            </h3>
            <p style={{ marginTop: 14, fontSize: 14, color: INK_SOFT, lineHeight: 1.6 }}>
              Everything lives in your Apple App Group container — no cloud, no sync server, no telemetry.
            </p>
          </div>
          <div style={{ textAlign: "right", fontSize: 13, color: INK_SOFT }}>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "end", gap: 10, marginBottom: 12 }}>
              <VellemIcon size={28} />
              <span style={{ fontSize: 15, fontWeight: 700, color: INK }}>Vellem</span>
            </div>
            <div>MIT · made in France · v1.0.8</div>
            <div style={{ marginTop: 4, color: INK_MUTE }}>github · all releases · privacy</div>
          </div>
        </div>
      </section>
    );
  }

  function DirectionC() {
    return (
      <div style={{
        width: 1280, color: INK,
        fontFamily: "'Inter Tight', system-ui, sans-serif",
        background: "#FFFDF4",
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

  window.DirectionC = DirectionC;
})();
