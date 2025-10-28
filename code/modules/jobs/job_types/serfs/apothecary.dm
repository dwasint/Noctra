/datum/job/apothecary
	title = "Apothecary"
	tutorial = "You know every plant growing on these grounds and in the woods like the back of your hand. \
<<<<<<< HEAD
	You are tasked with mixing tinctures and supplying the town and Feldsher with medicine for pain... or pleasure. \
	For a price, of course. \
	You have been known to kill men who cross you or your work-partner."
=======
	You are tasked with mixing tinctures and supplying the town and Feldsher with medicine. \
	Some seek you out for your expertise in poisons or hedonistic pleasure. \
	Others may look down upon you for your work, but your clients never complain. \
	You have combined ownership of the Apothecarian Workshop and the Clinic with the Feldsher. Best to work together."
>>>>>>> vanderlin/main
	department_flag = SERFS
	job_flags = (JOB_ANNOUNCE_ARRIVAL | JOB_SHOW_IN_CREDITS | JOB_EQUIP_RANK | JOB_NEW_PLAYER_JOINABLE)
	display_order = JDO_APOTHECARY
	faction = FACTION_TOWN
<<<<<<< HEAD
	total_positions = 2
	spawn_positions = 2
	min_pq = 1
	bypass_lastclass = TRUE

	allowed_races = RACES_PLAYER_NONEXOTIC
=======
	total_positions = 1
	spawn_positions = 1
	min_pq = 2
	bypass_lastclass = TRUE

	trainable_skills = list(/datum/skill/craft/alchemy)
	max_apprentices = 2
	apprentice_name = "Apothecary-in-training"
	can_have_apprentices = TRUE

	jobstats = list(
		STATKEY_INT = 2,
		STATKEY_PER = -1,
	)

	skills = list(
		/datum/skill/combat/wrestling = 2,
		/datum/skill/combat/unarmed = 2,
		/datum/skill/craft/crafting = 2,//they need this to craft bottles
		/datum/skill/misc/athletics = 2,
		/datum/skill/misc/reading = 4,
		/datum/skill/misc/sneaking = 3,
		/datum/skill/misc/climbing = 2,
		/datum/skill/craft/alchemy = 5,
		/datum/skill/misc/medicine = 3,
		/datum/skill/labor/farming = 3,
	)

	traits = list(
		TRAIT_FORAGER,
		TRAIT_LEGENDARY_ALCHEMIST,
	)

	allowed_races = RACES_PLAYER_NONEXOTIC

>>>>>>> vanderlin/main
	outfit = /datum/outfit/apothecary
	give_bank_account = 100
	cmode_music = 'sound/music/cmode/nobility/combat_physician.ogg'

	job_bitflag = BITFLAG_CONSTRUCTOR

<<<<<<< HEAD
/datum/outfit/apothecary/pre_equip(mob/living/carbon/human/H)
	..()
=======
/datum/job/apothecary/after_spawn(mob/living/carbon/human/spawned, client/player_client)
	. = ..()
	spawned.adjust_skillrank(/datum/skill/combat/wrestling, pick(0,0,1), TRUE)
	if(spawned.age == AGE_OLD)
		spawned.adjust_skillrank(/datum/skill/craft/alchemy, 1, TRUE)

/datum/outfit/apothecary
>>>>>>> vanderlin/main
	armor = /obj/item/clothing/armor/gambeson/apothecary
	shoes = /obj/item/clothing/shoes/apothboots
	shirt = /obj/item/clothing/shirt/apothshirt
	pants = /obj/item/clothing/pants/trou/apothecary
	gloves = /obj/item/clothing/gloves/leather/apothecary
<<<<<<< HEAD
	belt = /obj/item/storage/belt/leather
	beltl = /obj/item/storage/keyring/apothecary
	beltr = /obj/item/storage/belt/pouch/coins/poor
	ADD_TRAIT(H, TRAIT_LEGENDARY_ALCHEMIST, TRAIT_GENERIC)
	ADD_TRAIT(H, TRAIT_FORAGER, TRAIT_GENERIC)
	H.adjust_skillrank(/datum/skill/combat/wrestling, pick(2,2,3), TRUE)//so he can help the feldsher hold down unruly patients
	H.adjust_skillrank(/datum/skill/combat/unarmed, 2, TRUE)
	H.adjust_skillrank(/datum/skill/misc/athletics, 2, TRUE)
	H.adjust_skillrank(/datum/skill/misc/reading, 2, TRUE)
	H.adjust_skillrank(/datum/skill/misc/sneaking, 3, TRUE)
	H.adjust_skillrank(/datum/skill/misc/climbing, 2, TRUE)//I assume they venture often into the wild for herbs
	H.adjust_skillrank(/datum/skill/craft/alchemy, 5, TRUE)
	H.adjust_skillrank(/datum/skill/craft/crafting, 2, TRUE)
	H.adjust_skillrank(/datum/skill/misc/medicine, 3, TRUE)
	H.adjust_skillrank(/datum/skill/labor/farming, 3, TRUE)
	if(H.age == AGE_OLD)
		H.adjust_skillrank(/datum/skill/craft/alchemy, 1, TRUE)
	H.change_stat(STATKEY_INT, 2)
	H.change_stat(STATKEY_PER, -1)

=======
	backl = /obj/item/storage/backpack/satchel
	belt = /obj/item/storage/belt/leather
	beltl = /obj/item/storage/keyring/clinic
	beltr = /obj/item/storage/belt/pouch/coins/poor
>>>>>>> vanderlin/main
