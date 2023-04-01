untyped // almost everything is hardcoded in this file!

global function TitanPick_Init
global function TitanPick_Enabled_Init

global function TitanPick_EnableWeaponDrops // main settings func
global function TitanPick_SoulSetEnableWeaponDrop
global function TitanPick_SoulSetEnableWeaponPick

global function TitanPick_SoulSetWeaponDropTitanCharacterName

// for specific titan such as monarch, save it's upgrades
global function TitanPick_SoulShouldSaveOffhandWeapons

// registering new titan
global function TitanPick_RegisterTitanWeaponDrop
global function TitanPick_AddIllegalWeaponMod

// shared with meleeSyncedTitan
global function TitanPick_ShouldTitanDropWeapon
global function TitanPick_TitanDropWeapon

const string TITAN_DROPPED_WEAPON_SCRIPTNAME    = "titanPickWeaponDrop"
const float TITAN_WEAPON_DROP_LIFETIME          = 60 // after this time the weapon drop will be destroyed
const vector DEFAULT_DROP_ORIGIN                = < -9999, -9999, -9999 > // hack, this means drop right under player or titan
const vector DEFAULT_DROP_ANGLES                = < -9999, -9999, -9999 > // hack, this means drop right under player or titan

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
    entity functionref( entity weapon, vector origin, vector angles ) weaponPropFunc
    string functionref( entity weapon ) displayNameFunc

    // keep same as DroppedTitanWeapon does
    void functionref( entity titan, bool isPickup = false, bool isSpawning = false ) loadoutFunction 
}

// for specific titan such as monarch, save it's upgrades
struct OffhandWeaponData
{
    string special = ""
    array<string> specialMods = []
    string ordnance = ""
    array<string> ordnanceMods = []
    string antiRodeo = ""
    array<string> antiRodeoMods = []
    string melee = ""
    array<string> meleeMods = []
    string core = ""
    array<string> coreMods = []
}

struct
{
    bool enableWeaponDrops = false

    table<entity, bool> soulEnabledTitanDrop
    table<entity, bool> soulEnabledTitanPick
    table<entity, string> soulWeaponDropCharcterName // default classes registered in titan_replace.gnut
    table<entity, bool> soulSaveOffhandWeapons

    table<string, WeaponDropFunctions> registeredWeaponDrop
    table<entity, DroppedTitanWeapon> droppedWeaponPropsTable
    table<entity, OffhandWeaponData> droppedOffhandsTable
    array<string> illegalWeaponMods
} file

void function TitanPick_Init() 
{
    AddCallback_OnPlayerKilled( OnPlayerOrNPCKilled )
    AddCallback_OnNPCKilled( OnPlayerOrNPCKilled )
}

// main settings
void function TitanPick_Enabled_Init()
{
    TitanPick_EnableWeaponDrops( true )
}

void function TitanPick_EnableWeaponDrops( bool enable )
{
    file.enableWeaponDrops = enable
}

void function OnPlayerOrNPCKilled( entity victim, entity attacker,var damageInfo )
{
    TryDropWeaponOnTitanKilled( victim )
}

void function TryDropWeaponOnTitanKilled( entity titan )
{
    if ( !TitanPick_ShouldTitanDropWeapon( titan ) )
        return

    // all checks passed
    // try to drop right under player( default origin and angles )
    TitanPick_TitanDropWeapon( titan )
}

// shared func
bool function TitanPick_ShouldTitanDropWeapon( entity titan )
{
    // main check
    if ( !file.enableWeaponDrops )
        return false

    if( !titan.IsTitan() )
        return false

    entity soul = titan.GetTitanSoul()
    //print( soul )
    if ( !IsValid( soul ) )
        return false

    if ( soul in file.soulEnabledTitanDrop )
        return file.soulEnabledTitanDrop[ soul ]

    return true // if checks reached here, we can drop it
}

