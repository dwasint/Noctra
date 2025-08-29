/datum/sex_session //! TODO SEX SOUNDS
	/// The initiating user
	var/mob/living/carbon/human/user
	/// Target of our actions
	var/mob/living/carbon/human/target
	/// Whether the user desires to stop current action
	var/desire_stop = FALSE
	/// What is the current performed action
	var/datum/sex_action/current_action = null
	/// Enum of desired speed
	var/speed = SEX_SPEED_MID
	/// Enum of desired force
	var/force = SEX_FORCE_MID
	/// Makes genital arousal automatic by default
	var/manual_arousal = SEX_MANUAL_AROUSAL_DEFAULT
	/// Whether we want to screw until finished, or non stop
	var/do_until_finished = TRUE
	///inactivity bumps
	var/inactivity = 0
	/// Reference to the collective this session belongs to
	var/datum/collective_message/collective = null

	var/static/sex_id = 0
	var/our_sex_id = 0 //this is so we can have more then 1 sex id open at once

/datum/sex_session/New(mob/living/carbon/human/session_user, mob/living/carbon/human/session_target)
	user = session_user
	target = session_target
	sex_id++
	our_sex_id = sex_id
	assign_to_collective()

	addtimer(CALLBACK(src, PROC_REF(check_sex)), 60 SECONDS, flags = TIMER_LOOP)

/datum/sex_session/Destroy(force, ...)
	// Remove from collective
	if(collective)
		collective.sessions -= src
		// If this was the last session in the collective, remove the collective
		if(!collective.sessions.len)
			collective.unregister_collective_tab()
			LAZYREMOVE(GLOB.sex_collectives, collective)
			qdel(collective)

	GLOB.sex_sessions -= src
	. = ..()


/datum/sex_session/proc/assign_to_collective()
	// Check if we can merge with an existing collective
	for(var/datum/collective_message/existing_collective in GLOB.sex_collectives)
		if(existing_collective.can_merge_session(src))
			existing_collective.merge_session(src)
			return

	// No existing collective found, create a new one
	var/datum/collective_message/new_collective = new /datum/collective_message(src)
	LAZYADD(GLOB.sex_collectives, new_collective)
	collective = new_collective

/datum/sex_session/proc/check_sex()
	if(current_action)
		return
	inactivity++

	if(inactivity < 3)
		return
	qdel(src)

/datum/sex_session/proc/check_climax()
	var/list/arousal_data = list()
	SEND_SIGNAL(user, COMSIG_SEX_GET_AROUSAL, arousal_data)
	if(arousal_data["arousal"] < ACTIVE_EJAC_THRESHOLD)
		return FALSE
	return TRUE

/datum/sex_session/proc/try_start_action(action_type)
	if(action_type == current_action)
		try_stop_current_action()
		return
	if(current_action != null)
		try_stop_current_action()
		return
	if(!action_type)
		return
	if(!can_perform_action(action_type))
		return

	desire_stop = FALSE
	current_action = action_type
	inactivity = 0
	var/datum/sex_action/action = SEX_ACTION(current_action)
	log_combat(user, target, "Started sex action: [action.name] with [target.name].")
	INVOKE_ASYNC(src, PROC_REF(sex_action_loop))

/datum/sex_session/proc/try_stop_current_action()
	if(!current_action)
		return
	desire_stop = TRUE

/datum/sex_session/proc/considered_limp(mob/limper)
	var/list/arousal_data = list()
	SEND_SIGNAL(limper, COMSIG_SEX_GET_AROUSAL, arousal_data)
	var/arousal_value = arousal_data["arousal"]
	if(arousal_value >= AROUSAL_HARD_ON_THRESHOLD)
		return FALSE
	return TRUE

/datum/sex_session/proc/sex_action_loop()
	var/performed_action_type = current_action
	var/datum/sex_action/action = SEX_ACTION(current_action)
	action.on_start(user, target)

	while(TRUE)
		if(isnull(target.client))
			break

		var/stamina_cost = action.stamina_cost * get_stamina_cost_multiplier()
		if(!user.adjust_stamina(-stamina_cost))
			break

		var/do_time = action.do_time / get_speed_multiplier()
		if(!do_after(user, do_time, target = target))
			break

		if(current_action == null || performed_action_type != current_action)
			break
		if(!can_perform_action(current_action))
			break
		if(action.is_finished(user, target))
			break
		if(desire_stop)
			break

		action.on_perform(user, target)

		if(action.is_finished(user, target))
			break
		if(!action.continous)
			break

	stop_current_action()

/datum/sex_session/proc/stop_current_action()
	if(!current_action)
		return
	var/datum/sex_action/action = SEX_ACTION(current_action)
	action.on_finish(user, target)
	desire_stop = FALSE
	current_action = null

/datum/sex_session/proc/can_perform_action(action_type)
	if(!action_type)
		return FALSE
	var/datum/sex_action/action = SEX_ACTION(action_type)
	if(!inherent_perform_check(action_type))
		return FALSE
	if(!action.can_perform(user, target))
		return FALSE
	return TRUE

/datum/sex_session/proc/inherent_perform_check(action_type)
	var/datum/sex_action/action = SEX_ACTION(action_type)
	if(!target)
		return FALSE
	if(user.stat != CONSCIOUS)
		return FALSE
	if(!user.Adjacent(target))
		return FALSE
	if(action.check_incapacitated && user.incapacitated())
		return FALSE
	if(action.check_same_tile)
		var/same_tile = (get_turf(user) == get_turf(target))
		var/grab_bypass = (action.aggro_grab_instead_same_tile && user.get_highest_grab_state_on(target) == GRAB_AGGRESSIVE)
		if(!same_tile && !grab_bypass)
			return FALSE
	if(action.require_grab)
		var/grabstate = user.get_highest_grab_state_on(target)
		if(grabstate == null || grabstate < action.required_grab_state)
			return FALSE
	return TRUE

/datum/sex_session/proc/perform_sex_action(mob/living/carbon/human/action_target, arousal_amt, pain_amt, giving)
	SEND_SIGNAL(action_target, COMSIG_SEX_RECEIVE_ACTION, arousal_amt, pain_amt, giving, force, speed)

