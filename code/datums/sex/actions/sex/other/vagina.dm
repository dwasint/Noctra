/datum/sex_action/sex/other/vagina
	name = "Ride them"
	hole_id = "vagina"
	stamina_cost = 1.0
	aggro_grab_instead_same_tile = FALSE

/datum/sex_action/sex/other/vagina/shows_on_menu(mob/living/carbon/human/user, mob/living/carbon/human/target)
	if(user == target)
		return FALSE
	if(!user.getorganslot(ORGAN_SLOT_VAGINA))
		return FALSE
	if(!target.getorganslot(ORGAN_SLOT_PENIS))
		return FALSE
	return TRUE

/datum/sex_action/sex/other/vagina/can_perform(mob/living/carbon/human/user, mob/living/carbon/human/target)
	. = ..()
	if(!.)
		return FALSE
	if(user == target)
		return FALSE
	if(check_sex_lock(target, ORGAN_SLOT_PENIS))
		return FALSE
	if(!check_location_accessible(user, user, BODY_ZONE_PRECISE_GROIN, TRUE))
		return FALSE
	if(!check_location_accessible(user, target, BODY_ZONE_PRECISE_GROIN, TRUE))
		return FALSE
	if(!user.getorganslot(ORGAN_SLOT_VAGINA))
		return FALSE
	if(!target.getorganslot(ORGAN_SLOT_PENIS))
		return FALSE
	return TRUE

/datum/sex_action/sex/other/vagina/on_start(mob/living/carbon/human/user, mob/living/carbon/human/target)
	. = ..()
	user.visible_message(span_warning("[user] gets on top of [target] and begins riding [target.p_them()] with [user.p_their()] cunt!"))
	playsound(target, list('sound/misc/mat/insert (1).ogg','sound/misc/mat/insert (2).ogg'), 20, TRUE, ignore_walls = FALSE)

/datum/sex_action/sex/other/vagina/on_perform(mob/living/carbon/human/user, mob/living/carbon/human/target)
	var/datum/sex_session/sex_session = get_sex_session(user, target)
	user.visible_message(sex_session.spanify_force("[user] [sex_session.get_generic_force_adjective()] rides [target]."))
	playsound(target, 'sound/misc/mat/segso.ogg', 50, TRUE, -2, ignore_walls = FALSE)
	do_thrust_animate(user, target)

	if(sex_session.considered_limp(target))
		sex_session.perform_sex_action(target, 1.2, 3, TRUE)
	else
		sex_session.perform_sex_action(target, 2.4, 7, TRUE)
	sex_session.handle_passive_ejaculation(target)

	sex_session.perform_sex_action(target, 2, 4, FALSE)

/datum/sex_action/sex/other/vagina/handle_climax_message(mob/living/carbon/human/user, mob/living/carbon/human/target)
	target.visible_message(span_love("[target] cums into [user]'s cunt!"))
	target.virginity = FALSE
	user.virginity = FALSE
	return "into"

/datum/sex_action/sex/other/vagina/on_finish(mob/living/carbon/human/user, mob/living/carbon/human/target)
	. = ..()
	user.visible_message(span_warning("[user] gets off [target]."))
