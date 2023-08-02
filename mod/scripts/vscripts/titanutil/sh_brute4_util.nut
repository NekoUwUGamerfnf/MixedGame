untyped
global function Brute4_Init

void function Brute4_Init()
{
	MpTitanAbilityBrute4DomeShield_Init()
	MpTitanweaponGrenadeLauncher_Init()
	BarrageCore_Init()

	AddCallback_IsValidMeleeExecutionTarget( Brute4MeleeExecution )
}

bool function Brute4MeleeExecution( entity attacker, entity target )
{
	#if SERVER
		// Brute4 edge case, prevent terminations when Dome Shield is active
		if( IsValid( target.GetTitanSoul().soul.bubbleShield ) )
			return false
	#endif
	return true
}