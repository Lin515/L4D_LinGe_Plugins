// 适用于战役模式的多人控制 主要是自用
// 代码大量参考（复制~）了望夜多人插件(R_smc)与豆瓣多人插件（l4d2_multislots SwiftReal, MI 5, 豆瓣）
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <LinGe_Library>
#include <left4dhooks>

public Plugin myinfo = {
	name = "多人控制",
	author = "LinGe",
	description = "L4D2多人控制",
	version = "2.3",
	url = "https://github.com/LinGe515"
};

// SDKCall Function
Handle h_RoundRespawn = INVALID_HANDLE;
Handle h_SetHumanSpec = INVALID_HANDLE;
Handle h_TakeOverBot = INVALID_HANDLE;
Handle h_SetObserverTarget = INVALID_HANDLE; // 该函数保留不使用

ConVar cv_l4dSurvivorLimit;
ConVar cv_svmaxplayers;
ConVar cv_survivorLimit;
ConVar cv_maxs;
ConVar cv_autoGive;
ConVar cv_autoSupply;
ConVar cv_allowSset;
ConVar cv_autoJoin;
ConVar cv_onlySafeAddBot;
ConVar cv_autoKickBot;
ConVar cv_tpPermission;
ConVar cv_tpLimit;

bool g_isOnVersus = true; // 本插件不应该用在对抗中，但是可以用在基于对抗的药役中
ArrayList g_autoGive; // 自动给予哪些物品
ArrayList g_supply; // 哪些启用多倍物资补给
int g_nowMultiple = 1; // 当前物资倍数
bool g_allHumanInGame = true; // 所有玩家是否已经载入 默认为true是为了在游戏中途加载插件时能正常工作

bool g_autoJoin[MAXPLAYERS+1] = true; // 哪些玩家自动加入生还者
int g_lastTpTime[MAXPLAYERS+1] = 0; // 玩家上次使用tp时间

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion game = GetEngineVersion();
	if (game != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "本插件只支持 Left 4 Dead 2 ");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadSDKCallFunction();

	cv_l4dSurvivorLimit	= FindConVar("survivor_limit");
	cv_svmaxplayers		= FindConVar("sv_maxplayers");
	cv_survivorLimit	= CreateConVar("l4d2_multislots_survivor_limit", "4", "生还者初始数量（添加多了服务器会爆卡喔，要是满了32个会刷不出特感）", FCVAR_SERVER_CAN_EXECUTE, true, 1.0, true, 32.0);
	cv_maxs				= CreateConVar("l4d2_multislots_maxs", "8", "服务器默认最大人数。不允许插件控制人数时本参数无效。", FCVAR_SERVER_CAN_EXECUTE, true, 1.0, true, 32.0);
	cv_autoGive			= CreateConVar("l4d2_multislots_auto_give", "1", "自动给予离开安全区以后新出生的生还者武器与物品 -1:完全禁用(游戏中也无法使用指令开启) 0:关闭 1:开启", FCVAR_SERVER_CAN_EXECUTE, true, -1.0, true, 1.0);
	cv_autoSupply		= CreateConVar("l4d2_multislots_auto_supply", "1", "根据人数自动设置物资倍数 -1:完全禁用(游戏中也无法使用指令开启) 0:关闭 1:开启", FCVAR_SERVER_CAN_EXECUTE, true, -1.0, true, 1.0);
	cv_allowSset		= CreateConVar("l4d2_multislots_allow_sset", "1", "允许插件控制服务器最大人数？0:不允许 1:允许且允许其它方式修改最大人数 2:只允许本插件控制最大人数", FCVAR_SERVER_CAN_EXECUTE, true, 0.0, true, 2.0);
	cv_autoJoin			= CreateConVar("l4d2_multislots_auto_join", "1", "玩家连接完毕后是否自动使其加入游戏", FCVAR_SERVER_CAN_EXECUTE, true, 0.0, true, 1.0);
	cv_onlySafeAddBot	= CreateConVar("l4d2_multislots_onlysafe_addbot", "0", "只允许在安全区内增加BOT", FCVAR_SERVER_CAN_EXECUTE, true, 0.0, true, 1.0);
	cv_autoKickBot		= CreateConVar("l4d2_multislots_auto_kickbot", "1", "当前回合结束是否自动踢出多余BOT", FCVAR_SERVER_CAN_EXECUTE, true, 0.0, true, 1.0);
	cv_tpPermission		= CreateConVar("l4d2_multislots_tp_permission", "2", "哪些人可以使用传送指令？0:完全禁用 1:仅管理员可用 2:所有人可用", FCVAR_SERVER_CAN_EXECUTE, true, 0.0, true, 2.0);
	cv_tpLimit			= CreateConVar("l4d2_multislots_tp_limit", "0", "限制玩家使用传送指令的时间间隔，单位为秒", FCVAR_SERVER_CAN_EXECUTE, true, 0.0);
	cv_l4dSurvivorLimit.SetBounds(ConVarBound_Upper, true, 32.0);
	cv_l4dSurvivorLimit.AddChangeHook(SurvivorLimitChanged);
	cv_survivorLimit.AddChangeHook(SurvivorLimitChanged);
	cv_autoSupply.AddChangeHook(AutoMultipleChanged);
	if (null != cv_svmaxplayers)
		cv_svmaxplayers.AddChangeHook(MaxplayersChanged);
	AutoExecConfig(true, "l4d2_multislots");

	RegAdminCmd("sm_forceaddbot", Cmd_forceaddbot, ADMFLAG_ROOT, "强制增加一个BOT，无视条件限制");
	RegAdminCmd("sm_addbot", Cmd_addbot, ADMFLAG_KICK, "增加一个BOT");
	RegAdminCmd("sm_ab", Cmd_addbot, ADMFLAG_KICK, "增加一个BOT");
	RegAdminCmd("sm_kb", Cmd_kb, ADMFLAG_KICK, "踢出所有电脑BOT");
	RegAdminCmd("sm_sset", Cmd_sset, ADMFLAG_ROOT, "设置服务器最大人数");
	RegAdminCmd("sm_mmn", Cmd_mmn, ADMFLAG_ROOT, "自动多倍物资设置");
	RegAdminCmd("sm_autogive", Cmd_autogive, ADMFLAG_ROOT, "自动给予物品设置");

	AddCommandListener(Command_Jointeam, "jointeam");
	RegConsoleCmd("sm_jg", Cmd_joingame, "玩家加入生还者");
	RegConsoleCmd("sm_join", Cmd_joingame, "玩家加入生还者");
	RegConsoleCmd("sm_joingame", Cmd_joingame, "玩家加入生还者");
	RegConsoleCmd("sm_away", Cmd_away, "玩家进入旁观");
	RegConsoleCmd("sm_s", Cmd_away, "玩家进入旁观");
	RegConsoleCmd("sm_spec", Cmd_away, "玩家进入旁观");
	RegConsoleCmd("sm_spectate", Cmd_away, "玩家进入旁观");
	RegConsoleCmd("sm_afk", Cmd_afk, "快速闲置");
	RegConsoleCmd("sm_tp", Cmd_tp, "玩家自主传送指令");

	HookEvent("round_start", Event_round_start, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_round_end, EventHookMode_Pre);
	HookEvent("finale_win", Event_round_end, EventHookMode_Pre);
	HookEvent("round_end", Event_round_end, EventHookMode_Pre);
	HookEvent("player_team", Event_player_team, EventHookMode_Post);

	g_supply = CreateArray(40);
	g_autoGive = CreateArray(40);
}

