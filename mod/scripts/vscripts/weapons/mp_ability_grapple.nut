untyped
global function OnWeaponActivate_ability_grapple
global function OnWeaponPrimaryAttack_ability_grapple
global function OnWeaponAttemptOffhandSwitch_ability_grapple
global function CodeCallback_OnGrapple
global function GrappleWeaponInit

#if SERVER
global function OnWeaponNpcPrimaryAttack_ability_grapple
#endif

// modified callbacks
global function OnWeaponOwnerChange_ability_grapple
global function OnProjectileCollision_ability_grapple

global function AddCallback_MpAbilityGrapplePrimaryAttack
global function AddCallback_OnGrapple


struct
{
	int grappleExplodeImpactTable

	// modified callback
	array< void functionref( entity, WeaponPrimaryAttackParams ) > weaponPrimaryAttackCallbacks
	array< void functionref( entity, entity, vector, vector ) > onGrappleCallbacks
} file

const int GRAPPLEFLAG_CHARGED	= (1<<0)

void function GrappleWeaponInit()
{
	// modified fix: manually do a impact fx
	//file.grappleExplodeImpactTable = PrecacheImpactEffectTable( "exp_rocket_archer" )
	//file.grappleExplodeImpactTable = PrecacheImpactEffectTable( "40mm_mortar_shots" ) // this may cause client desync!
#if SERVER
	// modified signal, required!!!
	RegisterSignal( "OnGrappled" )
	RegisterSignal( "GrappleCancelled" )
#endif
}

// modified for cooldowns
void function OnWeaponOwnerChange_ability_grapple( entity weapon, WeaponOwnerChangedParams changeParams )
{

}

void function OnWeaponActivate_ability_grapple( entity weapon )
{
	entity weaponOwner = weapon.GetWeaponOwner()
	int pmLevel = GetPVEAbilityLevel( weapon )
	if ( (pmLevel >= 2) && IsValid( weaponOwner ) )
		weapon.SetScriptTime0( Time() )
	else
		weapon.SetScriptTime0( 0.0 )

	// clear "charged-up" flag:
	{
		int oldFlags = weapon.GetScriptFlags0()
		weapon.SetScriptFlags0( oldFlags & ~GRAPPLEFLAG_CHARGED )
	}
}

int function GetPVEAbilityLevel( entity weapon )
{
	if ( weapon.HasMod( "pm2" ) )
		return 2
	if ( weapon.HasMod( "pm1" ) )
		return 1
	if ( weapon.HasMod( "pm0" ) )
		return 0

	return -1
}

var function OnWeaponPrimaryAttack_ability_grapple( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapons
	if( weapon.HasMod( "zipline_gun" ) )
	{
		return OnWeaponPrimaryAttack_ability_zipline_gun( weapon, attackParams )
	}

	entity owner = weapon.GetWeaponOwner()

#if SERVER
	if ( owner.MayGrapple() )
	{
		#if BATTLECHATTER_ENABLED
			TryPlayWeaponBattleChatterLine( owner, weapon ) //Note that this is fired whenever you fire the grapple, not when you've successfully grappled something. No callback for that unfortunately...
		#endif
	}
#endif

	if ( owner.IsPlayer() )
	{
		int pmLevel = GetPVEAbilityLevel( weapon )
		float scriptTime = weapon.GetScriptTime0()
		if ( (pmLevel >= 2) && (scriptTime != 0.0) )
		{
			float chargeMaxTime = weapon.GetWeaponSettingFloat( eWeaponVar.custom_float_0 )
			float chargeTime = (Time() - scriptTime)
			if ( chargeTime >= chargeMaxTime )
			{
				int oldFlags = weapon.GetScriptFlags0()
				weapon.SetScriptFlags0( oldFlags | GRAPPLEFLAG_CHARGED )
			}
		}
	}

	PlayerUsedOffhand( owner, weapon )

	owner.Grapple( attackParams.dir )

	// modified signal
#if SERVER
	owner.Signal( "OnGrappled" )
#endif

	// run callbacks
	foreach ( void functionref( entity, WeaponPrimaryAttackParams ) callbackFunc in file.weaponPrimaryAttackCallbacks )
		callbackFunc( weapon, attackParams )

	return 1
}

bool function OnWeaponAttemptOffhandSwitch_ability_grapple( entity weapon )
{
	entity ownerPlayer = weapon.GetWeaponOwner()
	bool allowSwitch = (ownerPlayer.GetSuitGrapplePower() >= 100.0)

	if ( !allowSwitch )
	{
		entity ownerPlayer = weapon.GetWeaponOwner()
		ownerPlayer.Grapple( <0,0,1> )
	}

	// limit removed for now
	/*
	if( weapon.HasMod( "pm2" ) && !allowSwitch )
	{
		entity ownerPlayer = weapon.GetWeaponOwner()
		#if SERVER
		SendHudMessage(ownerPlayer, "需要完全充满以使用加长钩爪", -1, -0.35, 255, 255, 100, 255, 0, 3, 0)
		#endif
	}
	*/

	return allowSwitch
}

