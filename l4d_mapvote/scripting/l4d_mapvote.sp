// 本插件编写参考 SilverShot l4d_votemode.sp

#include <sourcemod>
#include <adminmenu>
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

ConVar cv_checkGamemode; // 是否直接显示当前游戏模式支持的地图
ConVar cv_useBuiltinvotes; // 是否使用扩展发起原版投票开关
ConVar cv_mapCheck; // 地图检查开关
ConVar cv_voteTime; // 投票持续时间
ConVar cv_mapchangeDelay; // 地图更换延时

bool g_isBuiltinvotesLoaded = false; // Builtinvotes扩展是否加载成功

bool g_useBuiltinvotes = false; // 当前插件是否使用原版投票
bool g_allowMapChange = true; // 当前是否允许插件发起地图更改
bool g_isMapChange[MAXPLAYERS+1]; // 记录本次指令是否是mapchange
BaseMode g_baseMode = INVALID;
int g_iChangemapTo, g_iSelected[MAXPLAYERS+1];

char g_mapCodes[1024][64], g_mapNames[1024][64];
int g_mapCount;
char g_mapClass[64][64];
int g_classCount, g_mapIndex[64];

bool g_isAdminPass; // 在提前取消投票的时候判断是否是管理员直接通过了本次投票

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion game = GetEngineVersion();
	if (game!=Engine_Left4Dead && game!=Engine_Left4Dead2)
	{
		strcopy(error, err_max, "本插件只支持 Left 4 Dead 1&2 ");
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

	cv_checkGamemode	= CreateConVar("l4d_mapvote_check_gamemode", "1", "是否直接显示当前游戏模式所支持的地图？（获取游戏模式需要安装LinGe_Library.smx。此外，插件无法检测地图支持哪些模式，你需要自己在data/l4d_mapvote.cfg中配置）", _, true, 0.0, true, 1.0);
	cv_useBuiltinvotes	= CreateConVar("l4d_mapvote_use_builtinvotes", "1", "是否使用builtinvotes扩展发起原版投票？开启情况下，若扩展未正常加载仍会使用sourcemod平台菜单投票。游戏中直接修改这个参数不会生效。", _, true, 0.0, true, 1.0);
	cv_mapCheck			= CreateConVar("l4d_mapvote_map_check", "1", "地图检查，若开启则不会显示data/l4d_mapvote.cfg中的无效地图。游戏中直接修改这个参数不会生效。（注意：只有服务端才会自动读取addons下的全部三方图，客户端不会。）", _, true, 0.0, true, 1.0);
	cv_voteTime			= CreateConVar("l4d_mapvote_vote_time", "20", "投票应在多少秒内完成？", _, true, 10.0, true, 60.0);
	cv_mapchangeDelay	= CreateConVar("l4d_mapvote_mapchange_delay", "5", "地图更换延时", _, true, 0.0, true, 60.0);
	AutoExecConfig(true, "l4d_mapvote");

	Handle topmenu = GetAdminTopMenu();
	if( LibraryExists("adminmenu") && (topmenu != null) )
		OnAdminMenuReady(topmenu);

	if ( GetExtensionFileStatus("builtinvotes.ext") == 1 )
		g_isBuiltinvotesLoaded = true;
}

