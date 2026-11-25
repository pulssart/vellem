#!/usr/bin/env python3
"""Check that the local Codex app server discovers an isolated Debug MCP server."""
import json
import os
from pathlib import Path
import queue
import subprocess
import sys
import tempfile
import threading


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 Tests/test_codex_discovery.py /path/to/Debug/vellem-mcp")
    binary = str(Path(sys.argv[1]).resolve())
    strings = subprocess.run(["/usr/bin/strings", binary], capture_output=True, text=True, check=True).stdout
    if "VELLEM_TEST_DIRECTORY" not in strings:
        raise SystemExit("The binary does not support the Debug isolation directory; refusing to run.")

    with tempfile.TemporaryDirectory(prefix="vellem-codex-discovery-") as directory:
        config = ("mcp_servers={vellem_check={command=" + json.dumps(binary) +
                  ",env={VELLEM_TEST_DIRECTORY=" + json.dumps(directory) + "}}}")
        process = subprocess.Popen(["codex", "-c", config, "app-server", "--stdio"], cwd=directory,
                                   env=dict(os.environ, CODEX_HOME=directory),
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                   text=True, bufsize=1)
        messages = queue.Queue()

        def read_messages():
            for line in process.stdout:
                try:
                    messages.put(json.loads(line))
                except json.JSONDecodeError:
                    continue

        threading.Thread(target=read_messages, daemon=True).start()

        def request(message):
            process.stdin.write(json.dumps(message) + "\n")
            process.stdin.flush()
            while True:
                response = messages.get(timeout=30)
                if response.get("id") == message["id"]:
                    if "error" in response:
                        raise RuntimeError(response["error"])
                    return response["result"]

        try:
            request({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
                "clientInfo": {"name": "vellem-integration-test", "version": "1"}}})
            process.stdin.write(json.dumps({"jsonrpc": "2.0", "method": "initialized", "params": {}}) + "\n")
            process.stdin.flush()
            response = request({"jsonrpc": "2.0", "id": 2, "method": "mcpServerStatus/list", "params": {
                "serverName": "vellem_check", "detail": "toolsAndAuthOnly"}})
            servers = response.get("data", [])
            assert len(servers) == 1 and servers[0]["name"] == "vellem_check"
            tools = servers[0]["tools"]
            assert tools["add_note"]["inputSchema"]["required"] == ["text"]
            assert "update_note" not in tools and "search_notes" in tools
            assert "send_output" in tools
            thread = request({"id": 3, "method": "thread/start", "params": {"ephemeral": True}})
            result = request({"id": 4, "method": "mcpServer/tool/call", "params": {
                "threadId": thread["thread"]["id"], "server": "vellem_check", "tool": "send_output",
                "arguments": {"text": "    hello from Codex\n", "format": "code"}}})
            assert not result.get("isError"), result
            note = json.loads((Path(directory) / "notes.json").read_text())[0]
            assert note["text"] == "    hello from Codex\n" and "Codex" in note["sourceApp"], note["sourceApp"]
            print("Codex discovered send_output and delivered code through the real app server: PASS")
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


if __name__ == "__main__":
    main()
