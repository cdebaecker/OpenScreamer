## Beast City places: the weapon shop, the FRD office, the doctor, the bar; talking
## and giving (also used in BIAS).
class_name Shops
extends Mod

## the person picked in the bar (the original's), the one talked to () and the one
## given something ()
var _person := 0
var _talk_person := 0
var _give_person := 0
## what a sold item fetches ()
var _sell_price := 0
var _vars_ready := false


func _init_vars() -> void:
	if _vars_ready:
		return
	_vars_ready = true
	_person = int(data.table("shops_init_person")[0])
	_give_person = int(data.table("shops_init_give_person")[0])
	var v: Array = data.table("shops_init_vars")
	_sell_price = int(v[0]) | (int(v[1]) << 8)
	_talk_person = int(v[0x0e])


func _choose(nav: String, pos: String) -> int:
	return await ui.choose(data.table(nav), Ui.positions(data.table(pos)))


## leave for the town menu
func _to_town() -> void:
	sys.jump(&"town_menu")


func _npc_wait(s: String) -> void:
	await common.npc(s)
	if sys.unwinding: return
	await ui.wait_space()


# ------------------------------------------------------------------ weapon shop

func weapon_shop() -> void:
	_init_vars()
	common.show_picture(6)
	items.set(&"show_prices", 0xff)
	st.hide_hunter = 0xff
	ui.menu_reset(4)
	screen.clear_window(Screen.MENU)
	common.say(5, 3, data.msg(&"shop.01"))
	await common.npc(data.msg(&"shop.02"))
	if sys.unwinding: return
	while true:
		var sel: int = await ui.menu_choose()
		if sys.unwinding: return
		match sel:
			1:
				await _buy()
			2:
				await _sell()
			3:
				await items.look_items()
			4:
				_to_town()
				return
		if sys.unwinding: return


func _buy() -> void:
	var c := st.chr
	while true:
		items.set(&"show_prices", 0xff)
		screen.clear_window(Screen.MESSAGE)
		if c.inv_full != 0:
			await _npc_wait(data.msg(&"shop.03"))
			if sys.unwinding: return
			break
		txt.set_number(c.credits, 0)
		await common.npc(data.msg(&"shop.04"))
		if sys.unwinding: return
		var p: Dictionary = await items.pick_item(1)
		if sys.unwinding: return
		var item: int = p["item"]
		if not item:
			break
		if c.credits < chara.item_price(item):
			await _npc_wait(data.msg(&"shop.05"))
			if sys.unwinding: return
			break
		await common.npc(data.msg(&"shop.06"))
		if sys.unwinding: return
		txt.at(0x22, 0x13, 0x22)
		txt.puts(data.msg(&"shop.07"))
		var yes: int = await _choose("shops_buy_nav", "shops_buy_pos")
		if sys.unwinding: return
		if yes == 2:
			break
		var price := chara.item_price(item)
		if c.credits < price:
			await _npc_wait(data.msg(&"shop.05"))
			if sys.unwinding: return
			break
		c.credits -= price
		c.inv_add(item)
		await _npc_wait(data.msg(&"shop.08"))
		if sys.unwinding: return
		await common.npc(data.msg(&"shop.09"))
		if sys.unwinding: return
		txt.at(0x22, 0x13, 0x22)
		txt.puts(data.msg(&"shop.10"))
		var more: int = await _choose("shops_buy_nav", "shops_buy_pos")
		if sys.unwinding: return
		if more != 1:
			break
	screen.clear_window(Screen.MESSAGE)