// 不编写游戏中途重新读取地图列表的功能，因为读取量太大时会造成短暂的卡顿
public void OnConfigsExecuted()
{
	// 只有当扩展加载成功时才使用原版投票
	if (cv_useBuiltinvotes.IntValue == 1 && g_isBuiltinvotesLoaded)
		g_useBuiltinvotes = true;
	else
		g_useBuiltinvotes = false;
	if (IsPluginRunning("LinGe_Library.smx"))
		g_baseMode = GetBaseMode();
	else
		g_baseMode = INVALID;
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

public int Handle_Category(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength)
{
	switch( action )
	{
		case TopMenuAction_DisplayTitle:
			Format(buffer, maxlength, "更换地图");
		case TopMenuAction_DisplayOption:
			Format(buffer, maxlength, "更换地图");
		case TopMenuAction_SelectOption:
		{
			g_isMapChange[client] = true;
			VoteMenu_Select(client);
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
	g_classCount = -1;
	if (FileExists(sPath))
		ParseConfigFile(sPath); // 读取data/l4d_mapvote.cfg中的地图
	else
		SetFailState("文件不存在 : %s", sPath);
}

// 读取配置文件
bool ParseConfigFile(const char[] file)
{
	SMCParser parser = new SMCParser();
	SMC_SetReaders(parser, Config_NewSection, Config_KeyValue, Config_EndSection);
	parser.OnEnd = Config_End;

	char error[128];
	int line = 0, col = 0;
	SMCError result = parser.ParseFile(file, line, col);
	delete parser;

	if ( result != SMCError_Okay )
	{
		SMC_GetErrorString(result, error, sizeof(error));
		SetFailState("%s on line %d, col %d of %s [%d]", error, line, col, file, result);
	}

	return (result == SMCError_Okay);
}

public SMCResult Config_NewSection(Handle parser, const char[] section, bool quotes)
{
	g_classCount++;
	if( g_classCount > 0 )
	{
		strcopy(g_mapClass[g_classCount-1], 64, section);
		g_mapIndex[g_classCount-1] = g_mapCount;
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
	g_mapIndex[g_classCount] = g_mapCount;
	return SMCParse_Continue;
}
public void Config_End(Handle parser, bool halted, bool failed)
{
	if( failed )
		SetFailState("Error: Cannot load the mapvote config");
}


// --------------------------------CMD---------------------------------------
public Action CommandVeto(int client, int args)
{
	if (_IsVoteInProgress())
	{
		g_isAdminPass = false;
		PrintToChatAll("\x04管理员否决了本次投票");
		_CancelVote();
	}
	return Plugin_Handled;
}

public Action CommandPass(int client, int args)
{
	if(_IsVoteInProgress())
	{
		g_isAdminPass = true;
		PrintToChatAll("\x04管理员通过了本次投票");
		_CancelVote();
	}
	return Plugin_Handled;
}

public Action CommandVote(int client, int args)
{
	if (0 == client || args > 0)
		return Plugin_Handled;

	if (GetClientTeam(client) == 1)
	{
		PrintToChat(client, "\x04旁观者不能发起投票");
		return Plugin_Handled;
	}

	// 判断是否能发起投票
	if(!_IsNewVoteAllowed())
	{
		PrintToChat(client, "\x04暂时还不能发起新投票");
		return Plugin_Handled;
	}

	g_isMapChange[client] = false;
	VoteMenu_Select(client);
	return Plugin_Handled;
}

public Action CommandChange(int client, int args)
{
	if (0 == client || args > 0)
		return Plugin_Handled;

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

	if (cv_checkGamemode.IntValue == 1
	&& g_baseMode != INVALID
	&& g_baseMode <= g_classCount)
	{
		g_iSelected[client] = g_baseMode - 1;
		VoteTwoMenu_Select(client, g_iSelected[client], false);
	}
	else
	{
		Menu menu = new Menu(VoteMenuHandler_Select);
		if (g_isMapChange[client])
			menu.SetTitle("更换地图");
		else
			menu.SetTitle("投票换图");

		// Build menu
		for (int i=0; i<g_classCount; i++)
			menu.AddItem("", g_mapClass[i]);

		// Display menu
		menu.Display(client, MENU_TIME_FOREVER);
	}
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
			VoteTwoMenu_Select(client, g_iSelected[client]);
		}
	}
}

void VoteTwoMenu_Select(int client, int curSel, bool allowBack=true)
{
	Menu menu = new Menu(VoteMenuTwoMenur_Select);
	if (g_isMapChange[client])
		menu.SetTitle("更换地图[%s]", g_mapClass[curSel]);
	else
		menu.SetTitle("投票换图[%s]", g_mapClass[curSel]);
	// Build menu
	int idxsrt = g_mapIndex[curSel];
	curSel = g_mapIndex[curSel+1];
	for (int i=idxsrt; i<curSel; i++)
		menu.AddItem("", g_mapNames[i]);
	// Display menu
	if (allowBack)
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
			MapSelect(client, iSelected);
		}
	}
}

