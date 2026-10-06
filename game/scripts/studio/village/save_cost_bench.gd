extends RefCounted
## Step-4 measurement on Hilmi's real saves (--owner-saves=a;b): what one checked acceptance costs and which
## people fields carry the weight. Prints BENCH lines only; no judgement, no writes.
const Codec := preload("res://scripts/studio/village/sim/save.gd")
static func report() -> PackedStringArray:
	var out := PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--owner-saves="):
			for path: String in arg.trim_prefix("--owner-saves=").split(";",false):_one(out,path)
	return out
static func _ms(started: int) -> float:
	return (Time.get_ticks_usec()-started)/1000.0
static func _one(out: PackedStringArray, path: String) -> void:
	var name := path.get_base_dir().get_file()
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var v=Codec.from_data(data.village)
	var t := {"encode":0.0,"encode_z":0.0,"decode":0.0,"stringify":0.0}
	for _i in 3:
		var s := Time.get_ticks_usec();var raw := Codec.to_data(v,false);t.encode+=_ms(s)
		s=Time.get_ticks_usec();Codec.from_data(raw);t.decode+=_ms(s)
		s=Time.get_ticks_usec();var packed := Codec.to_data(v,true);t.encode_z+=_ms(s)
		var whole: Dictionary=data.duplicate();whole.village=packed
		s=Time.get_ticks_usec();JSON.stringify(whole);t.stringify+=_ms(s)
	t.clone_native=0.0;t.save_warm=0.0;t.save_one_changed=0.0
	Codec.to_data(v,true)
	for i in 3:
		var s := Time.get_ticks_usec();var copy=Codec.clone(v);t.clone_native+=_ms(s)
		var whole: Dictionary=data.duplicate()
		s=Time.get_ticks_usec();whole.village=Codec.to_data(v,true);JSON.stringify(whole);t.save_warm+=_ms(s)
		copy.people[0].mind.known["bench:%d" % i]={"deed":"bench","via":"heard"}
		s=Time.get_ticks_usec();whole.village=Codec.to_data(copy,true);JSON.stringify(whole);t.save_one_changed+=_ms(s)
		Codec.to_data(v,true)
	for k: String in t:t[k]=snappedf(t[k]/3.0,0.01)
	out.append("BENCH %s old clone=%.1fms old save=%.1fms | new clone=%.1fms autosave(unchanged)=%.1fms save(one mind changed)=%.1fms detail=%s" % [name,t.encode+t.decode,t.encode_z+t.stringify,t.clone_native,t.save_warm,t.save_one_changed,JSON.stringify(t)])
	var sizes := {"known":0,"appraised":0,"episodes":0,"stances":0,"pending":0,"plan":0}
	var biggest := {}
	for p in v.people:
		var m=p.mind
		sizes.known+=JSON.stringify(m.known).length();sizes.appraised+=JSON.stringify(m.appraised).length()
		sizes.episodes+=JSON.stringify(m.episodes.map(func(e)->Dictionary:return e.account)).length() # stored copies (M3 leaves them empty)
		sizes.stances+=JSON.stringify(m.stances).length();sizes.pending+=JSON.stringify(m.pending).length();sizes.plan+=JSON.stringify(m.plan).length()
	for field: String in ["people_facts","people_notices","actor_minds","runtime","stagings"]:
		biggest[field]=JSON.stringify(v.get(field)).length() if v.get(field)!=null else 0
	var sample: Dictionary={}
	for p in v.people:
		for r: Dictionary in p.mind.appraised.values():
			if r.has("basis"):sample=r;break
		if not sample.is_empty():break
	var basis_len := JSON.stringify(sample.get("basis",{})).length()
	out.append("BENCH %s people_minds_chars=%s village_fields_chars=%s one_receipt_basis_chars=%d accounts=%d" % [name,JSON.stringify(sizes),JSON.stringify(biggest),basis_len,
		v.people.reduce(func(n: int,p)->int:return n+p.mind.known.size(),0)])
