#include <sourcemod>
#include <sdktools>
#include <LinGe_Function>
#include <LinGe_Library>

public Plugin myinfo = {
	name = "[L4D] LinGe Library",
	author = "LinGe",
	description = "求生之路 一个简单的自用库",
	version = "0.1",
	url = "https://github.com/LinGe515"
};

ConVar cv_allowLobby;
ConVar cv_allowBotGame;
ConVar cv_autoLobby;
ConVar cv_autoHibernate;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion game = GetEngineVersion();
	if (game!=Engine_Left4Dead && game != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "本插件只支持 Left 4 Dead 1&2 .");
		return APLRes_SilentFailure;
	}

	CreateNative("GetBaseMode", Native_GetBaseMode);
	CreateNative("GetLobbySlots", Native_GetLobbySlots);
	RegPluginLibrary("LinGe_Library");

	return APLRes_Success;
}

public void OnPluginStart()
{
	cv_allowLobby = FindConVar("sv_allow_lobby_connect_only");
	cv_allowBotGame = FindConVar("sb_all_bot_game");
	cv_autoLobby = CreateConVar("LinGe_Library_auto_lobby", "1", "自动管理sv_allow_lobby_connect_only参数，当有人连接时设置为0，服务器无人时设置为1。", FCVAR_SERVER_CAN_EXECUTE, true, 0.0, true, 1.0);
	cv_autoHibernate = CreateConVar("LinGe_Library_auto_hibernate", "1", "服务器无人时自动设置sb_all_bot_game为0，以让服务器可自动休眠。", FCVAR_SERVER_CAN_EXECUTE, true, 0.0, true, 1.0);
	AutoExecConfig(true, "LinGe_Library");
}

public void OnMapStart()
{
	if (cv_autoHibernate.IntValue == 1)
	{
		if (cv_allowBotGame.IntValue == 1)
			cv_allowBotGame.SetInt(0);
	}
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
	if (cv_autoLobby.IntValue == 0)
		return true;
	if (cv_allowLobby.IntValue == 0)
		return true;
	cv_allowLobby.SetInt(0);
	return true;
}

public void OnClientDisconnect_Post(int client)
{
	int humans = AllHumans();

	if (cv_autoLobby.IntValue == 1 && 0 == humans)
	{
		if (cv_allowLobby.IntValue == 0)
			cv_allowLobby.SetInt(1);
	}

	if (cv_autoHibernate.IntValue == 1 && 0 == humans)
	{
		if (cv_allowBotGame.IntValue == 1)
			cv_allowBotGame.SetInt(0);
	}
}

BaseModeType g_iCurrentMode = INVALID;
public any Native_GetBaseMode(Handle plugin, int numParams)
{
	g_iCurrentMode = INVALID;
	int entity = CreateEntityByName("info_gamemode", -1);
	if (IsValidEntity(entity))
	{
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "PostSpawnActivate", -1, -1, 0);
		if (IsValidEntity(entity))
		{
			RemoveEdict(entity);
		}
	}
	return g_iCurrentMode;
}
public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if (strcmp(output, "OnCoop") == 0)
		g_iCurrentMode = OnCoop;
	else if (strcmp(output, "OnSurvival") == 0)
		g_iCurrentMode = OnSurvival;
	else if (strcmp(output, "OnVersus") == 0)
		g_iCurrentMode = OnVersus;
	else if (strcmp(output, "OnScavenge") == 0)
		g_iCurrentMode = OnScavenge;
	else
		g_iCurrentMode = INVALID;
}

public int Native_GetLobbySlots(Handle plugin, int numParams)
{
	char gamemode[30];
	GetConVarString(FindConVar("mp_gamemode"), gamemode, sizeof(gamemode));
	if (strcmp(gamemode, "mutation15") == 0) // 生还者对抗
		return 8;

	BaseModeType baseMode = GetBaseMode();
	if (OnVersus == baseMode)
		return 8;
	if (OnScavenge == baseMode)
		return 8;

	return 4;
}