// this will create a weapon drop based on a titan
entity function TitanPick_TitanDropWeapon( entity titan, vector droppoint = DEFAULT_DROP_ORIGIN, vector dropangle = DEFAULT_DROP_ANGLES, bool snapToGround = true ) 
{
    // get charaName from this titan
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

    if ( snapToGround ) // try to drop the weapon onto ground
    {
        array<entity> ignoreEnts
        // always ignore all npcs and players, try to drop onto ground
        ignoreEnts.extend( GetPlayerArray() )
        ignoreEnts.extend( GetNPCArray() )
        // trace down to ground
        vector traceStart = droppoint
        if ( traceStart == DEFAULT_DROP_ORIGIN ) // not given any droppoint
            traceStart = titan.GetOrigin() // use titan orgin instead

        vector traceEnd = traceStart + < 0, 0, -65535 >
        TraceResults downTrace = TraceLine( traceStart, traceEnd, ignoreEnts, TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )

        // calculate default drop point
        vector titanPos = titan.GetOrigin()
        droppoint = titanPos
        
        vector endPos = downTrace.endPos
        if ( titanPos.z > endPos.z ) // playerPos is higher than traced pos
            droppoint = endPos // use trace endPos instead
        
        droppoint += < 0,0,15 > // add a bit offset

        // get surface angle
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
    else
    {
        if ( droppoint == DEFAULT_DROP_ORIGIN )
            droppoint = titan.GetOrigin()
        if ( dropangle == DEFAULT_DROP_ANGLES )
        {
            dropangle = titan.GetAngles() + < 0,0,10 >
            dropangle.x = 0
            dropangle.z = 90
        }
    }

    WeaponDropFunctions curDropFuncs
    curDropFuncs = file.registeredWeaponDrop[ charaName ] // get this titan's dropFuncs

    string displayName = curDropFuncs.displayNameFunc( weapon ) // this one is dropped by a titan, has weapon entity valid

    int skin = weapon.GetSkin()
    int camo = weapon.GetCamo()
    entity weaponProp = curDropFuncs.weaponPropFunc( weapon, droppoint, dropangle ) //CreatePropDynamic( modelname, droppoint, dropangle, SOLID_VPHYSICS )
    
    if ( displayName == "" || !IsValid( weaponProp ) )
        return

    weaponProp.SetUsable()
    weaponProp.SetUsableByGroup( "titan" )
    weaponProp.SetUsePrompts( "按住 %use% 以撿起 " + displayName, "按下 %use% 以撿起 " + displayName )
    weaponProp.SetScriptName( TITAN_DROPPED_WEAPON_SCRIPTNAME )
    AddCallback_OnUseEntity( weaponProp, GiveDroppedTitanWeapon )

    DroppedTitanWeapon weaponStruct
    weaponStruct.weaponName = displayName
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
    // for specific titans
    if ( soul in file.soulSaveOffhandWeapons )
	{
        if ( file.soulSaveOffhandWeapons[ soul ] )
            file.droppedOffhandsTable[ weaponProp ] <- GetTitanOffhandWeaponStruct( titan )
    }
    thread TitanWeaponDropLifeTime( weaponProp )

    // destroy current weapon
    weapon.Destroy()

    return weaponProp
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

OffhandWeaponData function GetTitanOffhandWeaponStruct( entity titan )
{
    OffhandWeaponData titanOffhands
    entity special = titan.GetOffhandWeapon( OFFHAND_SPECIAL )
    entity ordnance = titan.GetOffhandWeapon( OFFHAND_ORDNANCE )
    entity antiRodeo = titan.GetOffhandWeapon( OFFHAND_ANTIRODEO )
    entity melee = titan.GetOffhandWeapon( OFFHAND_MELEE )
    entity core = titan.GetOffhandWeapon( OFFHAND_EQUIPMENT )
    if ( IsValid( special ) )
    {
        titanOffhands.special = special.GetWeaponClassName()
        titanOffhands.specialMods = RemoveIllegalWeaponMods( special.GetMods() )
    }
    if ( IsValid( ordnance ) )
    {
        titanOffhands.ordnance = ordnance.GetWeaponClassName()
        titanOffhands.ordnanceMods = RemoveIllegalWeaponMods( ordnance.GetMods() )
    }
    if ( IsValid( antiRodeo ) )
    {
        titanOffhands.antiRodeo = antiRodeo.GetWeaponClassName()
        titanOffhands.antiRodeoMods = RemoveIllegalWeaponMods( antiRodeo.GetMods() )
    }
    if ( IsValid( melee ) )
    {
        titanOffhands.melee = melee.GetWeaponClassName()
        titanOffhands.meleeMods = RemoveIllegalWeaponMods( melee.GetMods() )
    }
    if ( IsValid( core ) )
    {
        titanOffhands.core = core.GetWeaponClassName()
        titanOffhands.coreMods = RemoveIllegalWeaponMods( core.GetMods() )
    }

    return titanOffhands
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
	TitanPick_TitanDropWeapon( player, weaponmodel.GetOrigin(), weaponmodel.GetAngles(), false )
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

void function ApplySavedOffhandWeapons( entity titan, OffhandWeaponData savedOffhands )
{
    if ( savedOffhands.special != "" )
    {
        titan.TakeOffhandWeapon( OFFHAND_SPECIAL )
        titan.GiveOffhandWeapon( savedOffhands.special, OFFHAND_SPECIAL, savedOffhands.specialMods )
    }
    if ( savedOffhands.ordnance != "" )
    {
        titan.TakeOffhandWeapon( OFFHAND_ORDNANCE )
        titan.GiveOffhandWeapon( savedOffhands.ordnance, OFFHAND_ORDNANCE, savedOffhands.ordnanceMods )
    }
    if ( savedOffhands.antiRodeo != "" )
    {
        titan.TakeOffhandWeapon( OFFHAND_ANTIRODEO )
        titan.GiveOffhandWeapon( savedOffhands.antiRodeo, OFFHAND_ANTIRODEO, savedOffhands.antiRodeoMods )
    }
    if ( savedOffhands.melee != "" )
    {
        titan.TakeOffhandWeapon( OFFHAND_MELEE )
        titan.GiveOffhandWeapon( savedOffhands.melee, OFFHAND_MELEE, savedOffhands.meleeMods )
    }
    if ( savedOffhands.core != "" )
    {
        titan.TakeOffhandWeapon( OFFHAND_EQUIPMENT )
        titan.GiveOffhandWeapon( savedOffhands.core, OFFHAND_EQUIPMENT, savedOffhands.coreMods )
    }
}

// utility
void function TitanPick_RegisterTitanWeaponDrop( string charaName, entity functionref( entity weapon, vector origin, vector angles ) weaponPropFunc, string functionref( entity weapon ) displayNameFunc, void functionref( entity titan, bool isPickup = false, bool isSpawning = false ) loadoutFunction  )
{
    charaName = charaName.tolower() // always use tolower()

    if ( charaName in file.registeredWeaponDrop )
    {
        print( "[TITAN PICK] titan character name " + charaName + " already registered!" )
        return
    }

    WeaponDropFunctions dropFuncsStruct
    dropFuncsStruct.weaponPropFunc = weaponPropFunc
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

void function TitanPick_SoulSetWeaponDropTitanCharacterName( entity titanSoul, string charaName )
{
    charaName = charaName.tolower()
    if ( !( titanSoul in file.soulWeaponDropCharcterName ) )
		file.soulWeaponDropCharcterName[ titanSoul ] <- "" // default value
	file.soulWeaponDropCharcterName[ titanSoul ] = charaName
}

// for specific titans
void function TitanPick_SoulShouldSaveOffhandWeapons( entity titanSoul, bool save )
{
    if ( !( titanSoul in file.soulSaveOffhandWeapons ) )
		file.soulSaveOffhandWeapons[ titanSoul ] <- false // default value
	file.soulSaveOffhandWeapons[ titanSoul ] = save
}