-- Obsidian Patches: small fixes for the game, each one an option in Obsidian. The five that change how
-- the game plays are also on the pause menu's Mods page (Obsidian API 1.16 and newer), bound to the same
-- options: a change there applies at once and reaches Obsidian's mod details. The other seven, fixes
-- for the game's own faults and screens to skip, are read at launch. Every
-- hook is always installed and checks its option each time, so a change from the page needs no restart.
local has_api, api = pcall(function() return obsidian.import("obsidian.api") end)
if not has_api then api = nil end

local on = {
	skip_intro = false, skip_login = false, skip_war_briefs = false, skip_planet_scanning = false,
	expedite_mission_end = "off", solo_pause = true, aim_cursor = false, toggle_map = false, widescreen = true,
	recoil_fix = true, dive_sprint_fix = true, dynamic_input = false,
}
for id in pairs(on) do
	local ok, v = pcall(obsidian.settings.get, id)
	if ok and v ~= nil then on[id] = v end
end
local changed = {}

-- The pause menu rows, by language, as the options read in obsidian.json.
local PAGE = {
	{ id = "expedite_mission_end",
		label = { en = "Expedite mission end", fr = "Accélérer la fin de mission", es = "Agilizar el final de la misión", ["pt-BR"] = "Agilizar o fim da missão" },
		info = { en = "Faster gives each results screen about a second. Instant skips to the last one. Rewards are saved either way.",
			fr = "Plus rapide affiche chaque écran de résultats environ une seconde. Instantané passe au dernier. Les récompenses sont enregistrées dans les deux cas.",
			es = "Más rápido deja cada pantalla de resultados cerca de un segundo. Instantáneo salta a la última. Las recompensas se guardan en ambos casos.",
			["pt-BR"] = "Mais rápido deixa cada tela de resultados por cerca de um segundo. Instantâneo pula para a última. As recompensas são salvas nos dois casos." },
		choices = {
			{ id = "off", label = { en = "Off", fr = "Désactivé", es = "Desactivado", ["pt-BR"] = "Desligado" } },
			{ id = "faster", label = { en = "Faster", fr = "Plus rapide", es = "Más rápido", ["pt-BR"] = "Mais rápido" } },
			{ id = "instant", label = { en = "Instant", fr = "Instantané", es = "Instantáneo", ["pt-BR"] = "Instantâneo" } },
		} },
	{ id = "solo_pause",
		label = { en = "Dynamic solo pause", fr = "Pause dynamique en solo", es = "Pausa dinámica en solitario", ["pt-BR"] = "Pausa dinâmica solo" },
		info = { en = "With a single player in the mission, the pause menu freezes the game, even in a public or friends-only lobby. The game resumes as soon as someone joins.",
			fr = "Avec un seul joueur dans la mission, le menu pause fige le jeu, même dans un lobby public ou réservé aux amis. Le jeu reprend dès que quelqu'un rejoint.",
			es = "Con un solo jugador en la misión, el menú de pausa congela el juego, incluso en un lobby público o solo para amigos. El juego sigue en cuanto alguien se une.",
			["pt-BR"] = "Com um único jogador na missão, o menu de pausa congela o jogo, mesmo num lobby público ou só para amigos. O jogo continua assim que alguém entra." } },
	{ id = "aim_cursor",
		label = { en = "Aim cursor always visible", fr = "Curseur de visée toujours visible", es = "Cursor de apuntado siempre visible", ["pt-BR"] = "Cursor de mira sempre visível" },
		info = { en = "On PC, the cursor keeps the aiming look at all times, instead of dimming between shots.",
			fr = "Sur PC, le curseur garde toujours l'aspect de visée au lieu de s'estomper entre les tirs.",
			es = "En PC, el cursor mantiene siempre el aspecto de apuntado en vez de atenuarse entre disparos.",
			["pt-BR"] = "No PC, o cursor fica sempre com a aparência de mira, em vez de esmaecer entre os tiros." } },
	{ id = "toggle_map",
		label = { en = "Toggle minimap", fr = "Basculer la mini-carte", es = "Alternar minimapa", ["pt-BR"] = "Alternar minimapa" },
		info = { en = "The map key opens the minimap and keeps it open until pressed again, instead of only while held.",
			fr = "La touche de la carte ouvre la mini-carte et la garde ouverte jusqu'au prochain appui, au lieu de seulement pendant qu'elle est maintenue.",
			es = "La tecla del mapa abre el minimapa y lo mantiene abierto hasta volver a pulsarla, en vez de solo mientras se mantiene pulsada.",
			["pt-BR"] = "A tecla do mapa abre o minimapa e o mantém aberto até ser pressionada de novo, em vez de só enquanto está pressionada." } },
}

PAGE[#PAGE + 1] = { id = "dynamic_input", label = { en = "Dynamic input switch", ["pt-BR"] = "Troca dinâmica de controle", fr = "Bascule dynamique des commandes", es = "Cambio dinámico de control" },
	info = { en = "With a keyboard and a gamepad connected, both control the first Helldiver, and the button prompts follow whichever was used last. The gamepad joins as a second Helldiver only when its join button is held for 1.5 seconds.", ["pt-BR"] = "Com teclado e controle conectados, os dois comandam o primeiro Helldiver, e os ícones de botões seguem o último usado. O controle só entra como segundo Helldiver quando o botão de entrar fica pressionado por 1,5 segundo.", fr = "Avec un clavier et une manette branchés, les deux dirigent le premier Helldiver, et les touches affichées suivent le dernier utilisé. La manette ne rejoint comme deuxième Helldiver que si son bouton pour rejoindre est maintenu 1,5 seconde.", es = "Con teclado y mando conectados, los dos controlan al primer Helldiver, y los botones que se muestran siguen al último usado. El mando solo se une como segundo Helldiver si se mantiene su botón de unirse 1,5 segundos." } }

