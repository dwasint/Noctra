/datum/job/feldsher
	title = "Feldsher"
	tutorial = "You have seen countless wounds over your time. \
	Stitched the sores of blades, sealed honey over the bubous of plague. \
	A thousand deaths stolen from the Carriagemen, yet these people will still call you a charlatan. \
<<<<<<< HEAD
	At least the Apothecary understands you."
=======
	Atleast the Apothecary understands you. \
	You have combined ownership of the Apothecarian Workshop and the Clinic with the Apothecary. Best to work together."
>>>>>>> vanderlin/main
	department_flag = SERFS
	display_order = JDO_FELDSHER
	job_flags = (JOB_ANNOUNCE_ARRIVAL | JOB_SHOW_IN_CREDITS | JOB_EQUIP_RANK | JOB_NEW_PLAYER_JOINABLE)
	faction = FACTION_TOWN
<<<<<<< HEAD
	total_positions = 2
	spawn_positions = 2
	min_pq = 2

	//Reason all species allowed is you are basically a very talented court physician; even 'lower species' would find this to be one of the only ways to obtain a sort of nobility.
	allowed_races = RACES_PLAYER_NONEXOTIC

=======
	total_positions = 1
	spawn_positions = 1
	min_pq = 2
	bypass_lastclass = TRUE

	trainable_skills = list(/datum/skill/misc/medicine)
	max_apprentices = 2
	apprentice_name = "Feldsher-in-training"
	can_have_apprentices = TRUE

	allowed_races = RACES_PLAYER_NONEXOTIC

	jobstats = list(
		STATKEY_STR = -1,
		STATKEY_INT = 4,
		STATKEY_CON = - 1,
	)

	skills = list(
		/datum/skill/combat/wrestling = 2,
		/datum/skill/craft/crafting = 2,
		/datum/skill/combat/knives = 2,
		/datum/skill/misc/reading = 5,
		/datum/skill/labor/mathematics = 3,
		/datum/skill/misc/sewing = 3,
		/datum/skill/misc/climbing = 2,
		/datum/skill/misc/medicine = 5,
		/datum/skill/craft/alchemy = 3,
		/datum/skill/labor/farming = 3,
	)

	traits = list(
		TRAIT_EMPATH,
		TRAIT_STEELHEARTED,
		TRAIT_DEADNOSE,
	)

>>>>>>> vanderlin/main
	outfit = /datum/outfit/feldsher
	give_bank_account = 100
	cmode_music = 'sound/music/cmode/nobility/combat_physician.ogg'

	spells = list(
		/datum/action/cooldown/spell/diagnose,
	)

	job_bitflag = BITFLAG_CONSTRUCTOR

<<<<<<< HEAD
/datum/outfit/feldsher/pre_equip(mob/living/carbon/human/H)
	..()
=======
/datum/job/feldsher/after_spawn(mob/living/carbon/human/spawned, client/player_client)
	. = ..()
	spawned.adjust_skillrank(/datum/skill/combat/wrestling, pick(0,0,1), TRUE)
	if(spawned.age == AGE_OLD)
		spawned.adjust_skillrank(/datum/skill/misc/medicine, 1, TRUE)

/datum/outfit/feldsher
>>>>>>> vanderlin/main
	shoes = /obj/item/clothing/shoes/shortboots
	shirt = /obj/item/clothing/shirt/undershirt/colored/red
	backr = /obj/item/storage/backpack/satchel
	backl = /obj/item/storage/backpack/satchel/surgbag
	pants = /obj/item/clothing/pants/tights/colored/random
	gloves = /obj/item/clothing/gloves/leather/feld
	armor = /obj/item/clothing/shirt/robe/feld
	head = /obj/item/clothing/head/roguehood/feld
	mask = /obj/item/clothing/face/feld
	neck = /obj/item/clothing/neck/feld
	belt = /obj/item/storage/belt/leather
<<<<<<< HEAD
	beltl = /obj/item/storage/keyring/feldsher
	beltr = /obj/item/storage/fancy/ifak

	H.adjust_skillrank(/datum/skill/combat/wrestling, pick(2,2,3), TRUE)//so he can hold down unruly patients
	H.adjust_skillrank(/datum/skill/misc/reading, 5, TRUE)
	H.adjust_skillrank(/datum/skill/craft/crafting, 2, TRUE)
	H.adjust_skillrank(/datum/skill/combat/knives, 2, TRUE)
	H.adjust_skillrank(/datum/skill/misc/sewing, 3, TRUE)
	H.adjust_skillrank(/datum/skill/misc/medicine, 5, TRUE)
	H.adjust_skillrank(/datum/skill/craft/alchemy, 3, TRUE)
	H.adjust_skillrank(/datum/skill/labor/mathematics, 3, TRUE)
	if(H.age == AGE_OLD)
		H.adjust_skillrank(/datum/skill/misc/medicine, 1, TRUE)
	H.change_stat(STATKEY_STR, -1)
	H.change_stat(STATKEY_INT, 4)
	H.change_stat(STATKEY_CON, -1)
	ADD_TRAIT(H, TRAIT_EMPATH, TRAIT_GENERIC)
	ADD_TRAIT(H, TRAIT_STEELHEARTED, TRAIT_GENERIC)
	ADD_TRAIT(H, TRAIT_DEADNOSE, TRAIT_GENERIC)
=======
	wrists = /obj/item/storage/keyring/clinic
	beltl = /obj/item/storage/fancy/ifak
	beltr = /obj/item/storage/belt/pouch
	ring = /obj/item/clothing/ring/feldsher_ring
>>>>>>> vanderlin/main
