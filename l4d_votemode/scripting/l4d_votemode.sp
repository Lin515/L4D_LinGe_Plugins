#define PLUGIN_VERSION		"2.0"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Vote Mode
*	Author	:	SilverShot
*	Modify	:	LinGe - https://github.com/Lin515/L4D_LinGe_Plugins
*	Descrp	:	Allows players to vote change the game mode. Admins can force change the game mode.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=179279
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:
2.0 (19-Jun-2021) by LinGe
	- 增加功能：可以使用builtinvotes扩展发起游戏内置投票
	- 原菜单投票功能的实现改为SourceMod的API函数实现

1.5 (16-Jun-2020)
	- Added Hungarian translations to the "translations.zip", thanks to "KasperH" for providing.
	- Now sets Normal difficulty anytime the plugin changes gamemode. Thanks to "Alex101192" for reporting.

1.4 (10-May-2020)
	- Fixed potential issues with some translations not being displayed in the right language.
	- Various changes to tidy up code.

1.3 (30-Apr-2020)
	- Optionally uses Info Editor (requires version 1.8 or newer) to detect and change to valid Survival/Scavenge maps.
	- This method will also set the difficulty to Normal when switching to Survival/Scavenge maps.
	- This method only works when l4d_votemode_restart is set to 1.
	- Thanks to "Alex101192" for testing.

1.2 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.

1.1 (10-May-2012)
	- Fixed votes potentially not displaying to everyone.

1.0 (28-Feb-2012)
	- Initial release.

========================================================================================

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	Thanks to "N3wton" for "[L4D2] Pause" - Used to make the voting system.
	https://forums.alliedmods.net/showthread.php?t=137765

*	Thanks to "chundo" for "Custom Votes" - Used to load the config via SMC Parser.
	https://forums.alliedmods.net/showthread.php?p=633808

*	Thanks to "Rayman1103" for the "All Mutations Unlocked" addon.
	https://forums.steampowered.com/forums/showthread.php?t=1529433

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <adminmenu>
#include <builtinvotes>

#define CVAR_FLAGS				FCVAR_NOTIFY
#define CHAT_TAG				"\x04"
#define CONFIG_VOTEMODE			"data/l4d_votemode.cfg"


// Cvar handles and variables
ConVar g_hCvarAdmin, g_hCvarMenu, g_hCvarRestart, g_hCvarTimeout;
int g_iCvarAdmin, g_iCvarRestart;
int g_fCvarTimeout;

// Other handles
ConVar g_hMPGameMode, g_hRestartGame;
TopMenu g_hCvarMenuMenu;

// Distinguishes mode selected and if admin forced
int g_iChangeModeTo, g_iSelected[MAXPLAYERS+1];

// Strings to hold the gamemodes and titles
char g_sModeCommands[256][64], g_sModeNames[256][64], g_sModeTitles[256][64];

// Store where the different titles are within the commands list
int g_iConfigCount, g_iConfigLevel, g_iModeIndex[64], g_iTitleIndex[64], g_iTitleCount;

// Survival/Scavenge map detection
native void InfoEditor_GetString(int pThis, const char[] keyname, char[] dest, int destLen);
bool g_bInfoEditor;


ConVar cv_useBuiltinvotes; // 是否使用扩展发起原版投票开关
bool g_useBuiltinvotes = false; // 当前插件是否使用原版投票
bool g_allowChangeMode = true; // 当前是否允许插件发起模式更改
bool g_isForceMode[MAXPLAYERS+1]; // 记录本次指令是否是forcemode
bool g_isAdminPass; // 在提前取消投票的时候判断是否是管理员直接通过了本次投票


// ====================================================================================================
//					PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Vote Mode",
	author = "SilverShot, LinGe",
	description = "Allows players to vote change the game mode. Admins can force change the game mode.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Lin515/L4D_LinGe_Plugins/L4D_LinGe_Plugins"
