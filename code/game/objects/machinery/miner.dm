#define MINER_RUNNING	0
#define MINER_SMALL_DAMAGE	1
#define MINER_MEDIUM_DAMAGE	2
#define MINER_DESTROYED	3

#define MINER_RESISTANT	"reinforced components"
#define MINER_COMPACTOR	"upgraded crystalizer module"
#define MINER_OVERCLOCKED "high-efficiency drill"


///Resource generator that produces a certain material that can be repaired by marines and attacked by xenos, Intended as an objective for marines to play towards to get more req gear
/obj/machinery/miner
	name = "\improper Nanotrasen phoron Mining Well"
	desc = "Top-of-the-line Nanotrasen research drill with it's own packaging module, used to extract phoron in vast quantities. Selling the phoron mined by these would net a nice profit..."
	icon = 'icons/obj/mining_drill.dmi'
	density = TRUE
	icon_state = "mining_drill_active"
	anchored = TRUE
	resistance_flags = INDESTRUCTIBLE
	///How many sheets of material we have stored
	var/stored_mineral = 0
	///Current status of the miner
	var/miner_status = MINER_RUNNING
	///Tracks how many ticks have passed since we last added a sheet of material
	var/add_tick = 0
	///How many times we neeed to tick for a resource to be created, in this case this is 2* the specified amount
	var/required_ticks = 70  //make one crate every 140 seconds
	///The mineral type that's produced
	var/mineral_produced = /obj/structure/ore_box/phoron
	///Health for the miner we use because changing obj_integrity is apparently bad
	var/miner_integrity = 100
	///Max health of the miner
	var/max_miner_integrity = 100
	///What type of upgrade it has installed , used to change the icon of the miner.
	var/miner_upgrade_type

/obj/machinery/miner/damaged	//mapping and all that shebang
	miner_status = MINER_DESTROYED
	icon_state = "mining_drill_error"

/obj/machinery/miner/damaged/platinum
	name = "\improper Nanotrasen platinum Mining Well"
	desc = "A Nanotrasen platinum drill with an internal packaging module. Produces even more valuable materials than it's phoron counterpart"
	mineral_produced = /obj/structure/ore_box/platinum

/obj/machinery/miner/Initialize()
	. = ..()
	start_processing()

/obj/machinery/miner/update_icon()
	switch(miner_status)
		if(MINER_RUNNING)
			if((mineral_produced == /obj/item/compactorebox/platinum) && (miner_upgrade_type == MINER_COMPACTOR))
				icon_state = "mining_drill_active_platinum_[miner_upgrade_type]"
			else
				icon_state = "mining_drill_active_[miner_upgrade_type]"
		if(MINER_SMALL_DAMAGE)
			icon_state = "mining_drill_braced_[miner_upgrade_type]"
		if(MINER_MEDIUM_DAMAGE)
			icon_state = "mining_drill_[miner_upgrade_type]"
		if(MINER_DESTROYED)
			icon_state = "mining_drill_error_[miner_upgrade_type]"
/// Called whenever someone attacks the miner with a object which is considered a upgrade.The object needs to have a uptype var.
/obj/machinery/miner/proc/attempt_upgrade(obj/item/minerupgrade/upgrade, mob/user, params)
	if(miner_upgrade_type)
		to_chat(user, "<span class='info'>The [src]'s module sockets are already occupied by the [miner_upgrade_type].</span>")
		return FALSE
	if(user.skills.getRating("construction")<SKILL_CONSTRUCTION_ADVANCED)
		to_chat(user, "<span class='info'>You can't figure out how to install the complex module.</span>")
		return FALSE
	user.visible_message("<span class='notice'>[user] begins attaching a module to [src]'s sockets.</span>")
	to_chat(user, "<span class='info'>You begin installing the [upgrade] on the miner.</span>")
	if(!do_after(user, 15 SECONDS, TRUE, src, BUSY_ICON_BUILD))
		return FALSE
	switch(upgrade.uptype)
		if(MINER_RESISTANT)
			max_miner_integrity = 300
			miner_integrity = 300
		if(MINER_COMPACTOR)
			if(mineral_produced == /obj/structure/ore_box/platinum)
				mineral_produced = /obj/item/compactorebox/platinum
			else
				mineral_produced = /obj/item/compactorebox/phoron
		if(MINER_OVERCLOCKED)
			required_ticks = 35
	miner_upgrade_type = upgrade.uptype
	user.visible_message("<span class='notice'>[user] attaches the [miner_upgrade_type] to the [src]!</span>")
	qdel(upgrade)
	playsound(loc,'sound/items/screwdriver.ogg', 25, TRUE)
	update_icon()

/obj/machinery/miner/attackby(obj/item/I,mob/user,params)
	. = ..()

	if(istype(I, /obj/item/minerupgrade))
		var/obj/item/minerupgrade/upgrade = I
		if(!(miner_status == MINER_RUNNING))
			to_chat(user, "<span class='info'>[src]'s module sockets seem bolted down.</span>")
			return FALSE
		attempt_upgrade(upgrade,user)

