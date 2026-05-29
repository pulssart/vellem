import {
  AbsoluteFill,
  Easing,
  interpolate,
  Sequence,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
  Img,
} from "remotion";

const notes = [
  {
    source: "From Codex",
    title: "Release plan",
    body: "The agent writes the next steps directly into your notebook.",
    time: "09:18",
  },
  {
    source: "From Claude",
    title: "Customer research",
    body: "Interview notes, synthesis, and open questions stay readable.",
    time: "10:42",
  },
  {
    source: "Quick Note",
    title: "A thought before it escapes",
    body: "Capture your own ideas without opening a heavy workspace.",
    time: "12:07",
  },
];

const scenes = [
  { start: 0, end: 150, eyebrow: "Vellem", title: "A notebook agents can actually use.", body: "Claude, Codex, and you can write in the same local place." },
  { start: 150, end: 330, eyebrow: "The problem", title: "Good work disappears in chat history.", body: "Plans, summaries, and decisions often live where you cannot browse them later." },
  { start: 330, end: 540, eyebrow: "How it works", title: "Agents save notes through MCP.", body: "Connect Vellem once, then let your AI clients create, update, and search notes while they work." },
  { start: 540, end: 750, eyebrow: "Daily flow", title: "Today shows what just happened.", body: "The app keeps recent work, your quick notes, and agent output in one clean timeline." },
  { start: 750, end: 960, eyebrow: "Memory", title: "Find the thread again.", body: "Semantic search and related notes help you recover the context behind a decision." },
  { start: 960, end: 1140, eyebrow: "Privacy", title: "Local on your Mac.", body: "Notes are stored in the app group container. Vellem is built for private agent memory." },
  { start: 1140, end: 1320, eyebrow: "Vellem", title: "Keep the useful parts.", body: "Turn agent work into notes you can return to." },
];

