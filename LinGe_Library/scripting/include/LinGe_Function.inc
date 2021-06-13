#if defined  _LinGe_Function_included_
	#endinput
#endif
#define _LinGe_Function_included_

// 一些常用函数

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
// 测试可用 但会出现编译警告 warning 219: local variable "arr" shadows a variable at a preceding level
// 我不太清楚这个警告的意义 如果觉得烦人可以在编译时给 spcomp 添加参数 -w 219 屏蔽这个警告
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
stock void BypassAndExecuteCommand(int client, const char[] cmd, const char[] params)
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

// 判断某个插件是否正在运行
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

// 从网络属性去判断client是否存活
stock bool IsAlive(client)
{
	if (GetEntProp(client, Prop_Send, "m_lifeState"))
		return false;
	else
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
	if (IsAlive(bot))
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
	int numclients = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			if (IsClientInGame(i) || noNeedInGame)
				numclients++;
		}
	}
	return numclients;
}

// 当前在线的全部真实玩家数
stock int GetHumans(bool noNeedInGame=false)
{
	int numplayers = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
		{
			if (IsClientInGame(i) || noNeedInGame)
				numplayers++;
		}
	}
	return numplayers;
}

// 生还者总数
stock int GetSurvivors()
{
	int numSurvivors = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == 2)
				numSurvivors++;
		}
	}
	return numSurvivors;
}

// 真实玩家生还者数
stock int GetHumanSurvivors()
{
	int numSurvivors = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == 2 && !IsFakeClient(i))
				numSurvivors++;
		}
	}
	return numSurvivors;
}

// 存活生还者数
stock int GetAliveSurvivors()
{
	int numSurvivors = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == 2 && IsAlive(i))
				numSurvivors++;
		}
	}
	return numSurvivors;
}

// BOT生还数(不含闲置)
stock int GetBotSurvivors()
{
	int numBots = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == 2 && IsFakeClient(i))
			{
				if (GetHumanClient(i) == 0)
					numBots++;
			}
		}
	}
	return numBots;
}

// 存活BOT数(不含闲置)
stock int GetAliveBotSurvivors()
{
	int AnumBots = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == 2 && IsFakeClient(i))
			{
				if (IsAlive(i) && GetHumanClient(i) == 0)
					AnumBots++;
			}
		}
	}
	return AnumBots;
}

// 闲置数
stock int GetIdleSurvivors()
{
	int numIdle = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == 2 && IsFakeClient(i))
			{
				if (GetHumanClient(i) > 0)
					numIdle++;
			}
		}
	}
	return numIdle;
}

// 真实旁观数（不含闲置）
stock int GetSpectators()
{
	int numaways = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == 1 && !IsFakeClient(i)) // 不知道有没有出现BOT在旁观的可能，总之加了这个判断不会错
				numaways++;
		}
	}
	return numaways-GetIdleSurvivors();
}