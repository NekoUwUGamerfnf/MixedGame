untyped
#if SERVER && MP
global function EndFakePhase
global function StartFakePhase
global function ProwlerHunt_Init


//////introfunc
global function ProwlerHunt
global function spectreswarm
global function AshIntro
global function RichterIntro//missinganim
global function KaneIntro//missinganim
global function BossIntro
global function SloneIntro
global function ViperIntro//
global function ViperReturn//

//melee event
global function SpectreRip
#endif






















#if SERVER && MP


void function ProwlerHunt_Init()
{
	//used signals
	RegisterSignal("AshEnteredPhaseShift")
	RegisterSignal("aiskit_forcedeathonskitend")
	RegisterSignal("aiskit_doomed")
	RegisterSignal("aiskit_dontbreakout")
	RegisterSignal("DoCore")


	//ai melee event
	AddDamageCallbackSourceID( eDamageSourceId.spectre_melee, SpectreRip )
    AddDamageCallbackSourceID( eDamageSourceId.prowler_melee, ProwlerRip )



}






































void function ProwlerHunt( entity attacker , entity target )
{
	thread ProwlerHunt_threaded( attacker , target )
}
void function AshIntro( entity titan )
{
	thread AshIntro_threaded( titan )
}
void function RichterIntro( entity titan )
{
	thread RichterIntro_threaded( titan )
}
void function KaneIntro( entity titan )
{
	thread KaneIntro_threaded( titan )
}
void function BossIntro( entity titan )
{
	thread BossIntro_threaded( titan )
}
void function SloneIntro( entity titan )
{
	thread SloneIntro_threaded( titan )
	thread mardershit( titan )
}
void function ViperIntro( entity titan )
{
	thread ViperIntro_threaded( titan )
}
void function ViperReturn( entity titan )
{
	thread ViperReturn_threaded( titan )
}












