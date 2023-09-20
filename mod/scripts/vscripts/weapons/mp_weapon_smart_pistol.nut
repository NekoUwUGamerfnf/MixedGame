untyped

global function MpWeaponSmartPistol_Init

global function OnWeaponActivate_weapon_smart_pistol
global function OnWeaponDeactivate_weapon_smart_pistol
global function OnWeaponPrimaryAttack_weapon_smart_pistol
global function OnWeaponBulletHit_weapon_smart_pistol

global function OnWeaponStartZoomIn_weapon_smart_pistol
global function OnWeaponStartZoomOut_weapon_smart_pistol

const float SMART_PISTOL_TRACKER_TIME = 10.0

function MpWeaponSmartPistol_Init()
{
	PrecacheParticleSystem( $"P_smartpistol_lockon_FP" )
	PrecacheParticleSystem( $"P_smartpistol_lockon" )

	// modified condition
#if SERVER
	// burnmod blacklist
	// we've added burnmod support for smart pistol, no need to add blacklist for unlimited ammo
    //ModdedBurnMods_AddDisabledMod( "smart_pistol_unlimited_ammo" )
	ModdedBurnMods_AddDisabledMod( "fake_smart_xo16" )

	// damageSourceId callbacks
	AddCallback_WeaponMod_DamageSourceIdOverride( 
		"mp_weapon_smart_pistol",							// weapon name
		"fake_smart_xo16",									// weapon mod
		eDamageSourceId.mp_titanweapon_xo16_vanguard		// damageSourceId override
	)
#endif
}

void function OnWeaponActivate_weapon_smart_pistol( entity weapon )
{
	if ( !( "initialized" in weapon.s ) )
	{
		weapon.s.damageValue <- weapon.GetWeaponInfoFileKeyField( "damage_near_value" )
		SmartAmmo_SetAllowUnlockedFiring( weapon, true )
		SmartAmmo_SetUnlockAfterBurst( weapon, (SMART_AMMO_PLAYER_MAX_LOCKS > 1) )
		SmartAmmo_SetWarningIndicatorDelay( weapon, 0.0 )

		weapon.s.initialized <- true

#if SERVER
		weapon.s.lockStartTime <- Time()
		weapon.s.locking <- true
#endif
	}

#if SERVER
	weapon.s.locking = true
	weapon.s.lockStartTime = Time()

	// modified content: adding fake model for fake weapons
	CreateFakeModelForSmartPistol( weapon )
#endif
}

void function OnWeaponDeactivate_weapon_smart_pistol( entity weapon )
{
	weapon.StopWeaponEffect( $"P_smartpistol_lockon_FP", $"P_smartpistol_lockon" )

#if SERVER
	// modified content: adding fake model for fake weapons
	// shared utility from _fake_world_weapon_model.gnut
	// now handled by looping think "TrackFakeModelLifeTime()"
	//FakeWorldModel_DestroyForWeapon( weapon )
#endif
}

var function OnWeaponPrimaryAttack_weapon_smart_pistol( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	int damageFlags = weapon.GetWeaponDamageFlags()
	// note: fix for npc firing smart ammo done in sh_smart_ammo.gnut!
	return SmartAmmo_FireWeapon( weapon, attackParams, damageFlags, damageFlags )
}

function SmartWeaponFireSound( entity weapon, target )
{
	if ( weapon.HasMod( "silencer" ) )
	{
		weapon.EmitWeaponSound_1p3p( "Weapon_SmartPistol_SuppressedFire_1P", "Weapon_SmartPistol_SuppressedFire_3P" )
	}
	else
	{
		if ( target == null )
			weapon.EmitWeaponSound_1p3p( "Weapon_SmartPistol_Fire_1P", "Weapon_SmartPistol_Fire_3P" )
		else
			weapon.EmitWeaponSound_1p3p( "Weapon_SmartPistol_Fire_1P", "Weapon_SmartPistol_Fire_3P" )
	}
}

void function OnWeaponBulletHit_weapon_smart_pistol( entity weapon, WeaponBulletHitParams hitParams )
{
	//if ( weapon.HasMod( "proto_tracker" ) ) //Recheck for this once we make it mod only
	entity hitEnt = hitParams.hitEnt
	if ( IsValid( hitEnt ) )
	{
		weapon.SmartAmmo_TrackEntity( hitEnt, SMART_PISTOL_TRACKER_TIME )

		#if SERVER
			if ( weapon.GetWeaponSettingBool( eWeaponVar.smart_ammo_player_targets_must_be_tracked ) )
			{
				if ( hitEnt.IsPlayer() &&  !hitEnt.IsTitan() ) //Note that there is a max of 10 status effects, which means that if you theoreteically get hit as a pilot 10 times without somehow dying, you could knock out other status effects like emp slow etc
					StatusEffect_AddTimed( hitEnt, eStatusEffect.lockon_detected, 1.0, SMART_PISTOL_TRACKER_TIME, 0.0 )
			}
		#endif
	}

}

void function OnWeaponStartZoomIn_weapon_smart_pistol( entity weapon )
{

	if ( !weapon.HasMod( "ads_smaller_lock_on" ) )
	{
		array<string> mods = weapon.GetMods()
		mods.append( "ads_smaller_lock_on" )
		weapon.SetMods( mods )
	}
}

void function OnWeaponStartZoomOut_weapon_smart_pistol( entity weapon )
{
	if ( weapon.HasMod( "ads_smaller_lock_on" ) )
	{
		array<string> mods = weapon.GetMods()
		mods.fastremovebyvalue( "ads_smaller_lock_on" )
		weapon.SetMods( mods )
	}

}

#if SERVER
// modified content: adding fake model for fake weapons
// can't get eWeaponVar.playermodel... currently hardcode
const table< string, asset > FAKE_MODEL_MODS =
{
	["fake_smart_xo16"] = $"models/weapons/titan_xo16_shorty/w_xo16shorty.mdl"
}

void function CreateFakeModelForSmartPistol( entity weapon )
{
	string fakeModelMod = ""
	array<string> mods = weapon.GetMods()
	foreach ( mod in mods )
	{
		if ( mod in FAKE_MODEL_MODS )
		{
			//print( "Found fakemodel mod!" )
			fakeModelMod = mod
			break
		}
	}

	if ( fakeModelMod == "" )
	{
		//print( "Can't find fakemodel mod!" )
		return
	}

	// can't get eWeaponVar.playermodel... currently hardcode
	asset model = FAKE_MODEL_MODS[ fakeModelMod ]
	// shared utility from _fake_world_weapon_model.gnut
	FakeWorldModel_CreateForWeapon( weapon, model )
}
#endif