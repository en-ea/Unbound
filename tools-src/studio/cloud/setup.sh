#!/usr/bin/env bash
# Studio cloud sessions (Claude Code cloud VM: Ubuntu 24.04, x86_64, no GPU): installs what the studio's checks and
# look boards need. Safe to run again; each step skips when it is already done. Paste this file into the cloud
# environment's setup script so the result is cached (it must finish in about five minutes); a session can also run
# it itself: bash tools-src/studio/cloud/setup.sh
#
#   STUDIO_WEB=1        also install the Web export templates (a large download; only for web export checks)
#   STUDIO_BPY=1        also install Blender 4.5 as the bpy module (needs Python 3.11; only for model generation)
#   STUDIO_GODOT_ZIP    a path to Godot_v<ver>-stable_linux.x86_64.zip already on disk (used instead of downloading)
#
# Versions follow Enea's tools-src/cloud_setup.sh (Godot 4.7.2, bpy 4.5.14). Change them only after he does.
# Prints "STUDIO SETUP OK ..." or "STUDIO SETUP FAIL ..." lines and always exits 0, so an environment still starts and
# the session can read what is missing; tools-src/studio/cloud/runs/* refuse to run without the engine.
set -u
VER=4.7.2
BPY=4.5.14
G=$HOME/godot/Godot_v${VER}-stable_linux.x86_64
URL=https://github.com/godotengine/godot-builds/releases/download/${VER}-stable
say() { echo "STUDIO SETUP $*"; }
SUDO=""
[ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"

# 1. A virtual display, Mesa's software OpenGL (llvmpipe) and the libraries Godot's Linux build loads.
if ! command -v xvfb-run >/dev/null 2>&1; then
	export DEBIAN_FRONTEND=noninteractive
	if ($SUDO apt-get update -qq && $SUDO apt-get install -y -qq xvfb xauth unzip mesa-utils \
		libgl1 libgl1-mesa-dri libglx-mesa0 libegl1 libgles2 libx11-6 libxcursor1 libxinerama1 libxext6 \
		libxrandr2 libxrender1 libxi6 libxkbcommon0 libfontconfig1 libdbus-1-3 libasound2t64 libpulse0) \
		> /tmp/studio-apt.log 2>&1; then
		say "OK display packages"
	else
		say "FAIL apt install (see /tmp/studio-apt.log)"
	fi
else
	say "OK display packages (already present)"
fi

# 2. The Godot editor binary.
if [ ! -x "$G" ]; then
	mkdir -p "$HOME/godot"
	zip=${STUDIO_GODOT_ZIP:-/tmp/godot.zip}
	if [ -z "${STUDIO_GODOT_ZIP:-}" ]; then
		code=$(curl -sSL -w '%{http_code}' -o "$zip" "$URL/Godot_v${VER}-stable_linux.x86_64.zip" 2>/tmp/studio-godot.log)
		[ "$code" != 200 ] && say "FAIL godot download HTTP $code from godotengine/godot-builds (cloud sessions reach release assets of attached repositories only; see docs/studio/CLOUD-SESSIONS.md)"
	fi
	[ -f "$zip" ] && unzip -oq "$zip" -d "$HOME/godot" 2>>/tmp/studio-godot.log && chmod +x "$G" 2>/dev/null
	[ -z "${STUDIO_GODOT_ZIP:-}" ] && rm -f "$zip"
fi
if [ -x "$G" ]; then say "OK godot $G"; else say "FAIL godot missing at $G"; fi

# 3. Optional: the Web export templates.
if [ "${STUDIO_WEB:-0}" = 1 ]; then
	T=$HOME/.local/share/godot/export_templates/${VER}.stable
	if [ ! -f "$T/web_nothreads_release.zip" ]; then
		mkdir -p "$T"
		if curl -fsSL -o /tmp/tpl.tpz "$URL/Godot_v${VER}-stable_export_templates.tpz" 2>/tmp/studio-tpl.log \
			&& unzip -ojq /tmp/tpl.tpz 'templates/web*' 'templates/version.txt' -d "$T"; then
			say "OK web templates"
		else
			say "FAIL web templates (see /tmp/studio-tpl.log)"
		fi
		rm -f /tmp/tpl.tpz
	else
		say "OK web templates (already present)"
	fi
fi

# 4. Optional: Blender as the bpy module.
if [ "${STUDIO_BPY:-0}" = 1 ]; then
	if [ ! -x "$HOME/blender-venv/bin/python" ]; then
		py=$(command -v python3.11 || true)
		if [ -z "$py" ] && command -v uv >/dev/null 2>&1; then
			uv python install 3.11 > /tmp/studio-py.log 2>&1 && py=$(uv python find 3.11 2>/dev/null || true)
		fi
		if [ -n "$py" ] && "$py" -m venv "$HOME/blender-venv" && "$HOME/blender-venv/bin/pip" install -q "bpy==$BPY" \
			> /tmp/studio-bpy.log 2>&1; then
			say "OK bpy $BPY"
		else
			say "FAIL bpy (Python 3.11: ${py:-not found}; see /tmp/studio-py.log and /tmp/studio-bpy.log)"
		fi
	else
		say "OK bpy (already present)"
	fi
fi
exit 0
