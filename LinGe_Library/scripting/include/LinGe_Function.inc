// 一些常用函数

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
stock bool IsPluginRunning(const char[] file)
{
	Handle plugin = FindPluginByFile(file);
	if (plugin != INVALID_HANDLE)
	{
		if ( GetPluginStatus(plugin) == Plugin_Running )
			return true;
		else
			return false;
	}
	else
		return false;
}

// 是否是有效Client
stock bool IsValidClient(int client)
{
	if (client < 1 || client > MaxClients)
		return false;
	if (!IsClientConnected(client) || !IsClientInGame(client))
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

// 当前在线的全部真实玩家数
stock int AllHumans()
{
	int numplayers = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i))
		{
			if(!IsFakeClient(i))
				numplayers++;
		}
	}
	return numplayers;
}

// 从闲置生还者中获取其真实玩家client
// 若返回0，则说明该BOT没有真实玩家就位
// 若返回<0，则说明该client无效或不是生还者或不是BOT
// 若返回>0，则说明有真实玩家就位，并且返回值为其真实玩家client
stock int GetHumanClient(int client)
{
	if (!IsValidClient(client))
		return -1;
	if (GetClientTeam(client) != 2)
		return -2;
	if (!IsFakeClient(client))
		return -3;
	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

// 玩家是否处于闲置（旁观不算）
stock bool IsClientIdle(int client)
{
	for(int i=1; i<=MaxClients; i++)
	{
		if (GetHumanClient(i) == client)
			return true;
	}
	return false;
}

// 生还者总数
stock int Survivors()
{
	int numSurvivors = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			if (GetClientTeam(i) == 2)
				numSurvivors++;
		}
	}
	return numSurvivors;
}

// 存活生还者数
stock int AliveSurvivors()
{
	int numSurvivors = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			if (GetClientTeam(i) == 2 && IsPlayerAlive(i))
				numSurvivors++;
		}
	}
	return numSurvivors;
}

// BOT生还数(不含闲置)
stock int BotSurvivors()
{
	int numBots = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (GetHumanClient(i) == 0)
			numBots++;
	}
	return numBots;
}

// 存活BOT数(不含闲置)
stock int AliveBotSurvivors()
{
	int AnumBots = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (GetHumanClient(i) == 0)
		{
			if (IsPlayerAlive(i))
				AnumBots++;
		}
	}
	return AnumBots;
}

// 闲置数
stock int Idle()
{
	int numIdle = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (GetHumanClient(i) > 0)
			numIdle++;
	}
	return numIdle;
}

// 真实旁观数（不含闲置）
stock int Spectator()
{
	int numaways = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			if (GetClientTeam(i) == 1)
				numaways++;
		}
	}
	return numaways-Idle();
}