void function ViperReturn_threaded( entity viper )
{
	/*hread PlayAnim( bt, "bt_s2s_viper_returns_throw_setup_idle")
	FlagWait( "TackleReadyForFastball" )

	waitthread PlayAnim( bt, "bt_s2s_viper_returns_throw_setup_end")
	thread PlayAnim( bt, "bt_s2s_viper_returns_fastball_idle" )*/
	string squadName = MakeSquadName( 2, UniqueString( "ZiplineTable" ) )

    entity bt = CreateNPC( "npc_titan", 2, viper.GetOrigin() , viper.GetAngles())
    SetSpawnOption_AISettings( bt, "npc_titan_buddy")
    SetSpawnOption_NPCTitan( bt, TITAN_HENCH )
    bt.ai.titanSpawnLoadout.setFile = "titan_buddy"
    OverwriteLoadoutWithDefaultsForSetFile( bt.ai.titanSpawnLoadout )
    DispatchSpawn( bt )
    SetSquad( bt, squadName )






	thread PlayAnim( bt, 	"bt_s2s_viper_returns_start"  )
	waitthread PlayAnim( viper, "lt_s2s_viper_returns_start"  )
	thread PlayAnim( bt, 	"bt_s2s_viper_returns_middle"  )
	thread PlayAnim( viper, "lt_s2s_viper_returns_middle"  )
	wait 1.5
	thread PlayAnim( bt, 	"bt_s2s_viper_returns_end" )
	waitthread PlayAnim( viper, "lt_s2s_viper_returns_end" )
	bt.Destroy()
}
void function ViperIntro_threaded( entity titan )
{
	thread PlayAnim( titan , "lt_s2s_boss_intro" )
}
void function SloneIntro_threaded( entity titan )
{
	entity slone = CreateNPC( "npc_pilot_elite", titan.GetTeam(), titan.GetOrigin() , titan.GetAngles())
	entity blisk = CreateNPC( "npc_pilot_elite", titan.GetTeam(), titan.GetOrigin() , titan.GetAngles())
	//entity marder = CreateNPC( "npc_pilot_elite", titan.GetTeam(), titan.GetOrigin() , titan.GetAngles())
	entity legion = CreateNPCTitan( "npc_titan_ogre", 3, titan.GetOrigin() , titan.GetAngles() ,[])
	SetSpawnOption_AISettings( legion , "npc_titan_ogre_minigun" )
	HideName(blisk)
	HideName(slone)
	//HideName(marder)
	HideName(legion)
	DispatchSpawn(slone)
	DispatchSpawn(blisk)
	//DispatchSpawn(marder)
	DispatchSpawn(legion)
	TakePrimaryWeapon(slone)
	TakePrimaryWeapon(blisk)
	blisk.SetModel($"models/humans/heroes/imc_hero_blisk.mdl")
	//marder.SetModel($"models/humans/heroes/imc_hero_marder.mdl")
    thread PlayAnim( titan , "mt_injectore_room_slone" )
	thread PlayAnim( blisk , "pt_injectore_room_blisk" )
	thread PlayAnim( slone , "pt_injectore_room_slone" )
	thread PlayAnim( legion , "ht_injectore_room_blisk" )
	//thread PlayAnim( marder , "pt_injectore_room_villain" )
	float duration = titan.GetSequenceDuration( "mt_injectore_room_slone" )
	wait duration
	blisk.Destroy()
	slone.Destroy()
	legion.Destroy()
}
void function mardershit(entity titan)
{
	//entity marder = CreateNPC( "npc_pilot_elite", titan.GetTeam(), titan.GetOrigin() - <0,0,120> , titan.GetAngles())
	//HideName(marder)
	//DispatchSpawn(marder)
	//TakePrimaryWeapon(marder)
	//marder.SetModel($"models/humans/heroes/imc_hero_marder.mdl")
	entity marder = CreatePropDynamic( $"models/humans/heroes/imc_hero_marder.mdl", titan.GetOrigin() , titan.GetAngles(), 0 ) // 0 = no collision
	marder.SetSkin( 1 )
	int attachIndex = marder.LookupAttachment( "CHESTFOCUS" )
	StartParticleEffectOnEntity( marder, GetParticleSystemIndex( GHOST_TRAIL_EFFECT ), FX_PATTACH_POINT_FOLLOW, attachIndex )
	StartParticleEffectOnEntity( marder, GetParticleSystemIndex( GHOST_FLASH_EFFECT ), FX_PATTACH_POINT, attachIndex )
	EmitSoundOnEntity( marder, "skyway_scripted_hologram_loop" )
	entity mover = CreateScriptMover( titan.GetOrigin() - <0,0,100>, titan.GetAngles() )
	waitthread PlayAnim( marder , "pt_injectore_room_villain" , mover )
	mover.Destroy()
	EmitSoundOnEntity( marder, "skyway_scripted_hologram_end" )
	marder.Dissolve( ENTITY_DISSOLVE_CHAR, < 0, 0, 0 >, 0 )
}
void function BossIntro_threaded( entity titan )
{
	entity pilot
	pilot = CreateNPC( "npc_pilot_elite", titan.GetTeam(), titan.GetOrigin() , titan.GetAngles())
	HideName(pilot)
	DispatchSpawn( pilot )
	thread PlayAnim(titan , "mt_beacon_boss_intro" )
	thread PlayAnim(pilot , "pt_beacon_boss_intro" )
	float duration = titan.GetSequenceDuration( "mt_beacon_boss_intro" )
	wait duration + 0.5
	pilot.Destroy()
}
void function KaneIntro_threaded( entity titan )
{
	//Kane broken
	//entity pilotKane = CreateNPC( "npc_pilot_elite", titan.GetTeam(), titan.GetOrigin() , titan.GetAngles())
	entity pilot = CreateNPC( "npc_pilot_elite", titan.GetTeam(), titan.GetOrigin() , titan.GetAngles())
	entity victimtitan = CreateNPCTitan( "npc_titan_atlas", 3, titan.GetOrigin() , titan.GetAngles() ,[])
	SetSpawnOption_NPCTitan( victimtitan, TITAN_HENCH )
	SetSpawnOption_AISettings( victimtitan , "npc_titan_atlas_tracker" )
	SetSpawnOption_NPCTitan( victimtitan, TITAN_HENCH )

	HideName(pilot)
	//HideName(pilotKane)
	HideName(victimtitan)
	//pilotKane.SetParent( titan, "HIJACK" )
	DispatchSpawn( pilot )
	//DispatchSpawn( pilotKane )
	DispatchSpawn( victimtitan )
	//pilotKane.Anim_ScriptedPlay("pt_sewers_boss_intro")
	//pilotKane.Anim_EnableUseAnimatedRefAttachmentInsteadOfRootMotion()

	//thread PlayAnim(pilotKane , "pt_sewers_boss_intro" )
	thread PlayAnim(titan , "ht_Kane_boss_intro_ht" )
	thread PlayAnim(pilot , "pt_Kane_boss_intro_pilot" )
	thread PlayAnim(victimtitan , "mt_Kane_boss_intro_mt" )
	float duration = titan.GetSequenceDuration( "ht_Kane_boss_intro_ht" )
	wait duration + 0.5
	//pilotKane.Destroy()
	pilot.Destroy()
	victimtitan.Destroy()
}
void function RichterIntro_threaded( entity titan )
{
	entity pilot = CreateNPC( "npc_pilot_elite", titan.GetTeam(), titan.GetOrigin() , titan.GetAngles())
	HideName(pilot)
	pilot.SetParent( titan, "HIJACK" )
	DispatchSpawn( pilot )
	thread PlayAnim(titan , "mt_richter_taunt_mt" )
	//pilot.Anim_ScriptedPlay("pt_ht_boss_intro")
	//pilot.Anim_EnableUseAnimatedRefAttachmentInsteadOfRootMotion()
	//pilot.SetOrigin(titan.GetOrigin() - <0,0,90>)
	//float anim1duration = pilot.GetSequenceDuration( "pt_ht_boss_intro" )
	//wait anim1duration
	//pilot.SetOrigin(titan.GetOrigin())
	pilot.Anim_ScriptedPlay("pt_mount_idle")
	pilot.Anim_EnableUseAnimatedRefAttachmentInsteadOfRootMotion()
	float duration = titan.GetSequenceDuration( "mt_richter_taunt_mt" )
	wait duration + 0.5
	pilot.Destroy()
}

