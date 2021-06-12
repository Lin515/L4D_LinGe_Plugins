// 多人控制 主要是自用 代码参考了望夜多人插件(R_smc)与豆瓣多人插件（l4d2_multislots SwiftReal, MI 5, 豆瓣）

#include <sourcemod>
#include <sdktools>
#include <LinGe_Function>
#include <left4dhooks>

public Plugin myinfo = {
	name = "多人控制",
	author = "LinGe",
	description = "L4D2多人控制",
	version = "2.0",
	url = "https://github.com/LinGe515"
};

// SDKCall Function
Handle h_RoundRespawn;
Handle h_SetHumanSpec;
Handle h_TakeOverBot;

ConVar cv_l4dSurvivorLimit;
ConVar cv_svmaxplayers;
ConVar cv_survivorLimit;
ConVar cv_maxs;
ConVar cv_autoGive;
ConVar cv_autoMultiple;
ConVar cv_allowSset;
ConVar cv_autoJoin;
ConVar cv_onlySafeAddBot;
ConVar cv_autoKickBot;
ConVar cv_tpPermission;
ConVar cv_tpLimit;

ArrayList g_autoGive; // 自动给予哪些
ArrayList g_supply; // 哪些启用多倍物资补给
int g_maxplayers = -999;
int g_nowMultiple = 1; // 当前物资倍数
bool g_allPlayerLoaded = false; // 开局检测所有玩家是否已经载入完毕
bool g_isFirstHumanPutInServer = false; // 第一个玩家是否已经载入

