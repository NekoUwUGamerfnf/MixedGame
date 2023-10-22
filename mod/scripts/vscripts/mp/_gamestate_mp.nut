untyped

global function PIN_GameStart
global function SetGameState
global function GameState_EntitiesDidLoad
global function WaittillGameStateOrHigher
global function AddCallback_OnRoundEndCleanup
// new adding
global function AddCallback_OnMatchEndCleanup

global function SetShouldUsePickLoadoutScreen
global function SetSwitchSidesBased
global function SetSuddenDeathBased
global function SetTimerBased
global function SetShouldUseRoundWinningKillReplay

global function SetRoundWinningKillReplayKillClasses
global function SetUpRoundWinningKillReplayFromDamageInfo // this could handle all roundWinning kill replay stuffs
global function SetRoundWinningKillReplayAttacker
// function for highlight replay such as CTF scoring
global function SetRoundWinningHighlightReplayPlayer
// fix for projectile kill replay
global function SetRoundWinningKillReplayInflictor

global function SetWinner
// modified. we only do replay if game wins by player earning score
global function MarkAsGameWinsByEarnScore

global function SetTimeoutWinnerDecisionFunc
global function SetTimeoutWinnerDecisionReason
global function AddTeamScore
global function GetWinningTeamWithFFASupport

global function GameState_GetTimeLimitOverride
global function IsRoundBasedGameOver
global function ShouldRunEvac
global function GiveTitanToPlayer
global function GetTimeLimit_ForGameMode

// i want my game to have these!
global function IsSwitchSidesBased_NorthStar // this returns northstar's setting of switchSides, should DEPRECATE
global function SetWaitingForPlayersMaxDuration // so you don't have to wait so freaking long

global function SetPickLoadoutEnabled
global function SetPickLoadoutDuration // for modified intros
global function SetTitanSelectionMenuDuration // overwrites SetPickLoadoutDuration()
global function GameState_SetScoreEventDialogueEnabled // game progress dialogue toggle

// modifiable consts, I don't know which respawn const to use, just use mine
// playing
// noPlayerAlive checks currently removed
//const float NO_PLAYER_ALIVE_SET_WINNER_DELAY = 15.0 // if no player alive for these seconds, we just decide winner

// replay
const float ROUND_WINNING_KILL_REPLAY_FADE_ON_START = 2.0 // delay before roundwinning killreplay starts after round end
const float ROUND_WINNING_KILL_REPLAY_EXTRA_BEFORE_TIME = 1.0 // extra before time added to replay
const float ROUND_WINNING_HIGHLIGHT_REPLAY_DURATION = ROUND_WINNING_KILL_REPLAY_LENGTH_OF_REPLAY
const float ROUND_WINNING_KILL_REPLAY_MAX_DELAY = 8.0 // we never do replay if our replay has been delayed for this long
const float ROUND_WINNING_KILL_REPLAY_EXTRA_DELAY_SWITCHING_SIDES = 1.5 // switchsides replay should wait this more time
const float ROUND_WINNING_KILL_REPLAY_EXTRA_DELAY_MATCH_END = 1.5 // match end kill replay should wait this more time

// round based
const float ROUND_CLEANUP_WAIT = 2.0 // delay before round cleanup starts after roundwinnning killreplay ends
const float ROUND_CLEANUP_EXTRA_WAIT_NO_REPLAY = 1.0 // if no replay playing, we wait a bit more before cleanup
const float ROUND_TRANSITION_DELAY = 2.0 // delay before starting next round after round cleanup

// switchside based
const float SWITCH_SIDE_CLEANUP_WAIT = 2.0
const float SWITCH_SIDE_EXTRA_WAIT_NO_REPLAY = 1.0
const float SWITCH_SIDE_INTERMISSION_CAM_DELAY = 1.0 // set player back to intermission cam after this delay if we did replay. needs to be longer than 1s to hide player's death screen effect
const float SWITCH_SIDE_TRANSITION_DELAY = 1.5
const float SWITCH_SIDE_TRANSITION_DELAY_NO_REPLAY = 2.5

// match cleanup
const float MATCH_CLEANUP_WAIT = 1.0 // delay before we do match cleanup

struct {
	// used for togglable parts of gamestate
	bool usePickLoadoutScreen
	bool switchSidesBased
	bool suddenDeathBased
	bool timerBased = true
	int functionref() timeoutWinnerDecisionFunc
	string timeoutWinningReason = "#GAMEMODE_TIME_LIMIT_REACHED"
	string timeoutLosingReason = "#GAMEMODE_TIME_LIMIT_REACHED"
	
	// for waitingforplayers
	int numPlayersFullyConnected
	
	bool hasSwitchedSides
	bool isTimeOutSwitchingSides // modified
	
	int announceRoundWinnerWinningSubstr
	int announceRoundWinnerLosingSubstr
		
	bool roundWinningKillReplayTrackPilotKills = true 
	bool roundWinningKillReplayTrackTitanKills = false
	
	// no need to do frame checks
	//bool gameWonThisFrame
	//bool hasKillForGameWonThisFrame
	bool gameWonByEarnScore // we only do replay if game wins by player earning score
	bool roundWinningKillReplayHasSetUp = false // this will be enough
	//float roundWinningKillReplayTime // doesn't seem needed...
	entity roundWinningKillReplayVictim // still needed in case we want to use player.SetKillReplayVictim(), but doesn't matter
	// reworked to use entity index directly...
	//entity roundWinningKillReplayAttacker
	// store everything that can be used by PlayerWatchesKillReplay()
	int roundWinningKillReplayAttackerIndex = -1
	int roundWinningKillReplayAttackerEHandle = -1
	int roundWinningKillReplayMethodOfDeath = -1
	float roundWinningKillReplayHealthFrac = 0.0
	int roundWinningKillReplayInflictorEHandle = -1 // fix projectile kill replay
	// replay length
	float roundWinningKillReplayLength = 0.0 // this is better, we can calculate it using CalculateLengthOfKillReplay()=
	float roundWinningKillReplayTimeSinceAttackerSpawned = 0.0
	float roundWinningKillReplayTimeOfDeath = 0.0
	float roundWinningKillReplayBeforeTime = 0.0 // beforeTime is the actual replay length
	table roundWinningKillReplayTracker
	// replay finished amount
	int numPlayersFinishedWatchingReplay
	
	array<void functionref()> roundEndCleanupCallbacks
	// new adding
	array<void functionref()> matchEndCleanupCallbacks

	// modified
	float waitingForPlayersMaxDuration = 20.0
	bool enteredSuddenDeath = false

	bool pickLoadoutEnable = false
	float pickLoadoutDuration = 10.0
	float titanSelectionMenuDuration = 30.0
	bool scoreEventDialogue = true
} file

void function PIN_GameStart()
{
	// todo: using the pin telemetry function here, weird and was done veeery early on before i knew how this all worked, should use a different one

	// called from InitGameState
	//FlagInit( "ReadyToStartMatch" )
	
	// In vanilla the level.nv.switchSides only inited when gamemode is actually using switch sides, or the function IsSwitchSidesBased() from _utility_shared.nut will always return a "true"!
	//SetServerVar( "switchedSides", 0 ) // handled by SetSwitchSidesBased()
	SetServerVar( "winningTeam", -1 )
		
	AddCallback_GameStateEnter( eGameState.WaitingForCustomStart, GameStateEnter_WaitingForCustomStart )
	AddCallback_GameStateEnter( eGameState.WaitingForPlayers, GameStateEnter_WaitingForPlayers )
	AddCallback_OnClientConnected( WaitingForPlayers_ClientConnected )
	
	AddCallback_GameStateEnter( eGameState.PickLoadout, GameStateEnter_PickLoadout )
	AddCallback_GameStateEnter( eGameState.Prematch, GameStateEnter_Prematch )
	AddCallback_GameStateEnter( eGameState.Playing, GameStateEnter_Playing )
	AddCallback_GameStateEnter( eGameState.WinnerDetermined, GameStateEnter_WinnerDetermined )
	AddCallback_GameStateEnter( eGameState.SwitchingSides, GameStateEnter_SwitchingSides )
	AddCallback_GameStateEnter( eGameState.SuddenDeath, GameStateEnter_SuddenDeath )
	AddCallback_GameStateEnter( eGameState.Postmatch, GameStateEnter_Postmatch )
	
	AddCallback_OnPlayerKilled( OnPlayerKilled )
	AddDeathCallback( "npc_titan", OnTitanKilled )

	RegisterSignal( "CleanUpEntitiesForRoundEnd" )
	// new adding
	RegisterSignal( "CleanUpEntitiesForMatchEnd" )
}

void function SetGameState( int newState )
{
	if ( newState == GetGameState() )
		return

	SetServerVar( "gameStateChangeTime", Time() )
	SetServerVar( "gameState", newState )
	svGlobal.levelEnt.Signal( "GameStateChanged" )
	
	// added in AddCallback_GameStateEnter
	foreach ( callbackFunc in svGlobal.gameStateEnterCallbacks[ newState ] )
		callbackFunc()
}

void function GameState_EntitiesDidLoad()
{
	if ( GetClassicMPMode() || ClassicMP_ShouldTryIntroAndEpilogueWithoutClassicMP() )
		ClassicMP_SetupIntro()
}

void function WaittillGameStateOrHigher( int gameState )
{
	while ( GetGameState() < gameState )
		svGlobal.levelEnt.WaitSignal( "GameStateChanged" )
}


// logic for individual gamestates:


// eGameState.WaitingForCustomStart
void function GameStateEnter_WaitingForCustomStart()
{
	// unused in release, comments indicate this was supposed to be used for an e3 demo
	// perhaps games in this demo were manually started by an employee? no clue really
}