void function DoGrappleImpactExplosion( entity player, entity grappleWeapon, entity hitent, vector hitpos, vector hitNormal )
{
#if CLIENT
	if ( !grappleWeapon.ShouldPredictProjectiles() )
		return
#endif //

	vector origin = hitpos + hitNormal * 16.0
	int damageType = (DF_RAGDOLL | DF_EXPLOSION | DF_ELECTRICAL)
	entity nade = FireWeaponGrenade_RecordData( grappleWeapon, origin, hitNormal, <0,0,0>, 0.01, damageType, damageType, true, true, true )
	if ( !nade )
		return

	// modified fix: manually do a impact fx
	//nade.SetImpactEffectTable( file.grappleExplodeImpactTable )
	nade.GrenadeExplode( hitNormal )
	#if SERVER
		PlayImpactFXTable( hitpos, player, "exp_satchel" )
	#endif
}

void function CodeCallback_OnGrapple( entity player, entity hitent, vector hitpos, vector hitNormal )
{
#if SERVER
#if MP
	PIN_PlayerAbility( player, "grapple", "mp_ability_grapple", {pos = hitpos}, 0 )
#endif //
#endif //

	// assault impact:
	// make them in a function, so callbacks below can set up
	TryGrappleImpactExplosion( player, hitent, hitpos, hitNormal )
	/*
	{
		if ( !IsValid( player ) )
			return

		entity grappleWeapon = null
		foreach( entity offhand in player.GetOffhandWeapons() )
		{
			if( offhand.GetWeaponClassName() == "mp_ability_grapple" )
				grappleWeapon = offhand
		}

		if ( !IsValid( grappleWeapon ) )
			return
		if ( !grappleWeapon.GetWeaponSettingBool( eWeaponVar.grapple_weapon ) )
			return

		int flags = grappleWeapon.GetScriptFlags0()
		if ( ! (flags & GRAPPLEFLAG_CHARGED) )
			return

		int expDamage = grappleWeapon.GetWeaponSettingInt( eWeaponVar.explosion_damage )
		if ( expDamage <= 0 )
			return

		DoGrappleImpactExplosion( player, grappleWeapon, hitent, hitpos, hitNormal )
	}
	*/

	// run callbacks
	foreach ( void functionref( entity, entity, vector, vector ) callbackFunc in file.onGrappleCallbacks )
		callbackFunc( player, hitent, hitpos, hitNormal )
}

// splited function
void function TryGrappleImpactExplosion( entity player, entity hitent, vector hitpos, vector hitNormal )
{
	if ( !IsValid( player ) )
		return

	entity grappleWeapon = null
	foreach( entity offhand in player.GetOffhandWeapons() )
	{
		if( offhand.GetWeaponClassName() == "mp_ability_grapple" )
			grappleWeapon = offhand
	}

	if ( !IsValid( grappleWeapon ) )
		return
	if ( !grappleWeapon.GetWeaponSettingBool( eWeaponVar.grapple_weapon ) )
		return

	int flags = grappleWeapon.GetScriptFlags0()
	if ( ! (flags & GRAPPLEFLAG_CHARGED) )
		return

	int expDamage = grappleWeapon.GetWeaponSettingInt( eWeaponVar.explosion_damage )
	if ( expDamage <= 0 )
		return

	DoGrappleImpactExplosion( player, grappleWeapon, hitent, hitpos, hitNormal )
}

// modified
void function OnProjectileCollision_ability_grapple( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // modded weapon refire behavior
	if ( mods.contains( "zipline_gun" ) )
		return OnProjectileCollision_ability_zipline_gun( projectile, pos, normal, hitEnt, hitbox, isCritical )
}


#if SERVER
var function OnWeaponNpcPrimaryAttack_ability_grapple( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity owner = weapon.GetWeaponOwner()

	owner.GrappleNPC( attackParams.dir )

	return 1
}
#endif


// modified callback
void function AddCallback_MpAbilityGrapplePrimaryAttack( void functionref( entity, WeaponPrimaryAttackParams ) callbackFunc )
{
	file.weaponPrimaryAttackCallbacks.append( callbackFunc )
}

void function AddCallback_OnGrapple( void functionref( entity, entity, vector, vector ) callbackFunc )
{
	file.onGrappleCallbacks.append( callbackFunc )
}