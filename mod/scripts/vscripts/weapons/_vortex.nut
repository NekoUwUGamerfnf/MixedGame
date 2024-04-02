untyped

global function Vortex_Init

global function CreateVortexSphere
global function DestroyVortexSphereFromVortexWeapon
global function EnableVortexSphere
// northstar modified utility
global function RegisterNewVortexIgnoreClassname
global function RegisterNewVortexIgnoreClassnames
// mods ignoring
global function RegisterNewVortexIgnoreWeaponMod
global function RegisterNewVortexIgnoreWeaponMods
// let modded vortex weapon get what we ignoring
global function GetVortexIgnoreClassnames
global function GetVortexIgnoreWeaponMods
//
#if SERVER
global function ValidateVortexImpact
global function TryVortexAbsorb
global function SetVortexSphereBulletHitRules
global function SetVortexSphereProjectileHitRules
#endif
global function VortexDrainedByImpact
global function VortexPrimaryAttack
global function GetVortexSphereCurrentColor
global function GetShieldTriLerpColor
global function IsVortexing
#if SERVER
global function Vortex_HandleElectricDamage
global function VortexSphereDrainHealthForDamage
global function Vortex_CreateImpactEventData
// modified to globalize
global function Vortex_SpawnShieldPingFX
//
global function Vortex_SpawnHeatShieldPingFX
#endif

global function Vortex_SetTagName
global function Vortex_SetBulletCollectionOffset

global function CodeCallback_OnVortexHitBullet
global function CodeCallback_OnVortexHitProjectile

const AMPED_WALL_IMPACT_FX = $"P_impact_xo_shield_cp"

global const PROTO_AMPED_WALL = "proto_amped_wall"
global const GUN_SHIELD_WALL = "gun_shield_wall"
const PROX_MINE_MODEL = $"models/weapons/caber_shot/caber_shot_thrown.mdl"

const VORTEX_SPHERE_COLOR_CHARGE_FULL		= <115, 247, 255>	// blue
const VORTEX_SPHERE_COLOR_CHARGE_MED		= <200, 128, 80>	// orange
const VORTEX_SPHERE_COLOR_CHARGE_EMPTY		= <200, 80, 80>	// red
const VORTEX_SPHERE_COLOR_PAS_ION_VORTEX	= <115, 174, 255>	// blue
const AMPED_DAMAGE_SCALAR = 1.5

const VORTEX_SPHERE_COLOR_CROSSOVERFRAC_FULL2MED	= 0.75  // from zero to this fraction, fade between full and medium charge colors
const VORTEX_SPHERE_COLOR_CROSSOVERFRAC_MED2EMPTY	= 0.95  // from "full2med" to this fraction, fade between medium and empty charge colors

const VORTEX_BULLET_ABSORB_COUNT_MAX = 32
const VORTEX_PROJECTILE_ABSORB_COUNT_MAX = 32

const VORTEX_TIMED_EXPLOSIVE_FUSETIME				= 2.75	// fuse time for absorbed projectiles
const VORTEX_TIMED_EXPLOSIVE_FUSETIME_WARNINGFRAC	= 0.75	// wait this fraction of the fuse time before warning the player it's about to explode

const VORTEX_EXP_ROUNDS_RETURN_SPREAD_XY = 0.15
const VORTEX_EXP_ROUNDS_RETURN_SPREAD_Z = 0.075

const VORTEX_ELECTRIC_DAMAGE_CHARGE_DRAIN_MIN = 0.1  // fraction of charge time
const VORTEX_ELECTRIC_DAMAGE_CHARGE_DRAIN_MAX = 0.3

//The shotgun spams a lot of pellets that deal too much damage if they return full damage.
const VORTEX_SHOTGUN_DAMAGE_RATIO = 0.25


const SHIELD_WALL_BULLET_FX = $"P_impact_xo_shield_cp"
const SHIELD_WALL_EXPMED_FX = $"P_impact_exp_med_xo_shield_CP"

const SIGNAL_ID_BULLET_HIT_THINK = "signal_id_bullet_hit_think"

const VORTEX_EXPLOSIVE_WARNING_SFX_LOOP = "Weapon_Vortex_Gun.ExplosiveWarningBeep"

const VORTEX_PILOT_WEAPON_WEAKNESS_DAMAGESCALE = 6.0

// These match the strings in the WeaponEd dropdown box for vortex_refire_behavior
global const VORTEX_REFIRE_NONE					= ""
global const VORTEX_REFIRE_ABSORB				= "absorb"
global const VORTEX_REFIRE_BULLET				= "bullet"
global const VORTEX_REFIRE_EXPLOSIVE_ROUND		= "explosive_round"
global const VORTEX_REFIRE_ROCKET				= "rocket"
global const VORTEX_REFIRE_GRENADE				= "grenade"
global const VORTEX_REFIRE_GRENADE_LONG_FUSE	= "grenade_long_fuse"

// northstar modified utility
// const VortexIgnoreClassnames
table<string, bool> VortexIgnoreClassnames = {
	["mp_titancore_flame_wave"] = true,
	["mp_ability_grapple"] = true,
	["mp_ability_shifter"] = true,
}
//

// modified utility: allow ignore specific weapon mod
// vanilla should be empty
table<string, bool> VortexIgnoreWeaponMods

// nessie modified utility
global function Vortex_GetRefiredProjectileMods
global function Vortex_AddProjectileModToKeepDataOnRefire

// basic behavior override
global function Vortex_AddBehaviorOverride_WeaponName
global function Vortex_AddBehaviorOverride_WeaponMod

// these functions are not globalized because there's no need we share the struct to other files
/*
global function Vortex_HasBehaviorOverride_WeaponName
global function Vortex_GetBehaviorOverride_WeaponName
global function Vortex_HasBehaviorOverride_WeaponMod
global function Vortex_GetBehaviorOverride_WeaponMod

global function Vortex_WeaponOrProjectileHasBehaviorOverride
global function Vortex_GetBehaviorOverrideFromWeaponOrProjectile
*/

// impact data override
global function Vortex_AddImpactDataOverride_WeaponName
global function Vortex_AddImpactDataOverride_WeaponMod

global function Vortex_HasImpactDataOverride_WeaponName
global function Vortex_GetImpactDataOverride_WeaponName
global function Vortex_HasImpactDataOverride_WeaponMod
global function Vortex_GetImpactDataOverride_WeaponMod
global function Vortex_WeaponOrProjectileHasImpactDataOverride
global function Vortex_GetImpactDataOverrideFromWeaponOrProjectile

// respawn messy functions rework
#if SERVER
global function Vortex_CalculateBulletHitDamage
global function Vortex_CalculateProjectileHitDamage
#endif

// respawn hardcode turns to settings
global function Vortex_SetWeaponVortexColorUpdateFunc
global function Vortex_ClearWeaponVortexColorUpdateFunc

// global callbacks when something hits vortex...
global function AddCallback_OnVortexHitBullet
global function AddCallback_OnVortexHitProjectile

// callbacks per vortexSphere entity
global function AddEntityCallback_OnVortexHitBullet
global function AddEntityCallback_OnVortexHitProjectile

// this will run all callbacks from vortexHitBulletCallbacks, and entityVortexHitBulletCallbacks specified for current entity
global function RunEntityCallbacks_OnVortexHitBullet
// this will run all callbacks from vortexHitProjectileCallbacks, and entityVortexHitProjectileCallbacks specified for current entity
global function RunEntityCallbacks_OnVortexHitProjectile

#if SERVER
// modified callbacks
global function AddCallback_VortexDrainedByImpact

global function AddCallback_CalculateVortexBulletHitDamage
global function AddCallback_CalculateVortexProjectileHitDamage

global function AddCallback_OnProjectileRefiredByVortex_ClassName // allows specific projectile being fired to trigger callback
global function RunCallback_OnProjectileRefiredByVortex_ClassName // run callback for specific classname

// modified utility
/*
	note: 
		grenades deal damage before calling OnProjectileExplode() callback
		missiles deal damage before callbacks
		bolts won't do OnProjectileExplode() callback. their explosion damage happens after OnProjectileCollision() callback
*/
// on refire by vortex, certain weapon mod will be retained so we can get correct damage
global function Vortex_AddWeaponModRetainedOnRefire

// using a modified function so we can get whether they're vortexed or not
global function Vortex_SetProjectileRefiredByVortex

// modified settings override: use our impact data to handle modded projectile damage
/*
global function OnProjectileCollision_VortexRefiredDamageOverride
global function Vortex_RefiredMissileImpactExplosion
global function Vortex_RefiredBoltImpactExplosion
global function Vortex_RefiredGrenadeExplode
global function Vortex_RefiredProjectileExplodeForCollisionCallback
*/

//global function 
#endif

// WIP: basic behavior override
struct VortexBehaviorOverride
{
	string impact_sound_1p				// leave empty "" to use weapon's default value
	string impact_sound_3p				// leave empty "" to use weapon's default value
	// "vortex_impact_effect" is a weapon settings that can be modified by mods, why not.
	// but to keep everything modifiable through script, I'd like to add it here
	asset vortex_impact_effect			// leave empty $"" to use weapon(or mod)'s default value
	string projectile_ignores_vortex	// projectile only. leave empty "" to use weapon's default value
}

// absorb impactdata override
struct ImpactDataOverride
{
	asset absorb_effect					// leave empty $"" to use weapon's default value
	asset absorb_effect_third_person	// leave empty $"" to use weapon's default value
	string refire_behavior				// leave empty "" to use weapon's default value
}

// damage data storing
// not splited into npc damage, they're stored during refire
struct RefiredProjectileDamageData
{
	int damage_near_value
	int damage_far_value
	int damage_very_far_value
	int damage_near_value_titanarmor
	int damage_far_value_titanarmor
	int damage_very_far_value_titanarmor
	int damage_near_distance
	int damage_far_distance
	int damage_very_far_distance

	int explosion_damage
	int explosion_damage_heavy_armor
	int explosionradius
	int explosion_inner_radius

	float damage_headshot_scale
	float critical_hit_damage_scale
}

struct
{
	// utility
	table< entity, array<string> > vortexRefiredProjectileMods
	array<string> projectileModsToKeepDataOnRefire
	// basic behavior override
	table< string, VortexBehaviorOverride > vortexBehaviorOverride_WeaponName
	table< string, table< string, VortexBehaviorOverride > > vortexBehaviorOverride_WeaponMod
	// absorb impactdata override
	table< string, ImpactDataOverride > vortexImpactDataOverride_WeaponName
	table< string, table< string, ImpactDataOverride > > vortexImpactDataOverride_WeaponMod

	// respawn messy functions rework
	table< entity, bool functionref( entity vortexSphere, entity attacker, entity projectile, bool takesDamage ) > vortexCustomProjectileHitRules // don't want to change entityStruct, use fileStruct instead
	// respawn hardcode turns to settings
	table<entity, void functionref( entity weapon, var sphereClientFXHandle = null )> vortexWeaponColorUpdateFunc

	array< void functionref( entity weapon, entity vortexSphere, var damageInfo ) > vortexHitBulletCallbacks
	array< void functionref( entity weapon, entity vortexSphere, entity attacker, entity projectile, vector contactPos ) > vortexHitProjectileCallbacks
	
	table< entity, array< void functionref( entity weapon, entity vortexSphere, var damageInfo ) > > entityVortexHitBulletCallbacks
	table< entity, array< void functionref( entity weapon, entity vortexSphere, entity attacker, entity projectile, vector contactPos ) > > entityVortexHitProjectileCallbacks

	array< float functionref( entity vortexWeapon, entity weapon, entity projectile, var damageType, float drainAmount ) > vortexDrainByImpactCallbacks
	array< float functionref( entity vortexSphere, var damageInfo, float damage ) > calculateVortexBulletHitDamageCallbacks
	array< float functionref( entity vortexSphere, entity attacker, entity projectile, float damage ) > calculateVortexProjectileHitDamageCallbacks

	table< string, array< void functionref( entity projectile, entity vortexWeapon ) > > onProjectileRefiredByVortexCallbacks_ClassName

	// modded utility
	table< string, array<string> > weaponModsToRetainOnVortexRefire

	// projectile behavior fix
	table< entity, bool > projectileRefiredByVortex
	int refireDataIndex
	table< int, RefiredProjectileDamageData > indexedProjectileDamagedata // for us store a index in impactData
	table< entity, RefiredProjectileDamageData > vortexRefiredProjectileDamageData
	table< entity, bool > refiredProjectileHitTargets
	table< entity, bool > projectileOverrideImpactDamageFromData // when impact, this projectile won't do it's original damage, but re-calculate damage from saved data
	table< entity, bool > projectileDoingRefiredExplosions // when triggering this, projectile itself won't deal explosion damage, but do an extra explosion from saved data
} file
//

// northstar modified utility
void function RegisterNewVortexIgnoreClassnames(table<string, bool> classTable)
{
	foreach(string classname, bool shouldignore in classTable)
	{
		RegisterNewVortexIgnoreClassname(classname, shouldignore)
	}
}
void function RegisterNewVortexIgnoreClassname(string classname, bool shouldignore)
{
	VortexIgnoreClassnames[classname] <- shouldignore
}
//

// modified utilities
void function RegisterNewVortexIgnoreWeaponMods( table<string, bool> classTable )
{
	foreach( string modname, bool shouldignore in classTable )
	{
		RegisterNewVortexIgnoreWeaponMod( modname, shouldignore )
	}
}
void function RegisterNewVortexIgnoreWeaponMod( string modname, bool shouldignore )
{
	VortexIgnoreWeaponMods[ modname ] <- shouldignore
}

array<string> function GetVortexIgnoreClassnames()
{
	array<string> ignoreArray
	foreach( string classname, bool shouldignore in VortexIgnoreClassnames )
	{
		if ( shouldignore && !ignoreArray.contains( classname ) )
			ignoreArray.append( classname )
	}

	return ignoreArray
}

array<string> function GetVortexIgnoreWeaponMods()
{
	array<string> ignoreArray
	foreach( string modname, bool shouldignore in VortexIgnoreWeaponMods )
	{
		if ( shouldignore && !ignoreArray.contains( modname ) )
			ignoreArray.append( modname )
	}

	return ignoreArray
}

// nessie modified utility
array<string> function Vortex_GetRefiredProjectileMods( entity projectile )
{
	if ( !( projectile in file.vortexRefiredProjectileMods ) )
		return projectile.ProjectileGetMods()

	array<string> refiredMods = file.vortexRefiredProjectileMods[ projectile ]
	if ( !ShouldKeepModsDataOnRefire( refiredMods ) )
		return projectile.ProjectileGetMods()
	
	return clone refiredMods // never return our array directly!
}

bool function ShouldKeepModsDataOnRefire( array<string> mods )
{
	foreach ( mod in mods )
	{
		if ( file.projectileModsToKeepDataOnRefire.contains( mod ) )
			return true
	}
	return false
}

void function Vortex_AddProjectileModToKeepDataOnRefire( string mod )
{
	if ( !file.projectileModsToKeepDataOnRefire.contains( mod ) )
		file.projectileModsToKeepDataOnRefire.append( mod )
}

// BASIC BEHAVIOR OVERRIDE
void function Vortex_AddBehaviorOverride_WeaponName( string weaponName, string impactSound1p, string impactSound3p, asset vortexImpactEffect, string ignoresVortex )
{
	// construct
	VortexBehaviorOverride dataStruct
	dataStruct.impact_sound_1p = impactSound1p
	dataStruct.impact_sound_3p = impactSound3p
	dataStruct.vortex_impact_effect = vortexImpactEffect
	dataStruct.projectile_ignores_vortex = ignoresVortex

	if ( !( weaponName in file.vortexBehaviorOverride_WeaponName ) )
		file.vortexBehaviorOverride_WeaponName[ weaponName ] <- dataStruct
	else
		file.vortexBehaviorOverride_WeaponName[ weaponName ] = dataStruct
}

void function Vortex_AddBehaviorOverride_WeaponMod( string weaponName, string weaponMod, string impactSound1p, string impactSound3p, asset vortexImpactEffect, string ignoresVortex )
{
	VortexBehaviorOverride dataStruct
	dataStruct.impact_sound_1p = impactSound1p
	dataStruct.impact_sound_3p = impactSound3p
	dataStruct.vortex_impact_effect = vortexImpactEffect
	dataStruct.projectile_ignores_vortex = ignoresVortex

	// init done here
	if ( !( weaponName in file.vortexBehaviorOverride_WeaponMod ) )
		file.vortexBehaviorOverride_WeaponMod[ weaponName ] <- {}
	if ( !( weaponMod in file.vortexBehaviorOverride_WeaponMod[ weaponName ] ) )
		file.vortexBehaviorOverride_WeaponMod[ weaponName ][ weaponMod ] <- dataStruct
	else
		file.vortexBehaviorOverride_WeaponMod[ weaponName ][ weaponMod ] = dataStruct
}

bool function Vortex_HasBehaviorOverride_WeaponName( string weaponName )
{
	return weaponName in file.vortexBehaviorOverride_WeaponName
}

