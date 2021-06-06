#include <sourcemod>
#include <sdktools>
#include <LinGe_Function>

// 这个插件主要是自用 就懒得说太多具体作用了
public Plugin myinfo = {
	name = "[L4D] LinGe Server Manager",
	author = "LinGe",
	description = "求生之路 简单管理服务器",
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
	return APLRes_Success;
}

public void OnPluginStart()
{
	cv_allowLobby = FindConVar("sv_allow_lobby_connect_only");
	cv_allowBotGame = FindConVar("sb_all_bot_game");

	cv_autoLobby = CreateConVar("l4d_server_manager_auto_lobby", "1", "自动管理sv_allow_lobby_connect_only参数，当有人连接时设置为0，服务器无人时设置为1。", FCVAR_SERVER_CAN_EXECUTE, true, 0.0, true, 1.0);
	cv_autoHibernate = CreateConVar("l4d_server_manager_auto_hibernate", "1", "服务器无人时自动设置sb_all_bot_game为0，以让服务器可自动休眠。", FCVAR_SERVER_CAN_EXECUTE, true, 0.0, true, 1.0);

	AutoExecConfig(true, "l4d_server_manager");
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