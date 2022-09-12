untyped
global function Brute4_Init

struct {
	array<entity> reminded // Used to only give players the HUD message on the first drop per match
} file

void function Brute4_Init()
{
	MpTitanAbilityBrute4DomeShield_Init()
	MpTitanweaponGrenadeLauncher_Init()
	BarrageCore_Init()
}