/datum/sex_session/proc/handle_passive_ejaculation(mob/living/carbon/human/handler)
	if(!handler)
		handler = user
	var/list/arousal_data = list()
	SEND_SIGNAL(handler, COMSIG_SEX_GET_AROUSAL, arousal_data)
	var/arousal_multiplier = arousal_data["arousal_multiplier"]
	var/arousal_value = arousal_data["arousal"]

	if(arousal_multiplier > 1.5 && user.check_handholding())
		if(prob(5))
			SEND_SIGNAL(handler, COMSIG_SEX_RECEIVE_ACTION, 3, 0, 1, 0)
		if(arousal_value < 70)
			SEND_SIGNAL(handler, COMSIG_SEX_ADJUST_AROUSAL, 0.2)

		if(handler.handcuffed)
			if(prob(8))
				var/chaffepain = pick(10,10,10,10,20,20,30)
				SEND_SIGNAL(handler, COMSIG_SEX_RECEIVE_ACTION, 3, chaffepain, 1, 0)
				handler.visible_message(("<span class='love_mid'>[handler] squirms uncomfortably in [handler.p_their()] restraints.</span>"), \
					("<span class='love_extreme'>I feel [handler.handcuffed] rub uncomfortably against my skin.</span>"))
			if(arousal_value < ACTIVE_EJAC_THRESHOLD)
				SEND_SIGNAL(handler, COMSIG_SEX_ADJUST_AROUSAL, 0.25)


/datum/sex_session/proc/get_speed_multiplier()
	switch(speed)
		if(SEX_SPEED_LOW)
			return 1.0
		if(SEX_SPEED_MID)
			return 1.5
		if(SEX_SPEED_HIGH)
			return 2.0
		if(SEX_SPEED_EXTREME)
			return 2.5

/datum/sex_session/proc/get_stamina_cost_multiplier()
	switch(force)
		if(SEX_FORCE_LOW)
			return 1.0
		if(SEX_FORCE_MID)
			return 1.5
		if(SEX_FORCE_HIGH)
			return 2.0
		if(SEX_FORCE_EXTREME)
			return 2.5

/datum/sex_session/proc/adjust_speed(amt)
	speed = clamp(speed + amt, SEX_SPEED_MIN, SEX_SPEED_MAX)

/datum/sex_session/proc/adjust_force(amt)
	force = clamp(force + amt, SEX_FORCE_MIN, SEX_FORCE_MAX)

/datum/sex_session/proc/finished_check()
	if(!do_until_finished)
		return FALSE
	return TRUE



/datum/sex_session/proc/get_force_string()
	switch(force)
		if(SEX_FORCE_LOW)
			return "<font color='#eac8de'>GENTLE</font>"
		if(SEX_FORCE_MID)
			return "<font color='#e9a8d1'>FIRM</font>"
		if(SEX_FORCE_HIGH)
			return "<font color='#f05ee1'>ROUGH</font>"
		if(SEX_FORCE_EXTREME)
			return "<font color='#d146f5'>BRUTAL</font>"

/datum/sex_session/proc/get_speed_string()
	switch(speed)
		if(SEX_SPEED_LOW)
			return "<font color='#eac8de'>SLOW</font>"
		if(SEX_SPEED_MID)
			return "<font color='#e9a8d1'>STEADY</font>"
		if(SEX_SPEED_HIGH)
			return "<font color='#f05ee1'>QUICK</font>"
		if(SEX_SPEED_EXTREME)
			return "<font color='#d146f5'>UNRELENTING</font>"

/datum/sex_session/proc/get_manual_arousal_string()
	switch(manual_arousal)
		if(SEX_MANUAL_AROUSAL_DEFAULT)
			return "<font color='#eac8de'>NATURAL</font>"
		if(SEX_MANUAL_AROUSAL_UNAROUSED)
			return "<font color='#e9a8d1'>UNAROUSED</font>"
		if(SEX_MANUAL_AROUSAL_PARTIAL)
			return "<font color='#f05ee1'>PARTIALLY ERECT</font>"
		if(SEX_MANUAL_AROUSAL_FULL)
			return "<font color='#d146f5'>FULLY ERECT</font>"
/datum/sex_session/proc/get_generic_force_adjective()
	switch(force)
		if(SEX_FORCE_LOW)
			return pick(list("gently", "carefully", "tenderly", "gingerly", "delicately", "lazily"))
		if(SEX_FORCE_MID)
			return pick(list("firmly", "vigorously", "eagerly", "steadily", "intently"))
		if(SEX_FORCE_HIGH)
			return pick(list("roughly", "carelessly", "forcefully", "fervently", "fiercely"))
		if(SEX_FORCE_EXTREME)
			return pick(list("brutally", "violently", "relentlessly", "savagely", "mercilessly"))

/datum/sex_session/proc/spanify_force(string)
	switch(force)
		if(SEX_FORCE_LOW)
			return "<span class='love_low'>[string]</span>"
		if(SEX_FORCE_MID)
			return "<span class='love_mid'>[string]</span>"
		if(SEX_FORCE_HIGH)
			return "<span class='love_high'>[string]</span>"
		if(SEX_FORCE_EXTREME)
			return "<span class='love_extreme'>[string]</span>"