// 原版 url = "https://forums.alliedmods.net/showthread.php?t=179279"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead && test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	MarkNativeAsOptional("InfoEditor_GetString");

	return APLRes_Success;
}

public void OnLibraryAdded(const char[] name)
{
	if( strcmp(name, "info_editor") == 0 )
		g_bInfoEditor = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if( strcmp(name, "info_editor") == 0 )
		g_bInfoEditor = false;
	else if( strcmp(name, "adminmenu") == 0 )
		g_hCvarMenuMenu = null;
}

public void OnPluginStart()
{
	if( (g_hMPGameMode = FindConVar("mp_gamemode")) == null )
		SetFailState("Failed to find convar handle 'mp_gamemode'. Cannot load plugin.");

	if( (g_hRestartGame = FindConVar("mp_restartgame")) == null )
		SetFailState("Failed to find convar handle 'mp_restartgame'. Cannot load plugin.");

	LoadTranslations("votemode.phrases");
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");

	g_hCvarMenu =		CreateConVar(	"l4d_votemode_admin_menu",		"1", 	"0=No, 1=Display in the Server Commands of admin menu.", CVAR_FLAGS );
	g_hCvarAdmin =		CreateConVar(	"l4d_votemode_admin_flag",		"", 	"Players with these flags can vote to change the game mode.", CVAR_FLAGS );
	g_hCvarRestart =	CreateConVar(	"l4d_votemode_restart",			"1",	"0=No restart, 1=With 'changelevel' command, 2=Restart map with 'mp_restartgame' cvar.", CVAR_FLAGS );
	g_hCvarTimeout =	CreateConVar(	"l4d_votemode_timeout",			"20.0",	"How long the vote should be visible.", CVAR_FLAGS, true, 5.0, true, 60.0 );
	cv_useBuiltinvotes	= CreateConVar(	"l4d_votemode_use_builtinvotes", "1", 	"Use the Builtinvotes extension to initiate a vote? If enabled, you must install the Builtinvotes extension.", CVAR_FLAGS, true, 0.0, true, 1.0);
	CreateConVar("l4d_votemode_version", PLUGIN_VERSION, "Vote Mode plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true, "l4d_votemode");

	GetCvars();
	g_hCvarAdmin.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarRestart.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTimeout.AddChangeHook(ConVarChanged_Cvars);

	RegAdminCmd(	"sm_modeveto",		CommandVeto,	ADMFLAG_ROOT,	"Allows admins to veto a current vote.");
	RegAdminCmd(	"sm_modepass",		CommandPass,	ADMFLAG_ROOT,	"Allows admins to pass a current vote.");
	RegAdminCmd(	"sm_modeforce",		CommandForce,	ADMFLAG_ROOT,	"Allows admins to force the game into a different mode.");
	RegConsoleCmd(	"sm_modevote",		CommandVote,					"Displays a menu to vote the game into a different mode.");
	RegAdminCmd(	"sm_vetomode",		CommandVeto,	ADMFLAG_ROOT,	"Allows admins to veto a current vote.");
	RegAdminCmd(	"sm_passmode",		CommandPass,	ADMFLAG_ROOT,	"Allows admins to pass a current vote.");
	RegAdminCmd(	"sm_forcemode",		CommandForce,	ADMFLAG_ROOT,	"Allows admins to force the game into a different mode.");
	RegConsoleCmd(	"sm_votemode",		CommandVote,					"Displays a menu to vote the game into a different mode.");

	Handle topmenu = GetAdminTopMenu();
	if( LibraryExists("adminmenu") && (topmenu != null) )
		OnAdminMenuReady(topmenu);

	LoadConfig();
}

public void OnConfigsExecuted()
{
	if (cv_useBuiltinvotes.IntValue == 1)
		g_useBuiltinvotes = true;
	else
		g_useBuiltinvotes = false;
	g_allowChangeMode = true;
}


// ====================================================================================================
//					ADD TO ADMIN MENU
// ====================================================================================================
public void OnAdminMenuReady(Handle topmenu)
{
	if( topmenu == g_hCvarMenuMenu || g_hCvarMenu.BoolValue == false )
		return;

	g_hCvarMenuMenu = view_as<TopMenu>(topmenu);

	TopMenuObject player_commands = FindTopMenuCategory(g_hCvarMenuMenu, ADMINMENU_SERVERCOMMANDS);
	if( player_commands == INVALID_TOPMENUOBJECT ) return;

	AddToTopMenu(g_hCvarMenuMenu, "sm_forcemode_menu", TopMenuObject_Item, Handle_Category, player_commands, "sm_forcemode_menu", ADMFLAG_GENERIC);
}

public int Handle_Category(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	switch( action )
	{
		case TopMenuAction_DisplayTitle:
			Format(buffer, maxlength, "%T", "VoteMode_Force", param);
		case TopMenuAction_DisplayOption:
			Format(buffer, maxlength, "%T", "VoteMode_Force", param);
		case TopMenuAction_SelectOption:
		{
			g_isForceMode[param] = true;
			VoteMenu_Select(param);
		}
	}
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	char sTemp[16];
	g_hCvarAdmin.GetString(sTemp, sizeof(sTemp));
	g_iCvarAdmin = ReadFlagString(sTemp);
	g_iCvarRestart = g_hCvarRestart.IntValue;
	g_fCvarTimeout = g_hCvarTimeout.IntValue;
}



// ====================================================================================================
//					LOAD CONFIG
// ====================================================================================================
void LoadConfig()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_VOTEMODE);

	if( !FileExists(sPath) )
	{
		SetFailState("Error: Cannot find the Votemode config '%s'", sPath);
		return;
	}

	ParseConfigFile(sPath);
}

