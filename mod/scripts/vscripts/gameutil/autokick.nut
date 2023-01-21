untyped
global function AutoKick_Init

const int KICK_START_REQUIRED_PLAYERS = 8
const float AFK_MAX_TIME = 60
const float KICK_WARN_TIME = 10

array<string> enabledGamemodes = ["mfd"]

void function AutoKick_Init() 
{
	#if SERVER
	AddCallback_OnPlayerKilled( CheckAFK )
	#endif
}

#if SERVER
void function CheckAFK( entity victim, entity attacker, var damageInfo )
{
	if( !enabledGamemodes.contains(GAMETYPE) )
		return
	thread CheckAFK_threaded( victim, attacker, damageInfo )
}

void function CheckAFK_threaded( entity victim, entity attacker, var damageInfo )
{
	victim.EndSignal( "RespawnMe" )
	victim.EndSignal( "OnRespawnPlayer" )
	victim.EndSignal( "PlayerRespawnStarted" )
	victim.EndSignal( "OnDestroy" )

	if( GetPlayerArray().len() <= KICK_START_REQUIRED_PLAYERS )
		return
	wait(AFK_MAX_TIME - KICK_WARN_TIME)
	if( IsValid( victim ) )
		SendHudMessage(victim, "挂机时间过久，仍不复活将被踢出", -1, -0.35, 255, 255, 0, 255, 0, KICK_WARN_TIME, 0)
    wait(KICK_WARN_TIME)
	if( !GamePlaying() )
		return
	if( IsValid( victim ) )
		ServerCommand( "kickid " + victim.GetUID() )
}
#endif