untyped
global function Brute4_Init

void function Brute4_Init()
{
	AddCallback_IsValidMeleeExecutionTarget( Brute4MeleeExecution )
}

bool function Brute4MeleeExecution( entity attacker, entity target )
{
	#if SERVER
		if ( attacker.IsTitan() && target.IsTitan() )
		{
			entity targetSoul = target.GetTitanSoul()
			// Brute4 edge case, prevent terminations when Dome Shield is active
			if( IsValid( targetSoul ) && IsValid( targetSoul.soul.bubbleShield ) )
				return false
		}
	#endif
	
	return true
}