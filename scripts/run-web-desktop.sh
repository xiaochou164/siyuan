#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
KERNEL_BIN="$APP_DIR/kernel/SiYuan-Kernel"
RUNTIME_DIR="$ROOT_DIR/.runtime"
PID_FILE="$RUNTIME_DIR/web-desktop.pid"
LOG_FILE="$RUNTIME_DIR/web-desktop.log"

PORT="${SIYUAN_PORT:-6806}"
WORKSPACE="${SIYUAN_WORKSPACE:-$HOME/SiYuan}"
MODE="${SIYUAN_MODE:-prod}"
ACCESS_AUTH_CODE="${SIYUAN_ACCESS_AUTH_CODE:-}"

usage() {
  cat <<USAGE
Usage: $(basename "$0") <command>

Commands:
  build       Build frontend and kernel for web-desktop
  start       Start SiYuan in background
  foreground  Start SiYuan in foreground
  stop        Stop background process
  restart     Restart background process
  status      Show process status
  logs        Tail runtime logs

Environment:
  SIYUAN_ACCESS_AUTH_CODE   Required in prod mode
  SIYUAN_PORT               Default: 6806
  SIYUAN_WORKSPACE          Default: \$HOME/SiYuan
  SIYUAN_MODE               Default: prod
USAGE
}

is_running() {
  [[ -f "$PID_FILE" ]] || return 1
  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

ensure_runtime() {
  mkdir -p "$RUNTIME_DIR"
  mkdir -p "$WORKSPACE"
}

require_tools() {
  command -v corepack >/dev/null 2>&1 || {
    echo "corepack not found. Please install Node.js >= 20." >&2
    exit 1
  }
  command -v go >/dev/null 2>&1 || {
    echo "go not found. Please install Go >= 1.25." >&2
    exit 1
  }
}

ensure_assets_layout() {
  if [[ -d "$APP_DIR/stage/build/web-desktop" ]]; then
    rm -rf "$APP_DIR/stage/build/desktop"
    cp -r "$APP_DIR/stage/build/web-desktop" "$APP_DIR/stage/build/desktop"
  fi
}

build_all() {
  require_tools
  cd "$APP_DIR"
  corepack enable
  corepack pnpm install
  corepack pnpm run build
  corepack pnpm run build:web-desktop
  ensure_assets_layout

  cd "$ROOT_DIR/kernel"
  export CGO_ENABLED=1
  go mod download
  go build --tags "fts5" -o ../app/kernel/SiYuan-Kernel

  echo "Build completed."
}

kernel_cmd() {
  local cmd=("$KERNEL_BIN" "--wd=$APP_DIR" "--mode=$MODE" "--port=$PORT" "--workspace=$WORKSPACE")
  if [[ -n "$ACCESS_AUTH_CODE" ]]; then
    cmd+=("--accessAuthCode=$ACCESS_AUTH_CODE")
  fi
  printf '%q ' "${cmd[@]}"
}

start_bg() {
  ensure_runtime
  if [[ ! -x "$KERNEL_BIN" ]]; then
    echo "Kernel binary not found at $KERNEL_BIN. Run: $0 build" >&2
    exit 1
  fi
  ensure_assets_layout

  if [[ "$MODE" == "prod" && -z "$ACCESS_AUTH_CODE" ]]; then
    echo "SIYUAN_ACCESS_AUTH_CODE is required in prod mode." >&2
    exit 1
  fi

  if is_running; then
    echo "Already running: PID $(cat "$PID_FILE")"
    exit 0
  fi

  local cmd
  cmd="$(kernel_cmd)"
  nohup bash -lc "$cmd" >>"$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"
  sleep 1

  if is_running; then
    echo "Started: PID $(cat "$PID_FILE"), port $PORT"
    echo "Log: $LOG_FILE"
  else
    echo "Failed to start. Check logs: $LOG_FILE" >&2
    exit 1
  fi
}

start_fg() {
  ensure_runtime
  if [[ ! -x "$KERNEL_BIN" ]]; then
    echo "Kernel binary not found at $KERNEL_BIN. Run: $0 build" >&2
    exit 1
  fi
  ensure_assets_layout

  if [[ "$MODE" == "prod" && -z "$ACCESS_AUTH_CODE" ]]; then
    echo "SIYUAN_ACCESS_AUTH_CODE is required in prod mode." >&2
    exit 1
  fi

  local cmd
  cmd="$(kernel_cmd)"
  exec bash -lc "$cmd"
}

stop_bg() {
  if ! is_running; then
    echo "Not running."
    rm -f "$PID_FILE"
    exit 0
  fi

  local pid
  pid="$(cat "$PID_FILE")"
  kill "$pid" 2>/dev/null || true

  for _ in {1..20}; do
    if ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$PID_FILE"
      echo "Stopped."
      return
    fi
    sleep 0.2
  done

  kill -9 "$pid" 2>/dev/null || true
  rm -f "$PID_FILE"
  echo "Stopped (forced)."
}

status_bg() {
  if is_running; then
    echo "Running: PID $(cat "$PID_FILE"), port $PORT"
  else
    echo "Not running."
  fi
}

logs_bg() {
  ensure_runtime
  touch "$LOG_FILE"
  tail -f "$LOG_FILE"
}

cmd="${1:-}"
case "$cmd" in
  build) build_all ;;
  start) start_bg ;;
  foreground) start_fg ;;
  stop) stop_bg ;;
  restart) stop_bg; start_bg ;;
  status) status_bg ;;
  logs) logs_bg ;;
  *) usage; exit 1 ;;
esac
