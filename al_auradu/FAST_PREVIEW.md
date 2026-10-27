# AL AURADU: Fast Codespaces preview (port 3000)

The browser can remain white for minutes when it opens a **Flutter debug**
server still compiling or a forwarded port that belongs to the **Dart
Development Service (DDS)**. The Codespaces app URL is not a permanent
deployment and may go offline when the Codespace stops.

## Recommended preview: compiled Flutter release

1. Open the trusted Al Auradu Codespace, preserving uncommitted files.
2. Switch safely to the current branch (or pull this PR into your current
   approved PDF branch).
3. In a terminal at `/workspaces/aurad`, stop only the **existing server on
   port 3000** if one is running. Do not kill arbitrary Dart processes and
   NEVER discard, stash-drop, or force reset local edits.
4. On the first preview or after code/asset updates, run:

   `bash al_auradu/tool/preview_fast.sh --rebuild`

   The Flutter release compilation happens **before** the server starts.
   Do not open the URL until the terminal prints the `Serving HTTP` message.
5. Open Codespaces **PORTS → 3000 → Open in Browser**. Set visibility to
   **Private**, not public. Hard-refresh once (Ctrl+Shift+R) if a browser has
   previously cached a broken development bootstrap.
6. To restart the same compiled release without a new compilation, stop the
   server with Ctrl+C, then run:

   `bash al_auradu/tool/preview_fast.sh`

## Expectations

- First-time **release compilation** can take a while. The source screenshot
  does not diagnose the exact failed request; inspect Console/Network if the
  page is still white once the server is ready.
- Subsequent **warm page loads** can be much faster because they do not
  require Flutter's Dart debug compilation/DDS connection.
- This preview has **no hot reload**; after any Dart or asset changes rebuild
  using `--rebuild`.
- The approved navy/gold Home, all 114 Quran/30 Juz labels, PDF artwork,
  badges and folders are untouched.
- The PDF viewer still loads its document only on opening a book.
- This **does not** make Codespaces a 24/7 hosted app. Opening a stopped
  Codespace requires restarting it. For an always-on instant production URL,
  use a separate hosting deployment only with the owner's approval.

This preview uses the standard `flutter build web --release` output
(`build/web`) served by Python's built-in static HTTP server; it contains
only the Flutter app and does not add any HTML/CSS-based app components.
