// 本插件编写参考 SilverShot l4d_votemode.sp

#include <sourcemod>
#include <adminmenu>
#include <LinGe_Function>
#undef REQUIRE_EXTENSIONS
#include <builtinvotes>
#define REQUIRE_EXTENSIONS
#undef REQUIRE_PLUGIN
#include <LinGe_Library>
#define REQUIRE_PLUGIN

#define CONFIG_MAPVOTE			"data/l4d_mapvote.cfg"

public Plugin myinfo = {
	name = "[L4D] Map Vote",
	author = "LinGe, SilverShot",
	description = "投票换图",
	version = "2.0",
	url = "https://github.com/LinGe515"
};

TopMenu g_hCvarMenuMenu;

ConVar cv_useBuiltinvotes; // 是否使用扩展发起原版投票开关
ConVar cv_mapCheck; // 地图检查开关
ConVar cv_voteTime; // 投票持续时间
ConVar cv_mapchangeDelay; // 地图更换延时

bool g_isBuiltinvotesLoaded = false; // Builtinvotes扩展是否加载成功
bool g_isLinGeLibraryRunning = false; // LinGe_Library插件是否正在运行

bool g_useBuiltinvotes = false; // 当前插件是否使用原版投票
bool g_allowMapChange = true; // 当前是否允许插件发起地图更改
bool g_isMapChange[MAXPLAYERS+1]; // 记录本次指令是否是mapchange
int g_iChangemapTo, g_iSelected[MAXPLAYERS+1];

char g_mapCodes[1024][64], g_mapNames[1024][64];
int g_mapCount;
char g_mapClass[64][64];
int g_configLevel, g_mapIndex[64];

// 只在使用扩展发起投票时用到的变量和函数，其均以_Ext结尾
bool g_isAdminPass_Ext; // 在提前取消投票的时候判断是否是管理员直接通过了本次投票

// Voting variables
bool g_bVoteInProgress; // 当前是否有投票在进行中
int g_iNoCount, g_iVoters, g_iYesCount; // 票数统计
Handle timer_voteCheck = INVALID_HANDLE;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion game = GetEngineVersion();
	if (game!=Engine_Left4Dead && game!=Engine_Left4Dead2)
	{
		strcopy(error, err_max, "本插件只支持 Left 4 Dead 1&2 .");
		// 在1代没经过测试，懒得测试，应该也是支持的
		return APLRes_SilentFailure;
	}
	__ext_builtinvotes_SetNTVOptional();
	__pl_LinGe_Library_SetNTVOptional();
	return APLRes_Success;
}

public void OnPluginStart()
{
	RegAdminCmd("sm_mapveto", CommandVeto,	ADMFLAG_ROOT, "管理员否决本次投票");
	RegAdminCmd("sm_mappass", CommandPass,	ADMFLAG_ROOT, "管理员通过本次投票");
	RegAdminCmd("sm_mapchange", CommandChange,	ADMFLAG_ROOT, "管理员直接更换地图无需经过投票");
	RegConsoleCmd("sm_mapvote", CommandVote, "打开投票换图菜单");

	cv_useBuiltinvotes = CreateConVar("l4d_mapvote_use_builtinvotes", "1", "是否使用builtinvotes扩展发起原版投票？开启情况下，若扩展未正常加载仍会使用sourcemod平台菜单投票。游戏中直接修改这个参数不会生效。", _, true, 0.0, true, 1.0);
	cv_mapCheck = CreateConVar("l4d_mapvote_map_check", "1", "地图检查，若开启则不会显示data/l4d_mapvote.cfg中的无效地图。游戏中直接修改这个参数不会生效。（注意：只有服务端才会自动读取addons下的全部三方图，客户端不会。）", _, true, 0.0, true, 1.0);
	cv_voteTime = CreateConVar("l4d_mapvote_vote_time", "20", "投票应在多少秒内完成？", _, true, 10.0, true, 60.0);
	cv_mapchangeDelay = CreateConVar("l4d_mapvote_mapchange_delay", "5", "地图更换延时", _, true, 0.0, true, 60.0);
	AutoExecConfig(true, "l4d_mapvote");

	Handle topmenu = GetAdminTopMenu();
	if( LibraryExists("adminmenu") && (topmenu != null) )
		OnAdminMenuReady(topmenu);

	if ( GetExtensionFileStatus("builtinvotes.ext") == 1 )
		g_isBuiltinvotesLoaded = true;
	g_isLinGeLibraryRunning = IsPluginRunning("LinGe_Library.smx");
}