// eGameState.WaitingForPlayers
void function GameStateEnter_WaitingForPlayers()
{
	foreach ( entity player in GetPlayerArray() )
		WaitingForPlayers_ClientConnected( player )
		
	thread WaitForPlayers() // like 90% sure there should be a way to get number of loading clients on server but idk it
}

void function WaitForPlayers()
{
	// note: atm if someone disconnects as this happens the game will just wait forever
	float endTime = Time() + file.waitingForPlayersMaxDuration
	
	while ( ( GetPendingClientsCount() != 0 && endTime > Time() ) || GetPlayerArray().len() == 0 )
		WaitFrame()

	print( "done waiting!" )
	
	wait 1.0 // bit nicer
	if ( file.pickLoadoutEnable || file.usePickLoadoutScreen )
		SetGameState( eGameState.PickLoadout ) // warpjump or wargames intro sound will be played on client if we're in eGameState.PickLoadout
	else
		SetGameState( eGameState.Prematch )
}

void function WaitingForPlayers_ClientConnected( entity player )
{
	if ( GetGameState() == eGameState.WaitingForPlayers )
	{
		ScreenFadeToBlackForever( player, 0.0 )
		file.numPlayersFullyConnected++
	}
}

// eGameState.PickLoadout
void function GameStateEnter_PickLoadout()
{
	thread GameStateEnter_PickLoadout_Threaded()
}

void function GameStateEnter_PickLoadout_Threaded()
{	
	float pickLoadoutTime = file.pickLoadoutDuration
	if ( file.usePickLoadoutScreen )
		pickLoadoutTime = file.titanSelectionMenuDuration

	SetServerVar( "minPickLoadOutTime", Time() + pickLoadoutTime )
	if ( !file.usePickLoadoutScreen )
		thread PickLoadoutFadeToBlack() // this is required if you want late joiners screen fade to black
	
	// titan selection menu can change minPickLoadOutTime so we need to wait manually until we hit the time
	while ( Time() < GetServerVar( "minPickLoadOutTime" ) )
		WaitFrame()
	
	SetGameState( eGameState.Prematch )
}

void function PickLoadoutFadeToBlack()
{
	svGlobal.levelEnt.EndSignal( "GameStateChanged" ) // end this thread once we entered prematch

	while ( GetGameState() == eGameState.PickLoadout )
	{
		foreach ( entity player in GetPlayerArray() )
			ScreenFadeToBlackForever( player, 0.0 )
		WaitFrame()
	}
}

// eGameState.Prematch
void function GameStateEnter_Prematch()
{
	int timeLimit = GameMode_GetTimeLimit( GAMETYPE ) * 60
	if ( file.switchSidesBased )
		timeLimit /= 2 // endtime is half of total per side
	
	SetServerVar( "gameEndTime", Time() + timeLimit + ClassicMP_GetIntroLength() )
	SetServerVar( "roundEndTime", Time() + ClassicMP_GetIntroLength() + GameMode_GetRoundTimeLimit( GAMETYPE ) * 60 )
	
	if ( !GetClassicMPMode() && !ClassicMP_ShouldTryIntroAndEpilogueWithoutClassicMP() )
		thread StartGameWithoutClassicMP()
	
	// have to recover from the screen fade caused by pickLoadout
	foreach ( entity player in GetPlayerArray() )
		ScreenFadeFromBlack( player, 3.0, 1.0 ) 
}

void function StartGameWithoutClassicMP()
{
	foreach ( entity player in GetPlayerArray() )
		if ( IsAlive( player ) )
			player.Die()

	WaitFrame() // wait for callbacks to finish
	
	// need these otherwise game will complain
	SetServerVar( "gameStartTime", Time() )
	SetServerVar( "roundStartTime", Time() )
	
	foreach ( entity player in GetPlayerArray() )
	{
		if ( !IsPrivateMatchSpectator( player ) )
		{
			// likely temp, deffo needs some work
			if ( Riff_SpawnAsTitan() == 1 )	// spawn as titan
				thread RespawnAsTitan( player )
			else // spawn as pilot
				RespawnAsPilot( player )
		}
			
		ScreenFadeFromBlack( player, 0 )
	}
	
	SetGameState( eGameState.Playing )
}


// eGameState.Playing
void function GameStateEnter_Playing()
{
	thread GameStateEnter_Playing_Threaded()
}

void function GameStateEnter_Playing_Threaded()
{
	WaitFrame() // ensure timelimits are all properly set

	thread DialoguePlayNormal() // runs dialogue play function

	// remove noPlayersAlive checks
	//float noPlayerAliveStartTime = -1
	while ( GetGameState() == eGameState.Playing )
	{
		// could cache these, but what if we update it midgame?
		float endTime
		if ( IsRoundBased() )
			endTime = expect float( GetServerVar( "roundEndTime" ) )
		else
			endTime = expect float( GetServerVar( "gameEndTime" ) )
	
		// time's up!
		if ( Time() >= endTime && file.timerBased )
		{
			int winningTeam
			if ( file.timeoutWinnerDecisionFunc != null )
				winningTeam = file.timeoutWinnerDecisionFunc()
			else
				winningTeam = GetWinningTeamWithFFASupport()

			if ( winningTeam < TEAM_UNASSIGNED ) // no valid winner
				winningTeam = TEAM_UNASSIGNED

			if ( file.switchSidesBased && !file.hasSwitchedSides && !IsRoundBased() ) // in roundbased modes, we handle this in setwinner
				SetGameState( eGameState.SwitchingSides )
			else if ( file.suddenDeathBased && winningTeam == TEAM_UNASSIGNED ) // suddendeath if we draw and suddendeath is enabled and haven't switched sides
			{
				if ( CanGameProcessToSuddenDeath() ) // we never start sudden death if we can end game properly
					SetGameState( eGameState.SuddenDeath )
			}
			else
				SetWinner( winningTeam, file.timeoutWinningReason, file.timeoutLosingReason )
		}
		// remove noPlayersAlive checks
		/*
		else
		{
			if ( GetPlayerArray_Alive().len() == 0 ) // player life think
			{
				if ( noPlayerAliveStartTime == -1 )
					noPlayerAliveStartTime = Time()
				else
				{
					if ( Time() - noPlayerAliveStartTime > NO_PLAYER_ALIVE_SET_WINNER_DELAY )
						SetWinner( TEAM_UNASSIGNED )
				}
			}
			else
				noPlayerAliveStartTime = -1
		}
		*/

		WaitFrame()
	}
}

// eGameState.WinnerDetermined
void function GameStateEnter_WinnerDetermined()
{	
	thread GameStateEnter_WinnerDetermined_Threaded()
}

