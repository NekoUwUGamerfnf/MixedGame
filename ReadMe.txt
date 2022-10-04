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

flipside_init(): 改的PeePeePoPoMan的mod。使用双充相位移动至地图对角位置，只会在异常启用同时修改异常的地图

TauntRandom_Init(): 需要白名单，按近战使用表情动作

EverythingNessy_Init(): 装饰mod，脚本里可以启用更多东西，默认启用头饰和背饰，白名单内的玩家可以在无泰坦模式丢电池

AltPilot_Init(): 装饰mod，修改玩家模型，并且再也不会出现隐身和a盾铁驭的模型

CustomDamageEffect_Init(): 不同的击杀效果，包括: 碎尸，消散，电击，破盾

Modded_Gamemode_Fighter_Init(): 修改游戏模式为纯近战( 无吸附 )

Modded_Gamemode_Zombie_Mfd_Init(): 修改猎杀标记为僵尸猎杀标记: 只有标记玩家可以用枪械，其他玩家为僵尸

No_Iron_Sight_Weapons_Init(): 取消所有武器的机瞄模型(若有rui则保留准星)

DropPodSpawn1Player_Init(): 从运兵舱中复活

RespawnShip_Init(): 从运输船中复活

Modded_Gamemode_Bleedout_Init(): 优化了流血系统的模式，未测试，不知道体验如何

NessieDebug_Init(): 测试的一堆笨比东西