const ease = (frame: number, start: number, duration: number, from: number, to: number) =>
  interpolate(frame, [start, start + duration], [from, to], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

const fade = (frame: number, start: number, duration = 24) =>
  interpolate(frame, [start, start + duration], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

const sceneProgress = (frame: number, start: number, end: number) =>
  interpolate(frame, [start, end], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

const currentScene = (frame: number) =>
  scenes.find((scene) => frame >= scene.start && frame < scene.end) ?? scenes[scenes.length - 1];

const AppIcon = () => (
  <div className="appIcon">
    <Img src={staticFile("app-icon.png")} className="appIconImage" />
  </div>
);

const Sidebar = () => (
  <div className="sidebar">
    <div className="traffic">
      <span />
      <span />
      <span />
    </div>
    <div className="search">Search notes</div>
    {["Today", "Claude", "Codex", "Prompt Library", "Services"].map((item, index) => (
      <div className={index === 0 ? "sideItem active" : "sideItem"} key={item}>
        <span className="sideGlyph" />
        <span>{item}</span>
        {index < 3 ? <b>{index === 0 ? "13" : index === 1 ? "11" : "16"}</b> : null}
      </div>
    ))}
    <div className="sideLabel">Folders</div>
    {["Build reports", "Dotfile", "User interviews", "Evening watch"].map((item) => (
      <div className="sideItem subtle" key={item}>
        <span className="folderGlyph" />
        <span>{item}</span>
      </div>
    ))}
  </div>
);

const NoteCard = ({ note, index, active }: { note: (typeof notes)[number]; index: number; active: boolean }) => (
  <div className={active ? "timelineRow active" : "timelineRow"}>
    <div className="time">{note.time}</div>
    <div className="dot" />
    <div className="noteCard">
      <div className="sourcePill">{note.source}</div>
      <h4>{note.title}</h4>
      <p>{note.body}</p>
      <small>{index + 2} min ago</small>
    </div>
  </div>
);

const AppWindow = ({ frame }: { frame: number }) => {
  const activeNote = frame < 540 ? 0 : frame < 750 ? 2 : frame < 960 ? 1 : 0;
  const searchValue = frame >= 750 && frame < 960 ? "customer decision from last week" : "";
  return (
    <div className="appWindow">
      <Sidebar />
      <div className="middlePane">
        <div className="paneHeader">
          <div>
            <b>Today</b>
            <span>13 notes</span>
          </div>
          <div className="headerButton">New note</div>
        </div>
        {searchValue ? <div className="bigSearch">{searchValue}</div> : null}
        <div className="timeline">
          {notes.map((note, index) => (
            <NoteCard key={note.title} note={note} index={index} active={index === activeNote} />
          ))}
        </div>
      </div>
      <div className="detailPane">
        <div className="detailMeta">
          <span>{notes[activeNote].source}</span>
          <span>128 words</span>
        </div>
        <h2>{notes[activeNote].title}</h2>
        <p>{notes[activeNote].body}</p>
        <p>
          Vellem keeps the useful part of the session as a readable note, with the source attached and the context ready for later.
        </p>
      </div>
    </div>
  );
};

const ChatStack = ({ frame }: { frame: number }) => {
  const inFrame = fade(frame, 160, 30);
  const y = ease(frame, 160, 48, 28, 0);
  return (
    <div className="chatStack" style={{ opacity: inFrame, transform: `translateY(${y}px)` }}>
      <div className="chatCard one">Can you turn this into a launch plan?</div>
      <div className="chatCard two">Done. I also found three follow ups.</div>
      <div className="chatCard three">Where did we decide the release scope?</div>
    </div>
  );
};

const McpFlow = ({ frame }: { frame: number }) => {
  const show = fade(frame, 330, 28);
  const line = ease(frame, 390, 70, 0, 1);
  return (
    <div className="mcpFlow" style={{ opacity: show }}>
      <div className="clientCard">Codex</div>
      <div className="flowLine">
        <span style={{ transform: `scaleX(${line})` }} />
      </div>
      <div className="serverCard">MCP</div>
      <div className="flowLine">
        <span style={{ transform: `scaleX(${Math.max(0, line - 0.25) / 0.75})` }} />
      </div>
      <div className="clientCard vellemMini">Vellem</div>
    </div>
  );
};

const LocalPanel = ({ frame }: { frame: number }) => {
  const show = fade(frame, 960, 28);
  return (
    <div className="localPanel" style={{ opacity: show }}>
      <div className="lockRing">Local</div>
      <div>
        <h3>Stored on your Mac</h3>
        <p>Designed for private notes, agent output, and project memory you can keep close.</p>
      </div>
    </div>
  );
};

const MainCopy = ({ frame }: { frame: number }) => {
  const scene = currentScene(frame);
  const progress = sceneProgress(frame, scene.start, scene.end);
  const localFrame = frame - scene.start;
  const enter = fade(localFrame, 0, 24);
  const exit = interpolate(progress, [0.82, 1], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <div className="copy" style={{ opacity: enter * exit }}>
      <div className="eyebrow">{scene.eyebrow}</div>
      <h1>{scene.title}</h1>
      <p>{scene.body}</p>
    </div>
  );
};

const ProgressRail = ({ frame }: { frame: number }) => {
  const { durationInFrames } = useVideoConfig();
  const width = interpolate(frame, [0, durationInFrames], [0, 100], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <div className="progressRail">
      <span style={{ width: `${width}%` }} />
    </div>
  );
};

export const VellemPromo = () => {
  const frame = useCurrentFrame();
  const windowScale = interpolate(frame, [0, 90, 1140, 1260], [0.72, 0.74, 0.74, 0.66], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const windowX = interpolate(frame, [0, 150, 330, 1140], [535, 520, 500, 490], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const windowY = interpolate(frame, [0, 150, 330, 1140], [118, 122, 128, 132], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  return (
    <AbsoluteFill className="video">
      <div className="backgroundWash" />
      <div className="grain" />
      <div className="brand">
        <AppIcon />
        <span>Vellem</span>
      </div>
      <MainCopy frame={frame} />
      <div
        className="windowWrap"
        style={{
          transform: `translate(${windowX}px, ${windowY}px) scale(${windowScale})`,
        }}
      >
        <AppWindow frame={frame} />
      </div>
      <Sequence from={150} durationInFrames={180}>
        <ChatStack frame={frame} />
      </Sequence>
      <Sequence from={330} durationInFrames={210}>
        <McpFlow frame={frame} />
      </Sequence>
      <Sequence from={960} durationInFrames={180}>
        <LocalPanel frame={frame} />
      </Sequence>
      <div className="closing" style={{ opacity: fade(frame, 1180, 42) }}>
        <AppIcon />
        <h2>Vellem</h2>
        <p>Capture. Browse. Search. Keep the useful parts.</p>
      </div>
      <ProgressRail frame={frame} />
    </AbsoluteFill>
  );
};