void function GameStateEnter_WinnerDetermined_Threaded()
{
	// do win announcement
	int winningTeam = GetWinningTeamWithFFASupport()

	// match ending think
	bool isMatchEnd = true
	// SetTeamScore() should be done after announced winner
	if ( IsRoundBased() )
	{
		isMatchEnd = false // round based default will be false!
		if ( winningTeam > TEAM_UNASSIGNED )
		{
			GameRules_SetTeamScore( winningTeam, GameRules_GetTeamScore( winningTeam ) + 1 )
			GameRules_SetTeamScore2( winningTeam, GameRules_GetTeamScore2( winningTeam ) + 1 )

			int highestScore = GameRules_GetTeamScore( winningTeam )
			int roundScoreLimit = GameMode_GetRoundScoreLimit( GAMETYPE )
				
			if ( highestScore >= roundScoreLimit )
				isMatchEnd = true
		}
	}

	// if round based match end, we always use #GAMEMODE_ROUND_LIMIT_REACHED
	if ( isMatchEnd && IsRoundBased() )
	{
		file.announceRoundWinnerWinningSubstr = GetStringID( "#GAMEMODE_ROUND_LIMIT_REACHED" )
		file.announceRoundWinnerLosingSubstr = GetStringID( "#GAMEMODE_ROUND_LIMIT_REACHED" )
	}

	foreach ( entity player in GetPlayerArray() )
	{

		int announcementSubstr
		if ( winningTeam > TEAM_UNASSIGNED )
			announcementSubstr = player.GetTeam() == winningTeam ? file.announceRoundWinnerWinningSubstr : file.announceRoundWinnerLosingSubstr
		else // draw
			announcementSubstr = GetStringID( "#GENERIC_DRAW_ANNOUNCEMENT" )

		if ( !isMatchEnd && IsRoundBased() ) // round based will do winner announcement if match ends
			Remote_CallFunction_NonReplay( player, "ServerCallback_AnnounceRoundWinner", winningTeam, announcementSubstr, ROUND_WINNING_KILL_REPLAY_SCREEN_FADE_TIME, GameRules_GetTeamScore2( TEAM_MILITIA ), GameRules_GetTeamScore2( TEAM_IMC ) )
		else
			Remote_CallFunction_NonReplay( player, "ServerCallback_AnnounceWinner", winningTeam, announcementSubstr, ROUND_WINNING_KILL_REPLAY_SCREEN_FADE_TIME )
	}
	
	// add score for match end
	// shared from _score.nut
	ScoreEvent_MatchComplete( winningTeam, isMatchEnd )

	bool killcamsWereEnabled = KillcamsEnabled()
	if ( killcamsWereEnabled ) // dont want killcams to interrupt stuff
		SetKillcamsEnabled( false )
	
	WaitFrame() // wait a frame so other scripts can setup killreplay stuff

	if( isMatchEnd ) // no winner dialogue till game really ends
		DialoguePlayWinnerDetermined() // play a faction dialogue when winner is determined
	
	// set gameEndTime to current time, so hud doesn't display time left in the match
	SetServerVar( "gameEndTime", Time() )
	SetServerVar( "roundEndTime", Time() )

	// reworked to use entity index directly...
	/*
	// get attacker before it gets destroyed, for later checks
	entity replayAttacker = file.roundWinningKillReplayAttacker
	entity replayVictim = file.roundWinningKillReplayVictim

	// get attacker before it gets destroyed, for later checks
	float replayLength = ROUND_WINNING_KILL_REPLAY_LENGTH_OF_REPLAY
	if( IsValid( replayAttacker ) )
	{
		attackerEHandle = replayAttacker.GetEncodedEHandle()
		attackerIndex = attacker.GetIndexForEntity()

		float attackerSpawnTime = Time()
		if ( replayAttacker.IsPlayer() && "respawnTime" in replayAttacker.s ) // player
			attackerSpawnTime = expect float ( replayAttacker.s.respawnTime )
		else if ( replayAttacker.IsNPC() ) // npc
			attackerSpawnTime = replayAttacker.ai.spawnTime

		if ( Time() - attackerSpawnTime < replayLength )
			replayLength += Time() - attackerSpawnTime
	}

	if( replayLength <= 0 ) // defensive fix
		replayLength = 2.0 // extra delay
	*/

	float replayStartTime = file.roundWinningKillReplayTimeOfDeath - file.roundWinningKillReplayBeforeTime // beforeTime is the actual replay length
	//print( "replayStartTime: " + string( replayStartTime ) )
	//print( "time: " + string( Time() ) )
	float replayDelay = Time() - replayStartTime
	//print( "replayDelay: " + string( replayDelay ) )
	//print( "gameWonByEarnScore: " + string( file.gameWonByEarnScore ) )

	bool doReplay = file.gameWonByEarnScore // we only do replay if game wins by player earning score
					&& winningTeam != TEAM_UNASSIGNED
					// generic checks
					&& Replay_IsEnabled() 
					&& IsRoundWinningKillReplayEnabled() 
					//&& IsValid( replayAttacker )
					// replay attacker validation checks
					&& file.roundWinningKillReplayAttackerEHandle != -1
					&& file.roundWinningKillReplayAttackerIndex != -1
					&& ( !isMatchEnd || !ClassicMP_ShouldRunEpilogue() )
					//&& Time() - file.roundWinningKillReplayTime <= ROUND_WINNING_KILL_REPLAY_LENGTH_OF_REPLAY 
					// never play a replay that is too old
					&& replayDelay > 0 
					&& replayDelay <= ROUND_WINNING_KILL_REPLAY_MAX_DELAY

	// debug
	//print( "doReplay: " + string( doReplay ) )
	if ( doReplay )
	{
		// pre setup for round end cleaning
		RoundCleanUpPreSetUp()
		
		// calculate replay start delay
		float killReplayStartDelay = 0.0
		if ( isMatchEnd ) // match end replay! we want the "VICTORY" notification to last longer
			killReplayStartDelay = ROUND_WINNING_KILL_REPLAY_EXTRA_DELAY_MATCH_END

		file.numPlayersFinishedWatchingReplay = 0
		int waitForNumPlayersFinishReplay = 0
		foreach ( entity player in GetPlayerArray() )
		{
			thread PlayerWatchesRoundWinningKillReplay( player, killReplayStartDelay )
			waitForNumPlayersFinishReplay++
		}

		// wait for all players finish watching replay
		while ( file.numPlayersFinishedWatchingReplay < waitForNumPlayersFinishReplay )
		{
			WaitFrame()
		}

		// prepare to cleanup
		wait ROUND_CLEANUP_WAIT
		CleanUpEntitiesForRoundEnd() // fade should be done by this point, so cleanup stuff now when people won't see

		wait ROUND_TRANSITION_DELAY
	}
	else if ( IsRoundBased() && !isMatchEnd ) // no replay roundBased, match not ending yet
	{
		// pre setup for round end cleaning
		RoundCleanUpPreSetUp()

		foreach( entity player in GetPlayerArray() )
			ScreenFadeToBlackForever( player, ROUND_CLEANUP_WAIT )
		
		wait ROUND_CLEANUP_EXTRA_WAIT_NO_REPLAY // if no replay playing, we wait a bit more

		wait ROUND_CLEANUP_WAIT
		CleanUpEntitiesForRoundEnd() // fade should be done by this point, so cleanup stuff now when people won't see

		wait ROUND_TRANSITION_DELAY
	}
	else if( !ClassicMP_ShouldRunEpilogue() )
	{
		wait ROUND_WINNING_KILL_REPLAY_LENGTH_OF_REPLAY // TEMP
	}

	if ( killcamsWereEnabled ) // reset last
		SetKillcamsEnabled( true )
	
	if ( IsRoundBased() )
	{
		svGlobal.levelEnt.Signal( "RoundEnd" )
		int roundsPlayed = expect int ( GetServerVar( "roundsPlayed" ) )
		SetServerVar( "roundsPlayed", roundsPlayed + 1 )
		
		int winningTeam = GetWinningTeamWithFFASupport()
		
		int highestScore = GameRules_GetTeamScore( winningTeam )
		int roundScoreLimit = GameMode_GetRoundScoreLimit( GAMETYPE )
		
		if ( highestScore >= roundScoreLimit )
		{
			if ( ClassicMP_ShouldRunEpilogue() )
			{
				ClassicMP_SetupEpilogue()
				SetGameState( eGameState.Epilogue )
			}
			else
			{
				SetGameState( eGameState.Postmatch )
			}
		}
		else if ( file.switchSidesBased && !file.hasSwitchedSides && highestScore >= ( roundScoreLimit.tofloat() / 2.0 ) ) // round up
			SetGameState( eGameState.SwitchingSides ) // note: switchingsides will handle setting to pickloadout and prematch by itself
		else if ( file.usePickLoadoutScreen ) // here we just doing round transition, no need to enable pickloadout for intro stuffs, only for titan menu
			SetGameState( eGameState.PickLoadout )
		else
			SetGameState ( eGameState.Prematch )
	}
	else
	{
		if ( ClassicMP_ShouldRunEpilogue() )
		{
			ClassicMP_SetupEpilogue()
			SetGameState( eGameState.Epilogue )
		}
		else
			SetGameState( eGameState.Postmatch )
	}
}

void function PlayerWatchesRoundWinningKillReplay( entity player, float extraDelay = 0.0 )
{
	// end if player dcs 
	player.EndSignal( "OnDestroy" )

	// setup OnThreadEnd
	OnThreadEnd
	(
		function(): ( player )
		{
			file.numPlayersFinishedWatchingReplay += 1
			if ( IsValid( player ) )
			{
				// clean up
				if ( player.IsWatchingKillReplay() )
					player.SetIsReplayRoundWinning( false ) // only valid when in replay
			}
		}
	)

	// setup all data we stored
	entity victim = file.roundWinningKillReplayVictim // no where can use

	int attackerIndex = file.roundWinningKillReplayAttackerIndex
	int attackerEHandle = file.roundWinningKillReplayAttackerEHandle
	int inflictorEHandle = file.roundWinningKillReplayInflictorEHandle
	int methodOfDeath = file.roundWinningKillReplayMethodOfDeath
	float attackerHealthFrac = file.roundWinningKillReplayHealthFrac
	
	float replayLength = file.roundWinningKillReplayLength
	float timeSinceAttackerSpawned = file.roundWinningKillReplayTimeSinceAttackerSpawned
	float timeOfDeath = file.roundWinningKillReplayTimeOfDeath
	float beforeTime = file.roundWinningKillReplayBeforeTime
	table replayTracker = file.roundWinningKillReplayTracker

	player.FreezeControlsOnServer()
	ScreenFadeToBlackForever( player, ROUND_WINNING_KILL_REPLAY_FADE_ON_START ) // no need to use const fade time, make it faster
	wait ROUND_WINNING_KILL_REPLAY_FADE_ON_START
	
	if ( extraDelay > 0 )
		wait extraDelay
	
	// shared from _base_gametype_mp.gnut
	SetServerVar( "roundWinningKillReplayEntHealthFrac", file.roundWinningKillReplayHealthFrac )
	thread PlayerWatchesKillReplayWrapper( player, inflictorEHandle, attackerIndex, replayLength, timeSinceAttackerSpawned, timeOfDeath, beforeTime, replayTracker, 0.0, false )
	if ( player.IsWatchingKillReplay() )
		player.SetIsReplayRoundWinning( true ) // change the text to "Last Cap Replay", only valid when in replay
	// wait for replay to end
	player.WaitSignal( "KillCamOver" )
	ScreenFadeToBlackForever( player, 0.0 ) // this is technically not necessary, as replay will follow the screen fade from attacker
}

void function GameStateEnter_SwitchingSides()
{
	thread GameStateEnter_SwitchingSides_Threaded()
}

