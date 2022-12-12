**This repository contains contents from:**

https://github.com/Legonzaur/Northstar-HoloShift

https://github.com/uniboi/ImpulseGrenade

https://github.com/JMM889901/PeePee.Flipside

https://github.com/JMM889901/Northstar.MutatorPack

https://github.com/GalacticMoblin/Moblin.Archon

https://github.com/Dinorush/Brute4

I made them compatible with my own scripts! Thanks to their support!

**English**

use loadedinits_after.gnut and loadedinits_before.gnut to Toggle gamemode modifiers

Avaliable modifiers:

RandomTitanGamemode_Init(): Always respawn as titans. Both change map and gamemode after a match

RandomPilotGamemode_Init()：Titans and boosts never avaliable. Both change map and gamemode after a match

TitanReplace_Init(): Replace Ronin Prime with Stryder, Legion Prime with Ogre, Tone Prime with Atlas, Scorch Prime with Bison( No mod required ). Replace Ion Prime with Archon, Northstar Prime with Brute4( mod required, so only enable to specific players by a uid check in titan_utils.gnut )

BTReplace_Init(): Replace Frontier Warpaint Monarch with SB-7274( Mod is required to have correct titanOS )

TitanPick_Init()：Titans will drop their primary weapon after death

PP_HarvesterPush_init(): From PeePeePoPoMan, protect your harvester and destroy enemy's

TeamShuffle_Init(): Shuffle team when game starts, also shuffle when team isn't balanced

AutoKick_Init(): Kick AFK players

MixedLoadout_Init(): Random loadouts with a punch( may not support controllers, will change it )

RandomizedEvent_Init(): From LegonZaur and PeePee, mutator pack including: gain speedboost on kill, switch all equipments on kill, switch positions on kill, elitist, moonGravity, twinTacticals, twinGrenades, classWar

TacticalReplace_Init()：Disable melee, hold melee to switch offhand type, hold use to switch main weapon type

flipside_enabled_init(): From PeePee, flipside with better behavior( may not support controllers, will change it )

TauntRandom_Init(): Press melee to do a taunt( unfinished )

EverythingNessy_Init(): Enable funny nessy outfits and throwable nessies

AltPilot_Enable_Init(): Enable model change for pilots, now supporting spectres with a hacking code

Modded_Gamemode_Fighter_Init(): Testing gamemode: melee only with no lunge

Modded_Gamemode_Zombie_Mfd_Init(): Replace MFD, only marked players using guns, other players behave like zombies

No_Iron_Sight_Weapons_Init(): Remove all iron sight models if possible

DropPodSpawn1Player_Init(): Respawn from droppod

Modded_Gamemode_Bleedout_Init(): Much better bleedout gamemode, many funny? mechanics

RespawnShip_Init(): Respawn from dropship

Fake_Scope_Sniper_Rifles_Init(): Sniper rifles with stock sights will have different scope models

Modded_Gamemode_Extra_Spawner_Enable_Init(): Replaces AiTDM, Extra Spawners that contains Tick Launcher Reapers, Npc Pilots with Titans, etc. Enables friendly fire.

NessieDebug_Init(): TEST SHITS.


**中文**

loadedinits.gnut 更改启用的主函数

主函数：

RandomTitanGamemode_Init(): 泰坦模式 + 地图轮换

RandomPilotGamemode_Init()：铁驭模式 + 地图轮换

TitanReplace_Init(): 更换 至尊浪人、军团、强力 至 游侠 巨妖 天图(无需mod)。 更换 至尊离子、北极星 至 执政官、野兽四号(需要mod，所以使用白名单) 

BTReplace_Init(): 更换 边境帝王 至 SB-7274

TitanPick_Init()：泰坦死亡后武器会掉落，武器包含配件且拾取后会切换至该泰坦的技能组。SB和帝王不可更换

SpawnTitanWeaponCommand(): 启用生成可拾取泰坦武器的控制台命令，需要Karma.Abuse

PP_HarvesterPush_init(): 改的PeePeePoPoMan的mod。修改小规模战斗为采集机攻防

TeamShuffle_Init(): 每局开始时随机分队

AutoKick_Init(): 自动踢出挂机玩家

MixedLoadout_Init(): (不保证能在有泰坦的模式里使用) 超级随机装备，包含mod里不需客户端安装的装备(除泰坦武器)

RandomizedEvent_Init(): (不保证能在有泰坦的模式里使用) 随机玩法突变，包含: 击杀加速(可互相夺取)、限制空速，空速过低锁血、头顶无遮挡物时低重力，有遮挡物重力增加、击杀后交换所有装备(除强化)、击杀后交换位置。因为ClientCommand不能用所以暂时没有提示告诉玩家切换到了什么突变

TacticalReplace_Init()：(不保证能在有泰坦的模式里使用) 禁用近战，按近战键更换装备类型，可使用原版装备与mod装备

flipside_enabled_init(): 改的PeePeePoPoMan的mod。使用双充相位移动至地图对角位置，只会在异常启用同时修改异常的地图

TauntRandom_Init(): 需要白名单，按近战使用表情动作

EverythingNessy_Init(): 装饰mod，脚本里可以启用更多东西，默认启用头饰和背饰，白名单内的玩家可以在无泰坦模式丢电池

AltPilot_Init(): 装饰mod，修改玩家模型，并且再也不会出现隐身和a盾铁驭的模型

Modded_Gamemode_Fighter_Init(): 修改游戏模式为纯近战( 无吸附 )

Modded_Gamemode_Zombie_Mfd_Init(): 修改猎杀标记为僵尸猎杀标记: 只有标记玩家可以用枪械，其他玩家为僵尸

No_Iron_Sight_Weapons_Init(): 取消所有武器的机瞄模型(若有rui则保留准星)

Modded_Gamemode_Bleedout_Init(): 优化了流血系统的模式，未测试，不知道体验如何

DropPodSpawn1Player_Init(): 从运兵舱中复活

RespawnShip_Init(): 从运输船中复活

Fake_Scope_Sniper_Rifles_Init(): 狙击枪的原厂镜会替换为随机模型，不影响实际效果

Modded_Gamemode_Extra_Spawner_Enable_Init(): 启用友伤，会刷各种各样的npc敌人出来，替换消耗战

Modded_Gamemode_BodyGroup_Init(): 只有击中特定的部位(如头部, 左臂, 右腿等)才可造成伤害

NessieDebug_Init(): 测试的一堆笨比东西