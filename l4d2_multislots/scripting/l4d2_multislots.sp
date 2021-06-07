// 多人控制 主要是自用 代码参考了望夜与豆瓣插件包中的多人插件

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
ConVar cv_autoGive;
ConVar cv_autoMultiple;
ConVar cv_allowsset;
ConVar cv_maxs;
ConVar cv_botlimit;
ConVar cv_autojoin;
ConVar cv_onlySafeAddBot;
ConVar cv_autokickbot;

ArrayList g_autoGive; // 自动给予哪些
ArrayList g_supply; // 哪些启用多倍物资补给
int g_maxplayers = -1;
int g_nowMultiple = 1; // 当前物资倍数
bool g_allPlayerLoaded = false; // 开局检测所有玩家是否已经载入完毕
bool g_isFirstSet = false; // 是否已在开局设置过一次物资多倍补给

bool g_noAutoJoin[MAXPLAYERS+1] = false; // 哪些玩家不自动加入

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion game = GetEngineVersion();
	if (game != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "本插件只支持 Left 4 Dead 2 .");
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

	cv_l4dSurvivorLimit = FindConVar("survivor_limit");
	cv_svmaxplayers = FindConVar("sv_maxplayers");
	cv_autoGive = CreateConVar("l4d2_multislots_auto_give", "1", "自动给予离开安全区以后新出生的生还者武器与物品", _, true, 0.0, true, 1.0);
	cv_autoMultiple = CreateConVar("l4d2_multislots_auto_multiple", "1", "根据人数自动设置物资倍数", _, true, 0.0, true, 1.0);
	cv_allowsset = 	CreateConVar("l4d2_multislots_enabled_sset", "1", "允许插件控制服务器最大人数？若启用则在游戏过程中也可以使用!sset指令来修改最大人数", _, true, 0.0, true, 1.0);
	cv_maxs = 		CreateConVar("l4d2_multislots_maxs", "8", "服务器默认最大人数，不允许插件控制人数时本参数无效", _, true, 1.0, true, 32.0);
	cv_botlimit = 	CreateConVar("l4d2_multislots_bot_limit", "4", "生还者人数不足多少时可以手动添加BOT", _, true, 0.0, true, 32.0);
	cv_autojoin = 	CreateConVar("l4d2_multislots_auto_join", "1", "玩家连接完毕后是否自动使其加入游戏", _, true, 0.0, true, 1.0);
	cv_onlySafeAddBot = CreateConVar("l4d2_multislots_onlysafe_addbot", "0", "只允许在安全区内增加BOT", _, true, 0.0, true, 1.0);
	cv_autokickbot = CreateConVar("l4d2_multislots_auto_kickbot", "1", "当前回合结束是否自动踢出多余BOT", _, true, 0.0, true, 1.0);
	AutoExecConfig(true, "l4d2_multislots");
//	cv_l4dSurvivorLimit.SetBounds();
	cv_autoMultiple.AddChangeHook(AutoMultipleChanged);
	cv_l4dSurvivorLimit.AddChangeHook(SurvivorLimitChanged);
	cv_botlimit.AddChangeHook(SurvivorLimitChanged);

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
	if (AddBot(true) == 0)
		PrintToChat(client, "\x04[提示]\x05已强制添加一个BOT.");
	return Plugin_Handled;
}

public Action Cmd_addbot(int client, int agrs)
{
	switch (AddBot())
	{
		case -1:
			PrintToChat(client, "\x04[提示]\x05服务器只允许未出安全区时增加BOT.");
		case -2:
			PrintToChat(client, "\x04[提示]\x05当前无需增加BOT.");
	}
	return Plugin_Handled;
}

public Action Cmd_away(int client, int args)
{
	if (GetClientTeam(client) == 1)
	{
		if (IsClientIdle(client))
			PrintToChat(client, "\x04[提示]\x05你当前已经是闲置状态.");
		else
			PrintToChat(client, "\x04[提示]\x05你已经是旁观者了.");
		return Plugin_Handled;
	}

	if (GetClientTeam(client) == 2)
		g_noAutoJoin[client] = true;
	ChangeClientTeam(client, 1);
	return Plugin_Handled;
}

public Action Cmd_afk(int client, int args)
{
	if (GetClientTeam(client) == 1)
	{
		if (IsClientIdle(client))
			PrintToChat(client, "\x04[提示]\x05你当前已经是闲置状态.");
		else
			PrintToChat(client, "\x04[提示]\x05你已经是旁观者了.");
		return Plugin_Handled;
	}

	if (GetClientTeam(client) != 2)
		PrintToChat(client, "\x04[提示]\x05闲置指令只限生还者使用.");
	else
	{
		if (IsPlayerAlive(client))
		{
			if (GetEntProp(client, Prop_Send, "m_isIncapacitated"))
				PrintToChat(client, "\x04[提示]\x05倒地时无法使用闲置指令.");
			else
				FakeClientCommand(client, "go_away_from_keyboard");
		}
		else
			PrintToChat(client, "\x04[提示]\x05死亡状态无权使用闲置指令.");
	}
	return Plugin_Handled;
}

