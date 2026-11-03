-- Obsidian Patches: small fixes for the game, each one an option in Obsidian. The four that change how
-- the game plays are also on the pause menu's Mods page (Obsidian API 1.16 and newer), bound to the same
-- options: a change there applies at once and reaches Obsidian's mod details. The other seven, fixes
-- for the game's own faults and screens to skip, are read at launch. Every
-- hook is always installed and checks its option each time, so a change from the page needs no restart.
local has_api, api = pcall(function() return obsidian.import("obsidian.api") end)
if not has_api then api = nil end

local on = {
	skip_intro = false, skip_login = false, skip_war_briefs = false, skip_planet_scanning = false,
	expedite_mission_end = "off", solo_pause = true, aim_cursor = false, toggle_map = false, widescreen = true,
	recoil_fix = true, dive_sprint_fix = true,
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

-- A stratagem throw can leave the weapon layer of the character's animation (entry 6 of the state the
-- engine gives for the unit) in a pose of the throw, and the weapon then fires with no recoil. The
-- entry is kept when the stratagem menu opens, and once the character is back on foot with the same
-- weapon for SETTLE frames, an entry that still differs is put back. Only units this machine runs go
-- through the stratagem states here: the player's, a second controller's and bots.
do
	local LAYER, SETTLE, GIVE_UP = 6, 20, 600
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

	obsidian.hook("CharacterStateStratagems", "on_enter", function(original, self, ctx, previous, ...)
		local ok, err = pcall(keep, self, previous)
		if not ok then obsidian.log("recoil fix: " .. tostring(err)) end
		return original(self, ctx, previous, ...)
	end)

	local function check(unit, k)
		local units = rawget(_G, "Unit")
		k.age = k.age + 1
		if not on.recoil_fix or not units.alive(unit) or k.age > GIVE_UP or weapon_of(unit) ~= k.weapon then return true end
		local cs = rawget(_G, "EntityAux").state(unit, "character")
		k.on_foot = cs and is_one_of(cs.current_state, ON_FOOT) and k.on_foot + 1 or 0
		if k.on_foot < SETTLE then return false end
		local pose = { units.animation_get_state(unit) }
		if pose[LAYER] ~= nil and pose[LAYER] ~= k.value then
			pose[LAYER] = k.value
			units.animation_set_state(unit, unpack(pose))
			obsidian.log("recoil fix: weapon pose put back after a stratagem")
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

-- A sprint that ends on its own sends the animation event sprint_stop. A dive out of a sprint leaves
-- the sprint state with no such event, so after the dive the upper body still holds the sprint, and the
-- next sprint plays over it in a stuck pose until the player stops and sprints again. A dive that began
-- in a sprint gets the missing sprint_stop once the character is back on foot: the dive state, or the
-- crawl it can turn into, handing over to standing.
do
	local from_sprint = setmetatable({}, { __mode = "k" })

	obsidian.hook("CharacterStateDodge", "on_enter", function(original, self, ctx, previous, ...)
		from_sprint[self] = on.dive_sprint_fix and previous ~= nil and previous == rawget(_G, "CharacterStateSprint") or nil
		return original(self, ctx, previous, ...)
	end)

	local function stand_up(unit, after)
		if not from_sprint[unit] or after == rawget(_G, "CharacterStateCrawl") then return end
		from_sprint[unit] = nil
		if after ~= nil and after == rawget(_G, "CharacterStateIdle") then
			rawget(_G, "Unit").animation_event(unit, "sprint_stop")
		end
	end

	for _, name in ipairs({ "CharacterStateDodge", "CharacterStateCrawl" }) do
		obsidian.hook(name, "on_exit", function(original, self, ctx, after, ...)
			local r = { original(self, ctx, after, ...) }
			local ok, err = pcall(stand_up, self, after)
			if not ok then obsidian.log("dive sprint fix: " .. tostring(err)) end
			return unpack(r)
		end)
	end
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
