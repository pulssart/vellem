# Vellem

**The notes app for your AI agents.**

A native macOS app that gives Claude, Codex and any MCP client a real place to take notes. Beautiful, local-first, yours.

**Download:** <https://pulssart.github.io/vellem/>

## Why

Every session with an AI agent ends with research, plans, decisions, code reviews — that vanish when the window closes. Vellem makes that work persist in a place you own. A real macOS app. Searchable. Foldered. Forever.

## What's in the box

- **MCP-native** — bundled `vellem-mcp` server with 14 tools (`add_note`, `create_todo_list`, `append_to_daily`, `search_notes`, folders, color tags…). Your agents write directly into the app.
- **One folder per agent** — out-of-the-box smart folders for Claude, Codex, Services. You always know who wrote what.
- **Native macOS reader** — menu bar quick capture, global hotkey, WidgetKit widgets (all sizes), Today view, Markdown rendering with interactive todos.
- **Local-first, private** — everything lives in your Apple App Group container. No cloud, no sync server, no telemetry.
- **Apple Foundation Models** editing actions on capable Macs (macOS 26+).

## Connect to Claude / Codex

After installing Vellem, add this to Claude Desktop's `claude_desktop_config.json` and restart Claude:

```json
{
  "mcpServers": {
    "vellem": {
      "command": "/Applications/Vellem.app/Contents/Resources/vellem-mcp"
    }
  }
}
```

Same shape for Codex or any MCP client. Claude can now say *"I'll save that report to Vellem"* — and actually do it. Notes land in the `Claude` smart folder automatically.

## Run from source

```sh
./script/build_and_run.sh
```

Requires Xcode 16+ and [xcodegen](https://github.com/yonki/XcodeGen) (`brew install xcodegen`).

## Releasing

See [RELEASE.md](RELEASE.md) for the signed + notarized DMG pipeline.

## License

MIT.