/obj/machinery/miner/welder_act(mob/living/user, obj/item/I)
	. = ..()
	var/obj/item/tool/weldingtool/weldingtool = I
	if((miner_status == MINER_RUNNING) && miner_upgrade_type)
		if(!weldingtool.remove_fuel(2,user))
			to_chat(user, "<span class='info'>You need more welding fuel to complete this task!</span>")
			return FALSE
		to_chat(user, "<span class='info'>You begin uninstalling the [miner_upgrade_type] from the miner!</span>")
		user.visible_message("<span class='notice'>[user] begins dismantling the [miner_upgrade_type] from the miner.</span>")
		if(!do_after(user, 30 SECONDS, TRUE, src, BUSY_ICON_BUILD))
			return FALSE
		user.visible_message("<span class='notice'>[user] dismantles the [miner_upgrade_type] from the miner!</span>")
		var/obj/item/upgrade
		switch(miner_upgrade_type)
			if(MINER_RESISTANT)
				upgrade = new /obj/item/minerupgrade/reinforcement
				if(miner_integrity < max_miner_integrity)
					miner_integrity = round(miner_integrity/3)
					set_miner_status()
				else
					miner_integrity = initial(miner_integrity)
				max_miner_integrity = initial(max_miner_integrity)
			if(MINER_OVERCLOCKED)
				upgrade = new /obj/item/minerupgrade/overclock
				required_ticks = initial(required_ticks)
			if(MINER_COMPACTOR)
				upgrade = new /obj/item/minerupgrade/compactor
				mineral_produced = initial(mineral_produced)
		upgrade.forceMove(user.loc)
		miner_upgrade_type = null
		update_icon()
	if(miner_status != MINER_DESTROYED)
		return
	if(!weldingtool.remove_fuel(1, user))
		to_chat(user, "<span class='warning'>You need more welding fuel to complete this task.</span>")
		return FALSE
	if(user.skills.getRating("engineer") < SKILL_ENGINEER_ENGI)
		user.visible_message("<span class='notice'>[user] fumbles around figuring out [src]'s internals.</span>",
		"<span class='notice'>You fumble around figuring out [src]'s internals.</span>")
		var/fumbling_time = 10 SECONDS - 2 SECONDS * user.skills.getRating("engineer")
		if(!do_after(user, fumbling_time, TRUE, src, BUSY_ICON_UNSKILLED, extra_checks = CALLBACK(weldingtool, /obj/item/tool/weldingtool/proc/isOn)))
			return FALSE
	playsound(loc, 'sound/items/weldingtool_weld.ogg', 25)
	user.visible_message("<span class='notice'>[user] starts welding [src]'s internal damage.</span>",
	"<span class='notice'>You start welding [src]'s internal damage.</span>")
	if(!do_after(user, 200, TRUE, src, BUSY_ICON_BUILD, extra_checks = CALLBACK(weldingtool, /obj/item/tool/weldingtool/proc/isOn)))
		return FALSE
	if(miner_status != MINER_DESTROYED )
		return FALSE
	playsound(loc, 'sound/items/welder2.ogg', 25, TRUE)
	miner_integrity = 0.33 * max_miner_integrity
	set_miner_status()
	user.visible_message("<span class='notice'>[user] welds [src]'s internal damage.</span>",
	"<span class='notice'>You weld [src]'s internal damage.</span>")
	return TRUE

/obj/machinery/miner/wirecutter_act(mob/living/user, obj/item/I)
	if(miner_status != MINER_MEDIUM_DAMAGE)
		return
	if(user.skills.getRating("engineer") < SKILL_ENGINEER_ENGI)
		user.visible_message("<span class='notice'>[user] fumbles around figuring out [src]'s wiring.</span>",
		"<span class='notice'>You fumble around figuring out [src]'s wiring.</span>")
		var/fumbling_time = 10 SECONDS - 2 SECONDS * user.skills.getRating("engineer")
		if(!do_after(user, fumbling_time, TRUE, src, BUSY_ICON_UNSKILLED))
			return FALSE
	playsound(loc, 'sound/items/wirecutter.ogg', 25, TRUE)
	user.visible_message("<span class='notice'>[user] starts securing [src]'s wiring.</span>",
	"<span class='notice'>You start securing [src]'s wiring.</span>")
	if(!do_after(user, 120, TRUE, src, BUSY_ICON_BUILD))
		return FALSE
	if(miner_status != MINER_MEDIUM_DAMAGE)
		return FALSE
	playsound(loc, 'sound/items/wirecutter.ogg', 25, TRUE)
	miner_integrity = 0.66 * max_miner_integrity
	set_miner_status()
	user.visible_message("<span class='notice'>[user] secures [src]'s wiring.</span>",
	"<span class='notice'>You secure [src]'s wiring.</span>")
	return TRUE

