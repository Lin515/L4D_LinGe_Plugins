# 求生之路1&2 投票更换模式

投票更换游戏模式插件，是用Silver的l4d_votemode修改的。  
我主要是在其原版的基础上增加了使用builtinvotes扩展来发起游戏内置投票的功能。  
保留了原版的多语言功能，不过经过修改之后，有一些小地方只能统一使用投票发起者的语言。因为需要新增一些提示语句，但我的能力有限，所以其原版的几个翻译文件中我只保留了英语的。

**支持游戏：求生之路1&2**（实际上游戏1代我没测试过，应该也是支持的）  
**建议插件平台：SourceMod 1.10.0**  
**依赖：[builtinvotes](https://github.com/LinGe515/L4D_LinGe_Plugins/tree/main/依赖的扩展与插件/builtinvotes)**  
**原版 l4d_votemode：** [[L4D & L4D2] Vote Mode](https://forums.alliedmods.net/showthread.php?t=179279)

## 指令与功能

- **!modevote**  
  打开投票更换模式菜单。非管理员也可以使用。
- **!modeveto**  
  直接否定当前的投票。仅具有ROOT权限管理员可用。
- **!modepass**  
  直接通过当前的投票。仅具有ROOT权限管理员可用。
- **!modeforce**  
  打开更换模式菜单，使用此指令更换模式无需经过投票。仅具有ROOT权限管理员可用。

插件使用方法与我的另一个插件[l4d_mapvote]([L4D_LinGe_Plugins/l4d_mapvote at main · LinGe515/L4D_LinGe_Plugins (github.com)](https://github.com/LinGe515/L4D_LinGe_Plugins/tree/main/l4d_mapvote))基本一样，这两个插件都是基于原版的l4d_votemode修改的。
