global function OnWeaponActivate_titancore_storm_wave
global function MpTitanWeaponStormWave_Init

global function OnAbilityCharge_StormWave
global function OnAbilityChargeEnd_StormWave

global function OnWeaponPrimaryAttack_titancore_storm_wave



const float PROJECTILE_SEPARATION = 128
const float FLAME_WALL_MAX_HEIGHT = 110
const asset FLAME_WAVE_IMPACT_TITAN = $"P_impact_exp_med_metal"
const asset FLAME_WAVE_IMPACT 		= $"P_impact_exp_xsmll_metal"
const asset FLAMEWAVE_EFFECT 		= $"P_wpn_meteor_wave"
const asset FLAMEWAVE_EFFECT_CONTROL = $"P_wpn_meteor_waveCP"

const string FLAME_WAVE_LEFT_SFX = "flamewave_blast_left"
const string FLAME_WAVE_MIDDLE_SFX = "flamewave_blast_middle"
const string FLAME_WAVE_RIGHT_SFX = "flamewave_blast_right"

void function MpTitanWeaponStormWave_Init()
{
	PrecacheParticleSystem( FLAME_WAVE_IMPACT_TITAN )
	PrecacheParticleSystem( FLAME_WAVE_IMPACT )
	PrecacheParticleSystem( FLAMEWAVE_EFFECT )
	PrecacheParticleSystem( FLAMEWAVE_EFFECT_CONTROL )

	#if SERVER
		// adding a new damageSourceId. it's gonna transfer to client automatically
	    RegisterWeaponDamageSource( "mp_titancore_storm_core", "Storm Core" )

		//AddDamageCallbackSourceID( eDamageSourceId.mp_titancore_storm_core, StormWave_DamagedPlayerOrNPC )
	
		//prevent player earning coremeter by storm core 
		GameModeRulesRegisterTimerCreditException( eDamageSourceId.mp_titancore_storm_core )
	#endif
}

void function OnWeaponActivate_titancore_storm_wave( entity weapon )
{
	// debug
	//print( "RUNNING OnWeaponActivate_titancore_storm_wave()" )

	weapon.EmitWeaponSound_1p3p( "flamewave_start_1p", "flamewave_start_3p" )
	OnAbilityCharge_TitanCore( weapon )
}


bool function OnAbilityCharge_StormWave( entity weapon )
{
	#if SERVER
		entity owner = weapon.GetWeaponOwner()
		float chargeTime = weapon.GetWeaponSettingFloat( eWeaponVar.charge_time )
		entity soul = owner.GetTitanSoul()
		if ( soul == null )
			soul = owner
		StatusEffect_AddTimed( owner, eStatusEffect.move_slow, 0.6, chargeTime, 0 )
		StatusEffect_AddTimed( owner, eStatusEffect.dodge_speed_slow, 0.6, chargeTime, 0 )
		StatusEffect_AddTimed( owner, eStatusEffect.emp, 0.05, chargeTime*1.5, 0.35 )
		//StatusEffect_AddTimed( soul, eStatusEffect.damageAmpFXOnly, 1.0, chargeTime, 0 )

		if ( owner.IsPlayer() )
			owner.SetTitanDisembarkEnabled( false )
		else
			owner.Anim_ScriptedPlay( "at_antirodeo_anim_fast" )
	#endif

	return true
}

void function OnAbilityChargeEnd_StormWave( entity weapon )
{
	#if SERVER
		entity owner = weapon.GetWeaponOwner()
		if ( owner.IsPlayer() )
			owner.SetTitanDisembarkEnabled( true )
		OnAbilityChargeEnd_TitanCore( weapon )

		if ( owner.IsPlayer() )
		{
			owner.Server_TurnOffhandWeaponsDisabledOff() // may need a little fix for animation
			HandlePlayerStormCoreAnim( owner )
		}

		// atlas npc titans can't use storm core properly, adding fix
		if ( owner.IsNPC() && IsAlive( owner ) )
			HandleNPCTitanStormCoreUsage( owner, weapon )

	#endif // #if SERVER
}