-- Rows bound to options came with Obsidian API 1.16 (mod_settings.BINDS); an older one gets no page.
if api and api.mod_settings and api.mod_settings.BINDS then
	local page = api.mod_settings.page("Obsidian Patches")
	for _, row in ipairs(PAGE) do
		local id = row.id
		local opts = { option = true, label = row.label, info = row.info, default = on[id], choices = row.choices,
			on_change = function(v)
				on[id] = v
				if changed[id] then changed[id](v) end
			end }
		on[id] = row.choices and page:choice(id, opts) or page:toggle(id, opts)
	end
end

-- Changes a settings table as soon as the game defines it, and again if the game ever replaces the
-- table with a new one. The per-frame check is one lookup and one comparison.
local function when_defined(name, change)
	local last
	local function check()
		local t = rawget(_G, name)
		if type(t) == "table" and t ~= last then
			last = t
			change(t)
		end
	end
	check()
	obsidian.on_frame(check)
end

-- StateLogos and the intro cutscene skip when Boot.arguments.skip_splash is set. Boot.arguments is
-- built from ARGUMENTS after mods start, and the frame callback covers the case where it isn't.
if on.skip_intro then
	local a = rawget(_G, "ARGUMENTS")
	if type(a) == "table" then a.skip_splash = true end
	obsidian.on_frame(function()
		local boot = rawget(_G, "Boot")
		if type(boot) == "table" and type(boot.arguments) == "table" then
			boot.arguments.skip_splash = true
			return true
		end
	end)
end

-- Two steps, the first visit to the main menu only, so quitting to the main menu works:
-- 1. The login click: the menu's own handle_input gets select from keyboard and mouse every frame
--    until the menu takes the input (showing_menu), so the game's own checks (logo done, fades)
--    still decide when. That also makes keyboard and mouse the main pad, as a click would.
-- 2. At the login step, the steps the menu takes for a Steam invite: ask for the ship with the
--    Steam backend. The menu finishes the online setup (backend, campaign) before it leaves.
-- ARGUMENTS.autohost would skip both but picks the LAN backend, which stays offline.
if on.skip_login then
	local clicked, done = false, false
	local function click(self)
		local pad = rawget(_G, "KEYBOARD_MOUSE_PAD_NUMBER")
		if pad == nil or type(self.handle_input) ~= "function" then return end
		local input = { select = true }
		local ok, err = pcall(self.handle_input, self, input, { { pad_number = pad, input_data = input } })
		if not ok then
			clicked = true
			obsidian.log("skip login: click failed, left to the player:", err)
		elseif self.showing_menu then
			clicked = true
			obsidian.log("skip login: clicked for keyboard and mouse")
		end
	end
	local function after_update(self)
		if done or type(self) ~= "table" or self.wants_exit then return end
		if not self.showing_menu then
			if not clicked then click(self) end
			return
		end
		if self.network_setup_state == nil or self.network_setup_state ~= self.NETWORK_SETUP_LOGIN then return end
		done = true
		self.wants_exit = true
		self.wanted_state = "menu"
		self.exit_timer = 0
		self.backend_type = "STEAM"
		local sm = self.state_machine
		if type(sm) == "table" and not sm:is_prepared("menu") and not sm:is_preparing("menu") then
			if sm:is_any_preparing() then sm:unprepare() end
			sm:prepare("menu")
		end
		obsidian.log("skip login: going online to the ship")
	end
	obsidian.hook("StateMainMenu", "update", function(original, self, ...)
		local r = { original(self, ...) }
		-- Protected here, so an error never makes the hook run the game's update a second time.
		local ok, err = pcall(after_update, self)
		if not ok then
			done = true
			obsidian.log("skip login: stopped after an error:", err)
		end
		return unpack(r)
	end)
end

-- The war brief after a long absence is the campaign recap, opened by show_recap when the ship
-- loads. The war-end sequence (state_season_end) writes the save and is left alone.
-- The galaxy map also plays a shorter brief each time it opens after the war has moved: what changed
-- since the last brief, or the snapshots since the last login. The recap screen still runs its own
-- entry, which records the war as seen, and then leaves at once. A recap the player asks for, and the
-- war's end, which goes on to the season end and its save, are left to play.
do
	obsidian.hook("StateMenu", "on_enter", function(original, self, params, ...)
		if on.skip_war_briefs and type(params) == "table" and params.show_recap then
			params.show_recap = false
			obsidian.log("skip war briefs: recap skipped")
		end
		return original(self, params, ...)
	end)

	local asked, waiting = false, nil
	local function keeps(self)
		local p = type(self.params) == "table" and self.params or {}
		return self.season_end_params ~= nil or p.season_end or p.debug_recap
	end
	obsidian.hook("MenuScreenCampaign", "go_to_recap", function(original, self, ...)
		asked = true
		return original(self, ...)
	end)
	obsidian.hook("MenuScreenCampaignRecap", "on_enter", function(original, self, ...)
		local by_player = asked
		asked, waiting = false, nil
		local r = { original(self, ...) }
		if on.skip_war_briefs and not by_player and not keeps(self) and not self.wants_exit then
			if #(self.snapshots or {}) > 0 then
				self.wants_exit = true
				obsidian.log("skip war briefs: brief skipped")
			else
				-- The snapshots come from the backend: whether there's a war end to show is known then.
				waiting = self
			end
		end
		return unpack(r)
	end)
	obsidian.hook("MenuScreenCampaignRecap", "recieve_snapshots", function(original, self, ...)
		local r = { original(self, ...) }
		if waiting == self then
			waiting = nil
			if not keeps(self) and not self.wants_exit then
				self.wants_exit = true
				obsidian.log("skip war briefs: brief skipped after the snapshots")
			end
		end
		return unpack(r)
	end)
