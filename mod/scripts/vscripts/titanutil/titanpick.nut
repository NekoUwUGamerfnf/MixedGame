// monarch hack really should be in callbacks such as AddCallback_TitanPickApplySavedOffhands()
untyped

global function TitanPick_Init

// main settings func
global function TitanPick_Enabled_Init
global function TitanPick_EnableWeaponDrops
global function TitanPick_MonarchUpgradeAfterDrop

// utilities
global function TitanPick_SoulSetEnableWeaponDrop
global function TitanPick_SoulSetEnableWeaponPick

global function TitanPick_SoulSetWeaponDropTitanCharacterName

// registering new titan
global function TitanPick_RegisterTitanWeaponDrop
global function TitanPick_AddIllegalWeaponMod
global function TitanPick_AddChangablePassive
global function TitanPick_AddChangableClassMod

// shared with meleeSyncedTitan
global function TitanPick_ShouldTitanDropWeapon
global function TitanPick_TitanDropWeapon


const float TITAN_WEAPON_DROP_LIFETIME          = 60 // after this time the weapon drop will be destroyed

// consts that no need to change
const string TITAN_DROPPED_WEAPON_SCRIPTNAME    = "titanPickWeaponDrop"
const vector DEFAULT_DROP_ORIGIN                = < -9999, -9999, -9999 > // hack, this means drop right under player or titan
const vector DEFAULT_DROP_ANGLES                = < -9999, -9999, -9999 > // hack, this means drop right under player or titan

const float PLAYER_PICKUP_COOLDOWN              = 0.5 // for we use this 0.2s to update core icon
const float PLAYER_RUI_UPDATE_DURATION          = 0.5 // use cinematic flag to update rui

// monarch hack
array<int> MONARCH_PASSIVES = 
[
    ePassives.PAS_VANGUARD_COREMETER,
    ePassives.PAS_VANGUARD_SHIELD,
    ePassives.PAS_VANGUARD_REARM,
    ePassives.PAS_VANGUARD_DOOM,
]
array<int> MONARCH_CORE_PASSIVES = 
[
    ePassives.PAS_VANGUARD_CORE1,
    ePassives.PAS_VANGUARD_CORE2,
    ePassives.PAS_VANGUARD_CORE3,
    ePassives.PAS_VANGUARD_CORE4,
    ePassives.PAS_VANGUARD_CORE5,
    ePassives.PAS_VANGUARD_CORE6,
    ePassives.PAS_VANGUARD_CORE7,
    ePassives.PAS_VANGUARD_CORE8,
    ePassives.PAS_VANGUARD_CORE9,
]
array<int> MONARCH_FIRST_UPGRADE_PASSIVES = 
[
    ePassives.PAS_VANGUARD_CORE1,
    ePassives.PAS_VANGUARD_CORE2,
    ePassives.PAS_VANGUARD_CORE3,
]
array<int> MONARCH_SECOND_UPGRADE_PASSIVES = 
[
    ePassives.PAS_VANGUARD_CORE4,
    ePassives.PAS_VANGUARD_CORE5,
    ePassives.PAS_VANGUARD_CORE6,
]
array<int> MONARCH_FINAL_UPGRADE_PASSIVES = 
[
    ePassives.PAS_VANGUARD_CORE7,
    ePassives.PAS_VANGUARD_CORE8,
    ePassives.PAS_VANGUARD_CORE9,
]
//

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

    void functionref( entity titan ) switchOffFunc = null // can be null
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
    
    table<int, bool> passives = {} // should clone from soul.passives
    array<string> classMods = [] // requires modified titan_base.txt
    int upgradeCount = 0 // monarch hack
}

struct
{
    bool enableWeaponDrops = false
    bool upgradeAllowedAfterDrop = false // monarch hack: if TitanPick_MonarchUpgradeAfterDrop() turns off, only owner monarch can upgrade their offhands

    table<entity, float> playerPickupAllowedTime // for updating core icon

    table<entity, bool> soulEnabledTitanDrop
    table<entity, bool> soulEnabledTitanPick
    table<entity, string> soulWeaponDropCharcterName // default classes registered in titan_replace.gnut

    table<string, WeaponDropFunctions> registeredWeaponDrop
    table<entity, DroppedTitanWeapon> droppedWeaponPropsTable
    table<entity, OffhandWeaponData> droppedOffhandsTable
    table<entity, entity> soulLoadoutOwnerSoul // for saving holding loadout's owner
    table<entity, entity> droppedWeaponOwnerSoul