bool ParseConfigFile(const char[] file)
{
	// Load parser and set hook functions
	SMCParser parser = new SMCParser();
	SMC_SetReaders(parser, Config_NewSection, Config_KeyValue, Config_EndSection);
	parser.OnEnd = Config_End;

	// Log errors detected in config
	char error[128];
	int line = 0, col = 0;
	SMCError result = parser.ParseFile(file, line, col);

	if( result != SMCError_Okay )
	{
		parser.GetErrorString(result, error, sizeof(error));
		SetFailState("%s on line %d, col %d of %s [%d]", error, line, col, file, result);
	}

	delete parser;
	return (result == SMCError_Okay);
}

public SMCResult Config_NewSection(Handle parser, const char[] section, bool quotes)
{
	// Section strings, used for the first menu ModeTitles
	g_iConfigLevel++;
	if( g_iConfigLevel > 1 )
	{
		strcopy(g_sModeTitles[g_iConfigLevel -2], sizeof(g_sModeTitles[]), section);
		g_iModeIndex[g_iConfigLevel -2] = g_iConfigCount;
		g_iTitleIndex[g_iTitleCount++] = g_iConfigCount + 1;
	}
	return SMCParse_Continue;
}

public SMCResult Config_KeyValue(Handle parser, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	// Key and value strings, used for the ModeNames and ModeCommands
	strcopy(g_sModeNames[g_iConfigCount], sizeof(g_sModeNames[]), key);
	strcopy(g_sModeCommands[g_iConfigCount], sizeof(g_sModeCommands[]), value);
	g_iConfigCount++;
	return SMCParse_Continue;
}

public SMCResult Config_EndSection(Handle parser)
{
	// Config finished loading
	g_iModeIndex[g_iConfigLevel -1] = g_iConfigCount;
	return SMCParse_Continue;
}

public void Config_End(Handle parser, bool halted, bool failed)
{
	if( failed )
		SetFailState("Error: Cannot load the Votemode config.");
}



