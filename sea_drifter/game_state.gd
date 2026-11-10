extends Node
signal changed
var config: Dictionary
var hp: float
var max_hp: float
var bonus: int
var armor: int
var day: int
var knife: bool
# Six stable slots. Empty dictionaries are empty slots; stacks never shift on use.
var bag: Array[Dictionary] = []
var selected_slot = 0
var blueprint_claimed = false
var blueprint_pending = false

func _ready():
	config = JSON.parse_string(FileAccess.get_file_as_string("res://config.json"))
	reset()

func reset():
	hp = config.player.hp
	max_hp = hp
	bonus = 0
	armor = 0
	day = 1
	knife = false
	selected_slot = 0
	blueprint_claimed = false
	blueprint_pending = false
	bag.clear()
	for i in range(int(config.player.slots)): bag.append({})
	changed.emit()

func count_item(kind: String) -> int:
	var total = 0
	for slot in bag:
		if slot.get("kind", "") == kind: total += int(slot.count)
	return total

func used_slots() -> int:
	var total = 0
	for slot in bag:
		if not slot.is_empty(): total += 1
	return total

func add_item(kind: String, amount: int = 1) -> int:
	# Returns the unaccepted quantity. Existing stacks can receive items in a full bag.
	var remaining = amount
	for slot in bag:
		if slot.get("kind", "") == kind:
			var added = mini(remaining, int(config.player.stack_limit) - int(slot.count))
			slot.count += added
			remaining -= added
			if remaining == 0: break
	if remaining > 0:
		for i in range(bag.size()):
			if bag[i].is_empty():
				var added = mini(remaining, int(config.player.stack_limit))
				bag[i] = {"kind": kind, "count": added}
				remaining -= added
				if remaining == 0: break
	if kind == "blueprint" and remaining < amount:
		blueprint_claimed = true
		blueprint_pending = false
	if remaining < amount: changed.emit()
	return remaining

func remove_item(kind: String, amount: int) -> bool:
	if count_item(kind) < amount: return false
	var remaining = amount
	for i in range(bag.size()):
		if bag[i].get("kind", "") != kind: continue
		var removed = mini(remaining, int(bag[i].count))
		bag[i].count -= removed
		remaining -= removed
		if bag[i].count == 0: bag[i] = {}
		if remaining == 0: break
	return true

func defer_blueprint():
	if not blueprint_claimed and not knife:
		blueprint_pending = true
		fulfill_reward()

func fulfill_reward():
	if blueprint_pending and not blueprint_claimed and not knife: add_item("blueprint")

func consume(index: int) -> String:
	if index < 0 or index >= bag.size() or bag[index].is_empty(): return "此格为空"
	var item = str(bag[index].kind)
	if item == "blueprint": return "图纸是合成材料：按 N 手动制作小刀"
	bag[index].count -= 1
	if bag[index].count == 0: bag[index] = {}
	match item:
		"wood":
			max_hp = min(max_hp + config.resources.wood_hp, config.player.hp_cap)
			hp = min(hp + config.resources.wood_hp, max_hp)
		"plastic": bonus = mini(bonus + int(config.resources.plastic_attack), int(config.player.attack_cap))
		"stone": hp = min(hp + config.resources.stone_heal, max_hp)
	fulfill_reward()
	changed.emit()
	return "已使用 1 件物资"

func craft(board: bool) -> String:
	var cost = int(config.resources.craft_cost)
	if not board and knife: return "已经拥有小刀"
	if board and armor >= config.player.armor_cap: return "护甲已满"
	if not board and count_item("blueprint") < int(config.resources.knife_blueprints): return "需要小刀图纸：击败金边怪物获取"
	if count_item("wood") < cost: return "需要 %d 块木头" % cost
	# Validate the entire recipe before removing anything; failures cost no materials.
	remove_item("wood", cost)
	if board:
		max_hp = min(max_hp + config.resources.board_hp, config.player.hp_cap)
		armor = mini(armor + int(config.resources.board_armor), int(config.player.armor_cap))
	else:
		remove_item("blueprint", int(config.resources.knife_blueprints))
		knife = true
	fulfill_reward()
	changed.emit()
	return "已制作加固板" if board else "已制作小刀：K 挥刀"
