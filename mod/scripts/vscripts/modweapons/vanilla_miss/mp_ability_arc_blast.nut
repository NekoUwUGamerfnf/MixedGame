global function MpAbilityArcBlast_Init

global function OnWeaponPrimaryAttack_ability_arc_blast
bool saveMeleeEnable = true

void function MpAbilityArcBlast_Init()
{
	
}

var function OnWeaponPrimaryAttack_ability_arc_blast( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity owner = weapon.GetWeaponOwner()
	if( weapon.HasMod( "area_force" ) )
		thread AreaForceThink( weapon, owner )
}

void function AreaForceThink( entity offhand, entity player )
{
	#if SERVER

	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnChangedPlayerClass" )

	OnThreadEnd(
		function(): ( player, offhand )
		{
			if( IsValid( player ) )
			{
				StopSoundOnEntity( player, "cloak_sustain_loop_1P" )
				StopSoundOnEntity( player, "cloak_sustain_loop_3P" )
				if( IsValid( offhand ) && offhand.HasMod( "no_regen" ) )
					offhand.RemoveMod( "no_regen" )
			}
		}
	)
	
	string activeweapon
	string savedmelee
	wait 0.1
	if( IsValid(player) )
	{
		if( IsValid( player.GetOffhandWeapon(OFFHAND_MELEE) ) )
		{
			if( saveMeleeEnable )
				savedmelee = player.GetOffhandWeapon(OFFHAND_MELEE).GetWeaponClassName()
			player.TakeWeaponNow( player.GetOffhandWeapon(OFFHAND_MELEE).GetWeaponClassName() )
		}
		player.GiveOffhandWeapon( "melee_pilot_sword", OFFHAND_MELEE, ["areaforce"] )
		
		if( IsValid( offhand ) )
		{
			offhand.AddMod( "no_regen" )
			offhand.SetWeaponPrimaryClipCountAbsolute( 0 )
		}

		EmitSoundOnEntityOnlyToPlayer( player, player, "cloak_on_1P" )
		EmitSoundOnEntityExceptToPlayer( player, player, "cloak_on_3P" )

		EmitSoundOnEntityOnlyToPlayer( player, player, "cloak_sustain_loop_1P" )
		EmitSoundOnEntityExceptToPlayer( player, player, "cloak_sustain_loop_3P" )

		SendHudMessage( player, "进入蓄力状态\n按下近战拉近准星处敌人", -1, -0.35, 255, 255, 100, 255, 0, 5, 0 )

		while( true )
		{
			activeweapon = player.GetActiveWeapon().GetWeaponClassName()

			if( activeweapon == "melee_pilot_sword" )
			{
				if( IsValid(player) )
				{
					StopSoundOnEntity( player, "cloak_sustain_loop_1P" )
					StopSoundOnEntity( player, "cloak_sustain_loop_3P" )

					EmitSoundOnEntityOnlyToPlayer( player, player, "cloak_interruptend_1P" )
					EmitSoundOnEntityExceptToPlayer( player, player, "cloak_interruptend_3P" )

					SendHudMessage( player, "退出蓄力", -1, -0.35, 255, 255, 100, 255, 0, 2, 0 )
					if( IsValid( offhand ) )
						offhand.RemoveMod( "no_regen" )
				}
				wait 0.1
				if( IsValid(player) )
				{
					if( IsValid( player.GetOffhandWeapon(OFFHAND_MELEE) ) )
						player.TakeWeaponNow( player.GetOffhandWeapon(OFFHAND_MELEE).GetWeaponClassName() )
					wait 0.3
					if( saveMeleeEnable )
					{
						if( IsValid(player) )
						{
							if( savedmelee != "" && !IsValid( player.GetOffhandWeapon(OFFHAND_MELEE) ) )
								player.GiveOffhandWeapon( savedmelee, OFFHAND_MELEE )
						}
					}
				}
				break
			}
			WaitFrame()
		}
	}
	#endif
}

/* //Unused Assassin skill, which not a proper tactical
void function AssassinStateShink( entity player, float duration = 3 )
{
	//WaitFrame()
	EnableAssassin( player )
	wait duration
	DisbaleAssassin( player )
}

void function EnableAssassin( entity player, float duration = 3 )
{
	if( IsValid(player) )
	{
		if( player.GetOffhandWeapon(OFFHAND_MELEE).GetWeaponClassName() == "melee_pilot_emptyhanded" )
		{
			//WaitFrame()
			player.TakeOffhandWeapon(OFFHAND_MELEE)
			WaitFrame()
			player.GiveOffhandWeapon( "melee_pilot_kunai", OFFHAND_MELEE )

			StimPlayer( player, 0.5 )
			EnableCloak( player, 2.0 )
		}
	}
}

void function DisbaleAssassin( entity player )
{
	if( IsValid(player) && IsAlive(player) )
	{
		if( player.GetOffhandWeapon(OFFHAND_MELEE).GetWeaponClassName() == "melee_pilot_kunai" )
		{
			EmitSoundOnEntityOnlyToPlayer( player, player, "cloak_interruptend_1P" )
			EmitSoundOnEntityExceptToPlayer( player, player, "cloak_interruptend_3P" )

			//WaitFrame()
			player.TakeOffhandWeapon(OFFHAND_MELEE)
			WaitFrame()
			player.GiveOffhandWeapon( "melee_pilot_emptyhanded", OFFHAND_MELEE )
		}
	}
}
*/