// 不编写游戏中途重新读取地图列表的功能，因为读取量太大时会造成短暂的卡顿
public void OnConfigsExecuted()
{
	// 只有当扩展加载成功时才使用原版投票
	if (cv_useBuiltinvotes.IntValue == 1 && g_isBuiltinvotesLoaded)
		g_useBuiltinvotes = true;
	else
		g_useBuiltinvotes = false;
	g_allowMapChange = true;
	LoadConfig();
}

// ====================================================================================================
//					ADD TO ADMIN MENU
// ====================================================================================================
public void OnLibraryRemoved(const char[] name)
{
	if( strcmp(name, "adminmenu") == 0 )
		g_hCvarMenuMenu = null;
}

public void OnAdminMenuReady(Handle topmenu)
{
	if( topmenu == g_hCvarMenuMenu)
		return;

	g_hCvarMenuMenu = view_as<TopMenu>(topmenu);

	TopMenuObject player_commands = FindTopMenuCategory(g_hCvarMenuMenu, ADMINMENU_SERVERCOMMANDS);
	if( player_commands == INVALID_TOPMENUOBJECT ) return;

	AddToTopMenu(g_hCvarMenuMenu, "sm_changemap_menu", TopMenuObject_Item, Handle_Category, player_commands, "sm_changemap_menu", ADMFLAG_GENERIC);
}

public int Handle_Category(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	switch( action )
	{
		case TopMenuAction_DisplayTitle:
			Format(buffer, maxlength, "更换地图");
		case TopMenuAction_DisplayOption:
			Format(buffer, maxlength, "更换地图");
		case TopMenuAction_SelectOption:
		{
			g_isMapChange[param] = true;
			VoteMenu_Select(param);
		}
	}
}

// ====================================================================================================
//					LOAD CONFIG
// ====================================================================================================
void LoadConfig()
{
	// 获取到配置文件的绝对路径
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_MAPVOTE);

	g_mapCount = 0;
	g_configLevel = 0;
	if (FileExists(sPath))
		ParseConfigFile(sPath); // 读取data/l4d_mapvote.cfg中的地图
	else
		g_configLevel = 1;
//	LoadMapList(); // 读取所有能读取的地图
	// 不过因为插件无法获取到地图的显示名称，相较于sourcemod的votemap也没什么太大区别
	// 所以感觉这个功能意义不是很大，暂不启用
}

bool ParseConfigFile(const char[] file)
{
	SMCParser parser = new SMCParser();
	SMC_SetReaders(parser, Config_NewSection, Config_KeyValue, Config_EndSection);
	parser.OnEnd = Config_End;

	char error[128];
	int line = 0, col = 0;
	SMCError result = parser.ParseFile(file, line, col);
	delete parser;

	if( result != SMCError_Okay )
	{
		SMC_GetErrorString(result, error, sizeof(error));
		SetFailState("%s on line %d, col %d of %s [%d]", error, line, col, file, result);
	}

	return (result == SMCError_Okay);
}

public SMCResult Config_NewSection(Handle parser, const char[] section, bool quotes)
{
	g_configLevel++;
	if( g_configLevel > 1 )
	{
		strcopy(g_mapClass[g_configLevel-2], 64, section);
		g_mapIndex[g_configLevel-2] = g_mapCount;
	}
	return SMCParse_Continue;
}

public SMCResult Config_KeyValue(Handle parser, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	if (!IsMapValid(value) && cv_mapCheck.IntValue == 1)
		return SMCParse_Continue;
	strcopy(g_mapNames[g_mapCount], 64, key);
	strcopy(g_mapCodes[g_mapCount], 64, value);
	g_mapCount++;
	return SMCParse_Continue;
}

public SMCResult Config_EndSection(Handle parser)
{
	g_mapIndex[g_configLevel-1] = g_mapCount;
	return SMCParse_Continue;
}

public void Config_End(Handle parser, bool halted, bool failed)
{
	if( failed )
		SetFailState("Error: Cannot load the mapvote config.");
}

