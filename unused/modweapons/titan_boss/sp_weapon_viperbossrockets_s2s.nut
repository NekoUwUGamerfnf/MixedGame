// from sp_s2s.nut. intro require these
#if SERVER
global function ViperCoreThink
const asset VIPER_CORE_EFFECT = $"P_titan_core_atlas_blast"
// from sp_s2s_common.nut. suprisingly respawn can make things work
const vector CONVOYDIR = <0,90,0>

// modified version
global function ViperCoreThink_Once
#endif

global function SPWeaponViperBossRockets_S2S_Init
global function ScriptOnlyWeapon

#if SERVER
global function NPCScriptOnlyWeapon
global function OnWeaponScriptPrimaryAttack_ViperSwarmRockets_s2s
global function OnWeaponScriptAttack_s2s_BossIntro
global function OnWeaponScriptAttack_s2s_ViperDead
global function ViperSwarmRockets_SetupAttackParams
#endif

const VIPERMAXVOLLEY 				= 24

// Non-global structs may not be used in a global context
global struct WeaponViperAttackParams
{
	vector pos
	vector dir
	bool firstTimePredicted
	int burstIndex
	int barrelIndex
	vector relativeDelta
	entity movingGeo
}

const VIPERMISSILE_SFX_LOOP					= "Weapon_Sidwinder_Projectile"
const VIPERMISSILE_MISSILE_SPEED_SCALE				= 1.0
const VIPERMISSILE_MISSILE_SPEED_SCALE_BOSSINTRO	= 1.5
const DEBUG_DRAW_PATH 						= false

void function SPWeaponViperBossRockets_S2S_Init()
{
	// from sp_s2s.nut. intro require these
	#if SERVER
		RegisterSignal( "StopAimingFlightCore" )
	#endif

	PrecacheParticleSystem( $"wpn_mflash_xo_rocket_shoulder_FP" )
	PrecacheParticleSystem( $"wpn_mflash_xo_rocket_shoulder" )
	#if DEV
		RegisterSignal( "DebugMissileTarget" )
	#endif
}

