#!/bin/sh
# Skillz agent activity notifier — updates ~/Library/Application Support/Skillz/agent-state.json
# Usage: skillz-agent-notify.sh <platform> <state> [session_id] [title] [cwd] [pid]
# States: working | idle | needsInput | release

set -eu

platform="${1:-}"
state="${2:-}"
session_id="${3:-}"
title="${4:-}"
cwd="${5:-}"
pid="${6:-}"
input_file="$(mktemp "${TMPDIR:-/tmp}/skillz-agent-hook.XXXXXX")" || exit 0
trap 'rm -f "$input_file"' EXIT HUP INT TERM
cat >"$input_file" 2>/dev/null || true

case "$platform" in
  cursor|claudeCode|codex) ;;
  *) exit 0 ;;
esac

case "$state" in
  working|idle|needsInput|release) ;;
  *) exit 0 ;;
esac

STATE_DIR="${HOME}/Library/Application Support/Skillz"
STATE_FILE="${STATE_DIR}/agent-state.json"
LOCK_FILE="${STATE_DIR}/agent-state.lock"
mkdir -p "$STATE_DIR"

LOCK_DIR="${STATE_DIR}/agent-state.lockdir"
lock_attempt=0
while ! mkdir "$LOCK_DIR" 2>/dev/null; do
  lock_attempt=$((lock_attempt + 1))
  [ "$lock_attempt" -gt 100 ] && exit 0
  sleep 0.05
done
trap 'rm -f "$input_file"; rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT HUP INT TERM

export SKILLZ_PLATFORM="$platform"
export SKILLZ_STATE="$state"
export SKILLZ_SESSION_ID="$session_id"
export SKILLZ_TITLE="$title"
export SKILLZ_CWD="$cwd"
export SKILLZ_PID="$pid"
export SKILLZ_STATE_FILE="$STATE_FILE"
export SKILLZ_LOCK_FILE="$LOCK_FILE"
export SKILLZ_HOOK_INPUT_FILE="$input_file"

/usr/bin/osascript -l JavaScript <<'JXA'
ObjC.import('Foundation')

const env = $.NSProcessInfo.processInfo.environment

function getenv(key) {
  const value = env.objectForKey(key)
  return value ? ObjC.unwrap(value) : ''
}

function readText(path) {
  const data = $.NSData.dataWithContentsOfFile(path)
  if (!data) return ''
  const text = $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding)
  return text ? ObjC.unwrap(text) : ''
}

function writeText(path, text) {
  const nsText = $.NSString.alloc.initWithUTF8String(text)
  nsText.writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null)
}

function firstString(object, keys) {
  for (const key of keys) {
    const value = object[key]
    if (typeof value === 'string' && value.length > 0) return value
  }
  return ''
}

let platform = getenv('SKILLZ_PLATFORM')
let state = getenv('SKILLZ_STATE')
let sessionID = getenv('SKILLZ_SESSION_ID')
let title = getenv('SKILLZ_TITLE')
let cwd = getenv('SKILLZ_CWD')
let pidString = getenv('SKILLZ_PID')
const stateFile = getenv('SKILLZ_STATE_FILE')
const inputFile = getenv('SKILLZ_HOOK_INPUT_FILE')

let hookInput = {}
try {
  const raw = readText(inputFile)
  if (raw.trim().length > 0) hookInput = JSON.parse(raw)
} catch (_) {
  hookInput = {}
}

if (!sessionID) sessionID = firstString(hookInput, ['session_id', 'sessionId', 'conversation_id', 'conversationId'])
if (!cwd) cwd = firstString(hookInput, ['cwd', 'workspace', 'workspace_root'])
if (!title) title = firstString(hookInput, ['message', 'prompt', 'hook_event_name', 'event'])
if (!pidString && Number.isInteger(hookInput.pid)) pidString = String(hookInput.pid)
if (!sessionID) sessionID = `${platform}:${pidString || $.NSProcessInfo.processInfo.processIdentifier}`

if (!platform || !state || !sessionID || !stateFile) $.exit(0)

let data = { version: 1, sessions: [] }
try {
  const raw = readText(stateFile)
  if (raw.trim().length > 0) data = JSON.parse(raw)
} catch (_) {
  data = { version: 1, sessions: [] }
}

const pid = /^[0-9]+$/.test(pidString) ? Number(pidString) : null
let sessions = Array.isArray(data.sessions) ? data.sessions.filter((session) => session.id !== sessionID) : []

if (state !== 'release') {
  sessions.push({
    id: sessionID,
    platform,
    state,
    title: title || (cwd ? cwd.split('/').filter(Boolean).pop() : platform),
    cwd: cwd || null,
    pid,
    updatedAt: new Date().toISOString()
  })
}

writeText(stateFile, JSON.stringify({ version: 1, sessions }, null, 2) + '\n')
JXA
