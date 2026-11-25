#!/usr/bin/env python3
"""Health-check an isolated Debug server with the installed Claude Code client."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 Tests/test_claude_connection.py /path/to/Debug/vellem-mcp")
    binary = str(Path(sys.argv[1]).resolve())
    strings = subprocess.run(["/usr/bin/strings", binary], capture_output=True, text=True, check=True).stdout
    if "VELLEM_TEST_DIRECTORY" not in strings:
        raise SystemExit("The binary does not support the Debug isolation directory; refusing to run.")

    with tempfile.TemporaryDirectory(prefix="vellem-claude-connection-") as directory:
        config = Path(directory) / "config"
        config.mkdir()
        env = dict(os.environ, CLAUDE_CONFIG_DIR=str(config))
        listing = subprocess.run(["claude", "mcp", "list"], cwd=directory, env=env,
                                 capture_output=True, text=True, timeout=30, check=True)
        if "No MCP servers configured" not in listing.stdout:
            raise SystemExit("Claude did not use the isolated configuration; refusing to modify it.")
        subprocess.run(["claude", "mcp", "add", "--scope", "user", "--transport", "stdio", "vellem_check",
                        "--", binary], cwd=directory, env=env, capture_output=True, text=True, timeout=30, check=True)
        health = subprocess.run(["claude", "mcp", "get", "vellem_check"], cwd=directory, env=env,
                                capture_output=True, text=True, timeout=30, check=True)
        if "Connected" not in health.stdout:
            raise SystemExit("Claude Code did not report a successful MCP connection.")
        print("Claude Code connected to the isolated Vellem MCP server: PASS")


if __name__ == "__main__":
    main()
