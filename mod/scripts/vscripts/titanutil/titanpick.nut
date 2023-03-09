untyped // almost everything is hardcoded in this file!

global function TitanPick_Init

global function TitanPick_SoulSetEnableWeaponDrop
global function TitanPick_SoulSetEnableWeaponPick

global function TitanPick_SoulSetWeaponDropTitanCharcterName

// registering new titan
global function TitanPick_RegisterTitanWeaponDrop
global function TitanPick_AddIllegalWeaponMod

global function TitanPick_DropTitanWeapon
global function GiveDroppedTitanWeapon

const float TITAN_WEAPON_DROP_LIFETIME      = 60 // after this time the weapon drop will be destroyed
const vector DEFAULT_DROP_ORIGIN    = < -9999, -9999, -9999 > // hack, this means drop right under player or titan
const vector DEFAULT_DROP_ANGLES    = < -9999, -9999, -9999 > // hack, this means drop right under player or titan

struct DroppedTitanWeapon
{
    string weaponClassName
    string weaponName
    array<string> weaponMods
    int weaponAmmo
    int weaponSkin
    int weaponCamo

    // keep same as WeaponDropFunctions does
    void functionref( entity titan, bool isPickup = false, bool isSpawning = false ) loadoutFunction
}

struct WeaponDropFunctions
{
    asset functionref( entity weapon ) modelNameFunc
    string functionref( entity weapon ) displayNameFunc

    // keep same as DroppedTitanWeapon does
    void functionref( entity titan, bool isPickup = false, bool isSpawning = false ) loadoutFunction 
}

struct
{
    table<entity, bool> soulEnabledTitanDrop
    table<entity, bool> soulEnabledTitanPick
    table<entity, string> soulWeaponDropCharcterName // default classes registered in titan_replace.gnut
    
    table<string, WeaponDropFunctions> registeredWeaponDrop
    table<entity, DroppedTitanWeapon> droppedWeaponPropsTable
    array<string> illegalWeaponMods
} file

void function TitanPick_Init() 
{
    AddCallback_OnPlayerKilled( OnTitanKilled )
    AddCallback_OnNPCKilled( OnTitanKilled )
}

void function OnTitanKilled( entity victim, entity attacker,var damageInfo )
{
    if( !victim.IsTitan() )
        return
    entity soul = victim.GetTitanSoul()
    //print( soul )
    if ( !IsValid( soul ) )
        return
    if ( soul in file.soulEnabledTitanDrop )
    {
        //print( "here" )
        if ( !file.soulEnabledTitanDrop[ soul ] )
            return
    }

    TitanPick_DropTitanWeapon( victim )
}