// ====================================================================================================
//					COMMANDS
// ====================================================================================================
public Action CommandVeto(int client, int args)
{
	if( _IsVoteInProgress() )
	{
		g_isAdminPass = false;
		PrintToChatAll("%s%t", CHAT_TAG, "VoteMode_Veto");
		_CancelVote();
	}
	return Plugin_Handled;
}

public Action CommandPass(int client, int args)
{
	if( _IsVoteInProgress() )
	{
		g_isAdminPass = true;
		PrintToChatAll("%s%t", CHAT_TAG, "VoteMode_Pass");
		_CancelVote();
	}
	return Plugin_Handled;
}

public Action CommandVote(int client, int args)
{
	if (0 == client)
		return Plugin_Handled;

	// Admins only
	if( CheckCommandAccess(client, "", g_iCvarAdmin) == false )
	{
		PrintToChat(client, "%s%t", CHAT_TAG, "No Access");
		return Plugin_Handled;
	}

	if (GetClientTeam(client) == 1)
	{
		PrintToChat(client, "%s%t", CHAT_TAG, "VoteMode_Spec");
		return Plugin_Handled;
	}

	if (!g_allowChangeMode)
	{
		PrintToChat(client, "%s%t", CHAT_TAG, "VoteMode_NoChangeMode");
		return Plugin_Handled;
	}

	if (!_IsNewVoteAllowed())
	{
		PrintToChat(client, "%s%t", CHAT_TAG, "VoteMode_InProgress");
		return Plugin_Handled;
	}

	if( args == 1 )
	{
		char sTemp[64];
		GetCmdArg(1, sTemp, sizeof(sTemp));

		for( int i = 0; i < g_iConfigCount; i++ )
		{
			if( strcmp(g_sModeCommands[i], sTemp, false) == 0 )
			{
				StartVote(client, i);
				return Plugin_Handled;
			}
		}
	}

	g_isForceMode[client] = false;
	VoteMenu_Select(client);
	return Plugin_Handled;
}

public Action CommandForce(int client, int args)
{
	if (!g_allowChangeMode)
	{
		PrintToChat(client, "%s%t", CHAT_TAG, "VoteMode_NoChangeMode");
		return Plugin_Handled;
	}

	if( args == 1 )
	{
		char sTemp[64];
		GetCmdArg(1, sTemp, sizeof(sTemp));

		for( int i = 0; i < g_iConfigCount; i++ )
		{
			if( strcmp(g_sModeCommands[i], sTemp, false) == 0 )
			{
				if (_IsVoteInProgress())
				{
					g_isAdminPass = false;
					PrintToChatAll("%s%t", CHAT_TAG, "VoteMode_AdminForce");
					_CancelVote();
				}
				ChangeGameModeTo(i);
				return Plugin_Handled;
			}
		}
	}

	g_isForceMode[client] = true;
	VoteMenu_Select(client);
	return Plugin_Handled;
}

// ====================================================================================================
//					DISPLAY MENU
// ====================================================================================================
void VoteMenu_Select(int client)
{
	Menu menu = new Menu(VoteMenuHandler_Select);
	if( g_isForceMode[client] )
		menu.SetTitle("%T", "VoteMode_Force", client);
	else
		menu.SetTitle("%T", "VoteMode_Vote", client);

	// Build menu
	for( int i = 0; i < g_iConfigLevel -1; i++ )
		menu.AddItem("", g_sModeTitles[i]);

	// Display menu
	menu.Display(client, MENU_TIME_FOREVER);
}

public int VoteMenuHandler_Select(Menu menu, MenuAction action, int client, int param2)
{
	switch( action )
	{
		case MenuAction_End:
		{
			delete menu;
		}
//		case MenuAction_Cancel:
//		{
//			if( param2 == MenuCancel_ExitBack && g_isForceMode[client] && g_hCvarMenuMenu != null )
//				g_hCvarMenuMenu.Display(client, TopMenuPosition_LastCategory); //TopMenuPosition_Start
//		}
		case MenuAction_Select:
		{
			g_iSelected[client] = param2;
			VoteTwoMenu_Select(client, param2);
		}
	}
}