void function GameStateEnter_SwitchingSides_Threaded()
{
	// update server state
	file.hasSwitchedSides = true
	SetServerVar( "switchedSides", 1 )

	bool killcamsWereEnabled = KillcamsEnabled()
	if ( killcamsWereEnabled ) // dont want killcams to interrupt stuff
		SetKillcamsEnabled( false )
	bool respawnsWereEnabled = RespawnsEnabled()
	if ( respawnsWereEnabled ) // don't want respawning to intterupt stuff
		SetRespawnsEnabled( false )

	// dialogue doesn't seem to exist in vanilla, just for fun
	PlayFactionDialogueToTeam( "mp_halftime", TEAM_IMC )
	PlayFactionDialogueToTeam( "mp_halftime", TEAM_MILITIA )
		
	WaitFrame() // wait a frame so callbacks can set killreplay info

	svGlobal.levelEnt.Signal( "RoundEnd" ) // might be good to get a new signal for this? not 100% necessary tho i think
	
	//PlayFactionDialogueToTeam( "mp_halftime", TEAM_IMC )
	//PlayFactionDialogueToTeam( "mp_halftime", TEAM_MILITIA )

	// abandoned stuffs
	/*
	entity replayAttacker = file.roundWinningKillReplayAttacker
	entity replayVictim = file.roundWinningKillReplayVictim
	bool doReplay = Replay_IsEnabled() 
					&& IsRoundWinningKillReplayEnabled() 
					&& IsValid( replayAttacker )
					&& !IsRoundBased() // for roundbased modes, we've already done the replay
					//&& Time() - file.roundWinningKillReplayTime <= SWITCHING_SIDES_DELAY
	
	float replayLength = 2.0 // extra delay if no replay

	int inflictorEHandle = -1
	int attackerEHandle = -1
	if ( doReplay )
	{		
		replayLength = ROUND_WINNING_KILL_REPLAY_LENGTH_OF_REPLAY

		if( IsValid( replayAttacker ) )
		{
			float attackerSpawnTime = Time()
			if ( replayAttacker.IsPlayer() && "respawnTime" in replayAttacker.s ) // player
				attackerSpawnTime = expect float ( replayAttacker.s.respawnTime )
			else if ( replayAttacker.IsNPC() ) // npc
				attackerSpawnTime = replayAttacker.ai.spawnTime

			if ( Time() - attackerSpawnTime < replayLength )
				replayLength += Time() - attackerSpawnTime
		}

		if( replayLength <= 0 ) // defensive fix
			replayLength = 2.0 // extra delay

		// fix for projectile kill replay
		int inflictorEHandle = file.roundWinningKillReplayInflictorEHandle
		// get attacker before it gets destroyed, for later checks
		int attackerEHandle = replayAttacker.GetEncodedEHandle()

		SetServerVar( "roundWinningKillReplayEntHealthFrac", file.roundWinningKillReplayHealthFrac )
	}

	foreach ( entity player in GetPlayerArray() )
		thread PlayerWatchesSwitchingSidesKillReplay( player, inflictorEHandle, replayAttacker, replayVictim, doReplay, replayLength )

	wait ROUND_WINNING_KILL_REPLAY_SCREEN_FADE_TIME // whatever we do, just wait here

	bool replaySuccess = doReplay && attackerEHandle != -1
	if( replaySuccess ) // do a same cauculate as replay's
		wait replayLength
	else
		wait SWITCHING_SIDES_DELAY - GAME_POSTROUND_CLEANUP_WAIT // save time for cleanup

	file.roundWinningKillReplayAttacker = null // reset this after replay

	PlayFactionDialogueToTeam( "mp_sideSwitching", TEAM_IMC )
	PlayFactionDialogueToTeam( "mp_sideSwitching", TEAM_MILITIA )

	CleanUpEntitiesForRoundEnd() // clean up players after dialogue
	
	wait GAME_POSTROUND_CLEANUP_WAIT // wait for better visual, may be no need for now?

	//wait 2.0 // bit nicer? 
	*/

	float replayStartTime = file.roundWinningKillReplayTimeOfDeath - file.roundWinningKillReplayBeforeTime // beforeTime is the actual replay length
	//print( "replayStartTime: " + string( replayStartTime ) )
	//print( "time: " + string( Time() ) )
	float replayDelay = Time() - replayStartTime
	//print( "replayDelay: " + string( replayDelay ) )
	//print( "gameWonByEarnScore: " + string( file.gameWonByEarnScore ) )

	float replayLength = Time() - file.roundWinningKillReplayTimeOfDeath
	bool doReplay = file.gameWonByEarnScore // we only do replay if game wins by player earning score
					// generic checks
					&& Replay_IsEnabled() 
					&& IsRoundWinningKillReplayEnabled() 
					// replay attacker validation checks
					&& file.roundWinningKillReplayAttackerEHandle != -1
					&& file.roundWinningKillReplayAttackerIndex != -1
					// never play a replay that is too old
					&& replayDelay > 0 
					&& replayDelay <= ROUND_WINNING_KILL_REPLAY_MAX_DELAY

	if ( doReplay )
	{
		// pre setup for round end cleaning
		RoundCleanUpPreSetUp()
		
		//print( "replayLength: " + string( replayLength ) )
		file.numPlayersFinishedWatchingReplay = 0
		int waitForNumPlayersFinishReplay = 0
		foreach ( entity player in GetPlayerArray() )
		{
			// switching sides replay should have an extra delay for "HALFTIME" notification to display!
			thread PlayerWatchesRoundWinningKillReplay( player, ROUND_WINNING_KILL_REPLAY_EXTRA_DELAY_SWITCHING_SIDES )
			waitForNumPlayersFinishReplay++
		}

		// wait for all players finish watching replay
		while ( file.numPlayersFinishedWatchingReplay < waitForNumPlayersFinishReplay )
		{
			WaitFrame()
		}

		// prepare to cleanup
		wait SWITCH_SIDE_CLEANUP_WAIT
		CleanUpEntitiesForRoundEnd() // fade should be done by this point, so cleanup stuff now when people won't see
	}
	else
	{
		// pre setup for round end cleaning
		RoundCleanUpPreSetUp()

		foreach( entity player in GetPlayerArray() )
		{
			// no replay specific: fade out sound for player
			MuteHalfTime( player )
			ScreenFadeToBlackForever( player, SWITCH_SIDE_CLEANUP_WAIT )
		}
		
		wait SWITCH_SIDE_EXTRA_WAIT_NO_REPLAY // if no replay playing, we wait a bit more

		wait SWITCH_SIDE_CLEANUP_WAIT
		CleanUpEntitiesForRoundEnd() // fade should be done by this point, so cleanup stuff now when people won't see
	}

	// wait for transition
	if ( doReplay )
	{
		// switching sides specific: set player back to intermission cam if we did replay
		wait SWITCH_SIDE_INTERMISSION_CAM_DELAY
		foreach ( entity player in GetPlayerArray() )
		{
			player.ClearReplayDelay()
			player.ClearViewEntity()
			SetPlayerCameraToIntermissionCam( player ) // set back to intermission cam
		}

		wait SWITCH_SIDE_TRANSITION_DELAY
	}
	else
	{
		wait SWITCH_SIDE_TRANSITION_DELAY_NO_REPLAY

		foreach ( entity player in GetPlayerArray() )
		{
			// clear sound fade on player
			UnMuteAll( player )
		}
	}

	// reset stuffs here
	if ( killcamsWereEnabled )
		SetKillcamsEnabled( true )
	if ( respawnsWereEnabled )
		SetRespawnsEnabled( true )

	if ( file.usePickLoadoutScreen ) // here we just doing round transition, no need to enable pickloadout for intro stuffs, only for titan menu
		SetGameState( eGameState.PickLoadout )
	else
		SetGameState ( eGameState.Prematch )
}

// why do we ever need to split this function from roundwinning kill replay?
// need to rework on it
// rework done, abandoned
/*
void function PlayerWatchesSwitchingSidesKillReplay( entity player, int inflictorEHandle, entity replayAttacker, entity replayVictim, bool doReplay, float replayLength ) // ( entity player, float replayLength )
{
	player.EndSignal( "OnDestroy" )
	player.FreezeControlsOnServer()

	if( doReplay )
	{
		// get index before attacker gets destroyed
		int attackerEHandle = replayAttacker.GetEncodedEHandle()
		int attackerIndex = replayAttacker.GetIndexForEntity()
		// setup victim before it gets destroyed
		if ( IsValid( replayVictim ) ) // victim can be invalid if we're only using attacker view
			player.SetKillReplayVictim( replayVictim )

		ScreenFadeToBlackForever( player, ROUND_WINNING_KILL_REPLAY_SCREEN_FADE_TIME ) // automatically cleared 
		wait ROUND_WINNING_KILL_REPLAY_SCREEN_FADE_TIME
	
		//player.SetPredictionEnabled( false ) // prediction fucks with replays
		player.SetPredictionEnabled( true ) // should we enable prediction on killreplay?
	
		// delay seems weird for switchingsides? ends literally the frame the flag is collected

		// don't get attacker from here since it has been delayed, pass from GameStateEnter_SwitchingSides_Threaded()
		//entity attacker = file.roundWinningKillReplayAttacker
		//entity victim = file.roundWinningKillReplayVictim

		float totalTime = replayLength + ROUND_WINNING_KILL_REPLAY_SCREEN_FADE_TIME
		float replayDelay = Time() - totalTime
		if( replayDelay <= 0 )
			replayDelay = 0
		//player.SetKillReplayDelay( Time() - replayLength, THIRD_PERSON_KILL_REPLAY_ALWAYS )
		player.SetKillReplayDelay( replayDelay, THIRD_PERSON_KILL_REPLAY_ALWAYS )
		if ( inflictorEHandle == -1 ) // invalid ehandle!
			inflictorEHandle = attackerEHandle // just assign attacker as inflictor!
		player.SetKillReplayInflictorEHandle( inflictorEHandle )
		player.SetViewIndex( attackerIndex )
		player.SetIsReplayRoundWinning( true )
		
		float finalWait = replayLength - 2.0
		if( finalWait <= 0 )
			finalWait = 0.0
		wait finalWait
		ScreenFadeToBlackForever( player, 2.0 )

		wait 2.0 // 2.0 is equal as SWITCHING_SIDES_DELAY_REPLAY

		wait GAME_POSTROUND_CLEANUP_WAIT // bit nicer to match GameStateEnter_SwitchingSides_Threaded() does
	}
	else // no replay valid
	{
		ScreenFadeToBlackForever( player, ROUND_WINNING_KILL_REPLAY_SCREEN_FADE_TIME ) // automatically cleared 
		wait ROUND_WINNING_KILL_REPLAY_SCREEN_FADE_TIME

		wait SWITCHING_SIDES_DELAY // extra delay if no replay
	}
	
	//player.SetPredictionEnabled( true ) doesn't seem needed, as native code seems to set this on respawn
	//player.ClearReplayDelay() // these has been done in CPlayer::RespawnPlayer()
	//player.ClearViewEntity()
}
*/

