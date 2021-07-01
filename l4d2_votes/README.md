# 求生之路2 多功能投票

发送 !votes 打开投票菜单，所有玩家可用。  
包含多倍弹药、自动红外、友伤设置、服务器人数设置、特感击杀回血等功能。  
另外可以添加自定义选项。

**支持游戏：求生之路2**  
**建议插件平台：SourceMod 1.10.0**  
**依赖：[builtinvotes](https://github.com/LinGe515/L4D_LinGe_Plugins/tree/main/依赖的扩展与插件/builtinvotes)**

## 服务器指令

- **l4d2_votes_additem**  
	给投票菜单添加额外选项。  
	指令格式：l4d2_votes_additem 是否是服务器指令[0或1] 选项名 指令  
	如果指定为服务器指令，则会发起投票，通过才会执行。  
	若不是服务器指令，则在客户端直接执行该指令。
	
	```
	// 设置服务器指令
	l4d2_votes_additem 1 "Coop" "sm_cvar mp_gamemode coop"
	// 设置客户端指令
	l4d2_votes_additem 0 "MapVote" "sm_mapvote"
	```
	
- **l4d2_votes_removeitem**  
	删除额外选项。  
	指令格式：l4d2_votes_removeitem 选项名  

	```
	l4d2_votes_removeitem "MapVote"
	```

### 关于添加额外的中文选项名

服务端对中文的支持不是很好，如果要添加额外的中文选项，例如在 cfg 文件中写入：  

```
l4d2_votes_additem 0 "更换地图" "sm_mapvote"
```

服务器会无法识别出中文字符而以致指令输入无效。

对此可以使用 VScripts 脚本来代替 cfg 文件完成指令添加，下面是一个简单的例子：

``` squirrel
// scripts/vscripts/director_base_addon.nut
switch (Convars.GetStr("hostport"))
{
case "20001":
	SendToServerConsole("l4d2_votes_additem 0 \"更换模式\" \"sm_modevote\"");
	SendToServerConsole("l4d2_votes_additem 0 \"更换地图\" \"sm_mapvote\"");
	break;
default:
	break;
}
```



## 控制台变量

本插件不自动生成 cfg 文件，如果需要设置下面的功能开关，请自行在你服务器的 server.cfg 里添加。  
每个变量后面为其默认值。

- **l4d2_votes_time**  20  
	投票应在多少秒内完成？
- **l4d2_votes_delay** 10  
  玩家需间隔多少秒才能再次发起投票？  
  插件会锁定 sm_vote_delay 一直为本变量的值。
- **l4d2_votes_ammomode** 1  
	多倍弹药模式
	- -1完全禁用
	- 0 禁用多倍但允许投票补满所有人弹药
	- 1 一倍且允许开启多倍弹药
	- 2 双倍
	- 3 三倍
	- 4 无限(需换弹)
	- 5 无限(无需换弹)
- **l4d2_votes_autolaser** 0  
	自动获得红外 -1:完全禁用 0:关闭 1:开启
- **l4d2_votes_teamhurt** 0  
	是否允许投票改变友伤系数 -1:不允许 0:允许
- **l4d2_votes_restartchapter** 0  
	是否允许投票重启当前章节 -1:不允许 0:允许
- **l4d2_votes_players** 8  
	服务器人数，若为0则不改变人数。游戏时改变本参数是无效的。
- **l4d2_votes_players_lower** 4  
	投票更改服务器人数的下限
- **l4d2_votes_players_upper** 12  
	投票更改服务器人数的上限。若下限>=上限，则不允许投票更改服务器人数（不影响本插件更改默认人数）。
- **ReturnBlood** 0  
	特感击杀回血总开关 -1:完全禁用 0:关闭 1:开启
- **l4d2_votes_returnblood_special** 2  
	击杀一只特感回多少血
- **l4d2_votes_returnblood_witch** 10  
	击杀一只Witch回多少血
- **l4d2_votes_returnblood_limit** 100  
	最高回血上限。  
	仅影响回血时的上限，不影响其它情况下的血量上限。