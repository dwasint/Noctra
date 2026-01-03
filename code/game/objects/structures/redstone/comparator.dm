/obj/structure/redstone/comparator
	name = "redstone comparator"
	desc = "Compares redstone signal strengths. Can read containers and signals through walls."
	icon_state = "comparator"
	redstone_role = REDSTONE_ROLE_PROCESSOR

	var/mode = "compare" // "compare" or "subtract"

	// Inputs (Cached)
	var/main_input = 0
	var/side_input_left = 0
	var/side_input_right = 0

	var/output_power = 0
	var/scheduled_target = -1 // For the 1-tick delay handling

	var/last_storage_signal = 0

	can_connect_wires = TRUE
	send_wall_power = TRUE

/obj/structure/redstone/comparator/Initialize()
	. = ..()
	// We process to check containers
	START_PROCESSING(SSobj, src)

<<<<<<< HEAD
/obj/structure/redstone/comparator/get_input_directions()
	return GLOB.cardinals - direction

// Add method to set direction during construction/placement
/obj/structure/redstone/comparator/proc/set_direction(new_dir)
	direction = new_dir
	update_directional_connections()
	update_icon()

/obj/structure/redstone/comparator/proc/update_directional_connections()
	// Comparators have three inputs (back, left, right) and one output (front)
	connected_components = list()

	// Connect to all adjacent components
	for(var/check_direction in GLOB.cardinals)
		var/turf/target_turf = get_step(src, check_direction)
		for(var/obj/structure/redstone/component in target_turf)
			if(component.can_connect_wires)
				connected_components += component

	// Check for storage containers behind us for signal generation
	check_storage_input()

/obj/structure/redstone/comparator/proc/check_storage_input()
	// Check behind the comparator for storage containers
	var/turf/back_turf = get_step(src, turn(direction, 180))
	var/storage_signal = get_storage_signal(back_turf)

	if(storage_signal != input_power)
		input_power = storage_signal
		calculate_output()

/obj/structure/redstone/comparator/proc/get_storage_signal(turf/T)
	if(!T)
		return 0

	// Check all objects on the turf for storage components
	for(var/obj/O in T)
		var/storage_signal = get_object_storage_signal(O)
		if(storage_signal > 0)
			return storage_signal

	var/strongest_signal = 0
	for(var/mob/living/carbon/mob in T)
		var/datum/component/hole_storage/hole = mob.GetComponent(/datum/component/hole_storage)
		if(!hole)
			continue
		for(var/hole_id in hole.hole_array)
			var/list/data = list()
			SEND_SIGNAL(mob, COMSIG_HOLE_GET_FULLNESS, hole_id, data)
			if(strongest_signal < data["redstone_level"])
				strongest_signal = data["redstone_level"]

	return strongest_signal

/obj/structure/redstone/comparator/proc/get_object_storage_signal(obj/O)
	if(!O)
		return 0

	// Check for storage component first (modern system)
	var/datum/component/storage/storage_comp = O.GetComponent(/datum/component/storage)
	if(storage_comp)
		return calculate_component_storage_fullness(storage_comp, O)

/obj/structure/redstone/comparator/proc/calculate_component_storage_fullness(datum/component/storage/storage_comp, obj/O)
	if(!storage_comp)
		return 0

	var/total_capacity = 0
	var/max_capacity = 0

	max_capacity = storage_comp.screen_max_rows * storage_comp.screen_max_columns

	if(max_capacity <= 0)
		return 0

	for(var/obj/item/item as anything in O.contents)
		total_capacity += (item.grid_width / 32) * (item.grid_height / 32)
	var/fullness_ratio = total_capacity / max_capacity
	return round(fullness_ratio * 15)

