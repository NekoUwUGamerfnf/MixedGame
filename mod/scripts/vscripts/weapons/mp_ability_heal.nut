global function OnWeaponPrimaryAttack_ability_heal
// modified!
global function OnWeaponTossPrep_ability_heal
global function OnWeaponTossReleaseAnimEvent_ability_heal
global function OnProjectileCollision_ability_heal
global function AddStimModifier

struct
{
	// modified, for saving stim's mods
	array<string> stimModifiers = []
} file

// stim modifiers functions!
void function AddStimModifier( string modName )
{
	if ( !( file.stimModifiers.contains( modName ) ) )
		file.stimModifiers.append( modName )
}

bool function HasStimModifier( array<string> mods )
{
	bool isModdedStim = false
	foreach ( string mod in file.stimModifiers )
	{
		if ( mods.contains( mod ) ) // has at least one modifier
			return true
	}

	return false
}

var function OnWeaponPrimaryAttack_ability_heal( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded stim checks!
	array<string> mods = weapon.GetMods()
	if( HasStimModifier( mods ) )
		return OnWeaponPrimaryAttack_ability_modded_stim( weapon, attackParams )
	//

	entity ownerPlayer = weapon.GetWeaponOwner()
	Assert( IsValid( ownerPlayer) && ownerPlayer.IsPlayer() )
	if ( IsValid( ownerPlayer ) && ownerPlayer.IsPlayer() )
	{
		if ( ownerPlayer.GetCinematicEventFlags() & CE_FLAG_CLASSIC_MP_SPAWNING )
			return false

		if ( ownerPlayer.GetCinematicEventFlags() & CE_FLAG_INTRO )
			return false
	}

	float duration = weapon.GetWeaponSettingFloat( eWeaponVar.fire_duration )
	if( weapon.HasMod( "bc_super_stim" ) && weapon.HasMod( "dev_mod_low_recharge" ) )
		StimPlayer( ownerPlayer, duration, 0.15 )
	else
		StimPlayer( ownerPlayer, duration )

	PlayerUsedOffhand( ownerPlayer, weapon )

#if SERVER
#if BATTLECHATTER_ENABLED
	TryPlayWeaponBattleChatterLine( ownerPlayer, weapon )
#endif //
#else //
	Rumble_Play( "rumble_stim_activate", {} )
#endif //

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
}


// modified callbacks
void function OnWeaponTossPrep_ability_heal( entity weapon, WeaponTossPrepParams prepParams )
{
	// modded stim checks!
	array<string> mods = weapon.GetMods()
	if ( HasStimModifier( mods ) )
		return OnWeaponTossPrep_ability_modded_stim( weapon, prepParams )
	//
}

var function OnWeaponTossReleaseAnimEvent_ability_heal( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded stim checks!
	array<string> mods = weapon.GetMods()
	if ( HasStimModifier( mods ) )
		return OnWeaponTossReleaseAnimEvent_ability_modded_stim( weapon, attackParams )
	//
}

void function OnProjectileCollision_ability_heal( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	// modded stim checks!
	array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // modded weapon refire behavior
	if ( HasStimModifier( mods ) )
		return OnProjectileCollision_ability_modded_stim( projectile, pos, normal, hitEnt, hitbox, isCritical )
	//
}
