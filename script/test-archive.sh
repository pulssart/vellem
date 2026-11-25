#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d -t vellem-archive-test)"
trap 'rm -rf "$TEST_DIR"' EXIT

swiftc -D DEBUG -enable-bare-slash-regex \
  "$ROOT_DIR/VellemShared/VellemLanguage.swift" \
  "$ROOT_DIR/VellemShared/VellemDisplayText.swift" \
  "$ROOT_DIR/VellemShared/VellemStorageEnvironment.swift" \
  "$ROOT_DIR/Vellem/Models/Note.swift" \
  "$ROOT_DIR/Vellem/Models/Folder.swift" \
  "$ROOT_DIR/Vellem/Support/AppGroup.swift" \
  "$ROOT_DIR/Vellem/Support/AppPreferences.swift" \
  "$ROOT_DIR/Vellem/Services/NotesArchiveService.swift" \
  "$ROOT_DIR/Tests/NotesArchiveTests.swift" \
  -o "$TEST_DIR/test-archive"
VELLEM_TEST_DIRECTORY="$TEST_DIR/library" "$TEST_DIR/test-archive"
