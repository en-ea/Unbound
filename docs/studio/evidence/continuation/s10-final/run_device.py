"""Bounded foreground Android measurements for the isolated Continuation package."""
import argparse
import json
import re
import subprocess
import time
from pathlib import Path

ADB = Path(r"C:\Users\hilmi\AppData\Local\Android\Sdk\platform-tools\adb.exe")
PKG = "com.unboundstudio.unbound.continuation"
OUT = Path(__file__).resolve().parent


def adb(*args, timeout=60, binary=False):
    p = subprocess.run([str(ADB), *args], capture_output=True, timeout=timeout)
    if p.returncode:
        raise RuntimeError(f"adb {args} exited {p.returncode}: {p.stderr.decode(errors='replace')}")
    return p.stdout if binary else p.stdout.decode(errors="replace")


def snapshot(label, second):
    stem = f"{label}-{second:04d}"
    (OUT / f"{stem}.png").write_bytes(adb("exec-out", "screencap", "-p", binary=True))
    (OUT / f"{stem}-thermal.txt").write_text(adb("shell", "dumpsys", "thermalservice"), encoding="utf-8")
    (OUT / f"{stem}-window.txt").write_text(adb("shell", "dumpsys", "window"), encoding="utf-8")
    (OUT / f"{stem}-activity.txt").write_text(adb("shell", "dumpsys", "activity", "activities"), encoding="utf-8")
    mem = adb("shell", "dumpsys", "meminfo", PKG)
    (OUT / f"{stem}-meminfo.txt").write_text(mem, encoding="utf-8")
    match = re.search(r"Native Heap:\s*(\d+)", mem)
    native_kb = int(match.group(1)) if match else -1
    print(f"sample {second}s captured", flush=True)
    return native_kb


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("label", choices=["s10-arrival", "s10-normal", "s10-arrival-guard", "s10-normal-guard"])
    ap.add_argument("apk", type=Path)
    args = ap.parse_args()
    label = args.label
    duration = 120 if "arrival" in label else 900
    points = [0, 10, 30, 40, 55, 115] if duration == 120 else [0, 10, 30, 55, 180, 360, 540, 720, 770, 895]
    window = adb("shell", "dumpsys", "window")
    if "isKeyguardShowing=true" in window:
        raise RuntimeError("device keyguard is showing; unlock by hand before measurement")
    print(adb("install", "-r", "--no-incremental", str(args.apk), timeout=300).strip(), flush=True)
    adb("shell", "am", "force-stop", PKG)
    adb("logcat", "-c")
    print(adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1").strip(), flush=True)
    started = time.monotonic()
    for second in points:
        time.sleep(max(0, started + second - time.monotonic()))
        native_kb = snapshot(label, second)
        if native_kb > 2_000_000:
            (OUT / f"{label}-abort.txt").write_text(f"native heap {native_kb} KB > 2,000,000 KB at {second}s\n", encoding="utf-8")
            (OUT / f"{label}-logcat.txt").write_text(adb("logcat", "-d", "-v", "threadtime", timeout=120), encoding="utf-8")
            adb("shell", "am", "force-stop", PKG)
            raise RuntimeError(f"memory guard: native heap {native_kb} KB at {second}s")
    time.sleep(max(0, started + duration + 25 - time.monotonic()))
    (OUT / f"{label}-logcat.txt").write_text(adb("logcat", "-d", "-v", "threadtime", timeout=120), encoding="utf-8")
    probe_name = f"studio-measure-{label}.json"
    probe = adb("exec-out", "run-as", PKG, "cat", f"files/{probe_name}", binary=True)
    (OUT / probe_name).write_bytes(probe)
    result = json.loads(probe)
    if result.get("label") != label or result.get("seconds", 0) < duration:
        raise RuntimeError(f"probe incomplete: {result.get('label')} {result.get('seconds')}")
    print(json.dumps({"probe": probe_name, "seconds": result["seconds"], "events": result.get("events")}), flush=True)


if __name__ == "__main__":
    main()