end

-- The planet discovery animation is a list of timed steps in CampaignSettings (about 6.75 s in
-- all). Each step keeps a tiny time instead of 0, so the screen never divides by zero.
do
	local steps, real = nil, setmetatable({}, { __mode = "k" })
	local function apply()
		for _, step in ipairs(steps or {}) do
			if type(step) == "table" and type(step.time) == "number" then
				if real[step] == nil then real[step] = step.time end
				step.time = on.skip_planet_scanning and 0.01 or real[step]
			end
		end
	end
	when_defined("CampaignSettings", function(s)
		steps = s.planet_scanning_states
		apply()
	end)
	changed.skip_planet_scanning = apply
end

-- Dynamic solo pause. The game never stops a mission for its pause menu, whoever is in the lobby.
-- Alone, the menu freezes it: the scripts' clock stops (_G.PAUSED, as the game's own debug pause has
-- it), and the enemy and movement components wait, as the game's tutorial pauses them. A waiting
-- component keeps the commands sent to it, and the game takes back some of their data at the end of
-- the frame (TempTableFactory), so those get their own copy. Someone joining unfreezes it at once.
-- Only what this paused is resumed: a freeze another mod made, such as Obsidian API's, stays.
do
	local COMPONENTS = { "navmesh_mover", "enemy" }
	local WAITING = { navmesh_mover = true, enemy = true }
	local frozen, menu_open, ours, real_queue, copying = false, false, {}, nil, nil

	local function alone()
		local network = rawget(_G, "NetworkGlobal")
		local lobby = type(network) == "table" and network.lobby or nil
		if not (lobby and lobby.lobby) then return true end
		local ok, members = pcall(lobby.members, lobby)
		return ok and type(members) == "table" and #members <= 1
	end

	local function state()
		local boot = rawget(_G, "Boot")
		local sm = type(boot) == "table" and boot.state_machine
		if not sm then return nil end
		return sm:get_current_state(), sm:get_current_state_name()
	end

	local function in_mission()
		local _, name = state()
		return name == "game"
	end

	local function copy_commands(on)
		local aux = rawget(_G, "EntityAux")
		if type(aux) ~= "table" then return end
		if on and not copying then
			real_queue = aux.queue_command_master
			copying = function(unit, component, command, data, ...)
				if frozen and WAITING[component] and type(data) == "table" then
					local own = {}
					for k, v in pairs(data) do own[k] = v end
					data = own
				end
				return real_queue(unit, component, command, data, ...)
			end
			aux.queue_command_master = copying
		elseif not on and copying and aux.queue_command_master == copying then
			aux.queue_command_master = real_queue
			copying, real_queue = nil, nil
		end
	end

	local function freeze(on)
		if on == frozen then return end
		local st = state()
		local cm = type(st) == "table" and st.component_manager
		frozen = on
		rawset(_G, "PAUSED", on)
		copy_commands(on)
		if cm then
			for _, name in ipairs(COMPONENTS) do
				local index, running = cm.component_name_to_index[name], false
				for _, i in ipairs(cm.active_components) do
					if i == index then running = true end
				end
				if on and running then
					cm:pause_component(name)
					ours[name] = true
				elseif not on and ours[name] and not running then
					cm:resume_component(name)
				end
			end
		end
		if not on then ours = {} end
		obsidian.log("solo pause: " .. (on and "frozen" or "running again"))
	end

	obsidian.hook("MenuScreenMain", "set_active_pause", function(original, self, pausing, ...)
		local r = { original(self, pausing, ...) }
		menu_open = pausing == true
		local ok, err = pcall(freeze, on.solo_pause and menu_open and in_mission() and alone())
		if not ok then obsidian.log("solo pause: stopped after an error:", err) end
		return unpack(r)
	end)

	obsidian.on_frame(function()
		if not frozen then return end
		local joined = not alone()
		if joined or not menu_open or not in_mission() or not on.solo_pause then
			if joined then obsidian.log("solo pause: someone joined") end
			local ok, err = pcall(freeze, false)
			if not ok then obsidian.log("solo pause: could not unfreeze:", err) end
		end
	end)
end

-- The game's own crosshair option shows the cursor dimmed between shots. This keeps the aiming
-- cursor up instead. It answers the input code alone, so the option in the game's menu stays as the
-- player set it.
do
	local inside = false
	obsidian.hook("InputComponent", "update_masters", function(original, ...)
		inside = true
		local ok, err = pcall(original, ...)
		inside = false
		if not ok then error(err, 0) end
	end)
	obsidian.hook("SaveManager", "get", function(original, self, key, ...)
		if on.aim_cursor and inside and key == "crosshair_always_visible" then return true end
		return original(self, key, ...)
	end)
	obsidian.hook("CursorManager", "set_cursor", function(original, self, name, ...)
		if on.aim_cursor and inside and name == "hud/cursors/game_inactive" then name = "hud/cursors/game" end
		return original(self, name, ...)
	end)