    // monarch hack
    table< entity, table<int, bool> > soulMonarchCorePassives
    table< entity, table<int, bool> > droppedMonarchCorePassives

    array<string> illegalWeaponMods
    array<int> changablePassives
    array<string> changableClassMods // requires modified titan_base.txt
} file

void function TitanPick_Init() 
{
    AddSoulInitFunc( OnTitanSoulInit )
    AddCallback_OnClientConnected( OnClientConnected )
    AddCallback_OnPlayerKilled( OnPlayerOrNPCKilled )
    AddCallback_OnNPCKilled( OnPlayerOrNPCKilled )

    // for updating rui
    RegisterSignal( "UpdateCoreIcon" )
    RegisterSignal( "UpdateCockpitRUI" )
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

void function TitanPick_MonarchUpgradeAfterDrop( bool enable )
{
    file.upgradeAllowedAfterDrop = enable
}

// init
void function OnTitanSoulInit( entity soul )
{
    if ( !( soul in file.soulLoadoutOwnerSoul ) )
        file.soulLoadoutOwnerSoul[ soul ] <- soul // default: the soul itself as owner
    if ( !( soul in file.soulMonarchCorePassives ) )
    {
        file.soulMonarchCorePassives[ soul ] <- {}
        thread DelayedInitSoulMornachPassives( soul )
    }
}

void function DelayedInitSoulMornachPassives( entity soul )
{
    soul.EndSignal( "OnDestroy" )
    WaitFrame() // wait for loadout being given
    file.soulMonarchCorePassives[ soul ] = GetMonarchCorePassivesTable( soul )
}

void function OnClientConnected( entity player )
{
    file.playerPickupAllowedTime[ player ] <- 0.0
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
    bool weaponDropEnabled = file.enableWeaponDrops || GetCurrentPlaylistVarInt( "titan_weapon_drops", 0 ) != 0
    //print( "weaponDropEnabled: " + string( weaponDropEnabled ) )
    if ( !weaponDropEnabled )
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
entity function TitanPick_TitanDropWeapon( entity titan, vector droppoint = DEFAULT_DROP_ORIGIN, vector dropangle = DEFAULT_DROP_ANGLES, bool droppedByPickup = false, bool snapToGround = true ) 
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
    
    string charaName = GetTitanCharacterName( titan )
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

    int skin = weapon.GetSkin() // titan weapons don't have weapon skin in vanilla, will be replaced with WEAPON_SKIN_INDEX_CAMO
    int camo = weapon.GetCamo()
    entity weaponProp = curDropFuncs.weaponPropFunc( weapon, droppoint, dropangle ) //CreatePropDynamic( modelname, droppoint, dropangle, SOLID_VPHYSICS )
    
    if ( !IsValid( weaponProp ) ) // weird crash
    {
        //print( "weaponProp invalid!" )
        return
    }
    // loadout owner
    if ( !droppedByPickup ) // dropped by titan death
    {
        file.droppedWeaponOwnerSoul[ weaponProp ] <- soul
        file.droppedMonarchCorePassives[ weaponProp ] <- GetMonarchCorePassivesTable( titan )
    }
    else // dropped by weapon switching
    {
        file.droppedWeaponOwnerSoul[ weaponProp ] <- file.soulLoadoutOwnerSoul[ soul ]
        file.droppedMonarchCorePassives[ weaponProp ] <- file.soulMonarchCorePassives[ soul ]
    }

    string displayName = curDropFuncs.displayNameFunc( weapon ) // this one is dropped by a titan, has weapon entity valid

    if ( displayName == "" || !IsValid( weaponProp ) )
        return

    weaponProp.SetUsable()
    weaponProp.SetUsableByGroup( "titan" )
    weaponProp.SetUsePrompts( "按住 %use% 以撿起 " + displayName, "按下 %use% 以撿起 " + displayName )
    weaponProp.SetScriptName( TITAN_DROPPED_WEAPON_SCRIPTNAME )
    AddCallback_OnUseEntity( weaponProp, PickupDroppedTitanWeapon )

    DroppedTitanWeapon weaponStruct
    weaponStruct.weaponName = displayName
    weaponStruct.weaponClassName = weapon.GetWeaponClassName()
    weaponStruct.weaponMods = RemoveIllegalWeaponMods( weapon.GetMods() )
    weaponStruct.weaponAmmo = 0
    // since chargeWeapons usually no need to save chargeFraction but tone's "burst loader" will be recognize as chargeWeapons, use a try-catch is better
    try { weaponStruct.weaponAmmo = weapon.GetWeaponPrimaryClipCount() }
    catch(ex1) {}
    
    // store skin and camo, add for weapon prop
    if ( camo > 0 )
        skin = WEAPON_SKIN_INDEX_CAMO // titan weapons don't have weapon skin in vanilla, use WEAPON_SKIN_INDEX_CAMO
    else
    {
        skin = 0
        camo = -1
    }
    weaponStruct.weaponSkin = skin
    weaponStruct.weaponCamo = camo
    // this sucks: prop-serverside or npc don't have correct camo, only prop-clientside can do with camo stuffs
    //weaponProp.SetSkin( skin )
    //weaponProp.SetCamo( camo )

    weaponStruct.loadoutFunction = curDropFuncs.loadoutFunction

    file.droppedWeaponPropsTable[ weaponProp ] <- weaponStruct

    // run switchoff callbacks before passives being taken off
    if ( curDropFuncs.switchOffFunc != null )
        curDropFuncs.switchOffFunc( titan )
    file.droppedOffhandsTable[ weaponProp ] <- GetTitanOffhandWeaponStruct( titan )

    thread TitanWeaponDropLifeTime( weaponProp )

    // destroy current weapon.. may cause mod titan with other smart ammo offhand to get another main weapon on disembarking, cause crash!
    //weapon.Destroy()

    return weaponProp
}

void function GiveSavedMonarchPassives( entity titan )
{
    entity soul = titan.GetTitanSoul()
    if ( !IsValid( soul ) )
        return

    table<int, bool> corePassives = file.soulMonarchCorePassives[ soul ]
    foreach ( int passive, bool enabled in corePassives )
    {
        //print( PassiveEnumFromBitfield( passive ) + " has been set to: " + string( enabled ) )
        soul.passives[ passive ] = enabled // apply passives
        if ( enabled && titan.IsPlayer() )
            titan.GivePassive( passive )
    }
}

void function TitanWeaponDropLifeTime( entity weaponProp )
{
    weaponProp.EndSignal( "OnDestroy" )
    wait TITAN_WEAPON_DROP_LIFETIME // life time
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

    entity soul = titan.GetTitanSoul()
    if ( IsValid( soul ) )
    {
        // passives
        foreach ( passive, enabled in soul.passives )
        {
            expect int( passive )
            expect bool( enabled )
            if ( file.changablePassives.contains( passive ) )
            {
                titanOffhands.passives[ passive ] <- enabled // add to table
                soul.passives[ passive ] = false // disable existing passive!
                if ( titan.IsPlayer() )
                    titan.RemovePassive( passive )
            }
        }

        // classmods
        if ( titan.IsPlayer() && IsAlive( titan ) )
        {
            array<string> classMods = titan.GetPlayerSettingsMods()
            foreach ( string mod in classMods )
            {
                if ( file.changableClassMods.contains( mod ) )
                {
                    //print( "found classmod: " + mod + ", removing" )
                    titanOffhands.classMods.append( mod ) // add to array
                    classMods.removebyvalue( mod ) // remove existing classmod
                    soul.soul.titanLoadout.setFileMods.removebyvalue( mod ) // remove from setFileMods
                }
            }
            // update health and class
            int curHealth = titan.GetHealth()
            titan.SetPlayerSettingsWithMods( titan.GetPlayerSettings(), classMods )
            int newMaxHealth = titan.GetMaxHealth()
			titan.SetHealth( min( curHealth, newMaxHealth ) )
        }

        // monarch upgrades
        titanOffhands.upgradeCount = soul.GetTitanSoulNetInt( "upgradeCount" )
    }

    return titanOffhands
}

function PickupDroppedTitanWeapon( weaponProp, player ) 
{
    expect entity( player )
    expect entity( weaponProp )

    //print( "RUNNING PickupDroppedTitanWeapon()" )
    if ( !IsValid( weaponProp ) )
        return
    
    if ( file.playerPickupAllowedTime[ player ] > Time() ) // grace period
        return
	
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

    entity newLoadoutOwner = file.droppedWeaponOwnerSoul[ weaponProp ]
    // monarch hack
    table<int, bool> newMonarchCorePassives = file.droppedMonarchCorePassives[ weaponProp ]
    // drop current weapon
	entity newWeaponProp = TitanPick_TitanDropWeapon( player, weaponProp.GetOrigin(), weaponProp.GetAngles(), true, false )
    // transfer owner
    file.soulLoadoutOwnerSoul[ soul ] = newLoadoutOwner
    // transfer passives table
    file.soulMonarchCorePassives[ soul ] = newMonarchCorePassives
    // replace loadout
    ReplaceTitanWeapon( player, weaponProp )
}

// monarch hack
table<int, bool> function GetMonarchCorePassivesTable( entity titan )
{
    table<int, bool> corePassives
    entity soul = IsSoul( titan ) ? titan : titan.GetTitanSoul()
    if ( !IsValid( soul ) )
        return corePassives
    
    foreach ( passive, enabled in soul.passives )
    {
        expect int( passive )
        expect bool( enabled )
        if ( MONARCH_CORE_PASSIVES.contains( passive ) )
        {
            //print( "passive: " + PassiveEnumFromBitfield( passive ) + " has been saved: " + string( enabled ) )
            corePassives[ passive ] <- enabled // add to table
        }
    }

    return corePassives
}

void function ReplaceTitanWeapon( entity player, entity weaponProp ) 
{  
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

    // reset behaviors
    player.SetTitanDisembarkEnabled( true ) // do need to set up this since some weapon or titancore will disable it
    player.ClearMeleeDisabled() // recover this for some titan core and ability(like power shot and flame core) will disable them
    player.Anim_StopGesture( 0 ) // stop any gesture animations maybe meleeing
    player.Server_TurnDodgeDisabledOff() // re-enable dodge disable caused by ability(like hover)

    // monarch hack: after being pick up, cannot upgrade anymore
    bool passUpgrades = ShouldTitanPassUpgradesForPickUp( player, weaponProp )

    // save cooldown
    table<int,float> cooldowns = GetWeaponCooldownsForTitanLoadoutSwitch( player )
    // apply offhands
    ApplySavedOffhandWeapons( player, file.droppedOffhandsTable[ weaponProp ], passUpgrades )
    // setup specific mechanics
    replacementWeapon.loadoutFunction( player, true, false )
    // apply cooldown
    SetWeaponCooldownsForTitanLoadoutSwitch( player, cooldowns )

    // clean up
    delete file.droppedWeaponPropsTable[ weaponProp ]
    delete file.droppedOffhandsTable[ weaponProp ]

    weaponProp.Destroy()

    // successfully applies weapons
    // try update cockpit rui visibility
    UpdateCoreIconForLoadoutSwitch( player )
    thread UpdateCockpitRUIVisbilityForLoadoutSwitch( player )
}

bool function ShouldTitanPassUpgradesForPickUp( entity titan, entity weaponProp )
{
    bool upgradeAfterPickup = file.upgradeAllowedAfterDrop || GetCurrentPlaylistVarInt( "monarch_upgrade_after_drop", 0 ) != 0
    //print( "upgradeAfterDrop: " + string( upgradeAfterDrop ) )
    if ( upgradeAfterPickup )
        return true

    entity soul = titan.GetTitanSoul()
    if ( !IsValid( soul ) )
        return false
    
    entity loadoutOwnerSoul = file.soulLoadoutOwnerSoul[ soul ]
    //print( "loadoutOwnerSoul is: " + string( loadoutOwnerSoul ) )
    //print( "checking titanSoul is: " + string( soul ) )
    if ( !IsValid( loadoutOwnerSoul ) || loadoutOwnerSoul != soul )
        return false
    // all checks passed
    return true
}

void function ApplySavedOffhandWeapons( entity titan, OffhandWeaponData savedOffhands, bool passUpgrades = false )
{
    // taking weapons done first
    if ( savedOffhands.special != "" )
        titan.TakeOffhandWeapon( OFFHAND_SPECIAL )
    if ( savedOffhands.ordnance != "" )
        titan.TakeOffhandWeapon( OFFHAND_ORDNANCE )
    if ( savedOffhands.antiRodeo != "" )
        titan.TakeOffhandWeapon( OFFHAND_ANTIRODEO )
    if ( savedOffhands.melee != "" )
        titan.TakeOffhandWeapon( OFFHAND_MELEE )
    if ( savedOffhands.core != "" )
        titan.TakeOffhandWeapon( OFFHAND_EQUIPMENT )

    // applying saved weapons goes here, to prevent crashes when switch to a titan with same weapon in different slot
    if ( savedOffhands.special != "" )
        titan.GiveOffhandWeapon( savedOffhands.special, OFFHAND_SPECIAL, savedOffhands.specialMods )
    if ( savedOffhands.ordnance != "" )
        titan.GiveOffhandWeapon( savedOffhands.ordnance, OFFHAND_ORDNANCE, savedOffhands.ordnanceMods )
    if ( savedOffhands.antiRodeo != "" )
        titan.GiveOffhandWeapon( savedOffhands.antiRodeo, OFFHAND_ANTIRODEO, savedOffhands.antiRodeoMods )
    if ( savedOffhands.melee != "" )
        titan.GiveOffhandWeapon( savedOffhands.melee, OFFHAND_MELEE, savedOffhands.meleeMods )
    if ( savedOffhands.core != "" )
        titan.GiveOffhandWeapon( savedOffhands.core, OFFHAND_EQUIPMENT, savedOffhands.coreMods )

    entity soul = titan.GetTitanSoul()
    if ( IsValid( soul ) )
    {
        // passives
        foreach ( passive, enabled in savedOffhands.passives )
        {
            soul.passives[ passive ] = enabled // apply passives
            if ( enabled && titan.IsPlayer() )
                titan.GivePassive( passive )
        }

        // classmods
        if ( titan.IsPlayer() && IsAlive( titan ) && savedOffhands.classMods.len() > 0 )
        {
            array<string> classMods = titan.GetPlayerSettingsMods()
            foreach ( string mod in savedOffhands.classMods )
            {
                //print( "found classmod: " + mod + ", applying" )
                classMods.append( mod )
                soul.soul.titanLoadout.setFileMods.append( mod )
            }
            // update health and class
            int curHealth = titan.GetHealth()
            titan.SetPlayerSettingsWithMods( titan.GetPlayerSettings(), classMods )
            int newMaxHealth = titan.GetMaxHealth()
			titan.SetHealth( min( curHealth, newMaxHealth ) )
        }

        // monarch upgrades
        soul.SetTitanSoulNetInt( "upgradeCount", savedOffhands.upgradeCount )
        //print( "new upgradeCount: "+ string( savedOffhands.upgradeCount ) )
        //print( "passUpgrades: " + string( passUpgrades ) )

        if ( titan.IsPlayer() || IsPetTitan( titan ) )
        {
            entity player = titan.IsPlayer() ? titan : GetPetTitanOwner( titan )
            if ( passUpgrades )
            {
                GiveSavedMonarchPassives( titan )
                // upgrade core icon
                string passive4 = GetMonarchFirstUpgradeName( titan )
                string passive5 = GetMonarchSecondUpgradeName( titan )
                string passive6 = GetMonarchFinalUpgradeName( titan )
                if ( passive4 != "" )
                    player.SetPersistentVar( "activeTitanLoadout.passive4", passive4 )
                if ( passive5 != "" )
                    player.SetPersistentVar( "activeTitanLoadout.passive5", passive5 )
                if ( passive6 != "" )
                    player.SetPersistentVar( "activeTitanLoadout.passive6", passive6 )
                //print( "passive4 is: " + passive4 )
                //print( "passive5 is: " + passive5 )
                //print( "passive6 is: " + passive6 )
            }
            else // can't upgrade
            {
                // hack check for maelstrom and superior chassis
                int upgradeCount = savedOffhands.upgradeCount
                bool hasMaelStrom = upgradeCount >= 2 && SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE5 )
                bool hasSuperiorChassis = upgradeCount >= 3 && SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE8 )
                
                TakeAllMonarchCorePassives( titan ) // take off passives
                // restore special core upgrades
                if ( hasMaelStrom )
                {
                    soul.passives[ ePassives.PAS_VANGUARD_CORE5 ] = true
                    player.GivePassive( ePassives.PAS_VANGUARD_CORE5 )
                }
                if ( hasSuperiorChassis )
                {
                    soul.passives[ ePassives.PAS_VANGUARD_CORE8 ] = true
                    player.GivePassive( ePassives.PAS_VANGUARD_CORE8 )
                }

                // use passive's icon instead, for notifying player that they cannot upgrade
                string replaceIcon = GetMonarchPassiveName( titan )
                player.SetPersistentVar( "activeTitanLoadout.passive4", replaceIcon )
                player.SetPersistentVar( "activeTitanLoadout.passive5", replaceIcon )
                player.SetPersistentVar( "activeTitanLoadout.passive6", replaceIcon )
            }
        }
    }
}

