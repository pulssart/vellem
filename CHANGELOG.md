# Vellem 1.0.16

This release adds the experimental true transparent sidebar setting for macOS 27.

## What changed

. Settings now has a True transparent sidebar toggle in Appearance.
. When enabled, the sidebar uses a behind-window AppKit material so desktop content can show through more directly.
. Archive export and import now preserve the transparent sidebar preference.

## Validation

. Built and launched locally with `bash script/build_and_run.sh run`.
. Release artifact is signed, notarized, stapled, and ready for Sparkle updates.

# Vellem 1.0.15

This release fixes the macOS launch failure seen after installing or updating to 1.0.14.

## Fixes

. Removed iCloud entitlements from the Mac app target because the Developer ID build did not ship with a matching profile.
. Fresh installs and Sparkle updates can now launch the app again after macOS validates the signed bundle.

## Validation

. Reproduced the launch failure locally from the 1.0.14 DMG.
. Built a signed release and verified the fixed app launches from a copied DMG install.

# Vellem 1.0.14

This release focuses on safer backups, data recovery, richer note rendering, and stricter agent context.

## What changed

. Settings now has a Data tab to export the full Vellem library as JSON.
. JSON exports include notes, folders, attachments, and user preferences.
. JSON imports can restore the same archive after confirmation, replacing the current local library.
. Markdown tables now use a native macOS table renderer with column resizing and cleaner overflow.
. Note copy actions now prefer stable note references where that helps agent workflows.
. MCP note creation now requires explicit decision context so new agent notes keep their source, effect, expiry, and validation rule.

## Fixes

. Import and export now use native AppKit file panels with user-selected file access enabled in the sandbox.
. Widget reloads now target the Vellem widget kind directly and retry shortly after note changes.
. Split view autosave now retries when SwiftUI attaches the underlying native split view late.

## Validation

. Built and launched locally with `bash script/build_and_run.sh run`.
. Release artifact is signed, notarized, stapled, and ready for Sparkle updates.

# Vellem 1.0.12

This release focuses on Inbox, cleaner list controls, mobile iCloud groundwork, richer widgets, and the new promo video package.

## What changed

. Inbox is now a first-class smart view, with unread counts and note provenance kept visible.
. Folder and Inbox lists now support unread filtering, preview toggles, provenance toggles, and newest or oldest sorting.
. The sidebar and top toolbar color treatment can now be controlled from Settings.
. Quick Capture opens from the main toolbar and keeps new captures visible in Inbox.
. Widgets now use safer shared display text and show richer note context.
. The iPhone target has been added with an iCloud-backed mobile note store and markdown rendering.
. The promo video package is now in the repo for future release assets.

## Fixes

. Folder navigation keeps the selected note aligned with active filters.
. Notes file I/O now creates parent directories before writes.
. Sidebar sections were simplified around Inbox, Today, smart folders, and user folders.

## Validation

. Built and launched locally with `bash script/build_and_run.sh run`.
. Release artifact is signed, notarized, stapled, and ready for Sparkle updates.

# Vellem 1.0.11

This release focuses on the agent notebook workflow, safer widget links, cleaner note actions, and a calmer first-run onboarding.

## What changed

. The onboarding flow was redesigned around five product steps, with a softer accent gradient, shorter modal, richer copy, and one-click MCP setup copy for Claude and Codex.
. Note context menus are now shared across Today, folders, and recent notes, so note actions stay consistent.
. The note detail header now makes provenance, edit and preview mode, and word count easier to read.
. Codex and Claude setup guidance now supports faster copy flows for MCP config.

## Fixes

. Widget deeplinks no longer rely on force-unwrapped raw URLs.
. The sidebar search field no longer steals focus on app launch.
. Embedding cache entries are pruned when notes disappear, avoiding stale semantic search data.
. Semantic search now blends lexical and embedding signals for more useful matches.

## Validation

. Built and launched locally with `bash script/build_and_run.sh run`.

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