VortexBehaviorOverride function Vortex_GetBehaviorOverride_WeaponName( string weaponName )
{
	VortexBehaviorOverride overrideStruct
	if ( Vortex_HasBehaviorOverride_WeaponName( weaponName ) )
	{
		// never directly return a struct, use clone
		overrideStruct = clone file.vortexBehaviorOverride_WeaponName[ weaponName ]
	}

	return overrideStruct
}

bool function Vortex_HasBehaviorOverride_WeaponMod( string weaponName, string weaponMod )
{
	if ( weaponName in file.vortexBehaviorOverride_WeaponMod 
		 && weaponMod in file.vortexBehaviorOverride_WeaponMod[ weaponName ] )
		return true

	return false
}

VortexBehaviorOverride function Vortex_GetBehaviorOverride_WeaponMod( string weaponName, string weaponMod )
{
	VortexBehaviorOverride overrideStruct
	if ( Vortex_HasBehaviorOverride_WeaponMod( weaponName, weaponMod ) )
	{
		// never directly return a struct, use clone
		overrideStruct = clone file.vortexBehaviorOverride_WeaponMod[ weaponName ][ weaponMod ]
	}

	return overrideStruct
}

bool function Vortex_WeaponOrProjectileHasBehaviorOverride( entity weaponOrProjectile )
{
	string weaponName
	array<string> weaponMods

	if ( weaponOrProjectile.IsProjectile() )
	{
		weaponName = weaponOrProjectile.ProjectileGetWeaponClassName()
		weaponMods = Vortex_GetRefiredProjectileMods( weaponOrProjectile )
	}
	else
	{
		weaponName = weaponOrProjectile.GetWeaponClassName()
		weaponMods = weaponOrProjectile.GetMods()
	}

	foreach ( string mod in weaponMods )
	{
		//print( "weapon has mod " + mod + " registered: " + string( Vortex_HasBehaviorOverride_WeaponMod( weaponName, mod ) ) )
		if ( Vortex_HasBehaviorOverride_WeaponMod( weaponName, mod ) )
			return true
	}

	return false
}

VortexBehaviorOverride function Vortex_GetBehaviorOverrideFromWeaponOrProjectile( entity weaponOrProjectile )
{
	string weaponName
	array<string> weaponMods

	if ( weaponOrProjectile.IsProjectile() )
	{
		weaponName = weaponOrProjectile.ProjectileGetWeaponClassName()
		weaponMods = Vortex_GetRefiredProjectileMods( weaponOrProjectile )
	}
	else
	{
		weaponName = weaponOrProjectile.GetWeaponClassName()
		weaponMods = weaponOrProjectile.GetMods()
	}

	VortexBehaviorOverride overrideStruct
	bool hasWeaponOverride = weaponName in file.vortexBehaviorOverride_WeaponName
	bool foundModOverride = false
	// get from mod override
	foreach ( string mod in weaponMods )
	{
		if ( Vortex_HasBehaviorOverride_WeaponMod( weaponName, mod ) )
		{
			overrideStruct = Vortex_GetBehaviorOverride_WeaponMod( weaponName, mod )
			foundModOverride = true
			break
		}
	}
	// no mod override! try to find from weapon
	if ( !foundModOverride && hasWeaponOverride )
		overrideStruct = Vortex_GetBehaviorOverride_WeaponName( weaponName )

	return overrideStruct
}

// IMPACT DATA OVERRIDE
void function Vortex_AddImpactDataOverride_WeaponName( string weaponName, asset absorbFX, asset absorbFX_3p, string refireBehavior )
{
	// construct
	ImpactDataOverride dataStruct
	dataStruct.absorb_effect = absorbFX
	dataStruct.absorb_effect_third_person = absorbFX_3p
	dataStruct.refire_behavior = refireBehavior

	if ( !( weaponName in file.vortexImpactDataOverride_WeaponName ) )
		file.vortexImpactDataOverride_WeaponName[ weaponName ] <- dataStruct
	else
		file.vortexImpactDataOverride_WeaponName[ weaponName ] = dataStruct
}

void function Vortex_AddImpactDataOverride_WeaponMod( string weaponName, string weaponMod, asset absorbFX, asset absorbFX_3p, string refireBehavior )
{
	ImpactDataOverride dataStruct
	dataStruct.absorb_effect = absorbFX
	dataStruct.absorb_effect_third_person = absorbFX_3p
	dataStruct.refire_behavior = refireBehavior

	// init done here
	if ( !( weaponName in file.vortexImpactDataOverride_WeaponMod ) )
		file.vortexImpactDataOverride_WeaponMod[ weaponName ] <- {}
	if ( !( weaponMod in file.vortexImpactDataOverride_WeaponMod[ weaponName ] ) )
		file.vortexImpactDataOverride_WeaponMod[ weaponName ][ weaponMod ] <- dataStruct
	else
		file.vortexImpactDataOverride_WeaponMod[ weaponName ][ weaponMod ] = dataStruct
}

table function BuildImpactDataFromOverride( ImpactDataOverride overrideStruct )
{
	table impactData = {
		absorbFX = overrideStruct.absorb_effect,
		absorbFX_3p = overrideStruct.absorb_effect_third_person,
		refireBehavior = overrideStruct.refire_behavior,
	}

	return impactData
}

bool function Vortex_HasImpactDataOverride_WeaponName( string weaponName )
{
	return weaponName in file.vortexImpactDataOverride_WeaponName
}

table function Vortex_GetImpactDataOverride_WeaponName( string weaponName )
{
	if ( !Vortex_HasImpactDataOverride_WeaponName( weaponName ) )
		return {}

	return BuildImpactDataFromOverride( file.vortexImpactDataOverride_WeaponName[ weaponName ] )
}

bool function Vortex_HasImpactDataOverride_WeaponMod( string weaponName, string weaponMod )
{
	if ( weaponName in file.vortexImpactDataOverride_WeaponMod 
		 && weaponMod in file.vortexImpactDataOverride_WeaponMod[ weaponName ] )
		return true

	return false
}

table function Vortex_GetImpactDataOverride_WeaponMod( string weaponName, string weaponMod )
{
	if ( !Vortex_HasImpactDataOverride_WeaponMod( weaponName, weaponMod ) )
		return {}
	
	return BuildImpactDataFromOverride( file.vortexImpactDataOverride_WeaponMod[ weaponName ][ weaponMod ] )
}

bool function Vortex_WeaponOrProjectileHasImpactDataOverride( entity weaponOrProjectile )
{
	string weaponName
	array<string> weaponMods

	if ( weaponOrProjectile.IsProjectile() )
	{
		weaponName = weaponOrProjectile.ProjectileGetWeaponClassName()
		weaponMods = Vortex_GetRefiredProjectileMods( weaponOrProjectile )
	}
	else
	{
		weaponName = weaponOrProjectile.GetWeaponClassName()
		weaponMods = weaponOrProjectile.GetMods()
	}

	foreach ( string mod in weaponMods )
	{
		//print( "weapon has mod " + mod + " registered: " + string( Vortex_HasImpactDataOverride_WeaponMod( weaponName, mod ) ) )
		if ( Vortex_HasImpactDataOverride_WeaponMod( weaponName, mod ) )
			return true
	}

	return false
}

table function Vortex_GetImpactDataOverrideFromWeaponOrProjectile( entity weaponOrProjectile )
{
	string weaponName
	array<string> weaponMods

	if ( weaponOrProjectile.IsProjectile() )
	{
		weaponName = weaponOrProjectile.ProjectileGetWeaponClassName()
		weaponMods = Vortex_GetRefiredProjectileMods( weaponOrProjectile )
	}
	else
	{
		weaponName = weaponOrProjectile.GetWeaponClassName()
		weaponMods = weaponOrProjectile.GetMods()
	}

	bool hasWeaponOverride = weaponName in file.vortexImpactDataOverride_WeaponName
	// get from mod override
	foreach ( string mod in weaponMods )
	{
		if ( Vortex_HasImpactDataOverride_WeaponMod( weaponName, mod ) )
			return Vortex_GetImpactDataOverride_WeaponMod( weaponName, mod )
	}
	// no mod override! try to find from weapon
	if ( hasWeaponOverride )
		return Vortex_GetImpactDataOverride_WeaponName( weaponName )

	// default value
	return {}
}

// respawn messy functions rework
#if SERVER
float function Vortex_CalculateBulletHitDamage( entity vortexSphere, var damageInfo )
{
	entity weapon = DamageInfo_GetWeapon( damageInfo )
	float damage = ceil( DamageInfo_GetDamage( damageInfo ) )
	// debug print here for us testing heavy armor vortex
	//print( "damage: " + string( damage ) )

	Assert( damage >= 0, "Bug 159851 - Damage should be greater than or equal to 0.")
	damage = max( 0.0, damage )

	if ( IsValid( weapon ) )
		damage = HandleWeakToPilotWeapons( vortexSphere, weapon.GetWeaponClassName(), damage )

	//JFS - Arc Round bug fix for Monarch. Projectiles vortex callback doesn't even have damageInfo, so the shield modifier here doesn't exist in VortexSphereDrainHealthForDamage like it should.
	// GetShieldDamageModifier() has been modified, now passing victim into it
	//ShieldDamageModifier damageModifier = GetShieldDamageModifier( damageInfo )
	ShieldDamageModifier damageModifier = GetShieldDamageModifier( vortexSphere, damageInfo )
	damage *= damageModifier.damageScale

	// run callbacks
	foreach ( callbackFunc in file.calculateVortexBulletHitDamageCallbacks )
		damage = callbackFunc( vortexSphere, damageInfo, damage ) // update damage on each call

	return damage
}

float function Vortex_CalculateProjectileHitDamage( entity vortexSphere, entity attacker, entity projectile )
{
	// modified here: try to use our new utility for calculating projectile damage??
	// this will break projectile with falloff's damage behavior... but more accurate I think???
	// vortex cannot be used as heavy armor... revert back to this behavior
	float damage = float( projectile.GetProjectileWeaponSettingInt( eWeaponVar.damage_near_value ) )
	//	once damageInfo is passed correctly we'll use that instead of looking up the values from the weapon .txt file.
	//	local damage = ceil( DamageInfo_GetDamage( damageInfo ) )

	// modified: try to add heavy armor vortex sphere???
	// vortex cannot be used as heavy armor... at least we can't use SetArmorType() for them
	//if ( vortexSphere.GetArmorType() == ARMOR_TYPE_HEAVY )
	//	damage = float( projectile.GetProjectileWeaponSettingInt( eWeaponVar.damage_near_value_titanarmor ) )
	//
	// modified function in damage_calc_util.gnut. requires any other projectile weapon to be modified before taking effect
	// vortex cannot be used as heavy armor...
	//float damage = ceil( CalculateWeaponOrProjectileDamageAgainstTarget( projectile, vortexSphere ) )
	// debug
	//print( "damage: " + string( damage ) )

	if ( IsValid( projectile ) )
	{
		damage = HandleWeakToPilotWeapons( vortexSphere, projectile.ProjectileGetWeaponClassName(), damage )
		damage = damage + CalculateTitanSniperExtraDamage( projectile, vortexSphere )
	}

	// run callbacks
	foreach ( callbackFunc in file.calculateVortexProjectileHitDamageCallbacks )
		damage = callbackFunc( vortexSphere, attacker, projectile, damage ) // update damage on each call

	return damage
}
#endif

// respawn hardcode turns to settings
void function Vortex_SetWeaponVortexColorUpdateFunc( entity weapon, void functionref( entity weapon, var sphereClientFXHandle = null ) func )
{
	if ( !( weapon in file.vortexWeaponColorUpdateFunc ) )
		file.vortexWeaponColorUpdateFunc[ weapon ] <- null
	file.vortexWeaponColorUpdateFunc[ weapon ] = func
}

bool function Vortex_ClearWeaponVortexColorUpdateFunc( entity weapon )
{
	if ( !( weapon in file.vortexWeaponColorUpdateFunc ) )
		return false
	delete file.vortexWeaponColorUpdateFunc[ weapon ]
	return true
}

void functionref( entity weapon, var sphereClientFXHandle = null ) function GetWeaponVortexColorUpdateFunc( entity weapon )
{
	// default return value: use color update func in this file
	if ( !( weapon in file.vortexWeaponColorUpdateFunc ) || file.vortexWeaponColorUpdateFunc[ weapon ] == null )
		return VortexSphereColorUpdate
	
	return file.vortexWeaponColorUpdateFunc[ weapon ]
}

// modded callbacks
void function AddCallback_OnVortexHitBullet( void functionref( entity weapon, entity vortexSphere, var damageInfo ) callbackFunc )
{
	if ( !file.vortexHitBulletCallbacks.contains( callbackFunc ) )
		file.vortexHitBulletCallbacks.append( callbackFunc )
}

void function AddCallback_OnVortexHitProjectile( void functionref( entity weapon, entity vortexSphere, entity attacker, entity projectile, vector contactPos ) callbackFunc )
{
	if ( !file.vortexHitProjectileCallbacks.contains( callbackFunc ) )
		file.vortexHitProjectileCallbacks.append( callbackFunc )
}

void function AddEntityCallback_OnVortexHitBullet( entity vortexSphere, void functionref( entity weapon, entity vortexSphere, var damageInfo ) callbackFunc )
{
	if ( !( vortexSphere in file.entityVortexHitBulletCallbacks ) )
		file.entityVortexHitBulletCallbacks[ vortexSphere ] <- []

	if ( !file.entityVortexHitBulletCallbacks[ vortexSphere ].contains( callbackFunc ) )
		file.entityVortexHitBulletCallbacks[ vortexSphere ].append( callbackFunc )
}

void function AddEntityCallback_OnVortexHitProjectile( entity vortexSphere, void functionref( entity weapon, entity vortexSphere, entity attacker, entity projectile, vector contactPos ) callbackFunc )
{
	if ( !( vortexSphere in file.entityVortexHitProjectileCallbacks ) )
		file.entityVortexHitProjectileCallbacks[ vortexSphere ] <- []

	if ( !file.entityVortexHitProjectileCallbacks[ vortexSphere ].contains( callbackFunc ) )
		file.entityVortexHitProjectileCallbacks[ vortexSphere ].append( callbackFunc )
}

// this will run all callbacks from vortexHitBulletCallbacks, and entityVortexHitBulletCallbacks specified for current entity
void function RunEntityCallbacks_OnVortexHitBullet( entity vortexSphere, entity weapon, var damageInfo )
{
	foreach ( callbackFunc in file.vortexHitBulletCallbacks )
	{
		callbackFunc( weapon, vortexSphere, damageInfo )
	}
	
	if ( vortexSphere in file.entityVortexHitBulletCallbacks )
	{
		foreach ( callbackFunc in file.entityVortexHitBulletCallbacks[ vortexSphere ] )
		{
			callbackFunc( weapon, vortexSphere, damageInfo )
		}
	}
}

// this will run all callbacks from vortexHitProjectileCallbacks, and entityVortexHitProjectileCallbacks specified for current entity
void function RunEntityCallbacks_OnVortexHitProjectile( entity vortexSphere, entity weapon, entity attacker, entity projectile, vector contactPos )
{
	foreach ( callbackFunc in file.vortexHitProjectileCallbacks )
	{
		callbackFunc( weapon, vortexSphere, attacker, projectile, contactPos )
	}
	
	if ( vortexSphere in file.entityVortexHitProjectileCallbacks )
	{
		foreach ( callbackFunc in file.entityVortexHitProjectileCallbacks[ vortexSphere ] )
		{
			callbackFunc( weapon, vortexSphere, attacker, projectile, contactPos )
		}
	}
}

#if SERVER
// modded callbacks
void function AddCallback_VortexDrainedByImpact( float functionref( entity vortexWeapon, entity weapon, entity projectile, var damageType, float drainAmount ) callbackFunc )
{
	if ( !file.vortexDrainByImpactCallbacks.contains( callbackFunc ) )
		file.vortexDrainByImpactCallbacks.append( callbackFunc )
}

void function AddCallback_CalculateVortexBulletHitDamage( float functionref( entity vortexSphere, var damageInfo, float damage ) callbackFunc )
{
	if ( !file.calculateVortexBulletHitDamageCallbacks.contains( callbackFunc ) )
		file.calculateVortexBulletHitDamageCallbacks.append( callbackFunc )
}

void function AddCallback_CalculateVortexProjectileHitDamage( float functionref( entity vortexSphere, entity attacker, entity projectile, float damage ) callbackFunc )
{
	if ( !file.calculateVortexProjectileHitDamageCallbacks.contains( callbackFunc ) )
		file.calculateVortexProjectileHitDamageCallbacks.append( callbackFunc )
}

void function AddCallback_OnProjectileRefiredByVortex_ClassName( string className, void functionref( entity projectile, entity vortexWeapon ) callbackFunc )
{
	if ( !( className in file.onProjectileRefiredByVortexCallbacks_ClassName ) )
		file.onProjectileRefiredByVortexCallbacks_ClassName[ className ] <- []
	
	if ( !file.onProjectileRefiredByVortexCallbacks_ClassName[ className ].contains( callbackFunc ) )
		file.onProjectileRefiredByVortexCallbacks_ClassName[ className ].append( callbackFunc )
}

