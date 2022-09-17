global function TeamShuffle_Init

array<string> disabledGamemodes_Shuffle = ["private_match"]
array<string> disabledGamemodes_Balance = ["private_match"]
array<string> disabledMaps = ["mp_lobby"]

const int BALANCE_ALLOWED_TEAM_DIFFERENCE = 1
bool hasShuffled = false

void function TeamShuffle_Init()
{
	AddCallback_GameStateEnter( eGameState.Prematch, ShuffleTeams )
	if( !(GAMETYPE == "tdm" && GetMapName() == "mp_forwardbase_kodai") )
		AddCallback_OnPlayerKilled( CheckTeamBalance )
}

void function ShuffleTeams()
{
	TeamShuffleThink()
	if( ClassicMP_GetIntroLength() < 1 )
	{
		FixShuffle()
		WaitFrame() // do need wait to make things shuffled
	}
	else if( ClassicMP_GetIntroLength() >= 5 )
		thread FixShuffle( ClassicMP_GetIntroLength() - 0.5 ) // fix shuffle
}

void function TeamShuffleThink()
{
	if( hasShuffled )
		return
	// Check if the gamemode or map are on the blacklist
	bool gamemodeDisable = disabledGamemodes_Shuffle.contains(GAMETYPE) || IsFFAGame();
	bool mapDisable = disabledMaps.contains(GetMapName());

  	if ( gamemodeDisable )
    	return
  
  	if ( mapDisable )
    	return
    
 	if ( GetPlayerArray().len() == 0 )
    	return
  
  	// Set team to TEAM_UNASSIGNED
  	foreach ( player in GetPlayerArray() )
    	SetTeam ( player, TEAM_UNASSIGNED )
  
  	int maxTeamSize = GetPlayerArray().len() / 2
  
  	// Assign teams
  	foreach ( player in GetPlayerArray() )
  	{
    	if( !IsValid( player ) )
      		continue
    
    	// Get random team
    	int team = RandomIntRange( TEAM_IMC, TEAM_MILITIA + 1 )
    	// Gueard for team size
    	if ( GetPlayerArrayOfTeam( team ).len() >= maxTeamSize )
    	{
      		SetTeam( player, GetOtherTeam( team ) )
      			continue
    	}
    // 
    	SetTeam( player, team )
	}
	hasShuffled = true
}

void function FixShuffle( float delay = 0 )
{
	if( delay > 0 )
		wait delay

	bool gamemodeDisable = disabledGamemodes_Shuffle.contains(GAMETYPE) || IsFFAGame();
	bool mapDisable = disabledMaps.contains(GetMapName());

  	if ( gamemodeDisable )
    	return
  
  	if ( mapDisable )
    	return

	int mltTeamSize = GetPlayerArrayOfTeam( TEAM_MILITIA ).len()
	int imcTeamSize = GetPlayerArrayOfTeam( TEAM_IMC ).len()
	int teamSizeDifference = abs( mltTeamSize - imcTeamSize )
  	if( teamSizeDifference <= BALANCE_ALLOWED_TEAM_DIFFERENCE )
		return
	
	if ( GetPlayerArray().len() == 1 )
		return

	int timeShouldBeDone = teamSizeDifference - BALANCE_ALLOWED_TEAM_DIFFERENCE
	int largerTeam = imcTeamSize > mltTeamSize ? TEAM_IMC : TEAM_MILITIA
	array<entity> largerTeamPlayers = GetPlayerArrayOfTeam( largerTeam )
	
	int largerTeamIndex = 0
	for( int i = 0; i < timeShouldBeDone; i ++ )
	{
		entity poorGuy = largerTeamPlayers[ largerTeamIndex ]
		largerTeamIndex += 1

		if( IsAlive( poorGuy ) ) // poor guy
			poorGuy.Die()
		int oldTeam = poorGuy.GetTeam()
		SetTeam( poorGuy, GetOtherTeam( largerTeam ) )
		Chat_ServerPrivateMessage( poorGuy, "由于队伍人数不平衡，你已被重新分队", false )
		NotifyClientsOfTeamChange( poorGuy, oldTeam, poorGuy.GetTeam() )
		if( !RespawnsEnabled() ) // do need respawn the guy if respawnsdisabled
			RespawnAsPilot( poorGuy )
	}
}

void function CheckTeamBalance( entity victim, entity attacker, var damageInfo )
{  
  	// Check if the gamemode or map are on the blacklist
	bool gamemodeDisable = disabledGamemodes_Balance.contains(GAMETYPE) || IsFFAGame();
	bool mapDisable = disabledMaps.contains(GetMapName());

	// Blacklist guards
  	if ( gamemodeDisable )
    	return
  
  	if ( mapDisable )
    	return
  
	// Check if difference is smaller than 2 ( dont balance when it is 0 or 1 )
	// May be too aggresive ??
	if( abs ( GetPlayerArrayOfTeam( TEAM_IMC ).len() - GetPlayerArrayOfTeam( TEAM_MILITIA ).len() ) <= BALANCE_ALLOWED_TEAM_DIFFERENCE )
		return
	
	if ( GetPlayerArray().len() == 1 )
		return
	
	// Compare victims teams size
	if ( GetPlayerArrayOfTeam( victim.GetTeam() ).len() < GetPlayerArrayOfTeam( GetOtherTeam( victim.GetTeam() ) ).len() )
		return
	
	// We passed all checks, balance the teams
	int oldTeam = victim.GetTeam()
	SetTeam( victim, GetOtherTeam( victim.GetTeam() ) )
	Chat_ServerPrivateMessage( victim, "由于队伍人数不平衡，你已被重新分队", false )
	NotifyClientsOfTeamChange( victim, oldTeam, victim.GetTeam() )
}