/datum/sex_session/proc/show_ui(selected_tab = "interactions")
	var/list/dat = list()
	var/list/arousal_data = list()
	SEND_SIGNAL(user, COMSIG_SEX_GET_AROUSAL, arousal_data)

	// CSS styling to match the dark red/brown color scheme
	dat += "<style>"
	dat += "body { background-color: #1a1010; color: #d4af8c; font-family: Arial, sans-serif; font-size: 12px; margin: 0; padding: 0; }"
	dat += ".main-container { background-color: #1a1010; min-height: 100vh; }"
	dat += ".header { background-color: #4a2c20; padding: 15px; border-bottom: 2px solid #8b6914; font-size: 16px; font-weight: bold; color: #d4af8c; }"
	dat += ".status-box { background-color: #2a1a15; border: 1px solid #4a2c20; margin: 10px; padding: 15px; }"
	dat += ".status-item { margin: 3px 0; font-size: 12px; color: #d4af8c; }"
	dat += ".progress-container { margin: 10px; }"
	dat += ".progress-bar { background-color: #2a1a15; height: 25px; margin: 2px 0; position: relative; overflow: hidden; border: 1px solid #4a2c20; }"
	dat += ".progress-fill-pleasure { background: linear-gradient(90deg, #ff69b4, #ff1493); height: 100%; transition: width 0.3s; }"
	dat += ".progress-fill-arousal { background: linear-gradient(90deg, #ff4444, #cc0000); height: 100%; transition: width 0.3s; }"
	dat += ".progress-fill-pain { background: linear-gradient(90deg, #666666, #333333); height: 100%; transition: width 0.3s; }"
	dat += ".progress-label { position: absolute; right: 10px; top: 50%; transform: translateY(-50%); font-weight: bold; color: #d4af8c; text-shadow: 1px 1px 2px rgba(0,0,0,0.8); }"
	dat += ".tabs { display: flex; background-color: #4a2c20; border-bottom: 1px solid #8b6914; }"
	dat += ".tab { padding: 12px 20px; background-color: #2a1a15; border-right: 1px solid #4a2c20; color: #d4af8c; cursor: pointer; text-decoration: none; }"
	dat += ".tab:hover { background-color: #3a2318; }"
	dat += ".tab.active { background-color: #4a2c20; color: #d4af8c; border-bottom: 2px solid #8b6914; }"
	dat += ".search-container { margin: 10px; display: flex; align-items: center; }"
	dat += ".search-icon { margin-right: 8px; font-size: 14px; }"
	dat += ".search-box { flex-grow: 1; padding: 8px; background-color: #2a1a15; border: 1px solid #4a2c20; color: #d4af8c; border-radius: 3px; margin-right: 5px; }"
	dat += ".search-btn { padding: 8px 12px; background-color: #8b6914; border: none; color: #d4af8c; cursor: pointer; border-radius: 3px; }"
	dat += ".search-btn:hover { background-color: #a07a1a; }"
	dat += ".section-header { background-color: #8b6914; color: #d4af8c; padding: 8px 15px; margin: 10px; font-weight: bold; }"
	dat += ".action-list { margin: 0 10px; }"
	dat += ".action-item { display: flex; align-items: center; margin: 2px 0; }"
	dat += ".action-button { flex-grow: 1; padding: 10px 15px; background-color: #4a2c20; color: #d4af8c; text-decoration: none; display: block; font-weight: bold; border: 1px solid #2a1a15; }"
	dat += ".action-button:hover { background-color: #5a3525; }"
	dat += ".action-button.blue { background-color: #3a4a5a; border-color: #5a6a7a; }"
	dat += ".action-button.blue:hover { background-color: #4a5a6a; }"
	dat += ".action-button.active { background-color: #8b6914 !important; color: #ffffff !important; border-color: #a07a1a !important; box-shadow: 0 0 5px rgba(139, 105, 20, 0.5) !important; }"
	dat += ".action-icons { display: flex; margin-left: 5px; }"
	dat += ".icon-btn { width: 25px; height: 25px; margin-left: 2px; background-color: #4a2c20; border: 1px solid #2a1a15; color: #d4af8c; text-align: center; line-height: 23px; cursor: pointer; font-size: 11px; text-decoration: none; }"
	dat += ".icon-btn:hover { background-color: #5a3525; }"
	dat += ".icon-btn.star { background-color: #8b6914; }"
	dat += ".icon-btn.stop { background-color: #cc4444; }"
	dat += ".linkOn { background-color: #8b6914 !important; color: #ffffff !important; }"
	dat += ".linkOff { background-color: #2a1a15 !important; color: #666666 !important; }"
	dat += ".tab-content { display: none; }"
	dat += ".tab-content.active { display: block; }"
	dat += ".control-section { margin: 10px; padding: 15px; background-color: #2a1a15; border: 1px solid #4a2c20; border-radius: 5px; }"
	dat += ".control-section h3 { color: #d4af8c; margin-top: 0; }"
	dat += ".control-row { margin: 15px 0; text-align: center; }"
	dat += ".control-btn { padding: 8px 15px; margin: 0 5px; background-color: #8b6914; color: #d4af8c; text-decoration: none; border-radius: 3px; }"
	dat += ".control-btn:hover { background-color: #a07a1a; }"
	dat += ".toggle-btn { padding: 8px 15px; background-color: #4a2c20; color: #d4af8c; text-decoration: none; border-radius: 3px; margin: 5px; border: 1px solid #2a1a15; }"
	dat += ".toggle-btn:hover { background-color: #5a3525; }"

	// Slider styles
	dat += ".slider-container { display: flex; align-items: center; justify-content: center; margin: 20px 0; }"
	dat += ".slider-label { min-width: 80px; text-align: right; margin-right: 15px; color: #d4af8c; font-weight: bold; }"
	dat += ".slider-wrapper { position: relative; width: 300px; height: 30px; margin: 0 15px; }"
	dat += ".slider-track { width: 100%; height: 6px; background-color: #2a1a15; border: 1px solid #4a2c20; border-radius: 3px; position: absolute; top: 50%; transform: translateY(-50%); }"
	dat += ".slider-fill { height: 100%; background: linear-gradient(90deg, #8b6914, #a07a1a); border-radius: 2px; transition: width 0.3s ease; }"
	dat += ".slider-notches { position: absolute; width: 100%; height: 30px; top: 0; }"
	dat += ".slider-notch { position: absolute; width: 2px; height: 15px; background-color: #4a2c20; top: 50%; transform: translate(-50%, -50%); cursor: pointer; }"
	dat += ".slider-notch:hover { background-color: #8b6914; }"
	dat += ".slider-notch.active { background-color: #a07a1a; height: 20px; }"
	dat += ".slider-value { min-width: 100px; text-align: left; margin-left: 15px; color: #d4af8c; font-style: italic; }"

	// Styles for kinks and notes tabs
	dat += ".kink-category { margin: 15px 0; }"
	dat += ".kink-category-title { background-color: #8b6914; color: #d4af8c; padding: 8px 15px; font-weight: bold; margin-bottom: 5px; }"
	dat += ".kink-item { background-color: #2a1a15; border: 1px solid #4a2c20; margin: 2px 0; padding: 10px; }"
	dat += ".kink-name { font-weight: bold; color: #d4af8c; margin-bottom: 5px; }"
	dat += ".kink-description { color: #b09070; font-size: 11px; margin-bottom: 5px; }"
	dat += ".kink-intensity { color: #ff69b4; font-size: 11px; }"
	dat += ".kink-notes { color: #a0a0a0; font-style: italic; font-size: 11px; margin-top: 5px; }"
	dat += ".kink-disabled { opacity: 0.5; }"
	dat += ".note-item { background-color: #2a1a15; border: 1px solid #4a2c20; margin: 5px 0; padding: 12px; }"
	dat += ".note-title { font-weight: bold; color: #d4af8c; margin-bottom: 8px; }"
	dat += ".note-content { color: #b09070; line-height: 1.4; margin-bottom: 8px; }"
	dat += ".note-meta { color: #808080; font-size: 10px; }"
	dat += ".no-data { text-align: center; color: #666666; padding: 20px; font-style: italic; }"
	dat += ".session-info { background-color: #2a1a15; border: 1px solid #4a2c20; margin: 10px; padding: 15px; }"
	dat += ".session-name-input { background-color: #2a1a15; border: 1px solid #4a2c20; color: #d4af8c; padding: 8px; margin: 5px 0; width: 200px; }"
	dat += ".participants-list { margin: 10px 0; }"
	dat += ".participant-item { background-color: #3a2a20; padding: 8px; margin: 3px 0; border-left: 3px solid #8b6914; }"
	dat += ".collective-toggle { background-color: #4a2c20; color: #d4af8c; border: 1px solid #2a1a15; padding: 10px 15px; cursor: pointer; margin: 10px 0; }"
	dat += ".collective-toggle.enabled { background-color: #8b6914; color: #ffffff; }"
	dat += ".prefs-container { display: flex; height: 400px; }"
	dat += ".prefs-left, .prefs-right { width: 50%; padding: 10px; }"
	dat += ".prefs-left { border-right: 1px solid #4a2c20; }"
	dat += ".prefs-header { background-color: #8b6914; color: #d4af8c; padding: 8px 15px; margin-bottom: 10px; font-weight: bold; }"
	dat += ".pref-category { margin: 15px 0; }"
	dat += ".pref-category-title { background-color: #4a2c20; color: #d4af8c; padding: 6px 12px; font-weight: bold; margin-bottom: 5px; }"
	dat += ".pref-item { background-color: #2a1a15; border: 1px solid #4a2c20; margin: 2px 0; padding: 8px; }"
	dat += ".pref-name { font-weight: bold; color: #d4af8c; margin-bottom: 3px; }"
	dat += ".pref-description { color: #b09070; font-size: 11px; margin-bottom: 5px; }"
	dat += ".pref-toggle { background-color: #4a2c20; color: #d4af8c; border: none; padding: 5px 10px; cursor: pointer; border-radius: 3px; }"
	dat += ".pref-toggle.enabled { background-color: #8b6914; color: #ffffff; }"
	dat += ".pref-toggle.disabled { background-color: #666666; cursor: not-allowed; }"

	dat += ".notes-sub-tabs { display: flex; background-color: #4a2c20; border-bottom: 1px solid #8b6914; margin-bottom: 15px; }"
	dat += ".notes-sub-tab { padding: 10px 15px; background-color: #2a1a15; border-right: 1px solid #4a2c20; color: #d4af8c; cursor: pointer; text-decoration: none; flex: 1; text-align: center; }"
	dat += ".notes-sub-tab:hover { background-color: #3a2318; }"
	dat += ".notes-sub-tab.active { background-color: #8b6914; color: #ffffff; }"
	dat += ".notes-tab-content { display: none; }"
	dat += ".notes-tab-content.active { display: block; }"
	dat += ".panel-header { border-bottom: 1px solid #4a2c20; padding-bottom: 10px; margin-bottom: 15px; }"
	dat += ".panel-header h3 { margin: 0 0 10px 0; color: #d4af8c; font-size: 16px; }"
	dat += ".note-form { background-color: #1a1010; border: 1px solid #4a2c20; padding: 15px; margin: 10px 0; border-radius: 5px; }"
	dat += ".note-input-title { width: 100%; padding: 8px; background-color: #2a1a15; border: 1px solid #4a2c20; color: #d4af8c; margin-bottom: 10px; }"
	dat += ".note-input-content { width: 100%; height: 80px; padding: 8px; background-color: #2a1a15; border: 1px solid #4a2c20; color: #d4af8c; resize: vertical; }"
	dat += ".note-form-buttons { margin-top: 10px; text-align: right; }"
	dat += ".note-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }"
	dat += ".note-buttons { display: flex; gap: 5px; }"
	dat += ".note-btn { padding: 4px 8px; background-color: #4a2c20; color: #d4af8c; text-decoration: none; border-radius: 3px; font-size: 11px; }"
	dat += ".note-btn:hover { background-color: #5a3525; }"
	dat += ".note-btn.remove-btn { background-color: #cc4444; }"
	dat += ".note-btn.remove-btn:hover { background-color: #dd5555; }"
	dat += ".note-item { background-color: #1a1010; border: 1px solid #4a2c20; margin: 5px 0; padding: 12px; cursor: pointer; transition: all 0.3s ease; }"
	dat += ".note-item:hover { background-color: #2a1a15; border-color: #8b6914; }"
	dat += ".note-item.expanded { background-color: #2a1a15; border-color: #8b6914; box-shadow: 0 2px 8px rgba(139, 105, 20, 0.3); }"
	dat += ".note-content { color: #b09070; line-height: 1.4; margin-bottom: 8px; max-height: 60px; overflow: hidden; transition: max-height 0.3s ease; }"
	dat += ".note-content.expanded { max-height: none; overflow: visible; }"

	dat += "</style>"

	dat += "<div class='main-container'>"

	// Dynamic Sex Info
	dat += get_sex_session_header()
	dat += get_sex_session_body()

	dat += "<div class='progress-container'>"
	var/max_arousal = MAX_AROUSAL
	var/current_arousal = arousal_data["arousal"] || 0
	var/pleasure_percent = min(100, (current_arousal / max_arousal) * 100)
	var/arousal_percent = min(100, (current_arousal / max_arousal) * 100)

	dat += "<div class='progress-bar'>"
	dat += "<div class='progress-fill-pleasure' style='width: [pleasure_percent]%;'></div>"
	dat += "<div class='progress-label'>Pleasure</div>"
	dat += "</div>"

	dat += "<div class='progress-bar'>"
	dat += "<div class='progress-fill-arousal' style='width: [arousal_percent]%;'></div>"
	dat += "<div class='progress-label'>Arousal</div>"
	dat += "</div>"

	dat += "<div class='progress-bar'>"
	dat += "<div class='progress-fill-pain' style='width: 0%;'></div>"
	dat += "<div class='progress-label'>Pain</div>"
	dat += "</div>"
	dat += "</div>"

	dat += "<div class='tabs'>"
	dat += "<a href='?src=[REF(src)];task=tab;tab=interactions' class='tab [selected_tab == "interactions" ? "active" : ""]'>Interactions</a>"
	dat += "<a href='?src=[REF(src)];task=tab;tab=genital' class='tab [selected_tab == "genital" ? "active" : ""]'>Controls</a>"
	dat += "<a href='?src=[REF(src)];task=tab;tab=session' class='tab [selected_tab == "session" ? "active" : ""]'>Session</a>"
	dat += "<a href='?src=[REF(src)];task=tab;tab=preferences' class='tab [selected_tab == "preferences" ? "active" : ""]'>Preferences</a>"
	dat += "<a href='?src=[REF(src)];task=tab;tab=kinks' class='tab [selected_tab == "kinks" ? "active" : ""]'>Kinks</a>"
	dat += "<a href='?src=[REF(src)];task=tab;tab=notes' class='tab [selected_tab == "notes" ? "active" : ""]'>Notes</a>"
	dat += "</div>"

	// Interactions Tab
	dat += "<div class='tab-content [selected_tab == "interactions" ? "active" : ""]' id='interactions-tab'>"
	dat += "<div class='search-container'>"
	dat += "<span class='search-icon'></span>"
	dat += "<input type='text' class='search-box' placeholder='Search for an interaction' id='searchBox'>"
	dat += "</div>"

	dat += "<div class='action-list'>"
	for(var/action_type in GLOB.sex_actions)
		var/datum/sex_action/action = SEX_ACTION(action_type)
		if(!action.shows_on_menu(user, target))
			continue

		dat += "<div class='action-item'>"
		var/button_class = "action-button"
		var/is_current = (current_action == action_type)
		var/can_perform = can_perform_action(action_type)

		if(action.name == "Salute")
			button_class += " blue"
		if(!can_perform)
			button_class += " linkOff"
		if(is_current)
			button_class += " active"

		dat += "<a class='[button_class]' href='?src=[REF(src)];task=action;action_type=[action_type];tab=[selected_tab]'>[action.name]</a>"

		dat += "<div class='action-icons'>"
		if(is_current)
			dat += "<a href='?src=[REF(src)];task=stop;tab=[selected_tab]' class='icon-btn stop'></a>"
		dat += "</div>"
		dat += "</div>"
	dat += "</div>"
	dat += "</div>"

	// Controls Tab
	dat += "<div class='tab-content [selected_tab == "genital" ? "active" : ""]' id='genital-tab'>"
	dat += "<div class='control-section'>"
	dat += "<h3>Speed & Force Controls</h3>"

	var/current_speed = get_current_speed()
	var/current_force = get_current_force()
	var/speed_name = get_speed_string()
	var/force_name = get_force_string()
	var/manual_arousal_name = get_manual_arousal_string()

	// Speed slider
	dat += "<div class='slider-container'>"
	dat += "<div class='slider-label'>Speed:</div>"
	dat += "<div class='slider-wrapper'>"
	dat += "<div class='slider-track'>"
	dat += "<div class='slider-fill' style='width: [((current_speed - SEX_SPEED_MIN) / (SEX_SPEED_MAX - SEX_SPEED_MIN)) * 100]%;'></div>"
	dat += "</div>"
	dat += "<div class='slider-notches'>"
	for(var/i = SEX_SPEED_MIN; i <= SEX_SPEED_MAX; i++)
		var/notch_position = ((i - SEX_SPEED_MIN) / (SEX_SPEED_MAX - SEX_SPEED_MIN)) * 100
		var/notch_class = (i <= current_speed) ? "slider-notch active" : "slider-notch"
		dat += "<a href='?src=[REF(src)];task=set_speed;value=[i];tab=[selected_tab]' class='[notch_class]' style='left: [notch_position]%;'></a>"
	dat += "</div>"
	dat += "</div>"
	dat += "<div class='slider-value'>[speed_name]</div>"
	dat += "</div>"

	// Force slider
	dat += "<div class='slider-container'>"
	dat += "<div class='slider-label'>Force:</div>"
	dat += "<div class='slider-wrapper'>"
	dat += "<div class='slider-track'>"
	dat += "<div class='slider-fill' style='width: [((current_force - SEX_FORCE_MIN) / (SEX_FORCE_MAX - SEX_FORCE_MIN)) * 100]%;'></div>"
	dat += "</div>"
	dat += "<div class='slider-notches'>"
	for(var/i = SEX_FORCE_MIN; i <= SEX_FORCE_MAX; i++)
		var/notch_position = ((i - SEX_FORCE_MIN) / (SEX_FORCE_MAX - SEX_FORCE_MIN)) * 100
		var/notch_class = (i <= current_force) ? "slider-notch active" : "slider-notch"
		dat += "<a href='?src=[REF(src)];task=set_force;value=[i];tab=[selected_tab]' class='[notch_class]' style='left: [notch_position]%;'></a>"
	dat += "</div>"
	dat += "</div>"
	dat += "<div class='slider-value'>[force_name]</div>"
	dat += "</div>"

	if(user.getorganslot(ORGAN_SLOT_PENIS))
		dat += "<div class='control-row'>"
		dat += "<a href='?src=[REF(src)];task=manual_arousal_down;tab=[selected_tab]' class='control-btn'><</a>"
		dat += " [manual_arousal_name] "
		dat += "<a href='?src=[REF(src)];task=manual_arousal_up;tab=[selected_tab]' class='control-btn'>></a>"
		dat += "</div>"

	dat += "<div class='control-row'>"
	dat += "<a href='?src=[REF(src)];task=toggle_finished;tab=[selected_tab]' class='toggle-btn'>[do_until_finished ? "UNTIL IM FINISHED" : "UNTIL I STOP"]</a>"
	dat += "</div>"

	dat += "<div class='control-row'>"
	dat += "<a href='?src=[REF(src)];task=set_arousal;tab=[selected_tab]' class='toggle-btn'>SET AROUSAL</a>"
	dat += "<a href='?src=[REF(src)];task=freeze_arousal;tab=[selected_tab]' class='toggle-btn'>[arousal_data["frozen"] ? "UNFREEZE AROUSAL" : "FREEZE AROUSAL"]</a>"
	dat += "</div>"
	dat += "</div>"
	dat += "</div>"

	// Session Tab
	dat += "<div class='tab-content [selected_tab == "session" ? "active" : ""]' id='session-tab'>"
	dat += get_session_tab_content()
	dat += "</div>"

	// Preferences Tab
	dat += "<div class='tab-content [selected_tab == "preferences" ? "active" : ""]' id='preferences-tab'>"
	dat += get_preferences_tab_content()
	dat += "</div>"

	// Kinks Tab
	dat += "<div class='tab-content [selected_tab == "kinks" ? "active" : ""]' id='kinks-tab'>"
	dat += get_kinks_tab_content()
	dat += "</div>"

	// Notes Tab
	dat += "<div class='tab-content [selected_tab == "notes" ? "active" : ""]' id='notes-tab'>"
	dat += get_notes_tab_content()
	dat += "</div>"

	// JavaScript for search functionality and tab management
	dat += "<script>"

	dat += "function switchNotesTab(tabName) {"
	dat += "  var contents = document.querySelectorAll('.notes-tab-content');"
	dat += "  contents.forEach(function(content) {"
	dat += "    content.classList.remove('active');"
	dat += "  });"
	dat += "  "
	dat += "  var tabs = document.querySelectorAll('.notes-sub-tab');"
	dat += "  tabs.forEach(function(tab) {"
	dat += "    tab.classList.remove('active');"
	dat += "  });"
	dat += "  "
	dat += "  if (tabName === 'self') {"
	dat += "    document.getElementById('selfNotesContent').classList.add('active');"
	dat += "    document.getElementById('selfTab').classList.add('active');"
	dat += "  } else if (tabName === 'target') {"
	dat += "    document.getElementById('targetNotesContent').classList.add('active');"
	dat += "    document.getElementById('targetTab').classList.add('active');"
	dat += "  }"
	dat += "}"

	dat += "function stopAction() { window.location.href = '?src=[REF(src)];task=stop;tab=[selected_tab]'; }"
	dat += "function updateSessionName() {"
	dat += "  var nameInput = document.getElementById('sessionNameInput');"
	dat += "  if(nameInput) {"
	dat += "    var newName = nameInput.value.trim();"
	dat += "    if(newName) {"
	dat += "      window.location.href = '?src=[REF(src)];task=update_session_name;name=' + encodeURIComponent(newName) + ';tab=session';"
	dat += "    }"
	dat += "  }"
	dat += "}"
	dat += "document.addEventListener('DOMContentLoaded', function() {"
	dat += "  var searchBox = document.getElementById('searchBox');"
	dat += "  if(searchBox) {"
	dat += "    searchBox.addEventListener('input', function() {"
	dat += "      var filter = this.value.toLowerCase();"
	dat += "      var items = document.querySelectorAll('.action-item');"
	dat += "      items.forEach(function(item) {"
	dat += "        var text = item.textContent.toLowerCase();"
	dat += "        item.style.display = text.includes(filter) ? 'flex' : 'none';"
	dat += "      });"
	dat += "    });"
	dat += "  }"
	dat += "});"

	dat += "function toggleSelfNoteForm() {"
	dat += "  var form = document.getElementById('selfNoteForm');"
	dat += "  var btn = document.getElementById('addSelfNoteBtn');"
	dat += "  if (form.style.display === 'none' || form.style.display === '') {"
	dat += "    form.style.display = 'block';"
	dat += "    btn.textContent = 'Cancel';"
	dat += "    document.getElementById('selfNoteTitle').focus();"
	dat += "  } else {"
	dat += "    form.style.display = 'none';"
	dat += "    btn.textContent = 'Add Note About Yourself';"
	dat += "    clearSelfNoteForm();"
	dat += "  }"
	dat += "}"

	dat += "function submitSelfNote() {"
	dat += "  var title = document.getElementById('selfNoteTitle').value.trim();"
	dat += "  var content = document.getElementById('selfNoteContent').value.trim();"
	dat += "  if (!title || !content) {"
	dat += "    alert('Please fill in both title and content.');"
	dat += "    return;"
	dat += "  }"
	dat += "  window.location.href = '?src=[REF(src)];task=submit_self_note;title=' + encodeURIComponent(title) + ';content=' + encodeURIComponent(content) + ';tab=notes';"
	dat += "}"

	dat += "function cancelSelfNote() {"
	dat += "  var form = document.getElementById('selfNoteForm');"
	dat += "  var btn = document.getElementById('addSelfNoteBtn');"
	dat += "  form.style.display = 'none';"
	dat += "  btn.textContent = 'Add Note About Yourself';"
	dat += "  clearSelfNoteForm();"
	dat += "}"

	dat += "function clearSelfNoteForm() {"
	dat += "  document.getElementById('selfNoteTitle').value = '';"
	dat += "  document.getElementById('selfNoteContent').value = '';"
	dat += "}"

	dat += "</script>"

	dat += "</div>"

	var/datum/browser/popup = new(user, "sexcon[our_sex_id]", "<center>Sate Desire</center>", 750, 650)
	popup.set_content(dat.Join())
	popup.open()
	return

