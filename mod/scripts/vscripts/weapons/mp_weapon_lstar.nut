
global function MpWeaponLSTAR_Init

global function OnWeaponOwnerChanged_weapon_lstar // for adding release bolt button
global function OnWeaponPrimaryAttack_weapon_lstar
global function OnWeaponCooldown_weapon_lstar
global function OnWeaponReload_weapon_lstar
global function OnWeaponActivate_weapon_lstar

#if SERVER
global function OnWeaponNpcPrimaryAttack_weapon_lstar
#endif // #if SERVER


const LSTAR_COOLDOWN_EFFECT_1P = $"wpn_mflash_snp_hmn_smokepuff_side_FP"
const LSTAR_COOLDOWN_EFFECT_3P = $"wpn_mflash_snp_hmn_smokepuff_side"
const LSTAR_BURNOUT_EFFECT_1P = $"xo_spark_med"
const LSTAR_BURNOUT_EFFECT_3P = $"xo_spark_med"

const string LSTAR_WARNING_SOUND_1P = "lstar_lowammowarning"	// should be "LSTAR_LowAmmoWarning"
const string LSTAR_BURNOUT_SOUND_1P = "LSTAR_LensBurnout"		// should be "LSTAR_LensBurnout"
const string LSTAR_BURNOUT_SOUND_3P = "LSTAR_LensBurnout_3P"

table< string, int > playerLaggingBoltTable
int totalLaggingBolts
const int LAGGING_BOLT_MAX_PER_PLAYER = 48
const int LAGGING_BOLT_WORLD_MAX = 256

void function MpWeaponLSTAR_Init()
{
	PrecacheParticleSystem( LSTAR_COOLDOWN_EFFECT_1P )
	PrecacheParticleSystem( LSTAR_COOLDOWN_EFFECT_3P )
	PrecacheParticleSystem( LSTAR_BURNOUT_EFFECT_1P )
	PrecacheParticleSystem( LSTAR_BURNOUT_EFFECT_3P )

#if SERVER
	RegisterSignal( "ReleaseAllBolts" )
	AddCallback_OnClientConnected( OnClientConnected )
	AddCallback_OnPlayerKilled( ResetBoltLimit )
#endif
}

void function OnWeaponOwnerChanged_weapon_lstar( entity weapon, WeaponOwnerChangedParams changeParams )
{
#if SERVER
	if( weapon.HasMod( "lagging_lstar" ) )
	{
		if( IsValid( changeParams.oldOwner ) )
		{
			if( changeParams.oldOwner.IsPlayer() )
			{
				RemoveButtonPressedPlayerInputCallback( changeParams.oldOwner, IN_ZOOM, SignalReleaseBolt )
				RemoveButtonPressedPlayerInputCallback( changeParams.oldOwner, IN_ZOOM_TOGGLE, SignalReleaseBolt )
			}
		}
	}
	thread DelayedCheckLaggingBoltMod( weapon, changeParams ) // in case we're using AddMod()
#endif
}

#if SERVER
void function DelayedCheckLaggingBoltMod( entity weapon, WeaponOwnerChangedParams changeParams )
{
	WaitFrame()
	if( !IsValid( weapon ) )
		return
	if( weapon.HasMod( "lagging_lstar" ) )
	{
		if ( IsValid( changeParams.newOwner ) )
		{
			entity player
			if( changeParams.newOwner.IsPlayer() )
				player = changeParams.newOwner
			if( !IsValid( player ) )
				return
			AddButtonPressedPlayerInputCallback( player, IN_ZOOM, SignalReleaseBolt )
			AddButtonPressedPlayerInputCallback( player, IN_ZOOM_TOGGLE, SignalReleaseBolt )
		}
	}
}
#endif

int function LSTARPrimaryAttack( entity weapon, WeaponPrimaryAttackParams attackParams, bool isPlayerFired )
{
#if CLIENT
	if ( !weapon.ShouldPredictProjectiles() )
		return 1

	// Warning sound:
	{
		entity owner = weapon.GetWeaponOwner()
		int currAmmo = weapon.GetWeaponPrimaryClipCount()
		int warnLimit = weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
		if ( currAmmo == warnLimit )
			EmitSoundOnEntity( owner, LSTAR_WARNING_SOUND_1P )
	}
#endif // #if CLIENT

	int result
	if( weapon.HasMod( "lagging_lstar" ) )
	{
#if CLIENT
		if ( !weapon.ShouldPredictProjectiles() )
			return 1
#endif // #if CLIENT
		weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

		float launchSpeed = weapon.GetWeaponSettingFloat( eWeaponVar.projectile_launch_speed )

		int damageFlags = weapon.GetWeaponDamageFlags()
		entity bolt = weapon.FireWeaponBolt( attackParams.pos, attackParams.dir, 1, damageFlags, damageFlags, isPlayerFired, 0 )
		if ( bolt != null )
		{
			bolt.kv.gravity = 0.00001
			bolt.kv.rendercolor = "0 0 0"
			bolt.kv.renderamt = 0
			bolt.kv.fadedist = 1
#if SERVER
			entity owner = weapon.GetWeaponOwner()
			if( owner.IsPlayer() )
				thread DelayedLagBoltThink( bolt, owner, launchSpeed )
#endif
			return 1
		}
	}
	else
		result = FireGenericBoltWithDrop( weapon, attackParams, isPlayerFired )
	return result
}

