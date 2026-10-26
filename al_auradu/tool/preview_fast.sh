#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Release builds launch far faster than Flutter debug/DDService sessions.
# Recompile after Dart or asset changes with the --rebuild argument.
if [ "${1:-}" = '--rebuild' ] || [ ! -s build/web/main.dart.js ]; then
  flutter pub get
  flutter build web --release
fi

if [ ! -s build/web/index.html ]; then
  echo 'Web build missing. Run with --rebuild.'
  exit 1
fi

echo 'AL AURADU READY: Open Codespaces PORTS tab > port 3000.'
exec python3 -m http.server 3000 --bind 0.0.0.0 --directory build/web
