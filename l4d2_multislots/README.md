# 求生之路2 适用于战役、药役的4+玩家控制

## 简述

关于4+玩家控制的插件很多，但是都或多或少有些小问题不是让我很满意，而且它们都不能正常用在我服务器上的药役，所以自己重写了一个。   
请注意，这个插件只适用于战役或药役，有些药役是基于对抗修改的也可以用，但是正常对抗模式应禁用本插件。

**支持游戏：求生之路2**  
**建议插件平台：SourceMod 1.10.0**
**依赖：[left4dhooks&dhooks](https://github.com/LinGe515/L4D_LinGe_Plugins/tree/main/%E4%BE%9D%E8%B5%96%E7%9A%84%E6%89%A9%E5%B1%95%E4%B8%8E%E6%8F%92%E4%BB%B6/left4dhooks%26dhooks) [LinGe_Library]([L4D_LinGe_Plugins/LinGe_Library at main · LinGe515/L4D_LinGe_Plugins (github.com)](https://github.com/LinGe515/L4D_LinGe_Plugins/tree/main/LinGe_Library))**

## 功能说明

- **!jg !join !joingame**  
  加入生还者，若当前无存活BOT空位，则会自动增加一个BOT。
- **!away !s !spec !spectate**  
  进入旁观。
- **!afk**  
  快速闲置。  
  本插件不修复多人房间下的闲置BUG，有需求建议安装闲置修复插件：[survivor_afk_fix](https://github.com/LuxLuma/Left-4-fix/tree/master/left 4 fix/survivors/survivor_afk_fix)。
- **!tp**  
  传送指令，可以将自己快速传送到别的生还者位置上。主要方便掉队或卡住的玩家。  
  默认为所有人可用，0CD，cfg文件中可对该指令进行设置。
- **!ab !addbot**  
  手动增加一个BOT。仅管理员可用。
- **!kb**  
  踢出所有BOT，接管闲置玩家的BOT不会被踢出。仅管理员可用。
- **!sset**  
  设置服务器最大人数。仅管理员可用。
- **!mmn**  
  查看当前是否开启自动多倍物资补给。物资倍数=向上取整(玩家数/4)。  
  - **!mmn on**  
    打开自动多倍物资。
  - **!mmn off**  
    关闭自动多倍物资。
  - **服务器控制台下执行 sm_mmn**  
    查看当前设置的多倍物资列表。若未设置哪些物资多倍，则默认自动多倍医疗包。 
  - **服务器控制台下执行 sm_mmn xxx**  
    将xxx加入到多倍物资列表。sm_mmn clear 可清除当前物资设置
- **!autogive**  
  查看当前是否开启自动给予物资。设置这个功能的指令开关是为了适应一些固定武器的突变模式。
  - **!autogive on**  
    打开自动给予物资。
  - **!autogive off**  
    关闭自动给予物资。
  - **服务器控制台下执行 sm_autogive**  
    查看当前设置的自动给予物资列表。若未设置自动给予哪些物资，则默认给予MP5。
  - **服务器控制台下执行 sm_autogive xxx**  
    将xxx加入到自动给予物资列表。sm_autogive clear 可清除当前物资设置。

设置自动给予的物资和自动多倍的物资只能在服务器控制台设置，这是为了防止玩家游戏中误输入。  
推荐在cfg配置文件中写入相关指令。例如：  

```
// 医疗包与近战自动多倍
sm_mmn weapon_first_aid_kit_spawn
sm_mmn weapon_melee_spawn
// 自动给予马格南与M16
sm_autogive pistol_magnum
sm_autogive rifle
```

注意，插件不会对你设置的物资代码做任何检查，你应该自己确认物资代码有效性和合法性。  
物资代码请查看[物品代码.txt](https://github.com/LinGe515/L4D_LinGe_Plugins/blob/main/l4d2_multislots/物品代码.txt)。