public Action Cmd_forceaddbot(int client, int agrs)
{
	if (AddBot(true) == 0 && client>0)
		PrintToChat(client, "\x04已强制添加一个BOT");
	return Plugin_Handled;
}

public Action Cmd_addbot(int client, int agrs)
{
	if (0 == client)
		return Plugin_Handled;
	switch (AddBot())
	{
		case 0:
			PrintToChat(client, "\x04已成功添加一个BOT");
		case -1:
			PrintToChat(client, "\x04服务器只允许未出安全区时增加BOT");
		case -2:
			PrintToChat(client, "\x04当前无需增加BOT");
		case -3:
			PrintToChat(client, "\x04创建BOT失败");
		case -4:
			PrintToChat(client, "\x04生成生还者BOT失败");
		case -5:
			PrintToChat(client, "\x04无法复活BOT，请尝试在回合开始时再添加");
	}
	return Plugin_Handled;
}

public Action Cmd_away(int client, int args)
{
	if (0 == client)
		return Plugin_Handled;
	if (GetClientTeam(client) == 1)
	{
		if (IsClientIdle(client))
			PrintToChat(client, "\x04你当前已经是闲置状态");
		else
			PrintToChat(client, "\x04你已经是旁观者了");
		return Plugin_Handled;
	}
	if (GetClientTeam(client) == 2)
		g_autoJoin[client] = false;
	ChangeClientTeam(client, 1);
	return Plugin_Handled;
}