/datum/sex_session/proc/get_session_tab_content()
	var/list/content = list()

	content += "<div class='session-info'>"

	// Session name editing
	var/session_name = collective?.collective_display_name || "Private Session"
	content += "<div style='margin: 10px 0;'>"
	content += "<label style='color: #d4af8c; font-weight: bold;'>Session Name:</label><br>"
	content += "<input type='text' id='sessionNameInput' class='session-name-input' value='[session_name]' placeholder='Enter session name...'>"
	content += "<button onclick='updateSessionName()' class='control-btn' style='margin-left: 5px;'>Update</button>"
	content += "</div>"

	// Participants list
	content += "<div class='participants-list'>"
	content += "<h4 style='color: #d4af8c;'>Participants:</h4>"

	var/list/participants = list(user, target)
	if(collective)
		participants = collective.involved_mobs

	for(var/mob/living/carbon/human/participant in participants)
		var/display_name = participant.get_face_name() || participant.name
		var/is_you = (participant == user) ? " (You)" : ""
		content += "<div class='participant-item'>[display_name][is_you]</div>"

	content += "</div>"

	// Collective messaging toggle
	var/collective_enabled = collective ? TRUE : FALSE
	var/any_has_flag = any_has_erp_pref(participants, /datum/erp_preference/boolean/subtle_session_messages)

	var/toggle_class = "collective-toggle"
	if(collective_enabled && any_has_flag)
		toggle_class += " enabled"

	content += "<div class='[toggle_class]' onclick=\"window.location.href='?src=[REF(src)];task=toggle_subtle;tab=session'\">"
	content += "<strong>Subtle Messaging:</strong> [collective_enabled && any_has_flag ? "ENABLED" : "DISABLED"]<br>"
	content += "<small>Allows group chat between all session participants</small>"
	content += "</div>"

	content += "</div>"

	return content.Join("")