// monarch upgrades, hardcoded
void function TakeAllMonarchCorePassives( entity titan )
{
    entity soul = titan.GetTitanSoul()
    if ( !IsValid( soul ) )
        return

    foreach ( passive, enabled in soul.passives )
    {
        expect int( passive )
        expect bool( enabled )
        if ( MONARCH_CORE_PASSIVES.contains( passive ) )
        {
            //print( PassiveEnumFromBitfield( passive ) + " has been disabled" )
            soul.passives[ passive ] = false // disable existing passive!
            if ( titan.IsPlayer() )
                titan.RemovePassive( passive )
        }
    }
}

string function GetMonarchPassiveName( entity titan )
{
    entity soul = titan.GetTitanSoul()
    if ( !IsValid( soul ) )
        return "pas_bubbleshield" // have to return a value

    foreach ( int passive in MONARCH_PASSIVES )
    {
        if ( SoulHasPassive( soul, passive ) )
            return PassiveEnumFromBitfield( passive )
    }
    return "pas_bubbleshield" // have to return a value
}

string function GetMonarchFirstUpgradeName( entity titan )
{
    entity soul = titan.GetTitanSoul()
    if ( !IsValid( soul ) )
        return ""

    foreach ( int passive in MONARCH_FIRST_UPGRADE_PASSIVES )
    {
        if ( SoulHasPassive( soul, passive ) )
            return PassiveEnumFromBitfield( passive )
    }

    return ""
}

