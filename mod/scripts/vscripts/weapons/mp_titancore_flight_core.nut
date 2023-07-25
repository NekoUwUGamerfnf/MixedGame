global function FlightCore_Init

global function OnAbilityStart_FlightCore
global function OnAbilityEnd_FlightCore

global const FLIGHT_CORE_IMPACT_FX = $"droppod_impact"

void function FlightCore_Init()
{
	PrecacheParticleSystem( FLIGHT_CORE_IMPACT_FX )
	PrecacheWeapon( "mp_titanweapon_flightcore_rockets" )
}

bool function OnAbilityStart_FlightCore( entity weapon )
{
	// modded weapon
	if( weapon.HasMod( "brute4_barrage_core" ) )
		return OnAbilityStart_BarrageCore( weapon )
	//

	// vanilla behavior
	if ( !OnAbilityCharge_TitanCore( weapon ) )
		return false

#if SERVER
	OnAbilityChargeEnd_TitanCore( weapon )
#endif

	OnAbilityStart_TitanCore( weapon )

	entity titan = weapon.GetOwner() // GetPlayerFromTitanWeapon( weapon )

#if SERVER
	if ( titan.IsPlayer() )
		Melee_Disable( titan )
	thread PROTO_FlightCore( titan, weapon.GetCoreDuration(), weapon )
#else
	if ( titan.IsPlayer() && (titan == GetLocalViewPlayer()) && IsFirstTimePredicted() )
		Rumble_Play( "rumble_titan_hovercore_activate", {} )
#endif

	return true
}

void function OnAbilityEnd_FlightCore( entity weapon )
{
	// modded weapon
	if( weapon.HasMod( "brute4_barrage_core" ) )
		return OnAbilityEnd_BarrageCore( weapon )
	//

	// vanilla behavior
	entity titan = weapon.GetWeaponOwner()

	#if SERVER
	OnAbilityEnd_TitanCore( weapon )

	if ( titan != null )
	{
		if ( titan.IsPlayer() )
			Melee_Enable( titan )
		titan.Signal( "CoreEnd" )
	}
	#else
		if ( titan.IsPlayer() )
			TitanCockpit_PlayDialog( titan, "flightCoreOffline" )
	#endif
}