void function TitanPick_DropTitanWeapon( entity titan, vector droppoint = DEFAULT_DROP_ORIGIN, vector dropangle = DEFAULT_DROP_ORIGIN ) 
{
    entity soul = titan.GetTitanSoul()
    if ( !IsValid( soul ) )
        return

    array<entity> weapons = titan.GetMainWeapons()
    if ( weapons.len() == 0 )
        return

    entity weapon = weapons[0]
    if ( !IsValid( weapon ) )
        return
    
    string charaName = GetTitanCharacterName( titan ) // default character name
    //print( "charaName " + charaName )
    if ( soul in file.soulWeaponDropCharcterName ) // soul has another character name
        charaName = file.soulWeaponDropCharcterName[ soul ]
    charaName = charaName.tolower()
    if ( !( charaName in file.registeredWeaponDrop ) ) // can't find current character name!
        return

    // all checks passed
    // try to drop right under player
    array<entity> ignoreEnts
    // always ignore all npcs and players, try to drop onto ground
    ignoreEnts.extend( GetPlayerArray() )
    ignoreEnts.extend( GetNPCArray() )
    // trace down to ground
    vector traceStart = titan.GetOrigin()
    vector traceEnd = traceStart + < 0, 0, -65535 >
    TraceResults downTrace = TraceLine( traceStart, traceEnd, ignoreEnts, TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )

    // calculate default drop point
    if( droppoint == DEFAULT_DROP_ORIGIN ) 
    {
        vector titanPos = titan.GetOrigin()
        droppoint = titanPos
        
        vector endPos = downTrace.endPos
        if ( titanPos.z > endPos.z ) // playerPos is higher than traced pos
            droppoint = endPos // use trace endPos instead
        
        droppoint += < 0,0,15 > // add a bit offset
    }
    if( dropangle == DEFAULT_DROP_ORIGIN ) 
    {
        vector surfaceAng = VectorToAngles( downTrace.surfaceNormal )
        //vector titanYaw = < 0, titan.GetAngles().y, 0 >
        dropangle = surfaceAng + < 90, 0, 0 > //+ titanYaw
        dropangle.x = ClampAngle( dropangle.x )
        dropangle.z = 90
        /*
        dropangle = titan.GetAngles() + < 0,0,10 >
        dropangle.x = 0
        dropangle.z = 90
        */
    }
    
    WeaponDropFunctions curDropFuncs
    curDropFuncs = file.registeredWeaponDrop[ charaName ] // get this titan's dropFuncs

    asset modelname = curDropFuncs.modelNameFunc( weapon )
    string dispalyName = curDropFuncs.displayNameFunc( weapon )
    if ( modelname == $"" || dispalyName == "" )
        return

    int skin = weapon.GetSkin()
    int camo = weapon.GetCamo()
    entity weaponProp = CreatePropDynamic( modelname, droppoint, dropangle, SOLID_VPHYSICS )
    
    weaponProp.SetUsable()
    weaponProp.SetUsableByGroup( "titan" )
    weaponProp.SetUsePrompts( "按住 %use% 以撿起 " + dispalyName, "按下 %use% 以撿起 " + dispalyName )
    AddCallback_OnUseEntity( weaponProp, GiveDroppedTitanWeapon )

    DroppedTitanWeapon weaponStruct
    weaponStruct.weaponName = dispalyName
    weaponStruct.weaponClassName = weapon.GetWeaponClassName()
    weaponStruct.weaponMods = RemoveIllegalWeaponMods( weapon.GetMods() )
    weaponStruct.weaponAmmo = 0
    // since chargeWeapons usually no need to save chargeFraction but tone's "burst loader" will be recognize as chargeWeapons, use a try-catch is better
    try { weaponStruct.weaponAmmo = weapon.GetWeaponPrimaryClipCount() }
    catch(ex) {}
    
    weaponStruct.weaponSkin = skin
    weaponStruct.weaponCamo = camo

    weaponStruct.loadoutFunction = curDropFuncs.loadoutFunction

    file.droppedWeaponPropsTable[ weaponProp ] <- weaponStruct
    thread TitanWeaponDropLifeTime( weaponProp )
}

void function TitanWeaponDropLifeTime( entity weaponProp )
{
    weaponProp.EndSignal( "OnDestroy" )
    wait 60 // life time
    if ( IsValid( weaponProp ) )
    {
        delete file.droppedWeaponPropsTable[ weaponProp ]
        weaponProp.Destroy()
    }
}

// for some weapon mod that was not good for holding forever
array<string> function RemoveIllegalWeaponMods( array<string> mods )
{
    array<string> replaceArray
    foreach( string mod in mods )
    {
        if ( file.illegalWeaponMods.contains( mod ) ) // skip illegal mod
            continue
        /*
        if( mod == "Smart_Core" ||
            mod == "rocketeer_ammo_swap" ||
            mod == "LongRangeAmmo" )
            continue
        */

        replaceArray.append( mod )
    }

    return replaceArray
}

function GiveDroppedTitanWeapon( weaponmodel, player ) 
{
    expect entity(player)
    expect entity(weaponmodel)
	
	bool canPickUp = true
    entity soul = player.GetTitanSoul()
    if( !IsValid( soul ) )
        return
    if( soul in file.soulEnabledTitanPick )
        canPickUp = file.soulEnabledTitanPick[ soul ]
	if( !canPickUp )
	{
		SendHudMessage(player, "当前机体不可更换装备", -1, 0.3, 255, 255, 0, 255, 0.15, 3, 1)
		return
	}

	if( IsTitanCoreFiring( player ) )
	{
		SendHudMessage( player, "核心启动期间不可更换装备", -1, 0.3, 255, 255, 0, 0, 0, 3, 0 )
		return
	}
    
    // replace current weapon
	TitanPick_DropTitanWeapon( player, weaponmodel.GetOrigin(), weaponmodel.GetAngles() )
	ReplaceTitanWeapon( player, weaponmodel )
}