/obj/structure/redstone/comparator/receive_power(incoming_power, obj/structure/redstone/source, mob/user)
	if(!source)
		return

	// Determine which input this is based on source position relative to our direction
	var/source_dir = get_dir(src, source)
	var/source_key = "[ref(source)]"

	// Track power sources for each input separately
	if(incoming_power > 0)
		input_sources[source_key] = list("power" = incoming_power, "direction" = source_dir)
	else
		input_sources -= source_key

	// Recalculate input powers based on our facing direction
	var/back_dir = turn(direction, 180)
	var/left_dir = turn(direction, -90)
	var/right_dir = turn(direction, 90)

	input_power = 0
	side_power_left = 0
	side_power_right = 0

	for(var/key in input_sources)
		var/list/source_data = input_sources[key]
		///lmao Byond doesn't support non constant switch statements
		if(source_data["direction"] == back_dir) // Main input (back)
			input_power = max(input_power, source_data["power"])
		if(source_data["direction"] ==left_dir) // Left side input
			side_power_left = max(side_power_left, source_data["power"])
		if(source_data["direction"] == right_dir) // Right side input
			side_power_right = max(side_power_right, source_data["power"])

	// Also check for storage input
	var/storage_signal = get_storage_signal(get_step(src, back_dir))
	input_power = max(input_power, storage_signal)

	calculate_output(user)

/obj/structure/redstone/comparator/proc/calculate_output(mob/user)
	var/new_output = 0
	var/max_side_power = max(side_power_left, side_power_right)

	if(mode == "compare")
		// Output signal if main input >= side input
		if(input_power >= max_side_power)
			new_output = input_power
	else // subtract mode
		// Output difference between main and side inputs
		new_output = max(0, input_power - max_side_power)

	if(new_output != output_power)
		output_power = new_output
		set_power(output_power, user, null) // Comparator acts as its own source

// Override get_power_directions to only send power forward
/obj/structure/redstone/comparator/get_power_directions()
	// Comparators only send power in their facing direction
	return list(direction)

/obj/structure/redstone/comparator/attack_hand(mob/user)
	mode = (mode == "compare") ? "subtract" : "compare"
	to_chat(user, "<span class='notice'>Comparator set to [mode] mode.</span>")
	update_icon()
	calculate_output(user)

/obj/structure/redstone/comparator/update_icon()
	. = ..()
	var/base_state = "comparator"

	if(mode == "subtract")
		base_state += "_subtract"

	icon_state = base_state
	dir = direction

	// Add power overlay if outputting
	cut_overlays()
	if(output_power > 0)
		var/mutable_appearance/power_overlay = mutable_appearance(icon, "comparator_on")
		overlays += power_overlay

// Method to handle rotation/direction setting during placement
/obj/structure/redstone/comparator/proc/rotate_comparator(new_direction)
	direction = new_direction
	update_directional_connections()
	update_icon()
	return TRUE

// Alt-click rotation functionality
/obj/structure/redstone/comparator/AltClick(mob/user)
	if(!Adjacent(user))
		return

	// Rotate the comparator
	direction = turn(direction, 90)
	update_directional_connections()
	to_chat(user, "<span class='notice'>You rotate the [name] to face [dir2text_readable(direction)].</span>")
	update_icon()

	// Recalculate since inputs/outputs changed
	calculate_output(user)

/obj/structure/redstone/comparator/proc/dir2text_readable(dir)
	switch(dir)
		if(NORTH) return "north"
		if(SOUTH) return "south"
		if(EAST) return "east"
		if(WEST) return "west"
		else return "north"

// Enhanced examine to show more storage details
/obj/structure/redstone/comparator/examine(mob/user)
	. = ..()
	. += "It is facing [dir2text_readable(direction)] and in [mode] mode."
	. += "Main input: [input_power], Left side: [side_power_left], Right side: [side_power_right]"
	. += "Output: [output_power]"
	. += "Click to toggle mode, Alt-click to rotate."

	// Check for storage behind it with detailed info
	var/turf/back_turf = get_step(src, turn(direction, 180))
	if(back_turf)
		for(var/obj/O in back_turf)
			var/datum/component/storage/storage_comp = O.GetComponent(/datum/component/storage)
			if(storage_comp)
				var/storage_signal = get_object_storage_signal(O)
				var/total_capacity = 0
				for(var/obj/item/item as anything in O.contents)
					total_capacity += (item.grid_width / 32) * (item.grid_height / 32)
				var/max_capacity = 0

				max_capacity = storage_comp.screen_max_rows * storage_comp.screen_max_columns
				. += "Detecting [O.name]: [total_capacity]/[max_capacity] items (signal: [storage_signal])"
				break

/obj/structure/redstone/comparator/proc/get_storage_type_capacity(datum/component/storage/storage_comp)
	// Handle specific storage types
	if(istype(storage_comp, /datum/component/storage/concrete/grid/coin_pouch))
		return 4 // 4 rows × 1 column as mentioned in your example

	return storage_comp.screen_max_rows * storage_comp.screen_max_columns

