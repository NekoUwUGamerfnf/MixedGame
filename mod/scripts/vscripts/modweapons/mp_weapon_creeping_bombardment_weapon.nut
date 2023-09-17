
global function MpWeaponGrenadeCreepingBombardmentWeapon_Init
global function OnProjectileCollision_WeaponCreepingBombardmentWeapon

const asset CREEPING_BOMBARDMENT_WEAPON_SMOKESCREEN_FX = $"P_smokescreen_FD"
const asset CREEPING_BOMBARDMENT_SMOKE_FX = $"wpn_grenade_frag_mag"

const float CREEPING_BOMBARDMENT_WEAPON_SMOKESCREEN_DURATION = 15.0

const float CREEPING_BOMBARDMENT_WEAPON_DETONATION_DELAY = 8.0

const asset CREEPING_BOMBARDMENT_WEAPON_BOMB_MODEL = $"models/weapons/bullets/projectile_rocket_largest.mdl"

global const CREEPING_BOMBARDMENT_TARGETNAME = "creeping_bombardment_projectile"

const float CREEPING_BOMBARDMENT_WEAPON_EXPLOSION_DAMAGE = 40
const float CREEPING_BOMBARDMENT_WEAPON_EXPLOSION_DAMAGE_HEAVY_ARMOR = 400
const float CREEPING_BOMBARDMENT_WEAPON_EXPLOSION_RADIUS = 350

void function MpWeaponGrenadeCreepingBombardmentWeapon_Init()
{
	PrecacheParticleSystem( CREEPING_BOMBARDMENT_WEAPON_SMOKESCREEN_FX )
	PrecacheParticleSystem( CREEPING_BOMBARDMENT_SMOKE_FX )
	PrecacheModel( CREEPING_BOMBARDMENT_WEAPON_BOMB_MODEL )
}

void function OnProjectileCollision_WeaponCreepingBombardmentWeapon( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	entity player = projectile.GetOwner()

	if ( !IsValid( player ) )
		return

	if ( hitEnt == player )
		return

	if ( !EntityShouldStick( projectile, hitEnt ) )
		return

	if ( hitEnt.IsProjectile() )
		return

	if ( !LegalOrigin( pos ) )
		return

	#if SERVER
		//JFS HACK!!!: We need this to hit loot tanks ( needs to be cleaned up to support other moving geo ).
		array<string> lootTankParts = [
			"_hover_tank_interior"
			"_hover_tank_mover"
		]

		bool isLootTank = lootTankParts.contains( hitEnt.GetScriptName() )

		if ( IsValid( hitEnt ) && ( hitEnt.IsWorld() || isLootTank ) )
		{
			thread CreepingBombardmentWeapon_Detonation( pos, -projectile.GetAngles(), normal, hitEnt, player, projectile )
		}
	#endif
}

#if SERVER
void function CreepingBombardmentWeapon_Detonation( vector origin, vector angles, vector normal, entity hitEnt, entity owner, entity projectile )
{
	owner.EndSignal( "OnDestroy" )

	// do impact effect( cause projectile has been hide effect )
	PlayImpactFXTable( origin, null, "droppod_impact", SF_ENVEXPLOSION_INCLUDE_ENTITIES )

	entity bombModel = CreatePropDynamic( CREEPING_BOMBARDMENT_WEAPON_BOMB_MODEL, origin, angles, 0, 4096 )
	entity smokeFX = StartParticleEffectOnEntityWithPos_ReturnEntity( bombModel, GetParticleSystemIndex( CREEPING_BOMBARDMENT_SMOKE_FX ), FX_PATTACH_POINT_FOLLOW_NOROTATE, bombModel.LookupAttachment( "exhaust" ), <0,0,0>, <0,0,0> )
	smokeFX.kv.VisibilityFlags = ENTITY_VISIBLE_TO_ENEMY
	SetTeam( smokeFX, owner.GetTeam() )

	bombModel.SetForwardVector( -normal )
	if ( !hitEnt.IsWorld() )
		bombModel.SetParent( hitEnt, "", true )

	SetTargetName( bombModel, CREEPING_BOMBARDMENT_TARGETNAME )

	OnThreadEnd(
		function() : ( bombModel, smokeFX )
		{
			if ( IsValid( bombModel ) )
				bombModel.Destroy()

			if ( IsValid( smokeFX ) )
				EffectStop( smokeFX )
		}
	)

	wait CREEPING_BOMBARDMENT_WEAPON_DETONATION_DELAY

	CreepingBombardmentExplode( bombModel, owner )
	entity shake = CreateShake( origin, 5, 150, 1, 1028 )
	shake.kv.spawnflags = 4 // SF_SHAKE_INAIR
}

void function CreepingBombardmentExplode( entity bombModel, entity owner )
{
	EmitSoundAtPosition( TEAM_ANY, bombModel.GetOrigin(), "skyway_scripted_titanhill_mortar_explode" )
    PlayImpactFXTable( bombModel.GetOrigin(), owner, "exp_satchel", SF_ENVEXPLOSION_INCLUDE_ENTITIES )
    RadiusDamage(
        bombModel.GetOrigin(),						// center
        owner,		                				// attacker
        bombModel,									// inflictor
        CREEPING_BOMBARDMENT_WEAPON_EXPLOSION_DAMAGE,		                    				// damage
        CREEPING_BOMBARDMENT_WEAPON_EXPLOSION_DAMAGE_HEAVY_ARMOR,			               	 				// damageHeavyArmor
        CREEPING_BOMBARDMENT_WEAPON_EXPLOSION_RADIUS,		                				// innerRadius
        CREEPING_BOMBARDMENT_WEAPON_EXPLOSION_RADIUS,				        				// outerRadius
        0,			                    			// flags
        0,										    // distanceFromAttacker
        30000,				                		// explosionForce
        DF_EXPLOSION,	                            // scriptDamageFlags
        eDamageSourceId.bombardment )   //damageSourceID
    
    //thrownGun.Destroy()
}
#endif //SERVER
