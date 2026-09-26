#!/usr/bin/env bash
# Headless build+run of GMForms via gm-cli (https://github.com/YoYoGames/gm-cli), reporting the
# headless test suite result. Wraps the gotchas documented in CLAUDE.md's "Building, running and
# testing" section: `run` never exits on its own, output is ANSI-spinner noise, and the result we
# actually want ("[GMForms tests] N passed, M failed") appears near the top of the log.
#
# Usage:
#   tools/gmtest.sh                  # build + run, print the result line, exit 0 iff 0 failed
#   tools/gmtest.sh --compile-only   # syntax/asset-compile check only, no game launch (faster)
#   tools/gmtest.sh --timeout=60     # override how long to wait for the result line (default 90s)
set -uo pipefail
cd "$(dirname "$0")/.."

COMPILE_ONLY=0
MAX_WAIT=90
for arg in "$@"; do
  case "$arg" in
    --compile-only) COMPILE_ONLY=1 ;;
    --timeout=*) MAX_WAIT="${arg#*=}" ;;
    *) echo "gmtest: unknown argument '$arg'" >&2; exit 64 ;;
  esac
done

CLI=(npx --yes @gamemaker/gm-cli@latest)
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

strip() { tr -d '\r' | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g'; }

if [ "$COMPILE_ONLY" = "1" ]; then
  "${CLI[@]}" compile GMForms.yyp --target=windows --runtime=vm --verbose > "$LOG" 2>&1
  status=$?
  strip < "$LOG"
  exit $status
fi

"${CLI[@]}" run GMForms.yyp --target=windows --runtime=vm --verbose > "$LOG" 2>&1 &
PID=$!

for ((i = 0; i < MAX_WAIT; i++)); do
  grep -q '\[GMForms tests\]' "$LOG" 2>/dev/null && break
  kill -0 "$PID" 2>/dev/null || break   # process exited early, probably a build error
  sleep 1
done

kill "$PID" 2>/dev/null
wait "$PID" 2>/dev/null
# The above only stops bash's view of the top-level npx process. gm-cli actually chains
# npx -> node -> Igor.exe -> Runner.exe, and on git-bash/Windows, $! does not reliably map onto
# that real Windows process tree (taskkill //T //PID "$PID" is a silent no-op here) — so the game
# window (Runner.exe) and Igor.exe can survive as orphans. Kill them by name instead: both are
# GameMaker-exclusive binaries, so this is safe (unlike e.g. node.exe, which is not).
if command -v taskkill >/dev/null 2>&1; then
  taskkill //F //IM Runner.exe >/dev/null 2>&1
  taskkill //F //IM Igor.exe >/dev/null 2>&1
fi

CLEAN="$(strip < "$LOG")"
echo "$CLEAN" | grep -E '\[GMForms\]|\[GMForms tests\]|[Ee]rror'

RESULT_LINE="$(echo "$CLEAN" | grep '\[GMForms tests\]' | tail -1)"
if [ -z "$RESULT_LINE" ]; then
  echo "gmtest: no '[GMForms tests]' line within ${MAX_WAIT}s — build likely failed; full log:" >&2
  echo "$CLEAN" >&2
  exit 2
fi
echo "$RESULT_LINE" | grep -q ' 0 failed' && exit 0
exit 1
