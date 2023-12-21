// monarch hack really should be in callbacks such as AddCallback_TitanPickApplySavedOffhands()
// 2023.12.13 EDIT: has been reworked with callbacks, handled in titan_replace.gnut
untyped

global function TitanPick_Init

// main settings func
global function TitanPick_Enabled_Init
global function TitanPick_EnableWeaponDrops

global function TitanPick_SetTitanDroppedWeaponLifeTime // manually created weapon drops can bypass this setting

// utilities
global function TitanPick_SoulSetEnableWeaponDrop
global function TitanPick_SoulSetEnableWeaponPick

global function TitanPick_SoulSetWeaponDropTitanCharacterName
global function TitanPick_GetTitanWeaponDropCharacterName

global function TitanPick_AddCallback_OnTitanWeaponDropped
global function TitanPick_AddCallback_OnTitanPickupWeapon

global function TitanPick_PropIsTitanWeaponDrop // return true if this prop has TITAN_DROPPED_WEAPON_SCRIPTNAME
global function TitanPick_GetDroppedWeaponOwnerSoul // get weapon prop's owner soul
global function TitanPick_GetTitanLoadoutOwnerSoul // get titan current loadout's owner( won't be themselves if it's picked up from ground )

// registering new titan
global function TitanPick_RegisterTitanWeaponDrop
global function TitanPick_AddIllegalWeaponMod
global function TitanPick_AddChangablePassive
global function TitanPick_AddChangableClassMod

// shared with meleeSyncedTitan
global function TitanPick_ShouldTitanDropWeapon
global function TitanPick_TitanDropWeapon

// for balancing when loadout picked up by different chassis
global function TitanPick_AddPickedWeaponDamageScale
global function TitanPick_GetTitanDamageScale

const float TITAN_WEAPON_DROP_LIFETIME          = 60 // (serve as default value)after this time the weapon drop will be destroyed

// consts that no need to change
const string TITAN_DROPPED_WEAPON_SCRIPTNAME    = "titanPickWeaponDrop"
const vector DEFAULT_DROP_ORIGIN                = < -99999, -99999, -99999 > // hack, this means drop right under player or titan
const vector DEFAULT_DROP_ANGLES                = < -99999, -99999, -99999 > // hack, this means drop right under player or titan

// note: sound "bt_weapon_draw" lasts 1.5s
const float PLAYER_PICKUP_COOLDOWN              = 0.5 // disallow next pickup before this time, for we use it to update core icon and emit sound
const float PLAYER_RUI_UPDATE_DURATION          = 0.5 // use cinematic flag to update rui

global struct DroppedTitanWeapon
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

global struct OffhandWeaponData
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
}

struct
{
    bool enableWeaponDrops = false
    float titanDroppedWeaponLifeTime = TITAN_WEAPON_DROP_LIFETIME

    table<entity, float> playerPickupAllowedTime // for updating core icon

    // soul settings
    table<entity, bool> soulEnabledTitanDrop
    table<entity, bool> soulEnabledTitanPick
    table<entity, string> soulWeaponDropCharcterName // default classes registered in titan_replace.gnut

    // in-file variables
    table<string, WeaponDropFunctions> registeredWeaponDrop
    table<entity, DroppedTitanWeapon> droppedWeaponPropsTable
    table<entity, OffhandWeaponData> droppedOffhandsTable
    table<entity, entity> soulLoadoutOwnerSoul // for saving holding loadout's owner
    table<entity, entity> droppedWeaponOwnerSoul

    // callbacks
    array<void functionref( entity titan, entity weaponProp, bool droppedByPickup )> onDropTitanWeaponCallbacks
    array<void functionref( entity titan, entity weaponProp, entity newWeaponProp )> onTitanPickupWeaponCallbacks

    // settings table
    array<string> illegalWeaponMods
    array<int> changablePassives
    array<string> changableClassMods // requires modified titan_base.txt

    // titan chassis-based balancing
    table< string, table<string, float> > pickedWeaponDropDamageScaling
} file

