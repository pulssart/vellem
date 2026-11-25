#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 /path/to/Debug/vellem-mcp" >&2
  exit 2
fi
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d -t vellem-concurrency-test)"
trap 'rm -rf "$TEST_DIR"' EXIT
if ! /usr/bin/strings "$1" | /usr/bin/grep 'VELLEM_TEST_DIRECTORY' >/dev/null; then
  echo "The MCP binary does not support the Debug isolation directory." >&2
  exit 2
fi

swiftc -D DEBUG -enable-bare-slash-regex \
  "$ROOT_DIR/VellemShared/VellemLanguage.swift" \
  "$ROOT_DIR/VellemShared/VellemDisplayText.swift" \
  "$ROOT_DIR/VellemShared/VellemStorageEnvironment.swift" \
  "$ROOT_DIR/VellemShared/VellemLibraryValidation.swift" \
  "$ROOT_DIR/VellemShared/LibraryWriteLock.swift" \
  "$ROOT_DIR/VellemShared/CloudMirrorStore.swift" \
  "$ROOT_DIR/Vellem/Models/Note.swift" \
  "$ROOT_DIR/Vellem/Models/Folder.swift" \
  "$ROOT_DIR/Vellem/Models/ExternalNoteEvent.swift" \
  "$ROOT_DIR/Vellem/Support/AppGroup.swift" \
  "$ROOT_DIR/Vellem/Stores/NoteLibraryMerge.swift" \
  "$ROOT_DIR/Vellem/Stores/LibraryFileTransaction.swift" \
  "$ROOT_DIR/Vellem/Stores/EmbeddingCachePruner.swift" \
  "$ROOT_DIR/Vellem/Stores/NotesStore.swift" \
  "$ROOT_DIR/Tests/ConcurrentStoreTests.swift" \
  -o "$TEST_DIR/test-concurrent-store"
VELLEM_TEST_DIRECTORY="$TEST_DIR/library" "$TEST_DIR/test-concurrent-store" "$1"