// from sp_s2s.nut. intro require these
#if SERVER
void function ViperCoreThink( entity viper, bool firstTime = false )
{
	/* // sp specific
	if ( Flag( "ViperFakeDead" ) )
		return
	FlagEnd( "ViperFakeDead" )
	viper.EndSignal( "FakeDeath" )
	*/

	// mp specific
	viper.EndSignal( "OnDeath" )
	viper.EndSignal( "OnDestroy" )

	while( 1 )
	{
		/* // sp specific
		if ( Flag( "DeckViperDoingRelocate" ) )
		{
			FlagWaitClear( "DeckViperDoingRelocate" )
			wait 4
		}
		*/

		//play anim
		if ( !firstTime )
		{
			thread ViperDoesCoreAnim( viper )
			thread ViperCoreVO( viper )
		}

		//play tell warning sound and fx
		//EmitSoundOnEntity( file.player, "northstar_rocket_warning" )
		// mp modified version
		foreach ( entity player in GetPlayerArray() )
			EmitSoundOnEntityOnlyToPlayer( viper, player, "northstar_rocket_warning" )
		float launchdelay = 3.0
		SetCoreEffect( viper, CreateCoreEffect, VIPER_CORE_EFFECT )
		thread ViperKillCoreFx( viper, launchdelay + 1.0 )
		wait launchdelay

		// sp specific
		//entity weapon 		= viper.GetOffhandWeapon( 0 )
		// mp modified version
		entity weapon 		= viper.GiveWeapon( "mp_titanweapon_flightcore_rockets" )
		entity enemy 		= ViperGetEnemy( viper )
		vector targetPos 	= viper.GetOrigin()
		if ( IsAlive( enemy ) )
			targetPos 		= enemy.GetOrigin()
		vector dir 			= viper.GetOrigin() - targetPos
		float dist 			= dir.Length()

		targetPos = ViperCoreGetLeadTargetPos( targetPos, dir, dist )
		// sp specific
		//WeaponViperAttackParams	viperParams = ViperSwarmRockets_SetupAttackParams( targetPos, file.malta.mover )
		entity attackRef = viper
		if ( IsValid( viper.GetParent() ) )
			attackRef = viper.GetParent()
		WeaponViperAttackParams	viperParams = ViperSwarmRockets_SetupAttackParams( targetPos, attackRef )

		//EmitSoundOnEntity( file.player, "northstar_rocket_fire" )
		// mp modified version
		foreach ( entity player in GetPlayerArray() )
			EmitSoundOnEntityOnlyToPlayer( viper, player, "northstar_rocket_fire" )

		for( int i = 0; i < VIPERMAXVOLLEY; i++ )
		{
			viperParams.burstIndex = i
			OnWeaponScriptPrimaryAttack_ViperSwarmRockets_s2s( weapon, viperParams )

			wait 0.1

			// mp modified version
			enemy = ViperGetEnemy( viper )
			if ( !IsAlive( enemy ) )
				continue

			//update pos if player is close
			targetPos 	= enemy.GetOrigin()
			dir 		= viper.GetOrigin() - targetPos
			dist 		= dir.Length()
			if ( dist < VIPERCOREMINAIMDIST )
			{
				targetPos = ViperCoreGetLeadTargetPos( targetPos, dir, dist )
				// sp specific
				//viperParams = ViperSwarmRockets_SetupAttackParams( targetPos, file.malta.mover )
				entity attackRef = viper
				if ( IsValid( viper.GetParent() ) )
					attackRef = viper.GetParent()
				ViperSwarmRockets_SetupAttackParams( targetPos, attackRef )
			}
		}

		wait viper.GetSequenceDuration( "lt_npc_flight_core" )
		float lastTime = Time()

		/* // sp specific
		if ( Flag( "DeckViperStage2" ) )
			wait RandomFloatRange( 8, 11 )
		else
		{
			FlagWaitWithTimeout( "DeckViperStage2", RandomFloatRange( 20, 25 ) )
			float deltaTime = Time() - lastTime
			if ( deltaTime < 10 )
				wait 10 - deltaTime
		}
		*/

		firstTime = false

		// mp modified version
		if ( IsValid( weapon ) )
			weapon.Destroy()
		viper.SetActiveWeaponBySlot( 0 )
	}
}

