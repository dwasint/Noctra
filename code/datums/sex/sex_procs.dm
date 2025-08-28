/mob/living/carbon/human/proc/get_highest_grab_state_on(mob/living/carbon/human/victim)
	var/grabstate = null
	if(r_grab && r_grab.grabbed == victim)
		if(grabstate == null || r_grab.grab_state > grabstate)
			grabstate = r_grab.grab_state
	if(l_grab && l_grab.grabbed == victim)
		if(grabstate == null || l_grab.grab_state > grabstate)
			grabstate = l_grab.grab_state
	return grabstate

/proc/do_thrust_animate(atom/movable/user, atom/movable/target, pixels = 4, time = 2.7)
	var/oldx = user.pixel_x
	var/oldy = user.pixel_y
	var/target_x = oldx
	var/target_y = oldy
	var/dir = get_dir(user, target)
	if(user.loc == target.loc)
		dir = user.dir
	switch(dir)
		if(NORTH)
			target_y += pixels
		if(SOUTH)
			target_y -= pixels
		if(WEST)
			target_x -= pixels
		if(EAST)
			target_x += pixels

	animate(user, pixel_x = target_x, pixel_y = target_y, time = time)
	animate(pixel_x = oldx, pixel_y = oldy, time = time)

/mob/living/proc/start_sex_session(mob/living/target)
	if(!target)
		return
	var/datum/sex_session/old_session = get_sex_session(src, target)
	if(old_session)
		old_session.show_ui()
		return


	var/datum/sex_session/session = new /datum/sex_session(src, target)
	LAZYADD(GLOB.sex_sessions, session)
	session.show_ui()
	return session

/mob/living/carbon/human/proc/make_sucking_noise()
	if(gender == FEMALE)
		playsound(src, pick('sound/misc/mat/girlmouth (1).ogg','sound/misc/mat/girlmouth (2).ogg'), 25, TRUE, ignore_walls = FALSE)
	else
		playsound(src, pick('sound/misc/mat/guymouth (2).ogg','sound/misc/mat/guymouth (3).ogg','sound/misc/mat/guymouth (4).ogg','sound/misc/mat/guymouth (5).ogg'), 35, TRUE, ignore_walls = FALSE)

/mob/living/proc/can_do_sex()
	return TRUE

/mob/living/carbon/human/MiddleMouseDrop_T(atom/movable/dragged, mob/living/user)
	var/mob/living/carbon/human/target = src

	if(user.mmb_intent)
		return ..()
	if(!istype(dragged))
		return
	// Need to drag yourself to the target.
	if(dragged != user)
		return
	if(!user.can_do_sex())
		to_chat(user, "<span class='warning'>I can't do this.</span>")
		return

	if(!user.start_sex_session(target))
		to_chat(user, "<span class='warning'>I'm already sexing.</span>")
		return

/proc/get_sex_session(mob/giver, mob/taker)
	for(var/datum/sex_session/session as anything in GLOB.sex_sessions)
		if(session.user != giver)
			continue
		if(session.target != taker)
			continue
		return session
	return null

/mob/living/proc/has_hands()
	return TRUE

/mob/living/proc/has_mouth()
	return TRUE

/mob/living/proc/mouth_is_free()
	return !is_mouth_covered()

/mob/living/proc/foot_is_free()
	return is_barefoot()

/mob/living/proc/is_barefoot()
	for(var/item_slot in DEFAULT_SLOT_PRIORITY)
		var/obj/item/clothing = get_item_by_slot(item_slot)
		if(!clothing) // Don't have this slot or not wearing anything in it
			continue
		if(clothing.body_parts_covered & FEET)
			return FALSE
	// If didn't stop before, then we're barefoot
	return TRUE

/mob/living/carbon/human/has_mouth()
	return get_bodypart(BODY_ZONE_HEAD)

/mob/living/carbon/human/has_hands() // technically should be an and but i'll replicate original behavior
	return get_bodypart(BODY_ZONE_L_ARM) || get_bodypart(BODY_ZONE_R_ARM)

/mob/living/carbon/human/Initialize()
	. = ..()
	AddComponent(/datum/component/arousal)

/mob/living/proc/return_character_information()
	var/list/data = list()
	if(has_hands())
		data += "<div>...have hands.</div>"
	if(has_mouth())
		data += "<div>...have a mouth, which is [mouth_is_free() ? "uncovered" : "covered"].</div>"
	return data

/mob/living/proc/get_active_precise_hand()
	var/active_hand = BODY_ZONE_PRECISE_L_HAND
	if(active_hand_index != 1)
		active_hand = BODY_ZONE_PRECISE_R_HAND
	return active_hand

/mob/proc/check_handholding()
	return

/mob/living/carbon/human/check_handholding()
	if(pulledby && pulledby != src)
		var/obj/item/bodypart/LH
		var/obj/item/bodypart/RH
		LH = get_bodypart(BODY_ZONE_PRECISE_L_HAND)
		RH = get_bodypart(BODY_ZONE_PRECISE_R_HAND)
		if(LH || RH)
			for(var/obj/item/grabbing/G in src.grabbedby)
				if(G.limb_grabbed == LH || G.limb_grabbed == RH)
					return TRUE

/proc/return_sessions_with_user(mob/living/carbon/human/user)
	var/list/sessions = list()
	for(var/datum/sex_session/session in GLOB.sex_sessions)
		if(user != session.target && user != session.user)
			continue
		sessions |= session
	return sessions

/proc/return_highest_priority_action(list/sessions = list(), mob/living/carbon/human/user)
	var/datum/sex_session/highest_session
	for(var/datum/sex_session/session in sessions)
		if(!highest_session)
			highest_session = session
			continue
		if(user == session.target)
			if(session.current_action.target_priority > highest_session.current_action.target_priority)
				highest_session = session
				continue
		if(user == session.user)
			if(session.current_action.user_priority > highest_session.current_action.user_priority)
				highest_session = session
				continue
	return highest_session

/mob/proc/get_erp_pref(pref_type)
	if(!client?.prefs)
		return FALSE

	if(!ispath(pref_type, /datum/erp_preference))
		return FALSE

	var/datum/erp_preference/pref = new pref_type()
	return pref.get_value(client.prefs)

/mob/proc/set_erp_pref(pref_type, value)
	if(!client?.prefs)
		return FALSE

	if(!ispath(pref_type, /datum/erp_preference))
		return FALSE

	var/datum/erp_preference/pref = new pref_type()
	pref.set_value(client.prefs, value)
	client.prefs.save_preferences()
	return TRUE

/mob/proc/has_erp_pref(pref_type)
	return get_erp_pref(pref_type) == TRUE

/mob/proc/get_all_erp_prefs()
	if(!client?.prefs)
		return list()

	var/list/prefs_by_category = list()

	for(var/pref_type in subtypesof(/datum/erp_preference))
		var/datum/erp_preference/pref = new pref_type()
		var/category = pref.category
		var/value = pref.get_value(client.prefs)

		if(!prefs_by_category[category])
			prefs_by_category[category] = list()

		prefs_by_category[category][pref_type] = list(
			"name" = pref.name,
			"description" = pref.description,
			"value" = value,
			"pref_object" = pref
		)

	return prefs_by_category

/proc/any_has_erp_pref(list/mobs, pref_type)
	for(var/mob/M in mobs)
		if(M.has_erp_pref(pref_type))
			return TRUE
	return FALSE

/proc/all_have_erp_pref(list/mobs, pref_type)
	for(var/mob/M in mobs)
		if(!M.has_erp_pref(pref_type))
			return FALSE
	return TRUE