bool g_noAutoJoin[MAXPLAYERS+1] = false; // 哪些玩家不自动加入
int g_lastTpTime[MAXPLAYERS+1] = 0;

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

	RegAdminCmd("sm_forceaddbot", Cmd_forceaddbot, ADMFLAG_ROOT, "强制增加一个BOT，无视条件限制");
	RegAdminCmd("sm_addbot", Cmd_addbot, ADMFLAG_KICK, "增加一个BOT");
	RegAdminCmd("sm_ab", Cmd_addbot, ADMFLAG_KICK, "增加一个BOT");
	RegAdminCmd("sm_kb", Cmd_kb, ADMFLAG_KICK, "踢出所有电脑BOT");
	RegAdminCmd("sm_sset", Cmd_sset, ADMFLAG_ROOT, "设置服务器最大人数");
	RegAdminCmd("sm_mmn", Cmd_mmn, ADMFLAG_ROOT, "自动多倍物资设置");
	RegAdminCmd("sm_autogive", Cmd_autogive, ADMFLAG_ROOT, "自动给予物品设置");

	RegConsoleCmd("sm_jg", Cmd_joingame, "玩家加入生还者");
	RegConsoleCmd("sm_join", Cmd_joingame, "玩家加入生还者");
	RegConsoleCmd("sm_joingame", Cmd_joingame, "玩家加入生还者");
	RegConsoleCmd("sm_away", Cmd_away, "玩家进入旁观");
	RegConsoleCmd("sm_s", Cmd_away, "玩家进入旁观");
	RegConsoleCmd("sm_spec", Cmd_away, "玩家进入旁观");
	RegConsoleCmd("sm_spectate", Cmd_away, "玩家进入旁观");
	RegConsoleCmd("sm_afk", Cmd_afk, "快速闲置");
	RegConsoleCmd("sm_tp", Cmd_tp, "玩家自主传送指令");

	cv_l4dSurvivorLimit	= FindConVar("survivor_limit");
	cv_svmaxplayers		= FindConVar("sv_maxplayers");
	cv_survivorLimit	= CreateConVar("l4d2_multislots_survivor_limit", "4", "生还者初始数量（添加多了服务器会爆卡喔，要是满了32个会刷不出特感）", FCVAR_NOTIFY, true, 1.0, true, 32.0);
	cv_maxs				= CreateConVar("l4d2_multislots_maxs", "8", "服务器默认最大人数，不允许插件控制人数时本参数无效", FCVAR_NOTIFY, true, 1.0, true, 32.0);
	cv_autoGive			= CreateConVar("l4d2_multislots_auto_give", "1", "自动给予离开安全区以后新出生的生还者武器与物品", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cv_autoMultiple		= CreateConVar("l4d2_multislots_auto_multiple", "1", "根据人数自动设置物资倍数", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cv_allowSset		= CreateConVar("l4d2_multislots_allow_sset", "1", "允许插件控制服务器最大人数？0:不允许 1:允许且允许其它方式修改最大人数 2:只允许本插件控制最大人数", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	cv_autoJoin			= CreateConVar("l4d2_multislots_auto_join", "1", "玩家连接完毕后是否自动使其加入游戏", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cv_onlySafeAddBot	= CreateConVar("l4d2_multislots_onlysafe_addbot", "0", "只允许在安全区内增加BOT", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cv_autoKickBot		= CreateConVar("l4d2_multislots_auto_kickbot", "1", "当前回合结束是否自动踢出多余BOT", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cv_tpPermission		= CreateConVar("l4d2_multislots_tp_permission", "2", "哪些人可以使用传送指令？0:完全禁用 1:仅管理员可用 2:所有人可用", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	cv_tpLimit			= CreateConVar("l4d2_multislots_tp_limit", "0", "限制玩家使用传送指令的时间间隔，单位为秒", FCVAR_NOTIFY, true, 0.0);

	AutoExecConfig(true, "l4d2_multislots");
	cv_l4dSurvivorLimit.SetBounds(ConVarBound_Upper, true, 32.0);
	cv_autoMultiple.AddChangeHook(AutoMultipleChanged);
	cv_l4dSurvivorLimit.AddChangeHook(SurvivorLimitChanged);
	cv_survivorLimit.AddChangeHook(SurvivorLimitChanged);
	if (null != cv_svmaxplayers)
		cv_svmaxplayers.AddChangeHook(MaxplayersChanged);

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
	if (0 == client)
		return Plugin_Handled;
	if (AddBot(true) == 0)
		PrintToChat(client, "\x04已强制添加一个BOT");
	return Plugin_Handled;
}

public Action Cmd_addbot(int client, int agrs)
{
	if (0 == client)
		return Plugin_Handled;
	switch (AddBot())
	{
		case -1:
			PrintToChat(client, "\x04服务器只允许未出安全区时增加BOT");
		case -2:
			PrintToChat(client, "\x04当前无需增加BOT");
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
		g_noAutoJoin[client] = true;
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
	else if (!IsPlayerAlive(client))
		PrintToChat(client, "\x04死亡状态无权使用闲置");
	else if (GetEntProp(client, Prop_Send, "m_isIncapacitated"))
		PrintToChat(client, "\x04倒地时无法使用闲置");
	else if (GetHumanSurvivors() == 1)
		PrintToChat(client, "\x04只有一名玩家时无法使用闲置");
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
		case -2:
			PrintToChat(client, "\x04当前生还者空位不足，暂时无法加入");
		case -4:
			PrintToChat(client, "\x04你已经是生还者了");
		case -5:
			PrintToChat(client, "\x04你当前是闲置状态，请点击鼠标左键加入游戏");
		case -7:
			PrintToChat(client, "\x04当前有玩家尚未载入完毕，当所有玩家载入完毕时你将自动加入生还者");
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
	if (client)
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
			if (cv_autoMultiple.IntValue == 1)
				PrintToChatAll("\x04自动多倍物资补给\x03 已开启");
			else
				PrintToChatAll("\x04自动多倍物资补给\x03 已关闭");
		}
	}
	else if (1 == args)
	{
		GetCmdArg(1, buffer, sizeof(buffer));

		if (strcmp(buffer, "on", false) == 0)
		{
			cv_autoMultiple.SetInt(1);
			PrintToChatAll("\x04自动多倍物资补给\x03 已开启");
		}
		else if (strcmp(buffer, "off", false) == 0)
		{
			cv_autoMultiple.SetInt(0);
			PrintToChatAll("\x04自动多倍物资补给\x03 已关闭");
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
}

public Action Cmd_autogive(int client, int args)
{
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
}

public void AutoMultipleChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (strcmp(newValue, "1") == 0)
		SetMultiple();
	else
		SetMultiple(1);
}
public void SurvivorLimitChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	cv_l4dSurvivorLimit.SetInt(cv_survivorLimit.IntValue);
}
public void MaxplayersChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	// 若只允许本插件修改最大人数，则将最大人数始终锁定为本插件中的值
	// 否则则以最后更新的值为准
	if (cv_allowSset.IntValue == 2)
		cv_svmaxplayers.SetInt(g_maxplayers);
	else
		g_maxplayers = StringToInt(newValue);
}


public void OnConfigsExecuted()
{
	if (-999 == g_maxplayers)
		g_maxplayers = cv_maxs.IntValue;
	if (cv_allowSset.IntValue>=1 && cv_svmaxplayers!=null)
		cv_svmaxplayers.SetInt(g_maxplayers);

	g_isFirstHumanPutInServer = false;
	g_allPlayerLoaded = false;
}

public void OnClientDisconnect(int client)
{
// 游戏中途离线 重置其数据无需判断是不是BOT
	if (g_allPlayerLoaded)
		g_noAutoJoin[client] = false;
	g_lastTpTime[client] = 0;
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
		return;
	g_lastTpTime[client] = 0;
	if (cv_autoJoin.IntValue==1 && !g_noAutoJoin[client])
		CreateTimer(1.0, Timer_AutoJoinSurvivor, client);

	if (!g_isFirstHumanPutInServer)
	{
		g_isFirstHumanPutInServer = true;
		// 只有当第一个玩家进入游戏以后，物资实体才会生成
		CreateTimer(1.0, Timer_FirstSetMultipe);
	}
}
public Action Timer_AutoJoinSurvivor(Handle timer, any client)
{
	JoinSurvivor(client);
}
public Action Timer_FirstSetMultipe(Handle timer)
{
	int nowMultiple = g_nowMultiple;
	g_nowMultiple = 1;
	if (cv_autoMultiple.IntValue == 1)
		SetMultiple(nowMultiple);
}

public Action Event_round_start(Event event, const char[] name, bool dontBroadcast)
{
	g_allPlayerLoaded = false;
	CreateTimer(1.0, Timer_CheckPlayerInGame, _, TIMER_REPEAT);
}
public Action Timer_CheckPlayerInGame(Handle timer)
{
	// 当所有玩家载入完毕之后
	if (IsAllHumanInGame() && GetSurvivors()>0)
	{
		g_allPlayerLoaded = true;
		CreateTimer(1.0, Timer_AllAutoJoinSurvivor);
		return Plugin_Stop;
	}
	return Plugin_Continue;
}
public Action Timer_AllAutoJoinSurvivor(Handle timer)
{
	// 让玩家自动加入生还者
	for (int i=1; i<=MaxClients; i++)
	{
		if (!g_noAutoJoin[i])
			JoinSurvivor(i); // 无需判断client有效性 JoinSurvivor自带判断
	}
}

public Action Event_round_end(Event event, const char[] name, bool dontBroadcast)
{
	g_allPlayerLoaded = false;
	if (cv_autoKickBot.IntValue == 1)
		KickAllBot(false);
}

public Action Event_player_team(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client, true))
	{
		if (!IsFakeClient(client))
		{
			// 自动更改物资倍数需所有玩家已完成载入
			if (g_allPlayerLoaded && cv_autoMultiple.IntValue == 1)
				CreateTimer(0.5, Timer_SetMultiple);
		}
	}
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
			g_maxplayers = StringToInt(clientinfos);
			cv_svmaxplayers.SetInt(g_maxplayers);
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
	for(int i=1; i<=MaxClients; i++)
	{
		if(IsClientInGame(i))
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
				float vOrigin[3];
				float vAngles[3];
				GetClientAbsOrigin(target, vOrigin);
				GetClientAbsAngles(target, vAngles);
				TeleportEntity(client, vOrigin, vAngles, NULL_VECTOR);
				g_lastTpTime[client] = GetTime();
			}
		}
	}
}

