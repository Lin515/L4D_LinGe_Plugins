#if defined  _LinGe_Function_included_
	#endinput
#endif
#define _LinGe_Function_included_
#include <sdktools>

// 一些常用函数

// L4D2_RunScript 来源 Silver https://forums.alliedmods.net/showthread.php?p=2657025
// 用logic_script实体来执行一段vscript脚本代码
// 控制台指令script具有相同的功能 不过script是cheats指令
// 并且据Silvers所说script指令似乎存在内存泄漏 所以通过实体来执行代码更优一点
stock void L4D2_RunScript(const char[] sCode)
{
	// 获取 logic_script 实体
	static int iScriptLogic = INVALID_ENT_REFERENCE;
	if ( iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic) )
	{
		iScriptLogic = FindEntityByClassname(-1, "logic_script");
		// 如果查找不到则创建
		if ( iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic) )
		{
			iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
			if ( iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic) )
			{
				LogError("Could not create 'logic_script'");
				return;
			}
			DispatchSpawn(iScriptLogic);
		}
	}

	SetVariantString(sCode);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}
stock void _L4D2_RunScript(char[] sCode, any ...)
{
	static char sBuffer[8192];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	L4D2_RunScript(sBuffer);
}

// 将运行结果存入指定ConVar
// 这种利用控制台变量获取返回值的方法参考自left4dhooks
stock void Ret_L4D2_RunScript(const char[] code, const char[] convar)
{
	_L4D2_RunScript("Convars.SetValue(\"%s\", %s)", convar, code);
}

// 传送
stock bool Teleport(int client, int target)
{
	float vOrigin[3] = 0.0;
	float vAngles[3] = 0.0;
	GetClientAbsOrigin(target, vOrigin);
	GetClientAbsAngles(target, vAngles);
	TeleportEntity(client, vOrigin, vAngles, NULL_VECTOR);
}

// 在char[][] arr中查找指定字符串
stock int IndexString(const char[] str, const char[][] arr, int size, int srtidx=0, bool reverse=false, bool caseSensitive=true, bool equal=true)
{
	if (srtidx >= size || srtidx < 0)
	{
		LogError("索引溢出 srtidx=%d size=%d", srtidx, size);
		return -2;
	}
	if (reverse)
	{
		for (int i=srtidx; i>=0; i--)
		{
			if (equal)
			{
				if (strcmp(str, arr[i], caseSensitive) == 0)
					return i;
			}
			else
			{
				if (StrContains(str, arr[i], caseSensitive) != -1)
					return i;
			}
		}
	}
	else
	{
		for (int i=srtidx; i<size; i++)
		{
			if (equal)
			{
				if (strcmp(str, arr[i], caseSensitive) == 0)
					return i;
			}
			else
			{
				if (StrContains(str, arr[i], caseSensitive) != -1)
					return i;
			}
		}
	}
	return -1;
}
// 在any arr中查找指定数据
stock int IndexData(any data, const any[] arr, int size, int srtidx=0, bool reverse=false)
{
	if (srtidx >= size || srtidx < 0)
	{
		LogError("索引溢出 srtidx=%d size=%d", srtidx, size);
		return -2;
	}
	if (reverse)
	{
		for (int i=srtidx; i>=0; i--)
		{
			if (data == arr[i])
				return i;
		}
	}
	else
	{
		for (int i=srtidx; i<size; i++)
		{
			if (data == arr[i])
				return i;
		}
	}
	return -1;
}