/datum/sex_session/proc/get_preferences_tab_content()
	var/list/content = list()

	content += "<div class='prefs-container'>"

	// Left side - User's preferences (editable)
	content += "<div class='prefs-left'>"
	content += "<div class='prefs-header'>Your Preferences</div>"
	content += get_erp_preferences_display(user, TRUE)
	content += "</div>"

	// Right side - Target's preferences (read-only)
	content += "<div class='prefs-right'>"
	content += "<div class='prefs-header'>[target.name]'s Preferences</div>"
	content += get_erp_preferences_display(target, FALSE)
	content += "</div>"

	content += "</div>"

	return content.Join("")

/datum/sex_session/proc/get_erp_preferences_display(mob/living/carbon/human/character, editable = FALSE)
	var/list/content = list()

	if(!character.client?.prefs)
		content += "<div class='no-data'>No preferences available</div>"
		return content.Join("")

	var/datum/preferences/prefs = character.client.prefs
	if(!prefs.erp_preferences)
		prefs.erp_preferences = list()

	// Group preferences by category
	var/list/prefs_by_category = list()

	for(var/datum/erp_preference/pref_type as anything in subtypesof(/datum/erp_preference))
		if(is_abstract(pref_type))
			continue
		var/datum/erp_preference/pref = new pref_type()
		var/category = pref.category

		if(!prefs_by_category[category])
			prefs_by_category[category] = list()

		prefs_by_category[category][pref_type] = pref

	// Display preferences by category
	for(var/category in prefs_by_category)
		content += "<div class='pref-category'>"
		content += "<div class='pref-category-title'>[category]</div>"

		for(var/pref_type in prefs_by_category[category])
			var/datum/erp_preference/pref = prefs_by_category[category][pref_type]

			content += "<div class='pref-item'>"
			content += "<div class='pref-name'>[pref.name]</div>"

			if(pref.description)
				content += "<div class='pref-description'>[pref.description]</div>"

			// Let the preference datum handle its own UI
			content += pref.show_session_ui(prefs, editable, src)

			content += "</div>"

		content += "</div>"

	return content.Join("")