void function ReplaceTitanWeapon( entity player, entity weaponProp ) 
{
    if ( !IsValid( weaponProp ) )
        return
        
    DroppedTitanWeapon replacementWeapon = file.droppedWeaponPropsTable[ weaponProp ]

    // replace first weapon
    if( player.GetMainWeapons().len() > 0 )
        player.TakeWeaponNow( player.GetMainWeapons()[0].GetWeaponClassName() )
    entity weapon = player.GiveWeapon( replacementWeapon.weaponClassName, replacementWeapon.weaponMods )
    player.SetActiveWeaponByName( replacementWeapon.weaponClassName )

    // since chargeWeapons usually no need to save chargeFraction and tone's "burst loader" will be recognize as chargeWeapons, use a try{}catch{} is better
    try { weapon.SetWeaponPrimaryClipCount( replacementWeapon.weaponAmmo ) }
    catch(ex) {}
    weapon.SetSkin( replacementWeapon.weaponSkin )
    weapon.SetCamo( replacementWeapon.weaponCamo )

    table<int,float> cooldowns = GetWeaponCooldownsForTitanLoadoutSwitch( player )
    // give offhands
    replacementWeapon.loadoutFunction( player, true, false )
    // apply cooldown
    SetWeaponCooldownsForTitanLoadoutSwitch( player, cooldowns )

    delete file.droppedWeaponPropsTable[ weaponProp ]
    weaponProp.Destroy()
}

// utility
void function TitanPick_RegisterTitanWeaponDrop( string charaName, asset functionref( entity weapon ) modelNameFunc, string functionref( entity weapon ) displayNameFunc, void functionref( entity titan, bool isPickup = false, bool isSpawning = false ) loadoutFunction  )
{
    charaName = charaName.tolower() // always use tolower()

    if ( charaName in file.registeredWeaponDrop )
    {
        print( "[TITAN PICK] titan character name " + charaName + " already registered!" )
        return
    }

    WeaponDropFunctions dropFuncsStruct
    dropFuncsStruct.modelNameFunc = modelNameFunc
    dropFuncsStruct.displayNameFunc = displayNameFunc
    dropFuncsStruct.loadoutFunction = loadoutFunction

    file.registeredWeaponDrop[ charaName ] <- dropFuncsStruct

    print( "[TITAN PICK] registered " + charaName )
}

// weapon mod settings
void function TitanPick_AddIllegalWeaponMod( string mod )
{
    if ( !file.illegalWeaponMods.contains( mod ) )
        file.illegalWeaponMods.append( mod )
}

// soul settings...
void function TitanPick_SoulSetEnableWeaponDrop( entity titanSoul, bool enable )
{
    if ( !( titanSoul in file.soulEnabledTitanDrop ) )
		file.soulEnabledTitanDrop[ titanSoul ] <- true // default value
	file.soulEnabledTitanDrop[ titanSoul ] = enable
}

void function TitanPick_SoulSetEnableWeaponPick( entity titanSoul, bool enable )
{
    if ( !( titanSoul in file.soulEnabledTitanPick ) )
		file.soulEnabledTitanPick[ titanSoul ] <- true // default value
	file.soulEnabledTitanPick[ titanSoul ] = enable
}

void function TitanPick_SoulSetWeaponDropTitanCharcterName( entity titanSoul, string charaName )
{
    charaName = charaName.tolower()
    if ( !( titanSoul in file.soulWeaponDropCharcterName ) )
		file.soulWeaponDropCharcterName[ titanSoul ] <- "" // default value
	file.soulWeaponDropCharcterName[ titanSoul ] = charaName
}