void function RunCallback_OnProjectileRefiredByVortex_ClassName( string className, entity projectile, entity vortexWeapon )
{
	if ( !( className in file.onProjectileRefiredByVortexCallbacks_ClassName ) )
		return

	foreach ( callbackFunc in file.onProjectileRefiredByVortexCallbacks_ClassName[ className ] )
		callbackFunc( projectile, vortexWeapon )
}

// modified utility after adding HACK_ProjectileAddMod
void function Vortex_AddWeaponModRetainedOnRefire( string weaponName, string modName )
{
	if ( !( weaponName in file.weaponModsToRetainOnVortexRefire ) )
		file.weaponModsToRetainOnVortexRefire[ weaponName ] <- []
	
	if ( !file.weaponModsToRetainOnVortexRefire[ weaponName ].contains( modName ) )
		file.weaponModsToRetainOnVortexRefire[ weaponName ].append( modName )
}

array<string> function GetWeaponModsRetainedOnRefire( string weaponName )
{
	if ( !( weaponName in file.weaponModsToRetainOnVortexRefire ) )
		return []
	
	return file.weaponModsToRetainOnVortexRefire[ weaponName ]
}

// modified radius damage data storing

// modified utility
void function Vortex_SetProjectileRefiredByVortex( entity projectile, bool refired )
{
	projectile.SetVortexRefired( refired )
	
	if ( !( projectile in file.projectileRefiredByVortex ) )
		file.projectileRefiredByVortex[ projectile ] <- false // default value
	file.projectileRefiredByVortex[ projectile ] = refired
}

bool function Vortex_IsProjectileRefiredByVortex( entity projectile )
{
	if ( !( projectile in file.projectileRefiredByVortex ) )
		return false // default value

	return file.projectileRefiredByVortex[ projectile ]
}
#endif // SERVER

table vortexImpactWeaponInfo

const DEG_COS_60 = cos( 60 * DEG_TO_RAD )

function Vortex_Init()
{
	PrecacheParticleSystem( SHIELD_WALL_BULLET_FX )
	GetParticleSystemIndex( SHIELD_WALL_BULLET_FX )
	PrecacheParticleSystem( SHIELD_WALL_EXPMED_FX )
	GetParticleSystemIndex( SHIELD_WALL_EXPMED_FX )
	PrecacheParticleSystem( AMPED_WALL_IMPACT_FX )
	GetParticleSystemIndex( AMPED_WALL_IMPACT_FX )

	RegisterSignal( SIGNAL_ID_BULLET_HIT_THINK )
	RegisterSignal( "VortexStopping" )

	RegisterSignal( "VortexAbsorbed" )
	RegisterSignal( "VortexFired" )
	RegisterSignal( "Script_OnDamaged" )

	// fixing instal vortex refire for tf2
	// delay 1 frame to fire back if we're not collecting more bullets/projectiles
	RegisterSignal( "DelayedVortexFireBack" )

	// add damage callback for every classes to handle damage override
	#if SERVER
		// shared function from levels_util.gnut
		foreach ( string className in Levels_GetAllVulnerableEntityClasses() )
			AddDamageCallback( className, VortexRefiredProjectileDamageOverride )
	#endif
}

// modified callback func
#if SERVER
void function VortexRefiredProjectileDamageOverride( entity ent, var damageInfo )
{
	entity inflictor = DamageInfo_GetInflictor( damageInfo )
	if ( !IsValid( inflictor ) )
		return
	if ( !inflictor.IsProjectile() )
		return
	
	if ( inflictor in file.projectileOverrideImpactDamageFromData )
	{
		// grenades deal impact damage earlier than their OnProjectileCollision() callbacks
		if ( inflictor instanceof CBaseGrenade )

		
		// this means projectile dealing explosion damage to target
		if ( !( inflictor in file.refiredProjectileHitTargets ) )
		{
			
		}
	}
}
#endif
//

#if SERVER
var function VortexBulletHitRules_Default( entity vortexSphere, var damageInfo )
{
	return damageInfo
}

// WTF RESPAWN? why not pass the projectile entity on vortex hit? modified
//bool function VortexProjectileHitRules_Default( entity vortexSphere, entity attacker, bool takesDamageByDefault )
bool function VortexProjectileHitRules_Default( entity vortexSphere, entity attacker, entity projectile, bool takesDamageByDefault )
{
	return takesDamageByDefault
}

void function SetVortexSphereBulletHitRules( entity vortexSphere, var functionref( entity, var ) customRules  )
{
	vortexSphere.e.BulletHitRules = customRules
}

// WTF RESPAWN? why not pass the projectile entity on vortex hit? modified
//void function SetVortexSphereProjectileHitRules( entity vortexSphere, bool functionref( entity, entity, bool ) customRules  )
void function SetVortexSphereProjectileHitRules( entity vortexSphere, bool functionref( entity vortexSphere, entity attacker, entity projectile, bool takesDamage ) customRules )
{
	//vortexSphere.e.ProjectileHitRules = customRules // don't want to change entityStruct, use fileStruct instead
	if ( !( vortexSphere in file.vortexCustomProjectileHitRules ) )
		file.vortexCustomProjectileHitRules[ vortexSphere ] <- null // default value
	file.vortexCustomProjectileHitRules[ vortexSphere ] = customRules
}
#endif
function CreateVortexSphere( entity vortexWeapon, bool useCylinderCheck, bool blockOwnerWeapon, int sphereRadius = 40, int bulletFOV = 180 )
{
	entity owner = vortexWeapon.GetWeaponOwner()
	Assert( owner )

	#if SERVER
		//printt( "util ent:", vortexWeapon.GetWeaponUtilityEntity() )
		Assert ( !vortexWeapon.GetWeaponUtilityEntity(), "Tried to create more than one vortex sphere on a vortex weapon!" )

		entity vortexSphere = CreateEntity( "vortex_sphere" )
		Assert( vortexSphere )

		int spawnFlags = SF_ABSORB_BULLETS | SF_BLOCK_NPC_WEAPON_LOF

		if ( useCylinderCheck )
		{
			spawnFlags = spawnFlags | SF_ABSORB_CYLINDER
			vortexSphere.kv.height = sphereRadius * 2
		}

		if ( blockOwnerWeapon )
			spawnFlags = spawnFlags | SF_BLOCK_OWNER_WEAPON

		vortexSphere.kv.spawnflags = spawnFlags

		vortexSphere.kv.enabled = 0
		vortexSphere.kv.radius = sphereRadius
		vortexSphere.kv.bullet_fov = bulletFOV
		vortexSphere.kv.physics_pull_strength = 25
		vortexSphere.kv.physics_side_dampening = 6
		vortexSphere.kv.physics_fov = 360
		vortexSphere.kv.physics_max_mass = 2
		vortexSphere.kv.physics_max_size = 6
		Assert( owner.IsNPC() || owner.IsPlayer(), "Vortex script expects the weapon owner to be a player or NPC." )

		SetVortexSphereBulletHitRules( vortexSphere, VortexBulletHitRules_Default )
		SetVortexSphereProjectileHitRules( vortexSphere, VortexProjectileHitRules_Default )

		DispatchSpawn( vortexSphere )

		vortexSphere.SetOwner( owner )

		if ( owner.IsNPC() )
		{
			vortexSphere.SetParent( owner, "PROPGUN" )
			vortexSphere.SetLocalOrigin( Vector( 0, 35, 0 ) )
		}
		else
		{
			vortexSphere.SetParent( owner )
			vortexSphere.SetLocalOrigin( Vector( 0, 10, -30 ) )
		}
		vortexSphere.SetAbsAngles( Vector( 0, 0, 0 ) ) //Setting local angles on a parented object is not supported

		vortexSphere.SetOwnerWeapon( vortexWeapon )
		vortexWeapon.SetWeaponUtilityEntity( vortexSphere )
	#endif

	SetVortexAmmo( vortexWeapon, 0 )
}


function EnableVortexSphere( entity vortexWeapon )
{
	string tagname = GetVortexTagName( vortexWeapon )
	entity weaponOwner = vortexWeapon.GetWeaponOwner()
	local hasBurnMod = vortexWeapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod )

	#if SERVER
		entity vortexSphere = vortexWeapon.GetWeaponUtilityEntity()
		Assert( vortexSphere )
		vortexSphere.FireNow( "Enable" )

		thread SetPlayerUsingVortex( weaponOwner, vortexWeapon )

		Vortex_CreateAbsorbFX_ControlPoints( vortexWeapon )

		// world (3P) version of the vortex sphere FX
		vortexSphere.s.worldFX <- CreateEntity( "info_particle_system" )

		if ( hasBurnMod )
		{
			if ( "fxChargingControlPointBurn" in vortexWeapon.s )
				vortexSphere.s.worldFX.SetValueForEffectNameKey( expect asset( vortexWeapon.s.fxChargingControlPointBurn ) )
		}
		else
		{
			if ( "fxChargingControlPoint" in vortexWeapon.s )
				vortexSphere.s.worldFX.SetValueForEffectNameKey( expect asset( vortexWeapon.s.fxChargingControlPoint ) )
		}

		vortexSphere.s.worldFX.kv.start_active = 1
		vortexSphere.s.worldFX.SetOwner( weaponOwner )
		vortexSphere.s.worldFX.SetParent( vortexWeapon, tagname )
		vortexSphere.s.worldFX.kv.VisibilityFlags = (ENTITY_VISIBLE_TO_FRIENDLY | ENTITY_VISIBLE_TO_ENEMY) // not owner only
		vortexSphere.s.worldFX.kv.cpoint1 = vortexWeapon.s.vortexSphereColorCP.GetTargetName()
		vortexSphere.s.worldFX.SetStopType( "destroyImmediately" )

		DispatchSpawn( vortexSphere.s.worldFX )
	#endif

	SetVortexAmmo( vortexWeapon, 0 )

	#if CLIENT
		if ( IsLocalViewPlayer( weaponOwner ) )
	{
		local fxAlias = null

		if ( hasBurnMod )
		{
			if ( "fxChargingFPControlPointBurn" in vortexWeapon.s )
				fxAlias = vortexWeapon.s.fxChargingFPControlPointBurn
		}
		else
		{
			if ( "fxChargingFPControlPoint" in vortexWeapon.s )
				fxAlias = vortexWeapon.s.fxChargingFPControlPoint
		}

		if ( fxAlias )
		{
			int sphereClientFXHandle = vortexWeapon.PlayWeaponEffectReturnViewEffectHandle( fxAlias, $"", tagname )
			// modified: use a setting for handling function
			//thread VortexSphereColorUpdate( vortexWeapon, sphereClientFXHandle )
			thread GetWeaponVortexColorUpdateFunc( vortexWeapon )( vortexWeapon, sphereClientFXHandle )
		}
	}
	#elseif  SERVER
		asset fxAlias = $""

		if ( hasBurnMod )
		{
			if ( "fxChargingFPControlPointReplayBurn" in vortexWeapon.s )
				fxAlias = expect asset( vortexWeapon.s.fxChargingFPControlPointReplayBurn )
		}
		else
		{
			if ( "fxChargingFPControlPointReplay" in vortexWeapon.s )
				fxAlias = expect asset( vortexWeapon.s.fxChargingFPControlPointReplay )
		}

		if ( fxAlias != $"" )
			vortexWeapon.PlayWeaponEffect( fxAlias, $"", tagname )

		// modified: use a setting for handling function
		//thread VortexSphereColorUpdate( vortexWeapon )
		thread GetWeaponVortexColorUpdateFunc( vortexWeapon )( vortexWeapon )
	#endif
}


function DestroyVortexSphereFromVortexWeapon( entity vortexWeapon )
{
	DisableVortexSphereFromVortexWeapon( vortexWeapon )

	#if SERVER
		DestroyVortexSphere( vortexWeapon.GetWeaponUtilityEntity() )
		vortexWeapon.SetWeaponUtilityEntity( null )
	#endif
}

void function DestroyVortexSphere( entity vortexSphere )
{
	if ( IsValid( vortexSphere ) )
	{
		vortexSphere.s.worldFX.Destroy()
		vortexSphere.Destroy()
	}
}


function DisableVortexSphereFromVortexWeapon( entity vortexWeapon )
{
	vortexWeapon.Signal( "VortexStopping" )

	// server cleanup
	#if SERVER
		DisableVortexSphere( vortexWeapon.GetWeaponUtilityEntity() )
		Vortex_CleanupAllEffects( vortexWeapon )
		Vortex_ClearImpactEventData( vortexWeapon )
	#endif

	// client & server cleanup

	if ( vortexWeapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod ) )
	{
		if ( "fxChargingFPControlPointBurn" in vortexWeapon.s )
			vortexWeapon.StopWeaponEffect( expect asset( vortexWeapon.s.fxChargingFPControlPointBurn ), $"" )
		if ( "fxChargingFPControlPointReplayBurn" in vortexWeapon.s )
			vortexWeapon.StopWeaponEffect( expect asset( vortexWeapon.s.fxChargingFPControlPointReplayBurn ), $"" )
	}
	else
	{
		if ( "fxChargingFPControlPoint" in vortexWeapon.s )
			vortexWeapon.StopWeaponEffect( expect asset( vortexWeapon.s.fxChargingFPControlPoint ), $"" )
		if ( "fxChargingFPControlPointReplay" in vortexWeapon.s )
			vortexWeapon.StopWeaponEffect( expect asset( vortexWeapon.s.fxChargingFPControlPointReplay ), $"" )
	}
}

void function DisableVortexSphere( entity vortexSphere )
{
	if ( IsValid( vortexSphere ) )
	{
		vortexSphere.FireNow( "Disable" )
		vortexSphere.Signal( SIGNAL_ID_BULLET_HIT_THINK )
	}

}


#if SERVER
function Vortex_CreateAbsorbFX_ControlPoints( entity vortexWeapon )
{
	entity player = vortexWeapon.GetWeaponOwner()
	Assert( player )

	// vortex swirling incoming rounds FX location control point
	if ( !( "vortexBulletEffectCP" in vortexWeapon.s ) )
		vortexWeapon.s.vortexBulletEffectCP <- null
	vortexWeapon.s.vortexBulletEffectCP = CreateEntity( "info_placement_helper" )
	SetTargetName( expect entity( vortexWeapon.s.vortexBulletEffectCP ), UniqueString( "vortexBulletEffectCP" ) )
	vortexWeapon.s.vortexBulletEffectCP.kv.start_active = 1

	DispatchSpawn( vortexWeapon.s.vortexBulletEffectCP )

	vector offset = GetBulletCollectionOffset( vortexWeapon )
	vector origin = player.OffsetPositionFromView( player.EyePosition(), offset )

	vortexWeapon.s.vortexBulletEffectCP.SetOrigin( origin )
	vortexWeapon.s.vortexBulletEffectCP.SetParent( player )

	// vortex sphere color control point
	if ( !( "vortexSphereColorCP" in vortexWeapon.s ) )
		vortexWeapon.s.vortexSphereColorCP <- null
	vortexWeapon.s.vortexSphereColorCP = CreateEntity( "info_placement_helper" )
	SetTargetName( expect entity( vortexWeapon.s.vortexSphereColorCP ), UniqueString( "vortexSphereColorCP" ) )
	vortexWeapon.s.vortexSphereColorCP.kv.start_active = 1

	DispatchSpawn( vortexWeapon.s.vortexSphereColorCP )
}


function Vortex_CleanupAllEffects( entity vortexWeapon )
{
	Assert( IsServer() )

	Vortex_CleanupImpactAbsorbFX( vortexWeapon )

	if ( ( "vortexBulletEffectCP" in vortexWeapon.s ) && IsValid_ThisFrame( expect entity( vortexWeapon.s.vortexBulletEffectCP ) ) )
		vortexWeapon.s.vortexBulletEffectCP.Destroy()

	if ( ( "vortexSphereColorCP" in vortexWeapon.s ) && IsValid_ThisFrame( expect entity( vortexWeapon.s.vortexSphereColorCP ) ) )
		vortexWeapon.s.vortexSphereColorCP.Destroy()
}
#endif // SERVER


function SetPlayerUsingVortex( entity weaponOwner, entity vortexWeapon )
{
	weaponOwner.EndSignal( "OnDeath" )

	weaponOwner.s.isVortexing <- true

	vortexWeapon.WaitSignal( "VortexStopping" )

	OnThreadEnd
	(
		function() : ( weaponOwner )
		{
			if ( IsValid_ThisFrame( weaponOwner ) && "isVortexing" in weaponOwner.s )
			{
				delete weaponOwner.s.isVortexing
			}
		}
	)
}


function IsVortexing( entity ent )
{
	Assert( IsServer() )

	if ( "isVortexing" in ent.s )
		return true
}