func _sell() -> void:
	var c := st.chr
	if c.inv_count() == 0:
		await _npc_wait(data.msg(&"shop.11"))
		return
	await common.npc(data.msg(&"shop.12"))
	if sys.unwinding: return
	items.set(&"show_prices", 0xff)
	var p: Dictionary = await items.pick_item(0)
	if sys.unwinding: return
	var item: int = p["item"]
	if item:
		var half := chara.item_price(item) >> 1
		_sell_price = half
		txt.set_number(half, 0)
		await common.npc(data.msg(&"shop.13"))
		if sys.unwinding: return
		var yes: bool = await ui.yes_no()
		if sys.unwinding: return
		if yes:
			# (original: credits wrap at 65535; an equipped FRD (bit 7 set) doesn't count as the
			# FRD, so its points stay; sold armour still counts in AC)
			c.credits = mini(c.credits + _sell_price, 0xffff) if sys.fix_bugs else c.credits + _sell_price
			c.inv_remove(p["index"])
			if (item & (0x7f if sys.fix_bugs else 0xff)) == 0x52:
				_frd_lost()
			if sys.fix_bugs and item & Character.EQUIPPED:
				chara.recalc_ac()
			await _npc_wait(data.msg(&"shop.08"))
			if sys.unwinding: return
	screen.clear_window(Screen.MESSAGE)


## without the FRD the unclaimed beast points are lost
func _frd_lost() -> void:
	st.chr.bp = 0
	st.chr.bp_total = 0
	chara.status_panel()


# ------------------------------------------------------------------ the FRD office

func frd_shop() -> void:
	_init_vars()
	common.show_picture(4)
	await common.npc(data.msg(&"shop.14"))
	if sys.unwinding: return
	ui.menu_reset(4)
	screen.clear_window(Screen.MENU)
	common.say(5, 3, data.msg(&"shop.15"))
	while true:
		var sel: int = await ui.menu_choose()
		if sys.unwinding: return
		match sel:
			1:
				await _show_frd()
			2:
				await _get_frd()
			3:
				await chara.show_abilities()
			4:
				_to_town()
				return
		if sys.unwinding: return


func _show_frd() -> void:
	var c := st.chr
	if chara.has_item(0x52) < 0:
		await _npc_wait(data.msg(&"shop.16"))
		return
	if c.bp == 0:
		await _npc_wait(data.msg(&"shop.17"))
		return
	await common.npc(data.msg(&"shop.18"))
	if sys.unwinding: return
	txt.set_number(c.bp, 0)
	txt.col = 0x1b
	txt.row = 0x16
	txt.puts(data.msg(&"shop.19"))
	var bp := c.bp
	if sys.fix_bugs:  # the original's words wrap at 65535 (a rich screamer's credits go back to ~0)
		c.bp_total = mini(c.bp_total + bp, 0xffff)
		c.credits = mini(c.credits + bp, 0xffff)
	else:
		c.bp_total += bp
		c.credits += bp
	c.bp = 0
	chara.status_panel()
	await ui.wait_space()
	if sys.unwinding: return
	if c.hc == 0x19:
		await _master_class()
		return
	var left: int = await _class_check()
	if sys.unwinding: return
	if sys.fix_bugs and c.hc == 0x19:  # just made master: the original shows a count to a class
		await _master_class()  # that doesn't exist, and the memento only on a later visit
		return
	txt.set_number(left, 0)
	await _npc_wait(data.msg(&"shop.20"))


## raise the hunter class while the earned BP exceed the table; returns BP still needed
func _class_check() -> int:
	var c := st.chr
	var table: Array = data.table("shops_class_bp")
	while true:
		var need := int(table[c.hc])
		var left := need - c.bp_total
		# (the original classes up only past the table's value: exactly on it, "0 points to go")
		if left > 0 or (left == 0 and not sys.fix_bugs):
			return left
		await common.npc(data.msg(&"shop.21"))
		if sys.unwinding: return 0
		c.hc += 1
		var hp := c.hp_max + 10
		if hp >= 0xfb:
			hp = 0xff
		c.hp_max = hp
		for s in [&"agl_max", &"pow_max", &"tec_max", &"iq_max"]:
			c.set(s, mini(int(c.get(s)) + 10, 0xfa))
		await ui.wait_space()
		if sys.unwinding: return 0
		chara.status_panel()
	return 0