public Action Cmd_afk(int client, int args)
{
	if (0 == client)
		return Plugin_Handled;

	if (GetClientTeam(client) == 1)
	{
		if (IsClientIdle(client))
			PrintToChat(client, "\x04你当前已经是闲置状态");
		else
			PrintToChat(client, "\x04你已经是旁观者了");
	}
	else if (GetClientTeam(client) != 2)
		PrintToChat(client, "\x04闲置指令只限生还者使用");
	else if (!IsAlive(client))
		PrintToChat(client, "\x04死亡状态无权使用闲置");
	else if (GetEntProp(client, Prop_Send, "m_isIncapacitated"))
		PrintToChat(client, "\x04倒地时无法使用闲置");
	else if (GetPlayers(TEAM_SURVIVOR, false, true) == 1)
		PrintToChat(client, "\x04只有一名玩家存活时无法使用闲置");
	else
		FakeClientCommand(client, "go_away_from_keyboard");
	return Plugin_Handled;
}
public Action Cmd_tp(int client, int args)
{
	if (0 == client)
		return Plugin_Handled;

	if (cv_tpPermission.IntValue == 0)
	{
		PrintToChat(client, "\x04服务器未启用传送指令");
		return Plugin_Handled;
	}
	else if (cv_tpPermission.IntValue == 1)
	{
		if (0 == GetUserFlagBits(client))
		{
			PrintToChat(client, "\x04服务器只允许管理员使用传送指令");
			return Plugin_Handled;
		}
	}

	if (GetClientTeam(client) != 2)
	{
		PrintToChat(client, "\x04只有生还者可以使用传送指令");
		return Plugin_Handled;
	}
	else if (!IsAlive(client))
	{
		PrintToChat(client, "\x04死亡状态无法使用传送");
		return Plugin_Handled;
	}
	else if (GetPlayers(TEAM_SURVIVOR, true, true) == 1)
	{
		PrintToChat(client, "\x04只有一名存活生还者时无法使用传送");
		return Plugin_Handled;
	}

	int diff = GetTime() - g_lastTpTime[client];
	if (diff < cv_tpLimit.IntValue)
	{
		PrintToChat(client, "\x04你需要\x03 %d \x04秒后才能再次使用传送指令", cv_tpLimit.IntValue-diff);
		return Plugin_Handled;
	}

	DisplayTpMenu(client);
	return Plugin_Handled;
}

public Action Cmd_joingame(int client, int args)
{
	if (0 == client)
		return Plugin_Handled;
	switch (JoinSurvivor(client))
	{
		case -1:
			PrintToChat(client, "\x04请等待本回合结束后再加入游戏");
		case -2, -5: // 按本插件的机制，应该不会返回-2 -5为无法复活BOT
			PrintToChat(client, "\x04当前生还者空位不足，暂时无法加入");
		case 1:
			PrintToChat(client, "\x04你已经是生还者了");
		case 2:
			PrintToChat(client, "\x04你当前是闲置状态，请点击鼠标左键加入游戏");
		case 3:
			PrintToChat(client, "\x04有玩家尚未载入完毕，当所有玩家载入完毕时你将自动加入生还者");
	}
	return Plugin_Handled;
}

public Action Cmd_kb(int client, int args)
{
	KickAllBot();
	PrintToChatAll("\x04踢除所有bot");

	return Plugin_Handled;
}

public Action Cmd_sset(int client, int args)
{
	if (client > 0)
	{
		if (null == cv_svmaxplayers)
			PrintToChat(client, "\x04未能捕捉到\x03 sv_maxplayers");
		else if (cv_allowSset.IntValue >= 0)
			SsetMenuDisplay(client);
		else
			PrintToChat(client, "\x04服务器人数控制未开启");
	}
	return Plugin_Handled;
}

public Action Cmd_mmn(int client, int args)
{
	if (cv_autoSupply.IntValue == -1 && client > 0)
	{
		PrintToChat(client, "\x04自动多倍物资功能当前是完全禁用的");
		return Plugin_Handled;
	}

	char buffer[40];
	if (0 == args)
	{
		if (0 == client)
		{
			int len = g_supply.Length;
			if (0 == len)
			{
				PrintToServer("未设置自定义多倍的物资，将默认启用医疗包多倍");
			}
			else
			{
				for (int i=0; i<len; i++)
				{
					g_supply.GetString(i, buffer, sizeof(buffer));
					PrintToServer("自动多倍物资 %d : %s", i, buffer);
				}
			}
		}
		else
		{
			// 查看多倍物资补给状态
			if (cv_autoSupply.IntValue == 1)
				PrintToChatAll("\x04自动多倍物资补给\x03 已开启\x04，当前倍数为\x03 %d", g_nowMultiple);
			else
				PrintToChatAll("\x04自动多倍物资补给\x03 已关闭");
		}
	}
	else if (1 == args)
	{
		GetCmdArg(1, buffer, sizeof(buffer));

		if (strcmp(buffer, "on", false) == 0)
		{
			PrintToChatAll("\x04自动多倍物资补给\x03 已开启");
			cv_autoSupply.SetInt(1);
		}
		else if (strcmp(buffer, "off", false) == 0)
		{
			PrintToChatAll("\x04自动多倍物资补给\x03 已关闭");
			cv_autoSupply.SetInt(0);
		}
		else if (strcmp(buffer, "clear", false) == 0 && 0 == client)
		{
			g_supply.Clear();
		}
		else if (0 == client) // 只允许在服务器端命令行设置物资 防止玩家指令误操作
		{
			if (-1 == g_supply.FindString(buffer))
				g_supply.PushString(buffer);
		}
	}
	else if (0 == client)
		PrintToServer("参数过多，请一次只添加一种物资");
	return Plugin_Handled;
}

