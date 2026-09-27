class_name CandyText
## Text in the style of the Candy Marble logo: chunky Fredoka letters in candy
## pastels, a cream outline and a chocolate edge underneath.

const FONT_BOLD := preload("res://fonts/fredoka_bold.tres")
const FONT := preload("res://fonts/fredoka_semibold.tres")
const CHOCOLATE := Color("#5A3426")
const CREAM := Color("#FFF4E0")
## Letter colours taken from the logo.
const PASTELS := [
	Color("#F4829F"), Color("#8EDDB6"), Color("#F7D66B"), Color("#B99BEA"), Color("#8CC9F0"),
]


## Styles a Label or RichTextLabel. `fill` is the letter colour.
static func style(c: Control, size: int, fill: Color = CHOCOLATE, bold: bool = true) -> void:
	var f := FONT_BOLD if bold else FONT
	var outline := clampi(size / 6, 3, 12)
	var edge := clampi(size / 10, 2, 8)
	if c is RichTextLabel:
		c.add_theme_font_override("normal_font", f)
		c.add_theme_font_size_override("normal_font_size", size)
		c.add_theme_color_override("default_color", fill)
	else:
		c.add_theme_font_override("font", f)
		c.add_theme_font_size_override("font_size", size)
		c.add_theme_color_override("font_color", fill)
	c.add_theme_color_override("font_outline_color", CREAM)
	c.add_theme_constant_override("outline_size", outline)
	c.add_theme_color_override("font_shadow_color", CHOCOLATE)
	c.add_theme_constant_override("shadow_outline_size", outline + edge)
	c.add_theme_constant_override("shadow_offset_x", 0)
	c.add_theme_constant_override("shadow_offset_y", clampi(size / 16, 1, 5))


## BBCode that colours each letter in turn with the logo pastels.
static func rainbow(text: String, start: int = 0) -> String:
	var out := ""
	var k := start
	for ch in text:
		if ch == " " or ch == "\n":
			out += ch
			continue
		out += "[color=#%s]%s[/color]" % [PASTELS[k % PASTELS.size()].to_html(false), ch]
		k += 1
	return out


## Styles a Label3D pop-up.
static func style_3d(l: Label3D, fill: Color) -> void:
	l.font = FONT_BOLD
	l.modulate = fill
	l.outline_modulate = CHOCOLATE
	l.outline_size = 22
