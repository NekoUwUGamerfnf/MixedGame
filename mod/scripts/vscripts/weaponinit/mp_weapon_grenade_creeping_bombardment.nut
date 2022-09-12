
global function MpWeaponGrenadeCreepingBombardment_Init
global function OnProjectileCollision_WeaponCreepingBombardment

#if SERVER
global function CreepingBombardmentSmoke
#endif

//Bangalore Ult
const string CREEPING_BOMBARDMENT_MISSILE_WEAPON = "mp_weapon_grenade_electric_smoke"

const float CREEPING_BOMBARDMENT_WIDTH 		 	= 2750 //The width of the bombardment line is 4098
const float CREEPING_BOMBARDMENT_BOMBS_PER_STEP = 6
const int 	CREEPING_BOMBARDMENT_STEP_COUNT		= 6//16 //The bombardment will advance a total of 10 steps before it ends.
const float CREEPING_BOMBARDMENT_STEP_INTERVAL 	= 0.75//1.0 //The bombardment will advance 1 step every 2.5 seconds.
const float CREEPING_BOMBARDMENT_DELAY 			= 2.0 //The bombardment will wait 2.0 seconds before firing the first shell.

const float CREEPING_BOMBARDMENT_SHELLSHOCK_DURATION = 8.0

void function MpWeaponGrenadeCreepingBombardment_Init()
{
	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.bombardment, CreepingBombardment_DamagedTarget )
	#endif //SERVER

}

void function OnProjectileCollision_WeaponCreepingBombardment( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	entity player = projectile.GetOwner()
	if ( hitEnt == player )
		return

	if ( projectile.GrenadeHasIgnited() )
		return

	table collisionParams =
	{
		pos = pos,
		normal = normal,
		hitEnt = hitEnt,
		hitbox = hitbox
	}

	bool result = PlantStickyEntityOnWorldThatBouncesOffWalls( projectile, collisionParams, 0.7 )

#if SERVER
	if ( !result )
	{
		return
	}
	else if ( IsValid( hitEnt ) && ( hitEnt.IsPlayer() || hitEnt.IsTitan() || hitEnt.IsNPC() ) )
	{
		thread CreepingBombardmentSmoke( projectile )
	}
	else
	{
		thread CreepingBombardmentSmoke( projectile )
	}
#endif
	projectile.GrenadeIgnite()
	projectile.SetDoesExplode( false )
}

#if SERVER
void function CreepingBombardment_DamagedTarget( entity victim, var damageInfo )
{
	// Seems like we need this since the invulnerability from phase shift has not kicked in at this point yet
	if ( victim.IsPhaseShifted() )
		return

	//if the attacker is a valid friendly set damage do zero.
	//Note: We need the FF so we can trigger the shellshock effect.
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( IsValid( attacker ) )
	{
		if ( attacker.GetTeam() == victim.GetTeam() && (attacker != victim) )
			DamageInfo_ScaleDamage( damageInfo, 0 )
	}

	if ( victim.IsPlayer() )
		FakeShellShock_ApplyForDuration( victim, CREEPING_BOMBARDMENT_SHELLSHOCK_DURATION )
}

void function CreepingBombardmentSmoke( entity projectile )
{
	entity owner = projectile.GetThrower()

	if ( !IsValid( owner ) )
		return

	entity bombardmentWeapon = VerifyBombardmentWeapon( owner, CREEPING_BOMBARDMENT_MISSILE_WEAPON )
	if ( !IsValid( bombardmentWeapon ) )
		return

	vector origin = projectile.GetOrigin()
	vector dir = Normalize ( FlattenVector ( projectile.GetOrigin() - owner.GetOrigin() ) )

	thread Bombardment_MortarBarrageDetCord( bombardmentWeapon, $"", dir, origin, projectile.GetOrigin(),
		CREEPING_BOMBARDMENT_WIDTH,
		CREEPING_BOMBARDMENT_WIDTH / CREEPING_BOMBARDMENT_BOMBS_PER_STEP,
		CREEPING_BOMBARDMENT_STEP_COUNT,
		CREEPING_BOMBARDMENT_STEP_INTERVAL,
		CREEPING_BOMBARDMENT_DELAY )

	float duration = CREEPING_BOMBARDMENT_STEP_COUNT * CREEPING_BOMBARDMENT_STEP_INTERVAL
	wait duration + CREEPING_BOMBARDMENT_DELAY
}
#endif