string function GetMonarchSecondUpgradeName( entity titan )
{
    entity soul = titan.GetTitanSoul()
    if ( !IsValid( soul ) )
        return ""

    foreach ( int passive in MONARCH_SECOND_UPGRADE_PASSIVES )
    {
        if ( SoulHasPassive( soul, passive ) )
            return PassiveEnumFromBitfield( passive )
    }

    return ""
}

string function GetMonarchFinalUpgradeName( entity titan )
{
    entity soul = titan.GetTitanSoul()
    if ( !IsValid( soul ) )
        return ""

    foreach ( int passive in MONARCH_FINAL_UPGRADE_PASSIVES )
    {
        if ( SoulHasPassive( soul, passive ) )
            return PassiveEnumFromBitfield( passive )
    }

    return ""
}

// rui updating
void function UpdateCoreIconForLoadoutSwitch( entity player )
{
    file.playerPickupAllowedTime[ player ] = Time() + PLAYER_PICKUP_COOLDOWN // add a grace period for we update core icon
    entity soul = player.GetTitanSoul()
    if ( IsValid( soul ) )
    {
        if ( IsValid( player.GetOffhandWeapon( OFFHAND_EQUIPMENT ) ) ) // anti crash... why?
            SoulTitanCore_SetExpireTime( soul, Time() + 0.15 ) // this will make core state become active, after that client will update icon
    }
}