// eGameState.SuddenDeath
void function GameStateEnter_SuddenDeath()
{
	// disable respawns, suddendeath calling is done on a kill callback
	SetRespawnsEnabled( false )
	file.enteredSuddenDeath = true
	
	// sudden-death really begins
	foreach( entity player in GetPlayerArray() )
		PlaySuddenDeathDialogueBasedOnFaction( player )

	// actually this can cause sudden death to stuck... don't know how to work around server Vars
	//thread SuddenDeathCheckAnyPlayerAlive()
}

// returns false if sudden death no longer a valid gamestate
bool function SuddenDeathCheckTeamPlayers()
{
	if ( IsFFAGame() ) // ffa variant
	{
		array<int> teamsWithLivingPlayers
		foreach ( entity player in GetPlayerArray_Alive() )
		{
			if ( !teamsWithLivingPlayers.contains( player.GetTeam() ) )
				teamsWithLivingPlayers.append( player.GetTeam() )
		}
		
		if ( teamsWithLivingPlayers.len() == 1 )
		{
			SetWinner( teamsWithLivingPlayers[ 0 ], "#GAMEMODE_ENEMY_PILOTS_ELIMINATED", "#GAMEMODE_FRIENDLY_PILOTS_ELIMINATED" )
			return false
		}
		else if ( teamsWithLivingPlayers.len() == 0 ) // failsafe: only team was the dead one
		{
			SetWinner( TEAM_UNASSIGNED ) // this is fine in ffa
			return false
		}
	}
	else
	{
		bool mltElimited = false
		bool imcElimited = false
		if( GetPlayerArrayOfTeam_Alive( TEAM_MILITIA ).len() < 1 )
			mltElimited = true
		if( GetPlayerArrayOfTeam_Alive( TEAM_IMC ).len() < 1 )
			imcElimited = true

		if( mltElimited && imcElimited )
		{
			SetWinner( TEAM_UNASSIGNED )
			return false
		}
		else if( mltElimited )
		{
			SetWinner( TEAM_IMC, "#GAMEMODE_ENEMY_PILOTS_ELIMINATED", "#GAMEMODE_FRIENDLY_PILOTS_ELIMINATED" )
			return false
		}
		else if( imcElimited )
		{
			SetWinner( TEAM_MILITIA, "#GAMEMODE_ENEMY_PILOTS_ELIMINATED", "#GAMEMODE_FRIENDLY_PILOTS_ELIMINATED" )
			return false
		}
	}

	return true
}

void function SuddenDeathCheckAnyPlayerAlive()
{
	// debug
	print( "RUNNING SuddenDeathCheckAnyPlayerAlive()" )

	//svGlobal.levelEnt.EndSignal( "GameStateChanged" )

	OnThreadEnd
	(
		function(): ()
		{
			print( "SuddenDeathCheckAnyPlayerAlive() Ends!" )
		}
	)

	wait 10 // initial wait before deciding winner
	while( true )
	{
		WaitFrame()

		if ( !SuddenDeathCheckTeamPlayers() )
			return
	}
}

// returns false if game can end without entering sudden death
bool function CanGameProcessToSuddenDeath()
{
	if ( IsFFAGame() ) // ffa variant
	{
		array<int> teamsNotEmpty
		foreach ( entity player in GetPlayerArray() )
		{
			if ( !teamsNotEmpty.contains( player.GetTeam() ) )
				teamsNotEmpty.append( player.GetTeam() )
		}
		
		if ( teamsNotEmpty.len() == 1 )
		{
			SetWinner( teamsNotEmpty[ 0 ], "#GAMEMODE_ENEMY_PILOTS_ELIMINATED", "#GAMEMODE_FRIENDLY_PILOTS_ELIMINATED" )
			return false
		}
		else if ( teamsNotEmpty.len() == 0 ) // failsafe: no teams alive for ffa sudden death
		{
			SetWinner( TEAM_UNASSIGNED ) // this is fine in ffa
			return false
		}
	}
	else
	{
		bool mltTeamEmpty = false
		bool imcTeamEmpty = false
		if( GetPlayerArrayOfTeam( TEAM_MILITIA ).len() < 1 )
			mltTeamEmpty = true
		if( GetPlayerArrayOfTeam( TEAM_IMC ).len() < 1 )
			imcTeamEmpty = true

		if( mltTeamEmpty && imcTeamEmpty )
		{
			SetWinner( TEAM_UNASSIGNED )
			return false
		}
		else if( mltTeamEmpty )
		{
			SetWinner( TEAM_IMC, "#GAMEMODE_ENEMY_PILOTS_ELIMINATED", "#GAMEMODE_FRIENDLY_PILOTS_ELIMINATED" )
			return false
		}
		else if( imcTeamEmpty )
		{
			SetWinner( TEAM_MILITIA, "#GAMEMODE_ENEMY_PILOTS_ELIMINATED", "#GAMEMODE_FRIENDLY_PILOTS_ELIMINATED" )
			return false
		}
	}

	return true
}

// respawn didn't register this, doing it myself
void function PlaySuddenDeathDialogueBasedOnFaction( entity player )
{
	switch( GetFactionChoice( player ) )
	{
		case "faction_marauder":
			EmitSoundOnEntityOnlyToPlayer( player, player, "diag_mcor_sarah_mp_suddenDeath" )
			return
		case "faction_apex":
			EmitSoundOnEntityOnlyToPlayer( player, player, "diag_imc_blisk_mp_suddenDeath" )
			return
		case "faction_vinson":
			EmitSoundOnEntityOnlyToPlayer( player, player, "diag_imc_ash_mp_suddenDeath" )
			return
		case "faction_aces":
			EmitSoundOnEntityOnlyToPlayer( player, player, "diag_mcor_barker_mp_suddenDeath" )
			return
		case "faction_64":
			EmitSoundOnEntityOnlyToPlayer( player, player, "diag_mcor_gates_mp_suddenDeath" )
			return
		case "faction_ares":
			EmitSoundOnEntityOnlyToPlayer( player, player, "diag_imc_marder_mp_suddenDeath" )
			return
		case "faction_marvin":
			EmitSoundOnEntityOnlyToPlayer( player, player, "diag_mcor_marvin_mp_suddenDeath" )
			return
	}
}

// eGameState.Postmatch
void function GameStateEnter_Postmatch()
{
	// disable any pending kill replay
	SetKillcamsEnabled( false )
	// disable respawn
	SetRespawnsEnabled( false )
	// setup stuffs before clean up starts
	MatchCleanUpPreSetUp()

	thread PostMatchForceFadeToBlack()
		
	thread GameStateEnter_Postmatch_Threaded()
}

void function GameStateEnter_Postmatch_Threaded()
{
	wait MATCH_CLEANUP_WAIT // wait for fade

	CleanUpEntitiesForMatchEnd() // match really ends, clean up stuffs

	wait GAME_POSTMATCH_LENGTH - MATCH_CLEANUP_WAIT

	GameRules_EndMatch()
}

void function PostMatchForceFadeToBlack()
{
	// keep make player blacking out to darkness
	// fadeout any sound playing on a player
	while ( true )
	{
		foreach ( entity player in GetPlayerArray() )
		{
			ScreenFadeToBlackForever( player, MATCH_CLEANUP_WAIT )

			if ( !( "didSoundFadeout" in player.s ) )
				player.s.didSoundFadeout <- false
			if ( !player.s.didSoundFadeout )
			{
				// vanilla behavior. take 4s to fadeout all sounds
				MuteAll( player, 4 )
				player.s.didSoundFadeout = true
			}
		}

		WaitFrame()
	}
}

// shared across multiple gamestates
void function OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	// no need to do frame checks
	/*
	if ( !GamePlayingOrSuddenDeath() )
	{
		if ( file.gameWonThisFrame )
		{
			if ( file.hasKillForGameWonThisFrame )
				return
		}
		else
			return
	}
	*/

	//if ( ( Riff_EliminationMode() == eEliminationMode.Titans || Riff_EliminationMode() == eEliminationMode.PilotsTitans ) && victim.IsTitan() ) // need an extra check for this
	if ( victim.IsTitan() )
		OnTitanKilled( victim, damageInfo )	
	else // pilot player
	{
		// set round winning killreplay from damageInfo
		// titan player setup is handled in OnTitanKilled(), but actually works fine if we run it twice
		SetUpRoundWinningKillReplayFromDamageInfo( victim, damageInfo )
	}

	// checks below should only in playing or sudden death state
	if ( GamePlayingOrSuddenDeath() )
	{
		CheckSuddenDeathPlayers( victim )
	}
}

void function CheckSuddenDeathPlayers( entity victim )
{
	// note: pilotstitans is just win if enemy team runs out of either pilots or titans
	if ( IsPilotEliminationBased() || GetGameState() == eGameState.SuddenDeath )
	{
		//if ( GetPlayerArrayOfTeam_Alive( victim.GetTeam() ).len() == 0 )
		if ( GetPlayerArrayOfTeam_Alive( victim.GetTeam() ).len() == 0 )
		{
			if ( !SuddenDeathCheckTeamPlayers()	)
			{
				// we only do replay if game wins by player earning score
				MarkAsGameWinsByEarnScore()
			}
		}
	}
}