end

-- The game can already make a key toggle: a sticky binding, the Keybindings menu's own setting, and
-- how a pad's map key starts. The input code gets a copy of its bindings with the map's set to that,
-- so the player's saved keybindings and that menu stay as they are.
do
	obsidian.hook("InputRebinder", "get_or_default", function(original, self, ...)
		local bindings = original(self, ...)
		if not on.toggle_map or type(bindings) ~= "table" then return bindings end
		local copy = {}
		for i, binding in ipairs(bindings) do
			copy[i] = binding
			if binding.output_name == "map_pressed" and binding.key == "FilterSticky" and type(binding.input) == "table" then
				local entry, input = {}, {}
				for k, v in pairs(binding) do entry[k] = v end
				for k, v in pairs(binding.input) do input[k] = v end
				input.start_sticky = true
				entry.input = input
				copy[i] = entry
			end
		end
		return copy
	end)
end

-- A stratagem throw, or picking a weapon up from the ground, can leave the weapon layer of the
-- character's animation (entry 6 of the state the engine gives for the unit) in a pose of the throw or
-- the pickup, and the weapon then fires with no recoil. The weapon is wielded while that animation still
-- holds the layer, so the weapon's own setup of the layer is lost. The entry is kept when the stratagem
-- menu or an interaction opens, and once the character is back on foot for SETTLE frames:
-- - the same weapon in hand: an entry that still differs is put back;
-- - another weapon in hand, the one picked up: that weapon's own on_wielded flow event plays again,
--   which sets the layer up the way wielding it does.
-- A weapon switch on the way re-wields by itself, and drops the check. Only units this machine runs go
-- through these states here: the player's, a second controller's and bots.
do
	local LAYER, SETTLE, GIVE_UP = 6, 20, 900
	local ON_FOOT = { "CharacterStateIdle", "CharacterStateWalk", "CharacterStateAim", "CharacterStateAimWalk", "CharacterStateSprint" }
	local FIRING = { "CharacterStateFire", "CharacterStateWalkFire", "CharacterStateAimFire", "CharacterStateAimWalkFire" }
	local kept = setmetatable({}, { __mode = "k" })

	local function is_one_of(state, names)
		if state == nil then return false end
		for _, name in ipairs(names) do
			if state == rawget(_G, name) then return true end
		end
		return false
	end

	local function weapon_of(unit)
		local inv = rawget(_G, "EntityAux").state(unit, "inventory")
		return inv and inv.current_weapon
	end

	-- A pose kept while the weapon was firing would bring back a shot, so only a calm one counts.
	local function keep(unit, previous)
		if not on.recoil_fix or is_one_of(previous, FIRING) then return end
		local pose = { rawget(_G, "Unit").animation_get_state(unit) }
		if pose[LAYER] == nil then return end
		kept[unit] = { weapon = weapon_of(unit), value = pose[LAYER], on_foot = 0, age = 0 }
	end

	for _, name in ipairs({ "CharacterStateStratagems", "CharacterStateInteract" }) do
		obsidian.hook(name, "on_enter", function(original, self, ctx, previous, ...)
			local ok, err = pcall(keep, self, previous)
			if not ok then obsidian.log("recoil fix: " .. tostring(err)) end
			return original(self, ctx, previous, ...)
		end)
	end

	local function check(unit, k)
		local units = rawget(_G, "Unit")
		k.age = k.age + 1
		if not on.recoil_fix or not units.alive(unit) or k.age > GIVE_UP then return true end
		local cs = rawget(_G, "EntityAux").state(unit, "character")
		local state = cs and cs.current_state
		if state ~= nil and state == rawget(_G, "CharacterStateSwitchWeapon") then return true end
		local weapon = weapon_of(unit)
		if weapon == nil then return true end
		if weapon ~= k.weapon then
			k.weapon, k.picked_up, k.on_foot = weapon, true, 0
		end
		k.on_foot = is_one_of(state, ON_FOOT) and k.on_foot + 1 or 0
		if k.on_foot < SETTLE then return false end
		if k.picked_up then
			units.flow_event(weapon, "on_wielded")
			obsidian.log("recoil fix: weapon set up again after a pickup")
			return true
		end
		local pose = { units.animation_get_state(unit) }
		if pose[LAYER] ~= nil and pose[LAYER] ~= k.value then
			pose[LAYER] = k.value
			units.animation_set_state(unit, unpack(pose))
			obsidian.log("recoil fix: weapon pose put back")
		end
		return true
	end

	obsidian.on_frame(function()
		if next(kept) == nil then return end
		for unit, k in pairs(kept) do
			local ok, done = pcall(check, unit, k)
			if not ok then obsidian.log("recoil fix: " .. tostring(done)) end
			if not ok or done then kept[unit] = nil end
		end
	end)
end