public Action Cmd_autogive(int client, int args)
{
	if (cv_autoGive.IntValue == -1 && client > 0)
	{
		PrintToChat(client, "\x04自动给予物资功能当前是完全禁用的");
		return Plugin_Handled;
	}

	char buffer[40];
	if (0 == args)
	{
		// 如果是在服务器执行，则列出当前自动给予物品列表
		if (0 == client)
		{
			int len = g_autoGive.Length;
			if (0 == len)
				PrintToServer("未设置自动给予的物品，将默认给予MP5");
			else
			{
				for (int i=0; i<len; i++)
				{
					g_autoGive.GetString(i, buffer, sizeof(buffer));
					PrintToServer("出生自动给予物品 %d : %s", i, buffer);
				}
			}
		}
		else
		{
			if (cv_autoGive.IntValue == 1)
				PrintToChatAll("\x04出生自动给予物品\x03 已开启");
			else
				PrintToChatAll("\x04出生自动给予物品\x03 已关闭");
		}
	}
	else if (1 == args)
	{
		GetCmdArg(1, buffer, sizeof(buffer));

		if (strcmp(buffer, "on", false) == 0)
		{
			cv_autoGive.SetInt(1);
			PrintToChatAll("\x04出生自动给予物品\x03 已开启");
		}
		else if (strcmp(buffer, "off", false) == 0)
		{
			cv_autoGive.SetInt(0);
			PrintToChatAll("\x04出生自动给予物品\x03 已关闭");
		}
		else if (strcmp(buffer, "clear", false) == 0 && 0 == client)
		{
			g_autoGive.Clear();
		}
		else if (0 == client) // 只允许在服务器端命令行设置物资 防止玩家指令误操作
		{
			if (-1 == g_autoGive.FindString(buffer))
				g_autoGive.PushString(buffer);
		}
	}
	else if (0 == client)
		PrintToServer("参数过多，请一次只添加一种物资");
	return Plugin_Handled;
}

public void AutoMultipleChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetMultiple();
}

public void SurvivorLimitChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	cv_l4dSurvivorLimit.SetInt(cv_survivorLimit.IntValue);
}
public void MaxplayersChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (cv_allowSset.IntValue == 2)
		cv_svmaxplayers.IntValue = cv_maxs.IntValue;
	else
		cv_maxs.IntValue = cv_svmaxplayers.IntValue;
}

public void OnConfigsExecuted()
{
	if (cv_allowSset.IntValue >= 0 && null != cv_svmaxplayers)
		cv_svmaxplayers.IntValue = cv_maxs.IntValue;
	g_isOnVersus = (GetBaseMode() == OnVersus);
}

public void OnClientDisconnect(int client)
{
	// 重置一些数据
	if (IsFakeClient(client))
		return;
	g_autoJoin[client] = true;
	g_lastTpTime[client] = 0;
}

public void OnMapEnd()
{
	g_allHumanInGame = false;
}
// round_start事件在OnMapStart之前触发，且OnMapStart只在地图变更时会触发
public Action Event_round_start(Event event, const char[] name, bool dontBroadcast)
{
	g_allHumanInGame = false;
	CreateTimer(1.0, Timer_HasClient, _, TIMER_REPEAT);
}
public Action Timer_HasClient(Handle timer, any multiple)
{
	if (GetClients() == 0)
		return Plugin_Continue;

	// 开局以之前的倍数设置一次多倍物资
	// 只有当游戏中有至少一个玩家存在时，物资实体才会存在
	// 此时设置多倍物资才是有效的
	int nowMultiple = g_nowMultiple;
	g_nowMultiple = 1;
	if (cv_autoSupply.IntValue == 1)
		SetMultiple(nowMultiple);
	CreateTimer(1.0, Timer_CheckAllHumanInGame, _, TIMER_REPEAT);
	return Plugin_Stop;
}
public Action Timer_CheckAllHumanInGame(Handle timer)
{
	if (!IsAllHumanInGame())
		return Plugin_Continue;
	// 所有玩家载入完毕之后再校准一次物资倍数
	if (cv_autoSupply.IntValue == 1)
		SetMultiple();
	g_allHumanInGame = true;
	// 让没有加入游戏的玩家自动加入
	if (GetPlayers(TEAM_SURVIVOR) > 0)
	{
		for (int i=1; i<=MaxClients; i++)
		{
			if (g_autoJoin[i])
				JoinSurvivor(i); // 无需判断client有效性 JoinSurvivor自带判断
		}
	}
	return Plugin_Stop;
}

