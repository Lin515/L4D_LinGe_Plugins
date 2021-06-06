# 求生之路2 适用于战役模式的4+玩家控制

## 简述

关于4+玩家控制的插件很多，但是都或多或少有些小问题不是让我很满意，所以自己重写了一个。      
请注意，这个插件只适用于战役，对抗模式应禁用本插件。

**支持游戏：求生之路2**  
**建议插件平台：SourceMod 1.10.0**

## 功能说明

- **!jg !join !joingame**  
  加入生还者，若当前无存活BOT空位，则会自动增加一个BOT。
- **!away !s !spec !spectate**  
  进入旁观。
- **!afk**  
  强制闲置。
- **!ab !addbot** 
  手动增加一个BOT。仅管理员可用。
- **!kb**  
  踢出所有BOT，接管闲置玩家的BOT不会被踢出。仅管理员可用。
- **!sset**  
  设置服务器最大人数。仅管理员可用。
- **!mmn**  
  查看当前是否开启自动多倍物资补给。  
  - **!mmn on** 打开自动多倍物资。
  - **!mmn off** 关闭自动多倍物资。
  - **!mmn xxx** 将xxx加入到多倍物资列表中。  
    若未设置哪些物资多倍，则默认自动多倍医疗包。  
    推荐在cfg文件中使用sm_mmn设置，例如设置医疗包：sm_mmn weapon_first_aid_kit_spawn。  
    sm_mmn clear可清除当前物资设置。
- **l4d2_multislots_auto_give_supply**  
  这是一条服务器命令，用来设置自动给予新加入的BOT哪些物品。  
  推荐在cfg文件中设置，例如设置自动给予马格南：l4d2_multislots_auto_give_supply pistol_magnum。  
  l4d2_multislots_auto_give_supply clear 可清除当前物资设置。

物资代码请查看[物品代码.txt](https://github.com/LinGe515/L4D_LinGe_Plugins/blob/main/l4d2_multislots/物品代码.txt)，一些插件设置请查看[l4d2_multislots.cfg](https://github.com/LinGe515/L4D_LinGe_Plugins/blob/main/l4d2_multislots/l4d2_multislots.cfg)。