func _master_class() -> void:
	await _npc_wait(data.msg(&"shop.22"))
	if sys.unwinding: return
	if chara.has_item(0x4a) >= 0:
		return
	if st.chr.inv_full != 0:
		await _npc_wait(data.msg(&"shop.23"))
		return
	st.chr.inv_add(0x4a)
	await _npc_wait(data.msg(&"shop.24"))


func _get_frd() -> void:
	if chara.has_item(0x52) >= 0:
		await _npc_wait(data.msg(&"shop.25"))
		return
	if st.chr.inv_full != 0:
		await _npc_wait(data.msg(&"shop.26"))
		return
	st.chr.inv_add(0x52)
	await _npc_wait(data.msg(&"shop.27"))
	if sys.unwinding: return
	await _npc_wait(data.msg(&"shop.28"))


# ------------------------------------------------------------------ the doctor

## the stat being treated: its number for adjust_stat, its name in the character record, its label
var _treat_stat := 0
var _treat_field := &"hp"
var _treat_label := ""


func hospital() -> void:
	_init_vars()
	common.show_picture(5)
	await common.npc(data.msg(&"shop.29"))
	if sys.unwinding: return
	ui.menu_reset(8)
	screen.clear_window(Screen.MENU)
	common.say(5, 3, data.msg(&"shop.30"))
	var labels: Array = data.table("shops_treat_labels")  # HP, Agl, Pow, IQ, Tec
	while true:
		var sel: int = await ui.menu_choose()
		if sys.unwinding: return
		match sel:
			1:
				await _treat(0, labels[0], &"hp")
			2:
				await _treat(1, labels[1], &"agl")
			3:
				await _treat(2, labels[2], &"pow")
			4:
				await _treat(4, labels[3], &"iq")
			5:
				await _treat(3, labels[4], &"tec")
			6:
				await _antidote()
			7:
				await chara.show_abilities()
			8:
				_to_town()
				return
		if sys.unwinding: return


func _show_credits() -> void:
	txt.col = 0x27
	txt.row = 0x17
	txt.set_number(st.chr.credits, 0)
	txt.puts(data.msg(&"shop.31"))


func _show_treated_stat() -> void:
	txt.col = 0x13
	txt.row = 0x17
	txt.set_number(int(st.chr.get(_treat_field)), 0)
	txt.puts(_treat_label)


func _pay_wrong() -> void:
	await _npc_wait(data.msg(&"shop.32"))


## 1 point for 5 credits
func _treat(stat: int, label: String, field: StringName) -> void:
	_treat_stat = stat
	_treat_label = label
	_treat_field = field
	await common.npc(data.msg(&"shop.33"))
	if sys.unwinding: return
	# (the original falls through a few stray data bytes here that AND random memory; skipped)
	_show_credits()
	_show_treated_stat()
	txt.col = 0x1b
	txt.row = 0x14
	await ui.line_input()
	if sys.unwinding: return
	var paid := Ui.parse_number(ui.input)
	if paid < 5:
		await _pay_wrong()
		return
	if sys.fix_bugs:  # the original takes it all and gives a point for the odd 1..4 credits too
		paid -= paid % 5
	var after := st.chr.credits - paid
	if after < 0:
		await _pay_wrong()
		return
	after &= 0xffff
	var left := paid
	while true:
		txt.kana_mode = 0xff
		chara.adjust_stat(_treat_stat, 1)
		if sys.unwinding: return
		_show_treated_stat()
		await common.wait(0x1388)
		st.chr.credits -= 5
		left -= 5
		if left <= 0:
			break
		_show_credits()
	st.chr.credits = after
	txt.kana_mode = 0xff
	await common.npc(data.msg(&"shop.34"))
	if sys.unwinding: return
	chara.status_panel()