public Action Event_round_end(Event event, const char[] name, bool dontBroadcast)
{
	if (cv_autoKickBot.IntValue == 1)
		KickAllBot(false);
}

public Action Event_player_team(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int oldteam = event.GetInt("oldteam");
	int team = event.GetInt("team");

	if (IsValidClient(client, true))
	{
		// 自动让玩家加入生还者
		if (!IsFakeClient(client))
		{
			if (oldteam==0 && team!=2)
			{
				if (cv_autoJoin.IntValue==1 && g_autoJoin[client])
					CreateTimer(1.0, Timer_AutoJoinSurvivor, client, TIMER_REPEAT);
			}
		}
		// 自动更改物资倍数需所有玩家已完成载入
		if ( g_allHumanInGame && cv_autoSupply.IntValue == 1)
		{
			if ( (0 == oldteam && 2 == team)
			|| (2 == oldteam && 0 == team) )
				CreateTimer(1.2, Timer_SetMultiple);
		}
	}
}
public Action Timer_AutoJoinSurvivor(Handle timer, any client)
{
	if (IsClientConnected(client))
	{
		// 等待玩家完全进入游戏再使其自动加入
		if (IsClientInGame(client))
		{
			JoinSurvivor(client);
			return Plugin_Stop;
		}
		else
		{
			return Plugin_Continue;
		}
	}
	return Plugin_Stop;
}
public Action Timer_SetMultiple(Handle timer)
{
	SetMultiple();
}

void SsetMenuDisplay(int client)
{
	char namelist[128];
	char nameno[16];
	Menu menu = new Menu(SsetMenuHandler);
	menu.SetTitle("设置服务器人数:");
	int i = 1;
	while (i <= 32)
	{
		Format(namelist, 32, "%d", i);
		Format(nameno, 4, "%i", i);
		AddMenuItem(menu, nameno, namelist, 0);
		i++;
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 0);
}
public int SsetMenuHandler(Handle menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char clientinfos[20];
			GetMenuItem(menu, itemNum, clientinfos, sizeof(clientinfos));
			cv_maxs.IntValue = StringToInt(clientinfos);
			cv_svmaxplayers.IntValue = cv_maxs.IntValue;
			PrintToChatAll("\x04更改服务器的最大人数为\x04 \x03%i \x05人", cv_svmaxplayers.IntValue);
		}
		case MenuAction_End:
			delete menu;
	}
	return 0;
}

int DisplayTpMenu(int client)
{
	char name[MAX_NAME_LENGTH];
	char rec[10];
	Menu menu = new Menu(TpMenuHandler);
	menu.SetTitle("你想传送到谁那里？");
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == 2 && IsAlive(i) && i != client)
			{
				GetClientName(i, name, sizeof(name));
				IntToString(i, rec, sizeof(rec));
				menu.AddItem(rec, name);
			}
		}
	}
	menu.ExitBackButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}
public int TpMenuHandler(Menu menu, MenuAction action, int client, int curSel)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			char rec[10];
			if ( menu.GetItem(curSel, rec, sizeof(rec)) )
			{
				int target = StringToInt(rec);
				if ( IsValidClient(target) && GetClientTeam(target)==2
				&& IsValidClient(client) && GetClientTeam(client)==2 )
				{
					Teleport(client, target);
					g_lastTpTime[client] = GetTime();
				}
			}
		}
	}
}

// 设置物资补给倍数，参数为0则根据当前生还者数量自动设置，若未开启多倍物资则重置为1
void SetMultiple(int num=0)
{
	if (0 == num)
	{
		if (cv_autoSupply.IntValue == 1)
		{
			int survivors = GetPlayers(TEAM_SURVIVOR);
			num = survivors / 4;
			// 向上取整且num最小为1
			if (survivors%4 != 0 || 0 == num)
				num++;
		}
		else
			num = 1;
	}

	if (num != g_nowMultiple)
	{
		int len = g_supply.Length;
		char buffer[40];
		char numstr[10];
		IntToString(num, numstr, sizeof(numstr));
		// 如果未自定义物资补给，则只设置医疗包多倍
		if (0 == len)
		{
			SetKeyValueByClassname("weapon_first_aid_kit_spawn", "count", numstr);
		}
		else
		{
			for (int i=0; i<len; i++)
			{
				g_supply.GetString(i, buffer, sizeof(buffer));
				SetKeyValueByClassname(buffer, "count", numstr);
			}
		}
		g_nowMultiple = num;
		PrintToChatAll("\x04物资补给倍数已修改为\x03 %d", num);
	}
}

// all=true:踢出所有BOT all=false:只踢出多余BOT
// 不会踢出处于闲置的BOT
void KickAllBot(bool all=true)
{
	int kickCount = MaxClients;
	if (!all)
		kickCount = GetPlayers(TEAM_SURVIVOR) - cv_survivorLimit.IntValue;

	for (int i=1; i<=MaxClients && kickCount>0; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i))
		{
			if (GetClientTeam(i) == 2)
			{
				if (GetHumanClient(i) == 0)
				{
					KickClient(i, "");
					kickCount--;
				}
			}
		}
	}
}