void function OnTitanKilled( entity victim, var damageInfo )
{
	// no need to do frame checks
	/*
	if ( !GamePlayingOrSuddenDeath() )
	{
		if ( file.gameWonThisFrame )
		{
			if ( file.hasKillForGameWonThisFrame )
				return
		}
		else
			return
	}
	*/

	// set round winning killreplay from damageInfo
	SetUpRoundWinningKillReplayFromDamageInfo( victim, damageInfo )
	
	// checks below should only in playing or sudden death state
	if ( GamePlayingOrSuddenDeath() )
	{
		CheckTitanEliminationPlayers( victim )
	}
}

void function CheckTitanEliminationPlayers( entity victim )
{
	// note: pilotstitans is just win if enemy team runs out of either pilots or titans
	if ( IsTitanEliminationBased() )
	{
		int livingTitans
		foreach ( entity titan in GetTitanArrayOfTeam( victim.GetTeam() ) )
			livingTitans++
	
		if ( livingTitans == 0 )
		{
			// for ffa we need to manually get the last team alive 
			if ( IsFFAGame() )
			{
				array<int> teamsWithLivingTitans
				foreach ( entity titan in GetTitanArray() )
				{
					if ( !teamsWithLivingTitans.contains( titan.GetTeam() ) )
						teamsWithLivingTitans.append( titan.GetTeam() )
				}
				
				if ( teamsWithLivingTitans.len() == 1 )
				{
					SetWinner( teamsWithLivingTitans[ 0 ], "#GAMEMODE_ENEMY_TITANS_DESTROYED", "#GAMEMODE_FRIENDLY_TITANS_DESTROYED" )
				
					// we only do replay if game wins by player earning score
					MarkAsGameWinsByEarnScore()
				}
				else if ( teamsWithLivingTitans.len() == 0 ) // failsafe: only team was the dead one
					SetWinner( TEAM_UNASSIGNED ) // this is fine in ffa
			}
			else
			{
				SetWinner( GetOtherTeam( victim.GetTeam() ), "#GAMEMODE_ENEMY_TITANS_DESTROYED", "#GAMEMODE_FRIENDLY_TITANS_DESTROYED" )
			
				// we only do replay if game wins by player earning score
				MarkAsGameWinsByEarnScore()
			}
		}
	}
}

void function AddCallback_OnRoundEndCleanup( void functionref() callback )
{
	file.roundEndCleanupCallbacks.append( callback )
}

// new adding
void function AddCallback_OnMatchEndCleanup( void functionref() callback )
{
	file.matchEndCleanupCallbacks.append( callback )
}

// before cleanup, we should setup some stuff
// for round end
void function RoundCleanUpPreSetUp()
{
	foreach ( entity player in GetPlayerArray() )
	{
		// disable player's movements
		player.FreezeControlsOnServer()
		if ( IsAlive( player ) )
			player.SetInvulnerable() // player no longer dies from here( unless they fall off cliff )
		// shared from _base_gametype_mp.gnut, stop any kill replay playing
		StopKillReplayForPlayer( player )
		// respawn disallowed
		ClearRespawnAvailable( player )
	}
}

// for match end
void function MatchCleanUpPreSetUp()
{
	foreach ( entity player in GetPlayerArray() )
	{
		// disable player's movements
		player.FreezeControlsOnServer()
		if ( IsAlive( player ) )
			player.SetInvulnerable() // player no longer dies from here( unless they fall off cliff )
		// shared from _base_gametype_mp.gnut, stop any kill replay playing
		StopKillReplayForPlayer( player )
		// respawn disallowed
		ClearRespawnAvailable( player )
	}
}

void function CleanUpEntitiesForRoundEnd()
{
	// this function should clean up any and all entities that need to be removed between rounds, ideally at a point where it isn't noticable to players
	bool deathsIsHidden = IsPlayerDeathsHidden() // new adding function
	SetPlayerDeathsHidden( true ) // hide death sounds and such so people won't notice they're dying
	
	// clean up replay stuffs
	RoundWinningKillReplayCleanUp()

	foreach ( entity player in GetPlayerArray() )
	{
		ClearTitanAvailable( player )
		PROTO_CleanupTrackedProjectiles( player )
		player.SetPlayerNetInt( "batteryCount", 0 ) 
		if ( IsAlive( player ) )
		{
			// debug
			//print( "Try to kill player: " + string( player ) )
			player.Die( svGlobal.worldspawn, svGlobal.worldspawn, { damageSourceId = eDamageSourceId.round_end } )
			player.BecomeRagdoll( < 0,0,0 >, false ) // drop weapons immediately
		}
		// spectator player: needs to stop their spec mode on clean up
		// otherwise when they respawn, they get weird camera forever
		if ( Spectator_IsPlayerSpectating( player ) )
		{
			Spectator_StopPlayerSpectating( player )
			SetPlayerCameraToIntermissionCam( player ) // set back to intermission cam
		}

		player.UnfreezeControlsOnServer() // freeze should be cleared here
	}
	
	foreach ( entity npc in GetNPCArray() )
	{
		if ( !IsValid( npc ) || !IsAlive( npc ) )
			continue	
		// kill rather than destroy, as destroying will cause issues with children which is an issue especially for dropships and titans
		// this also happens when npc.BecomeRagdoll() as ragdoll a npc meaning destroy them on server
		npc.e.forceRagdollDeath = true // proper way to make a npc become ragdoll on death, handled by HandleDeathPackage()
		npc.Die( svGlobal.worldspawn, svGlobal.worldspawn, { damageSourceId = eDamageSourceId.round_end } )
	}
	
	// destroy weapons
	ClearDroppedWeapons()
	
	// clean up batteries
	foreach ( entity battery in GetEntArrayByClass_Expensive( "item_titan_battery" ) )
		battery.Destroy()
	
	// allow other scripts to clean stuff up too
	svGlobal.levelEnt.Signal( "CleanUpEntitiesForRoundEnd" ) 
	// Added via AddCallback_OnRoundEndCleanup()
	foreach ( void functionref() callback in file.roundEndCleanupCallbacks )
		callback()
	
	//SetPlayerDeathsHidden( false )
	SetPlayerDeathsHidden( deathsIsHidden ) // restore death hidden effect
}

void function CleanUpEntitiesForMatchEnd()
{
	// don't let players die if we're not roundbased! showing a better scoreboard
	foreach ( entity player in GetPlayerArray() )
	{
		ClearTitanAvailable( player )
		PROTO_CleanupTrackedProjectiles( player )
		if ( IsAlive( player ) )
			player.SetInvulnerable() // player no longer dies from here( unless they fall off cliff )
	}

	// freeze all npcs instead of killing them
	// match already end and there's no need we clean them up
	thread FreezeAllNPCsForMatchEnd()
	
	// destroy weapons
	ClearDroppedWeapons()
	
	// clean up batteries
	foreach ( entity battery in GetEntArrayByClass_Expensive( "item_titan_battery" ) )
		battery.Destroy()
	
	// allow other scripts to clean stuff up too
	svGlobal.levelEnt.Signal( "CleanUpEntitiesForMatchEnd" )
	// Added via AddCallback_OnMatchEndCleanup()
	foreach ( void functionref() callback in file.matchEndCleanupCallbacks )
		callback()
}

void function FreezeAllNPCsForMatchEnd()
{
	while ( true )
	{
		foreach ( entity npc in GetNPCArray() )
		{
			if ( !IsValid( npc ) || !IsAlive( npc ) )
				continue
			if ( !npc.IsFrozen() )
				npc.Freeze()
			if ( !npc.IsInvulnerable() )
				npc.SetInvulnerable() // npc no longer dies from here
		}

		WaitFrame()
	}
}

// stuff for gamemodes to call

void function SetShouldUsePickLoadoutScreen( bool shouldUse )
{
	file.usePickLoadoutScreen = shouldUse
}

void function SetSwitchSidesBased( bool switchSides )
{
	file.switchSidesBased = switchSides

	// In vanilla the level.nv.switchSides only inited when gamemode is actually using switch sides, or the function IsSwitchSidesBased() from _utility_shared.nut will always return a "true"!
	if ( switchSides )
		SetServerVar( "switchedSides", 0 )
	else
		SetServerVar( "switchedSides", null )
}

void function SetSuddenDeathBased( bool suddenDeathBased )
{
	file.suddenDeathBased = suddenDeathBased
}

void function SetTimerBased( bool timerBased )
{
	file.timerBased = timerBased
}

void function SetShouldUseRoundWinningKillReplay( bool shouldUse )
{
	SetServerVar( "roundWinningKillReplayEnabled", shouldUse )
}

bool function IsSwitchSidesBased_NorthStar()
{
	return file.switchSidesBased
}

void function SetRoundWinningKillReplayKillClasses( bool pilot, bool titan )
{
	file.roundWinningKillReplayTrackPilotKills = pilot
	file.roundWinningKillReplayTrackTitanKills = titan // player kills in titans should get tracked anyway, might be worth renaming this
}

void function SetRoundWinningKillReplayAttacker( entity attacker )
{
	//file.roundWinningKillReplayTime = Time() // doesn't seem needed...
	file.roundWinningKillReplayHealthFrac = GetHealthFrac( attacker )
	// reworked to use index directly...
	//file.roundWinningKillReplayAttacker = attacker
	file.roundWinningKillReplayAttackerIndex = attacker.GetIndexForEntity()
	file.roundWinningKillReplayAttackerEHandle = attacker.GetEncodedEHandle()
	file.roundWinningKillReplayTimeOfDeath = Time()
	// replay tracker
	table replayTracker = { validTime = null }
	thread TrackDestroyTimeForReplay( attacker, replayTracker )
	file.roundWinningKillReplayTracker = replayTracker
}