// 直接从sourcemod自带的votemap.sp复制过来改写的，懒得深究细节
void LoadMapList()
{
	Handle map_array = null;
	int map_serial = -1;

	if ((map_array = ReadMapList(null,
			map_serial,
			"sm_votemap menu",
			MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER))
		== null)
	{
		return;
	}

	int map_count = GetArraySize(map_array);
	g_configLevel++;
	strcopy(g_mapClass[g_configLevel-2], 64, "所有地图");
	g_mapIndex[g_configLevel-2] = g_mapCount;

	for (int i=0; i<map_count; i++)
	{
		GetArrayString(map_array, i, g_mapCodes[g_mapCount], 64);
		GetArrayString(map_array, i, g_mapNames[g_mapCount], 64);
		// 在求生之路里，GetMapDisplayName是没有用的，它获取不到地图文本里的DisplayName
		//GetMapDisplayName(g_mapCodes[g_mapCount], g_mapNames[g_mapCount], 64);
		//Format(g_mapNames[g_mapCount], 64, "%s[%s]", g_mapNames[g_mapCount], g_mapCodes[g_mapCount]);
		g_mapCount++;
	}
	g_mapIndex[g_configLevel-1] = g_mapCount;
}


public Action CommandVeto(int client, int args)
{
	if (g_useBuiltinvotes)
	{
		if(IsBuiltinVoteInProgress())
		{
			g_isAdminPass_Ext = false;
			PrintToChatAll("\x04管理员否决了本次投票");
			CancelBuiltinVote();
		}
	}
	else
	{
		if(g_bVoteInProgress)
		{
			if (timer_voteCheck != INVALID_HANDLE)
			{
				KillTimer(timer_voteCheck);
				timer_voteCheck = INVALID_HANDLE;
			}
			g_bVoteInProgress = false;
			PrintToChatAll("\x04管理员否决了本次投票");
		}
	}
	return Plugin_Handled;
}

public Action CommandPass(int client, int args)
{
	if (g_useBuiltinvotes)
	{
		if(IsBuiltinVoteInProgress())
		{
			g_isAdminPass_Ext = true;
			PrintToChatAll("\x04管理员通过了本次投票");
			CancelBuiltinVote();
		}
	}
	else
	{
		if(g_bVoteInProgress)
		{
			if (timer_voteCheck != INVALID_HANDLE)
			{
				KillTimer(timer_voteCheck);
				timer_voteCheck = INVALID_HANDLE;
			}
			g_bVoteInProgress = false;
			PrintToChatAll("\x04管理员通过了本次投票");
			ChangeMapTo(g_iChangemapTo);
		}
	}
	return Plugin_Handled;
}

public Action CommandVote(int client, int args)
{
	if (args > 0)
		return Plugin_Handled;
	if (GetClientTeam(client) == 1)
	{
		PrintToChat(client, "\x04旁观者不能发起投票");
		return Plugin_Handled;
	}

	// 判断是否能发起投票
	if (g_useBuiltinvotes)
	{
		if(!IsNewBuiltinVoteAllowed())
		{
			PrintToChat(client, "\x04暂时还不能发起新投票");
			return Plugin_Handled;
		}
	}
	else
	{
		if (g_bVoteInProgress)
		{
			PrintToChat(client, "\x04已有投票正在进行");
			return Plugin_Handled;
		}
	}

	g_isMapChange[client] = false;
	VoteMenu_Select(client);
	return Plugin_Handled;
}

public Action CommandChange(int client, int args)
{
	g_isMapChange[client] = true;
	VoteMenu_Select(client);
	return Plugin_Handled;
}

void VoteMenu_Select(int client)
{
	if (g_mapCount == 0)
	{
		PrintToChat(client, "\x04未读取到地图，请确认\x03 data/l4d_mapvote.cfg \x04配置正确");
		return;
	}
	if (!g_allowMapChange)
	{
		PrintToChat(client, "\x04当前不能发起地图更改");
		return;
	}
	Menu menu = new Menu(VoteMenuHandler_Select);
	if (g_isMapChange[client])
		menu.SetTitle("更换地图");
	else
		menu.SetTitle("投票换图");

	// Build menu
	for (int i=0; i<g_configLevel-1; i++)
		menu.AddItem("", g_mapClass[i]);

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int VoteMenuHandler_Select(Menu menu, MenuAction action, int client, int curSel)
{
	switch( action )
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			g_iSelected[client] = curSel;
			VoteTwoMenu_Select(client, curSel);
		}
	}
}