// 使client加入生还者 会自动判断client有效性
int JoinSurvivor(int client)
{
	if (!IsValidClient(client)) // 判断client有效性
		return 4;
	if (IsFakeClient(client)) // 不允许BOT通过此函数加入生还
		return 5;
	g_autoJoin[client] = true;
	if (GetClientTeam(client) == 2) // client已经是生还者
		return 1;
	if (IsClientIdle(client)) // client处于闲置
		return 2;
	if (!g_allHumanInGame)
		return 3;

	// 搜索可接管BOT，若没有则添加一个
	int bot = FindBotToTakeOver();
	if (bot > 0)
	{
		TakeOverBot(client, bot);
		return 0;
	}
	else
	{
		int ret = AddBot();
		if (0 == ret)
			CreateTimer(0.5, Delay_JoinSurvivor, client);
		return ret;
	}
}
public Action Delay_JoinSurvivor(Handle timer, any client)
{
	JoinSurvivor(client);
}

// AddBot 返回0表示成功增加BOT 返回-1表示当前不允许增加BOT 返回-2表示无需增加BOT
int AddBot(bool force=false)
{
	if (!force && cv_onlySafeAddBot.IntValue == 1
	&& L4D_HasAnySurvivorLeftSafeArea() )
		return -1;
	if (!force && GetAliveBotSurvivors() >= GetSpectators()
	&& GetPlayers(TEAM_SURVIVOR) >= cv_survivorLimit.IntValue )
		return -2;

	int bot = CreateFakeClient("survivor bot");
	if (bot > 0)
	{
		KickClientEx(bot, "");
		ChangeClientTeam(bot, 2);
		if (DispatchKeyValue(bot, "classname", "SurvivorBot") && DispatchSpawn(bot))
		{
			// 如果新BOT是死亡的则复活它
			if (!IsAlive(bot) && h_RoundRespawn != INVALID_HANDLE )
				SDKCall(h_RoundRespawn, bot);
			if (!IsAlive(bot))
			{
				KickClient(bot, "无法复活BOT");
				return -5;
			}

			// 如果已经有人离开安全区
			if (L4D_HasAnySurvivorLeftSafeArea())
			{
				// 传送
				for (int i=1; i<=MaxClients; i++)
				{
					if (IsClientInGame(i))
					{
						if (GetClientTeam(i) == 2 && bot!=i && IsAlive(i))
						{
							Teleport(bot, i);
							break;
						}
					}
				}
				// 给予物品
				if (cv_autoGive.IntValue == 1)
					GivePlayerSupply(bot);
			}
			KickClient(bot, "");
			return 0;
		}
		KickClient(bot, "");
		LogError("生成生还者BOT失败");
		return -4;
	}
	else
	{
		LogError("BOT创建失败");
		return -3;
	}
}

void GivePlayerSupply(int client)
{
	if (!IsValidClient(client))
		return;
	int len = g_autoGive.Length;
	char buffer[40];
	if (len > 0)
	{
		for (int i=0; i<len; i++)
		{
			g_autoGive.GetString(i, buffer, sizeof(buffer));
			CheatCommand(client, "give", buffer);
		}
	}
	else
		CheatCommand(client, "give", "smg_mp5");
}

// 寻找一个可以被玩家接管的生还者BOT，若未找到则返回0
int FindBotToTakeOver()
{
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == 2 && IsFakeClient(i))
			{
				if (IsAlive(i) && GetHumanClient(i) == 0)
					return i;
			}
		}
	}
	return 0;
}

