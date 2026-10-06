extends RefCounted
## Which anti-aliasing a viewport may use on this device. Godot's Compatibility renderer on Android grows native
## memory every frame while a 3D viewport has MSAA (godotengine/godot#97967): measured on an S10 (Mali-G76) on
## 29 Sep at about 40 MB/s, and on the S24 Ultra (Adreno 750) on 1 Oct at 5 MB/s with the game standing still,
## 248 -> 1072 MB in 172 s with MSAA and flat at 216-223 MB without (toolbox/device-lab/phone_memory.sh). The owner's
## 22-minute session ended with Android killing the game at 7.8 GB. So no viewport gets MSAA there; every other
## device keeps what it asked for.
##
##   viewport.msaa_3d = RenderGate.msaa(Viewport.MSAA_2X)
##
## Dev argument --studio-aa=msaa|none forces one choice anywhere (look boards, memory runs).


## True where 3D MSAA leaks: Android on the Compatibility renderer.
static func msaa_leaks() -> bool:
	return OS.get_name() == "Android" and RenderingServer.get_current_rendering_method() == "gl_compatibility"


## The MSAA a viewport that wants `wanted` may have here.
static func msaa(wanted: Viewport.MSAA) -> Viewport.MSAA:
	match _forced():
		"msaa":
			return wanted
		"none":
			return Viewport.MSAA_DISABLED
	return Viewport.MSAA_DISABLED if msaa_leaks() else wanted


static func _forced() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--studio-aa="):
			return arg.trim_prefix("--studio-aa=")
	return ""
