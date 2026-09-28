#!/usr/bin/env bash
# Device lab, Android side: build a Godot project, sign it, put it on a USB-connected phone, and
# measure it. Game-agnostic: everything project-specific comes from the variables below.
# Usage: source android.sh; lab_build <project_dir> <preset> <out.apk>; lab_install <apk>; lab_run <pkg> <label>
set -u
LAB_TOOLS="${LAB_TOOLS:-C:/Users/hilmi/AppData/Local/UnboundStudio/tools}"
LAB_SDK="${LAB_SDK:-C:/Users/hilmi/AppData/Local/Android/Sdk}"
LAB_OUT="${LAB_OUT:-.}"                      # where screenshots and readings go
LAB_GODOT="${LAB_GODOT:-$LAB_TOOLS/godot/Godot_v4.7.2-stable_win64_console.exe}"
LAB_BUILD_TOOLS="${LAB_BUILD_TOOLS:-35.0.1}"  # Godot 4.7.2 falls back to the OLDEST build-tools when none match
                                              # target SDK 36, and that signer fails silently - so we re-sign here
export JAVA_HOME="${JAVA_HOME:-$(ls -d "$LAB_TOOLS"/jdk/*/ | head -1)}"
export PATH="$JAVA_HOME/bin:$PATH"
export MSYS_NO_PATHCONV=1
ADB="$LAB_SDK/platform-tools/adb.exe"

lab_build() {   # project_dir preset out.apk
  "$LAB_GODOT" --headless --path "$1" --export-debug "$2" "$3" 2>&1 | grep -E "DONE.*export|ERROR" | tail -2
  "$LAB_SDK/build-tools/$LAB_BUILD_TOOLS/apksigner.bat" sign --ks "$LAB_TOOLS/debug.keystore" \
    --ks-pass pass:android --ks-key-alias androiddebugkey "$3" &&
  "$LAB_SDK/build-tools/$LAB_BUILD_TOOLS/apksigner.bat" verify "$3" && echo "signed and verified: $3"
}

lab_install() { timeout 180 "$ADB" install -r "$1" 2>&1 | tail -1; }

lab_temps() { "$ADB" shell dumpsys thermalservice | grep -m2 'mName=AP\|mName=SKIN' |
  sed 's/.*mValue=\([0-9.]*\).*mName=\([A-Z]*\).*/\2=\1C/' | tr '\n' ' '; }

lab_shot() { "$ADB" exec-out screencap -p > "$LAB_OUT/$1.png"; }

# Cold start with cleared data, screenshot after load, optional tap, then N minutes of temperature
# samples and a final screenshot. The game's own on-screen fps overlay is read from the screenshots.
lab_run() {     # pkg label [tap_x tap_y] [minutes]
  local pkg=$1 label=$2 tx=${3:-} ty=${4:-} mins=${5:-3}
  "$ADB" shell am force-stop "$pkg"; "$ADB" shell pm clear "$pkg" >/dev/null
  "$ADB" logcat -c; "$ADB" shell monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  sleep 35; lab_shot "$label-start"
  if [ -n "$tx" ]; then "$ADB" shell input tap "$tx" "$ty"; sleep 20; lab_shot "$label-after-tap"; fi
  for m in $(seq 1 "$mins"); do sleep 60; echo "t=${m}min $(lab_temps)"; done | tee "$LAB_OUT/$label-thermal.txt"
  lab_shot "$label-end"
  "$ADB" logcat -d | grep -i -m3 "OpenGL API\|renderingDevice\|Vulkan API" > "$LAB_OUT/$label-renderer.txt"
  "$ADB" shell am force-stop "$pkg"
}