/datum/sex_session/Topic(href, href_list)
	if(usr != user)
		return
	var/list/arousal_data = SEND_SIGNAL(user, COMSIG_SEX_GET_AROUSAL)
	var/selected_tab = href_list["tab"] || "interactions"

	switch(href_list["task"])
		if("tab")
			selected_tab = href_list["tab"] || "interactions"
			show_ui(selected_tab)
			return
		if("action")
			var/action_path = text2path(href_list["action_type"])
			var/datum/sex_action/action = SEX_ACTION(action_path)
			if(!action)
				show_ui(selected_tab)
				return
			try_start_action(action_path)
			return // Don't refresh main UI immediately
		if("stop")
			try_stop_current_action()
		if("set_speed")
			var/new_speed = text2num(href_list["value"])
			if(new_speed >= SEX_SPEED_MIN && new_speed <= SEX_SPEED_MAX)
				set_current_speed(new_speed)
		if("set_force")
			var/new_force = text2num(href_list["value"])
			if(new_force >= SEX_FORCE_MIN && new_force <= SEX_FORCE_MAX)
				set_current_force(new_force)
		if("speed_up")
			adjust_speed(1)
		if("speed_down")
			adjust_speed(-1)
		if("force_up")
			adjust_force(1)
		if("force_down")
			adjust_force(-1)
		if("toggle_finished")
			do_until_finished = !do_until_finished
		if("set_arousal")
			var/amount = input(user, "Value above [MAX_AROUSAL || 120] will immediately cause orgasm!", "Set Arousal", arousal_data["arousal"]) as num
			SEND_SIGNAL(user, COMSIG_SEX_SET_AROUSAL, amount)
		if("freeze_arousal")
			SEND_SIGNAL(user, COMSIG_SEX_FREEZE_AROUSAL)

		if("update_session_name")
			var/new_name = url_decode(href_list["name"])
			if(new_name && collective)
				collective.collective_display_name = new_name
				collective.update_collective_tab()
				to_chat(user, "<span class='notice'>Session name updated to '[new_name]'</span>")

		if("toggle_subtle")
			collective.toggle_subtle()

		// Generic preference handler - delegates to the preference datum
		if("handle_pref")
			var/pref_type = text2path(href_list["pref_type"])
			if(!pref_type || !ispath(pref_type, /datum/erp_preference))
				show_ui(selected_tab)
				return

			var/datum/erp_preference/pref = new pref_type()
			if(!user.client?.prefs)
				show_ui(selected_tab)
				return

			// Let the preference handle its own topic
			var/handled = pref.handle_session_topic(user, href_list, user.client.prefs, src)
			if(!handled)
				to_chat(user, "<span class='warning'>Unknown preference action.</span>")

		if("submit_self_note")
			var/note_title = url_decode(href_list["title"])
			var/note_content = url_decode(href_list["content"])

			if(!note_title || !note_content)
				to_chat(user, "<span class='warning'>Both title and content are required.</span>")
				show_ui(selected_tab)
				return

			var/character_slot = get_character_slot(user)

			var/list/existing_notes = get_player_notes_about(user.ckey, user.ckey, character_slot)
			if(existing_notes[note_title])
				to_chat(user, "<span class='warning'>A note with that title already exists. Please choose a different title.</span>")
				show_ui(selected_tab)
				return

			if(set_player_note_about(user.ckey, target.ckey, note_title, note_content, character_slot))
				to_chat(user, "<span class='notice'>Note '[note_title]' saved successfully.</span>")
			else
				to_chat(user, "<span class='warning'>Failed to save note. Please try again.</span>")

		if("edit_self_note")
			var/note_title = url_decode(href_list["note_title"])
			if(!note_title)
				show_ui(selected_tab)
				return

			var/character_slot = get_character_slot(user)
			var/list/notes = get_player_notes_about(user.ckey, user.ckey, character_slot)

			if(!notes[note_title])
				to_chat(user, "<span class='warning'>Note not found.</span>")
				show_ui(selected_tab)
				return

			var/old_content = notes[note_title]["content"]
			var/new_content = input(user, "Edit your self-note:", "Edit Note", old_content) as message|null

			if(!new_content)
				show_ui(selected_tab)
				return

			set_player_note_about(user.ckey, user.ckey, note_title, new_content, character_slot)
			to_chat(user, "<span class='notice'>Self-note '[note_title]' updated.</span>")

		if("remove_self_note")
			var/note_title = url_decode(href_list["note_title"])
			if(!note_title)
				show_ui(selected_tab)
				return

			var/character_slot = get_character_slot(user)
			var/datum/save_manager/SM = get_save_manager(user.ckey)
			if(SM)
				var/save_name = "character_[character_slot]_notes"
				var/list/all_notes = SM.get_data(save_name, "partner_notes", list())
				if(all_notes[ckey(user.ckey)] && all_notes[ckey(user.ckey)][note_title])
					all_notes[ckey(user.ckey)] -= note_title
					SM.set_data(save_name, "partner_notes", all_notes)
					to_chat(user, "<span class='notice'>Self-note '[note_title]' removed.</span>")
				else
					to_chat(user, "<span class='warning'>Note not found.</span>")

	show_ui(selected_tab)

