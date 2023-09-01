global function CodeCallback_MapInit

void function CodeCallback_MapInit()
{
	// northstar missing: mark this map as "HasRoof"
	// so replacement titans will try to warpfall
	FlagSet( "LevelHasRoof" )
	
	SetupLiveFireMaps()
}