func _antidote() -> void:
	var c := st.chr
	if c.poison == 0:
		await _npc_wait(data.msg(&"shop.35"))
		return
	await common.npc(data.msg(&"shop.36"))
	if sys.unwinding: return
	txt.at(0x25, 0x14, 0x25)
	txt.puts(data.msg(&"shop.37"))
	txt.col = 0x14
	txt.row = 0x17
	txt.set_number(c.credits, 0)
	txt.puts(data.msg(&"shop.31"))
	# the price depends on how many poisons you carry
	var n := 0
	for bit in [1, 2, 4, 8, 0x10]:
		if c.poison & bit:
			n += 1
	var price := int(data.table("shops_antidote_prices")[n])
	txt.num_hi = 0
	txt.num_lo = price
	txt.col = 0x2b
	txt.row = 0x17
	txt.puts(data.msg(&"shop.38"))
	var yes: int = await _choose("shops_antidote_nav", "shops_antidote_pos")
	if sys.unwinding: return
	if yes != 1:
		await _npc_wait(data.msg(&"shop.39"))
		return
	var after := c.credits - price
	if after < 0:
		await _pay_wrong()
		return
	c.credits = after
	c.poison = 0
	txt.col = 0xff
	await _npc_wait(data.msg(&"shop.34"))


# ------------------------------------------------------------------ the bar

## the bar (flow target "bar")
func bar() -> void:
	_init_vars()
	common.monster_dest = 0x83c
	common.show_picture(7)
	await common.npc(data.msg(&"shop.40"))
	if sys.unwinding: return
	while true:
		ui.menu_reset(3)
		screen.clear_window(Screen.MENU)
		common.say(5, 3, data.msg(&"shop.41"))
		var seated := false
		while not seated:
			var sel: int = await ui.menu_choose()
			if sys.unwinding: return
			match sel:
				1:
					seated = await _drink()
				2:
					await chara.show_abilities()
				3:
					_to_town()
					return
			if sys.unwinding: return
		# leave the seat
		common.show_picture(7)
		await common.npc(data.msg(&"shop.42"))
		if sys.unwinding: return


## pay 50 credits and sit down; returns when the player leaves the seat
func _drink() -> bool:
	if st.chr.credits < 0x32:
		await _npc_wait(data.msg(&"shop.43"))
		if sys.unwinding: return false
		_to_town()
		return false
	st.chr.credits -= 0x32
	ui.menu_reset(4)
	screen.clear_window(Screen.MENU)
	common.say(5, 3, data.msg(&"shop.44"))
	await common.npc(data.msg(&"shop.45"))
	if sys.unwinding: return false
	while true:
		common.show_picture(8)
		var sel: int = await ui.menu_choose()
		if sys.unwinding: return false
		match sel:
			1:
				await talk()
			2:
				await give()
			3:
				await chara.show_abilities()
			4:
				return true
		if sys.unwinding: return false
	return true


# ------------------------------------------------------------------ talking and giving

## pick one of the screamers in the bar; 0 = nobody
func _pick_person() -> int:
	txt.at(0x1d, 0x13, 0x1d)
	txt.puts(data.msg(&"shop.46"))
	var r: int = await _choose("shops_person_nav", "shops_person_pos")
	if sys.unwinding: return 0
	_person = r
	screen.clear_window(Screen.MESSAGE)
	if r == 8:
		return 0
	screen.clear_window(Screen.VIEW)
	common.show_monster(r + 0x33)
	return r


## the person spoken to: picked in the bar, or the hunter met in BIAS; kept in `store`
func _whom(prompt: String, store: StringName) -> bool:
	if st.game_mode == 2:
		screen.clear_window(Screen.MESSAGE)
		common.say(0x12, 0x11, prompt)
		var p: int = await _pick_person()
		if sys.unwinding: return false
		if not p:
			return false
		set(store, p)
	if st.game_mode == 3:
		if st.hunter == 0:
			screen.clear_window(Screen.MESSAGE)
			common.say(0x12, 0x11, data.msg(&"shop.47"))
			await ui.wait_space()
			return false
		set(store, st.hunter)
	return true


