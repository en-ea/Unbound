class_name SignLabel
extends RefCounted
## A painted-sign style name floating over a board (village projects, the For sale sign): a bolder,
## slightly spaced warm cream lettering with a dark wood-brown outline, instead of plain white text.


static func make(text: String, height := 2.3) -> Label3D:
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.7
	font.spacing_glyph = 3
	var l := Label3D.new()
	l.text = text.to_upper()
	l.font = font
	l.font_size = 40
	l.outline_size = 16
	l.pixel_size = 0.008
	l.modulate = Color(1.0, 0.9, 0.66)
	l.outline_modulate = Color(0.3, 0.17, 0.09, 0.95)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, height, 0)
	return l
