/obj/item/clothing/head/helmet/heavy/steam
	name = "steamknight helmet"
	desc = "Part of the the steamknight armor. Requires knowledge in engineering to operate."
	icon_state = "steamknight_helm"
	icon = 'icons/roguetown/clothing/steamknight.dmi'
	mob_overlay_icon = 'icons/roguetown/clothing/onmob/steamknight_onmob.dmi'
	anvilrepair = /datum/skill/craft/engineering
<<<<<<< HEAD
	block2add = null // no fov block, was trying to make it so theres a fov block if its unpowered but it didn't really work out sadly, was too buggy
	item_weight = 9 * BRONZE_MULTIPLIER
=======
	item_weight = 9 * BRONZE_MULTIPLIER
	block2add = FOV_RIGHT|FOV_LEFT
>>>>>>> vanderlin/main
	smeltresult = /obj/item/ingot/bronze

/obj/item/clothing/head/helmet/heavy/steam/dropped(mob/living/carbon/user)
	// Locate the boiler in the back slots
	var/obj/item/clothing/cloak/boiler/B = locate(/obj/item/clothing/cloak/boiler) in list(user.backr, user.backl)
	if(B)
		B.power_off(user)

	. = ..()
<<<<<<< HEAD
=======

/obj/item/clothing/head/helmet/heavy/steam/proc/power_on(mob/living/user)
	block2add = null
	user.update_fov_angles()

/obj/item/clothing/head/helmet/heavy/steam/proc/power_off(mob/living/user)
	block2add = FOV_RIGHT|FOV_LEFT
	user.update_fov_angles()
>>>>>>> vanderlin/main