var function OnWeaponPrimaryAttack_titancore_storm_wave( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// debug
	//print( "RUNNING OnWeaponPrimaryAttack_titancore_storm_wave()" )

	OnAbilityStart_TitanCore( weapon )

	#if CLIENT
    	ClientScreenShake( 4.0, 5.0, 5.0, Vector( 0.0, 0.0, 0.0 ) )
  	#endif

	#if SERVER
	OnAbilityEnd_TitanCore( weapon )
	#endif
	bool shouldPredict = weapon.ShouldPredictProjectiles()
	#if CLIENT
		if ( !shouldPredict )
			return 1
	#endif


	#if SERVER
		weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.5 )
      	FireStormBall( weapon, attackParams.pos, attackParams.dir, shouldPredict)
	#elseif CLIENT
		ClientScreenShake( 8.0, 10.0, 1.0, Vector( 0.0, 0.0, 0.0 ) )
	#endif

	return 1
}

#if SERVER
void function HandleNPCTitanStormCoreUsage( entity npc, entity weapon )
{
	// for titan pick: atlas titans don't have proper anim event for core usage
	if ( !ShouldFixAnimForTitan( npc ) )
		return

	// build fake attack params
	vector attackPos = npc.EyePosition()
	int attachId = -1
	if ( npc.LookupAttachment( "CHESTFOCUS" ) > 0 )
		attachId = npc.LookupAttachment( "CHESTFOCUS" )
	else if ( npc.LookupAttachment( "PROPGUN" ) > 0 )
		attachId = npc.LookupAttachment( "PROPGUN" )

	if ( attachId > 0 )
		attackPos = npc.GetAttachmentOrigin( attachId )

	vector attackDir = npc.GetForwardVector()
	attachId = -1
	if ( npc.LookupAttachment( "PROPGUN" ) > 0 )
		attachId = npc.LookupAttachment( "PROPGUN" )

	if ( attachId > 0 )
	{
		attackDir = npc.GetAttachmentAngles( attachId )
		attackDir.x = -20 // move up attack angle a little bit
		attackDir.z = 0
		attackDir = AnglesToForward( attackDir )
	}

	WeaponPrimaryAttackParams npcAttackParams
	npcAttackParams.pos = attackPos
	npcAttackParams.dir = attackDir

	// remove core frac
	entity soul = npc.GetTitanSoul()
	SoulTitanCore_SetExpireTime( soul, Time() )
	SoulTitanCore_SetNextAvailableTime( soul, 0.0 )
	// run primaryattack function
	OnWeaponPrimaryAttack_titancore_storm_wave( weapon, npcAttackParams )
	// stop animation after delay
	thread StopOffhandAnimationAfterDelay( npc, 0.8 ) // give anim a little time( 0.8s )
}

void function HandlePlayerStormCoreAnim( entity player )
{
	// for titan pick: atlas titans don't have proper anim event for core usage
	if ( !ShouldFixAnimForTitan( player ) )
		return

	thread StopOffhandAnimationAfterDelay( player, 0.5 ) // give anim a little time( 0.5s )
}

bool function ShouldFixAnimForTitan( entity titan )
{
	if ( !titan.IsTitan() )
		return false
	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) )
		return false
	string titanType = GetSoulTitanSubClass( soul )
	if ( titanType != "atlas" ) // only atlas titans can't recover from animation
		return false

	// all checks passes
	return true
}

void function StopOffhandAnimationAfterDelay( entity titan, float delay )
{
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )
	if ( titan.IsPlayer() ) // player specific: no need to fix anim if they disembark
    	titan.EndSignal( "DisembarkingTitan" )

	wait delay
	if ( titan.IsPlayer() )
		titan.Anim_StopGesture( 0 )
	else
		titan.Anim_Stop()
}
#endif
