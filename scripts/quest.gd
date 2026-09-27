class_name Quest
extends RefCounted
## A quest is a pack of custom levels with a name, an author and a description.
## Installed quests live in user://quests/<id>.candyquest as JSON.
##
## Sharing:
##   * share code: one line of text ("CANDYQUEST1:" + base64 of gzipped JSON)
##     that fits in a chat message. Paste it in Quests > Paste code.
##   * .candyquest file: the plain JSON. Drop it on the game window, pick it
##     with Quests > Open file, or copy it into the quest folder.

const FORMAT := "candy-quest"
const VERSION := 1
const DIR := "user://quests"
const EXT := "candyquest"
const CODE_PREFIX := "CANDYQUEST1:"
const MAX_LEVELS := 50
const MAX_FILE := 4 * 1024 * 1024

var id := ""
var name := "My quest"
var author := ""
var description := ""
var levels: Array = []  # CustomLevel dictionaries
var created := 0
var updated := 0


static func create(quest_name: String = "My quest") -> Quest:
	var q := Quest.new()
	q.id = new_id()
	q.name = quest_name
	q.created = int(Time.get_unix_time_from_system())
	q.updated = q.created
	q.levels = [CustomLevel.blank("Level 1")]
	return q


static func new_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "q%08x%04x" % [int(Time.get_unix_time_from_system()) & 0xffffffff, rng.randi() & 0xffff]


func to_dict() -> Dictionary:
	return {
		format = FORMAT, version = VERSION, id = id, name = name, author = author,
		description = description, created = created, updated = updated, levels = levels,
	}


## Quest from untrusted data, or null if it isn't one.
static func from_dict(d: Variant) -> Quest:
	if not d is Dictionary or not d.get("format") is String or d.format != FORMAT:
		return null
	var q := Quest.new()
	var raw_id: String = str(d.get("id", ""))
	var clean_id := ""
	for ch in raw_id.substr(0, 32):
		if ch in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			clean_id += ch
	q.id = clean_id if clean_id.length() >= 4 else new_id()
	q.name = CustomLevel._text(d.get("name"), "Untitled quest", 48)
	q.author = CustomLevel._text(d.get("author"), "", 40)
	q.description = CustomLevel._text(d.get("description"), "", 600)
	q.created = int(CustomLevel._num(d.get("created"), 0))
	q.updated = int(CustomLevel._num(d.get("updated"), 0))
	var src: Array = d.get("levels") if d.get("levels") is Array else []
	for l: Variant in src.slice(0, MAX_LEVELS):
		q.levels.append(CustomLevel.sanitize(l))
	if q.levels.is_empty():
		return null
	return q


func duplicate_quest() -> Quest:
	var q := Quest.from_dict(JSON.parse_string(JSON.stringify(to_dict())))
	return q


func make_level(index: int) -> CustomLevel:
	return CustomLevel.from_dict(levels[clampi(index, 0, levels.size() - 1)])


# --- files --------------------------------------------------------------------

func path() -> String:
	return "%s/%s.%s" % [DIR, id, EXT]


func to_json() -> String:
	return JSON.stringify(to_dict(), "\t")


func save() -> Error:
	DirAccess.make_dir_recursive_absolute(DIR)
	updated = int(Time.get_unix_time_from_system())
	return write_to(path())


func write_to(file_path: String) -> Error:
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(to_json())
	f.close()
	return OK


func delete() -> void:
	DirAccess.remove_absolute(path())


static func load_file(file_path: String) -> Quest:
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null or f.get_length() > MAX_FILE:
		return null
	var text := f.get_as_text()
	f.close()
	if text.strip_edges().begins_with(CODE_PREFIX):
		return from_share_code(text)
	return from_dict(JSON.parse_string(text))


## Every installed quest, newest first.
static func list_installed() -> Array[Quest]:
	var out: Array[Quest] = []
	DirAccess.make_dir_recursive_absolute(DIR)
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	var seen := {}
	for f in dir.get_files():
		if not (f.ends_with("." + EXT) or f.ends_with(".json")):
			continue
		var q := load_file(DIR + "/" + f)
		if q == null:
			continue
		# A file copied into the folder by hand: store it under its id.
		if f != q.id + "." + EXT:
			if FileAccess.file_exists(q.path()):
				var existing := load_file(q.path())
				if existing and existing.updated >= q.updated:
					dir.remove(f)
					continue
			q.write_to(q.path())
			dir.remove(f)
		if seen.has(q.id):
			continue
		seen[q.id] = true
		out.append(q)
	out.sort_custom(func(a: Quest, b: Quest) -> bool: return a.updated > b.updated)
	return out


static func find(quest_id: String) -> Quest:
	for q in list_installed():
		if q.id == quest_id:
			return q
	return null


## Installs a quest (replacing an older copy with the same id). Returns the
## installed quest.
static func install(q: Quest) -> Quest:
	DirAccess.make_dir_recursive_absolute(DIR)
	q.write_to(q.path())
	return q


static func install_file(file_path: String) -> Quest:
	var q := load_file(file_path)
	return install(q) if q else null


## Sample quests shipped with the game, installed once (deleting them sticks).
const SAMPLES := ["res://quests/sweet_starter.json"]


static func install_samples() -> void:
	var marker := DIR + "/.samples_1"
	if FileAccess.file_exists(marker):
		return
	for p: String in SAMPLES:
		var q := load_file(p)
		if q:
			install(q)
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(marker, FileAccess.WRITE)
	if f:
		f.store_string("1")


static func folder() -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	return ProjectSettings.globalize_path(DIR)


# --- share codes ----------------------------------------------------------------

func share_code() -> String:
	var raw := JSON.stringify(to_dict()).to_utf8_buffer()
	var packed := raw.compress(FileAccess.COMPRESSION_GZIP)
	return CODE_PREFIX + str(raw.size()) + ":" + Marshalls.raw_to_base64(packed)


static func from_share_code(text: String) -> Quest:
	var t := text.strip_edges()
	var at := t.find(CODE_PREFIX)
	if at < 0:
		return null
	t = t.substr(at + CODE_PREFIX.length())
	var colon := t.find(":")
	if colon < 1:
		return null
	var size := t.substr(0, colon).to_int()
	if size <= 0 or size > MAX_FILE:
		return null
	# Codes pasted from chat apps may be wrapped over several lines.
	var b64 := ""
	for ch in t.substr(colon + 1):
		if ch not in " \n\r\t":
			b64 += ch
	if b64.length() % 4 != 0 or not RegEx.create_from_string("^[A-Za-z0-9+/]+=*$").search(b64):
		return null
	var packed := Marshalls.base64_to_raw(b64)
	if packed.is_empty():
		return null
	var raw := packed.decompress(size, FileAccess.COMPRESSION_GZIP)
	if raw.size() != size:
		return null
	return from_dict(JSON.parse_string(raw.get_string_from_utf8()))


## Safe file name for exports.
func file_name() -> String:
	var s := ""
	for ch in name.to_lower():
		s += ch if ch in "abcdefghijklmnopqrstuvwxyz0123456789" else "_"
	while s.contains("__"):
		s = s.replace("__", "_")
	s = s.strip_edges().trim_prefix("_").trim_suffix("_")
	return (s if s != "" else "quest") + "." + EXT
