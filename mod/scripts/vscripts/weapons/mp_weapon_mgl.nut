
global function OnWeaponActivate_weapon_mgl
// modified callbacks
global function OnWeaponDeactivate_weapon_mgl
//
global function OnWeaponPrimaryAttack_weapon_mgl
global function OnProjectileCollision_weapon_mgl

#if CLIENT
global function OnClientAnimEvent_weapon_mgl
#endif // #if CLIENT

#if SERVER
global function OnWeaponNpcPrimaryAttack_weapon_mgl
#endif // #if SERVER

// modified callbacks
global function OnWeaponStartZoomIn_weapon_mgl
global function OnWeaponStartZoomOut_weapon_mgl

const MAX_BONUS_VELOCITY	= 1250

// modded weapon
struct
{
	table<entity, bool> mglWeaponUpdateArcFromMod // for saving a mgl that has "grenade_arc_on_ads" got "ar_trajectory" from this script, so we can remove them
} file
//

void function OnWeaponActivate_weapon_mgl( entity weapon )
{
	// vanilla behavior
#if CLIENT
	UpdateViewmodelAmmo( false, weapon )
#endif // #if CLIENT
}

// modified callbacks
void function OnWeaponDeactivate_weapon_mgl( entity weapon )
{

}
//

#if CLIENT
void function OnClientAnimEvent_weapon_mgl( entity weapon, string name )
{
	GlobalClientEventHandler( weapon, name )
}
#endif // #if CLIENT

var function OnWeaponPrimaryAttack_weapon_mgl( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapon
	if ( weapon.HasMod( "tripwire_launcher" ) )
		return OnWeaponPrimaryAttack_weapon_tripwire_launcher( weapon, attackParams )
	if ( weapon.HasMod( "flesh_magnetic" ) || weapon.HasMod( "magnetic_rollers" ) )
		return OnWeaponPrimaryAttack_weapon_flesh_mgl( weapon, attackParams )
	//

	// vanilla behavior
	entity player = weapon.GetWeaponOwner()

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	//vector bulletVec = ApplyVectorSpread( attackParams.dir, player.GetAttackSpreadAngle() * 2.0 )
	//attackParams.dir = bulletVec

	if ( IsServer() || weapon.ShouldPredictProjectiles() )
	{
		FireGrenade( weapon, attackParams )
	}
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_weapon_mgl( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapon
	if ( weapon.HasMod( "flesh_magnetic" ) || weapon.HasMod( "magnetic_rollers" ) )
		return OnWeaponNpcPrimaryAttack_weapon_flesh_mgl( weapon, attackParams )
	// vanilla behavior

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	FireGrenade( weapon, attackParams, true )
}
#endif // #if SERVER

void function FireGrenade( entity weapon, WeaponPrimaryAttackParams attackParams, bool isNPCFiring = false )
{
	vector angularVelocity = Vector( RandomFloatRange( -1200, 1200 ), 100, 0 )
	entity nade = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir, angularVelocity, 0, damageTypes.explosive, damageTypes.explosive, !isNPCFiring, true, false )

	if ( nade )
	{
		entity weaponOwner = weapon.GetWeaponOwner()
		#if SERVER
			EmitSoundOnEntity( nade, "Weapon_MGL_Grenade_Emitter" )
			// will set proj.onlyAllowSmartPistolDamage = true, which makes us cannot destroy it by normal weapons
			Grenade_Init( nade, weapon )
		#else
			//InitMagnetic needs to be after the team is set on both client and server.
			SetTeam( nade, weaponOwner.GetTeam() )
		#endif

		// nessie modified MGL
		if( weapon.HasMod( "nessie_mgl" ) )
			nade.SetModel( $"models/domestic/nessy_doll.mdl" )
		
		nade.InitMagnetic( MGL_MAGNETIC_FORCE, "Explo_MGL_MagneticAttract" )
		//thread MagneticFlight( nade, MGL_MAGNETIC_FORCE )
	}
}