// modified version: only do core ability once
void function ViperCoreThink_Once( entity viper )
{
	// mp specific
	viper.EndSignal( "OnDeath" )
	viper.EndSignal( "OnDestroy" )
	viper.SetInvulnerable() // for mp, want to make them invulnerable on intro core ability

	//play anim
	thread ViperCoreVO( viper )
	thread ViperDoesCoreAnim_Static( viper )

	// mp modified version
	foreach ( entity player in GetPlayerArray() )
		EmitSoundOnEntityOnlyToPlayer( viper, player, "northstar_rocket_warning" )
	float launchdelay = 3.0
	SetCoreEffect( viper, CreateCoreEffect, VIPER_CORE_EFFECT )
	thread ViperKillCoreFx( viper, launchdelay + 1.0 )
	wait launchdelay

	// mp modified version
	entity weapon 		= viper.GiveWeapon( "mp_titanweapon_flightcore_rockets" )
	entity enemy 		= ViperGetEnemy( viper )
	vector targetPos 	= viper.GetOrigin()
	if ( IsAlive( enemy ) )
		targetPos 		= enemy.GetOrigin()
	vector dir 			= viper.GetOrigin() - targetPos
	float dist 			= dir.Length()

	targetPos = ViperCoreGetLeadTargetPos( targetPos, dir, dist )
	entity attackRef = viper
	if ( IsValid( viper.GetParent() ) )
		attackRef = viper.GetParent()
	WeaponViperAttackParams	viperParams = ViperSwarmRockets_SetupAttackParams( targetPos, attackRef )

	//EmitSoundOnEntity( file.player, "northstar_rocket_fire" )
	// mp modified version
	foreach ( entity player in GetPlayerArray() )
		EmitSoundOnEntityOnlyToPlayer( viper, player, "northstar_rocket_fire" )

	for( int i = 0; i < VIPERMAXVOLLEY; i++ )
	{
		viperParams.burstIndex = i
		OnWeaponScriptPrimaryAttack_ViperSwarmRockets_s2s( weapon, viperParams )

		wait 0.1

		// mp modified version
		enemy = ViperGetEnemy( viper )
		if ( !IsAlive( enemy ) )
			continue

		//update pos if player is close
		targetPos 	= enemy.GetOrigin()
		dir 		= viper.GetOrigin() - targetPos
		dist 		= dir.Length()
		if ( dist < VIPERCOREMINAIMDIST )
		{
			targetPos = ViperCoreGetLeadTargetPos( targetPos, dir, dist )
			// sp specific
			//viperParams = ViperSwarmRockets_SetupAttackParams( targetPos, file.malta.mover )
			entity attackRef = viper
			if ( IsValid( viper.GetParent() ) )
				attackRef = viper.GetParent()
			ViperSwarmRockets_SetupAttackParams( targetPos, attackRef )
		}
	}

	// mp modified version
	if ( IsValid( weapon ) )
		weapon.Destroy()
	viper.SetActiveWeaponBySlot( 0 )

	// mp modified version
	viper.ClearInvulnerable()
}

void function ViperKillCoreFx( entity viper, float delay )
{
	// mp adding
	viper.EndSignal( "OnDeath" )
	viper.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function() : ( viper )
			{
				if ( IsValid( viper.GetTitanSoul() ) )
					CleanupCoreEffect( viper.GetTitanSoul() )
			}
		)


	wait delay
}

vector function ViperCoreGetLeadTargetPos( vector targetPos, vector dir, float dist  )
{
	float lead = GraphCapped( dist, 1000, VIPERCOREMINAIMDIST, 0, 600 )
	vector leadTarget = targetPos + ( Normalize( < dir.x, dir.y, 0 > ) * lead )

	return leadTarget
}

