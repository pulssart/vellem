#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_BINARY="$(mktemp -t vellem-library-merge)"
trap 'rm -f "$TEST_BINARY"' EXIT

swiftc -enable-bare-slash-regex \
  "$ROOT_DIR/VellemShared/VellemLanguage.swift" \
  "$ROOT_DIR/VellemShared/VellemDisplayText.swift" \
  "$ROOT_DIR/Vellem/Models/Note.swift" \
  "$ROOT_DIR/Vellem/Stores/NoteLibraryMerge.swift" \
  "$ROOT_DIR/Tests/NoteLibraryMergeTests.swift" \
  -o "$TEST_BINARY"
"$TEST_BINARY"