// 已选择指定地图
void MapSelect(int client, int iSelected)
{
	if ( g_isMapChange[client] )
	{
		if (_IsVoteInProgress())
		{
			g_isAdminPass = false;
			PrintToChatAll("\x04管理员已选择地图，本次投票取消");
			_CancelVote();
		}
		ChangeMapTo(iSelected);
	}
	else
		StartVote(client, iSelected);
}

Handle g_voteExt;
int g_iNumPlayers = 0;
int g_iPlayers[MAXPLAYERS];
void StartVote(int client, int imap)
{
	if (GetClientTeam(client) == 1)
	{
		PrintToChat(client, "\x04旁观者不能发起投票");
		return;
	}
	if (!_IsNewVoteAllowed())
	{
		PrintToChat(client, "\x04暂时还不能发起新投票");
		return;
	}

	// 开始发起投票
	char sBuffer[128];
	Format(sBuffer, sizeof(sBuffer), "是否同意更换地图为 %s ?", g_mapNames[imap]);
	g_iChangemapTo = imap;
	g_isAdminPass = false;
	g_iNumPlayers = 0;

	for (int i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) == 1))
			continue;
		g_iPlayers[g_iNumPlayers++] = i;
	}

	if (g_useBuiltinvotes)
	{
		g_voteExt = CreateBuiltinVote(Vote_ActionHandler_Ext, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(g_voteExt, sBuffer);
		SetBuiltinVoteInitiator(g_voteExt, client);
		DisplayBuiltinVote(g_voteExt, g_iPlayers, g_iNumPlayers, cv_voteTime.IntValue);
	}
	else
	{
		Menu vote = new Menu(Vote_ActionHandler_Menu);
		vote.SetTitle(sBuffer);
		vote.AddItem("", "是");
		vote.AddItem("", "否");
		vote.DisplayVote(g_iPlayers, g_iNumPlayers, cv_voteTime.IntValue);
	}
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
			if (g_isAdminPass)
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

public int Vote_ActionHandler_Menu(Menu menu, MenuAction action, int param1, int param2)
{
	switch( action )
	{
		// 投票结束
		case MenuAction_VoteEnd:
		{
			int yes = 0, winningVotes = 0, totalVotes = 0;
			GetMenuVoteInfo(param2, winningVotes, totalVotes);
			if (0 == param1) // 0为 是 选项
				yes = winningVotes;
			else
				yes = totalVotes - winningVotes;
			if (yes > g_iNumPlayers-yes)
			{
				PrintToChatAll("\x04同意票数\x03 %d\x04，否定票数\x03 %d\x04，本次投票通过", yes, g_iNumPlayers-yes);
				ChangeMapTo(g_iChangemapTo);
			}
			else
			{
				PrintToChatAll("\x04同意票数\x03 %d\x04，否定票数\x03 %d\x04，本次投票未通过", yes, g_iNumPlayers-yes);
			}
		}
		// 投票被取消
		case MenuAction_VoteCancel:
		{
			// 所有人弃权
			if (VoteCancel_NoVotes == param1)
			{
				PrintToChatAll("\x04所有人弃权投票，本次投票未通过");
			}
			else if (VoteCancel_Generic == param1 && g_isAdminPass)
				ChangeMapTo(g_iChangemapTo);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}


// 延时更换地图
public Action delayChangeMap(Handle timer, any imap)
{
	g_allowMapChange = false;
	ChangeMapTo(imap);
}

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



bool _IsNewVoteAllowed()
{
	if (g_useBuiltinvotes)
		return IsNewBuiltinVoteAllowed();
	else
		return IsNewVoteAllowed();
}

bool _IsVoteInProgress()
{
	if (g_useBuiltinvotes)
		return IsBuiltinVoteInProgress();
	else
		return IsVoteInProgress();
}

void _CancelVote()
{
	if (g_useBuiltinvotes)
		CancelBuiltinVote();
	else
		CancelVote();
}