const float VIPERCOREMINAIMDIST = 2500
void function ViperDoesCoreAnim( entity viper )
{
	/* // sp specific
	viper.EndSignal( "FakeDeath" )
	if ( Flag( "ViperFakeDead" ) )
		return
	FlagEnd( "ViperFakeDead" )

	FlagSet( "DeckViperDoingCore" )
	*/
	viper.kv.allowshoot = false

	// sp specific
	//thread ViperAimsDuringCoreAnim( viper, Flag( "DeckViperStage2" ) )
	thread ViperAimsDuringCoreAnim( viper, false )

	/* // sp specific
	if ( Flag( "DeckViperStage2" ) )
	{
		entity ref = viper.GetParent()
		waitthread PlayAnim( viper, "s2s_viper_flight_move_2_core", ref )
		thread PlayAnim( viper, "s2s_viper_flight_core_idle", ref )

		wait 5.5

		waitthread PlayAnim( viper, "s2s_viper_flight_core_2_move", ref )
		viper.Signal( "StopAimingFlightCore" )
		thread PlayAnim( viper, "s2s_viper_flight_move_idle", ref )
	}
	else
	{
		entity ref = CreateScriptMover( viper.GetOrigin(), viper.GetAngles() )
		ref.SetParent( file.malta.mover, "", true, 0 )
		viper.SetParent( ref )
		thread PlayAnim( viper, "s2s_viper_flight_core", ref )//lt_npc_flight_core

		float blendTime = 0.5
		ref.NonPhysicsSetMoveModeLocal( true )
		ref.NonPhysicsMoveTo( ref.GetLocalOrigin() + <0,0,4>, blendTime, blendTime * 0.5, blendTime * 0.5 )

		wait blendTime
		thread ViperCoreAnimStaysOutFront( viper, ref )
		ref.NonPhysicsRotateTo( CONVOYDIR * -1, blendTime, blendTime * 0.5, blendTime * 0.5 )

		WaittillAnimDone( viper )
		viper.Signal( "StopAimingFlightCore" )
		viper.ClearParent()
		ViperStuckSolidFailSafe( viper )
		ref.Destroy()
	}
	*/

	// mp modified version
	entity ref = CreateScriptMover( viper.GetOrigin(), viper.GetAngles() )
	//ref.SetParent( file.malta.mover, "", true, 0 )
	viper.SetParent( ref )
	thread PlayAnim( viper, "s2s_viper_flight_core", ref )//lt_npc_flight_core

	float blendTime = 0.5
	ref.NonPhysicsSetMoveModeLocal( true )
	ref.NonPhysicsMoveTo( ref.GetLocalOrigin() + <0,0,4>, blendTime, blendTime * 0.5, blendTime * 0.5 )

	wait blendTime
	thread ViperCoreAnimStaysOutFront( viper, ref )
	ref.NonPhysicsRotateTo( CONVOYDIR * -1, blendTime, blendTime * 0.5, blendTime * 0.5 )

	WaittillAnimDone( viper )
	viper.Signal( "StopAimingFlightCore" )
	viper.ClearParent()
	// sp specific
	//ViperStuckSolidFailSafe( viper )
	ref.Destroy()

	viper.kv.allowshoot = true
	// sp specific
	//FlagClear( "DeckViperDoingCore" )
}

void function ViperDoesCoreAnim_Static( entity viper )
{
	viper.kv.allowshoot = false

	thread ViperAimsDuringCoreAnim( viper, false )

	// mp modified version
	thread PlayAnim( viper, "s2s_viper_flight_core" )//lt_npc_flight_core

	float blendTime = 0.5
	wait blendTime

	WaittillAnimDone( viper )
	viper.Signal( "StopAimingFlightCore" )

	viper.kv.allowshoot = true
	// sp specific
	//FlagClear( "DeckViperDoingCore" )
}

void function ViperCoreAnimStaysOutFront( entity viper, entity ref )
{
	// mp adding
	viper.EndSignal( "OnDeath" )
	viper.EndSignal( "OnDestroy" )
	viper.EndSignal( "StopAimingFlightCore" )
	ref.EndSignal( "OnDestroy" )
	// sp specific
	/*
	viper.EndSignal( "FakeDeath" )
	if ( Flag( "ViperFakeDead" ) )
		return
	FlagEnd( "ViperFakeDead" )
	*/

	float yRange = 900
	float xMax = 12700
	float blendTime = 1.0

	while( 1 )
	{
		WaitFrame()

		float deltaY = ref.GetOrigin().y - ViperGetEnemy( viper ).GetOrigin().y

		if ( deltaY >= yRange )
			continue

		float moveY = deltaY
		if ( moveY < 0 )
			moveY = yRange

		vector newOrigin = ref.GetLocalOrigin() + <moveY,0,0>
		if ( newOrigin.x > xMax )
			newOrigin = <xMax, newOrigin.y, newOrigin.z>

		// mp modified version
		entity mover = viper.GetParent()

		//getlocal origin gives a different value than 	GetRelativeDelta
		vector fixDelta = < -newOrigin.y, newOrigin.x, newOrigin.z >
		//vector worldOrigin = GetWorldOriginFromRelativeDelta( fixDelta, file.malta.mover )
		// mp modified version
		vector worldOrigin = GetWorldOriginFromRelativeDelta( fixDelta, viper )
		if ( IsValid( mover ) )
			vector worldOrigin = GetWorldOriginFromRelativeDelta( fixDelta, mover )

		//vector up = file.malta.mover.GetUpVector()
		// mp modified version
		vector up = viper.GetUpVector()
		if ( IsValid( mover ) )
			up = mover.GetUpVector()
		array<entity> ignore = GetNPCArrayByClass( "npc_titan" )
		//ignore.append( file.player )
		ignore.extend( GetPlayerArray() )
		TraceResults traceResult = TraceLine( worldOrigin + ( up * 100 ), worldOrigin + ( up * -1000 ), ignore, TRACE_MASK_TITANSOLID, TRACE_COLLISION_GROUP_NONE )

		if ( traceResult.fraction < 1.0 )
			worldOrigin = traceResult.endPos + ( up * 4 )

		//vector relDelta = GetRelativeDelta( worldOrigin, file.malta.mover )
		vector relDelta = GetRelativeDelta( worldOrigin, viper )
		if ( IsValid( mover ) )
			relDelta = GetRelativeDelta( worldOrigin, mover )
		vector finalLoc = < relDelta.y, -relDelta.x, relDelta.z >

		ref.NonPhysicsMoveTo( finalLoc, blendTime, 0, blendTime * 0.25 )
	}
}

