#!/bin/bash
# SessionStart hook — provision Godot 4.5 for Claude Code on the web.
#
# The remote container ships without Godot and is reclaimed between sessions, so
# every web session has to install it again before the headless suite, the
# simulator or the tools can run. This script does that, then warms the
# class_name import scan the project requires (see CLAUDE.md: skipping the scan
# makes every GUT suite fail with "Identifier not found").
#
# Local sessions are left alone — this only runs when CLAUDE_CODE_REMOTE=true.
#
# Failure is non-fatal by design: a session that cannot install Godot should
# still start, and CLAUDE.md documents the read-only fallback.

set -euo pipefail

# Pinned release. When bumping the version, update BOTH lines — the SHA512 is
# the published checksum from the release's SHA512-SUMS.txt.
readonly GODOT_VERSION="4.5-stable"
readonly GODOT_SHA512="b5bd5d8a4dd3f44de1d123361beabaafa4825dd05b5e20fd2bfa540f32594f81d82e7c4e86fae420f4faee77d9def573b570f8b156e9c84a4dc2d5123d09e852"
readonly GODOT_ZIP="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
readonly GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_ZIP}"
readonly INSTALL_PATH="/usr/local/bin/godot"

log() { echo "[session-start] $*"; }

# Web sessions only.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Idempotent: a cached container may already have the right binary.
if command -v godot >/dev/null 2>&1 && godot --version 2>/dev/null | grep -q '^4\.5\.stable'; then
  log "Godot $(godot --version 2>/dev/null | tail -1) already installed — skipping download."
else
  install_godot() {
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN

    log "Downloading Godot ${GODOT_VERSION} (~66 MB)..."
    curl -sSL --retry 3 --retry-delay 2 --max-time 300 -o "$tmp/godot.zip" "$GODOT_URL"

    log "Verifying checksum..."
    echo "${GODOT_SHA512}  $tmp/godot.zip" | sha512sum -c - >/dev/null

    unzip -oq "$tmp/godot.zip" -d "$tmp"
    install -m 0755 "$tmp/Godot_v${GODOT_VERSION}_linux.x86_64" "$INSTALL_PATH"
    log "Installed $($INSTALL_PATH --version 2>/dev/null | tail -1) -> ${INSTALL_PATH}"
  }

  if ! install_godot; then
    log "WARNING: could not install Godot — the headless suite and simulator will"
    log "         be unavailable this session. Work read-only and do not claim"
    log "         tests pass (see CLAUDE.md)."
    exit 0
  fi
fi

# Warm the import scan so class_name globals resolve and .godot/ is cached with
# the container. Without this the first `gut_cmdln.gd` run fails outright.
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"
log "Running the class_name import scan..."
if godot --headless --editor --quit >/dev/null 2>&1; then
  log "Import scan complete — the GUT suite is ready to run."
else
  log "WARNING: the import scan failed; run 'godot --headless --editor --quit'"
  log "         manually before the test suite."
fi

exit 0