#if SERVER
//HACK - Should use operator functions from Joe/Steven W
void function PROTO_FlightCore( entity titan, float flightTime, entity weapon )
{
	if ( !titan.IsTitan() )
		return

	table<string, bool> e
	e.shouldDeployWeapon <- false

	// modified
	//entity weaponToRestore // can't use this, maybe takenWeapon will be soon destroyed
	table storedWeapon = {}
	storedWeapon.shouldRestore <- false
	storedWeapon.weaponName <- ""
	array<string> storedMods = []
	storedWeapon.skin <- 0
	storedWeapon.camo <- 0

	array<string> weaponArray = [ "mp_titancore_flight_core" ]

	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "TitanEjectionStarted" )
	titan.EndSignal( "DisembarkingTitan" )
	titan.EndSignal( "OnSyncedMelee" )

	if ( titan.IsPlayer() )
		titan.ForceStand()

	OnThreadEnd(
		function() : ( titan, e, weaponArray, storedWeapon, storedMods ) // weaponToRestore )
		{
			//print( weaponToRestore )
			bool willRestoreWeapon = expect bool( storedWeapon.shouldRestore ) // IsValid( weaponToRestore ) 
			//print( willRestoreWeapon )
			if ( IsValid( titan ) && titan.IsPlayer() )
			{
				if ( IsAlive( titan ) && titan.IsTitan() )
				{
					if ( HasWeapon( titan, "mp_titanweapon_flightcore_rockets" ) )
					{
						EnableWeapons( titan, weaponArray )
						if( willRestoreWeapon ) // instantly take it
							titan.TakeWeaponNow( "mp_titanweapon_flightcore_rockets" )
						else // keep vanilla behavior
							titan.TakeWeapon( "mp_titanweapon_flightcore_rockets" )
					}
				}

				titan.ClearParent()
				titan.UnforceStand()
				if ( e.shouldDeployWeapon && !titan.ContextAction_IsActive() )
					DeployAndEnableWeapons( titan )

				titan.Signal( "CoreEnd" )
			}

			// modified, defensive fix for some modded situations northstar has 3 main weapons
			if( IsAlive( titan ) && titan.IsTitan() && willRestoreWeapon )
			{
				//titan.GiveExistingWeapon( weaponToRestore )
				if( storedWeapon.weaponName != "" )
				{
					string weaponName = expect string( storedWeapon.weaponName )
					int skinIndex = expect int( storedWeapon.skin )
					int camoIndex = expect int( storedWeapon.camo )
					//print( weaponName )
					//print( storedMods )
					entity newGivenWeapon = titan.GiveWeapon( weaponName, storedMods )
					if( IsValid( newGivenWeapon ) )
					{
						newGivenWeapon.SetSkin( skinIndex )
						newGivenWeapon.SetCamo( camoIndex )
					}
				}
			}
		}
	)

	// modified
	if( titan.GetMainWeapons().len() >= 3 ) // no room for flight core
	{
		//weaponToRestore = titan.TakeWeapon_NoDelete( titan.GetMainWeapons()[2].GetWeaponClassName() )
		storedWeapon.shouldRestore = true
		// try to store a weapon
		array<entity> allMainWeapons = titan.GetMainWeapons()
		entity weaponToStore = titan.GetActiveWeapon()
		if( !allMainWeapons.contains( weaponToStore ) )
			weaponToStore = allMainWeapons[0]
		titan.TakeWeaponNow( weaponToStore.GetWeaponClassName() )
		storedMods = weaponToStore.GetMods()
		storedWeapon.weaponName = weaponToStore.GetWeaponClassName()
		storedWeapon.skin = weaponToStore.GetSkin()
		storedWeapon.camo = weaponToStore.GetCamo()
	}	

	entity soul = titan.GetTitanSoul()

	if( !IsValid( soul ) )
		return

	bool hasPasFlightCore = false
	foreach( entity offhand in titan.GetOffhandWeapons() )
	{
		if( offhand.GetWeaponClassName() == "mp_titancore_flight_core" )
		{
			if( offhand.HasMod( "pas_northstar_flightcore" ) )
				hasPasFlightCore = true
		}
	}
	if( SoulHasPassive( soul, ePassives.PAS_NORTHSTAR_FLIGHTCORE ) )
		hasPasFlightCore = true

	if ( titan.IsPlayer() )
	{
		const float takeoffTime = 1.0
		const float landingTime = 1.0

		e.shouldDeployWeapon = true
		HolsterAndDisableWeapons( titan )

		DisableWeapons( titan, weaponArray )	

		titan.GiveWeapon( "mp_titanweapon_flightcore_rockets" )
		titan.SetActiveWeaponByName( "mp_titanweapon_flightcore_rockets" )

		float horizontalVelocity
		if( hasPasFlightCore )
			horizontalVelocity = 350.0
		else
			horizontalVelocity = 200.0
		HoverSounds soundInfo
		soundInfo.liftoff_1p = "titan_core_flight_liftoff_1p"
		soundInfo.liftoff_3p = "titan_core_flight_liftoff_3p"
		soundInfo.hover_1p = "Titan_Core_Flight_Hover_1P"
		soundInfo.hover_3p = "Titan_Core_Flight_Hover_3P"
		soundInfo.descent_1p = "Titan_Core_Flight_Descent_1P"
		soundInfo.descent_3p = "Titan_Core_Flight_Descent_3P"
		soundInfo.landing_1p = "core_ability_land_1p"
		soundInfo.landing_3p = "core_ability_land_3p"
		thread FlyerHovers( titan, soundInfo, flightTime, horizontalVelocity )

		wait takeoffTime

		e.shouldDeployWeapon = false
		DeployAndEnableWeapons( titan )

		titan.WaitSignal( "CoreEnd" )

		if ( IsAlive( titan ) && titan.IsTitan() )
		{
			e.shouldDeployWeapon = true
			HolsterAndDisableWeapons( titan )

			wait landingTime
		}
	}
	else
	{
		titan.GiveWeapon( "mp_titanweapon_flightcore_rockets" )
		titan.SetActiveWeaponByName( "mp_titanweapon_flightcore_rockets" )
		titan.WaitSignal( "CoreEnd" )
		titan.TakeWeapon( "mp_titanweapon_flightcore_rockets" )

		array<entity> weapons = titan.GetMainWeapons()
		Assert( weapons.len() > 0 && weapons[0] != null )
		if ( weapons.len() > 0 && weapons[0] )
			titan.SetActiveWeaponByName( weapons[0].GetWeaponClassName() )
	}
}
#endif