func talk() -> void:
	_init_vars()
	var ok: bool = await _whom(data.msg(&"shop.48"), &"_talk_person")
	if sys.unwinding or not ok: return
	screen.clear_window(Screen.MESSAGE)
	common.say(0x12, 0x11, data.msg(&"shop.49"))
	await ui.line_input()
	if sys.unwinding: return
	var typed := _english_keyword(ui.input)
	if _talk_person == 7 and typed == data.table("shops_password"):
		common.show_picture(0x0e)
		screen.clear_window(Screen.MESSAGE)
		txt.at(0x13, 0x11, 0x13)
		txt.puts("_")
		txt.puts(data.msg(&"shop.50"))
		await common.wait(0xc350)
		screen.clear_window(Screen.MESSAGE)
		return
	# drop the spaces, then look the word up in the conversation table
	typed = typed.replace(" ", "")
	ui.input_buf = _strip_spaces(ui.input_buf)
	var entry: Dictionary = {}
	for e: Dictionary in data.talk:
		if e["keyword"] == typed:
			entry = e
			break
	if entry.is_empty():
		screen.clear_window(Screen.MESSAGE)
		common.say(0x12, 0x11, data.msg(&"shop.51"))
		await ui.wait_space()
		return
	if (st.chr.iq & 0xff) < int(entry["iq"]):
		screen.clear_window(Screen.MESSAGE)
		common.say(0x12, 0x11, data.msg(&"shop.52"))
		await ui.wait_space()
		return
	var replies: Array = entry["replies"]
	var al := (replies.size() - 1) & 0xff
	if al != 0:
		al = rng.random(al)
	screen.clear_window(Screen.MESSAGE)
	txt.at(0x13, 0x11, 0x13)
	txt.kana_mode = 0xff
	txt.puts(replies[al])
	sys.journal(&"talk", ui.input.strip_edges(), replies[al])  # (what was asked, as typed)
	await ui.wait_space()


## in a translation, a typed word stands for the katakana keyword (or the password) the original
## expects (it replaces the typed text in the input buffer too)
func _english_keyword(typed: String) -> String:
	var kw := data.keyword_for(typed)
	if kw.is_empty():
		return typed
	var b := GameText.encode(kw)
	var buf := ui.input_buf
	for i in mini(b.size() + 1, buf.size()):
		buf[i] = b[i] if i < b.size() else 0
	ui.input_buf = buf
	return kw


## the spaces go, the rest moves down in place: bytes after the end are left as they were
static func _strip_spaces(buf: PackedByteArray) -> PackedByteArray:
	var d := 0
	for i in buf.size():
		var c := buf[i]
		if c == 0x20:
			continue
		buf[d] = c
		d += 1
		if c == 0:
			break
	return buf


func give() -> void:
	_init_vars()
	var ok: bool = await _whom(data.msg(&"shop.53"), &"_give_person")
	if sys.unwinding or not ok: return
	screen.clear_window(Screen.MESSAGE)
	common.say(0x12, 0x11, data.msg(&"shop.54"))
	var what: int = await _choose("shops_give_nav", "shops_give_pos")
	if sys.unwinding: return
	if what == 1:
		await _give_gold()
	else:
		await _give_item()


# The answers to gifts: per person, two zero-terminated entries, walked byte by byte like the
# original (an entry starts with a number: the gold that pleases, or the item wanted and the
# item given back).

## the entry of the person given something
func _person_entry(tab: Array) -> int:
	return _skip(tab, 0, (_give_person * 2) & 0xffff)


static func _skip(tab: Array, i: int, count: int) -> int:
	for n in count:
		while int(tab[i]) != 0:
			i += 1
		i += 1
	return i