// 接管jointeam加入生还者的功能
public Action Command_Jointeam(int client, const char[] command, int args)
{
	if (args > 0)
	{
		char buffer[MAX_NAME_LENGTH];
		GetCmdArg(1, buffer, sizeof(buffer));
		if ( strcmp(buffer, "2") == 0
		|| strcmp(buffer, "survivor", false) == 0 )
		{
			int bot = FindBotToTakeOver();
			GetClientName(client, buffer, sizeof(buffer));
			if (h_SetHumanSpec == INVALID_HANDLE && bot > 0)
			{
				LogMessage("放行 %s jointeam survivor", buffer);
				return Plugin_Continue;
			}
			else if (h_TakeOverBot == INVALID_HANDLE
			&& bot > 0 && g_isOnVersus )
			{
				LogMessage("放行 %s jointeam survivor", buffer);
				return Plugin_Continue;
			}
			else
			{
				JoinSurvivor(client);
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

// 让玩家接管一个生还者BOT
void TakeOverBot(int client, int bot)
{
	// 完全接管适用于基于对抗模式的药役
	// 战役模式应不完全接管
	if (g_isOnVersus)
	{
		if ( h_SetHumanSpec != INVALID_HANDLE
		&& h_TakeOverBot != INVALID_HANDLE )
		{
			SDKCall(h_SetHumanSpec, bot, client);
			SDKCall(h_TakeOverBot, client, true);
		}
		else
			ClientCommand(client, "jointeam 2");
	}
	else
	{
		if (h_SetHumanSpec != INVALID_HANDLE)
		{
			SDKCall(h_SetHumanSpec, bot, client);
	//		SDKCall(h_SetObserverTarget, client, bot);
			SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
			WriteTakeoverPanel(client, bot);
		}
		else
		{
			ClientCommand(client, "jointeam 2");
			ClientCommand(client, "go_away_from_keyboard");
		}
	}
}
// WriteTakeoverPanel 来源于 [Lux]survivor_afk_fix.sp
//Thanks Leonardo for helping me with the vgui keyvalue layout
//This is for rare case sometimes the takeover panel don't show.
void WriteTakeoverPanel(int client, int bot)
{
	char buf[2];
	int character = GetEntProp(bot, Prop_Send, "m_survivorCharacter", 1);
	IntToString(character, buf, sizeof(buf));
	BfWrite msg = view_as<BfWrite>(StartMessageOne("VGUIMenu", client));
	msg.WriteString("takeover_survivor_bar"); //type
	msg.WriteByte(true); //hide or show panel type
	msg.WriteByte(1); //amount of keys
	msg.WriteString("character"); //key name
	msg.WriteString(buf); //key value
	EndMessage();
}


// 载入SDKCall Function
#define GAMEDATAFILE "l4d2_multislots"
#define SDKCall_RoundRespawn_Key			"RoundRespawn"
#define SDKCall_RoundRespawn_Windows		"\\x56\\x8B\\xF1\\xE8\\x2A\\x2A\\x2A\\x2A\\xE8\\x2A\\x2A\\x2A\\x2A\\x84\\xC0\\x75"
#define SDKCall_RoundRespawn_Linux			"@_ZN13CTerrorPlayer12RoundRespawnEv"
#define SDKCall_SetHumanSpec_Key			"SetHumanSpec"
#define SDKCall_SetHumanSpec_Windows		"\\x55\\x8B\\xEC\\x56\\x8B\\xF1\\x83\\xBE\\x2A\\x2A\\x2A\\x2A\\x00\\x7E\\x07\\x32\\xC0\\x5E\\x5D\\xC2\\x04\\x00\\x8B\\x0D"
#define SDKCall_SetHumanSpec_Linux			"@_ZN11SurvivorBot17SetHumanSpectatorEP13CTerrorPlayer"
#define SDKCall_TakeOverBot_Key				"TakeOverBot"
#define SDKCall_TakeOverBot_Windows			"\\x55\\x8B\\xEC\\x81\\xEC\\x2A\\x2A\\x2A\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x33\\xC5\\x89\\x45\\xFC\\x53\\x56\\x8D\\x85"
#define SDKCall_TakeOverBot_Linux			"@_ZN13CTerrorPlayer11TakeOverBotEb"
#define SDKCall_SetObserverTarget_Key		"SetObserverTarget"
#define SDKCall_SetObserverTarget_Windows	402
#define SDKCall_SetObserverTarget_Linux		403

void LoadSDKCallFunction()
{
	char filePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, filePath, sizeof(filePath), "gamedata/%s.txt", GAMEDATAFILE);
	if (FileExists(filePath))
		LoadGameData();
	else
	{
		LogError("未找到文件 %s ，将自动创建", filePath);
		if (CreateGameDataFile(filePath))
			LoadGameData();
		else
			LogError("创建文件 %s 失败", filePath);
	}
}

void LoadGameData()
{
	h_RoundRespawn = INVALID_HANDLE;
	h_SetHumanSpec = INVALID_HANDLE;
	h_TakeOverBot = INVALID_HANDLE;
	h_SetObserverTarget = INVALID_HANDLE;

	GameData hGameData = new GameData(GAMEDATAFILE);
	if (hGameData == null)
	{
		LogError("无法载入 %s", GAMEDATAFILE);
		return;
	}

	// CTerrorPlayer::RoundRespawn
	StartPrepSDKCall(SDKCall_Player);
	if (PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, SDKCall_RoundRespawn_Key))
	{
		h_RoundRespawn = EndPrepSDKCall();
		if (h_RoundRespawn == INVALID_HANDLE)
			LogError("无法创建SDKCall ： CTerrorPlayer::RoundRespawn");
	}
	else
		LogError("未能找到签名 ： CTerrorPlayer::RoundRespawn");

	// SurvivorBot::SetHumanSpectator
	StartPrepSDKCall(SDKCall_Player);
	if (PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, SDKCall_SetHumanSpec_Key))
	{
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
		h_SetHumanSpec = EndPrepSDKCall();
		if (h_SetHumanSpec == INVALID_HANDLE)
			LogError("无法创建SDKCall ： SurvivorBot::SetHumanSpectator");
	}
	else
		LogError("未能找到签名 ： SurvivorBot::SetHumanSpectator");

	// CTerrorPlayer::TakeOverBot
	StartPrepSDKCall(SDKCall_Player);
	if (PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, SDKCall_TakeOverBot_Key))
	{
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
		h_TakeOverBot = EndPrepSDKCall();
		if (h_TakeOverBot == INVALID_HANDLE)
			LogError("无法创建SDKCall ： CTerrorPlayer::TakeOverBot");
	}
	else
		LogError("未能找到签名 ： CTerrorPlayer::TakeOverBot");

	// CTerrorPlayer::SetObserverTarget
	StartPrepSDKCall(SDKCall_Player);
	if (PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, SDKCall_SetObserverTarget_Key))
	{
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		h_SetObserverTarget = EndPrepSDKCall();
		if (h_SetObserverTarget == INVALID_HANDLE)
			LogError("无法创建SDKCall ： CTerrorPlayer::SetObserverTarget'");
	}
	else
		LogError("未能找到Offset ： CTerrorPlayer::SetObserverTarget");

	CloseHandle(hGameData);
}