void function SetRoundWinningHighlightReplayPlayer( entity player )
{
	// we watch highlight player's view
	SetRoundWinningKillReplayAttacker( player )
	// setup replay length
	file.roundWinningKillReplayLength = ROUND_WINNING_HIGHLIGHT_REPLAY_DURATION
	file.roundWinningKillReplayTimeSinceAttackerSpawned = GetReplayTimeSinceAttackerSpawned( player ) // shared from _base_gametype_mp.gnut
	file.roundWinningKillReplayBeforeTime = ROUND_WINNING_HIGHLIGHT_REPLAY_DURATION // beforeTime is the actual replay time

	// mark as we've setup replay
	// replay can still be refreshed by another SetRoundWinningHighlightReplayPlayer()
	// but prevents SetUpRoundWinningKillReplayFromDamageInfo() from setup again
	// no need to do frame checks
	//if ( file.gameWonThisFrame )
	//	file.hasKillForGameWonThisFrame = true
	file.roundWinningKillReplayHasSetUp = true
}

// fix for projectile kill replay
// inflictor isn't necessary, we could just return if inflictor not valid
void function SetRoundWinningKillReplayInflictor( entity inflictor )
{
	if ( !IsValid( inflictor ) ) // have to do IsValid() check for inflictors
		return

	if ( inflictor.IsProjectile() && inflictor.GetProjectileWeaponSettingBool( eWeaponVar.projectile_killreplay_enabled ) )
		file.roundWinningKillReplayInflictorEHandle = inflictor.GetEncodedEHandle()
}

// generic setup if we have damageInfo
void function SetUpRoundWinningKillReplayFromDamageInfo( entity victim, var damageInfo )
{
	// most important check
	if ( !victim.IsPlayer() )
		return
	
	// don't setup multiple times
	if ( file.roundWinningKillReplayHasSetUp )
		return

	// general checks
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) )
		return
	// replay only valid for player or npc as attacker
	if ( !attacker.IsPlayer() && !attacker.IsNPC() )
		return

	// suicide
	if ( victim == attacker )
		return
	// if we only track titan kills, but attacker isn't titan
	if ( file.roundWinningKillReplayTrackTitanKills && !attacker.IsTitan() )
		return
	// if we only track pilot kills, but attacker is titan or npc
	if ( file.roundWinningKillReplayTrackPilotKills && ( attacker.IsTitan() || attacker.IsNPC() ) )
		return

	int methodOfDeath = DamageInfo_GetDamageSourceIdentifier( damageInfo )
	float replayLength = CalculateLengthOfKillReplay( victim, methodOfDeath )
	// need to do ShouldDoReplay() checks
	if ( !ShouldDoReplay( victim, attacker, replayLength, methodOfDeath ) )
		return

	// all checks passed, do replay stuffs
	file.roundWinningKillReplayVictim = victim
	// setup attacker
	SetRoundWinningKillReplayAttacker( attacker )
	file.roundWinningKillReplayMethodOfDeath = methodOfDeath
	file.roundWinningKillReplayHealthFrac = GetHealthFrac( attacker )
	// setup inflictor
	SetRoundWinningKillReplayInflictor( DamageInfo_GetInflictor( damageInfo ) ) // inflictor isn't necessary, it's function has IsValid() checks

	// setup replay length
	file.roundWinningKillReplayLength = replayLength
	file.roundWinningKillReplayTimeOfDeath = Time()
	file.roundWinningKillReplayTimeSinceAttackerSpawned = GetReplayTimeSinceAttackerSpawned( attacker ) // shared from _base_gametype_mp.gnut
	file.roundWinningKillReplayBeforeTime = GetKillReplayBeforeTime( victim, methodOfDeath ) + ROUND_WINNING_KILL_REPLAY_EXTRA_BEFORE_TIME // beforeTime is the actual replay length

	// mark as we've setup replay
	// no need to do frame checks
	//if ( file.gameWonThisFrame )
	//	file.hasKillForGameWonThisFrame = true
	file.roundWinningKillReplayHasSetUp = true
}

void function RoundWinningKillReplayCleanUp()
{
	file.roundWinningKillReplayVictim = null

	file.roundWinningKillReplayAttackerIndex = -1
	file.roundWinningKillReplayAttackerEHandle = -1
	file.roundWinningKillReplayInflictorEHandle = -1
	file.roundWinningKillReplayMethodOfDeath = -1
	file.roundWinningKillReplayHealthFrac = 0.0
	
	file.roundWinningKillReplayLength = 0.0
	file.roundWinningKillReplayTimeSinceAttackerSpawned = 0.0
	file.roundWinningKillReplayTimeOfDeath = 0.0
	file.roundWinningKillReplayBeforeTime = 0.0
	file.roundWinningKillReplayTracker = {}

	file.numPlayersFinishedWatchingReplay = 0


	file.roundWinningKillReplayHasSetUp = false
}


void function SetWinner( int team, string winningReason = "", string losingReason = "" )
{	
	SetServerVar( "winningTeam", team )
	
	// no need to do frame checks
	//file.gameWonThisFrame = true
	//thread UpdateGameWonThisFrameNextFrame()
	
	if ( winningReason.len() == 0 )
		file.announceRoundWinnerWinningSubstr = 0
	else
		file.announceRoundWinnerWinningSubstr = GetStringID( winningReason )
	
	if ( losingReason.len() == 0 )
		file.announceRoundWinnerLosingSubstr = 0
	else
		file.announceRoundWinnerLosingSubstr = GetStringID( losingReason )
	
	if ( GamePlayingOrSuddenDeath() )
	{
		SetGameState( eGameState.WinnerDetermined )
	}
}

// no need to do frame checks
/*
void function UpdateGameWonThisFrameNextFrame()
{
	WaitFrame()
	file.gameWonThisFrame = false
	file.hasKillForGameWonThisFrame = false
}
*/

void function AddTeamScore( int team, int amount )
{
	// using "fixAmount" now
	//GameRules_SetTeamScore( team, GameRules_GetTeamScore( team ) + amount )
	//GameRules_SetTeamScore2( team, GameRules_GetTeamScore2( team ) + amount )

	if( !GamePlayingOrSuddenDeath() ) // don't add score in other states!
		return

	int score = GameRules_GetTeamScore( team )
	int scoreLimit
	if ( IsRoundBased() )
		scoreLimit = GameMode_GetRoundScoreLimit( GAMETYPE )
	else
		scoreLimit = GameMode_GetScoreLimit( GAMETYPE )
	int maxScoreLimit = scoreLimit // prevent switch sides with less than 3 max score

	// switchsides based
	if ( file.switchSidesBased && !file.hasSwitchedSides )
		scoreLimit = int( scoreLimit.tofloat() / 2.0 ) + 1

	// debug
	//print( "maxScoreLimit: " + string( maxScoreLimit ) )
	//print( "scoreLimit: " + string( scoreLimit ) )

	int fixedAmount = score + amount > scoreLimit ? scoreLimit - score : amount

	GameRules_SetTeamScore( team, GameRules_GetTeamScore( team ) + fixedAmount )
	GameRules_SetTeamScore2( team, GameRules_GetTeamScore2( team ) + amount ) // round score is no need to use fixedAmount

	//int score = GameRules_GetTeamScore( team ) // moved up to make use of it
	score = GameRules_GetTeamScore( team ) // update score earned

	if ( score >= scoreLimit ) // score limit reached!
	{
		if ( file.switchSidesBased && !file.hasSwitchedSides && ( maxScoreLimit != scoreLimit ) )
			SetGameState( eGameState.SwitchingSides )
		else // default
			SetWinner( team, "#GAMEMODE_SCORE_LIMIT_REACHED", "#GAMEMODE_SCORE_LIMIT_REACHED" )

		// we only do replay if game wins by player earning score
		MarkAsGameWinsByEarnScore()
	}
	else if ( GetGameState() == eGameState.SuddenDeath ) // in sudden death, game ends when a team earns score
	{
		SetWinner( team, "#GAMEMODE_SCORE_LIMIT_REACHED", "#GAMEMODE_SCORE_LIMIT_REACHED" )
	
		// we only do replay if game wins by player earning score
		MarkAsGameWinsByEarnScore()
	}
}

// we only do replay if game wins by player earning score
void function MarkAsGameWinsByEarnScore()
{
	if ( file.gameWonByEarnScore )
		return
	
	file.gameWonByEarnScore = true
	thread MarkAsGameWinsByEarnScore_Threaded()
}

void function MarkAsGameWinsByEarnScore_Threaded()
{
	svGlobal.levelEnt.WaitSignal( "GameStateChanged" ) // wait for other codes running through
	file.gameWonByEarnScore = false
}

void function SetTimeoutWinnerDecisionFunc( int functionref() callback )
{
	file.timeoutWinnerDecisionFunc = callback
}

void function SetTimeoutWinnerDecisionReason( string winningReason, string losingReason )
{
	file.timeoutWinningReason = winningReason
	file.timeoutLosingReason = losingReason
}

// using a struct so we can sort them
struct TeamScoreStruct
{
	int team
	int score
}