/obj/machinery/miner/wrench_act(mob/living/user, obj/item/I)
	if(miner_status != MINER_SMALL_DAMAGE)
		return
	if(user.skills.getRating("engineer") < SKILL_ENGINEER_ENGI)
		user.visible_message("<span class='notice'>[user] fumbles around figuring out [src]'s tubing and plating.</span>",
		"<span class='notice'>You fumble around figuring out [src]'s tubing and plating.</span>")
		var/fumbling_time = 10 SECONDS - 2 SECONDS * user.skills.getRating("engineer")
		if(!do_after(user, fumbling_time, TRUE, src, BUSY_ICON_UNSKILLED))
			return FALSE
	playsound(loc, 'sound/items/ratchet.ogg', 25, TRUE)
	user.visible_message("<span class='notice'>[user] starts repairing [src]'s tubing and plating.</span>",
	"<span class='notice'>You start repairing [src]'s tubing and plating.</span>")
	if(!do_after(user, 150, TRUE, src, BUSY_ICON_BUILD))
		return FALSE
	if(miner_status != MINER_SMALL_DAMAGE)
		return FALSE
	playsound(loc, 'sound/items/ratchet.ogg', 25, TRUE)
	miner_integrity = max_miner_integrity
	set_miner_status()
	user.visible_message("<span class='notice'>[user] repairs [src]'s tubing and plating.</span>",
	"<span class='notice'>You repair [src]'s tubing and plating.</span>")
	start_processing()
	return TRUE

/obj/machinery/miner/examine(mob/user)
	. = ..()
	if(!ishuman(user))
		return
	if(!miner_upgrade_type)
		to_chat(user, "<span class='info'>[src]'s module sockets seem empty, an upgrade could be installed.</span>")
	else
		to_chat(user, "<span class='info'>[src]'s module sockets are occupied by the [miner_upgrade_type].</span>")

	switch(miner_status)
		if(MINER_DESTROYED)
			to_chat(user, "<span class='info'>It's heavily damaged, and you can see internal workings.</span>\n<span class='info'>Use a blowtorch, then wirecutters, then a wrench to repair it.</span>")
		if(MINER_MEDIUM_DAMAGE)
			to_chat(user, "<span class='info'>It's damaged, and there are broken wires hanging out.</span>\n<span class='info'>Use wirecutters, then wrench to repair it.</span>")
		if(MINER_SMALL_DAMAGE)
			to_chat(user, "<span class='info'>It's lightly damaged, and you can see some dents and loose piping.</span>\n<span class='info'>Use a wrench to repair it.</span>")
		if(MINER_RUNNING)
			to_chat(user, "<span class='info'>[src]'s storage module displays [stored_mineral] crates are ready to be deposited.</span>")

/obj/machinery/miner/attack_hand(mob/living/user)
	if(miner_status != MINER_RUNNING)
		to_chat(user, "<span class='warning'>[src] is damaged!</span>")
		return

	if(!stored_mineral)
		to_chat(user, "<span class='warning'>[src] is not ready to produce a shipment yet!</span>")
		return

	new mineral_produced(user.loc, stored_mineral)
	stored_mineral -= 1
	start_processing()

/obj/machinery/miner/process()
	if(miner_status != MINER_RUNNING)
		stop_processing()
		return
	if(add_tick >= required_ticks)
		stored_mineral += 1
		add_tick = 0
	if(stored_mineral >= 2)	//Stores 2 boxes worth of minerals
		stop_processing()
	else
		add_tick += 1

/obj/machinery/miner/attack_alien(mob/living/carbon/xenomorph/xeno_attacker)
	xeno_attacker.do_attack_animation(src, ATTACK_EFFECT_CLAW)
	xeno_attacker.visible_message("<span class='danger'>[xeno_attacker] slashes \the [src]!</span>", \
	"<span class='danger'>We slash \the [src]!</span>", null, 5)
	playsound(loc, "alien_claw_metal", 25, TRUE)
	if(miner_status == MINER_DESTROYED)
		to_chat(xeno_attacker, "<span class='warning'>[src] is already destroyed!</span>")
		return
	miner_integrity -= 25
	set_miner_status()

/obj/machinery/miner/proc/set_miner_status()
	var/health_percent = round((miner_integrity / max_miner_integrity) * 100)
	switch(health_percent)
		if(-INFINITY to 0)
			miner_status = MINER_DESTROYED
			stored_mineral = 0
		if(1 to 50)
			stored_mineral = 0
			miner_status = MINER_MEDIUM_DAMAGE
		if(51 to 99)
			stored_mineral = 0
			miner_status = MINER_SMALL_DAMAGE
		if(100 to INFINITY)
			start_processing()
			miner_status = MINER_RUNNING
	update_icon()