// Process storage changes periodically
/obj/structure/redstone/comparator/process()
	check_storage_input()

=======
>>>>>>> vanderlin/main
/obj/structure/redstone/comparator/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/structure/redstone/comparator/get_source_power()
	return output_power

/obj/structure/redstone/comparator/get_effective_power()
	return output_power

/obj/structure/redstone/comparator/get_output_directions()
	return list(dir)

/obj/structure/redstone/comparator/get_input_directions()
	return list(REVERSE_DIR(dir), turn(dir, 90), turn(dir, -90))

/obj/structure/redstone/comparator/get_connection_directions()
	return list(dir, REVERSE_DIR(dir), turn(dir, 90), turn(dir, -90))

/obj/structure/redstone/comparator/can_connect_to(obj/structure/redstone/other, dir)
	return TRUE // Connects on all sides

/obj/structure/redstone/comparator/can_receive_from(obj/structure/redstone/source, dir)
	return (dir in get_input_directions())

/obj/structure/redstone/comparator/get_network_neighbors()
	var/list/neighbors = list()

	// 1. Standard Redstone Neighbors
	for(var/dir in get_connection_directions())
		var/turf/T = get_step(src, dir)
		for(var/obj/structure/redstone/R in T)
			if(can_connect_to(R, dir) && R.can_connect_to(src, REVERSE_DIR(dir)))
				neighbors += R

	// 2. Wall Power OUTPUT (Front)
	var/turf/front = get_step(src, dir)
	if(isclosedturf(front))
		neighbors |= get_wall_power_neighbors(dir, front)

	// 3. Wall Power INPUT (Rear & Sides)
	for(var/input_dir in get_input_directions())
		var/turf/T = get_step(src, input_dir)
		if(isclosedturf(T))
			neighbors |= get_wall_power_sources(input_dir, T)

	return neighbors

/obj/structure/redstone/comparator/proc/get_wall_power_sources(input_dir, turf/wall_turf)
	var/list/sources = list()
	for(var/check_dir in GLOB.cardinals)
		if(check_dir == REVERSE_DIR(input_dir)) continue
		var/turf/beyond_wall = get_step(wall_turf, check_dir)
		for(var/obj/structure/redstone/R in beyond_wall)
			if(!R.send_wall_power) continue
			var/dir_to_wall = REVERSE_DIR(check_dir)
			if(dir_to_wall in R.get_output_directions())
				sources += R
	return sources

/obj/structure/redstone/comparator/get_wall_power_neighbors(direction, turf/wall_turf)
	var/list/neighbors = list()

	// Horizontal
	for(var/check_dir in GLOB.cardinals)
		if(check_dir == REVERSE_DIR(direction)) continue
		var/turf/beyond_wall = get_step(wall_turf, check_dir)
		for(var/obj/structure/redstone/dust/dust in beyond_wall)
			neighbors += dust
		for(var/obj/structure/redstone/repeater/rep in beyond_wall)
			if(REVERSE_DIR(rep.facing_dir) == REVERSE_DIR(check_dir)) neighbors += rep

	// Vertical (Multi-Z)
	var/turf/above = GET_TURF_ABOVE(wall_turf)
	if(above)
		for(var/obj/structure/redstone/dust/dust in above) neighbors += dust

	var/turf/below = GET_TURF_BELOW(wall_turf)
	if(below)
		for(var/obj/structure/redstone/dust/dust in below) neighbors += dust

	return neighbors

/obj/structure/redstone/comparator/process()
	// 1. Get the current state of the container
	var/current_storage_signal = get_storage_signal()

	// 2. Only recalculate if the STORAGE ITSELF changed.
	// Do not compare against main_input (which might be high due to a wire).
	if(current_storage_signal != last_storage_signal)
		on_power_changed()