#if SERVER
function Vortex_HandleElectricDamage( entity ent, entity attacker, damage, entity weapon )
{
	if ( !IsValid( ent ) )
		return damage

	if ( !ent.IsTitan() )
		return damage

	if ( !ent.IsPlayer() && !ent.IsNPC() )
		return damage

	if ( !IsVortexing( ent ) )
		return damage

	entity vortexWeapon = ent.GetActiveWeapon()
	if ( !IsValid( vortexWeapon ) )
		return damage

	entity vortexSphere = vortexWeapon.GetWeaponUtilityEntity()
	if ( !IsValid( vortexSphere ) )
		return damage

	if ( !IsValid( vortexWeapon ) || !IsValid( vortexSphere ) )
		return damage

	// vortex FOV check
	//printt( "sphere FOV:", vortexSphere.kv.bullet_fov )
	local sphereFOV = vortexSphere.kv.bullet_fov.tointeger()
	entity attackerWeapon = attacker.GetActiveWeapon()
	int attachIdx = attackerWeapon.LookupAttachment( "muzzle_flash" )
	vector beamOrg = attackerWeapon.GetAttachmentOrigin( attachIdx )
	vector firingDir = beamOrg - vortexSphere.GetOrigin()
	firingDir = Normalize( firingDir )
	vector vortexDir = AnglesToForward( vortexSphere.GetAngles() )

	float dot = DotProduct( vortexDir, firingDir )

	float degCos = DEG_COS_60
	if ( sphereFOV != 120 )
		deg_cos( sphereFOV * 0.5 )

	// not in the vortex cone
	if ( dot < degCos )
		return damage

	if ( "fxElectricalExplosion" in vortexWeapon.s )
	{
			entity fxRef = CreateEntity( "info_particle_system" )
			fxRef.SetValueForEffectNameKey( expect asset( vortexWeapon.s.fxElectricalExplosion ) )
			fxRef.kv.start_active = 1
			fxRef.SetStopType( "destroyImmediately" )
			//fxRef.kv.VisibilityFlags = ENTITY_VISIBLE_TO_OWNER  // HACK this turns on owner only visibility. Uncomment when we hook up dedicated 3P effects
			fxRef.SetOwner( ent )
			fxRef.SetOrigin( vortexSphere.GetOrigin() )
			fxRef.SetParent( ent )

			DispatchSpawn( fxRef )
			fxRef.Kill_Deprecated_UseDestroyInstead( 1 )
	}

	return 0
}

// this function handles all incoming vortex impact events
// nessie: should add a function AddCallback_ModdedVortexAbsorb() to handle modded projectiles
// AddCallback_ModdedVortexAbsorb( string weaponName, string modName, string absorbBehavior )
bool function TryVortexAbsorb( entity vortexSphere, entity attacker, vector origin, int damageSourceID, entity weapon, string weaponName, string impactType, entity projectile = null, damageType = null, reflect = false )
{
	if ( weaponName in VortexIgnoreClassnames && VortexIgnoreClassnames[weaponName] )
		return false

	// modded utility
	entity weaponOrProjectile = impactType == "hitscan" ? weapon : projectile
	// weapon mods check
	if ( IsValid( weaponOrProjectile ) )
	{
		array<string> mods = weaponOrProjectile.IsProjectile() ? Vortex_GetRefiredProjectileMods( weaponOrProjectile ) : weaponOrProjectile.GetMods()
		foreach ( string mod in mods )
		{
			if ( mod in VortexIgnoreWeaponMods && VortexIgnoreWeaponMods[ mod ] )
				return false
		}
	}
	//

	entity vortexWeapon = vortexSphere.GetOwnerWeapon()
	entity owner = vortexWeapon.GetWeaponOwner()

	// keep cycling the oldest hitscan bullets out
	// modified here: we've reworked amped refire, they also needs clamp now
	// welp this will cause crash, guess I'll just stop adding bullets/projectiles into sphere to avoid issue
	if( !reflect )
	{
		if ( impactType == "hitscan" )
			Vortex_ClampAbsorbedBulletCount( vortexWeapon )
		else if ( impactType == "projectile" ) // changed to use else if() case
			Vortex_ClampAbsorbedProjectileCount( vortexWeapon )
	}

	// vortex spheres tag refired projectiles with info about the original projectile for accurate duplication when re-absorbed
	if ( projectile )
	{

		// specifically for tether, since it gets moved to the vortex area and can get absorbed in the process, then destroyed
		if ( !IsValid( projectile ) )
			return false

		entity projOwner = projectile.GetOwner()
		if ( IsValid( projOwner ) && projOwner.GetTeam() == owner.GetTeam() )
			return false

		if ( projectile.proj.hasBouncedOffVortex )
			return false

		if ( projectile.ProjectileGetWeaponInfoFileKeyField( "projectile_ignores_vortex" ) == "fall_vortex" )
		{
			vector velocity = projectile.GetVelocity()
			vector multiplier = < -0.25, -0.25, -0.25 >
			velocity = < velocity.x * multiplier.x, velocity.y * multiplier.y, velocity.z * multiplier.z >
			projectile.SetVelocity( velocity )
			projectile.proj.hasBouncedOffVortex = true
			return false
		}

		// if ( projectile.GetParent() == owner )
		// 	return false

		if ( "originalDamageSource" in projectile.s )
		{
			damageSourceID = expect int( projectile.s.originalDamageSource )

			// Vortex Volley Achievement
			if ( IsValid( owner ) && owner.IsPlayer() )
			{
				//if ( PlayerProgressionAllowed( owner ) )
				//	SetAchievement( owner, "ach_vortexVolley", true )
			}
		}

		// Max projectile stat tracking
		int projectilesInVortex = 1
		//projectilesInVortex += vortexWeapon.w.vortexImpactData.len()
		projectilesInVortex += expect int( Vortex_GetAllImpactEvents( vortexWeapon ).len() )

		if ( IsValid( owner ) && owner.IsPlayer() )
		{
		 	if ( PlayerProgressionAllowed( owner ) )
		 	{
				int record = owner.GetPersistentVarAsInt( "mostProjectilesCollectedInVortex" )
				if ( projectilesInVortex > record )
					owner.SetPersistentVar( "mostProjectilesCollectedInVortex", projectilesInVortex )
		 	}

			var impact_sound_1p = projectile.ProjectileGetWeaponInfoFileKeyField( "vortex_impact_sound_1p" )
			if ( impact_sound_1p != null )
				EmitSoundOnEntityOnlyToPlayer( vortexSphere, owner, impact_sound_1p )
		}

		var impact_sound_3p = projectile.ProjectileGetWeaponInfoFileKeyField( "vortex_impact_sound_3p" )
		if ( impact_sound_3p != null )
			EmitSoundAtPosition( TEAM_UNASSIGNED, origin, impact_sound_3p )
	}
	else
	{
		if ( IsValid( owner ) && owner.IsPlayer() )
		{
			var impact_sound_1p = GetWeaponInfoFileKeyField_Global( weaponName, "vortex_impact_sound_1p" )
			if ( impact_sound_1p != null )
				EmitSoundOnEntityOnlyToPlayer( vortexSphere, owner, impact_sound_1p )
		}

		var impact_sound_3p = GetWeaponInfoFileKeyField_Global( weaponName, "vortex_impact_sound_3p" )
		if ( impact_sound_3p != null )
			EmitSoundAtPosition( TEAM_UNASSIGNED, origin, impact_sound_3p )
	}

	// modified to add callback compatible
	//local impactData = Vortex_CreateImpactEventData( vortexWeapon, attacker, origin, damageSourceID, weaponName, impactType )
	local impactData = Vortex_CreateImpactEventData( vortexWeapon, attacker, origin, damageSourceID, weaponName, impactType, weaponOrProjectile )

	VortexDrainedByImpact( vortexWeapon, weapon, projectile, damageType )
	Vortex_NotifyAttackerDidDamage( expect entity( impactData.attacker ), owner, impactData.origin )

	if ( impactData.refireBehavior == VORTEX_REFIRE_ABSORB )
		return true

	// this is hardcoded for no reason
	if ( vortexWeapon.GetWeaponClassName() == "mp_titanweapon_heat_shield" )
		return true

	if ( !Vortex_ScriptCanHandleImpactEvent( impactData ) )
		return false

	Vortex_StoreImpactEvent( vortexWeapon, impactData )

	// modified here: if we're gonna reflect the impact immediately, shouldn't do absorbed FX
	// only needs to ping shield once
	if ( !reflect )
		VortexImpact_PlayAbsorbedFX( vortexWeapon, impactData )
	else
		Vortex_SpawnShieldPingFX( vortexWeapon, impactData )

	// modified here: just stop adding bullets/projectiles into sphere if we wanted to reflect
	if ( !reflect )
	{
		if ( impactType == "hitscan" )
			vortexSphere.AddBulletToSphere();
		else if ( impactType == "projectile" ) // changed to use else if() case
			vortexSphere.AddProjectileToSphere();
	}
	else // amped refire needs modified logic... they won't use client-side prediction so feel free to use serverside-only variables
	{
		if ( impactType == "hitscan" )
			AddVortexWeaponAmpedBulletCount( vortexWeapon )
		else if ( impactType == "projectile" ) // changed to use else if() case
			AddVortexWeaponAmpedProjectileCount( vortexWeapon )
	}

	// nessie note: I don't think this works best for shotgun bullets...
	// legion's power shot won't be handled, amped vortex refire also ignore this
	// looks pretty silly. though it breaks vanilla behavior, I'd like to remove it
	/*
	local maxShotgunPelletsToIgnore = VORTEX_BULLET_ABSORB_COUNT_MAX * ( 1 - VORTEX_SHOTGUN_DAMAGE_RATIO )
	if ( IsPilotShotgunWeapon( weaponName ) && ( vortexWeapon.s.shotgunPelletsToIgnore + 1 ) <  maxShotgunPelletsToIgnore )
		vortexWeapon.s.shotgunPelletsToIgnore += ( 1 - VORTEX_SHOTGUN_DAMAGE_RATIO )
	*/

	if ( reflect )
	{
		// this seem to work bad in TTF2
		// we do need to wait for next frame before firing them back... to prevent some infinite reflecting happens
		// the error indicates by SCRIPT ERROR Failed to Create Entity "info_particle_system", the failure is because we've created so much entities due to infinite refire
		// maybe also need to rework AmpedVortexRefireThink()? it fire back with script fps limit( triggers after WaitSignal() )
		
		// reworked here: delay 1 frame before refiring
		/*
		local attackParams = {}
		attackParams.pos <- owner.EyePosition()
		attackParams.dir <- owner.GetPlayerOrNPCViewVector()

		int bulletsFired = VortexReflectAttack( vortexWeapon, attackParams, expect vector( impactData.origin ) )

		Vortex_CleanupImpactAbsorbFX( vortexWeapon )
		Vortex_ClearImpactEventData( vortexWeapon )

		while ( vortexSphere.GetBulletAbsorbedCount() > 0 )
			vortexSphere.RemoveBulletFromSphere();

		while ( vortexSphere.GetProjectileAbsorbedCount() > 0 )
			vortexSphere.RemoveProjectileFromSphere();
		*/

		// fixing instal vortex refire for tf2
		// delay 1 frame to fire back if we're not collecting more bullets/projectiles
		thread DelayedVortexFireBack( owner, vortexWeapon, impactData, impactType, vortexSphere )
	}

	return true
}

void function DelayedVortexFireBack( entity owner, entity vortexWeapon, impactData, string impactType, entity vortexSphere = null )
{
	//print( "RUNNING DelayedVortexFireBack()" )
	owner.EndSignal( "OnDestroy" )
	owner.EndSignal( "OnDeath" )
	vortexWeapon.EndSignal( "OnDestroy" )
	// now we don't stack refire, just fire back each impact data individually
	//vortexWeapon.Signal( "DelayedVortexFireBack" )
	//vortexWeapon.EndSignal( "DelayedVortexFireBack" ) // stack refire if we taking fire within 1 frame
	// can still fire back after vortexSphere being destroyed, only needs weapon's data

	// mp_titanweapon_vortex_shield.gnut has been modified
	// it now fires back remaining impact data even when having burn mod
	// so after firing by that, this function should be ended
	vortexWeapon.EndSignal( "VortexFired" )

	// clean up
	OnThreadEnd
	(
		function(): ( vortexWeapon )
		{
			if ( IsValid( vortexWeapon ) )
			{
				// these clean-ups now handled by VortexPrimaryAttack()
				//Vortex_CleanupImpactAbsorbFX( vortexWeapon )
				//Vortex_ClearImpactEventData( vortexWeapon )
			}
		}
	)

	WaitFrame()
	// we may clamp out current impactData, needs re-exam after delay
	// removed: no longer needs clamp
	//if ( !Vortex_GetAllImpactEvents( vortexWeapon ).contains( impactData ) )
	//	return

	WeaponPrimaryAttackParams attackParams
	attackParams.pos = owner.EyePosition()
	attackParams.dir = owner.GetPlayerOrNPCViewVector()

	VortexReflectAttack( vortexWeapon, attackParams, impactData, impactType )

	// clean up after firing
	Vortex_RemoveImpactEvent( vortexWeapon, impactData )

	// we've stopped adding bullet/projectiles to sphere when reflecting, no need to do this
	/*
	if ( IsValid( vortexSphere ) )
	{
		if ( impactType == "hitscan" )
			vortexSphere.RemoveBulletFromSphere()
		else if ( impactType == "projectile" ) // changed to use else if() case
			vortexSphere.RemoveProjectileFromSphere()
	}
	*/

	// amped refire needs modified logic... they won't use client-side prediction so feel free to use serverside-only variables
	if ( impactType == "hitscan" )
		RemoveVortexWeaponAmpedBulletCount( vortexWeapon )
	else if ( impactType == "projectile" ) // changed to use else if() case
		RemoveVortexWeaponAmpedProjectileCount( vortexWeapon )
	
}
#endif // SERVER

// changed damageType parameter to be var type so we can better handle callbacks
//function VortexDrainedByImpact( entity vortexWeapon, entity weapon, entity projectile, damageType )
function VortexDrainedByImpact( entity vortexWeapon, entity weapon, entity projectile, var damageType )
{
	if ( vortexWeapon.HasMod( "unlimited_charge_time" ) )
		return
	if ( vortexWeapon.HasMod( "vortex_extended_effect_and_no_use_penalty" ) )
		return

	float amount
	if ( projectile )
	{
		amount = projectile.GetProjectileWeaponSettingFloat( eWeaponVar.vortex_drain )
	}
	else
	{
		amount = weapon.GetWeaponSettingFloat( eWeaponVar.vortex_drain )
	}

	// run modified callbacks here
	// update amount on each call
	foreach ( callbackFunc in file.vortexDrainByImpactCallbacks )
		amount = callbackFunc( vortexWeapon, weapon, projectile, damageType, amount )
	//

	if ( amount <= 0.0 )
		return

	if ( vortexWeapon.GetWeaponClassName() == "mp_titanweapon_vortex_shield_ion" )
	{
		entity owner = vortexWeapon.GetWeaponOwner()
		int totalEnergy = owner.GetSharedEnergyTotal()
		owner.TakeSharedEnergy( int( float( totalEnergy ) * amount ) )
	}
	else
	{
		float frac = min ( vortexWeapon.GetWeaponChargeFraction() + amount, 1.0 )
		vortexWeapon.SetWeaponChargeFraction( frac )
	}
}

function VortexSlowOwnerFromAttacker( entity player, entity attacker, vector velocity, float multiplier )
{
	vector damageForward = player.GetOrigin() - attacker.GetOrigin()
	damageForward.z = 0
	damageForward.Norm()

	vector velForward = player.GetVelocity()
	velForward.z = 0
	velForward.Norm()

	float dot = DotProduct( velForward, damageForward )
	if ( dot >= -0.5 )
		return

	dot += 0.5
	dot *= -2.0

	vector negateVelocity = velocity * -multiplier
	negateVelocity *= dot

	velocity += negateVelocity
	player.SetVelocity( velocity )
}


#if SERVER
function Vortex_ClampAbsorbedBulletCount( entity vortexWeapon )
{
	if ( GetBulletsAbsorbedCount( vortexWeapon ) >= ( VORTEX_BULLET_ABSORB_COUNT_MAX - 1 ) )
		Vortex_RemoveOldestAbsorbedBullet( vortexWeapon )
}

function Vortex_ClampAbsorbedProjectileCount( entity vortexWeapon )
{
	if ( GetProjectilesAbsorbedCount( vortexWeapon ) >= ( VORTEX_PROJECTILE_ABSORB_COUNT_MAX - 1 ) )
		Vortex_RemoveOldestAbsorbedProjectile( vortexWeapon )
}

function Vortex_RemoveOldestAbsorbedBullet( entity vortexWeapon )
{
	entity vortexSphere = vortexWeapon.GetWeaponUtilityEntity()

	local bulletImpacts = Vortex_GetHitscanBulletImpacts( vortexWeapon )
	local impactDataToRemove = bulletImpacts[ 0 ]  // since it's an array, the first one will be the oldest

	Vortex_RemoveImpactEvent( vortexWeapon, impactDataToRemove )

	vortexSphere.RemoveBulletFromSphere()
}

