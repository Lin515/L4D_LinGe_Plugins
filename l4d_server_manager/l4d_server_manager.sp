#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

// 这个插件主要是自用 就懒得说太多具体作用了
public Plugin myinfo = {
	name = "[L4D] LinGe Server Manager",
	author = "LinGe",
	description = "求生之路 简单管理服务器",
	version = "0.1",
	url = "https://github.com/Lin515/L4D_LinGe_Plugins"
};

ConVar cv_hostingLobby;
ConVar cv_allowLobby;
ConVar cv_allowBotGame;
ConVar cv_allowHibernate;
ConVar cv_autoLobby;
ConVar cv_autoHibernate;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion game = GetEngineVersion();
	if (game!=Engine_Left4Dead && game!=Engine_Left4Dead2)
	{
		strcopy(error, err_max, "本插件只支持 Left 4 Dead 1&2 .");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	cv_hostingLobby = FindConVar("sv_hosting_lobby");
	cv_allowLobby = FindConVar("sv_allow_lobby_connect_only");
	cv_allowBotGame = FindConVar("sb_all_bot_game");
	cv_allowHibernate = FindConVar("sv_hibernate_when_empty");

	cv_autoLobby = CreateConVar("l4d_server_manager_auto_lobby", "1", "自动管理服务器大厅（第一个人连入时使其创建大厅，然后再将大厅移除）", FCVAR_SERVER_CAN_EXECUTE, true, 0.0, true, 1.0);
	cv_autoHibernate = CreateConVar("l4d_server_manager_auto_hibernate", "1", "自动管理服务器休眠", FCVAR_SERVER_CAN_EXECUTE, true, 0.0, true, 1.0);
}

public void OnMapStart()
{
	CheckHasHuman();
}

public bool OnClientConnect(int client)
{
	if (!IsFakeClient(client))
	{
		if (cv_autoLobby.IntValue == 1)
			cv_allowLobby.SetInt(0);
	}
	return true;
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
		return;
	if (cv_autoLobby.IntValue == 1 && cv_hostingLobby.IntValue == 1)
		L4D_LobbyUnreserve();
	if (cv_autoHibernate.IntValue == 1)
		cv_allowBotGame.SetInt(1);
}

public void OnClientDisconnect(int client)
{
	if (IsFakeClient(client))
		return;
	CreateTimer(1.0, Timer_CheckHasHuman);
}
public Action Timer_CheckHasHuman(Handle timer)
{
	CheckHasHuman();
}

void CheckHasHuman()
{
	if (GetHumans(true) == 0)
	{
		if (cv_autoLobby.IntValue == 1)
		{
			cv_allowLobby.SetInt(1);
		}

		if (cv_autoHibernate.IntValue == 1)
		{
			cv_allowBotGame.SetInt(0);
			cv_allowHibernate.SetInt(1);
		}
	}
}

// 当前在线的全部真实玩家数
stock int GetHumans(bool noNeedInGame=false)
{
	int num = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
		{
			if (IsClientInGame(i) || noNeedInGame)
			{
				num++;
			}
		}
	}
	return num;
}