void function ViperAimsDuringCoreAnim( entity viper, bool dontCheckRange )
{
	// sp specific
	/*
	if ( Flag( "ViperFakeDead" ) )
		return
	FlagEnd( "ViperFakeDead" )
	*/

	// mp adding
	viper.EndSignal( "OnDeath" )
	viper.EndSignal( "OnDestroy" )

	viper.Signal( "StopAimingFlightCore" )

	int yawID 	= viper.LookupPoseParameterIndex( "aim_yaw_scripted" )
	int pitchID = viper.LookupPoseParameterIndex( "aim_pitch_scripted" )
	float blendTime = 0.5
	float dist = -999

	OnThreadEnd(
	function() : ( viper, yawID, pitchID, blendTime )
		{
			viper.SetPoseParameterOverTime( yawID, 0, blendTime )
			viper.SetPoseParameterOverTime( pitchID, 0, blendTime )
		}
	)

	while( 1 )
	{
		// mp modified version
		entity enemy = ViperGetEnemy( viper )
		if ( !IsAlive( enemy ) )
		{
			WaitFrame()
			continue
		}

		vector start 	= viper.GetOrigin()
		vector end 		= enemy.GetOrigin()

		if ( dist < VIPERCOREMINAIMDIST || dontCheckRange )
		{
			vector dir 		= Normalize( end - start )
			vector angles  	= VectorToAngles( dir )
			vector localAng = angles - <0,270,0>

			float deltaX 	= end.x - start.x
			float deltaY 	= end.y - start.y

			float yaw 	= GraphCapped( localAng.y, -90, 90, -45, 45 )
			float pitch = GraphCapped( localAng.x, -30, 30, -30, 30 )

			viper.SetPoseParameterOverTime( yawID, yaw, blendTime )
			viper.SetPoseParameterOverTime( pitchID, pitch, blendTime )
		}

		dist = Distance( start, end )

		WaitFrame()
	}
}

entity function ViperGetEnemy( entity viper )
{
	if ( viper.GetEnemy() )
		return viper.GetEnemy()

	entity closestPlayer
	if ( GetPlayerArray_Alive().len() < 1 )
		return null
	closestPlayer = GetClosest( GetPlayerArray_Alive(), viper.GetOrigin() )

	entity enemy = closestPlayer.GetPetTitan()
	if ( enemy == null )
		enemy = closestPlayer

	return enemy
}