void VoteTwoMenu_Select(int client, int curSel)
{
	Menu menu = new Menu(VoteMenuTwoMenur_Select);
	if (g_isMapChange[client])
		menu.SetTitle("更换地图");
	else
		menu.SetTitle("投票换图");

	// Build menu
	int idxsrt = g_mapIndex[curSel];
	curSel = g_mapIndex[curSel+1];

	for (int i=idxsrt; i<curSel; i++)
		menu.AddItem("", g_mapNames[i]);

	// Display menu
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int VoteMenuTwoMenur_Select(Menu menu, MenuAction action, int client, int curSel)
{
	switch( action )
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:
		{
			if( curSel == MenuCancel_ExitBack )
				VoteMenu_Select(client);
		}
		case MenuAction_Select:
		{
			if (!g_allowMapChange)
			{
				PrintToChat(client, "\x04当前不能发起地图更改");
				return;
			}
			int iSelected = g_iSelected[client];
			iSelected = g_mapIndex[iSelected];
			iSelected += curSel;
			if (g_useBuiltinvotes)
				MapSelect_Ext(client, iSelected);
			else
				MapSelect(client, iSelected);
		}
	}
}

public Action delayChangeMap(Handle timer, any imap)
{
	g_allowMapChange = false;
	ChangeMapTo(imap);
}

// 延时更换地图
int g_time;
void ChangeMapTo(int imap)
{
	g_time = cv_mapchangeDelay.IntValue;
	g_allowMapChange = false;
	if (g_time < 1)
	{
		ServerCommand("changelevel %s", g_mapCodes[imap]);
		g_allowMapChange = true;
	}
	else
	{
		PrintToChatAll("\x04将在 \x03%i \x04秒后更换地图为\x03 %s \x04...", g_time--, g_mapNames[imap]);
		CreateTimer(1.0, tmrChangeMap, imap, TIMER_REPEAT);
	}
}
public Action tmrChangeMap(Handle timer, any imap)
{
	if (g_time > 0)
	{
		PrintToChatAll("\x04将在 \x03%i \x04秒后更换地图为\x03 %s \x04...", g_time--, g_mapNames[imap]);
		return Plugin_Continue;
	}
	ServerCommand("changelevel %s", g_mapCodes[imap]);
	g_allowMapChange = true;
	return Plugin_Stop;
}


// 使用builtinvotes扩展来启动原版投票
// 选择到指定地图
void MapSelect_Ext(int client, int iSelected)
{
	if ( g_isMapChange[client] )
	{
		if (IsBuiltinVoteInProgress())
		{
			g_isAdminPass_Ext = false;
			PrintToChatAll("\x04管理员已选择地图，本次投票取消");
			CancelBuiltinVote();
		}
		ChangeMapTo(iSelected);
	}
	else
		StartVote_Ext(client, iSelected);
}

Handle g_voteExt;
void StartVote_Ext(int client, int imap)
{
	if (GetClientTeam(client) == 1)
	{
		PrintToChat(client, "\x04旁观者不能发起投票");
		return;
	}
	if (!IsNewBuiltinVoteAllowed())
	{
		PrintToChat(client, "\x04暂时还不能发起新投票");
		return;
	}

	// 开始发起投票
	g_isAdminPass_Ext = false;
	int iNumPlayers = 0;
	decl iPlayers[MaxClients];
	char sBuffer[128];
	Format(sBuffer, sizeof(sBuffer), "是否同意更换地图为 %s ?", g_mapNames[imap]);
	g_iChangemapTo = imap;

	for (int i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) == 1))
			continue;
		iPlayers[iNumPlayers++] = i;
	}

	g_voteExt = CreateBuiltinVote(Vote_ActionHandler_Ext, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
	SetBuiltinVoteArgument(g_voteExt, sBuffer);
	SetBuiltinVoteInitiator(g_voteExt, client);
	DisplayBuiltinVote(g_voteExt, iPlayers, iNumPlayers, cv_voteTime.IntValue);
}