public Action Cmd_joingame(int client, int args)
{
	switch (JoinSurvivor(client))
	{
		case -1:
			PrintToChat(client, "\x04[提示]\x05请等待本回合结束后再加入游戏.");
		case -2:
			PrintToChat(client, "\x04[提示]\x05当前生还者空位不足，暂时无法加入.");
		case -4:
			PrintToChat(client, "\x04[提示]\x05你已经是生还者了.");
		case -5:
			PrintToChat(client, "\x04[提示]\x05你当前是闲置状态，请点击鼠标左键加入游戏.");
	}
	return Plugin_Handled;
}

public Action Cmd_kb(int client, int args)
{
	KickAllBot();
	PrintToChatAll("\x04[提示]\x05踢除所有bot.");

	return Plugin_Handled;
}

public Action Cmd_sset(int client, int args)
{
	if (client)
	{
		if (null == cv_svmaxplayers)
			PrintToChat(client, "\x04[提示]\x05插件未能捕捉到sv_maxplayers.");
		else if (cv_allowsset.IntValue == 1)
			SsetMenuDisplay(client);
		else
			PrintToChat(client, "\x04[提示]\x05服务器人数控制未开启.");
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

		if (strcmp(buffer, "on") == 0)
		{
			cv_autoMultiple.SetInt(1);
			PrintToChatAll("\x04自动多倍物资补给\x03 已开启");
		}
		else if (strcmp(buffer, "off") == 0)
		{
			cv_autoMultiple.SetInt(0);
			PrintToChatAll("\x04自动多倍物资补给\x03 已关闭");
		}
		else if (strcmp(buffer, "clear") == 0 && 0 == client)
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
				PrintToServer("未设置自动给予的物品");
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

		if (strcmp(buffer, "on") == 0)
		{
			cv_autoGive.SetInt(1);
			PrintToChatAll("\x04出生自动给予物品\x03 已开启");
		}
		else if (strcmp(buffer, "off") == 0)
		{
			cv_autoGive.SetInt(0);
			PrintToChatAll("\x04出生自动给予物品\x03 已关闭");
		}
		else if (strcmp(buffer, "clear") == 0 && 0 == client)
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
	cv_l4dSurvivorLimit.SetInt(cv_botlimit.IntValue);
}

public void OnConfigsExecuted()
{
	if (-1 == g_maxplayers)
		g_maxplayers = cv_maxs.IntValue;
	if (cv_allowsset.IntValue==1 && cv_svmaxplayers!=null)
	{
		cv_svmaxplayers.SetInt(g_maxplayers);
	}
}

// 游戏中途离线 无需判断是不是BOT
public void OnClientDisconnect(int client)
{
	if (g_allPlayerLoaded)
		g_noAutoJoin[client] = false;
}

// 只有当第一个玩家进入游戏以后，物资实体才会生成，此时设置物资多倍才有效
public void OnClientPutInServer(client)
{
	// 判断是否需要在开局设置一次物资补给
	if (g_isFirstSet)
		return;
	if (IsFakeClient(client))
		return;
	g_isFirstSet = true;
	CreateTimer(1.0, Timer_FirstSetMultipe);
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
	g_isFirstSet = false;
	g_allPlayerLoaded = false;
	CreateTimer(1.0, Timer_CheckPlayerInGame, _, TIMER_REPEAT);
}
// 当所有玩家载入完毕之后
public Action Timer_CheckPlayerInGame(Handle timer, any data)
{
	if (AreAllInGame())
	{
		g_allPlayerLoaded = true;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action Event_round_end(Event event, const char[] name, bool dontBroadcast)
{
	g_allPlayerLoaded = false;
	if (cv_autokickbot.IntValue == 1)
		KickAllBot(false);
}

// 玩家刚加入游戏时自动让其加入生还者
// 若在对抗模式启用本功能所有刚加入游戏的玩家都会自动加入生还者
// 对抗模式最好不要启用本插件或者禁用本功能
public Action Event_player_team(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int oldteam = event.GetInt("oldteam");
	int team = event.GetInt("team");

	if (!IsValidClient(client))
		return Plugin_Continue;
	if (IsFakeClient(client))
		return Plugin_Continue;

	// 自动更改物资倍数需所有玩家已完成载入
	if (g_allPlayerLoaded && cv_autoMultiple.IntValue == 1)
		CreateTimer(0.5, Timer_SetMultiple);

	if (oldteam==0 && team!=2)
	{
		if (cv_autojoin.IntValue==1 && !g_noAutoJoin[client])
			CreateTimer(1.0, Timer_AutoJoinSurvivor, client, TIMER_REPEAT);
	}
	return Plugin_Continue;
}
public Action Timer_SetMultiple(Handle timer)
{
	SetMultiple();
}

public Action Timer_AutoJoinSurvivor(Handle timer, any client)
{
	if (g_allPlayerLoaded)
	{
		JoinSurvivor(client);
		return Plugin_Stop;
	}
	return Plugin_Continue;
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
			PrintToChatAll("\x04[提示]\x05更改服务器的最大人数为\x04 \x03%i \x05人.", cv_svmaxplayers.IntValue);
		}
		case MenuAction_End:
			delete menu;
	}
	return 0;
}

// 设置物资补给倍数，参数为-1则根据当前玩家数量自动设置
void SetMultiple(int num=-1)
{
	if (-1 == num)
	{
		int playerNum = AllPlayers();
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
		kickCount = Survivors() - cv_botlimit.IntValue;
	}
	for (int i=1; i<=MaxClients && kickCount>0; i++)
	{
		if (GetHumanClient(i) == 0)
		{
			KickClient(i, "");
			kickCount--;
		}
	}
}

int JoinSurvivor(client)
{
	if (!IsValidClient(client))
		return -6;
	if (IsFakeClient(client))
		return -3;
	if (GetClientTeam(client) == 2)
		return -4;
	if (IsClientIdle(client))
		return -5;

	if (0 < AliveBotSurvivors())
	{
		ClientCommand(client, "jointeam 2");
		return 0;
	}
	else
	{
		switch (AddBot())
		{
			case 0:
			{
				CreateTimer(1.0, Timer_Jointeam2, client);
				return 0;
			}
			case -1:
				return -1;
			case -2:
				return -2;
		}
		return -6;
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
	if (AliveBotSurvivors()>=Spectator() && Survivors()>=cv_botlimit.IntValue && !force)
		return -2;

	int survivorbot = CreateFakeClient("survivor bot");
	ChangeClientTeam(survivorbot, 2);
	DispatchKeyValue(survivorbot, "classname", "SurvivorBot");
	DispatchSpawn(survivorbot);
	// 如果新BOT是死亡的则复活它
	if (!IsAlive(survivorbot))
		SDKCall(h_RoundRespawn, survivorbot);

	// 传送BOT
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
	if (cv_autoGive.IntValue == 1 && L4D_HasAnySurvivorLeftSafeArea())
	{
		GivePlayerSupply(survivorbot);
	}
	KickClient(survivorbot, "Cmd_addbot...");
	return 0;
}

void GivePlayerSupply(int client)
{
	if (!IsValidClient(client))
		return;
	int len = g_autoGive.Length;
	char buffer[40];
	for (int i=0; i<len; i++)
	{
		g_autoGive.GetString(i, buffer, sizeof(buffer));
		BypassAndExecuteCommand(client, "give", buffer);
	}
}

// 所有玩家是否已载入到游戏
bool AreAllInGame()
{
	for (int i=1; i<=MaxClients; i++)
	{
		// 已连接且不是BOT，但尚未在游戏中的玩家
		if (IsClientConnected(i) && !IsFakeClient(i) && !IsClientInGame(i))
			return false;
	}
	return true;
}

// 当前在线的玩家数量（生还+旁观）
int AllPlayers()
{
	int numplayers = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			if(!IsFakeClient(i) && GetClientTeam(i) != 3)
				numplayers++;
		}
	}
	return numplayers;
}

//TakeOverBot(client, bool:completely)
//{
//	if (IsClientInGame(client))
//	{
//		if (GetClientTeam(client) == 2)
//		{
//			return 0;
//		}
//		if (IsFakeClient(client))
//		{
//			return 0;
//		}
//		new bot = FindBotToTakeOver();
//		if (bot)
//		{
//			if (completely)
//			{
//				SDKCall(hSetHumanSpec, bot, client);
//				SDKCall(hTakeOverBot, client, 1);
//			}
//			else
//			{
//				SDKCall(hSetHumanSpec, bot, client);
//				SetEntProp(client, 0, "m_iObserverMode", 5, 4, 0);
//			}
//			return 0;
//		}
//		PrintHintText(client, "[提示] 目前没有存活的电脑接管.");
//		return 0;
//	}
//	return 0;
//}

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