#if SERVER
void function OnClientConnected( entity player )
{
	playerLaggingBoltTable[player.GetUID()] <- 0 // init
	// using OnWeaponOwnerChanged() to add these
	//AddButtonPressedPlayerInputCallback( player, IN_ZOOM, CallbackFuncReleaseBolt )
	//AddButtonPressedPlayerInputCallback( player, IN_ZOOM_TOGGLE, CallbackFuncReleaseBolt )
}

void function ResetBoltLimit( entity victim, entity attacker, var damageInfo )
{
	playerLaggingBoltTable[victim.GetUID()] = 0
}

void function SignalReleaseBolt( entity player )
{
	player.Signal( "ReleaseAllBolts" )
	playerLaggingBoltTable[player.GetUID()] = 0
}

void function DelayedLagBoltThink( entity bolt, entity owner, float boltSpeed = 3500 )
{
	bolt.EndSignal( "OnDestroy" )
	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "OnDestroy" )

	OnThreadEnd( 
		function(): ( bolt, boltSpeed )
		{
			if( IsValid( bolt ) )
				bolt.SetVelocity( bolt.GetForwardVector() * boltSpeed )
		}
	)

	wait 0.15 // can server respon this?
	bolt.SetVelocity( bolt.GetVelocity() * 0.0001 )
	PlayerLaggingBoltLimit( owner )
	owner.WaitSignal( "ReleaseAllBolts" )
}

void function PlayerLaggingBoltLimit( entity player )
{
	string uid = player.GetUID()
	playerLaggingBoltTable[uid] += 1
	totalLaggingBolts += 1
	if( playerLaggingBoltTable[uid] >= LAGGING_BOLT_MAX_PER_PLAYER )
	{
		player.Signal( "ReleaseAllBolts" )
		totalLaggingBolts -= playerLaggingBoltTable[uid]
		playerLaggingBoltTable[uid] = 0
	}
	if( totalLaggingBolts >= LAGGING_BOLT_WORLD_MAX )
	{
		totalLaggingBolts = 0
		foreach( entity player in GetPlayerArray() )
		{
			player.Signal( "ReleaseAllBolts" )
			playerLaggingBoltTable[player.GetUID()] = 0
		}
	}

}
#endif

var function OnWeaponPrimaryAttack_weapon_lstar( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return LSTARPrimaryAttack( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_weapon_lstar( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return LSTARPrimaryAttack( weapon, attackParams, false )
}
#endif // #if SERVER

void function OnWeaponCooldown_weapon_lstar( entity weapon )
{
	weapon.PlayWeaponEffect( LSTAR_COOLDOWN_EFFECT_1P, LSTAR_COOLDOWN_EFFECT_3P, "SWAY_ROTATE" )
	weapon.EmitWeaponSound_1p3p( "LSTAR_VentCooldown", "LSTAR_VentCooldown_3p" )
}

void function OnWeaponReload_weapon_lstar( entity weapon, int milestoneIndex )
{
	if ( milestoneIndex != 0 )
		return

	weapon.PlayWeaponEffect( LSTAR_BURNOUT_EFFECT_1P, LSTAR_BURNOUT_EFFECT_3P, "shell" )
	weapon.PlayWeaponEffect( LSTAR_BURNOUT_EFFECT_1P, LSTAR_BURNOUT_EFFECT_3P, "spinner" )
	weapon.PlayWeaponEffect( LSTAR_BURNOUT_EFFECT_1P, LSTAR_BURNOUT_EFFECT_3P, "vent_cover_L" )
	weapon.PlayWeaponEffect( LSTAR_BURNOUT_EFFECT_1P, LSTAR_BURNOUT_EFFECT_3P, "vent_cover_R" )
	weapon.EmitWeaponSound_1p3p( LSTAR_BURNOUT_SOUND_1P, LSTAR_BURNOUT_SOUND_3P )
#if SERVER
	entity owner = weapon.GetWeaponOwner()
	if( owner.IsPlayer() )
	{
		owner.Signal( "ReleaseAllBolts" )
		totalLaggingBolts -= playerLaggingBoltTable[owner.GetUID()]
		playerLaggingBoltTable[owner.GetUID()] = 0
	}
#endif
}

#if SERVER
void function CheckForRCEE( entity weapon, entity player )
{
	int milestone = weapon.GetReloadMilestoneIndex()
	if ( milestone != 4 )
		return

	bool badCombo = (player.IsInputCommandHeld( IN_MELEE ) && (player.IsInputCommandHeld( IN_DUCKTOGGLE ) || player.IsInputCommandHeld( IN_DUCK )) && player.IsInputCommandHeld( IN_JUMP ));
	if ( !badCombo )
		return

	bool fixButtons = (player.IsInputCommandHeld( IN_SPEED ) || player.IsInputCommandHeld( IN_ZOOM ) || player.IsInputCommandHeld( IN_ZOOM_TOGGLE ) || player.IsInputCommandHeld( IN_ATTACK ));
	if ( fixButtons )
		return

	const string RCEE_MODNAME = "rcee"
	if ( weapon.HasMod( RCEE_MODNAME ) )
		return

	weapon.AddMod( RCEE_MODNAME )
	weapon.ForceDryfireEvent()
	EmitSoundOnEntity( player, "lstar_lowammowarning" )
	EmitSoundOnEntity( player, "lstar_dryfire" )
}
#endif // #if SERVER

void function OnWeaponActivate_weapon_lstar( entity weapon )
{
	entity owner = weapon.GetOwner()
	if ( !owner.IsPlayer() )
		return

#if SERVER
	CheckForRCEE( weapon, owner )
#endif // #if SERVER
}