-- The sprint state sends nothing to the upper-body (weapon) layer of the character's animation, so a
-- sprint keeps whatever pose the state before it left there. Walking releases that layer as it starts
-- (animation event no_animation), so a sprint out of a walk looks right. Standing still holds the idle
-- pose there (idle_upper), and firing holds the hip-fire pose (aim_hip), so a sprint that starts
-- straight from one of them runs with the upper body frozen in that pose, until a walk on the way
-- releases it. Getting up from a dive, or from the crawl it turns into, hands over to standing, and with
-- sprint and a direction still held the sprint starts on the next frame: the stuck pose after a dive.
-- A sprint that starts from standing, firing or a weapon switch releases the layer the way a walk does.
-- A reload releases it when the reload animation ends, and the map closes with an animation of its own,
-- so those two are left alone. Only units this machine runs go through these states here.
do
	local HELD = { "CharacterStateIdle", "CharacterStateFire", "CharacterStateWalkFire", "CharacterStateSwitchWeapon" }

	local function release(unit, previous)
		if not on.dive_sprint_fix or previous == nil then return end
		for _, name in ipairs(HELD) do
			if previous == rawget(_G, name) then
				local units = rawget(_G, "Unit")
				if units.has_animation_event(unit, "no_animation") then units.animation_event(unit, "no_animation") end
				return
			end
		end
	end

	obsidian.hook("CharacterStateSprint", "on_enter", function(original, self, ctx, previous, ...)
		local ok, err = pcall(release, self, previous)
		if not ok then obsidian.log("sprint pose fix: " .. tostring(err)) end
		return original(self, ctx, previous, ...)
	end)
end

-- Every game state limits the viewport to GameSettings.max_aspect_ratio (16:9), which letterboxes
-- wider screens. A high limit lets the viewport fill the screen.
do
	local settings, real = nil, nil
	local function apply()
		if not settings then return end
		if real == nil then real = settings.max_aspect_ratio end
		if type(real) == "number" then settings.max_aspect_ratio = on.widescreen and 10 or real end
	end
	when_defined("GameSettings", function(s)
		settings, real = s, nil
		apply()
	end)
	changed.widescreen = apply

	-- A 3D preview, such as the Armory's character, renders into part of the screen sized against
	-- 1280x720, and shows up in a box sized the same way. On a wider screen that part is wider than
	-- the box, so the character looks squashed. The width it renders at is only what the texture
	-- coordinates read, so narrowing it to match the box leaves everything else alone.
	obsidian.hook("PreviewWindow", "update_dimensions", function(original, self)
		original(self)
		local width, height = rawget(_G, "Application").resolution()
		if on.widescreen and width / height > 16 / 9 then
			self.norm_width = self.width / 720 * height / width
			self.viewport_proxy:set_rect(self.norm_x, self.norm_y, self.norm_width, self.norm_height)
		end
	end)

	-- The HUD lays out a 1280x720 screen and centres it (HdGui.update_offsets), so on a wider screen
	-- an element meant for a corner stands inside the 16:9 middle. The position HdGui draws at adds
	-- resolution_offset_x each time (HdGui.calculate_pos): while such an element draws, the offset
	-- is doubled to reach the right edge, or zeroed for the left one, then put back.
	local function wide()
		local app = rawget(_G, "Application")
		local ok, w, h = pcall(app.resolution)
		return on.widescreen and ok and type(w) == "number" and h > 0 and w / h > 16 / 9 + 0.01
	end

	local function pinned(guis, side, fn, ...)
		local kept = {}
		for i, gui in ipairs(guis) do
			if type(gui) == "table" and type(gui.resolution_offset_x) == "number" then
				kept[i] = gui.resolution_offset_x
				gui.resolution_offset_x = side == "right" and gui.resolution_offset_x * 2 or 0
			end
		end
		local function pack(...) return { n = select("#", ...), ... } end
		local r = pack(pcall(fn, ...))
		for i, gui in ipairs(guis) do
			if kept[i] then gui.resolution_offset_x = kept[i] end
		end
		if not r[1] then error(r[2], 0) end
		return unpack(r, 2, r.n)
	end

	-- The mission's objective list, at the top right.
	obsidian.hook("MissionManager", "draw_objective_list", function(original, self, gui, ...)
		if not wide() then return original(self, gui, ...) end
		return pinned({ gui }, "right", original, self, gui, ...)
	end)

	-- The galaxy map's menus draw with GuiManager, which centres the 1280x720 layout by adding
	-- (rect.w - design_width * scale) / 2 to each position (GuiManager.calculate_pos). While a panel
	-- draws, each position is moved by that much again to the side it stands on: whatever starts past
	-- 60% of the layout's width goes to the right edge, whatever ends before 40% to the left edge, and
	-- what crosses the middle, such as a title, stays.
	local function margin(gm)
		local ok, sx, sy = pcall(gm.get_scale, gm)
		if not ok then return nil end
		local s = math.min(sx, sy)
		local area = gm.gui_settings.design_width * s / (gm.ui_scale_user or 1)
		return (gm.rect.w - area) / 2, area
	end

	local function sides_pinned(gm, fn, ...)
		local extra, area = nil, nil
		if type(gm) == "table" and type(gm.rect) == "table" and type(gm.gui_settings) == "table" then extra, area = margin(gm) end
		if not extra or extra <= 0 or rawget(gm, "calculate_pos") then return fn(...) end
		local real = gm.calculate_pos
		gm.calculate_pos = function(self, pos, size, ...)
			local a, b, c = real(self, pos, size, ...)
			if a then
				local w = b and b.x or 0
				local from, to = (a.x - extra) / area, (a.x + w - extra) / area
				if from > 0.6 then a.x = a.x + extra elseif to < 0.4 then a.x = a.x - extra end
			end
			return a, b, c
		end
		local function pack(...) return { n = select("#", ...), ... } end
		local r = pack(pcall(fn, ...))
		gm.calculate_pos = nil
		if not r[1] then error(r[2], 0) end
		return unpack(r, 2, r.n)
	end

	-- The region's planet panel, and the planet's reward and mission panels.
	obsidian.hook("MenuScreenCampaignPlanet", "show_planet_info", function(original, self, gm, ...)
		if not wide() then return original(self, gm, ...) end
		return sides_pinned(gm, original, self, gm, ...)
	end)
	obsidian.hook("MenuScreenCampaignMission", "show_mission_info", function(original, self, gm, ...)
		if not wide() then return original(self, gm, ...) end
		return sides_pinned(gm, original, self, gm, ...)
	end)

	-- The galaxy map's scanline overlay is as wide as the layout: for its draw, the layout is as wide as
	-- the screen, which also takes the centring away.
	obsidian.hook("MenuScreenCampaign", "draw_scanlines", function(original, self, dt, layer, gm, ...)
		if not (wide() and type(gm) == "table" and type(gm.gui_settings) == "table" and type(gm.rect) == "table") then
			return original(self, dt, layer, gm, ...)
		end
		local settings = gm.gui_settings
		local real = settings.design_width
		local ok, sx, sy = pcall(gm.get_scale, gm)
		if ok then settings.design_width = gm.rect.w * (gm.ui_scale_user or 1) / math.min(sx, sy) end
		local done, err = pcall(original, self, dt, layer, gm, ...)
		settings.design_width = real
		if not done then error(err, 0) end
	end)

	-- A character's dialogue box, set over the first player's card at the left: on the ship, in the
	-- galaxy map's briefings and in missions. It draws on two guis, the HUD's own unless given.
	obsidian.hook("Hud", "draw_dialogue", function(original, self, ...)
		if not wide() then return original(self, ...) end
		local args = { ... }
		return pinned({ args[7] or self.hd_gui, args[8] or self.hd_gui_dialogue }, "left", original, self, ...)
	end)