// 设置物资补给倍数，参数为0则根据当前玩家数量自动设置
void SetMultiple(int num=0)
{
	if (0 == num)
	{
		int playerNum = GetPlayers();
		num = playerNum / 4;
		if (playerNum%4 != 0 || 0 == num)
			num++;
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
	{
		kickCount = GetSurvivors() - cv_survivorLimit.IntValue;
	}
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

int JoinSurvivor(client)
{
	if (!IsValidClient(client)) // 判断client有效性
		return -6;
	if (IsFakeClient(client)) // 不允许BOT通过此函数加入生还
		return -3;
	g_noAutoJoin[client] = false;
	if (GetClientTeam(client) == 2) // client已经是生还
		return -4;
	if (IsClientIdle(client)) // client处于闲置
		return -5;
	if (!g_allPlayerLoaded)
		return -7;

	if (0 < GetAliveBotSurvivors())
	{
		ClientCommand(client, "jointeam 2");
		return 0;
	}
	else
	{
		int ret = AddBot();
		if (0 == ret)
			CreateTimer(1.0, Timer_Jointeam2, client);
		return ret;
	}
}
public Action Timer_Jointeam2(Handle timer, any client)
{
	ClientCommand(client, "jointeam 2");
}

// AddBot 返回0表示成功增加BOT 返回1表示当前不允许增加BOT 返回2表示无需增加BOT
int AddBot(bool force=false)
{
	if (cv_onlySafeAddBot.IntValue == 1 && !force)
	{
		if (L4D_HasAnySurvivorLeftSafeArea())
			return -1;
	}
	if (GetAliveBotSurvivors() >= GetSpectators()
	&& GetSurvivors() >= cv_survivorLimit.IntValue
	&& !force)
		return -2;

	int survivorbot = CreateFakeClient("survivor bot");
	ChangeClientTeam(survivorbot, 2);
	DispatchKeyValue(survivorbot, "classname", "SurvivorBot");
	DispatchSpawn(survivorbot);
	// 如果新BOT是死亡的则复活它
	if (!IsAlive(survivorbot))
		SDKCall(h_RoundRespawn, survivorbot);
	
	// 如果已经有人离开安全区
	if (L4D_HasAnySurvivorLeftSafeArea())
	{
		// 传送
		for (int i=1; i<=MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if (GetClientTeam(i) == 2 && survivorbot!=i && IsAlive(i))
				{
					float vOrigin[3] = 0.0;
					float vAngles[3] = 0.0;
					GetClientAbsOrigin(i, vOrigin);
					GetClientAbsAngles(i, vAngles);
					TeleportEntity(survivorbot, vOrigin, vAngles, NULL_VECTOR);
					break;
				}
			}
		}
		// 给予物品
		if (cv_autoGive.IntValue == 1)
			GivePlayerSupply(survivorbot);
	}
	KickClient(survivorbot, "");	
	return 0;
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
			BypassAndExecuteCommand(client, "give", buffer);
		}
	}
	else
		BypassAndExecuteCommand(client, "give", "smg_mp5");
}