void function TitanPick_Init() 
{
    AddSoulInitFunc( OnTitanSoulInit )
    AddCallback_OnClientConnected( OnClientConnected )
    // these callback can't handle attacker invalid cases...
    //AddCallback_OnPlayerKilled( OnPlayerOrNPCKilled )
    //AddCallback_OnNPCKilled( OnPlayerOrNPCKilled )

    // for updating rui
    RegisterSignal( "UpdateCoreIcon" )
    RegisterSignal( "UpdateCockpitRUI" )

    AddDeathCallback( "player", TitanPick_OnTitanDeath )
    AddDeathCallback( "npc_titan", TitanPick_OnTitanDeath )

    // modified callbacks in _codecallbacks_common.gnut
    // for handling damage balancing
    AddFinalDamageByCallback( "player", TitanPick_OnTitanDamageTarget )
    AddFinalDamageByCallback( "npc_titan", TitanPick_OnTitanDamageTarget )
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

void function TitanPick_SetTitanDroppedWeaponLifeTime( float lifeTime )
{
    file.titanDroppedWeaponLifeTime = lifeTime
}

// init
void function OnTitanSoulInit( entity soul )
{
    if ( !( soul in file.soulLoadoutOwnerSoul ) )
        file.soulLoadoutOwnerSoul[ soul ] <- soul // default: the soul itself as owner
}

void function OnClientConnected( entity player )
{
    file.playerPickupAllowedTime[ player ] <- 0.0
}

// this callback can't handle attacker invalid cases...
/*
void function OnPlayerOrNPCKilled( entity victim, entity attacker,var damageInfo )
{
    TryDropWeaponOnTitanKilled( victim )
}
*/

void function TitanPick_OnTitanDeath( entity victim, var damageInfo )
{
    if ( !victim.IsTitan() ) // only handle titan victim cases
        return

    TryDropWeaponOnTitanKilled( victim ) // try to drop weapon
}

bool function TryDropWeaponOnTitanKilled( entity titan )
{
    if ( !TitanPick_ShouldTitanDropWeapon( titan ) )
        return false

    // all checks passed
    // try to drop right under player( default origin and angles )
    TitanPick_TitanDropWeapon( titan )
    return true
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
entity function TitanPick_TitanDropWeapon( entity titan, vector droppoint = DEFAULT_DROP_ORIGIN, vector dropangle = DEFAULT_DROP_ANGLES, bool droppedByPickup = false, bool snapToGround = true, float weaponLifeTime = -1 ) 
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

        vector traceEnd = traceStart + < 0, 0, -1024 > // no need to trace very much...
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
        dropangle = surfaceAng + < 90, 0, 0 > //+ titanYaw // not safe to change yaw because prop has already been rotated
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
            dropangle = titan.GetAngles() + < 0, 0, 10 >
            dropangle.x = 0
            dropangle.z = 90
        }
    }

    WeaponDropFunctions curDropFuncs
    curDropFuncs = file.registeredWeaponDrop[ charaName ] // get this titan's dropFuncs

    int skin = weapon.GetSkin() // titan weapons don't have weapon skin in vanilla, will be replaced with WEAPON_SKIN_INDEX_CAMO
    int camo = weapon.GetCamo()
    entity weaponProp = curDropFuncs.weaponPropFunc( weapon, droppoint, dropangle ) //CreatePropDynamic( modelname, droppoint, dropangle, SOLID_VPHYSICS )
    if ( !IsValid( weaponProp ) ) // anti-crash
    {
        //print( "weaponProp invalid!" )
        return
    }

    // loadout owner
    if ( !droppedByPickup ) // dropped by titan death
    {
        file.droppedWeaponOwnerSoul[ weaponProp ] <- soul
    }
    else // dropped by weapon switching
    {
        file.droppedWeaponOwnerSoul[ weaponProp ] <- file.soulLoadoutOwnerSoul[ soul ]
    }

    string displayName = curDropFuncs.displayNameFunc( weapon ) // this one is dropped by a titan, has weapon entity valid

    if ( displayName == "" )
    {
        // failed to drop weapon, needs to clean up weaponProp
        if ( IsValid( weaponProp ) )
            weaponProp.Destroy()
        return
    }
    if ( !IsValid( weaponProp ) ) // anti-crash
        return

    // try adjusting location closer to titan
    if ( !droppedByPickup )
        PutEntityInSafeSpot( weaponProp, null, null, titan.GetOrigin(), weaponProp.GetOrigin() )

    //weaponProp.SetUsable()
    weaponProp.SetUsableByGroup( "titan" )
    weaponProp.SetUsePrompts( "按住 %use% 以撿起 " + displayName, "按下 %use% 以撿起 " + displayName )
    weaponProp.SetScriptName( TITAN_DROPPED_WEAPON_SCRIPTNAME )
    weaponProp.kv.CollisionGroup = TRACE_COLLISION_GROUP_DEBRIS // Debris - Don't collide with the player or other debris
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

    thread MonitorTitanWeaponDropLifeTime( weaponProp, weaponLifeTime )

    // destroy current weapon.. may cause mod titan with other smart ammo offhand to get another main weapon on disembarking, cause crash!
    //weapon.Destroy()

    // run callbacks
    // Added via TitanPick_AddCallback_OnTitanWeaponDropped
    foreach ( callbackFunc in file.onDropTitanWeaponCallbacks )
        callbackFunc( titan, weaponProp, droppedByPickup )

    return weaponProp
}

