extends RefCounted
## Port of tools-src/studio/village-reference/rng.mjs.
## Keyed randomness for the village, the same hash chain as the world kernel: a draw is
## mix(...mix(mix(seed ^ C) ^ k1) ^ k2 ...), everything mod 2^32, integers only. A draw never depends on
## the order other draws were made in, so a change only spreads along real causes.
##
## Exactness: GDScript ints are 64-bit. Every value handed to mix is masked to 32 bits first (JS >>> 0),
## and no product may leave int64: 0x7feb352d is below 2^31, so (h ^ h>>16) * 0x7feb352d < 2^63; the second
## multiplier 0x846ca68b is split as 0x046ca68b + 2^31, and h * 2^31 mod 2^32 is (h & 1) << 31.

const M32 := 0xFFFFFFFF
const FNV := 2166136261


## Math.imul-based finaliser; h must already be in [0, 2^32).
static func mix(h: int) -> int:
	h = ((h ^ (h >> 16)) * 0x7feb352d) & M32
	h ^= h >> 15
	h = (h * 0x046ca68b + ((h & 1) << 31)) & M32
	return h ^ (h >> 16)


## key(h, k) = mix((h ^ k) >>> 0). k may be negative (-1 ids, opinions): the low 32 bits of the xor are
## the same as JS's ToInt32 xor.
static func key(h: int, k: int) -> int:
	h = (h ^ k) & M32
	h = ((h ^ (h >> 16)) * 0x7feb352d) & M32
	h ^= h >> 15
	h = (h * 0x046ca68b + ((h & 1) << 31)) & M32
	return h ^ (h >> 16)


## floor(d * 1e6 / 2^32): 0..999999. d < 2^32, so d * 1e6 < 2^52.
static func ppm(d: int) -> int:
	return (d * 1000000) >> 32


## floor(d * n / 2^32): 0..n-1. Every n used is a small count or a sum of small weights (d * n < 2^52).
static func pick(d: int, n: int) -> int:
	return (d * n) >> 32


## draw(h, a, b, c) = key(key(key(h, a), b), c).
static func draw(h: int, keys: Array) -> int:
	for k: int in keys:
		h = key(h, k)
	return h


static func chance(h: int, ppm_value: int) -> bool:
	return ((h * 1000000) >> 32) < ppm_value


## Stable hash of a string: FNV-1a over UTF-16 code units, then mixed. Every string hashed here is ASCII,
## so unicode_at gives the same units as charCodeAt.
static func str_key(s: String) -> int:
	var h := FNV
	for i in s.length():
		h = ((h ^ s.unicode_at(i)) * 16777619) & M32
	return mix(h)


# clamp(v, lo, hi): the port uses the built-in clampi, which is the same (v < lo ? lo : v > hi ? hi : v).


## Floor division (towards minus infinity, also for negative a), as Math.floor(a / b) in the reference.
## GDScript's int / truncates towards zero, so the quotient is corrected when the signs differ.
@warning_ignore("integer_division")
static func idiv(a: int, b: int) -> int:
	var q := a / b
	if q * b != a and ((a < 0) != (b < 0)):
		q -= 1
	return q