// 当前在线的玩家数量（生还+旁观+闲置）
int GetPlayers()
{
	int numplayers = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if(!IsFakeClient(i) && GetClientTeam(i) != 3)
				numplayers++;
		}
	}
	return numplayers;
}

// 载入SDKCall Function
void LoadSDKCallFunction()
{
	// CTerrorPlayer_RoundRespawn
	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetSignature(SDKLibrary_Server, "\x56\x8B\xF1\xE8\x2A\x2A\x2A\x2A\xE8\x2A\x2A\x2A\x2A\x84\xC0\x75", 16))
	{
		if (!PrepSDKCall_SetSignature(SDKLibrary_Server, "@_ZN13CTerrorPlayer12RoundRespawnEv", 0))
			SetFailState("未能找到签名 ： CTerrorPlayer_RoundRespawn");
	}
	h_RoundRespawn = EndPrepSDKCall();
	if (h_RoundRespawn == null)
		SetFailState("无法创建SDKCall ： CTerrorPlayer_RoundRespawn");

	// SurvivorBot_SetHumanSpectator
	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x56\x8B\xF1\x83\xBE\x2A\x2A\x2A\x2A\x00\x7E\x07\x32\xC0\x5E\x5D\xC2\x04\x00\x8B\x0D", 24))
	{
		if (!PrepSDKCall_SetSignature(SDKLibrary_Server, "@_ZN11SurvivorBot17SetHumanSpectatorEP13CTerrorPlayer", 0))
			SetFailState("未能找到签名 ： SurvivorBot_SetHumanSpectator");
	}
	h_SetHumanSpec = EndPrepSDKCall();
	if (h_SetHumanSpec == null)
		SetFailState("无法创建SDKCall ： SurvivorBot_SetHumanSpectator");

	// CTerrorPlayer_TakeOverBot
	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x81\xEC\x2A\x2A\x2A\x2A\xA1\x2A\x2A\x2A\x2A\x33\xC5\x89\x45\xFC\x53\x56\x8D\x85", 23))
	{
		if (!PrepSDKCall_SetSignature(SDKLibrary_Server, "@_ZN13CTerrorPlayer11TakeOverBotEb", 0))
			SetFailState("未能找到签名 ： CTerrorPlayer_TakeOverBot");
	}
	h_TakeOverBot = EndPrepSDKCall();
	if (h_TakeOverBot == null)
		SetFailState("无法创建SDKCall ： CTerrorPlayer_TakeOverBot");
}