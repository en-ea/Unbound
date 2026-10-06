# Appends "-- <args>" to the command line Godot bakes into an APK (assets/_cl_), so a debug build
# runs dev arguments with no change to the project. Used by lab_args in android.sh, which then
# re-aligns and re-signs the APK. Format of _cl_: int32 count, then per item int32 length + UTF-8.
# Usage: python bake_args.py <apk> <arg>...
import os
import re
import struct
import sys
import zipfile

apk, args = sys.argv[1], sys.argv[2:]
tmp = apk + ".tmp"
with zipfile.ZipFile(apk) as zin, zipfile.ZipFile(tmp, "w") as zout:
    for info in zin.infolist():
        if re.match(r"META-INF/.*\.(SF|RSA|DSA|EC|MF)$", info.filename):
            continue  # the old signature; lab_sign makes a new one
        data = zin.read(info)
        if info.filename == "assets/_cl_":
            count, off, items = struct.unpack_from("<i", data, 0)[0], 4, []
            for _ in range(count):
                n = struct.unpack_from("<i", data, off)[0]
                items.append(data[off + 4:off + 4 + n].decode("utf-8"))
                off += 4 + n
            if "--" not in items:
                items.append("--")
            items += args
            data = struct.pack("<i", len(items)) + b"".join(
                struct.pack("<i", len(x.encode("utf-8"))) + x.encode("utf-8") for x in items)
            print("command line:", " ".join(items))
        zout.writestr(info, data)  # keeps each entry's compression
os.replace(tmp, apk)