void function AshIntro_threaded( entity titan )
{
	entity pilot = CreateNPC( "npc_pilot_elite", titan.GetTeam(), titan.GetOrigin() , titan.GetAngles())
	pilot.SetModel($"models/humans/heroes/imc_hero_ash.mdl")
	HideName(pilot)
	DispatchSpawn( pilot )
	pilot.SetModel($"models/humans/heroes/imc_hero_ash.mdl")
	//pilot.Anim_ScriptedPlay("pt_boomtown_boss_intro")
	//pilot.Anim_EnableUseAnimatedRefAttachmentInsteadOfRootMotion()
	thread PlayAnim(titan , "lt_boomtown_boss_intro" )
	thread PlayAnim(pilot , "pt_boomtown_boss_intro" )
	float duration = pilot.GetSequenceDuration( "pt_boomtown_boss_intro" )
	wait duration - 0.7
	PhaseShift( titan , 0 , 2 )
	pilot.Destroy()
}

void function spectreswarm( entity titan )
{
	entity spectre1 = CreateNPC( "npc_spectre", 2, titan.GetOrigin() , titan.GetAngles())
	entity spectre2 = CreateNPC( "npc_spectre", 2, titan.GetOrigin() , titan.GetAngles())
	entity spectre3 = CreateNPC( "npc_spectre", 2, titan.GetOrigin() , titan.GetAngles())
	entity spectre4 = CreateNPC( "npc_spectre", 2, titan.GetOrigin() , titan.GetAngles())
	entity spectre5 = CreateNPC( "npc_spectre", 2, titan.GetOrigin(), titan.GetAngles())
	entity spectre6 = CreateNPC( "npc_spectre", 2, titan.GetOrigin(), titan.GetAngles())
	DispatchSpawn( spectre1 )
	DispatchSpawn( spectre2 )
	DispatchSpawn( spectre3 )
	DispatchSpawn( spectre4 )
	DispatchSpawn( spectre5 )
	DispatchSpawn( spectre6 )
	spectre1.SetParent( titan, "HIJACK" )
	spectre2.SetParent( titan, "HIJACK" )
	spectre3.SetParent( titan, "HIJACK" )
	spectre4.SetParent( titan, "HIJACK" )
	spectre1.MarkAsNonMovingAttachment()
	spectre2.MarkAsNonMovingAttachment()
	spectre3.MarkAsNonMovingAttachment()
	spectre4.MarkAsNonMovingAttachment()
	spectre1.Anim_ScriptedPlay("sp_titan_spectre_swarm")
	spectre2.Anim_ScriptedPlay("sp_titan_spectre_swarm_2")
	spectre3.Anim_ScriptedPlay("sp_titan_spectre_swarm_3")
	spectre4.Anim_ScriptedPlay("sp_titan_spectre_swarm_4")
	spectre1.Anim_EnableUseAnimatedRefAttachmentInsteadOfRootMotion()
	spectre2.Anim_EnableUseAnimatedRefAttachmentInsteadOfRootMotion()
	spectre3.Anim_EnableUseAnimatedRefAttachmentInsteadOfRootMotion()
	spectre4.Anim_EnableUseAnimatedRefAttachmentInsteadOfRootMotion()
	/*thread PlayAnim( spectre1 , "sp_titan_spectre_swarm" )
	thread PlayAnim( spectre2 , "sp_titan_spectre_swarm_2" )
	thread PlayAnim( spectre3 , "sp_titan_spectre_swarm_3" )
	thread PlayAnim( spectre4 , "sp_titan_spectre_swarm_4" )*/
    thread PlayAnim( spectre5 , "sp_titan_spectre_swarm_groundA" )
	thread PlayAnim( spectre6 , "sp_titan_spectre_swarm_groundB" )
	thread PlayAnim( titan , "at_titan_spectre_swarm" )
}