function Vortex_RemoveOldestAbsorbedProjectile( entity vortexWeapon )
{
	entity vortexSphere = vortexWeapon.GetWeaponUtilityEntity()

	local projImpacts = Vortex_GetProjectileImpacts( vortexWeapon )
	local impactDataToRemove = projImpacts[ 0 ]  // since it's an array, the first one will be the oldest

	Vortex_RemoveImpactEvent( vortexWeapon, impactDataToRemove )

	vortexSphere.RemoveProjectileFromSphere()
}

// nessie: should add some mod callbacks to change certain mod weapon's vortex behavior...
//function Vortex_CreateImpactEventData( entity vortexWeapon, entity attacker, vector origin, int damageSourceID, string weaponName, string impactType )
function Vortex_CreateImpactEventData( entity vortexWeapon, entity attacker, vector origin, int damageSourceID, string weaponName, string impactType, entity weaponOrProjectile = null )
{
	entity player = vortexWeapon.GetWeaponOwner()
	local impactData = {}

	impactData.attacker				<- attacker
	impactData.origin				<- origin
	impactData.damageSourceID		<- damageSourceID
	impactData.weaponName			<- weaponName
	impactData.impactType			<- impactType

	impactData.refireBehavior		<- VORTEX_REFIRE_NONE
	impactData.absorbSFX			<- "Vortex_Shield_AbsorbBulletSmall"
	impactData.absorbSFX_1p_vs_3p	<- null

	impactData.team 				<- null
	// sets a team even if the attacker disconnected
	if ( IsValid_ThisFrame( attacker ) )
	{
		impactData.team = attacker.GetTeam()
	}
	else
	{
		// default to opposite team
		if ( player.GetTeam() == TEAM_IMC )
			impactData.team = TEAM_MILITIA
		else
			impactData.team = TEAM_IMC
	}

	impactData.absorbFX				<- null
	impactData.absorbFX_3p			<- null
	impactData.fxEnt_absorb			<- null

	impactData.explosionradius		<- null
	impactData.explosion_damage		<- null
	impactData.impact_effect_table	<- -1

	// rework respawn's bad think in Vortex_FireBackGrenade()
	// store in data so we can modify them with weapon mods
	impactData.grenade_ignition_time <- null
	impactData.grenade_fuse_time <- null

	// -- everything from here down relies on being able to read a megaweapon file
	if ( !( impactData.weaponName in vortexImpactWeaponInfo ) )
	{
		vortexImpactWeaponInfo[ impactData.weaponName ] <- {}
		vortexImpactWeaponInfo[ impactData.weaponName ].absorbFX 						<- GetWeaponInfoFileKeyFieldAsset_Global( impactData.weaponName, "vortex_absorb_effect" )
		vortexImpactWeaponInfo[ impactData.weaponName ].absorbFX_3p 					<- GetWeaponInfoFileKeyFieldAsset_Global( impactData.weaponName, "vortex_absorb_effect_third_person" )
		vortexImpactWeaponInfo[ impactData.weaponName ].refireBehavior 					<- GetWeaponInfoFileKeyField_Global( impactData.weaponName, "vortex_refire_behavior" )
		vortexImpactWeaponInfo[ impactData.weaponName ].absorbSound 					<- GetWeaponInfoFileKeyField_Global( impactData.weaponName, "vortex_absorb_sound" )
		vortexImpactWeaponInfo[ impactData.weaponName ].absorbSound_1p_vs_3p			<- GetWeaponInfoFileKeyField_Global( impactData.weaponName, "vortex_absorb_sound_1p_vs_3p" )
		vortexImpactWeaponInfo[ impactData.weaponName ].explosionradius 				<- GetWeaponInfoFileKeyField_Global( impactData.weaponName, "explosionradius" )
		vortexImpactWeaponInfo[ impactData.weaponName ].explosion_damage_heavy_armor	<- GetWeaponInfoFileKeyField_Global( impactData.weaponName, "explosion_damage_heavy_armor" )
		vortexImpactWeaponInfo[ impactData.weaponName ].explosion_damage				<- GetWeaponInfoFileKeyField_Global( impactData.weaponName, "explosion_damage" )
		vortexImpactWeaponInfo[ impactData.weaponName ].impact_effect_table				<- GetWeaponInfoFileKeyField_Global( impactData.weaponName, "impact_effect_table" )
		vortexImpactWeaponInfo[ impactData.weaponName ].grenade_ignition_time			<- GetWeaponInfoFileKeyField_Global( impactData.weaponName, "grenade_ignition_time" )
		vortexImpactWeaponInfo[ impactData.weaponName ].grenade_fuse_time				<- GetWeaponInfoFileKeyField_Global( impactData.weaponName, "grenade_fuse_time" )
	}

	impactData.absorbFX				= vortexImpactWeaponInfo[ impactData.weaponName ].absorbFX
	impactData.absorbFX_3p			= vortexImpactWeaponInfo[ impactData.weaponName ].absorbFX_3p
	if ( impactData.absorbFX )
		Assert( impactData.absorbFX_3p, "Missing 3rd person absorb effect for " + impactData.weaponName )
	impactData.refireBehavior		= vortexImpactWeaponInfo[ impactData.weaponName ].refireBehavior

	local absorbSound = vortexImpactWeaponInfo[ impactData.weaponName ].absorbSound
	if ( absorbSound )
		impactData.absorbSFX = absorbSound

	local absorbSound_1p_vs_3p = vortexImpactWeaponInfo[ impactData.weaponName ].absorbSound_1p_vs_3p
	if ( absorbSound_1p_vs_3p )
		impactData.absorbSFX_1p_vs_3p = absorbSound_1p_vs_3p

	// info we need for refiring (some types of) impacts
	impactData.explosionradius		= vortexImpactWeaponInfo[ impactData.weaponName ].explosionradius
	impactData.explosion_damage		= vortexImpactWeaponInfo[ impactData.weaponName ].explosion_damage_heavy_armor
	if ( impactData.explosion_damage == null )
		impactData.explosion_damage		= vortexImpactWeaponInfo[ impactData.weaponName ].explosion_damage
	impactData.impact_effect_table	= vortexImpactWeaponInfo[ impactData.weaponName ].impact_effect_table

	// rework respawn's bad think in Vortex_FireBackGrenade()
	// here we store default value
	impactData.grenade_ignition_time <- vortexImpactWeaponInfo[ impactData.weaponName ].grenade_ignition_time
	impactData.grenade_fuse_time <- vortexImpactWeaponInfo[ impactData.weaponName ].grenade_fuse_time

	// modified
	if ( IsValid( weaponOrProjectile ) )
	{
		// behavior override
		//print( "Vortex_WeaponOrProjectileHasImpactDataOverride(): " + string( Vortex_WeaponOrProjectileHasImpactDataOverride( weaponOrProjectile ) ) )
		if ( Vortex_WeaponOrProjectileHasImpactDataOverride( weaponOrProjectile ) )
		{
			table overrideImpactData = Vortex_GetImpactDataOverrideFromWeaponOrProjectile( weaponOrProjectile )
			if ( overrideImpactData != {} )
			{
				if ( overrideImpactData.absorbFX != $"" )
					impactData.absorbFX = overrideImpactData.absorbFX
				if ( overrideImpactData.absorbFX_3p != $"" )
					impactData.absorbFX_3p = overrideImpactData.absorbFX_3p
				if ( overrideImpactData.refireBehavior!= "" )
					impactData.refireBehavior = overrideImpactData.refireBehavior
			}
		}

		// saving model, particle, and reset impact effect
		if ( weaponOrProjectile.IsProjectile() ) // projectile specific stuff!
		{
			impactData.projectileModel <- weaponOrProjectile.GetModelName()
			// get default trail effect, compare to current trail: if modified, do a extra trail effect
			asset defaultTrail = GetWeaponInfoFileKeyFieldAsset_Global( weaponName, "projectile_trail_effect_0" )
			asset modTrail = weaponOrProjectile.GetProjectileWeaponSettingAsset( eWeaponVar.projectile_trail_effect_0 )
			// debug
			//print( "defaultTrail: " + string( defaultTrail ) )
			//print( "modTrail: " + string( modTrail ) )
			if ( defaultTrail != modTrail )
			{
				// debug
				//print( "refired projectile trail has been modified!" )
				impactData.projectileTrail <- modTrail
			}
			// this may require tons of resources to display?
			//impactData.projectileTrail <- weaponOrProjectile.GetProjectileWeaponSettingAsset( eWeaponVar.projectile_trail_effect_0 )
			// convert asset to string
			string impactFXName = GetImpactTableNameFromWeaponOrProjectile( weaponOrProjectile ) // shared from _unpredicted_impact_fix.gnut
			impactData.impact_effect_table = impactFXName

			// rework these hardcoded stuffs to be mod
			impactData.grenade_ignition_time = weaponOrProjectile.GetProjectileWeaponSettingFloat( eWeaponVar.grenade_ignition_time )
			impactData.grenade_fuse_time = weaponOrProjectile.GetProjectileWeaponSettingFloat( eWeaponVar.grenade_fuse_time )
		}

		// saving mods
		array<string> mods = weaponOrProjectile.IsProjectile() ? Vortex_GetRefiredProjectileMods( weaponOrProjectile ) : weaponOrProjectile.GetMods()
		// build an var array
		array untypedArray
		foreach ( string mod in mods )
			untypedArray.append( mod )
		impactData.refiredProjectileMods <- untypedArray
	}

	return impactData
}

function Vortex_ScriptCanHandleImpactEvent( impactData )
{
	if ( impactData.refireBehavior == VORTEX_REFIRE_NONE )
		return false

	if ( !impactData.absorbFX )
		return false

	if ( impactData.impactType == "projectile" && !impactData.impact_effect_table )
		return false

	return true
}

function Vortex_StoreImpactEvent( entity vortexWeapon, impactData )
{
	vortexWeapon.w.vortexImpactData.append( impactData )
}

// safely removes data for a single impact event
function Vortex_RemoveImpactEvent( entity vortexWeapon, impactData )
{
	Vortex_ImpactData_KillAbsorbFX( impactData )

	vortexWeapon.w.vortexImpactData.fastremovebyvalue( impactData )
}

function Vortex_GetAllImpactEvents( entity vortexWeapon )
{
	return vortexWeapon.w.vortexImpactData
}

function Vortex_ClearImpactEventData( entity vortexWeapon )
{
	vortexWeapon.w.vortexImpactData = []
}

function VortexImpact_PlayAbsorbedFX( entity vortexWeapon, impactData )
{
	// generic shield ping FX
	Vortex_SpawnShieldPingFX( vortexWeapon, impactData )

	// specific absorb FX
	impactData.fxEnt_absorb = Vortex_SpawnImpactAbsorbFX( vortexWeapon, impactData )
}

// FX played when something first enters the vortex sphere
function Vortex_SpawnShieldPingFX( entity vortexWeapon, impactData )
{
	entity player = vortexWeapon.GetWeaponOwner()
	Assert( player )

	local absorbSFX = impactData.absorbSFX
	//printt( "SFX absorb sound:", absorbSFX )
	if ( vortexWeapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod ) )
		EmitSoundOnEntity( vortexWeapon, "Vortex_Shield_Deflect_Amped" )
	else
	{
		EmitSoundOnEntity( vortexWeapon, absorbSFX )
		if ( impactData.absorbSFX_1p_vs_3p != null )
		{
			if ( IsValid( impactData.attacker ) && impactData.attacker.IsPlayer() )
			{
				EmitSoundOnEntityOnlyToPlayer( vortexWeapon, impactData.attacker, impactData.absorbSFX_1p_vs_3p )
			}
		}
	}

	entity pingFX = CreateEntity( "info_particle_system" )

	if ( vortexWeapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod ) )
	{
		if ( "fxBulletHitBurn" in vortexWeapon.s )
			pingFX.SetValueForEffectNameKey( expect asset( vortexWeapon.s.fxBulletHitBurn ) )
	}
	else
	{
		if ( "fxBulletHit" in vortexWeapon.s )
			pingFX.SetValueForEffectNameKey( expect asset( vortexWeapon.s.fxBulletHit ) )
	}

	pingFX.kv.start_active = 1

	DispatchSpawn( pingFX )

	pingFX.SetOrigin( impactData.origin )
	pingFX.SetParent( player )
	pingFX.Kill_Deprecated_UseDestroyInstead( 0.25 )
}

function Vortex_SpawnHeatShieldPingFX( entity vortexWeapon, impactData, bool impactTypeIsBullet )
{
	entity player = vortexWeapon.GetWeaponOwner()
	Assert( player )

	if ( impactTypeIsBullet )
		EmitSoundOnEntity( vortexWeapon, "heat_shield_stop_bullet" )
	else
		EmitSoundOnEntity( vortexWeapon, "heat_shield_stop_projectile" )

	entity pingFX = CreateEntity( "info_particle_system" )

	if ( "fxBulletHit" in vortexWeapon.s )
		pingFX.SetValueForEffectNameKey( expect asset( vortexWeapon.s.fxBulletHit ) )

	pingFX.kv.start_active = 1

	DispatchSpawn( pingFX )

	pingFX.SetOrigin( impactData.origin )
	pingFX.SetParent( player )
	pingFX.Kill_Deprecated_UseDestroyInstead( 0.25 )
}

function Vortex_SpawnImpactAbsorbFX( entity vortexWeapon, impactData )
{
	// in case we're in the middle of cleaning the weapon up
	if ( !IsValid( vortexWeapon.s.vortexBulletEffectCP ) )
		return

	entity owner = vortexWeapon.GetWeaponOwner()
	Assert( owner )

	local fxRefs = []

	// owner
	{
		entity fxRef = CreateEntity( "info_particle_system" )

		fxRef.SetValueForEffectNameKey( expect asset( impactData.absorbFX ) )
		fxRef.kv.start_active = 1
		fxRef.SetStopType( "destroyImmediately" )
		fxRef.kv.VisibilityFlags = ENTITY_VISIBLE_TO_OWNER
		fxRef.kv.cpoint1 = vortexWeapon.s.vortexBulletEffectCP.GetTargetName()

		DispatchSpawn( fxRef )

		fxRef.SetOwner( owner )
		fxRef.SetOrigin( impactData.origin )
		fxRef.SetParent( owner )

		fxRefs.append( fxRef )
	}

	// everyone else
	{
		entity fxRef = CreateEntity( "info_particle_system" )

		fxRef.SetValueForEffectNameKey( expect asset( impactData.absorbFX_3p ) )
		fxRef.kv.start_active = 1
		fxRef.SetStopType( "destroyImmediately" )
		fxRef.kv.VisibilityFlags = (ENTITY_VISIBLE_TO_FRIENDLY | ENTITY_VISIBLE_TO_ENEMY)  // other only visibility
		fxRef.kv.cpoint1 = vortexWeapon.s.vortexBulletEffectCP.GetTargetName()

		DispatchSpawn( fxRef )

		fxRef.SetOwner( owner )
		fxRef.SetOrigin( impactData.origin )
		fxRef.SetParent( owner )

		fxRefs.append( fxRef )
	}

	return fxRefs
}

function Vortex_CleanupImpactAbsorbFX( entity vortexWeapon )
{
	foreach ( impactData in Vortex_GetAllImpactEvents( vortexWeapon ) )
	{
		Vortex_ImpactData_KillAbsorbFX( impactData )
	}
}

function Vortex_ImpactData_KillAbsorbFX( impactData )
{
	// modified: we now allow null absorb effect for amped vortex
	// add validation check
	if ( impactData.fxEnt_absorb == null )
		return
	foreach ( fxRef in impactData.fxEnt_absorb )
	{
		if ( !IsValid( fxRef ) )
			continue

		fxRef.Fire( "DestroyImmediately" )
		fxRef.Kill_Deprecated_UseDestroyInstead()
	}
}

bool function PlayerDiedOrDisconnected( entity player )
{
	if ( !IsValid( player ) )
		return true

	if ( !IsAlive( player ) )
		return true

	if ( IsDisconnected( player ) )
		return true

	return false
}

#endif // SERVER