void function ViperCoreVO( entity viper )
{
	/* // sp specific
	viper.EndSignal( "OnDeath" )
	file.player.EndSignal( "OnDeath" )
	viper.EndSignal( "FakeDeath" )
	if ( Flag( "ViperFakeDead" ) )
		return
	FlagEnd( "ViperFakeDead" )
	*/
	// mp adding
	viper.EndSignal( "OnDeath" )
	viper.EndSignal( "OnDestroy" )

	wait 2.0

	// sp specific
	//Remote_CallFunction_NonReplay( file.player, "ServerCallback_BossTitanUseCoreAbility", viper.GetEncodedEHandle(), GetTitanCurrentRegenTab( viper ) )
	// mp modified version
	MpBossTitan_ConversationUseCoreAbility( viper )
}
#endif // SERVER

var function ScriptOnlyWeapon( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	//not meant for player use
	return
}

#if SERVER
var function OnWeaponScriptPrimaryAttack_ViperSwarmRockets_s2s( entity weapon, WeaponViperAttackParams viperParams )
{
	#if DEV
		if ( GetBugReproNum() == 101 )
			return
	#endif

	entity owner = weapon.GetWeaponOwner()
	vector origin 	= GetWorldOriginFromRelativeDelta( viperParams.relativeDelta, viperParams.movingGeo )
	WeaponPrimaryAttackParams attackParams = PlayViperMissileFX( owner, weapon, viperParams.burstIndex, origin )

	entity missile = weapon.FireWeaponMissile( attackParams.pos, attackParams.dir, VIPERMISSILE_MISSILE_SPEED_SCALE, DF_GIB | DF_IMPACT, damageTypes.explosive, false, PROJECTILE_NOT_PREDICTED )
	InitMissile( missile, owner )

	thread HomingMissileThink( weapon, missile, viperParams )
}

void function OnWeaponScriptAttack_s2s_BossIntro( entity weapon, int burstIndex, entity target, vector offset, float homingSpeedScalar = 1.0, float missileSpeedScalar = 1.0 )
{
	entity owner = weapon.GetWeaponOwner()
	WeaponPrimaryAttackParams attackParams = PlayViperMissileFX( owner, weapon, burstIndex, target.GetOrigin() )

	entity missile = weapon.FireWeaponMissile( attackParams.pos, attackParams.dir, VIPERMISSILE_MISSILE_SPEED_SCALE_BOSSINTRO * missileSpeedScalar, DF_GIB | DF_IMPACT, damageTypes.explosive, false, PROJECTILE_NOT_PREDICTED )
	missile.DisableHibernation()
	InitMissileBossIntro( missile, owner )

	thread HomingMissileThinkTarget( weapon, missile, target, offset, homingSpeedScalar )
}

void function OnWeaponScriptAttack_s2s_ViperDead( entity weapon, int burstIndex, entity target, vector offset, float homingSpeedScalar = 1.0, float missileSpeedScalar = 1.0 )
{
	entity owner = weapon.GetWeaponOwner()
	WeaponPrimaryAttackParams attackParams = PlayViperMissileFXHigh( owner, weapon, burstIndex, target.GetOrigin() )

	entity missile = weapon.FireWeaponMissile( attackParams.pos, attackParams.dir, VIPERMISSILE_MISSILE_SPEED_SCALE_BOSSINTRO * missileSpeedScalar, DF_GIB | DF_IMPACT, damageTypes.explosive, false, PROJECTILE_NOT_PREDICTED )
	InitMissileBossIntro( missile, owner )

	delaythread( 0.3 ) HomingMissileThinkTargetLate( weapon, missile, target, offset, homingSpeedScalar )
}

void function InitMissile( entity missile, entity owner )
{
	missile.SetOwner( owner )
	missile.DamageAliveOnly( true )
	missile.kv.lifetime = RandomFloatRange( 4.0, 6.0 )
	SetTeam( missile, owner.GetTeam() )

	EmitSoundOnEntity( missile, VIPERMISSILE_SFX_LOOP )
}

void function InitMissileBossIntro( entity missile, entity owner )
{
	missile.SetOwner( owner )
	missile.DamageAliveOnly( true )
	missile.kv.lifetime = RandomFloatRange( 8.0, 10.0 )
	SetTeam( missile, owner.GetTeam() )

	EmitSoundOnEntity( missile, VIPERMISSILE_SFX_LOOP )
}

