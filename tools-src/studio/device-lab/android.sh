#!/usr/bin/env bash
# Device lab, Android side: build a Godot project, sign it, put it on a USB-connected phone, and
# measure it. Game-agnostic: everything project-specific comes from the variables below.
# Usage: source android.sh; lab_build <project_dir> <preset> <out.apk>; [lab_args <apk> <dev args...>];
#        lab_install <apk>; lab_wake; lab_run <pkg> <label>; lab_userfile <pkg> <path>
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
  lab_sign "$3"
}

lab_sign() {    # apk
  "$LAB_SDK/build-tools/$LAB_BUILD_TOOLS/apksigner.bat" sign --ks "$LAB_TOOLS/debug.keystore" \
    --ks-pass pass:android --ks-key-alias androiddebugkey "$1" &&
  "$LAB_SDK/build-tools/$LAB_BUILD_TOOLS/apksigner.bat" verify "$1" && echo "signed and verified: $1"
}

# Bakes dev arguments into a built APK, with no change to the project. Godot reads its command line
# from assets/_cl_ (a count, then length-prefixed strings, little-endian); this appends "-- args",
# so the game sees them in OS.get_cmdline_user_args(). Launch extras (am start --esa) did not reach
# Godot 4.7.2 in our test. The APK is re-aligned and re-signed.
lab_args() {    # apk arg...
  local apk=$1; shift
  python "$(dirname "${BASH_SOURCE[0]}")/bake_args.py" "$apk" "$@" || return 1
  "$LAB_SDK/build-tools/$LAB_BUILD_TOOLS/zipalign.exe" -f -p 4 "$apk" "$apk.aligned" && mv "$apk.aligned" "$apk" && lab_sign "$apk"
}

# Wakes the screen and dismisses a swipe lock. A PIN or pattern needs a person, and this says so
# (Android pauses a game whose screen is locked, so a run would silently do nothing).
lab_wake() {
  "$ADB" shell input keyevent KEYCODE_WAKEUP; sleep 1; "$ADB" shell wm dismiss-keyguard; sleep 2
  if "$ADB" shell dumpsys window | grep -q "isKeyguardShowing=true"; then
    echo "LOCKED: the phone needs unlocking by hand"; return 1
  fi
  echo "awake and unlocked"
}

# Reads a file the game wrote to user:// (debug builds only: run-as needs a debuggable app).
lab_userfile() { "$ADB" exec-out run-as "$1" cat "files/$2"; }   # pkg path

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
