# Vellem

A quiet, native macOS notes app with built-in MCP support. Capture fast from the menu bar, organize lightly with folders, and let any MCP client (Claude, Codex, …) read and write your notes.

**Download:** <https://pulssart.github.io/vellem/>

## What's in the box

- Native macOS app (SwiftUI, macOS 26+)
- Menu bar quick capture + global hotkey + Services menu integration
- WidgetKit widgets (small / medium / large / extra-large)
- Bundled MCP server (`vellem-mcp`) exposing `add_note`, `list_notes`, `search_notes`, folder management, todo lists, daily notes…
- Apple Foundation Models editing actions on capable Macs

## Run from source

```sh
./script/build_and_run.sh
```

Requires Xcode 16+ and [xcodegen](https://github.com/yonki/XcodeGen) (`brew install xcodegen`).

## Connect to Claude / Codex

The MCP binary ships at `Vellem.app/Contents/Resources/vellem-mcp`. Wire it into Claude Desktop's `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "vellem": {
      "command": "/Applications/Vellem.app/Contents/Resources/vellem-mcp"
    }
  }
}
```

Restart Claude. Notes you ask Claude to capture will land in the Vellem app's `Claude` smart folder.

## Releasing

See [RELEASE.md](RELEASE.md) for the signed + notarized DMG pipeline.

## License

MIT.
