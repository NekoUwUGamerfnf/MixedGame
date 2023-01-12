function VortexDrainedByImpact( entity vortexWeapon, entity weapon, entity projectile, damageType )
{
	if ( vortexWeapon.HasMod( "unlimited_charge_time" ) )
		return
	if ( vortexWeapon.HasMod( "vortex_extended_effect_and_no_use_penalty" ) )
		return

	float amount
	if ( projectile )
	{
		amount = projectile.GetProjectileWeaponSettingFloat( eWeaponVar.vortex_drain )
	}
	else
	{
		amount = weapon.GetWeaponSettingFloat( eWeaponVar.vortex_drain )
	}
	
	bool hasVortexRegen = vortexWeapon.HasMod( 配件名 ) //推荐在文件头开个常量来存配件名
														//如果以后有修改只需要去改常量

	if ( amount <= 0.0 && !hasVortexRegen )
		return
	
	if( hasVortexRegen )
	{
		amount = 回复量		// 推荐开个常量存
		if ( vortexWeapon.GetWeaponClassName() == "mp_titanweapon_vortex_shield_ion" )
		{
			// 离子版: 使用能量系统
			entity owner = vortexWeapon.GetWeaponOwner()
			int totalEnergy = owner.GetSharedEnergyTotal()
			int currentEnergy = owner.GetSharedEnergyCount()
			int maxEnergyToAdd = int( float( totalEnergy ) * amount )
			// 我不知道这里写得对不对，总之用了个?表达式麻烦你自己看了
			int energyToAdd = currentEnergy + maxEnergyToAdd >= totalEnergy ? totalEnergy - currentEnergy : maxEnergyToAdd
			owner.AddSharedEnergy( energyToAdd )
		}
		else
		{
			// 普通版：使用充能条
			// 对于涡旋盾和火盾这类充能武器来说，他们"充满"为不可用，所以要往0设置才算一直回复
			float frac = max ( vortexWeapon.GetWeaponChargeFraction() - amount, 0.0 )
			vortexWeapon.SetWeaponChargeFraction( frac )
		}
	}

	else // 原版涡旋盾行为，由于重生只考虑了减少的情况所以我们在上面开个if来写增加的
	{
		if ( vortexWeapon.GetWeaponClassName() == "mp_titanweapon_vortex_shield_ion" )
		{
			entity owner = vortexWeapon.GetWeaponOwner()
			int totalEnergy = owner.GetSharedEnergyTotal()
			owner.TakeSharedEnergy( int( float( totalEnergy ) * amount ) )
		}
		else
		{
			float frac = min ( vortexWeapon.GetWeaponChargeFraction() + amount, 1.0 )
			vortexWeapon.SetWeaponChargeFraction( frac )
		}
	}
}