end

-- The mission end screens are sub-states of StateMissionEnd: change_state(self, sub) calls
-- sub.on_enter(self), and the state's update hands sub.update(self, dt) the frame time. Waiting
-- for data writes the save and Done calls save_stats, so both always run at full length; the
-- screens between them only show results. Three screens wait until every player presses
-- continue, and this player's presses are made for them (other players still press their own).
-- Instant goes from waiting for data straight to Done, as the game's own debug skip does.
-- Faster runs each result screen in about a second: steps listed in sub_state_states are timed
-- to fit, and a screen still showing after that runs ever faster until it ends.
do
	local SHOWN = {
		"MissionEndStateMissionResult", "MissionEndStateMissionScore", "MissionEndStateGenocideResults",
		"MissionEndStateExperienceDistribution", "MissionEndStateIndividualStats", "MissionEndStatePrePlanetPause",
		"MissionEndStatePlanetCompleted", "MissionEndStatePlanetCompletedScore", "MissionEndStatePlanetCompletedReward",
		"MissionEndStateEventCompletedScore", "MissionEndStateEventCompletedReward", "MissionEndStateProvinggroundsCompleted",
		"MissionEndOverlayLevelUp",
	}
	local READY = {
		MissionEndStateGenocideResults = "is_ready_genocide",
		MissionEndStatePrePlanetPause = "is_ready_planet",
		MissionEndStateDone = "is_ready",
	}
	local PHASE = 1
	local phase = { elapsed = 0, speed = 1, pressed = false }

	local function current(self)
		for name in pairs(READY) do
			if self.current_state ~= nil and self.current_state == rawget(_G, name) then return name end
		end
	end

	-- Instant presses for all three screens at once: a host still showing one of them waits for
	-- this player's press there.
	local function press(self)
		local expedite = on.expedite_mission_end
		local name = current(self)
		if not name or phase.pressed then return end
		phase.pressed = true
		for _, p in ipairs(self.players or {}) do
			local go = p.player_go
			if go and go:owned() then
				if expedite == "instant" then
					for _, flag in pairs(READY) do go:set(flag, true) end
				else
					go:set(READY[name], true)
				end
			end
		end
	end

	obsidian.hook("StateMissionEnd", "change_state", function(original, self, sub, ...)
		local expedite = on.expedite_mission_end
		if expedite ~= "faster" and expedite ~= "instant" then return original(self, sub, ...) end
		local done = rawget(_G, "MissionEndStateDone")
		if expedite == "instant" and done and sub ~= nil and sub ~= done and sub ~= rawget(_G, "MissionEndStateWaitingForData") then
			sub = done
			obsidian.log("expedite mission end: results skipped")
		end
		local steps = self.sub_state_states
		local r = { original(self, sub, ...) }
		phase.elapsed, phase.pressed, phase.speed = 0, false, 2
		if self.sub_state_states ~= steps and type(self.sub_state_states) == "table" then
			local total = 0
			for _, step in ipairs(self.sub_state_states) do
				if type(step) == "table" and type(step.time) == "number" then total = total + step.time end
			end
			phase.speed = math.max(1, total / PHASE)
		end
		if expedite == "instant" then press(self) end
		return unpack(r)
	end)

	do
		obsidian.hook("StateMissionEnd", "update", function(original, self, dt, ...)
			if on.expedite_mission_end == "faster" and type(dt) == "number" then
				phase.elapsed = phase.elapsed + dt
				if phase.elapsed > PHASE then
					phase.speed = math.min(phase.speed * 1.25, 1000)
					press(self)
				end
			end
			return original(self, dt, ...)
		end)
		for _, name in ipairs(SHOWN) do
			obsidian.hook(name, "update", function(original, self, dt, ...)
				if on.expedite_mission_end == "faster" and type(dt) == "number" then dt = dt * phase.speed end
				return original(self, dt, ...)
			end)
		end
	end