static func _cstr(tab: Array, i: int) -> String:
	var b := PackedByteArray()
	while int(tab[i]) != 0:
		b.append(int(tab[i]))
		i += 1
	return GameText.decode(b)


func _give_gold() -> void:
	var amount := -1
	while amount < 0:
		screen.clear_window(Screen.MESSAGE)
		common.say(0x12, 0x11, data.msg(&"shop.55"))
		await ui.line_input()
		if sys.unwinding: return
		amount = Ui.parse_number(ui.input)
	if amount == 0:
		screen.clear_window(Screen.MESSAGE)
		common.say(0x12, 0x11, data.msg(&"shop.56"))
		await ui.wait_space()
		return
	if st.chr.credits < amount:
		screen.clear_window(Screen.MESSAGE)
		common.say(0x12, 0x11, data.msg(&"shop.57"))
		await ui.wait_space()
		return
	st.chr.credits -= amount
	var tab: Array = data.table("shops_give_gold")
	var di := _person_entry(tab)
	if amount >= (int(tab[di]) | (int(tab[di + 1]) << 8)):
		di += 2
	else:
		di = _skip(tab, di, 1)
	screen.clear_window(Screen.MESSAGE)
	txt.at(0x13, 0x11, 0x13)
	txt.kana_mode = 0xff
	txt.puts(_cstr(tab, di))
	await ui.wait_space()


func _give_item() -> void:
	var c := st.chr
	screen.clear_window(Screen.MESSAGE)
	if c.inv_count() == 0:
		common.say(0x12, 0x11, data.msg(&"shop.58"))
		await ui.wait_space()
		return
	common.say(0x12, 0x11, data.msg(&"shop.59"))
	var p: Dictionary = await items.pick_item(0)
	if sys.unwinding: return
	var item: int = p["item"]
	if not item:
		return
	c.inv_remove(p["index"])
	if (item & 0x7f) == 0x52:
		_frd_lost()
	if sys.fix_bugs and item & Character.EQUIPPED:
		chara.recalc_ac()  # (the original keeps counting given-away armour)
	# the screamers met in BIAS want the pendants (the chain that ends with the samurai's blade);
	# the original picks their table only in mode 4, combat, where there's no "give", so the
	# chain never works and the Samurai Blade, needed for the last doors, can't be had
	var bias := 3 if sys.fix_bugs or sys.pendant_fix else 4
	var tab: Array = data.table("shops_give_item_combat" if st.game_mode == bias else "shops_give_item")
	var di := _person_entry(tab)
	# (the original compares the item with its "equipped" bit: an equipped one is never wanted)
	if int(tab[di]) == (item & 0x7f if sys.fix_bugs else item):
		if c.inv_full != 0:
			screen.clear_window(Screen.MESSAGE)
			common.say(0x12, 0x11, data.msg(&"shop.60"))
			await ui.wait_space()
			return
		di += 1
		var reward := int(tab[di])
		c.inv_add(reward)
		sys.journal(&"gift", chara.item_name(reward), _cstr(tab, di + 1))
		di += 1
		txt.at(0x13, 0x11, 0x13)
		txt.puts(_cstr(tab, di))
		txt.puts("~          ")
		txt.puts(_item_cstr(reward))
		txt.puts(data.msg(&"shop.62"))
		await ui.wait_space()
		return
	di = _skip(tab, di + 1, 1)
	txt.at(0x13, 0x11, 0x13)
	txt.puts(_cstr(tab, di))
	await ui.wait_space()


## an item's name as the original prints it: its table entry from +1 up to a zero byte
func _item_cstr(n: int) -> String:
	var rec: Array = data.item(n)["record"]
	var b := PackedByteArray()
	var i := 1
	while i < rec.size() and int(rec[i]) != 0:
		b.append(int(rec[i]))
		i += 1
	return GameText.decode(b)