void VoteTwoMenu_Select(int client, int param2)
{
	Menu menu = new Menu(VoteMenuTwoMenur_Select);
	if( g_isForceMode[client] )
		menu.SetTitle("%T", "VoteMode_Force", client);
	else
		menu.SetTitle("%T", "VoteMode_Vote", client);

	// Build menu
	int param1 = g_iModeIndex[param2];
	param2 = g_iModeIndex[param2 +1];

	for( int i = param1; i < param2; i++ )
		menu.AddItem("", g_sModeNames[i]);

	// Display menu
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int VoteMenuTwoMenur_Select(Menu menu, MenuAction action, int client, int param2)
{
	switch( action )
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:
		{
			if( param2 == MenuCancel_ExitBack )
				VoteMenu_Select(client);
		}
		case MenuAction_Select:
		{
			// Work out the mode command index
			int iSelected = g_iSelected[client];
			iSelected = g_iModeIndex[iSelected];
			iSelected += param2;
			ModeSelect(client, iSelected);
		}
	}
}

void ModeSelect(int client, int iSelected)
{
	if ( g_isForceMode[client] )
	{
		if (_IsVoteInProgress())
		{
			g_isAdminPass = false;
			PrintToChatAll("%s%t", CHAT_TAG, "VoteMode_AdminForce");
			_CancelVote();
		}
		ChangeGameModeTo(iSelected);
	}
	else
		StartVote(client, iSelected);
}



// ====================================================================================================
//					VOTING STUFF
// ====================================================================================================
Handle g_voteExt;
int g_iNumPlayers = 0;
int g_iPlayers[MAXPLAYERS];
int g_voteInitiator = -1;
void StartVote(int client, int iMode)
{
	if (!g_allowChangeMode)
	{
		PrintToChat(client, "%s%t", CHAT_TAG, "VoteMode_NoChangeMode");
		return;
	}
	if (GetClientTeam(client) == 1)
	{
		PrintToChat(client, "%s%t", CHAT_TAG, "VoteMode_Spec");
		return;
	}
	// Don't allow multiple votes
	if( !_IsNewVoteAllowed() )
	{
		PrintToChat(client, "%s%t", CHAT_TAG, "VoteMode_InProgress");
		return;
	}

	// Setup vote
	g_isAdminPass = false;
	g_iNumPlayers = 0;
	g_iChangeModeTo = iMode;
	g_voteInitiator = client;
	char sBuffer[128];
	SetGlobalTransTarget(client);
	Format(sBuffer, sizeof(sBuffer), "%t", "VoteMode_Change", g_sModeNames[iMode]);

	// Display vote
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
		DisplayBuiltinVote(g_voteExt, g_iPlayers, g_iNumPlayers, g_fCvarTimeout);
	}
	else
	{
		Menu vote = new Menu(Vote_ActionHandler_Menu);
		vote.SetTitle(sBuffer);
		Format(sBuffer, sizeof(sBuffer), "%t", "Yes");
		vote.AddItem("", sBuffer);
		Format(sBuffer, sizeof(sBuffer), "%t", "No");
		vote.AddItem("", sBuffer);
		vote.DisplayVote(g_iPlayers, g_iNumPlayers, g_fCvarTimeout);
	}
}