int function VortexPrimaryAttack( entity vortexWeapon, WeaponPrimaryAttackParams attackParams )
{
	entity vortexSphere = vortexWeapon.GetWeaponUtilityEntity()
	if ( !vortexSphere )
		return 0

	#if SERVER
		Assert( vortexSphere )
	#endif

	int totalfired = 0
	int totalAttempts = 0

	bool forceReleased = false
	// in this case, it's also considered "force released" if the charge time runs out
	if ( vortexWeapon.IsForceRelease() || vortexWeapon.GetWeaponChargeFraction() == 1 )
		forceReleased = true

	// PREDICTED REFIRES
	// bullet impact events don't individually fire back per event because we aggregate and then shotgun blast them
	int bulletsFired = Vortex_FireBackBullets( vortexWeapon, attackParams )
	totalfired += bulletsFired

	// UNPREDICTED REFIRES
	#if SERVER
		//printt( "server: force released?", forceReleased )

		local unpredictedRefires = Vortex_GetProjectileImpacts( vortexWeapon )

		// HACK we don't actually want to refire them with a spiral but
		//   this is to temporarily ensure compatibility with the Titan rocket launcher
		if ( !( "spiralMissileIdx" in vortexWeapon.s ) )
			vortexWeapon.s.spiralMissileIdx <- null
		vortexWeapon.s.spiralMissileIdx = 0

		foreach ( impactData in unpredictedRefires )
		{
			// rework all attackParams to be typed...
			//table fakeAttackParams = {pos = attackParams.pos, dir = attackParams.dir, firstTimePredicted = attackParams.firstTimePredicted, burstIndex = attackParams.burstIndex}
			//bool didFire = DoVortexAttackForImpactData( vortexWeapon, fakeAttackParams, impactData, totalAttempts )
			bool didFire = DoVortexAttackForImpactData( vortexWeapon, attackParams, impactData, totalAttempts )
			if ( didFire )
				totalfired++
			totalAttempts++
		}
		//printt( "totalfired", totalfired )
	#else
		totalfired += GetProjectilesAbsorbedCount( vortexWeapon )
	#endif

	SetVortexAmmo( vortexWeapon, 0 )

	vortexWeapon.Signal( "VortexFired" )

	if ( forceReleased )
		DestroyVortexSphereFromVortexWeapon( vortexWeapon )
	else
		DisableVortexSphereFromVortexWeapon( vortexWeapon )

	return totalfired
}

int function Vortex_FireBackBullets( entity vortexWeapon, WeaponPrimaryAttackParams attackParams )
{
	int bulletCount = GetBulletsAbsorbedCount( vortexWeapon )
	// server modification here: always use amped bullet count if it's not 0
	#if SERVER
		// edit: no need to do such think, we fire back each bullet and projectile individually
		/*
		if ( GetAmpedBulletsAbsorbedCount( vortexWeapon ) > 0 )
			bulletCount = GetAmpedBulletsAbsorbedCount( vortexWeapon )
		*/
	#endif

	// nessie note: I don't think this works best for shotgun bullets...
	// legion's power shot won't be handled, amped vortex refire also ignore this
	// looks pretty silly. though it breaks vanilla behavior, I'd like to remove it
	//Defensive Check - Couldn't repro error.
	/*
	if ( "shotgunPelletsToIgnore" in vortexWeapon.s )
		bulletCount = int( ceil( bulletCount - vortexWeapon.s.shotgunPelletsToIgnore ) )
	*/

	if ( bulletCount )
	{
		bulletCount = minint( bulletCount, MAX_BULLET_PER_SHOT )

		//if ( IsClient() && GetLocalViewPlayer() == vortexWeapon.GetWeaponOwner() )
		//	printt( "vortex firing", bulletCount, "bullets" )

		float radius = LOUD_WEAPON_AI_SOUND_RADIUS_MP;
		vortexWeapon.EmitWeaponNpcSound( radius, 0.2 )
		int damageType = damageTypes.shotgun | DF_VORTEX_REFIRE
		// removing 1-bullet fireback, always do ShotgunBlast
		//if ( bulletCount == 1 ) // wait respawn you serious? 1 bullet can be refired to any distance?
		//	vortexWeapon.FireWeaponBullet( attackParams.pos, attackParams.dir, bulletCount, damageType )
		//else
			ShotgunBlast( vortexWeapon, attackParams.pos, attackParams.dir, bulletCount, damageType )
	}

	return bulletCount
}

#if SERVER
// rework vortexWeapon and attackParams to be typed...
//bool function Vortex_FireBackExplosiveRound( vortexWeapon, attackParams, impactData, sequenceID )
bool function Vortex_FireBackExplosiveRound( entity vortexWeapon, WeaponPrimaryAttackParams attackParams, impactData, sequenceID )
{
	//expect entity( vortexWeapon )

	// common projectile data
	float projSpeed		= 8000.0
	int damageType		= damageTypes.explosive | DF_VORTEX_REFIRE

	vortexWeapon.EmitWeaponSound( "Weapon.Explosion_Med" )

	vector attackPos
	//Requires code feature to properly fire tracers from offset positions.
	//if ( vortexWeapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod ) )
	//	attackPos = impactData.origin
	//else
		attackPos = Vortex_GenerateRandomRefireOrigin( vortexWeapon )

	vector fireVec = Vortex_GenerateRandomRefireVector( vortexWeapon, VORTEX_EXP_ROUNDS_RETURN_SPREAD_XY, VORTEX_EXP_ROUNDS_RETURN_SPREAD_Z )

	// fire off the bolt
	entity bolt = FireWeaponBolt_RecordData( vortexWeapon, attackPos, fireVec, projSpeed, damageType, damageType, PROJECTILE_NOT_PREDICTED, sequenceID )
	if ( bolt )
	{
		bolt.kv.gravity = 0.3

		// modified: add vortexWeapon parameter
		//Vortex_ProjectileCommonSetup( bolt, impactData )
		Vortex_ProjectileCommonSetup( bolt, impactData, vortexWeapon )
	}

	return true
}

// rework vortexWeapon and attackParams to be typed...
//bool function Vortex_FireBackProjectileBullet( vortexWeapon, attackParams, impactData, sequenceID )
bool function Vortex_FireBackProjectileBullet( entity vortexWeapon, WeaponPrimaryAttackParams attackParams, impactData, sequenceID )
{
	//expect entity( vortexWeapon )

	// common projectile data
	float projSpeed		= 12000.0
	int damageType		= damageTypes.bullet | DF_VORTEX_REFIRE

	vortexWeapon.EmitWeaponSound( "Weapon.Explosion_Med" )

	vector attackPos
	//Requires code feature to properly fire tracers from offset positions.
	//if ( vortexWeapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod ) )
	//	attackPos = impactData.origin
	//else
		attackPos = Vortex_GenerateRandomRefireOrigin( vortexWeapon )

	vector fireVec = Vortex_GenerateRandomRefireVector( vortexWeapon, 0.15, 0.1 )
	//printt( Time(), fireVec ) // print for bug with random

	// fire off the bolt
	entity bolt = FireWeaponBolt_RecordData( vortexWeapon, attackPos, fireVec, projSpeed, damageType, damageType, PROJECTILE_NOT_PREDICTED, sequenceID )
	if ( bolt )
	{
		bolt.kv.gravity = 0.0

		// modified: add vortexWeapon parameter
		//Vortex_ProjectileCommonSetup( bolt, impactData )
		Vortex_ProjectileCommonSetup( bolt, impactData, vortexWeapon )
	}

	return true
}

vector function Vortex_GenerateRandomRefireOrigin( entity vortexWeapon, float distFromCenter = 3.0 )
{
	float distFromCenter_neg = distFromCenter * -1

	vector attackPos = expect vector( vortexWeapon.s.vortexBulletEffectCP.GetOrigin() )

	float x = RandomFloatRange( distFromCenter_neg, distFromCenter )
	float y = RandomFloatRange( distFromCenter_neg, distFromCenter )
	float z = RandomFloatRange( distFromCenter_neg, distFromCenter )

	attackPos = attackPos + Vector( x, y, z )

	return attackPos
}

vector function Vortex_GenerateRandomRefireVector( entity vortexWeapon, float vecSpread, float vecSpreadZ )
{
	float x = RandomFloatRange( vecSpread * -1, vecSpread )
	float y = RandomFloatRange( vecSpread * -1, vecSpread )
	float z = RandomFloatRange( vecSpreadZ * -1, vecSpreadZ )

	vector fireVec = vortexWeapon.GetWeaponOwner().GetPlayerOrNPCViewVector() + Vector( x, y, z )
	return fireVec
}

// rework vortexWeapon and attackParams to be typed...
//bool function Vortex_FireBackRocket( vortexWeapon, attackParams, impactData, sequenceID )
bool function Vortex_FireBackRocket( entity vortexWeapon, WeaponPrimaryAttackParams attackParams, impactData, sequenceID )
{
	//expect entity( vortexWeapon )

	// TODO prediction for clients
	Assert( IsServer() )

	entity rocket = FireWeaponMissile_RecordData( vortexWeapon, attackParams.pos, attackParams.dir, 1800.0, damageTypes.largeCaliberExp | DF_VORTEX_REFIRE, damageTypes.largeCaliberExp | DF_VORTEX_REFIRE, false, PROJECTILE_NOT_PREDICTED )

	if ( rocket )
	{
		rocket.kv.lifetime = RandomFloatRange( 2.6, 3.5 )

		//InitMissileForRandomDriftForVortexLow( rocket, expect vector( attackParams.pos ), expect vector( attackParams.dir ) )
		InitMissileForRandomDriftForVortexLow( rocket, attackParams.pos, attackParams.dir )

		// modified: add vortexWeapon parameter
		//Vortex_ProjectileCommonSetup( rocket, impactData )
		Vortex_ProjectileCommonSetup( rocket, impactData, vortexWeapon )
	}

	return true
}

// rework all attackParams to be typed...
//bool function Vortex_FireBackGrenade( entity vortexWeapon, attackParams, impactData, int attackSeedCount, float baseFuseTime )
bool function Vortex_FireBackGrenade( entity vortexWeapon, WeaponPrimaryAttackParams attackParams, impactData, int attackSeedCount, float baseFuseTime )
{
	float x = RandomFloatRange( -0.2, 0.2 )
	float y = RandomFloatRange( -0.2, 0.2 )
	float z = RandomFloatRange( -0.2, 0.2 )

	//vector velocity = ( expect vector( attackParams.dir ) + Vector( x, y, z ) ) * 1500
	vector velocity = ( attackParams.dir + Vector( x, y, z ) ) * 1500
	vector angularVelocity = Vector( RandomFloatRange( -1200, 1200 ), 100, 0 )

	// rework these hardcoded stuffs, now handled by impactData
	//bool hasIgnitionTime = vortexImpactWeaponInfo[ impactData.weaponName ].grenade_ignition_time > 0
	bool hasIgnitionTime = impactData.grenade_ignition_time != null && impactData.grenade_ignition_time > 0
	float fuseTime = hasIgnitionTime ? 0.0 : baseFuseTime
	const int HARDCODED_DAMAGE_TYPE = (damageTypes.explosive | DF_VORTEX_REFIRE)

	entity grenade = FireWeaponGrenade_RecordData( vortexWeapon, attackParams.pos, velocity, angularVelocity, fuseTime, HARDCODED_DAMAGE_TYPE, HARDCODED_DAMAGE_TYPE, PROJECTILE_NOT_PREDICTED, true, true )
	if ( grenade )
	{
		Grenade_Init( grenade, vortexWeapon )
		// modified: add vortexWeapon parameter
		//Vortex_ProjectileCommonSetup( grenade, impactData )
		Vortex_ProjectileCommonSetup( grenade, impactData, vortexWeapon )
		if ( hasIgnitionTime )
		{
			// rework these hardcoded stuffs, now handled by impactData
			//grenade.SetGrenadeIgnitionDuration( vortexImpactWeaponInfo[ impactData.weaponName ].grenade_ignition_time )
			grenade.SetGrenadeIgnitionDuration( impactData.grenade_ignition_time )
		}
	}

	return (grenade ? true : false)
}

// rework all attackParams to be typed...
//bool function DoVortexAttackForImpactData( entity vortexWeapon, attackParams, impactData, int attackSeedCount )
bool function DoVortexAttackForImpactData( entity vortexWeapon, WeaponPrimaryAttackParams attackParams, impactData, int attackSeedCount )
{
	bool didFire = false
	switch ( impactData.refireBehavior )
	{
		case VORTEX_REFIRE_EXPLOSIVE_ROUND:
			didFire = Vortex_FireBackExplosiveRound( vortexWeapon, attackParams, impactData, attackSeedCount )
			break

		case VORTEX_REFIRE_ROCKET:
			didFire = Vortex_FireBackRocket( vortexWeapon, attackParams, impactData, attackSeedCount )
			break

		case VORTEX_REFIRE_GRENADE:
			didFire = Vortex_FireBackGrenade( vortexWeapon, attackParams, impactData, attackSeedCount, 1.25 )
			break

		case VORTEX_REFIRE_GRENADE_LONG_FUSE:
			didFire = Vortex_FireBackGrenade( vortexWeapon, attackParams, impactData, attackSeedCount, 10.0 )
			break

		case VORTEX_REFIRE_BULLET:
			didFire = Vortex_FireBackProjectileBullet( vortexWeapon, attackParams, impactData, attackSeedCount )
			break

		case VORTEX_REFIRE_NONE:
			break
	}

	return didFire
}

// modified: add vortexWeapon parameter, so we can run callbacks
//function Vortex_ProjectileCommonSetup( entity projectile, impactData )
function Vortex_ProjectileCommonSetup( entity projectile, impactData, entity vortexWeapon = null )
{
	// custom tag it so it shows up correctly if it hits another vortex sphere
	projectile.s.originalDamageSource <- impactData.damageSourceID

	Vortex_SetImpactEffectTable_OnProjectile( projectile, impactData )  // set the correct impact effect table

	// using a modified function so we can get whether they're vortexed or not
	//projectile.SetVortexRefired( true ) // This tells code the projectile was refired from the vortex so that it uses "projectile_vortex_vscript"
	Vortex_SetProjectileRefiredByVortex( projectile, true )

	// modified: model from modified impactData
	if ( "projectileModel" in impactData )
		projectile.SetModel( expect asset( impactData.projectileModel ) )
	else // default
		projectile.SetModel( GetWeaponInfoFileKeyFieldAsset_Global( impactData.weaponName, "projectilemodel" ) )

	//projectile.SetWeaponClassName( impactData.weaponName )  // causes the projectile to use its normal trail FX
	string weaponName = expect string( impactData.weaponName )
	projectile.SetWeaponClassName( weaponName )

	projectile.ProjectileSetDamageSourceID( impactData.damageSourceID ) // obit will show the owner weapon

	// modified: get refired mods from here
	bool haveModsToKeep = false
	if ( "refiredProjectileMods" in impactData )
	{
		array<string> typedArray
		foreach ( mod in impactData.refiredProjectileMods )
			typedArray.append( expect string( mod ) )
		file.vortexRefiredProjectileMods[ projectile ] <- typedArray

		// also... try to use our hack to add mods to current projectile
		// can't handle it good enough, multiple props with 0 passthrough thickness can still block projectile
		/*
		array<string> ownedMods = projectile.ProjectileGetMods() // get original projectile's mods
		array<string> modsToRetain = GetWeaponModsRetainedOnRefire( weaponName ) // only add mods those needs to be applied on refire( such as damage mod )
		foreach ( string mod in typedArray )
		{
			if ( !ownedMods.contains( mod ) && modsToRetain.contains( mod ) )
				HACK_ProjectileAddMod( projectile, mod )
		}
		*/

		haveModsToKeep = ShouldKeepModsDataOnRefire( typedArray )
	}

	// modified: fix for trails
	// if there ain't any mod needed to be saved, we won't have to do this
	if ( haveModsToKeep )
	{
		if ( "projectileTrail" in impactData )
		{
			asset trailEffect = expect asset( impactData.projectileTrail )
			if ( trailEffect != $"" )
				thread DelayedStartParticleEffectOnProjectile( projectile, trailEffect ) // delay one frame, so client can predict it
		}
	}

	// modified: run callbacks
	RunCallback_OnProjectileRefiredByVortex_ClassName( weaponName, projectile, vortexWeapon )
}

