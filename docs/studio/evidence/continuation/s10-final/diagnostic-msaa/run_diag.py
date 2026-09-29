"""One bounded S10 village diagnostic. No package data clearing or uninstallation."""
import argparse
import json
import re
import subprocess
import time
from pathlib import Path

ADB = r"C:\Users\hilmi\AppData\Local\Android\Sdk\platform-tools\adb.exe"
PKG = "com.unboundstudio.unbound.continuation"
OUT = Path(__file__).resolve().parent


def adb(*args, timeout=60):
    p = subprocess.run([ADB, *args], capture_output=True, timeout=timeout)
    if p.returncode:
        raise RuntimeError(f"adb {args}: {p.returncode}: {p.stderr.decode(errors='replace')}")
    return p.stdout


def sample(label, second):
    prefix = OUT / f"{label}-{second:03d}"
    (prefix.with_suffix(".png")).write_bytes(adb("exec-out", "screencap", "-p"))
    mem = adb("shell", "dumpsys", "meminfo", PKG).decode(errors="replace")
    (OUT / f"{label}-{second:03d}-meminfo.txt").write_text(mem, encoding="utf-8")
    (OUT / f"{label}-{second:03d}-thermal.txt").write_bytes(adb("shell", "dumpsys", "thermalservice"))
    (OUT / f"{label}-{second:03d}-window.txt").write_bytes(adb("shell", "dumpsys", "window"))
    match = re.search(r"Native Heap:\s*(\d+)", mem)
    native_kb = int(match.group(1)) if match else -1
    print(f"sample {second}s native_kb={native_kb}", flush=True)
    return native_kb


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("label")
    ap.add_argument("apk")
    args = ap.parse_args()
    label = args.label
    if b"isKeyguardShowing=true" in adb("shell", "dumpsys", "window"):
        raise RuntimeError("keyguard showing")
    print(adb("install", "-r", "--no-incremental", args.apk, timeout=300).decode(errors="replace").strip(), flush=True)
    adb("shell", "am", "force-stop", PKG)
    adb("logcat", "-c")
    adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
    start = time.monotonic()
    status = "completed"
    for second in [0, 10, 30, 55]:
        time.sleep(max(0, start + second - time.monotonic()))
        native_kb = sample(label, second)
        if native_kb > 2_000_000:
            status = f"aborted: native heap {native_kb} KB > 2,000,000 KB at {second}s"
            break
    if status == "completed":
        time.sleep(max(0, start + 72 - time.monotonic()))
        probe_name = f"studio-measure-{label}.json"
        p = subprocess.run([ADB, "exec-out", "run-as", PKG, "cat", f"files/{probe_name}"], capture_output=True)
        (OUT / f"{label}-probe-read.stdout").write_bytes(p.stdout)
        (OUT / f"{label}-probe-read.stderr").write_bytes(p.stderr)
        if p.returncode == 0 and p.stdout:
            result = json.loads(p.stdout)
            status = f"probe {result.get('seconds')}s"
        else:
            status = "probe missing"
    (OUT / f"{label}-logcat.txt").write_bytes(adb("logcat", "-d", "-v", "threadtime", timeout=120))
    (OUT / f"{label}-status.txt").write_text(status + "\n", encoding="utf-8")
    if status.startswith("aborted"):
        adb("shell", "am", "force-stop", PKG)
    print(status, flush=True)


if __name__ == "__main__":
    main()
