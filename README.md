# Vellem

Vellem is a native macOS inbox for agent outputs. Ask an agent to send a project brief, report, code snippet or any other text. Select its icon to read messages and select it again to open its folders.

The macOS app and MCP server share a local App Group library. Vellem also attempts to publish a copy to iCloud Drive for the iPhone app when the container is available. Availability and sync depend on the device and iCloud configuration.

## Connect an agent

Open **Settings → Agents** and choose Codex, Claude Code, Gemini CLI or Grok Build. **Copy and open Terminal** copies the registration command for the bundled stdio server. Paste it into Terminal and press Return. Start a new client session and ask it to send the result to Vellem. Claude Desktop has a JSON configuration to copy.

The MCP tool `send_output` requires only `text`. Optional fields are `title`, `format` (`markdown`, `text`, `json` or `code`), `source_agent`, and `folder_id` or `folder_name`. The app stores the original text verbatim. Delivered messages are read-only. Send a new message to deliver a revision. Existing clients can still call `add_note`. Known clients are attributed automatically. Bridges can pass the actual sender name.

For a bot with local shell access, deliver a UTF-8 file directly:

```sh
/Applications/Vellem.app/Contents/Resources/vellem-mcp send --agent Grokbot --format markdown --title "Project brief" < brief.md
```

The Mac reader displays Markdown tables, nested lists, checklists, quotations, footnotes, LaTeX formulas and static HTML such as figures with captions. Fenced code blocks can specify a language for highlighting. Wide tables scroll horizontally. JSON is indented for reading, and copying a message returns the original text.

## Build and test

The app targets macOS 26 or later. Install Xcode and `xcodegen`, then run:

```sh
./script/build_and_run.sh
```

The script builds and installs the app in both `~/Applications` and `/Applications`. It no longer merges old note files on every launch. The app imports legacy notes when there is no current library.

Run the storage merge checks with:

```sh
./script/test-library-merge.sh
./script/test-library-files.sh
./script/test-archive.sh
```

To exercise the MCP server against a temporary library, pass a Debug build of the server:

```sh
python3 Tests/test_mcp.py /path/to/Debug/vellem-mcp
./script/test-concurrent-store.sh /path/to/Debug/vellem-mcp
python3 Tests/test_codex_discovery.py /path/to/Debug/vellem-mcp
python3 Tests/test_claude_connection.py /path/to/Debug/vellem-mcp
swift Tests/MessageReaderTests.swift /path/to/Debug/Vellem.app
```

## Release

See [RELEASE.md](RELEASE.md) for the signed and notarized DMG pipeline.

## License

MIT.
