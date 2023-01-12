/*
void function HardpointThink( HardpointStruct hardpoint )
{
	entity hardpointEnt = hardpoint.hardpoint
	//int hardpointEHandle = hardpointEnt.GetEncodedEHandle()

	thread HardpointScoringThink( hardpoint )
	thread HardpointCappersThink( hardpoint )

	float lastTime = Time()
	bool hasBeenAmped = false

	// for maps like complex3, if running classicMPNoIntro it won't start capping
	// reassign cappers already in trigger before game starts
	foreach ( HardpointStruct hardpointStruct in file.hardpoints )
	{
		array<entity> touchingEnts = GetAllEntitiesInTrigger( hardpointStruct.trigger )
		// run the enter function for them
		foreach( entity ent in touchingEnts )
			OnHardpointEntered( hardpointStruct.trigger, ent )
	}

	EmitSoundOnEntity( hardpointEnt, "hardpoint_console_idle" )

	WaitFrame() // wait a frame so deltaTime is never zero

	while ( GamePlayingOrSuddenDeath() )
	{
		table<int, table<string, int> > capStrength = {
			[TEAM_IMC] = {
				pilots = 0,
				titans = 0,
			},
			[TEAM_MILITIA] = {
				pilots = 0,
				titans = 0,
			}
		}

		float currentTime = Time()
		float deltaTime = currentTime - lastTime

		SetCapperAmount( capStrength, hardpoint.militiaCappers )
		SetCapperAmount( capStrength, hardpoint.imcCappers )

		int imcPilotCappers = capStrength[TEAM_IMC]["pilots"]
		int imcTitanCappers = capStrength[TEAM_IMC]["titans"]

		int militiaPilotCappers = capStrength[TEAM_MILITIA]["pilots"]
		int militiaTitanCappers = capStrength[TEAM_MILITIA]["titans"]

		int imcCappers = ( imcTitanCappers + militiaTitanCappers ) > 0 ? imcTitanCappers : imcPilotCappers
		int militiaCappers = ( imcTitanCappers + militiaTitanCappers ) <= 0 ? militiaPilotCappers : militiaTitanCappers

		int cappingTeam
		int capperAmount = 0
		bool hardpointBlocked = false

		if((imcCappers > 0) && (militiaCappers > 0))
		{
			hardpointBlocked = true
		}
		else if ( imcCappers > 0 )
		{
			cappingTeam = TEAM_IMC
			capperAmount = imcCappers
		}
		else if ( militiaCappers > 0 )
		{
			cappingTeam = TEAM_MILITIA
			capperAmount = militiaCappers
		}
		capperAmount = minint(capperAmount, 3)

		if(hardpointBlocked)
		{
			SetHardpointState(hardpoint,CAPTURE_POINT_STATE_HALTED)
		}
		else if(cappingTeam==TEAM_UNASSIGNED) // nobody on point
		{
			waittread HardpointSelfUnamping( hardpoint )
		}
		else if(hardpointEnt.GetTeam()==TEAM_UNASSIGNED) // uncapped point
		{
			if(GetHardpointCappingTeam(hardpoint)==TEAM_UNASSIGNED) // uncapped point with no one inside
			{
				SetHardpointCaptureProgress( hardpoint, min(1.0,GetHardpointCaptureProgress( hardpoint ) + ( deltaTime / CAPTURE_DURATION_CAPTURE * capperAmount) ) )
				SetHardpointCappingTeam(hardpoint,cappingTeam)
				if(GetHardpointCaptureProgress(hardpoint)>=1.0)
				{
					CapturePointForTeam(hardpoint,cappingTeam)
					hasBeenAmped = false
				}
			}
			else if(GetHardpointCappingTeam(hardpoint)==cappingTeam) // uncapped point with ally inside
			{
				SetHardpointCaptureProgress( hardpoint,min(1.0, GetHardpointCaptureProgress( hardpoint ) + ( deltaTime / CAPTURE_DURATION_CAPTURE * capperAmount) ) )
				if(GetHardpointCaptureProgress(hardpoint)>=1.0)
				{
					CapturePointForTeam(hardpoint,cappingTeam)
					hasBeenAmped = false
				}
			}
			else // uncapped point with enemy inside
			{
				SetHardpointCaptureProgress( hardpoint,max(0.0, GetHardpointCaptureProgress( hardpoint ) - ( deltaTime / CAPTURE_DURATION_CAPTURE * capperAmount) ) )
				if(GetHardpointCaptureProgress(hardpoint)==0.0)
				{
					SetHardpointCappingTeam(hardpoint,cappingTeam)
					if(GetHardpointCaptureProgress(hardpoint)>=1)
					{
						CapturePointForTeam(hardpoint,cappingTeam)
						hasBeenAmped = false
					}
				}
			}
		}
		else if(hardpointEnt.GetTeam()!=cappingTeam) // capping enemy point
		{
			SetHardpointCappingTeam(hardpoint,cappingTeam)
			SetHardpointCaptureProgress( hardpoint,max(0.0, GetHardpointCaptureProgress( hardpoint ) - ( deltaTime / CAPTURE_DURATION_CAPTURE * capperAmount) ) )
			if(GetHardpointCaptureProgress(hardpoint)<=1.0)
			{
				if (GetHardpointState(hardpoint) == CAPTURE_POINT_STATE_AMPED) // only play 2inactive animation if we were amped
					thread PlayAnim( hardpoint.prop, "mh_active_2_inactive" )
				SetHardpointState(hardpoint,CAPTURE_POINT_STATE_CAPTURED) // unamp
			}
			if(GetHardpointCaptureProgress(hardpoint)<=0.0) // neutralize
			{
				SetHardpointCaptureProgress(hardpoint,0.0)
				NeturalizeHardPoint( hardpoint )
				hasBeenAmped = false
			}
		}
		else if(hardpointEnt.GetTeam()==cappingTeam) // capping allied point
		{
			SetHardpointCappingTeam(hardpoint,cappingTeam)
			if(GetHardpointCaptureProgress(hardpoint)<1.0) // not amped
			{
				SetHardpointCaptureProgress(hardpoint,GetHardpointCaptureProgress(hardpoint)+(deltaTime/CAPTURE_DURATION_CAPTURE*capperAmount))
			}
			else if(file.ampingEnabled)//amping or reamping
			{
				if(GetHardpointState(hardpoint)<CAPTURE_POINT_STATE_AMPING)
					SetHardpointState(hardpoint,CAPTURE_POINT_STATE_AMPING)
				SetHardpointCaptureProgress( hardpoint, min( 2.0, GetHardpointCaptureProgress( hardpoint ) + ( deltaTime / HARDPOINT_AMPED_DELAY * capperAmount ) ) )
				if(GetHardpointCaptureProgress(hardpoint)==2.0&&!(GetHardpointState(hardpoint)==CAPTURE_POINT_STATE_AMPED))
				{
					SetHardpointState( hardpoint, CAPTURE_POINT_STATE_AMPED )
					// can't use the dialogue functions here because for some reason GamemodeCP_VO_Amped isn't global?
					PlayFactionDialogueToTeam( "amphp_youAmped" + GetHardpointGroup(hardpoint.hardpoint), cappingTeam )
					PlayFactionDialogueToTeam( "amphp_enemyAmped" + GetHardpointGroup(hardpoint.hardpoint), GetOtherTeam( cappingTeam ) )
					thread PlayAnim( hardpoint.prop, "mh_inactive_2_active" )

					if(!hasBeenAmped){
						hasBeenAmped=true

						array<entity> allCappers
						allCappers.extend(hardpoint.militiaCappers)
						allCappers.extend(hardpoint.imcCappers)

						foreach(entity player in allCappers)
						{
							if ( IsValid( player ) )
							{
								if(player.IsPlayer())
								{
									AddPlayerScore(player,"ControlPointAmped", player)
									player.AddToPlayerGameStat(PGS_DEFENSE_SCORE,POINTVALUE_HARDPOINT_AMPED)
								}
							}
						}
					}
				}
			}
		}

		lastTime = currentTime
		WaitFrame()
	}
}

void function HardpointSelfUnamping(  )
{
	float lastTime = Time()

	while ( GamePlayingOrSuddenDeath() )
	{
		float currentTime = Time()
		float deltaTime = currentTime - lastTime

		if ( ( GetHardpointState(hardpoint) == CAPTURE_POINT_STATE_AMPED ) || ( GetHardpointState(hardpoint) == CAPTURE_POINT_STATE_AMPING ) )
		{
			SetHardpointCappingTeam( hardpoint,hardpointEnt.GetTeam() )
			SetHardpointCaptureProgress( hardpoint,max( 1.0, GetHardpointCaptureProgress(hardpoint) - (deltaTime/HARDPOINT_AMPED_DELAY) ) )
			if( GetHardpointCaptureProgress(hardpoint) <= 1.001 ) // unamp
			{
				if ( GetHardpointState(hardpoint) == CAPTURE_POINT_STATE_AMPED ) // only play 2inactive animation if we were amped
					thread PlayAnim( hardpoint.prop, "mh_active_2_inactive" )
				SetHardpointState( hardpoint,CAPTURE_POINT_STATE_CAPTURED )
			}
		}
		if(GetHardpointState(hardpoint)>=CAPTURE_POINT_STATE_CAPTURED)
			SetHardpointCappingTeam(hardpoint,TEAM_UNASSIGNED)
	}
}

void function HardpointScoringThink( HardpointStruct hardpoint )
{
	float lastScoreTime = Time()

	while( GamePlayingOrSuddenDeath() )
	{
		if ( hardpointEnt.GetTeam() != TEAM_UNASSIGNED && GetHardpointState( hardpoint ) >= CAPTURE_POINT_STATE_CAPTURED && currentTime - lastScoreTime >= TEAM_OWNED_SCORE_FREQ && !hardpointBlocked&&!(cappingTeam==GetOtherTeam(hardpointEnt.GetTeam())))
		{
			lastScoreTime = currentTime
			if ( GetHardpointState( hardpoint ) == CAPTURE_POINT_STATE_AMPED )
				AddTeamScore( hardpointEnt.GetTeam(), 2 )
			else if( GetHardpointState( hardpoint) >= CAPTURE_POINT_STATE_CAPTURED)
				AddTeamScore( hardpointEnt.GetTeam(), 1 )
		}

		WaitFrame()
	}
}

void function HardpointCappersThink( HardpointStruct hardpoint )
{
	while( GamePlayingOrSuddenDeath() )
	{
		foreach(entity player in hardpoint.imcCappers)
		{
			if( IsValid( player ) )
			{
				if ( DistanceSqr( player.GetOrigin(), hardpoint.trigger.GetOrigin() ) > 1200000 )
					FindAndRemove( hardpoint.imcCappers, player )
			}
		}
		foreach(entity player in hardpoint.militiaCappers)
		{
			if( IsValid( player ) )
			{
				if ( DistanceSqr( player.GetOrigin(), hardpoint.trigger.GetOrigin() ) > 1200000 )
					FindAndRemove( hardpoint.militiaCappers, player )
			}
		}

		WaitFrame()
	}
}
*/