// 执行一次带有FCVAR_CHEAT标识的指令
stock void CheatCommand(int client, const char[] cmd, const char[] params)
{
	int flags = GetCommandFlags(cmd);
	SetCommandFlags(cmd, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", cmd, params);
	SetCommandFlags(cmd, flags);
}

// 设置某类下所有已生成实体的KeyValue
stock int SetKeyValueByClassname(const char[] className, const char[] key, const char[] value)
{
	int entity = -1;
	int count = 0;
	while ( (entity=FindEntityByClassname(entity, className)) != -1)
	{
		DispatchKeyValue(entity, key, value);
		count++;
	}
	return count;
}

/*	判断某个插件是否正在运行
	传入的插件名是Plugin myinfo中的name元素的值
	sm plugins list 指令列出的插件名字也是这个值
	例如这是left4dhooks的myinfo

public Plugin myinfo =
{
	name = "[L4D & L4D2] Left 4 DHooks Direct",
	author = "SilverShot",
	……
}

	那么判断left4dhooks是否正在运行就是
	IsPluginRunning("[L4D & L4D2] Left 4 DHooks Direct")
	必须一字不差，区分大小写
*/
stock bool IsPluginRunning(const char[] name)
{
	Handle iter = GetPluginIterator();
	Handle plugin = INVALID_HANDLE;
	PluginStatus status;
	char buffer[260];
	bool ret = false;
	
	while (MorePlugins(iter))
	{
		plugin = ReadPlugin(iter);
		if (GetPluginInfo(plugin, PlInfo_Name, buffer, sizeof(buffer)))
		{
			if (strcmp(name, buffer) == 0)
			{
				status = GetPluginStatus(plugin);
				if (Plugin_Running == status)
					ret = true;
				else
					ret = false;
				break;
			}
		}
	}

	CloseHandle(iter);
	return ret;
}

// 判断某个插件是否已经载入完毕 allowRunning为允许将运行中的插件也视为已载入
stock bool IsPluginLoaded(const char[] name, bool allowRunning=true)
{
	Handle iter = GetPluginIterator();
	Handle plugin = INVALID_HANDLE;
	PluginStatus status;
	char buffer[260];
	bool ret = false;
	
	while (MorePlugins(iter))
	{
		plugin = ReadPlugin(iter);
		if (GetPluginInfo(plugin, PlInfo_Name, buffer, sizeof(buffer)))
		{
			if (strcmp(name, buffer) == 0)
			{
				status = GetPluginStatus(plugin);
				if (Plugin_Loaded == status)
					ret = true;
				else if (Plugin_Running == status && allowRunning)
					ret = true;
				else
					ret = false;
				break;
			}
		}
	}

	CloseHandle(iter);
	return ret;
}

// 一些操作网络属性的函数
// 是否存活
stock bool IsAlive(int client)
{
	return GetEntProp(client, Prop_Send, "m_lifeState") == 0;
}
// 是否倒地
stock bool IsIncapacitated(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0;
}

// 获取生命值
stock int GetHealth(int client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}
// 设置生命值
stock void SetHealth(int client, int health)
{
	SetEntProp(client, Prop_Send, "m_iHealth", health);
}


// 是否是有效Client
stock bool IsValidClient(int client, bool noNeedInGame=false)
{
	if (client < 1 || client > MaxClients)
		return false;
	if (!IsClientConnected(client))
		return false;
	if (!noNeedInGame && !IsClientInGame(client))
		return false;
	return true;
}

// 所有玩家是否已载入到游戏 主要用于每回合开始阶段检测
stock bool IsAllHumanInGame()
{
	for (int i=1; i<=MaxClients; i++)
	{
		// 若存在已连接且不是BOT，但尚未在游戏中的玩家
		if (IsClientConnected(i) && !IsClientInGame(i))
		{
			if (!IsFakeClient(i))
				return false;
		}
	}
	return true;
}

// 从BOT生还者中获取其有效真实玩家的client
// 在执行该函数前你应先确认该client是有效生还者BOT
// 若返回0，则说明该BOT没有真实玩家就位
// 若返回>0，则说明有真实玩家就位，并且返回值为其真实玩家client
stock int GetHumanClient(int bot)
{
	if (IsAlive(bot) && HasEntProp(bot, Prop_Send, "m_humanSpectatorUserID"))
	{
		int human = GetClientOfUserId(GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID"));
		if (human > 0)
		{
			if (IsClientInGame(human))
			{
				if (!IsFakeClient(human) && GetClientTeam(human)==1)
					return human;
			}
		}
	}
	return 0;
}

// 玩家是否处于闲置（旁观不算）
stock bool IsClientIdle(int client)
{
	if (GetClientTeam(client) != 1)
		return false;

	for(int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == 2 && IsFakeClient(i))
			{
				if (GetHumanClient(i) == client)
					return true;
			}
		}
	}
	return false;
}

// 当前在线的全部Client
stock int GetClients(bool noNeedInGame=false)
{
	int num = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			if (IsClientInGame(i) || noNeedInGame)
			{
				num++;
			}
		}
	}
	return num;
}

// 当前在线的全部真实玩家数
stock int GetHumans(bool noNeedInGame=false)
{
	int num = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
		{
			if (IsClientInGame(i) || noNeedInGame)
			{
				num++;
			}
		}
	}
	return num;
}

#define TEAM_UNKNOWN	0
#define TEAM_SPECTATOR	1
#define TEAM_SURVIVOR	2
#define TEAM_INFECTED	3
// 快速获取指定类型的玩家数量
// 若不指定任何参数 则获取所有IsClientInGame为真的client数量
stock int GetPlayers(int team=TEAM_UNKNOWN, bool bot=true, bool alive=false)
{
	int num = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (TEAM_UNKNOWN != team && GetClientTeam(i) != team)
				continue;
			if (!bot && IsFakeClient(i))
				continue;
			if (alive && !IsAlive(i))
				continue;
			num++;
		}
	}
	return num;
}

// BOT生还数(不含闲置)
stock int GetBotSurvivors()
{
	int num = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == 2 && IsFakeClient(i))
			{
				if (GetHumanClient(i) == 0)
					num++;
			}
		}
	}
	return num;
}

// 存活BOT数(不含闲置)
stock int GetAliveBotSurvivors()
{
	int num = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == 2 && IsFakeClient(i))
			{
				if (IsAlive(i) && GetHumanClient(i) == 0)
					num++;
			}
		}
	}
	return num;
}

// 闲置数
stock int GetIdleSurvivors()
{
	int num = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == 2 && IsFakeClient(i))
			{
				if (GetHumanClient(i) > 0)
					num++;
			}
		}
	}
	return num;
}

// 旁观数
// idle=true 返回真实旁观数+闲置
// idle=false 返回真实旁观数
stock int GetSpectators(bool idle=false)
{
	int num = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == 1 && !IsFakeClient(i)) // 不知道有没有出现BOT在旁观的可能，总之加了这个判断不会错
				num++;
		}
	}
	if (idle)
		return num;
	else
		return num-GetIdleSurvivors();
}