WeaponPrimaryAttackParams function PlayViperMissileFXHigh( entity owner, entity weapon, int burstIndex, vector origin )
{
	int fxId 			= GetParticleSystemIndex( $"wpn_mflash_xo_rocket_shoulder" )
	string attachment 	= IsEven( burstIndex ) ? "SCRIPT_POD_L" : "SCRIPT_POD_R"
	int attachId 		= owner.LookupAttachment( attachment )

	int adjustIndex = burstIndex
	float range = 45.0
	float add = 7.0
	float interval = ( range / VIPERMAXVOLLEY.tofloat() )

	if ( burstIndex > 0 && IsOdd( burstIndex ) )
	{
		adjustIndex = ( burstIndex - 1 ) * -1
		add *= -1
	}

	float degree = ( adjustIndex + add ) * interval
	vector angles = < 0,degree,0 >

	vector finalVec = AnglesToForward( AnglesCompose( owner.GetAttachmentAngles( attachId ), angles ) )
	//vector finalVec = AnglesToForward( AnglesCompose( < -90, 90, 0 >, angles ) )

	StartParticleEffectOnEntity( owner, fxId, FX_PATTACH_POINT_FOLLOW, attachId )
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	WeaponPrimaryAttackParams attackParams

	attackParams.pos = owner.GetAttachmentOrigin( attachId )
	attackParams.dir = finalVec

	return attackParams
}

WeaponPrimaryAttackParams function PlayViperMissileFX( entity owner, entity weapon, int burstIndex, vector origin )
{
	int fxId 			= GetParticleSystemIndex( $"wpn_mflash_xo_rocket_shoulder" )
	string attachment 	= IsEven( burstIndex ) ? "SCRIPT_POD_R" : "SCRIPT_POD_L"
	int attachId 		= owner.LookupAttachment( attachment )

	int adjustIndex = burstIndex
	float range = 45.0
	float add = 7.0
	float interval = ( range / VIPERMAXVOLLEY.tofloat() )

	if ( burstIndex > 0 && IsEven( burstIndex ) )
	{
		adjustIndex = ( burstIndex - 1 ) * -1
		add *= -1
	}

	float degree = ( adjustIndex + add ) * interval
	vector angles = < 0,degree,0 >


	float distMin 	= pow( 1000, 2 )
	float distMax 	= pow( 2500, 2 )
	float distSqr 	= DistanceSqr( origin, owner.GetOrigin() )

	float launchFrac = GraphCapped( distSqr, distMin, distMax, 0, 1.0 )
	float attackFrac = 1.0 - launchFrac

	vector launchVec = AnglesToForward( AnglesCompose( owner.GetAttachmentAngles( attachId ), angles ) )
	vector attackVec = Normalize( origin - owner.GetOrigin() )
	vector finalVec = ( launchVec * launchFrac ) + ( attackVec * attackFrac )

	StartParticleEffectOnEntity( owner, fxId, FX_PATTACH_POINT_FOLLOW, attachId )
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	WeaponPrimaryAttackParams attackParams

	attackParams.pos = owner.GetAttachmentOrigin( attachId )
	attackParams.dir = finalVec

	return attackParams
}

void function HomingMissileThinkTarget( entity weapon, entity missile, entity target, vector offset, float homingSpeedScalar )
{
	Assert( IsValid( missile ) )

	missile.EndSignal( "OnDestroy" )
	missile.EndSignal( "OnDeath" )

	missile.SetMissileTarget( target, offset )

	float timeMin = 0
	float timeMax = 3
	float timeStart = Time()
	float speedMin = 75
	float speedMax = 150

	while( 1 )
	{
		float deltaTime = Time() - timeStart
		float value = GraphCapped( deltaTime, timeMin, timeMax, speedMin, speedMax ) * homingSpeedScalar

		missile.SetHomingSpeeds( value, 0 )

		wait 0.2

		if ( value == speedMax )
			return
	}
}

