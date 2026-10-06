#!/usr/bin/env python3
"""Graphics S5: are two glb files the same model? Byte equality, else every primitive's triangles compared as sorted lists of their
corners' full attributes (position, normal, UVs: order-free), with the JSON structure equal."""
import json, struct, sys
def load(p):
    d = open(p, 'rb').read()
    jl = struct.unpack('<I', d[12:16])[0]
    return json.loads(d[20:20 + jl]), d[20 + jl + 8:], d
def read(j, b, i):
    acc = j['accessors'][i]; bv = j['bufferViews'][acc['bufferView']]
    o = bv.get('byteOffset', 0) + acc.get('byteOffset', 0)
    comp = {5126: 'f', 5123: 'H', 5125: 'I', 5121: 'B'}[acc['componentType']]
    n = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[acc['type']]
    vals = struct.unpack_from('<' + comp * (acc['count'] * n), b, o)
    return [vals[k*n:(k+1)*n] for k in range(acc['count'])]
def tris(j, b):
    out = []
    for m in j['meshes']:
        for p in m['primitives']:
            attrs = {k: read(j, b, v) for k, v in sorted(p['attributes'].items())}
            idx = [x[0] for x in read(j, b, p['indices'])]
            corner = lambda v: tuple(attrs[k][v] for k in attrs)
            t = sorted(tuple(sorted((corner(idx[k]), corner(idx[k+1]), corner(idx[k+2])))) for k in range(0, len(idx), 3))
            out.append((p.get('material'), t))
    return out
ja, ba, da = load(sys.argv[1]); jb, bb, db = load(sys.argv[2])
if da == db:
    print("SAME bytes"); sys.exit(0)
ta, tb = tris(ja, ba), tris(jb, bb)
same = len(ta) == len(tb) and all(x == y for x, y in zip(ta, tb))
print(("SAME model (" if same else "DIFFERENT model (") + "%d primitives, %d triangles; bytes differ only in order)" % (len(ta), sum(len(t) for _, t in ta)) if same else "DIFFERENT model")
sys.exit(0 if same else 1)
