#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d -t vellem-library-files)"
trap 'rm -rf "$TEST_DIR"' EXIT

swiftc "$ROOT_DIR/Vellem/Stores/LibraryFileTransaction.swift" \
  "$ROOT_DIR/Tests/LibraryFileTransactionTests.swift" -o "$TEST_DIR/test-library-files"
"$TEST_DIR/test-library-files" "$TEST_DIR"
