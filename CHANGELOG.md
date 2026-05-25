# Vellem 1.0.8

This release focuses on the main notes experience, Prompt Library polish, Markdown rendering, macOS Services reliability, and the new app icon.

## What changed

. The notes shell now behaves like a cleaner split view, with sidebar, note list, and note detail only when the selected section needs them.
. Prompt Library opens without a useless right detail pane, uses larger editorial cards, and includes cleaner spacing between prompt categories.
. Today now behaves more like a chronological timeline, with the newest notes at the top.
. Markdown rendering is more complete, including fenced code blocks, H1 to H6 headings, multi-line quotes, numbered lists, inline code, tables, images, and interactive todos.
. The floating note viewer now matches the main renderer more closely.
. Quick Capture now follows the accent color chosen in Settings, including the title bar.
. Settings now uses a tabbed macOS-style layout.
. The macOS Services action was cleaned up so `Add to Vellem` no longer points to stale Supanote debug builds.
. Google Calendar, Slack, and Notion tool icons were updated.
. The app icon and landing page logo were replaced with the new Vellem icon set.

## Fixes

. Removed stale Supanote service registration during local build runs.
. Added cleanup for old Debug app registrations so macOS Services points to `/Applications/Vellem.app`.
. Improved Markdown parity between the main note view and floating viewer.
. Kept Codex and Claude smart sections tied to note source metadata after notes move to other folders.

## Validation

. Built and launched locally with `./script/build_and_run.sh --verify`.
. Release artifact is signed, notarized, stapled, and ready for Sparkle updates.
