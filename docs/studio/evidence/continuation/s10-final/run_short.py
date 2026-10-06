"""Finite Android crowd, conformance and normal-check gates on the Continuation package."""
import argparse
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


def capture(label, phase):
    prefix = f"{label}-{phase}"
    (OUT / f"{prefix}-thermal.txt").write_bytes(adb("shell", "dumpsys", "thermalservice"))
    (OUT / f"{prefix}-meminfo.txt").write_bytes(adb("shell", "dumpsys", "meminfo", PKG))
    (OUT / f"{prefix}-window.txt").write_bytes(adb("shell", "dumpsys", "window"))
    (OUT / f"{prefix}.png").write_bytes(adb("exec-out", "screencap", "-p"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("label")
    ap.add_argument("apk")
    ap.add_argument("kind", choices=["crowd", "conformance", "checks"])
    args = ap.parse_args()
    if b"isKeyguardShowing=true" in adb("shell", "dumpsys", "window"):
        raise RuntimeError("keyguard showing")
    print(adb("install", "-r", "--no-incremental", args.apk, timeout=300).decode(errors="replace").strip(), flush=True)
    adb("shell", "am", "force-stop", PKG)
    adb("logcat", "-c")
    adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
    started = time.monotonic()
    capture(args.label, "start")
    target = {"crowd": 100, "conformance": 360, "checks": 180}[args.kind]
    marker = {"crowd": "STUDIO device:", "conformance": "VILLAGE STORMS: PASS", "checks": "CHECKS complete failures="}[args.kind]
    midpoint = False
    while time.monotonic() - started < target:
        elapsed = time.monotonic() - started
        if not midpoint and elapsed >= (28 if args.kind == "crowd" else 15):
            capture(args.label, "mid")
            midpoint = True
            print(f"midpoint {elapsed:.1f}s", flush=True)
        logs = adb("logcat", "-d", "-s", "godot:I", timeout=60).decode(errors="replace")
        if marker in logs:
            break
        time.sleep(5)
    elapsed = time.monotonic() - started
    capture(args.label, "end")
    logs = adb("logcat", "-d", "-v", "threadtime", timeout=120).decode(errors="replace")
    (OUT / f"{args.label}-logcat.txt").write_text(logs, encoding="utf-8")
    if args.kind == "crowd":
        path = "studio-village-crowd_bench.txt"
        text = adb("exec-out", "run-as", PKG, "cat", f"files/{path}").decode(errors="replace")
        ok = all(f"{count} walking villagers" in text for count in [0, 30, 45])
    elif args.kind == "conformance":
        path = "studio-village-conformance.txt"
        text = adb("exec-out", "run-as", PKG, "cat", f"files/{path}").decode(errors="replace")
        ok = all(s in text for s in ["CONFORMANCE: PASS", "LIVE: PASS", "STORMS: PASS"])
    else:
        text = "\n".join(line for line in logs.splitlines() if "godot" in line and ("CHECKS" in line or "PASS " in line or "FAIL " in line or "SCRIPT ERROR" in line))
        ok = "CHECKS complete failures=0" in text and "FAIL " not in text and "SCRIPT ERROR" not in text
    (OUT / f"{args.label}-result.txt").write_text(text, encoding="utf-8")
    (OUT / f"{args.label}-status.txt").write_text(f"ok={ok} elapsed_s={elapsed:.3f}\n", encoding="utf-8")
    print(f"ok={ok} elapsed_s={elapsed:.3f}", flush=True)
    if not ok:
        raise RuntimeError(f"{args.kind} failed or timed out; inspect {args.label}-result.txt")


if __name__ == "__main__":
    main()