void function ProwlerHunt_threaded( entity attacker , entity target )
{
	entity wolf = CreateNPC( "npc_prowler", attacker.GetTeam(), target.GetOrigin(), target.GetAngles())
	wolf.SetBossPlayer( attacker )
	MakeInvincible( wolf )
	MakeInvincible( target )
	DispatchSpawn( wolf )
	wolf.kv.visibilityFlags = ENTITY_VISIBLE_TO_NOBODY
	EndFakePhase( wolf )
	float duration = wolf.GetSequenceDuration( "pr_grunt_attack_F" )

	thread PlayAnim( wolf , "pr_grunt_attack_F" )
	thread PlayAnim( target , "pt_prowler_attack_F" )
	wait duration
	if ( IsAlive(target) )
	{
	    target.Die( wolf, wolf, { damageSourceId = eDamageSourceId.human_execution, scriptType = DF_RAGDOLL })
	}
	thread PlayAnim( wolf ,  "pr_run_dodgehop_right" )
	wait 0.5
	StartFakePhase( wolf )
	wait 2
	wolf.Destroy()
}

void function EndFakePhase( entity player )
{
	if( IsValid( player ) )
	{
		EmitSoundOnEntity( player, SHIFTER_END_SOUND_3P_TITAN )
		player.kv.visibilityFlags = ENTITY_VISIBLE_TO_EVERYONE
	}
	if( IsAlive( player ) )
		PlayPhaseShiftAppearFX( player )
}

void function StartFakePhase( entity player )
{
	player.kv.visibilityFlags = ENTITY_VISIBLE_TO_NOBODY
	entity fx = PlayPhaseShiftDisappearFX( player )
	EmitSoundOnEntity( player, SHIFTER_START_SOUND_3P_TITAN )
	thread PhaseShiftDisappearEffectCleanup( player, fx, 2 )
}

void function StartFakePhaseShift( entity player, float duration )
{
    player.kv.visibilityFlags = ENTITY_VISIBLE_TO_NOBODY
	entity fx = PlayPhaseShiftDisappearFX( player )
	EmitSoundOnEntity( player, SHIFTER_START_SOUND_3P_TITAN )
	thread PhaseShiftDisappearEffectCleanup( player, fx, duration )

	wait duration

	if( IsValid( player ) )
	{
		EmitSoundOnEntity( player, SHIFTER_END_SOUND_3P_TITAN )
		player.kv.visibilityFlags = ENTITY_VISIBLE_TO_EVERYONE
	}
	if( IsAlive( player ) )
		PlayPhaseShiftAppearFX( player )
}
entity function PlayPhaseShiftAppearFX( entity ent )
{
	asset effect = $"P_phase_shift_main"
	if ( !IsHumanSized( ent ) )
		effect = $"P_phase_shift_main"

	if ( ent.IsTitan() )
		EmitSoundOnEntityExceptToPlayer( ent, ent, SHIFTER_END_SOUND_3P_TITAN )
	else
		EmitSoundOnEntityExceptToPlayer( ent, ent, SHIFTER_END_SOUND_3P )

	return PlayFXOnEntity( effect, ent )
}

void function PhaseShiftDisappearEffectCleanup( entity ent, entity fx, float duration )
{
	fx.EndSignal( "OnDestroy" )
	ent.EndSignal( "ForceStopPhaseShift" )

	OnThreadEnd(
	function() : ( fx )
		{
			if ( IsValid( fx ) )
			{
				EffectStop( fx )
			}
		}
	)

	float bufferTime = 1.4
	if ( ent.IsTitan() )
		bufferTime = 0.0

	wait max( duration - bufferTime, 0.0 )
}






































































void function SpectreRip( entity victim, var damageInfo )
{
	DamageInfo_SetDamage( damageInfo, 0 )
	entity spectre = DamageInfo_GetAttacker( damageInfo )
	thread SpectreRip_threaded( spectre, victim )
}
void function ProwlerRip( entity victim, var damageInfo )
{
	DamageInfo_SetDamage( damageInfo, 0 )
	entity prowler = DamageInfo_GetAttacker( damageInfo )
	thread ProwlerRip_threaded( prowler, victim )
}