/datum/sex_session/proc/get_sex_session_header()
	if(user == target)
		return "<div class='header'>Interacting with yourself...</div>"
	else
		return "<div class='header'>Interacting with [target.name]...</div>"

/datum/sex_session/proc/get_sex_session_body()
	var/list/data = list()
	data += "<div class='status-box'>"
	data += "<div>You... </div>"
	data += user.return_character_information()
	data += "</div>"
	return data.Join("")

/datum/sex_session/proc/get_kinks_tab_content()
	var/list/content = list()
	var/datum/preferences/prefs = target.client?.prefs
	if(!prefs || !prefs.erp_preferences)
		content += "<div class='no-data'>No kink preferences found for this character.</div>"
		return content.Join("")

	var/list/kink_prefs = prefs.erp_preferences["kinks"]
	if(!kink_prefs || !length(kink_prefs))
		content += "<div class='no-data'>No kink preferences found for this character.</div>"
		return content.Join("")

	var/list/kinks_by_category = list()
	for(var/kink_name in kink_prefs)
		var/list/kink_data = kink_prefs[kink_name]
		if(!kink_data["enabled"])
			continue
		var/datum/kink/base_kink = GLOB.available_kinks[kink_name]
		if(!base_kink)
			continue
		var/category = base_kink.category
		if(!kinks_by_category[category])
			kinks_by_category[category] = list()
		kinks_by_category[category][kink_name] = kink_data

	for(var/category in kinks_by_category)
		content += "<div class='kink-category'>"
		content += "<div class='kink-category-title'>[category]</div>"
		for(var/kink_name in kinks_by_category[category])
			var/list/kink_data = kinks_by_category[category][kink_name]
			var/datum/kink/base_kink = GLOB.available_kinks[kink_name]
			var/kink_class = "kink-item"
			if(!kink_data["enabled"])
				kink_class += " kink-disabled"
			content += "<div class='[kink_class]'>"
			content += "<div class='kink-name'>[kink_name]</div>"
			content += "<div class='kink-description'>[base_kink.description]</div>"
			var/intensity_text = get_kink_intensity_text(kink_data["intensity"])
			content += "<div class='kink-intensity'>Intensity: [intensity_text]</div>"
			if(kink_data["notes"])
				content += "<div class='kink-notes'>Notes: [kink_data["notes"]]</div>"
			content += "</div>"
		content += "</div>"
	return content.Join("")