void function OnProjectileCollision_weapon_mgl( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	// modded weapon
	array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // modded weapon refire behavior

	if( mods.contains( "tripwire_launcher" ) )
		return OnProjectileCollision_weapon_tripwire_launcher( projectile, pos, normal, hitEnt, hitbox, isCritical )
	else if ( mods.contains( "flesh_magnetic" ) || mods.contains( "magnetic_rollers" ) )
		return OnProjectileCollision_weapon_flesh_mgl( projectile, pos, normal, hitEnt, hitbox, isCritical )


	// vanilla behavior
	if ( !IsValid( hitEnt ) )
		return

	if ( IsMagneticTarget( hitEnt ) )
	{
		// adding friendlyfire support
		//if ( hitEnt.GetTeam() != projectile.GetTeam() )
		if ( FriendlyFire_IsEnabled() || hitEnt.GetTeam() != projectile.GetTeam() )
		{
			// adding visual fix: if client without mod installed hits a friendly target in close range
			// they won't predict the impact effect
			#if SERVER
				if ( hitEnt.GetTeam() == projectile.GetTeam() )
					FixImpactEffectForProjectileAtPosition( projectile, pos ) // shared from _unpredicted_impact_fix.gnut
			#endif

			projectile.ExplodeForCollisionCallback( normal )
		}
	}
}

// modified callbacks
void function OnWeaponStartZoomIn_weapon_mgl( entity weapon )
{
	// modded weapon
	// gives ar_trajectory on weapon ads, similar to softball ads arc
	if ( weapon.HasMod( "grenade_arc_on_ads" ) )
	{
		#if SERVER
			UpdateWeaponArTrajectory( weapon )
		#endif
	}
}

void function OnWeaponStartZoomOut_weapon_mgl( entity weapon )
{
	// modded weapon
	#if SERVER
		// may seem bad. vanilla zoom arc is based on zoomFrac
		// I don't care, it works fine
		weapon.Signal( "MGLZoomOut" ) // ends "AwaitingWeaponOwnerADSEnd" thread
	#endif
}

#if SERVER
void function UpdateWeaponArTrajectory( entity weapon )
{
	//print( "RUNNING UpdateWeaponArTrajectory()" )
	entity owner = weapon.GetWeaponOwner()
	if ( !owner.IsPlayer() )
		return

	thread AwaitingWeaponOwnerADSEnd( owner, weapon, "ar_trajectory" )
}

void function AwaitingWeaponOwnerADSEnd( entity owner, entity weapon, string newMod = "ar_trajectory" )
{
	if ( weapon.HasMod( newMod ) )
		return
	
	weapon.AddMod( newMod )
	//print( "Added " + newMod + " for player " + string( owner ) )

	weapon.Signal( "AwaitingWeaponOwnerADSEnd" )
	weapon.EndSignal( "AwaitingWeaponOwnerADSEnd" )
	weapon.EndSignal( "OnDestroy" )
	weapon.EndSignal( "MGLZoomOut" )
	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "OnDestroy" )

	OnThreadEnd
	(
		function(): ( weapon, newMod )
		{
			if ( IsValid( weapon ) )
			{
				weapon.RemoveMod( newMod )
				//print( "Removing mgl new mod" )
			}
		}
	)

	//const float zoomOutFrac = 0.4 // if zoom frac is lower than this we consider player as zoomed out

	while ( true )
	{
		WaitFrame() // at least let arc last 1 tick, also giving owner a grace period to start zoom in

		float zoomFrac = owner.GetZoomFrac()
		entity activeWeapon = owner.GetActiveWeapon()
		if ( zoomFrac == 0.0 )
			break
		if ( IsValid( activeWeapon ) && activeWeapon != weapon )
			break
	}
	//print( "AwaitingWeaponOwnerADSEnd reached last line!" )
}
#endif