void function ProwlerRip_threaded( entity prowler, entity player )
{
	prowler.SetAngles(prowler.GetAngles() + <0,180,0>)
	thread PlayAnim( prowler , "pr_grunt_attack_F" )
	waitthread PlayAnim( player , "pt_prowler_attack_F" , prowler )
	if ( IsAlive(player) )
	{
	    player.Die( prowler, prowler, { damageSourceId = eDamageSourceId.human_execution, scriptType = DF_RAGDOLL })
	}
}

void function SpectreRip_threaded( entity spectre, entity player )
{
	spectre.SetAngles(spectre.GetAngles() + <0,180,0>)
	thread PlayAnim( spectre , "sp_stand_melee_headrip_A" )
	waitthread PlayAnim( player , "pt_stand_melee_headrip_V" , spectre )
	if ( IsAlive(player) )
	{
	    player.Die( spectre, spectre, { damageSourceId = eDamageSourceId.human_execution, scriptType = DF_RAGDOLL })
	}
}
#endif



























#if SP
global function PrintBossTitanData

struct
{
	table< string, BossTitanData > bossTitans
	//table< string, BossTitanIntroData > bossTitanIntros
	//table< string, table<string,BossTitanConversation> > bossTitanConvData
	//table< string, float > aliasUsedTimes
} file

void function PrintBossTitanData()
{
	//boss titan stuff
	var dataTable = GetDataTable( $"datatable/titan_bosses.rpak" )
	for ( int i = 0; i < GetDatatableRowCount( dataTable ); i++ )
	{
		string bossName	= GetDataTableString( dataTable, i, GetDataTableColumnByName( dataTable, "bossCharacter" ) )
		print( bossName )
		//AddBossTitan( bossName )
		BossTitanData bossTitanData = GetBossTitanData( bossName )

		bossTitanData.bossTitle 			= GetDataTableString( dataTable, i, GetDataTableColumnByName( dataTable, "bossTitle" ) )
		bossTitanData.titanCameraAttachment	= GetDataTableString( dataTable, i, GetDataTableColumnByName( dataTable, "titanCameraAttachment" ) )
		bossTitanData.introAnimTitan 		= GetDataTableString( dataTable, i, GetDataTableColumnByName( dataTable, "introAnimTitan" ) )
		bossTitanData.introAnimPilot 		= GetDataTableString( dataTable, i, GetDataTableColumnByName( dataTable, "introAnimPilot" ) )
		bossTitanData.introAnimTitanRef 	= GetDataTableString( dataTable, i, GetDataTableColumnByName( dataTable, "introAnimTitanRef" ) )
		bossTitanData.characterModel 		= GetDataTableAsset( dataTable, i, GetDataTableColumnByName( dataTable, "pilotModel" ) )
        print( bossName )
		print( bossTitanData.bossTitle )
		print( bossTitanData.introAnimTitan  )
		print( bossTitanData.introAnimPilot)

		//unused

		/*BossTitanIntroData introData = GetBossTitanIntroData( bossName )
		introData.waitToStartFlag 	= GetDataTableString( dataTable, i, GetDataTableColumnByName( dataTable, "waitToStartFlag" ) )
		introData.waitForLookat 	= GetDataTableBool( dataTable, i, GetDataTableColumnByName( dataTable, "waitForLookat" ) )
		introData.lookatDoTrace 	= GetDataTableBool( dataTable, i, GetDataTableColumnByName( dataTable, "lookatDoTrace" ) )
		introData.lookatDegrees 	= GetDataTableFloat( dataTable, i, GetDataTableColumnByName( dataTable, "lookatDegrees" ) )
		introData.lookatMinDist 	= GetDataTableFloat( dataTable, i, GetDataTableColumnByName( dataTable, "lookatMinDist" ) )*/
	}
}

BossTitanData function AddBossTitan( string bossName )
{
	Assert( !( bossName in file.bossTitans ) )
	BossTitanData bossTitanData
	bossTitanData.bossID = file.bossTitans.len()
	file.bossTitans[ bossName ] <- bossTitanData

	//unused

	//BossTitanIntroData bossTitanIntroData
	//file.bossTitanIntros[ bossName ] <- bossTitanIntroData
	return bossTitanData
}
/*BossTitanData function GetBossTitanData( string bossName )
{
	Assert( bossName in file.bossTitans )
	return file.bossTitans[ bossName ]
}*/

#endif