void function UpdateCockpitRUIVisbilityForLoadoutSwitch( entity player )
{
    player.Signal( "UpdateCockpitRUI" )
    player.EndSignal( "UpdateCockpitRUI" )
    player.EndSignal( "OnDestroy" )
    if ( !HasCinematicFlag( player, CE_FLAG_TITAN_3P_CAM ) )
        AddCinematicFlag( player, CE_FLAG_TITAN_3P_CAM )

    wait PLAYER_RUI_UPDATE_DURATION
    if ( HasCinematicFlag( player, CE_FLAG_TITAN_3P_CAM ) )
        RemoveCinematicFlag( player, CE_FLAG_TITAN_3P_CAM )
}

// utility
void function TitanPick_RegisterTitanWeaponDrop( string charaName, entity functionref( entity weapon, vector origin, vector angles ) weaponPropFunc, string functionref( entity weapon ) displayNameFunc, void functionref( entity titan, bool isPickup = false, bool isSpawning = false ) loadoutFunction, void functionref( entity titan ) switchOffFunc = null )
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
    if ( switchOffFunc != null )
        dropFuncsStruct.switchOffFunc = switchOffFunc

    file.registeredWeaponDrop[ charaName ] <- dropFuncsStruct

    print( "[TITAN PICK] registered " + charaName )
}

// filter settings
void function TitanPick_AddIllegalWeaponMod( string mod )
{
    if ( !file.illegalWeaponMods.contains( mod ) )
        file.illegalWeaponMods.append( mod )
}

void function TitanPick_AddChangablePassive( int passives )
{
    if ( !file.changablePassives.contains( passives ) )
        file.changablePassives.append( passives )
}
void function TitanPick_AddChangableClassMod( string classMod )
{
    if ( !file.changableClassMods.contains( classMod ) )
        file.changableClassMods.append( classMod )
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