void function MonitorTitanWeaponDropLifeTime( entity weaponProp, float lifeTimeOverride = -1 )
{
    weaponProp.EndSignal( "OnDestroy" ) // getting picked up will destroy prop

    float lifeTime = file.titanDroppedWeaponLifeTime
    if ( lifeTimeOverride > 0 ) // life time override
        lifeTime = lifeTimeOverride
    
    wait lifeTime
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
                // this method seems bad, it can't trigger client passive change callbacks( or maybe serverside after we adding feature )
                //soul.passives[ passive ] = false // disable existing passive!
                //if ( titan.IsPlayer() )
                //    titan.RemovePassive( passive )
                // reworked stuffs
                TakePassive( soul, passive )
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
    }

    return titanOffhands
}

function PickupDroppedTitanWeapon( weaponProp, player ) 
{
    //print( "RUNNING PickupDroppedTitanWeapon()" )
    
    expect entity( player )
    expect entity( weaponProp )

    // anti-crash
    if ( !IsValid( weaponProp ) )
        return

    if ( !player.IsTitan() )
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
		SendHudMessage( player, "當前機體不可更換裝備", -1, 0.3, 255, 255, 0, 255, 0, 3, 0 )
		return
	}
	if( IsTitanCoreFiring( player ) )
	{
		SendHudMessage( player, "核心啓用期間不可更換裝備", -1, 0.3, 255, 255, 0, 255, 0, 3, 0 )
		return
	}

    entity newLoadoutOwner = file.droppedWeaponOwnerSoul[ weaponProp ]
    // drop current weapon
	entity newWeaponProp = TitanPick_TitanDropWeapon( player, weaponProp.GetOrigin(), weaponProp.GetAngles(), true, false )
    // transfer owner
    file.soulLoadoutOwnerSoul[ soul ] = newLoadoutOwner
    // replace loadout
    ReplaceTitanWeapon( player, weaponProp )
    // run callbacks
    // Added via TitanPick_AddCallback_OnTitanPickupWeapon
    foreach ( callbackFunc in file.onTitanPickupWeaponCallbacks )
        callbackFunc( player, weaponProp, newWeaponProp )
    // clean up weaponProp
    weaponProp.Destroy()
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

    // save cooldown
    table<int,float> cooldowns = TitanLoadoutSwitch_GetWeaponCooldowns( player )
    // apply offhands
    ApplySavedOffhandWeapons( player, file.droppedOffhandsTable[ weaponProp ] )
    // setup specific mechanics
    replacementWeapon.loadoutFunction( player, true, false )
    // apply cooldown
    TitanLoadoutSwitch_SetWeaponCooldownsFromTable( player, cooldowns )

    // clean up
    delete file.droppedWeaponPropsTable[ weaponProp ]
    delete file.droppedOffhandsTable[ weaponProp ]

    // destroy() shouldn't be handled here!!!
    // handle it in PickupDroppedTitanWeapon() is better
    //weaponProp.Destroy()

    // successfully applies weapons
    // try update cockpit rui visibility
    UpdateTitanStatusForLoadoutSwitch( player )
}

void function ApplySavedOffhandWeapons( entity titan, OffhandWeaponData savedOffhands )
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
            // this method seems bad, it can't trigger client passive change callbacks( or maybe serverside after we adding feature )
            //soul.passives[ passive ] = enabled // apply passives
            //if ( enabled && titan.IsPlayer() ) // player specific passive give
            //    titan.GivePassive( passive )
            // reworked stuffs
            // titan passive handled by soul entity
            if ( enabled )
                GivePassive( soul, passive )
            else
                TakePassive( soul, passive )
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
    }
}

void function UpdateTitanStatusForLoadoutSwitch( entity player )
{
    // add a grace period for we update core icon and play sound
    file.playerPickupAllowedTime[ player ] = Time() + PLAYER_PICKUP_COOLDOWN
    
    StopSoundOnEntity( player, "bt_weapon_draw" )
    EmitSoundOnEntityOnlyToPlayer( player, player, "bt_weapon_draw" )

    UpdateCoreIconForLoadoutSwitch( player )
    thread UpdateCockpitRUIVisbilityForLoadoutSwitch( player )
}