end


-- Dynamic input switch. On PC the first Helldiver plays on the keyboard and mouse, and a gamepad nobody
-- plays on asks "PRESS A TO JOIN" and joins at a press of interact. With the option on, that gamepad
-- drives the first Helldiver too: whichever of the two was used last is the one the Helldiver's input
-- component reads (its "pad_number" command, as the game sets it at spawn), and the button prompts
-- follow (InputUtility.set_localization_modifier_set_for). Its Start opens the pause menu for it. It
-- joins as a Helldiver of its own only once interact has been held for HOLD seconds: the game's own
-- join request at the press is held back (NetworkRouter.transmit_to), and sent here at the end of the
-- hold, with the checks the game makes. The prompt says HOLD instead of PRESS.
do
	local HOLD = 1.5
	local DEADZONE = 0.35
	local JOIN_RPC = "rpc_add_local_player_request"
	-- The game's verb in its join prompt, by language, and the one put in its place.
	local HOLD_WORDS = {
		{ "^PRESS ", "HOLD " }, { "^APPUYER SUR ", "MAINTENIR " }, { "^PULSA ", "MANTÉN " },
		{ "^PRESSIONE ", "SEGURE " }, { "^PRIME ", "MANTÉM PREMIDO " },
	}
	local JOINING = 5 -- seconds a gamepad that asked to join stays out of the first Helldiver's hands
	local dyn = { device = nil, unit = nil, held = {}, allowed = {}, joining = {}, last_cursor = nil }

	local function g(name) return rawget(_G, name) end

	local function keyboard_number() return g("KEYBOARD_MOUSE_PAD_NUMBER") or 0 end

	local function playing_state()
		local boot = g("Boot")
		local sm = type(boot) == "table" and boot.state_machine
		if not sm then return nil end
		local ok, name = pcall(sm.get_current_state_name, sm)
		if not ok or (name ~= "game" and name ~= "menu") then return nil end
		local ok2, st = pcall(sm.get_current_state, sm)
		return ok2 and type(st) == "table" and st or nil
	end

	-- The first Helldiver, on the keyboard, and the gamepads no local player has.
	local function seats(st)
		local first, used = nil, {}
		for _, record in ipairs(st.players or {}) do
			local go = record.player_go
			local ok, owned = pcall(function() return go:exists() and go:owned() end)
			if ok and owned then
				used[record.pad_number] = true
				if record.pad_number == keyboard_number() and not first then first = record end
			end
		end
		local free = {}
		local pads = g("PadManager")
		local ok, active = pcall(pads.get_active_pads, pads)
		if ok and type(active) == "table" then
			for _, p in ipairs(active) do
				if not used[p.pad_number] and p.pad_number ~= keyboard_number() then free[#free + 1] = { number = p.pad_number, pad = p.pad } end
			end
		end
		return first, free
	end

	local function pad_used(pad)
		local ok, used = pcall(function()
			if pad.any_pressed() then return true end
			for _, name in ipairs({ "left", "right" }) do
				local a = pad.axis(pad.axis_index(name))
				if math.abs(a.x) > DEADZONE or math.abs(a.y) > DEADZONE then return true end
			end
			return false
		end)
		return ok and used
	end

	local function keyboard_used()
		local kb, mouse = g("Keyboard"), g("Mouse")
		local used = false
		pcall(function() used = kb.any_pressed() end)
		if not used and mouse then
			pcall(function()
				if mouse.any_pressed() then used = true end
				local c = mouse.axis(mouse.axis_index("cursor"))
				if dyn.last_cursor and (math.abs(c.x - dyn.last_cursor.x) > 3 or math.abs(c.y - dyn.last_cursor.y) > 3) then used = true end
				dyn.last_cursor = { x = c.x, y = c.y }
			end)
		end
		return used
	end

	local function button_held(pad, name)
		local ok, v = pcall(function() return pad.button(pad.button_index(name)) end)
		return ok and type(v) == "number" and v > 0.5
	end

	local function button_pressed(pad, name)
		local ok, v = pcall(function() return pad.pressed(pad.button_index(name)) end)
		return ok and v == true
	end

	-- The Helldiver reads `number`'s input from now on, and the prompts show its buttons.
	local function drive(unit, number)
		local aux = g("EntityAux")
		pcall(aux.queue_command_master, unit, "input", "pad_number", number)
		pcall(aux.queue_command_master, unit, "input", "has_focus", true)
		pcall(g("InputUtility").set_localization_modifier_set_for, number)
		dyn.device, dyn.unit = number, unit
	end

	local function give_back()
		if dyn.unit and dyn.device and dyn.device ~= keyboard_number() then
			local ok, alive = pcall(g("Unit").alive, dyn.unit)
			if ok and alive then drive(dyn.unit, keyboard_number()) end
			pcall(g("InputUtility").set_localization_modifier_set_for, keyboard_number())
		end
		dyn.device, dyn.unit, dyn.held = nil, nil, {}
	end

	-- The game's own join request, at the end of a hold: the checks StateGame.handle_input and
	-- StateMenu.handle_input make before they send it.
	local function join(st, number)
		local lobby = g("NetworkGlobal") and g("NetworkGlobal").lobby
		if not (lobby and lobby.lobby_host) then return end
		local ok, players = pcall(st.get_active_players, st)
		if not ok or #players >= 4 then return end
		local hotjoin = g("HotjoinManager")
		if hotjoin and not hotjoin:can_pad_join(number) then return end
		local handler = st.network_session_handler
		if handler and not handler:is_peer_in_session() then return end
		dyn.allowed[number] = true
		pcall(st.network_router.transmit_to, st.network_router, lobby:lobby_host(), JOIN_RPC, number, 1)
		dyn.allowed[number] = nil
	end

	local function tick(dt)
		if not on.dynamic_input then
			if dyn.device then give_back() end
			return
		end
		local st = playing_state()
		if not st then
			dyn.device, dyn.unit, dyn.held = nil, nil, {}
			return
		end
		local first, free = seats(st)
		local unit = nil
		if first then
			local ok, u = pcall(first.player_go.get, first.player_go, "avatar_unit")
			if ok then unit = u end
		end
		local ok_alive, alive = pcall(g("Unit").alive, unit)
		if not (unit and ok_alive and alive) or #free == 0 then
			if #free == 0 and dyn.device then give_back() end
			dyn.unit = nil
			return
		end
		-- A held join button joins, as a press did before.
		for _, p in ipairs(free) do
			if button_held(p.pad, "a") then
				dyn.held[p.number] = (dyn.held[p.number] or 0) + dt
				if dyn.held[p.number] >= HOLD then
					dyn.held[p.number] = -math.huge
					if dyn.device == p.number then drive(unit, keyboard_number()) end
					dyn.joining[p.number] = JOINING
					join(st, p.number)
				end
			else
				dyn.held[p.number] = nil
			end
		end
		for number, left in pairs(dyn.joining) do
			dyn.joining[number] = left > dt and left - dt or nil
		end
		local want = dyn.device or keyboard_number()
		if dyn.joining[want] then want = keyboard_number() end
		if keyboard_used() then want = keyboard_number() end
		for _, p in ipairs(free) do
			if not dyn.joining[p.number] and pad_used(p.pad) then want = p.number end
		end
		-- A new Helldiver after a respawn starts on the keyboard, as the game spawns it.
		if want ~= dyn.device or unit ~= dyn.unit then drive(unit, want) end
		-- The game sets the prompts back to the keyboard's as a menu closes.
		local lm = g("LocalizationManager")
		local want_set = want == keyboard_number() and "keyboard_mouse" or ("pad" .. want)
		if lm and lm.get_current_modifier_set and lm:get_current_modifier_set() ~= want_set then
			pcall(g("InputUtility").set_localization_modifier_set_for, want)
		end
		-- Start on the gamepad that drives the first Helldiver opens the pause menu for it.
		if want ~= keyboard_number() and not st.active_screen and type(st.show_menu) == "function" then
			for _, p in ipairs(free) do
				if p.number == want and button_pressed(p.pad, "start") then
					pcall(st.show_menu, st, "main", { user_pad_number = want })
				end
			end
		end
	end

	obsidian.on_frame(function()
		local ok, err = pcall(tick, rawget(_G, "ENGINE_DT") or 0.016)
		if not ok and not dyn.failed then
			dyn.failed = true
			obsidian.log("dynamic input: " .. tostring(err))
		end
	end)

	-- The game's join at a press waits for the hold.
	-- Only the join a press asks for waits: the one StateGame.handle_input and StateMenu.handle_input
	-- send for a gamepad nobody plays on. The same message also adds every local player when this
	-- machine joins a session (StateMenu.on_added_to_session, at login and on the way to the ship), and
	-- holding that one back leaves the ship without a Helldiver.
	local function pressing(class)
		obsidian.hook(class, "handle_input", function(original, ...)
			dyn.pressing = true
			local function pack(...) return { n = select("#", ...), ... } end
			local r = pack(pcall(original, ...))
			dyn.pressing = false
			if not r[1] then error(r[2], 0) end
			return unpack(r, 2, r.n)
		end)
	end
	pressing("StateGame")
	pressing("StateMenu")

	-- The arguments go on exactly as they came: an RPC is sent with as many values as it's given, and a
	-- named one more would add a nil the session doesn't expect, which ends it.
	obsidian.hook("NetworkRouter", "transmit_to", function(original, self, peer, message, ...)
		if on.dynamic_input and dyn.pressing and message == JOIN_RPC and not dyn.allowed[(...)] then return end
		return original(self, peer, message, ...)
	end)

	obsidian.hook("LocalizationManager", "string", function(original, self, key, ...)
		local s = original(self, key, ...)
		if on.dynamic_input and key == "press_cross_to_join" and type(s) == "string" then
			for _, w in ipairs(HOLD_WORDS) do
				local swapped, n = s:gsub(w[1], w[2], 1)
				if n > 0 then return swapped end
			end
		end
		return s
	end)

	changed.dynamic_input = function(v)
		if not v then give_back() end
	end
end