public int Vote_ActionHandler_Ext(Handle vote, BuiltinVoteAction action, param1, param2)
{
	char sBuffer[128];
	Format(sBuffer, sizeof(sBuffer), "即将更换地图为 %s .", g_mapNames[g_iChangemapTo]);
	switch (action)
	{
		// 已完成投票
		case BuiltinVoteAction_VoteEnd:
		{
			if (param1 == BUILTINVOTES_VOTE_YES)
			{
				DisplayBuiltinVotePass(vote, sBuffer);
				// 延时3秒再发起换图指令，因为投票通过的显示具有延迟
				CreateTimer(3.0, delayChangeMap, g_iChangemapTo);
			}
			else if (param1 == BUILTINVOTES_VOTE_NO)
			{
				DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
			}
			else
			{
				// Should never happen, but is here as a diagnostic
				DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Generic);
				LogMessage("Vote failure. winner = %d", param1);
			}
		}
		// 投票被取消
		case BuiltinVoteAction_Cancel:
		{
			if (g_isAdminPass_Ext)
			{
				DisplayBuiltinVotePass(vote, sBuffer);
				CreateTimer(3.0, delayChangeMap, g_iChangemapTo);
			}
			else
				DisplayBuiltinVoteFail(vote, BuiltinVoteFailReason:param1);
		}
		// 投票动作结束
		case BuiltinVoteAction_End:
		{
			g_voteExt = INVALID_HANDLE;
			CloseHandle(vote);
		}
	}
}

// 使用Sourcemod菜单投票

// 已选择指定地图
void MapSelect(int client, int iSelected)
{
	if ( g_isMapChange[client] )
	{
		if (g_bVoteInProgress)
		{
			if (timer_voteCheck != INVALID_HANDLE)
			{
				KillTimer(timer_voteCheck);
				timer_voteCheck = INVALID_HANDLE;
			}
			g_bVoteInProgress = false;
			PrintToChatAll("\x04管理员已选择地图，本次投票取消");
		}
		ChangeMapTo(iSelected);
	}
	else
		StartVote(client, iSelected);
}

void StartVote(int client, int imap)
{
	if (GetClientTeam(client) == 1)
	{
		PrintToChat(client, "\x04旁观者不能发起投票.");
		return;
	}

	if(g_bVoteInProgress)
	{
		PrintToChat(client, "\x04已有投票正在进行.");
		return;
	}

	// 开始发起投票
	char sBuffer[128];
	Format(sBuffer, sizeof(sBuffer), "是否同意更换地图为 %s ?", g_mapNames[imap]);
	g_bVoteInProgress = true;
	g_iChangemapTo = imap;
	g_iYesCount = 0;
	g_iNoCount = 0;
	g_iVoters = 0;

	Panel panel;
	// Display vote
	for (int i=1; i<=MaxClients; i++)
	{
		if( IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i)!=1)
		{
			panel = new Panel();
			SetGlobalTransTarget(i);

			panel.SetTitle(sBuffer);
			panel.DrawItem("是");
			panel.DrawItem("否");

			PrintToChat(i, "\x04投票开始：是否更换地图为\x03 %s \x04?", g_mapNames[imap]);

			panel.Send(i, VoteMenu_Handler, cv_voteTime.IntValue);
			g_iVoters++;
			g_iNoCount++;
			delete panel;
		}
	}
	timer_voteCheck = CreateTimer(cv_voteTime.IntValue+1.0, Timer_VoteCheck);
}

// 菜单投票
public int VoteMenu_Handler(Menu menu, MenuAction action, int client, int choice)
{
	if (action == MenuAction_Select )
	{
		if (choice == 1) //yes
		{
			g_iNoCount--;
			g_iYesCount++;
			g_iVoters--;
		}
		else // No
			g_iVoters--;

		// 所有人已投票则提前结束投票
		if( g_iVoters == 0 ) // Everyone Has Voted
			VoteCompleted();
	}
}
// 定时器，如果时间超过则自动结束投票
public Action Timer_VoteCheck(Handle timer)
{
	VoteCompleted();
}
// 投票结束
void VoteCompleted()
{
	if (timer_voteCheck != INVALID_HANDLE)
	{
		KillTimer(timer_voteCheck);
		timer_voteCheck = INVALID_HANDLE;
	}
	if(!g_bVoteInProgress)
		return;

	g_bVoteInProgress = false;
	if (g_iYesCount > g_iNoCount)
	{
		PrintToChatAll("\x04本次投票已通过，同意：\x03%d \x04否定：\x03%d", g_iYesCount, g_iNoCount);
		ChangeMapTo(g_iChangemapTo);
	}
	else
	{
		PrintToChatAll("\x04本次投票未通过，同意：\x03%d \x04否定：\x03%d", g_iYesCount, g_iNoCount);
	}
}