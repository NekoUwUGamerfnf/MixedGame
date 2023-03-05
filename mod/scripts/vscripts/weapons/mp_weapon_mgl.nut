
global function OnWeaponActivate_weapon_mgl
global function OnWeaponPrimaryAttack_weapon_mgl
global function OnProjectileCollision_weapon_mgl

#if CLIENT
global function OnClientAnimEvent_weapon_mgl
#endif // #if CLIENT

#if SERVER
global function OnWeaponNpcPrimaryAttack_weapon_mgl
#endif // #if SERVER

const MAX_BONUS_VELOCITY	= 1250

void function OnWeaponActivate_weapon_mgl( entity weapon )
{
#if CLIENT
	UpdateViewmodelAmmo( false, weapon )
#endif // #if CLIENT
}

#if CLIENT
void function OnClientAnimEvent_weapon_mgl( entity weapon, string name )
{
	GlobalClientEventHandler( weapon, name )
}
#endif // #if CLIENT

var function OnWeaponPrimaryAttack_weapon_mgl( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity player = weapon.GetWeaponOwner()

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	//vector bulletVec = ApplyVectorSpread( attackParams.dir, player.GetAttackSpreadAngle() * 2.0 )
	//attackParams.dir = bulletVec

	if ( IsServer() || weapon.ShouldPredictProjectiles() )
	{
		FireGrenade( weapon, attackParams )
	}
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_weapon_mgl( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	FireGrenade( weapon, attackParams, true )
}
#endif // #if SERVER

void function FireGrenade( entity weapon, WeaponPrimaryAttackParams attackParams, bool isNPCFiring = false )
{
	vector angularVelocity = Vector( RandomFloatRange( -1200, 1200 ), 100, 0 )
	entity nade = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir, angularVelocity, 0, damageTypes.explosive, damageTypes.explosive, !isNPCFiring, true, false )

	if ( nade )
	{
		entity weaponOwner = weapon.GetWeaponOwner()
		#if SERVER
			EmitSoundOnEntity( nade, "Weapon_MGL_Grenade_Emitter" )
			// will set proj.onlyAllowSmartPistolDamage = true, which makes us cannot destroy it by normal weapons
			Grenade_Init( nade, weapon )
		#else
			//InitMagnetic needs to be after the team is set on both client and server.
			SetTeam( nade, weaponOwner.GetTeam() )
		#endif
		if( weapon.HasMod( "nessie_mgl" ) )
			nade.SetModel( $"models/domestic/nessy_doll.mdl" )
		if( weapon.HasMod( "tripwire_launcher" ) )
		{
			#if SERVER
			nade.proj.onlyAllowSmartPistolDamage = false
			#endif
		}
		else if( weapon.HasMod( "magnetic_rollers" ) )
			return
		else if( weapon.HasMod( "flesh_magnetic" ) )
		{
			#if SERVER
			GiveProjectileFakeMagnetic( nade )
			#endif
		}
		else
			nade.InitMagnetic( MGL_MAGNETIC_FORCE, "Explo_MGL_MagneticAttract" )

		//thread MagneticFlight( nade, MGL_MAGNETIC_FORCE )
	}
}

void function OnProjectileCollision_weapon_mgl( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	if ( !IsValid( hitEnt ) )
		return
	array<string> mods = projectile.ProjectileGetMods()

	if( mods.contains( "magnetic_rollers" ) )
	{
		#if SERVER
		if( projectile.proj.projectileBounceCount == 0 )
		{
			if( hitEnt.IsNPC() || hitEnt.IsPlayer() )
				return
			GiveProjectileFakeMagnetic( projectile, 125 )
			projectile.proj.projectileBounceCount++
			return
		}
		projectile.proj.projectileBounceCount++
		#endif
		if ( ( hitEnt.IsNPC() || hitEnt.IsPlayer() ) && hitEnt.GetTeam() != projectile.GetTeam() )
		{
#if SERVER
			// visual fix for client hitting near target, hardcoded. "exp_mgl" have airburst effect so PlayImpactFXTable() is better 
			PlayImpactFXTable( pos, projectile, "exp_mgl", SF_ENVEXPLOSION_INCLUDE_ENTITIES )
#endif
			projectile.ExplodeForCollisionCallback( normal )
			return
		}
	}
	else if( mods.contains( "flesh_magnetic" ) )
	{
		if ( ( hitEnt.IsNPC() || hitEnt.IsPlayer() ) && hitEnt.GetTeam() != projectile.GetTeam() )
		{
#if SERVER
			// visual fix for client hitting near target, hardcoded. "exp_mgl" have airburst effect so PlayImpactFXTable() is better 
			PlayImpactFXTable( pos, projectile, "exp_mgl" )
#endif
			projectile.ExplodeForCollisionCallback( normal )
			return
		}
	}

	if( mods.contains( "tripwire_launcher" ) )
	{
		return OnProjectileCollision_weapon_zipline( projectile, pos, normal, hitEnt, hitbox, isCritical )
		// cannot create frag entity
		//return OnProjectileCollision_weapon_tripwire( projectile, pos, normal, hitEnt, hitbox, isCritical )
	}

	else if ( IsMagneticTarget( hitEnt ) )
	{
		if ( hitEnt.GetTeam() != projectile.GetTeam() )
		{
			projectile.ExplodeForCollisionCallback( normal )
		}
	}
}