/obj/structure/redstone/comparator/on_power_changed()
	// 1. Calculate Side Inputs
	var/left_dir = turn(dir, 90)
	var/right_dir = turn(dir, -90)

	side_input_left = get_power_from_side(left_dir)
	side_input_right = get_power_from_side(right_dir)

	// 2. Calculate Main Input (Rear)
	var/rear_dir = REVERSE_DIR(dir)
	var/redstone_signal = get_power_from_side(rear_dir)

	// Update the separate storage tracker
	last_storage_signal = get_storage_signal()

	// Set the actual main input
	main_input = max(redstone_signal, last_storage_signal)

	// 3. Determine Desired Output
	var/max_side = max(side_input_left, side_input_right)
	var/desired_output = 0

	if(mode == "compare")
		// MAINTAIN STRENGTH: If Main >= Side, output Main. Else 0.
		desired_output = (main_input >= max_side) ? main_input : 0
	else // subtract
		desired_output = max(0, main_input - max_side)

	if(desired_output != output_power)
		// Prevent spamming spawns if we are already scheduled for this target
		if(scheduled_target != desired_output)
			scheduled_target = desired_output
			spawn(1)
				apply_scheduled_output()

/obj/structure/redstone/comparator/proc/apply_scheduled_output()
	// If we changed our mind mid-delay (fast pulse), handle it or cancel
	if(scheduled_target == -1) return

	if(output_power != scheduled_target)
		output_power = scheduled_target
		power_level = output_power

		// Only now do we update the network
		schedule_network_update()
		update_appearance(UPDATE_OVERLAYS)

	scheduled_target = -1

/obj/structure/redstone/comparator/proc/get_power_from_side(side_dir)
	var/turf/T = get_step(src, side_dir)
	var/found_power = 0

	// A. Direct Connection
	for(var/obj/structure/redstone/R in T)
		if(R.can_connect_to(src, REVERSE_DIR(side_dir)))
			found_power = max(found_power, R.get_effective_power())

	// B. Wall Power (Reading through a block)
	if(isclosedturf(T))
		for(var/check_dir in GLOB.cardinals)
			if(check_dir == REVERSE_DIR(side_dir)) continue
			var/turf/source_turf = get_step(T, check_dir)
			for(var/obj/structure/redstone/R in source_turf)
				if(R.send_wall_power)
					if(REVERSE_DIR(check_dir) in R.get_output_directions())
						found_power = max(found_power, R.get_effective_power())

	return found_power

/obj/structure/redstone/comparator/proc/get_storage_signal()
	var/turf/back_turf = get_step(src, REVERSE_DIR(dir))

	for(var/obj/O in back_turf)
		var/datum/component/storage/storage_comp = O.GetComponent(/datum/component/storage)
		if(storage_comp)
			return calculate_storage_fullness(storage_comp, O)
	return 0

/obj/structure/redstone/comparator/proc/calculate_storage_fullness(datum/component/storage/storage_comp, obj/O)
	var/max_capacity = storage_comp.screen_max_rows * storage_comp.screen_max_columns
	if(max_capacity <= 0)
		return 0

	var/total = 0
	for(var/obj/item/item in O.contents)
		total += (item.grid_width / 32) * (item.grid_height / 32)

	return round((total / max_capacity) * 15)

/obj/structure/redstone/comparator/update_icon()
	. = ..()
	icon_state = (mode == "subtract") ? "comparator_subtract" : "comparator"

/obj/structure/redstone/comparator/update_overlays()
	. = ..()
	var/mutable_appearance/rear_torch = mutable_appearance(icon, "torch_rear")
	rear_torch.color = (output_power > 0) ? "#FF0000" : "#8B4513"
	. += rear_torch

	if(output_power > 0)
		var/mutable_appearance/em = emissive_appearance(icon, "torch_rear")
		. += em

	var/mutable_appearance/front_torch = mutable_appearance(icon, "torch_front")
	front_torch.color = (mode == "subtract") ? "#FF0000" : "#8B4513"
	. += front_torch

	if(mode == "subtract")
		var/mutable_appearance/em = emissive_appearance(icon, "torch_front")
		. += em

/obj/structure/redstone/comparator/attack_hand(mob/user)
	mode = (mode == "compare") ? "subtract" : "compare"
	to_chat(user, "<span class='notice'>Mode changed to [mode].</span>")
	on_power_changed() // Recalculate
	update_appearance(UPDATE_ICON | UPDATE_OVERLAYS)

/obj/structure/redstone/comparator/AltClick(mob/user)
	if(!Adjacent(user)) return
	dir = turn(dir, 90)
	to_chat(user, "<span class='notice'>You rotate the [name].</span>")
	schedule_network_update()
	on_power_changed()