// rui updating
void function UpdateCoreIconForLoadoutSwitch( entity player )
{
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

string function TitanPick_GetTitanWeaponDropCharacterName( entity titan )
{
    entity titanSoul = titan.GetTitanSoul()
    if ( !( titanSoul in file.soulWeaponDropCharcterName ) )
		return GetTitanCharacterName( titan )
	return file.soulWeaponDropCharcterName[ titanSoul ]
}

// damage balancing
void function TitanPick_AddPickedWeaponDamageScale( string charaName, string chassis, float damageScale )
{
    InitLoadoutDamageTable( charaName )

    if ( !( chassis in file.pickedWeaponDropDamageScaling[ charaName ] ) ) // failsafe!! assigned an invalid chassis
        return

    file.pickedWeaponDropDamageScaling[ charaName ][ chassis ] = damageScale
}

void function InitLoadoutDamageTable( string charaName )
{
    if ( charaName in file.pickedWeaponDropDamageScaling ) // already inited?
        return

    table<string, float> emptyTable
    file.pickedWeaponDropDamageScaling[ charaName ] <- emptyTable
    // init default chassis
    file.pickedWeaponDropDamageScaling[ charaName ][ "atlas" ] <- 1.0
    file.pickedWeaponDropDamageScaling[ charaName ][ "stryder" ] <- 1.0
    file.pickedWeaponDropDamageScaling[ charaName ][ "ogre" ] <- 1.0
    file.pickedWeaponDropDamageScaling[ charaName ][ "buddy" ] <- 1.0
}

void function TitanPick_OnTitanDamageTarget( entity victim, var damageInfo )
{
    entity attacker = DamageInfo_GetAttacker( damageInfo )
    if ( IsValid( attacker ) && attacker.IsTitan() )
    {
        float damageScale = TitanPick_GetTitanDamageScale( attacker )
        // debug
        //print( "we got damage scale on " + string( attacker ) + " :" + string( damageScale ) )
        if ( damageScale != 1.0 )
            DamageInfo_ScaleDamage( damageInfo, damageScale )
    }
}

// note: this always return 1.0 after soul being destroyed, don't know how to track that case
float function TitanPick_GetTitanDamageScale( entity titan )
{
    entity soul = titan.GetTitanSoul()
    if ( !IsValid( soul ) )
        return 1.0 // soul invalid
    
    string curLoadout = TitanPick_GetTitanWeaponDropCharacterName( titan )
    string chassis = GetSoulTitanSubClass( soul )

    if ( curLoadout in file.pickedWeaponDropDamageScaling )
    {
        if ( chassis in file.pickedWeaponDropDamageScaling[ curLoadout ] )
            return file.pickedWeaponDropDamageScaling[ curLoadout ][ chassis ]
    }
    
    // failsafe
    return 1.0
}


// shared functions
bool function TitanPick_PropIsTitanWeaponDrop( entity prop )
{
    return prop.GetScriptName() == TITAN_DROPPED_WEAPON_SCRIPTNAME
}

entity function TitanPick_GetDroppedWeaponOwnerSoul( entity weaponProp )
{
    if ( !TitanPick_PropIsTitanWeaponDrop( weaponProp ) )
        return null
    return file.droppedWeaponOwnerSoul[ weaponProp ]
}

entity function TitanPick_GetTitanLoadoutOwnerSoul( entity titan )
{
    entity soul = titan.GetTitanSoul()
    if ( !IsValid( soul ) )
        return null
    return file.soulLoadoutOwnerSoul[ soul ]
}

void function TitanPick_AddCallback_OnTitanWeaponDropped( void functionref( entity titan, entity weaponProp, bool droppedByPickup ) callbackFunc )
{
    if ( !file.onDropTitanWeaponCallbacks.contains( callbackFunc ) )
        file.onDropTitanWeaponCallbacks.append( callbackFunc )
}

void function TitanPick_AddCallback_OnTitanPickupWeapon( void functionref( entity titan, entity weaponProp, entity newWeaponProp ) callbackFunc )
{
    if ( !file.onTitanPickupWeaponCallbacks.contains( callbackFunc ) )
        file.onTitanPickupWeaponCallbacks.append( callbackFunc )
}