int function GetWinningTeamWithFFASupport( int ffaTeamPlace = 1 ) // by default we return the team that places at 1st
{
	if ( !IsFFAGame() )
		return GameScore_GetWinningTeam() // GetWinningTeam() won't be setup if we're not assigning networkvar "winningTeam" yet, needs to use score checks
	else
	{
		// custom logic for calculating ffa winner as GameScore_GetWinningTeam doesn't handle this
		// trying to implement sorted team score...
		/*
		int winningTeam = TEAM_UNASSIGNED
		int winningScore = 0
		
		foreach ( entity player in GetPlayerArray() )
		{
			int currentScore = GameRules_GetTeamScore( player.GetTeam() )
			
			if ( currentScore == winningScore )
				winningTeam = TEAM_UNASSIGNED // if 2 teams are equal, return TEAM_UNASSIGNED
			else if ( currentScore > winningScore )
			{
				winningTeam = player.GetTeam()
				winningScore = currentScore
			}
		}

		return winningTeam
		*/
		int winningTeam = TEAM_UNASSIGNED
		int winningScore = 0
		array<TeamScoreStruct> teamScoreValues
		foreach ( entity player in GetPlayerArray() )
		{
			int playerTeam = player.GetTeam()
			int playerScore = GameRules_GetTeamScore( playerTeam )
			
			if ( playerScore == winningScore )
				winningTeam = TEAM_UNASSIGNED // if 2 teams are equal, return TEAM_UNASSIGNED
			else if ( playerScore > winningScore )
			{
				winningTeam = player.GetTeam()
				winningScore = playerScore
			}

			TeamScoreStruct teamStruct
			teamStruct.team = playerTeam
			teamStruct.score = playerScore
			teamScoreValues.append( teamStruct )
		}

		if ( winningTeam == TEAM_UNASSIGNED ) // if 2 teams are equal or no team to compare, return TEAM_UNASSIGNED
			return TEAM_UNASSIGNED
		else
		{
			teamScoreValues.sort( CompareTeamScore )

			// debug
			/*
			print( "sorted team numbers:" )
			foreach ( TeamScoreStruct teamStruct in teamScoreValues )
			{
				print( "team number: " + string( teamStruct.team ) )
				print( "team score: " + string( teamStruct.score ) )
			}
			*/
			//

			if ( teamScoreValues.len() >= ffaTeamPlace )
				return teamScoreValues[ ffaTeamPlace - 1 ].team
			else
				return teamScoreValues[ 0 ].team // if no enough teams to compare, just return 1st team
		}
	}
	
	unreachable
}

int function CompareTeamScore( TeamScoreStruct team1, TeamScoreStruct team2 )
{
	if ( team1.score > team2.score )
		return -1 // move higher score up
	else if ( team1.score < team2.score )
		return 1

	return 0
}

// idk

float function GameState_GetTimeLimitOverride()
{
	return 100
}

bool function IsRoundBasedGameOver()
{
	return false
}

bool function ShouldRunEvac()
{
	return true
}

void function GiveTitanToPlayer( entity player )
{

}

float function GetTimeLimit_ForGameMode()
{
	string mode = GameRules_GetGameMode()
	string playlistString = "timelimit"

	// default to 10 mins, because that seems reasonable
	return GetCurrentPlaylistVarFloat( playlistString, 10 )
}

// faction dialogue
void function DialoguePlayNormal()
{
	svGlobal.levelEnt.EndSignal( "GameStateChanged" )

	const float DIALOGUE_INTERVAL = 181 // play a faction dailogue every 180 + 1s to prevent play together with winner dialogue

	while( GetGameState() == eGameState.Playing )
	{
		// generally we start from 0:0 score, no dialogue will be played. but for round based gamemodes, this will play a dialogue on round start
		PlayScoreEventFactionDialogue( "winningLarge", "losingLarge", "winning", "losing", "winningClose", "losingClose" )
		wait DIALOGUE_INTERVAL // wait before playing next dialogue
	}
}

void function DialoguePlayWinnerDetermined()
{
	int winningTeam = TEAM_UNASSIGNED

	if( file.enteredSuddenDeath && !IsFFAGame() || !RespawnsEnabled() ) // respawn not enabled, or game in sudden death
	{
		if( GetPlayerArrayOfTeam_Alive( TEAM_MILITIA ).len() > GetPlayerArrayOfTeam_Alive( TEAM_IMC ).len() )
			winningTeam = TEAM_MILITIA
		else if( GetPlayerArrayOfTeam_Alive( TEAM_MILITIA ).len() < GetPlayerArrayOfTeam_Alive( TEAM_IMC ).len() )
			winningTeam = TEAM_IMC

		if( winningTeam > TEAM_UNASSIGNED )
		{
			PlayFactionDialogueToTeam( "scoring_won" , winningTeam )
			PlayFactionDialogueToTeam( "scoring_lost", GetOtherTeam( winningTeam ) )
		}
		return
	}

	PlayScoreEventFactionDialogue( "wonMercy", "lostMercy", "won", "lost", "wonClose", "lostClose", "tied" )
}

void function PlayScoreEventFactionDialogue( string winningLarge, string losingLarge, string winning, string losing, string winningClose, string losingClose, string tied = "" )
{
	// new setting!
	if ( !file.scoreEventDialogue )
		return

	int totalScore = GameMode_GetScoreLimit( GAMETYPE )
	if( IsRoundBased() )
		totalScore = GameMode_GetRoundScoreLimit( GAMETYPE )

	// FFA variant
	if ( IsFFAGame() )
	{
		int winningTeam = GetWinningTeamWithFFASupport()
		if ( winningTeam > TEAM_UNASSIGNED ) // returns TEAM_UNASSIGNED means score tied
		{
			int winningTeamScore = GameRules_GetTeamScore( winningTeam )
			
			foreach ( entity player in GetPlayerArray() )
			{
				int playerTeam = player.GetTeam()
				int scoreDiffer = -1
				if ( playerTeam == winningTeam ) // winning team player
				{
					// compare with 2nd team
					int secondTeam = GetWinningTeamWithFFASupport( 2 )
					if ( secondTeam == winningTeamScore ) // we don't have enough teams to compare?
						continue
					int secondTeamScore = GameRules_GetTeamScore( secondTeam )
					scoreDiffer = winningTeamScore - secondTeamScore
				}
				else // other players
				{
					// compare with 2nd team
					int playerTeamScore = GameRules_GetTeamScore( playerTeam )
					scoreDiffer = winningTeamScore - playerTeamScore
				}
				// compare score
				//print( "scoreDiffer: " + string( scoreDiffer ) )
				if ( scoreDiffer < 0 )
					continue
				string dialogue = ""
				if ( playerTeam == winningTeam ) // winning team player
				{
					if( scoreDiffer >= totalScore * 0.4 )
						dialogue = "scoring_" + winningLarge
					else if( scoreDiffer <= totalScore * 0.1 )
						dialogue = "scoring_" + winningClose
					else
						dialogue = "scoring_" + winning
				}
				else // other players
				{
					if( scoreDiffer >= totalScore * 0.4 )
						dialogue = "scoring_" + losingLarge
					else if( scoreDiffer <= totalScore * 0.1 )
						dialogue = "scoring_" + losingClose
					else
						dialogue = "scoring_" + losing
				}

				if ( dialogue != "" )
					PlayFactionDialogueToTeam( dialogue, playerTeam )
			}
		}
		else // this must mean score tied
		{
			//print( "FFA score tied!" )
			if( tied != "" )
			{
				foreach ( entity player in GetPlayerArray() )
					PlayFactionDialogueToPlayer( "scoring_" + tied, player )
			}
		}
	}
	else // two-team gamemode
	{
		int winningTeam
		int losingTeam
		bool scoreTied
		int mltScore = GameRules_GetTeamScore( TEAM_MILITIA )
		int imcScore = GameRules_GetTeamScore( TEAM_IMC )

		if( IsRoundBased() )
		{
			mltScore = GameRules_GetTeamScore2( TEAM_MILITIA )
			imcScore = GameRules_GetTeamScore2( TEAM_MILITIA )
		}

		if( mltScore < imcScore )
		{
			winningTeam = TEAM_IMC
			losingTeam = TEAM_MILITIA
		}
		else if( mltScore > imcScore )
		{
			winningTeam = TEAM_MILITIA
			losingTeam = TEAM_IMC
		}
		else if( mltScore == imcScore )
		{
			scoreTied = true
		}

		int winningTeamScore = GameRules_GetTeamScore( winningTeam )
		int losingTeamScore = GameRules_GetTeamScore( losingTeam )
		if( scoreTied && GetServerVar( "winningTeam" ) <= TEAM_UNASSIGNED )
		{
			if( tied != "" )
			{
				PlayFactionDialogueToTeam( "scoring_" + tied, TEAM_IMC )
				PlayFactionDialogueToTeam( "scoring_" + tied, TEAM_MILITIA )
			}
		}
		else if( winningTeamScore - losingTeamScore >= totalScore * 0.4 )
		{
			PlayFactionDialogueToTeam( "scoring_" + winningLarge, winningTeam )
			PlayFactionDialogueToTeam( "scoring_" + losingLarge, losingTeam )
		}
		else if( winningTeamScore - losingTeamScore <= totalScore * 0.1 )
		{
			PlayFactionDialogueToTeam( "scoring_" + winningClose, winningTeam )
			PlayFactionDialogueToTeam( "scoring_" + losingClose, losingTeam )
		}
		else
		{
			PlayFactionDialogueToTeam( "scoring_" + winning, winningTeam )
			PlayFactionDialogueToTeam( "scoring_" + losing, losingTeam )
		}
	}
}

// modified here
void function SetWaitingForPlayersMaxDuration( float duration )
{
	file.waitingForPlayersMaxDuration = duration
}

void function SetPickLoadoutEnabled( bool enable )
{
	file.pickLoadoutEnable = enable
}

void function SetPickLoadoutDuration( float duration )
{
	file.pickLoadoutDuration = duration
}

void function SetTitanSelectionMenuDuration( float duration )
{
	file.titanSelectionMenuDuration = duration
}

void function GameState_SetScoreEventDialogueEnabled( bool enable )
{
	file.scoreEventDialogue = enable
}