public int Vote_ActionHandler_Ext(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	char sBuffer[128];
	Format(sBuffer, sizeof(sBuffer), "%T", "VoteMode_Changing", g_voteInitiator, g_sModeNames[g_iChangeModeTo]);
	switch (action)
	{
		// 已完成投票
		case BuiltinVoteAction_VoteEnd:
		{
			if (param1 == BUILTINVOTES_VOTE_YES)
			{
				DisplayBuiltinVotePass(vote, sBuffer);
				ChangeGameModeTo(g_iChangeModeTo);
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
				ChangeGameModeTo(g_iChangeModeTo);
			}
			else
				DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
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
				PrintToChatAll("%s%t", CHAT_TAG, "VoteMode_VotePass", yes, g_iNumPlayers-yes);
				ChangeGameModeTo(g_iChangeModeTo);
			}
			else
			{
				PrintToChatAll("%s%t", CHAT_TAG, "VoteMode_VoteFail", yes, g_iNumPlayers-yes);
			}
		}
		// 投票被取消
		case MenuAction_VoteCancel:
		{
			// 所有人弃权
			if (VoteCancel_NoVotes == param1)
			{
				PrintToChatAll("%s%t", CHAT_TAG, "VoteMode_VoteInvalid");
			}
			else if (VoteCancel_Generic == param1 && g_isAdminPass)
				ChangeGameModeTo(g_iChangeModeTo);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}


// ====================================================================================================
//					SET GAME MODE
// ====================================================================================================

void ChangeGameModeTo(int iMode)
{
	g_allowChangeMode = false;
	CreateTimer(3.0, tmrChangeMode, iMode);
}

public Action tmrChangeMode(Handle timer, any index)
{
	// Change map
	if( g_iCvarRestart == 1 )
	{
		// Current map
		int done;
		bool change = true;
		char sMap[64];
		GetCurrentMap(sMap, sizeof(sMap));

		// Info Editor detected?
		if( g_bInfoEditor )
		{
			int indexed;

			// Get title from selected index
			for( int i = 0; i < sizeof(g_iTitleIndex); i++ )
			{
				if( g_iTitleIndex[i] && index + 1 >= g_iTitleIndex[i] )
				{
					indexed = i;
				} else {
					break;
				}
			}

			// Change to Survival/Scavenge mode?
			if( strcmp(g_sModeTitles[indexed], "Survival") == 0 || strcmp(g_sModeTitles[indexed], "Scavenge") == 0 )
			{
				char sTemp[64];
				ArrayList hTemp;
				hTemp = new ArrayList(ByteCountToCells(64));

				// Loop valid Survival/Scavenge maps from mission file
				for( int i = 1; i < 15; i++ )
				{
					Format(sTemp, sizeof(sTemp), "modes/%s/%d/map", g_sModeTitles[indexed], i);
					InfoEditor_GetString(0, sTemp, sTemp, sizeof(sTemp));

					if( strcmp(sTemp, "N/A") == 0 )			// Doesn't exist
					{
						break;
					}
					else if( strcmp(sTemp, sMap) == 0 )		// Same as current map
					{
						done = 1;
						break;
					}
					else
					{
						hTemp.PushString(sTemp);			// Store valid maps
					}
				}

				// Not same map
				if( !done )
				{
					// Get random valid map
					done = hTemp.Length;
					if( done )
					{
						hTemp.GetString(GetRandomInt(0, done-1), sMap, sizeof(sMap));
					}
					else
					{
						change = false;
					}
				}

				delete hTemp;
			}
		}

		if( change )
		{
			g_hMPGameMode.SetString(g_sModeCommands[index]);
//			ServerCommand("z_difficulty normal; changelevel %s", sMap);
			ServerCommand("changelevel %s", sMap);
		}
		else
		{
			PrintToChatAll("%sFailed to change gamemode, no valid map", CHAT_TAG);
			LogAction(-1, -1, "Failed to change gamemode, no valid map");
		}
		g_allowChangeMode = true;
	}
	else if( g_iCvarRestart == 2 )
	{
		g_hRestartGame.IntValue = 1;
		CreateTimer(0.1, tmrRestartGame);
	}
}

public Action tmrRestartGame(Handle timer)
{
	g_hRestartGame.IntValue = 1;
	g_allowChangeMode = true;
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