bool CreateGameDataFile(const char[] filePath)
{
	Handle hFile = OpenFile(filePath, "w");
	if (!hFile)
		return false;

	WriteFileLine(hFile, "\"Games\"");
	WriteFileLine(hFile, "{");
	WriteFileLine(hFile, "\x09\"left4dead2\"");
	WriteFileLine(hFile, "\x09{");
	WriteFileLine(hFile, "\x09\x09\"Offsets\"");
	WriteFileLine(hFile, "\x09\x09{");
	WriteFileLine(hFile, "\x09\x09\x09\"%s\"", SDKCall_SetObserverTarget_Key);
	WriteFileLine(hFile, "\x09\x09\x09{");
	WriteFileLine(hFile, "\x09\x09\x09\x09\"linux\"\x09\x09\"%d\"", SDKCall_SetObserverTarget_Linux);
	WriteFileLine(hFile, "\x09\x09\x09\x09\"windows\"\x09\"%d\"", SDKCall_SetObserverTarget_Windows);
	WriteFileLine(hFile, "\x09\x09\x09}");
	WriteFileLine(hFile, "\x09\x09}");
	WriteFileLine(hFile, "\x09\x09\"Signatures\"");
	WriteFileLine(hFile, "\x09\x09{");
	WriteFileLine(hFile, "\x09\x09\x09\"%s\"", SDKCall_RoundRespawn_Key);
	WriteFileLine(hFile, "\x09\x09\x09{");
	WriteFileLine(hFile, "\x09\x09\x09\x09\"library\"\x09\"server\"");
	WriteFileLine(hFile, "\x09\x09\x09\x09\"linux\"\x09\x09\"%s\"", SDKCall_RoundRespawn_Linux);
	WriteFileLine(hFile, "\x09\x09\x09\x09\"windows\"\x09\"%s\"", SDKCall_RoundRespawn_Windows);
	WriteFileLine(hFile, "\x09\x09\x09}");
	WriteFileLine(hFile, "\x09\x09\x09\"%s\"", SDKCall_SetHumanSpec_Key);
	WriteFileLine(hFile, "\x09\x09\x09{");
	WriteFileLine(hFile, "\x09\x09\x09\x09\"library\"\x09\"server\"");
	WriteFileLine(hFile, "\x09\x09\x09\x09\"linux\"\x09\x09\"%s\"", SDKCall_SetHumanSpec_Linux);
	WriteFileLine(hFile, "\x09\x09\x09\x09\"windows\"\x09\"%s\"", SDKCall_SetHumanSpec_Windows);
	WriteFileLine(hFile, "\x09\x09\x09}");
	WriteFileLine(hFile, "\x09\x09\x09\"%s\"", SDKCall_TakeOverBot_Key);
	WriteFileLine(hFile, "\x09\x09\x09{");
	WriteFileLine(hFile, "\x09\x09\x09\x09\"library\"\x09\"server\"");
	WriteFileLine(hFile, "\x09\x09\x09\x09\"linux\"\x09\x09\"%s\"", SDKCall_TakeOverBot_Linux);
	WriteFileLine(hFile, "\x09\x09\x09\x09\"windows\"\x09\"%s\"", SDKCall_TakeOverBot_Windows);
	WriteFileLine(hFile, "\x09\x09\x09}");
	WriteFileLine(hFile, "\x09\x09}");
	WriteFileLine(hFile, "\x09}");
	WriteFileLine(hFile, "}");

	CloseHandle(hFile);
	return true;
}