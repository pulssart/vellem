#!/usr/bin/env python3
"""Exercise a Debug MCP binary against a temporary, isolated library."""
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import uuid


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 Tests/test_mcp.py /path/to/Debug/vellem-mcp")
    binary = str(Path(sys.argv[1]).resolve())
    strings = subprocess.run(["/usr/bin/strings", binary], capture_output=True, text=True, check=True).stdout
    if "VELLEM_TEST_DIRECTORY" not in strings:
        raise SystemExit("The binary does not support the Debug isolation directory; refusing to run.")

    with tempfile.TemporaryDirectory(prefix="vellem-mcp-test-") as tmp:
        env = dict(os.environ, VELLEM_TEST_DIRECTORY=tmp)

        handshake = [
            {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
                "protocolVersion": "2024-11-05", "capabilities": {},
                "clientInfo": {"name": "Vellem integration test", "version": "1"}}},
            {"jsonrpc": "2.0", "method": "notifications/initialized"},
            {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
            {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "list_notes", "arguments": {}}}
        ]
        connected = subprocess.run([binary], input="".join(json.dumps(item) + "\n" for item in handshake),
                                   text=True, capture_output=True, env=env, timeout=30, check=True)
        replies = [json.loads(line) for line in connected.stdout.splitlines()]
        assert [reply["id"] for reply in replies] == [1, 2, 3]
        assert replies[0]["result"]["serverInfo"]["name"] == "vellem"
        assert replies[1]["result"]["tools"]
        assert not replies[2]["result"].get("isError")

        def request(method, params=None):
            message = {"jsonrpc": "2.0", "id": 1, "method": method}
            if params is not None:
                message["params"] = params
            result = subprocess.run([binary], input=json.dumps(message) + "\n", text=True,
                                    capture_output=True, env=env, timeout=30, check=True)
            return json.loads(result.stdout.splitlines()[0])["result"]

        def call(name, arguments):
            result = request("tools/call", {"name": name, "arguments": arguments})
            assert not result.get("isError"), (name, result)
            return result

        schemas = {tool["name"]: tool["inputSchema"] for tool in request("tools/list")["tools"]}
        assert schemas["add_note"]["required"] == ["text"]
        assert schemas["create_todo_list"]["required"] == ["title", "tasks"]
        assert schemas["send_output"]["required"] == ["text"]
        assert not any("decision" in name or "context" in name for name in schemas)
        assert "decision_title" not in schemas["add_note"]["properties"]
        samples = {
            "markdown": "# Présentation\n\n| A | B |\n|---|---|\n| 1 | 2 |\n",
            "text": "  *literal*\r\n  café ☕\n",
            "json": '  {\n    "message": "你好"\n  }\n',
            "code": "    def answer():\n        return 42\n",
        }
        for fmt, body in samples.items():
            call("send_output", {"text": body, "format": fmt, "source_agent": "Gemini",
                                 "folder_name": "Project", "title": fmt})
            latest = json.loads((Path(tmp) / "notes.json").read_text())[0]
            assert latest["text"] == body and latest["outputFormat"] == fmt and not latest["isRead"]
            assert call("get_note", {"id": latest["id"]})["content"][0]["text"].endswith(body)
        for invalid in [{"text": " \n"}, {"text": 42}, {"text": "data", "format": "unknown"}]:
            assert request("tools/call", {"name": "send_output", "arguments": invalid})["isError"]
        bot = subprocess.run([binary, "send", "--agent", "Grok Bot", "--format", "code", "--folder", "Project"],
                             input=samples["code"], text=True, capture_output=True, env=env, check=True)
        latest = json.loads((Path(tmp) / "notes.json").read_text())[0]
        assert latest["id"] in bot.stdout and latest["sourceApp"] == "Grokbot (CLI)"
        assert latest["text"] == samples["code"] and latest["outputFormat"] == "code"
        folders = json.loads((Path(tmp) / "folders.json").read_text())
        assert {folder["mailbox"] for folder in folders} == {"Gemini", "Grokbot"}
        assert len({folder["id"] for folder in folders}) == 2

        call("add_note", {"text": "# Simple note\n\nA note.", "source_agent": "Grok"})
        assert json.loads((Path(tmp) / "notes.json").read_text())[0]["sourceApp"] == "Grok (MCP)"
        call("create_todo_list", {"title": "Tasks", "tasks": ["First", "Second"]})
        # A write from the new server must round-trip a pre-inbox record losslessly.
        file = Path(tmp) / "notes.json"
        old_notes = json.loads(file.read_text())
        legacy = {"sourceDetail": "Archive", "capturedAt": 1, "decisionTitle": "Earlier choice",
                  "effect": "confirmed", "updatedAt": 2, "validationRule": "Review"}
        # Legacy daily notes are still readable after retiring the daily composer.
        old_notes.append(dict(old_notes[0], id=str(uuid.uuid4()), kind="daily", text="Earlier daily entry"))
        old_notes[0]["decisionContext"] = legacy
        file.write_text(json.dumps(old_notes))
        with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
            list(pool.map(lambda i: call("add_note", {"text": f"# Concurrent note {i}"}), range(32)))

        notes = json.loads((Path(tmp) / "notes.json").read_text())
        assert len(notes) == 40
        assert len({note["id"] for note in notes}) == 40
        assert sum(note.get("kind") == "daily" for note in notes) == 1
        assert sum(note.get("decisionContext") is not None for note in notes) == 1

        note_id = next(note["id"] for note in notes if "Simple note" in note["text"])
        assert next(note["decisionContext"] for note in notes if "decisionContext" in note) == legacy
        call("list_recent_notes", {"days": 7})
        call("search_notes_semantic", {"query": "simple note", "limit": 3})
        call("get_related_notes", {"id": note_id, "limit": 3})
        call("create_folder", {"name": "Research"})
        folder_id = next(f["id"] for f in json.loads((Path(tmp) / "folders.json").read_text()) if f["name"] == "Research")
        call("set_folder_color", {"id": folder_id, "color": "blue"})
        call("move_note", {"id": note_id, "folder_id": folder_id})
        before = file.read_bytes()
        for retired in ("update_note", "add_todo", "append_to_daily"):
            assert retired not in schemas
            rejected = request("tools/call", {"name": retired, "arguments": {"id": note_id, "text": "Rewrite"}})
            assert rejected["isError"] and file.read_bytes() == before
        assert call("get_note", {"id": note_id})["content"][0]["text"].endswith("# Simple note\n\nA note.")
        assert "Simple note" in call("search_notes", {"query": "Simple note"})["content"][0]["text"]
        assert "Earlier daily entry" in call("get_daily_log", {})["content"][0]["text"]
        call("delete_folder", {"id": folder_id})
        notes = json.loads((Path(tmp) / "notes.json").read_text())
        assert next(note for note in notes if note["id"] == note_id).get("folderID") is None
        call("delete_note", {"id": note_id})


        saved_notes = json.loads((Path(tmp) / "notes.json").read_text())
        assert len(saved_notes) == 39
        call("create_folder", {"name": "Keep on error"})
        keep_id = next(f["id"] for f in json.loads((Path(tmp) / "folders.json").read_text()) if f["name"] == "Keep on error")
        # Two simultaneous threads can use one Codex MCP connection. Never route by sender or by the last call.
        first, second = str(uuid.uuid4()), str(uuid.uuid4())
        initialize = {"method": "initialize", "params": {"clientInfo": {"name": "codex-mcp-client"}}}
        cases = [("first", first, None), ("second", second, None), ("unlinked", None, None),
                 ("other sender", first, "Claude")]
        messages = [initialize]
        for title, thread, sender in cases:
            fields = {"text": title}
            if sender:
                fields["source_agent"] = sender
            messages.append({"method": "tools/call", "params": {"name": "send_output", "arguments": fields,
                             "_meta": {"threadId": thread} if thread else {}}})
        wire = "".join(json.dumps(dict(message, jsonrpc="2.0", id=index)) + "\n"
                       for index, message in enumerate(messages, 1))
        isolated = dict(env, CODEX_THREAD_ID=str(uuid.uuid4()))
        subprocess.run([binary], input=wire, text=True, capture_output=True, env=isolated, check=True, timeout=30)
        stored = {n["text"]: n.get("conversation") for n in json.loads(file.read_text())}
        assert stored["first"]["sessionID"].lower() == first and stored["second"]["sessionID"].lower() == second
        assert stored["unlinked"] is None and stored["other sender"] is None

        notes_file = Path(tmp) / "notes.json"
        duplicate_data = json.dumps([saved_notes[0], saved_notes[0]])
        notes_file.write_text(duplicate_data)
        result = request("tools/call", {"name": "add_note", "arguments": {"text": "Must not overwrite"}})
        assert result.get("isError")
        assert notes_file.read_text() == duplicate_data
        notes_file.write_text("invalid test data")
        result = request("tools/call", {"name": "delete_folder", "arguments": {"id": keep_id}})
        assert result.get("isError")
        assert any(f["id"] == keep_id for f in json.loads((Path(tmp) / "folders.json").read_text()))
        assert notes_file.read_text() == "invalid test data"
        print("MCP read-only content, delivery, search, folder routing, lossless delivery in four formats, stdin, legacy records and 32 parallel writes passed")


if __name__ == "__main__":
    main()
