global function BarrageCore_Init

global function OnAbilityStart_BarrageCore
global function OnAbilityEnd_BarrageCore

void function BarrageCore_Init()
{

}

bool function OnAbilityStart_BarrageCore( entity weapon )
{
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
	thread PROTO_BarrageCore( titan, weapon.GetCoreDuration(), weapon.GetMods() )
#else
	if ( titan.IsPlayer() && (titan == GetLocalViewPlayer()) && IsFirstTimePredicted() )
		Rumble_Play( "rumble_titan_hovercore_activate", {} )
#endif

	return true
}

void function OnAbilityEnd_BarrageCore( entity weapon )
{
	entity titan = weapon.GetWeaponOwner()
	#if SERVER
	OnAbilityEnd_TitanCore( weapon )
	int currAmmo = weapon.GetWeaponPrimaryClipCount()
	
	if(currAmmo == 0)
	{
		titan.Signal( "CoreEnd" )
	}

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
void function PROTO_BarrageCore( entity titan, float flightTime, array<string> mods = [] )
{
	if ( !titan.IsTitan() )
		return

	table<string, bool> e
	e.shouldDeployWeapon <- false

	// modified
	//entity weaponToRestore // can't handle properly
	table storedWeapon = {}
	storedWeapon.shouldRestore <- false
	storedWeapon.weaponName <- ""
	array<string> storedMods = []
	storedWeapon.skin <- 0
	storedWeapon.camo <- 0

	array<string> weaponArray = [ "mp_titancore_flight_core" ]
	mods.removebyvalue( "brute4_barrage_core" )
	mods.append( "brute4_barrage_core_launcher" )

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


	if ( titan.IsPlayer() )
	{
		const float startupTime = 0.5
		const float endingTime = 0.5

		e.shouldDeployWeapon = true
		HolsterAndDisableWeapons( titan )

		DisableWeapons( titan, weaponArray )
		titan.GiveWeapon( "mp_titanweapon_flightcore_rockets", mods )
		titan.SetActiveWeaponByName( "mp_titanweapon_flightcore_rockets" )

		// here goes a hack: barrage core not making brute floating in air
		// which means their third person animation never shows
		// try to manually do Anim_PlayGesture()
		/* // don't work at all
		thread HACK_BarrageCorePlayerAnimation( titan )
		*/

		wait startupTime

		e.shouldDeployWeapon = false
		DeployAndEnableWeapons( titan )

		titan.WaitSignal( "CoreEnd" )

		if ( IsAlive( titan ) && titan.IsTitan() )
		{
			e.shouldDeployWeapon = true
			HolsterAndDisableWeapons( titan )

			wait endingTime
		}
	}
	else
	{
		titan.GiveWeapon( "mp_titanweapon_flightcore_rockets", mods )
		titan.SetActiveWeaponByName( "mp_titanweapon_flightcore_rockets" )
		titan.WaitSignal( "CoreEnd" )
		titan.TakeWeapon( "mp_titanweapon_flightcore_rockets" )

		array<entity> weapons = titan.GetMainWeapons()
		Assert( weapons.len() > 0 && weapons[0] != null )
		if ( weapons.len() > 0 && weapons[0] )
			titan.SetActiveWeaponByName( weapons[0].GetWeaponClassName() )
	}
}

// try to manually do Anim_PlayGesture()
/* // don't work at all
void function HACK_BarrageCorePlayerAnimation( entity titan )
{
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "CoreEnd" ) // all other endsignals handled here

	while ( true )
	{
		entity soul = titan.GetTitanSoul()
		if ( !IsValid( soul ) )
			return
		if ( GetSoulTitanSubClass( soul ) == "stryder" )
			titan.Anim_PlayGesture( "ACT_MP_JUMP_FLOAT", 0.2, 0.2, -1.0 )
	
		WaitFrame()
	}
}
*/
#endif