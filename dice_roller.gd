class_name DiceRoller
extends RefCounted
# Parses standard TTRPG dice notation and rolls it.
#
# Supported formats:
#   "d20"        -> one d20
#   "1d20"       -> one d20
#   "2d6"        -> two d6, summed
#   "2d6+3"      -> two d6, +3 modifier
#   "1d20-1"     -> one d20, -1 modifier
#   "4d6kh3"     -> roll 4d6, keep highest 3 (common for stat generation)
#
# Returns a Dictionary: { "total": int, "rolls": Array[int], "modifier": int,
#                          "breakdown": String }

static var _rng := RandomNumberGenerator.new()

static func roll(formula: String) -> Dictionary:
	var clean := formula.strip_edges().to_lower().replace(" ", "")
	var regex := RegEx.new()
	# groups: count, sides, keep-highest count (optional), modifier (optional)
	regex.compile("^(\\d*)d(\\d+)(kh(\\d+))?([+-]\\d+)?$")
	var m := regex.search(clean)

	if m == null:
		return {"total": 0, "rolls": [], "modifier": 0, "breakdown": "Invalid formula: %s" % formula}

	var count := 1
	if m.get_string(1) != "":
		count = int(m.get_string(1))
	var sides := int(m.get_string(2))
	var keep_highest := 0
	if m.get_string(4) != "":
		keep_highest = int(m.get_string(4))
	var modifier := 0
	if m.get_string(5) != "":
		modifier = int(m.get_string(5))

	count = clamp(count, 1, 100)
	sides = clamp(sides, 1, 1000)

	_rng.randomize()
	var rolls: Array = []
	for i in range(count):
		rolls.append(_rng.randi_range(1, sides))

	var used_rolls := rolls.duplicate()
	if keep_highest > 0 and keep_highest < rolls.size():
		used_rolls.sort()
		used_rolls.reverse()
		used_rolls = used_rolls.slice(0, keep_highest)

	var sum := 0
	for r in used_rolls:
		sum += r
	var total := sum + modifier

	var breakdown := "[%s] = %s" % [", ".join(rolls.map(func(x): return str(x))), str(sum)]
	if keep_highest > 0:
		breakdown = "[%s] keep highest %d -> [%s] = %s" % [
			", ".join(rolls.map(func(x): return str(x))),
			keep_highest,
			", ".join(used_rolls.map(func(x): return str(x))),
			str(sum)
		]
	if modifier != 0:
		var sign := "+" if modifier > 0 else ""
		breakdown += " %s%d" % [sign, modifier]

	return {"total": total, "rolls": rolls, "modifier": modifier, "breakdown": breakdown}