void function HomingMissileThinkTargetLate( entity weapon, entity missile, entity target, vector offset, float homingSpeedScalar )
{
	if ( !IsValid( missile ) )
		return

	missile.EndSignal( "OnDestroy" )
	missile.EndSignal( "OnDeath" )

	missile.SetMissileTarget( target, offset )

	missile.SetHomingSpeeds( 150 * homingSpeedScalar, 0 )
}

void function HomingMissileThink( entity weapon, entity missile, WeaponViperAttackParams viperParams )
{
	Assert( IsValid( missile ) )
	if ( !IsValid( viperParams.movingGeo ) )
		return

	viperParams.movingGeo.EndSignal( "OnDestroy" )
	missile.EndSignal( "OnDestroy" )
	missile.EndSignal( "OnDeath" )

	missile.SetHomingSpeeds( 50, 0 )

	vector origin 		= GetWorldOriginFromRelativeDelta( viperParams.relativeDelta, viperParams.movingGeo )
	vector dir 			= missile.GetOrigin() - origin
	vector baseAngles 	= FlattenAngles( VectorToAngles( Normalize( dir ) ) )

	bool playedIncomingSound = false
	while( 1 )
	{
		vector origin 	= GetWorldOriginFromRelativeDelta( viperParams.relativeDelta, viperParams.movingGeo )
		vector vec1 	= origin - missile.GetOrigin()
		float dist 		= vec1.Length()
		vector offset 	= <0,0,0>

		if ( DotProduct( Normalize( vec1 ), <0,90,0> ) < 0.0 )
		{
			vector angles 	= baseAngles

			//always pitch up
			float x = RandomFloatRange( -45, -90 )
			float y = RandomFloatRange( -45, 45 )

			angles = AnglesCompose( angles, < -20,0,0 > )
			angles = AnglesCompose( angles, <0,y,0> )

			dir = AnglesToForward( angles )
			float mag = GraphCapped( dist, 500, 5000, 0, 0.5 )
			offset = dir * ( dist * mag )
		}

		if ( dist < 2500 && !playedIncomingSound )
		{
			EmitSoundAtPosition( TEAM_ANY, origin, "northstar_rocket_flyby" )
			playedIncomingSound = true
		}

		missile.SetMissileTargetPosition( origin + offset )

		#if DEV
			thread DebugMissileTarget( missile, origin, offset )
		#endif

		wait RandomFloatRange( 0.25, 0.5 )
	}
}
#if DEV
void function DebugMissileTarget( entity missile, vector origin, vector offset )
{
	missile.Signal( "DebugMissileTarget" )

	missile.EndSignal( "OnDestroy" )
	missile.EndSignal( "DebugMissileTarget" )

	int r = RandomIntRange( 100, 255 )
	int g = RandomIntRange( 100, 255 )
	int b = RandomIntRange( 100, 255 )
	while( 1 )
	{
		WaitFrame()

		if ( GetBugReproNum() != 5 )
			continue
		DebugDrawLine( origin + offset, origin, 255,0,0, true, 0.1 )
		DebugDrawLine( origin + offset, missile.GetOrigin(), r, g, b, true, 0.1 )
		DebugDrawCircle( origin + offset, <0,0,0>, 8, r, g, b, true, 0.1, 4 )
	}
}
#endif

WeaponViperAttackParams function ViperSwarmRockets_SetupAttackParams( vector targetPos, entity movingGeo )
{
	WeaponViperAttackParams viperParams

	viperParams.relativeDelta 	= GetRelativeDelta( targetPos, movingGeo )
	viperParams.movingGeo 		= movingGeo

	return viperParams
}

var function NPCScriptOnlyWeapon( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	//if the AI tries to call - return
	return
}

#endif