// delay one frame, so client themselves can see it
void function DelayedStartParticleEffectOnProjectile( entity projectile, asset trailEffect )
{
	WaitFrame()
	if ( IsValid( projectile ) )
	{
		// debug
		//print( "starting trail on refired projectile!" )
		StartParticleEffectOnEntity( projectile, GetParticleSystemIndex( trailEffect ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
	}
}
//

// gives a refired projectile the correct impact effect table
function Vortex_SetImpactEffectTable_OnProjectile( projectile, impactData )
{
	//Getting more info for bug 207595, don't check into Staging.
	#if DEV
	printt( "impactData.impact_effect_table ", impactData.impact_effect_table )
	if ( impactData.impact_effect_table == "" )
		PrintTable( impactData )
	#endif

	local fxTableHandle = GetImpactEffectTable( impactData.impact_effect_table )

	projectile.SetImpactEffectTable( fxTableHandle )
}
#endif // SERVER

// absorbed bullets are tracked with a special networked kv variable because clients need to know how many bullets to fire as well, when they are doing the client version of FireWeaponBullet
int function GetBulletsAbsorbedCount( entity vortexWeapon )
{
	if ( !vortexWeapon )
		return 0

	entity vortexSphere = vortexWeapon.GetWeaponUtilityEntity()
	if ( !vortexSphere )
		return 0

	return vortexSphere.GetBulletAbsorbedCount()
}

int function GetProjectilesAbsorbedCount( entity vortexWeapon )
{
	if ( !vortexWeapon )
		return 0

	entity vortexSphere = vortexWeapon.GetWeaponUtilityEntity()
	if ( !vortexSphere )
		return 0

	return vortexSphere.GetProjectileAbsorbedCount()
}

// reworked amped vortex: they won't use any predicted refire, feel free to use serverside-only variables
#if SERVER
int function GetAmpedBulletsAbsorbedCount( entity vortexWeapon )
{
	if ( !vortexWeapon )
		return 0
	
	if ( !( "ampedBulletCount" in vortexWeapon.s ) )
		return 0

	return expect int( vortexWeapon.s.ampedBulletCount )
}

int function GetAmpedProjectilesAbsorbedCount( entity vortexWeapon )
{
	if ( !vortexWeapon )
		return 0
	
	if ( !( "ampedProjectileCount" in vortexWeapon.s ) )
		return 0

	return expect int( vortexWeapon.s.ampedProjectileCount )
}

void function AddVortexWeaponAmpedBulletCount( entity vortexWeapon )
{
	if ( "ampedBulletCount" in vortexWeapon.s )
		vortexWeapon.s.ampedBulletCount++
	else
		vortexWeapon.s.ampedBulletCount <- 1
}

void function RemoveVortexWeaponAmpedBulletCount( entity vortexWeapon )
{
	if ( !( "ampedBulletCount" in vortexWeapon.s ) )
		return
	
	if ( vortexWeapon.s.ampedBulletCount <= 0 )
	{
		vortexWeapon.s.ampedBulletCount = 0
		return
	}
	vortexWeapon.s.ampedBulletCount--
}

void function AddVortexWeaponAmpedProjectileCount( entity vortexWeapon )
{
	if ( "ampedProjectileCount" in vortexWeapon.s )
		vortexWeapon.s.ampedProjectileCount++
	else
		vortexWeapon.s.ampedProjectileCount <- 1
}

void function RemoveVortexWeaponAmpedProjectileCount( entity vortexWeapon )
{
	if ( !( "ampedProjectileCount" in vortexWeapon.s ) )
		return
	
	if ( vortexWeapon.s.ampedProjectileCount <= 0 )
	{
		vortexWeapon.s.ampedProjectileCount = 0
		return
	}
	vortexWeapon.s.ampedProjectileCount--
}
#endif // SERVER

#if SERVER
function Vortex_GetProjectileImpacts( entity vortexWeapon )
{
	local impacts = []
	foreach ( impactData in Vortex_GetAllImpactEvents( vortexWeapon ) )
	{
		if ( impactData.impactType == "projectile" )
			impacts.append( impactData )
	}

	return impacts
}

function Vortex_GetHitscanBulletImpacts( entity vortexWeapon )
{
	local impacts = []
	foreach ( impactData in Vortex_GetAllImpactEvents( vortexWeapon ) )
	{
		if ( impactData.impactType == "hitscan" )
			impacts.append( impactData )
	}

	return impacts
}

int function GetHitscanBulletImpactCount( entity vortexWeapon )
{
	int count = 0
	foreach ( impactData in Vortex_GetAllImpactEvents( vortexWeapon ) )
	{
		if ( impactData.impactType == "hitscan" )
			count++
	}

	return count
}
#endif // SERVER

// // lets the damage callback communicate to the attacker that he hit a vortex shield
function Vortex_NotifyAttackerDidDamage( entity attacker, entity vortexOwner, hitPos )
{
	if ( !IsValid( attacker ) || !attacker.IsPlayer() )
		return

	if ( !IsValid( vortexOwner ) )
		return

	Assert( hitPos )

	attacker.NotifyDidDamage( vortexOwner, 0, hitPos, 0, 0, DAMAGEFLAG_VICTIM_HAS_VORTEX, 0, null, 0 )
}

function SetVortexAmmo( entity vortexWeapon, count )
{
	entity owner = vortexWeapon.GetWeaponOwner()
	if ( !IsValid_ThisFrame( owner ) )
		return
	#if CLIENT
		if ( !IsLocalViewPlayer( owner ) )
		return
	#endif

	vortexWeapon.SetWeaponPrimaryAmmoCount( count )
}


// sets the RGB color value for the vortex sphere FX based on current charge fraction
// modified: make it typed, so we can handle it with callbacks
//function VortexSphereColorUpdate( entity weapon, sphereClientFXHandle = null )
void function VortexSphereColorUpdate( entity weapon, var sphereClientFXHandle = null )
{
	weapon.EndSignal( "VortexStopping" )

	#if CLIENT
		Assert( sphereClientFXHandle != null )
	#endif
	bool isIonVortex = weapon.GetWeaponClassName() == "mp_titanweapon_vortex_shield_ion"
	entity weaponOwner = weapon.GetWeaponOwner()
	float energyTotal = float ( weaponOwner.GetSharedEnergyTotal() )
	while( IsValid( weapon ) && IsValid( weaponOwner ) )
	{
		vector colorVec
		if ( isIonVortex )
		{
			float energyFrac = 1.0 - float( weaponOwner.GetSharedEnergyCount() ) / energyTotal
			if ( weapon.HasMod( "pas_ion_vortex" ) )
				colorVec = GetVortexSphereCurrentColor( energyFrac, VORTEX_SPHERE_COLOR_PAS_ION_VORTEX )
			else
				colorVec = GetVortexSphereCurrentColor( energyFrac )
		}
		else
		{
			colorVec = GetVortexSphereCurrentColor( weapon.GetWeaponChargeFraction() )
		}


		// update the world entity that is linked to the world FX playing on the server
		#if SERVER
			weapon.s.vortexSphereColorCP.SetOrigin( colorVec )
		#else
			// handles the server killing the vortex sphere without the client knowing right away,
			//  for example if an explosive goes off and we short circuit the charge timer
			if ( !EffectDoesExist( sphereClientFXHandle ) )
				break

			EffectSetControlPointVector( sphereClientFXHandle, 1, colorVec )
		#endif

		WaitFrame()
	}
}

vector function GetVortexSphereCurrentColor( float chargeFrac, vector fullHealthColor = VORTEX_SPHERE_COLOR_CHARGE_FULL )
{
	return GetTriLerpColor( chargeFrac, fullHealthColor, VORTEX_SPHERE_COLOR_CHARGE_MED, VORTEX_SPHERE_COLOR_CHARGE_EMPTY )
}

vector function GetShieldTriLerpColor( float frac )
{
	return GetTriLerpColor( frac, VORTEX_SPHERE_COLOR_CHARGE_FULL, VORTEX_SPHERE_COLOR_CHARGE_MED, VORTEX_SPHERE_COLOR_CHARGE_EMPTY )
}

vector function GetTriLerpColor( float fraction, vector color1, vector color2, vector color3 )
{
	float crossover1 = VORTEX_SPHERE_COLOR_CROSSOVERFRAC_FULL2MED  // from zero to this fraction, fade between color1 and color2
	float crossover2 = VORTEX_SPHERE_COLOR_CROSSOVERFRAC_MED2EMPTY  // from crossover1 to this fraction, fade between color2 and color3

	float r, g, b

	// 0 = full charge, 1 = no charge remaining
	if ( fraction < crossover1 )
	{
		r = Graph( fraction, 0, crossover1, color1.x, color2.x )
		g = Graph( fraction, 0, crossover1, color1.y, color2.y )
		b = Graph( fraction, 0, crossover1, color1.z, color2.z )
		return <r, g, b>
	}
	else if ( fraction < crossover2 )
	{
		r = Graph( fraction, crossover1, crossover2, color2.x, color3.x )
		g = Graph( fraction, crossover1, crossover2, color2.y, color3.y )
		b = Graph( fraction, crossover1, crossover2, color2.z, color3.z )
		return <r, g, b>
	}
	else
	{
		// for the last bit of overload timer, keep it max danger color
		r = color3.x
		g = color3.y
		b = color3.z
		return <r, g, b>
	}

	unreachable
}

// generic impact validation
#if SERVER
bool function ValidateVortexImpact( entity vortexSphere, entity projectile = null )
{
	Assert( IsServer() )

	if ( !IsValid( vortexSphere ) )
		return false

	if ( !vortexSphere.GetOwnerWeapon() )
		return false

	entity vortexWeapon = vortexSphere.GetOwnerWeapon()
	if ( !IsValid( vortexWeapon ) )
		return false

	if ( projectile )
	{
		if ( !IsValid_ThisFrame( projectile ) )
			return false

		if ( projectile.ProjectileGetWeaponInfoFileKeyField( "projectile_ignores_vortex" ) == 1 )
			return false

		if ( projectile.ProjectileGetWeaponClassName() == "" )
			return false

		// TEMP HACK
		if ( projectile.ProjectileGetWeaponClassName() == "mp_weapon_tether" )
			return false
	}

	return true
}
#endif

/********************************/
/*	Setting override functions	*/
/********************************/

function Vortex_SetTagName( entity weapon, string tagName )
{
	Vortex_SetWeaponSettingOverride( weapon, "vortexTagName", tagName )
}

function Vortex_SetBulletCollectionOffset( entity weapon, vector offset )
{
	Vortex_SetWeaponSettingOverride( weapon, "bulletCollectionOffset", offset )
}

function Vortex_SetWeaponSettingOverride( entity weapon, string setting, value )
{
	if ( !( setting in weapon.s ) )
		weapon.s[ setting ] <- null
	weapon.s[ setting ] = value
}

string function GetVortexTagName( entity weapon )
{
	if ( "vortexTagName" in weapon.s )
		return expect string( weapon.s.vortexTagName )

	return "vortex_center"
}

vector function GetBulletCollectionOffset( entity weapon )
{
	if ( "bulletCollectionOffset" in weapon.s )
		return expect vector( weapon.s.bulletCollectionOffset )

	entity owner = weapon.GetWeaponOwner()
	if ( owner.IsTitan() )
		return Vector( 300.0, -90.0, -70.0 )
	else
		return Vector( 80.0, 17.0, -11.0 )

	unreachable
}


#if SERVER
// nessie: really should leave a AddEntityCallback_OnVortexSphereDrainHealthForDamage()
// AddEntityCallback_OnVortexSphereDrainHealthForDamage( entity vortexSphere, var damageInfo )
function VortexSphereDrainHealthForDamage( entity vortexSphere, damage )
{
	// don't drain the health of vortex_spheres that are set to be invulnerable. This is the case for the Particle Wall
	if ( vortexSphere.IsInvulnerable() )
		return

	local result = {}
	result.damage <- damage
	vortexSphere.Signal( "Script_OnDamaged", result )

	int currentHealth = vortexSphere.GetHealth()
	Assert( damage >= 0 )
	// JFS to fix phone home bug; we never hit the assert above locally...
	damage = max( damage, 0 )
	vortexSphere.SetHealth( currentHealth - damage )

	entity vortexWeapon = vortexSphere.GetOwnerWeapon()
	if ( IsValid( vortexWeapon ) && vortexWeapon.HasMod( "fd_gun_shield_redirect" ) )
	{
		entity owner = vortexWeapon.GetWeaponOwner()
		if ( IsValid( owner ) && owner.IsTitan() )
		{
			entity soul = owner.GetTitanSoul()
			if ( IsValid( soul ) )
			{
				int shieldRestoreAmount = int( damage ) //Might need tuning
				//soul.SetShieldHealth( min( soul.GetShieldHealth() + shieldRestoreAmount, soul.GetShieldHealthMax() ) )
				SetShieldHealthWithFix( soul, min( GetShieldHealthWithFix( soul ) + shieldRestoreAmount, GetShieldHealthMaxWithFix( soul ) ) )
			}
		}
	}

	UpdateShieldWallColorForFrac( vortexSphere.e.shieldWallFX, GetHealthFrac( vortexSphere ) )
}
#endif


bool function CodeCallback_OnVortexHitBullet( entity weapon, entity vortexSphere, var damageInfo )
{
	bool isAmpedWall = vortexSphere.GetTargetName() == PROTO_AMPED_WALL
	bool takesDamage = !isAmpedWall
	bool adjustImpactAngles = !(vortexSphere.GetTargetName() == GUN_SHIELD_WALL)

	#if SERVER
		if ( vortexSphere.e.BulletHitRules != null )
		{
			vortexSphere.e.BulletHitRules( vortexSphere, damageInfo )
			takesDamage = takesDamage && (DamageInfo_GetDamage( damageInfo ) > 0)
		}
	#endif

	vector damageAngles = vortexSphere.GetAngles()

	if ( adjustImpactAngles )
		damageAngles = AnglesCompose( damageAngles, Vector( 90, 0, 0 ) )

	int teamNum = vortexSphere.GetTeam()

	#if CLIENT
		vector damageOrigin = DamageInfo_GetDamagePosition( damageInfo )
		if ( !isAmpedWall )
		{
			// TODO: slightly change angles to match radius rotation of vortex cylinder
			int effectHandle = StartParticleEffectInWorldWithHandle( GetParticleSystemIndex( SHIELD_WALL_BULLET_FX ), damageOrigin, damageAngles )
			//local color = GetShieldTriLerpColor( 1 - GetHealthFrac( vortexSphere ) )
			vector color = GetShieldTriLerpColor( 0.0 )
			EffectSetControlPointVector( effectHandle, 1, color )
		}

		if ( takesDamage )
		{
			float damage = ceil( DamageInfo_GetDamage( damageInfo ) )
			int damageType = DamageInfo_GetCustomDamageType( damageInfo )
			DamageFlyout( damage, damageOrigin, vortexSphere, false, false )
		}

		if ( DamageInfo_GetAttacker( damageInfo ) && DamageInfo_GetAttacker( damageInfo ).IsTitan() )
			EmitSoundAtPosition( teamNum, DamageInfo_GetDamagePosition( damageInfo ), "TitanShieldWall.Heavy.BulletImpact_1P_vs_3P" )
		else
			EmitSoundAtPosition( teamNum, DamageInfo_GetDamagePosition( damageInfo ), "TitanShieldWall.Light.BulletImpact_1P_vs_3P" )
	#else
		if ( !isAmpedWall )
		{
			int fxId = GetParticleSystemIndex( SHIELD_WALL_BULLET_FX )
			PlayEffectOnVortexSphere( fxId, DamageInfo_GetDamagePosition( damageInfo ), damageAngles, vortexSphere )
		}

		// I... genericly don't understand why respawn have to code things like this...
		// reworked
		/*
		entity weapon = DamageInfo_GetWeapon( damageInfo )
		float damage = ceil( DamageInfo_GetDamage( damageInfo ) )

		Assert( damage >= 0, "Bug 159851 - Damage should be greater than or equal to 0.")
		damage = max( 0.0, damage )

		if ( IsValid( weapon ) )
			damage = HandleWeakToPilotWeapons( vortexSphere, weapon.GetWeaponClassName(), damage )

		if ( takesDamage )
		{
			//JFS - Arc Round bug fix for Monarch. Projectiles vortex callback doesn't even have damageInfo, so the shield modifier here doesn't exist in VortexSphereDrainHealthForDamage like it should.
			ShieldDamageModifier damageModifier = GetShieldDamageModifier( damageInfo )
			damage *= damageModifier.damageScale
			VortexSphereDrainHealthForDamage( vortexSphere, damage )
		}
		*/
		float damage = Vortex_CalculateBulletHitDamage( vortexSphere, damageInfo )
		if ( takesDamage )
			VortexSphereDrainHealthForDamage( vortexSphere, damage )
		// rework end

		if ( DamageInfo_GetAttacker( damageInfo ) && DamageInfo_GetAttacker( damageInfo ).IsTitan() )
			EmitSoundAtPosition( teamNum, DamageInfo_GetDamagePosition( damageInfo ), "TitanShieldWall.Heavy.BulletImpact_3P_vs_3P" )
		else
			EmitSoundAtPosition( teamNum, DamageInfo_GetDamagePosition( damageInfo ), "TitanShieldWall.Light.BulletImpact_3P_vs_3P" )
	#endif

	if ( isAmpedWall )
	{
		#if SERVER
		DamageInfo_ScaleDamage( damageInfo, AMPED_DAMAGE_SCALAR )
		#endif
		return false // I think this means bullet won't be absorbed?
	}

	// run modified callbacks
	RunEntityCallbacks_OnVortexHitBullet( vortexSphere, weapon, damageInfo )

	return true
}

bool function OnVortexHitBullet_BubbleShieldNPC( entity vortexSphere, var damageInfo )
{
	vector vortexOrigin 	= vortexSphere.GetOrigin()
	vector damageOrigin 	= DamageInfo_GetDamagePosition( damageInfo )

	float distSq = DistanceSqr( vortexOrigin, damageOrigin )
	if ( distSq < MINION_BUBBLE_SHIELD_RADIUS_SQR )
		return false//the damage is coming from INSIDE the sphere

	vector damageVec 	= damageOrigin - vortexOrigin
	vector damageAngles = VectorToAngles( damageVec )
	damageAngles = AnglesCompose( damageAngles, Vector( 90, 0, 0 ) )

	int teamNum = vortexSphere.GetTeam()

	#if CLIENT
		int effectHandle = StartParticleEffectInWorldWithHandle( GetParticleSystemIndex( SHIELD_WALL_BULLET_FX ), damageOrigin, damageAngles )

		vector color = GetShieldTriLerpColor( 0.9 )
		EffectSetControlPointVector( effectHandle, 1, color )

		if ( DamageInfo_GetAttacker( damageInfo ) && DamageInfo_GetAttacker( damageInfo ).IsTitan() )
			EmitSoundAtPosition( teamNum, DamageInfo_GetDamagePosition( damageInfo ), "TitanShieldWall.Heavy.BulletImpact_1P_vs_3P" )
		else
			EmitSoundAtPosition( teamNum, DamageInfo_GetDamagePosition( damageInfo ), "TitanShieldWall.Light.BulletImpact_1P_vs_3P" )
	#else
		int fxId = GetParticleSystemIndex( SHIELD_WALL_BULLET_FX )
		PlayEffectOnVortexSphere( fxId, DamageInfo_GetDamagePosition( damageInfo ), damageAngles, vortexSphere )
		//VortexSphereDrainHealthForDamage( vortexSphere, DamageInfo_GetWeapon( damageInfo ), null )

		if ( DamageInfo_GetAttacker( damageInfo ) && DamageInfo_GetAttacker( damageInfo ).IsTitan() )
			EmitSoundAtPosition( teamNum, DamageInfo_GetDamagePosition( damageInfo ), "TitanShieldWall.Heavy.BulletImpact_3P_vs_3P" )
		else
			EmitSoundAtPosition( teamNum, DamageInfo_GetDamagePosition( damageInfo ), "TitanShieldWall.Light.BulletImpact_3P_vs_3P" )
	#endif
	return true
}

bool function CodeCallback_OnVortexHitProjectile( entity weapon, entity vortexSphere, entity attacker, entity projectile, vector contactPos )
{
	// code shouldn't call this on an invalid vortexsphere!
	if ( !IsValid( vortexSphere ) )
		return false

	// modified: vortex behavior override
	VortexBehaviorOverride overrideStruct = Vortex_GetBehaviorOverrideFromWeaponOrProjectile( projectile )

	var ignoreVortex = projectile.ProjectileGetWeaponInfoFileKeyField( "projectile_ignores_vortex" )
	// modified: vortex behavior override
	if ( overrideStruct.projectile_ignores_vortex != "" )
		ignoreVortex = overrideStruct.projectile_ignores_vortex

	if ( ignoreVortex != null )
	{
		#if SERVER
		if ( projectile.proj.hasBouncedOffVortex )
			return false

		vector velocity = projectile.GetVelocity()
		vector multiplier

		switch ( ignoreVortex )
		{
			case "drop":
				multiplier = < -0.25, -0.25, 0.0 >
				break

			case "fall_vortex":
			case "fall":
				multiplier = < -0.25, -0.25, -0.25 >
				break

			case "mirror":
				// bounce back, assume along xy axis
				multiplier = < -1.0, -1.0, 1.0 >
				break

			default:
				CodeWarning( "Unknown projectile_ignores_vortex " + ignoreVortex )
				break
		}

		velocity = < velocity.x * multiplier.x, velocity.y * multiplier.y, velocity.z * multiplier.z >
		projectile.proj.hasBouncedOffVortex = true
		projectile.SetVelocity( velocity )
		#endif
		return false
	}

	bool adjustImpactAngles = !(vortexSphere.GetTargetName() == GUN_SHIELD_WALL)

	vector damageAngles = vortexSphere.GetAngles()

	if ( adjustImpactAngles )
		damageAngles = AnglesCompose( damageAngles, Vector( 90, 0, 0 ) )

	asset projectileSettingFX = projectile.GetProjectileWeaponSettingAsset( eWeaponVar.vortex_impact_effect )
	// modified: vortex behavior override
	if ( overrideStruct.vortex_impact_effect != $"" )
		projectileSettingFX = overrideStruct.vortex_impact_effect
	
	asset impactFX = (projectileSettingFX != $"") ? projectileSettingFX : SHIELD_WALL_EXPMED_FX

	bool isAmpedWall = vortexSphere.GetTargetName() == PROTO_AMPED_WALL
	bool takesDamage = !isAmpedWall

	#if SERVER
		// WTF RESPAWN? why not pass the projectile entity on vortex hit? modified
		//if ( vortexSphere.e.ProjectileHitRules != null )
		//	takesDamage = vortexSphere.e.ProjectileHitRules( vortexSphere, attacker, takesDamage )
		// don't want to change entityStruct, use fileStruct instead
		if ( vortexSphere in file.vortexCustomProjectileHitRules )
			takesDamage = file.vortexCustomProjectileHitRules[ vortexSphere ]( vortexSphere, attacker, projectile, takesDamage )
	#endif
	// hack to let client know about amped wall, and to amp the shot
	if ( isAmpedWall )
		impactFX = AMPED_WALL_IMPACT_FX

	int teamNum = vortexSphere.GetTeam()

	#if CLIENT
		if ( !isAmpedWall )
		{
			int effectHandle = StartParticleEffectInWorldWithHandle( GetParticleSystemIndex( impactFX ), contactPos, damageAngles )
			//local color = GetShieldTriLerpColor( 1 - GetHealthFrac( vortexSphere ) )
			vector color = GetShieldTriLerpColor( 0.0 )
			EffectSetControlPointVector( effectHandle, 1, color )
		}

		var impact_sound_1p = projectile.ProjectileGetWeaponInfoFileKeyField( "vortex_impact_sound_1p" )
		// modified: vortex behavior override
		// though I think there won't be 1p vortex hit conditions. no vortex is bind with client-side
		if ( overrideStruct.impact_sound_1p != "" )
			impact_sound_1p = overrideStruct.impact_sound_1p
		
		if ( impact_sound_1p == null )
			impact_sound_1p = "TitanShieldWall.Explosive.BulletImpact_1P_vs_3P"

		EmitSoundAtPosition( teamNum, contactPos, impact_sound_1p )
	#else
		if ( !isAmpedWall )
		{
			int fxId = GetParticleSystemIndex( impactFX )
			PlayEffectOnVortexSphere( fxId, contactPos, damageAngles, vortexSphere )
		}

		// I... genericly don't understand why respawn have to code things like this...
		// reworked
		/*
		float damage = float( projectile.GetProjectileWeaponSettingInt( eWeaponVar.damage_near_value ) )
		//	once damageInfo is passed correctly we'll use that instead of looking up the values from the weapon .txt file.
		//	local damage = ceil( DamageInfo_GetDamage( damageInfo ) )

		damage = HandleWeakToPilotWeapons( vortexSphere, projectile.ProjectileGetWeaponClassName(), damage )
		damage = damage + CalculateTitanSniperExtraDamage( projectile, vortexSphere )
		*/
		float damage = Vortex_CalculateProjectileHitDamage( vortexSphere, attacker, projectile )
		// rework end

		if ( takesDamage )
		{
			VortexSphereDrainHealthForDamage( vortexSphere, damage )
			if ( IsValid( attacker ) && attacker.IsPlayer() )
				attacker.NotifyDidDamage( vortexSphere, 0, contactPos, 0, damage, DF_NO_HITBEEP, 0, null, 0 )
		}

		var impact_sound_3p = projectile.ProjectileGetWeaponInfoFileKeyField( "vortex_impact_sound_3p" )
		// modified: vortex behavior override
		// though I think there won't be 1p vortex hit conditions. no vortex is bind with client-side
		if ( overrideStruct.impact_sound_3p != "" )
			impact_sound_3p = overrideStruct.impact_sound_3p

		if ( impact_sound_3p == null )
			impact_sound_3p = "TitanShieldWall.Explosive.BulletImpact_3P_vs_3P"

		EmitSoundAtPosition( teamNum, contactPos, impact_sound_3p )

		// respawn you sure these things should hardcode?
		int damageSourceID = projectile.ProjectileGetDamageSourceID()
		switch ( damageSourceID )
		{
			case eDamageSourceId.mp_titanweapon_dumbfire_rockets:
				vector normal = projectile.GetVelocity() * -1
				normal = Normalize( normal )
				ClusterRocket_Detonate( projectile, normal )
				CreateNoSpawnArea( TEAM_INVALID, TEAM_INVALID, contactPos, ( CLUSTER_ROCKET_BURST_COUNT / 5.0 ) * 0.5 + 1.0, CLUSTER_ROCKET_BURST_RANGE + 100 )
				break

			case eDamageSourceId.mp_weapon_grenade_electric_smoke:
				ElectricGrenadeSmokescreen( projectile, FX_ELECTRIC_SMOKESCREEN_PILOT_AIR )
				break

			case eDamageSourceId.mp_weapon_grenade_emp:

				if ( StatusEffect_Get( vortexSphere, eStatusEffect.destroyed_by_emp ) )
					VortexSphereDrainHealthForDamage( vortexSphere, vortexSphere.GetHealth() )
				break

			case eDamageSourceId.mp_titanability_sonar_pulse:
				if ( IsValid( attacker ) && attacker.IsTitan() )
				{
					int team = attacker.GetTeam()
					PulseLocation( attacker, team, contactPos, false, false )
					//array<string> mods = projectile.ProjectileGetMods() // vanilla behavior, no need to use Vortex_GetRefiredProjectileMods()
					array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // I don't care, let's break vanilla behavior
					if ( mods.contains( "pas_tone_sonar" ) )
						thread DelayedPulseLocation( attacker, team, contactPos, false, false )
				}
				break

		}
	#endif

	// hack to let client know about amped wall, and to amp the shot
	if ( isAmpedWall )
	{
		#if SERVER
		projectile.proj.damageScale = AMPED_DAMAGE_SCALAR
		#endif

		return false
	}

	// run modified callbacks
	RunEntityCallbacks_OnVortexHitProjectile( vortexSphere, weapon, attacker, projectile, contactPos )

	return true
}

bool function OnVortexHitProjectile_BubbleShieldNPC( entity vortexSphere, entity attacker, entity projectile, vector contactPos )
{
	vector vortexOrigin 	= vortexSphere.GetOrigin()

	float dist = DistanceSqr( vortexOrigin, contactPos )
	if ( dist < MINION_BUBBLE_SHIELD_RADIUS_SQR )
		return false // the damage is coming from INSIDE THE SPHERE

	vector damageVec 	= Normalize( contactPos - vortexOrigin )
	vector damageAngles 	= VectorToAngles( damageVec )
	damageAngles = AnglesCompose( damageAngles, Vector( 90, 0, 0 ) )

	asset projectileSettingFX = projectile.GetProjectileWeaponSettingAsset( eWeaponVar.vortex_impact_effect )
	asset impactFX = (projectileSettingFX != $"") ? projectileSettingFX : SHIELD_WALL_EXPMED_FX

	int teamNum = vortexSphere.GetTeam()

	#if CLIENT
		int effectHandle = StartParticleEffectInWorldWithHandle( GetParticleSystemIndex( impactFX ), contactPos, damageAngles )

		vector color = GetShieldTriLerpColor( 0.9 )
		EffectSetControlPointVector( effectHandle, 1, color )

		EmitSoundAtPosition( teamNum, contactPos, "TitanShieldWall.Explosive.BulletImpact_1P_vs_3P" )
	#else
		int fxId = GetParticleSystemIndex( impactFX )
		PlayEffectOnVortexSphere( fxId, contactPos, damageAngles, vortexSphere )
//		VortexSphereDrainHealthForDamage( vortexSphere, null, projectile )

		EmitSoundAtPosition( teamNum, contactPos, "TitanShieldWall.Explosive.BulletImpact_3P_vs_3P" )

		if ( projectile.ProjectileGetDamageSourceID() == eDamageSourceId.mp_titanweapon_dumbfire_rockets )
		{
			vector normal = projectile.GetVelocity() * -1
			normal = Normalize( normal )
			ClusterRocket_Detonate( projectile, normal )
			CreateNoSpawnArea( TEAM_INVALID, TEAM_INVALID, contactPos, ( CLUSTER_ROCKET_BURST_COUNT / 5.0 ) * 0.5 + 1.0, CLUSTER_ROCKET_BURST_RANGE + 100 )
		}
	#endif
	return true
}

#if SERVER
float function HandleWeakToPilotWeapons( entity vortexSphere, string weaponName, float damage )
{
	if ( vortexSphere.e.proto_weakToPilotWeapons ) //needs code for real, but this is fine for prototyping
	{
		// is weapon a pilot weapon?
		local refType = GetWeaponInfoFileKeyField_Global( weaponName, "weaponClass" )
		if ( refType == "human" )
		{
			damage *= VORTEX_PILOT_WEAPON_WEAKNESS_DAMAGESCALE
		}
	}

	return damage
}
#endif

// to fix bad vortex refiring, this function has been reworked
// after reworking, this function only fires back 1 impactdata each time

// ???: reflectOrigin not used
//int function VortexReflectAttack( entity vortexWeapon, attackParams, vector reflectOrigin )
int function VortexReflectAttack( entity vortexWeapon, WeaponPrimaryAttackParams attackParams, impactData, string impactType )
{
	entity vortexSphere = vortexWeapon.GetWeaponUtilityEntity()
	if ( !vortexSphere )
		return 0

	#if SERVER
		Assert( vortexSphere )
	#endif

	// modified: this function only fires back 1 impactdata each time
	//int totalfired = 0
	//int totalAttempts = 0

	// this function won't destroy or disable vortex
	/*
	bool forceReleased = false
	// in this case, it's also considered "force released" if the charge time runs out
	if ( vortexWeapon.IsForceRelease() || vortexWeapon.GetWeaponChargeFraction() == 1 )
		forceReleased = true
	*/

	//Requires code feature to properly fire tracers from offset positions.
	//if ( vortexWeapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod ) )
	//	attackParams.pos = reflectOrigin

	// PREDICTED REFIRES
	// bullet impact events don't individually fire back per event because we aggregate and then shotgun blast them
	// nessie note: the signal is for triggering AmpedVortexRefireThink() in mp_titanweapon_vortex_shield.nut
	// but with modified script FPS, the reflecting maybe still fast enough to fire back per event( catching shotgunblast will still work )

	//Remove the below script after FireWeaponBulletBroadcast
	// reworked here: add back predicted refire, we've removed AmpedVortexRefireThink()
	// reworked again here: always fire back 1 bullet
	//local bulletsFired = Vortex_FireBackBullets( vortexWeapon, attackParams )
	//int bulletsFired = Vortex_FireBackBullets( vortexWeapon, attackParams )
	if ( impactType == "hitscan" )
	{
		int damageType = damageTypes.shotgun | DF_VORTEX_REFIRE
		ShotgunBlast( vortexWeapon, attackParams.pos, attackParams.dir, 1, damageType )
	}

	//totalfired += bulletsFired
	/*
	int bulletCount = GetBulletsAbsorbedCount( vortexWeapon )
	if ( bulletCount > 0 )
	{
		if ( "ampedBulletCount" in vortexWeapon.s )
			vortexWeapon.s.ampedBulletCount++
		else
			vortexWeapon.s.ampedBulletCount <- 1
		// to fix bad vortex refiring, this is removed
		//vortexWeapon.Signal( "FireAmpedVortexBullet" )
		totalfired += 1
	}
	*/

	// UNPREDICTED REFIRES
	#if SERVER
		//printt( "server: force released?", forceReleased )

		// reworked here fire back the specific impact data we passed in
		/*
		local unpredictedRefires = Vortex_GetProjectileImpacts( vortexWeapon )

		// HACK we don't actually want to refire them with a spiral but
		//   this is to temporarily ensure compatibility with the Titan rocket launcher
		if ( !( "spiralMissileIdx" in vortexWeapon.s ) )
			vortexWeapon.s.spiralMissileIdx <- null
		vortexWeapon.s.spiralMissileIdx = 0
		foreach ( impactData in unpredictedRefires )
		{
			bool didFire = DoVortexAttackForImpactData( vortexWeapon, attackParams, impactData, totalAttempts )
			if ( didFire )
				totalfired++
			totalAttempts++
		}
		*/

		if ( impactType == "projectile" )
		{
			// last parameter "attackSeedCount" is only used in Vortex_FireBackExplosiveRound() and Vortex_FireBackProjectileBullet()
			// default value should be 0
			bool didFire = DoVortexAttackForImpactData( vortexWeapon, attackParams, impactData, 0 )
			if ( !didFire ) // firing failed
				return 0 // don't do following think, return 0
		}
	#endif

	// removing SetVortexAmmo(), don't know how it works
	//SetVortexAmmo( vortexWeapon, 0 )
	// no need to signal things that can end certain thread
	//vortexWeapon.Signal( "VortexFired" )

#if SERVER
	// no longer needed, handled by DelayedVortexFireBack()
	//vortexSphere.ClearAllBulletsFromSphere()
#endif

	/*
	if ( forceReleased )
		DestroyVortexSphereFromVortexWeapon( vortexWeapon )
	else
		DisableVortexSphereFromVortexWeapon( vortexWeapon )
	*/

	// modified: this function only fires back 1 impactdata each time
	//return totalfired
	return 1
}