/proc/get_kink_intensity_text(intensity)//this still needs to be made into a global somewhere numbers are just easier to work with
	switch(intensity)
		if(1) return "Very Light"
		if(2) return "Light"
		if(3) return "Moderate"
		if(4) return "Intense"
		if(5) return "Very Intense"
	return "Unknown"

/datum/sex_session/proc/get_notes_tab_content()
	var/list/content = list()
	var/character_slot = get_character_slot(user)

	// Get your own self-notes and the target's self-notes (shared with you)
	var/list/self_notes = get_player_notes_about(user.ckey, user.ckey, character_slot) // Your notes about yourself
	var/target_character_slot = get_character_slot(target)
	var/list/target_self_notes = get_player_notes_about(target.ckey, target.ckey, target_character_slot) // Target's notes about themselves

	// Sub-tabs for notes
	content += "<div class='notes-sub-tabs'>"
	content += "<a href='javascript:void(0)' class='notes-sub-tab active' onclick='switchNotesTab(\"self\")' id='selfTab'>Your Notes (Shared)</a>"
	content += "<a href='javascript:void(0)' class='notes-sub-tab' onclick='switchNotesTab(\"target\")' id='targetTab'>[target.name]'s Notes</a>"
	content += "</div>"

	// Self notes content (initially visible)
	content += "<div class='notes-tab-content active' id='selfNotesContent'>"
	content += "<div class='panel-header'>"
	content += "<h3>Your Notes (Shared with [target.name])</h3>"
	content += "<button onclick='toggleSelfNoteForm()' class='control-btn' id='addSelfNoteBtn'>Add Note About Yourself</button>"
	content += "</div>"

	// Hidden form for self notes
	content += "<div id='selfNoteForm' class='note-form' style='display: none;'>"
	content += "<h4>Add Note About Yourself</h4>"
	content += "<input type='text' id='selfNoteTitle' placeholder='Note title...' class='note-input-title'>"
	content += "<textarea id='selfNoteContent' placeholder='Write your note here...' class='note-input-content'></textarea>"
	content += "<div class='note-form-buttons'>"
	content += "<button onclick='submitSelfNote()' class='control-btn'>Save Note</button>"
	content += "<button onclick='cancelSelfNote()' class='control-btn' style='background-color: #666666; margin-left: 5px;'>Cancel</button>"
	content += "</div>"
	content += "</div>"

	// Display self notes
	if(!length(self_notes))
		content += "<div class='no-data'>"
		content += "You haven't written any notes about yourself yet."
		content += "</div>"
	else
		for(var/note_title in self_notes)
			var/list/note_data = self_notes[note_title]
			content += "<div class='note-item'>"
			content += "<div class='note-header'>"
			content += "<div class='note-title'>[note_title]</div>"
			content += "<div class='note-buttons'>"
			content += "<a href='?src=[REF(src)];task=edit_self_note;note_title=[url_encode(note_title)];tab=notes' class='note-btn' onclick='event.stopPropagation()'>Edit</a>"
			content += "<a href='?src=[REF(src)];task=remove_self_note;note_title=[url_encode(note_title)];tab=notes' class='note-btn remove-btn' onclick='event.stopPropagation(); return confirm(\"Remove note: [note_title]?\")'>Remove</a>"
			content += "</div>"
			content += "</div>"
			content += "<div class='note-content'>[note_data["content"]]</div>"
			var/created_time = note_data["created"]
			var/modified_time = note_data["last_modified"]
			var/time_text = "Created: [time2text(created_time, "MM/DD/YY hh:mm")]"
			if(modified_time != created_time)
				time_text += " | Modified: [time2text(modified_time, "MM/DD/YY hh:mm")]"
			content += "<div class='note-meta'>[time_text]</div>"
			content += "</div>"

	content += "</div>" // End self notes content

	// Target's self-notes content (initially hidden)
	content += "<div class='notes-tab-content' id='targetNotesContent'>"
	content += "<div class='panel-header'>"
	content += "<h3>[target.name]'s Notes (About Themselves)</h3>"
	content += "</div>"

	// Display target's self-notes (read-only)
	if(!length(target_self_notes))
		content += "<div class='no-data'>"
		content += "[target.name] hasn't shared any notes about themselves yet."
		content += "</div>"
	else
		for(var/note_title in target_self_notes)
			var/list/note_data = target_self_notes[note_title]
			content += "<div class='note-item''>"
			content += "<div class='note-header'>"
			content += "<div class='note-title'>[note_title]</div>"
			content += "</div>"
			content += "<div class='note-content'>[note_data["content"]]</div>"
			var/created_time = note_data["created"]
			var/modified_time = note_data["last_modified"]
			var/time_text = "Created: [time2text(created_time, "MM/DD/YY hh:mm")]"
			if(modified_time != created_time)
				time_text += " | Modified: [time2text(modified_time, "MM/DD/YY hh:mm")]"
			content += "<div class='note-meta'>[time_text]</div>"
			content += "</div>"

	content += "</div>" // End target notes content

	return content.Join("")

/datum/sex_session/proc/get_current_speed()
	return speed || SEX_SPEED_LOW

/datum/sex_session/proc/get_current_force()
	return force || SEX_FORCE_LOW

/datum/sex_session/proc/set_current_speed(new_speed)
	speed = clamp(new_speed, SEX_SPEED_MIN, SEX_SPEED_MAX)

/datum/sex_session/proc/set_current_force(new_force)
	force = clamp(new_force, SEX_FORCE_MIN, SEX_FORCE_MAX)

/datum/sex_session/proc/get_character_slot(mob/target_mob)
	return target_mob?.client?.prefs.current_slot || 1


/proc/get_player_notes_about(viewer_ckey, target_ckey, character_slot = 1)
	var/datum/save_manager/SM = get_save_manager(viewer_ckey)
	if(!SM)
		return list()

	var/save_name = "character_[character_slot]_notes"
	var/list/all_notes = SM.get_data(save_name, "partner_notes", list())

	return all_notes[ckey(target_ckey)] || list()

/proc/set_player_note_about(writer_ckey, target_ckey, note_title, note_content, character_slot = 1)
	var/datum/save_manager/SM = get_save_manager(writer_ckey)
	if(!SM)
		return FALSE

	var/save_name = "character_[character_slot]_notes"
	var/list/all_notes = SM.get_data(save_name, "partner_notes", list())

	if(!all_notes[ckey(target_ckey)])
		all_notes[ckey(target_ckey)] = list()

	all_notes[ckey(target_ckey)][note_title] = list(
		"content" = note_content,
		"created" = world.realtime,
		"last_modified" = world.realtime
	)

	return SM.set_data(save_name, "partner_notes", all_notes)
