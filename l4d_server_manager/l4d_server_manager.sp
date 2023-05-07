#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <LinGe_Function>

// 这个插件主要是自用 就懒得说太多具体作用了
public Plugin myinfo = {
	name = "[L4D] LinGe Server Manager",
	author = "LinGe",
	description = "求生之路 简单管理服务器",
	version = "0.4",
	url = "https://github.com/Lin515/L4D_LinGe_Plugins"
};

ConVar cv_hostingLobby;
ConVar cv_onlyLobby;
ConVar cv_allowBotGame;
ConVar cv_allowHibernate;
ConVar cv_autoLobby;
ConVar cv_autoHibernate;
ConVar cv_exclusive;
ConVar cv_exclusiveLock;
ConVar cv_autoCrash;
ConVar cv_cheats;
int g_crashCountDown = 0;

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
	cv_onlyLobby = FindConVar("sv_allow_lobby_connect_only");
	cv_allowBotGame = FindConVar("sb_all_bot_game");
	cv_allowHibernate = FindConVar("sv_hibernate_when_empty");
	cv_exclusive = FindConVar("sv_steamgroup_exclusive");
	cv_cheats = FindConVar("sv_cheats");

	cv_autoLobby = CreateConVar("l4d_server_manager_auto_lobby", "1", "自动管理服务器大厅（第一个人连入时使其创建大厅，然后再将大厅移除）", _, true, 0.0, true, 1.0);
	cv_autoHibernate = CreateConVar("l4d_server_manager_auto_hibernate", "1", "自动管理服务器休眠", _, true, 0.0, true, 1.0);
	cv_exclusiveLock = CreateConVar("sv_steamgroup_exclusive_lock", "-1", "当该值>=0时，sv_steamgroup_exclusive 将被锁定为这个变量的值", _, true, -1.0, true, 1.0);
	cv_autoCrash = CreateConVar("l4d_auto_crash", "0", "当服务器不存在真人玩家多少秒后，自动将服务器Crash重启，若为0则不自动重启。(仅可用于Linux服务端，Windows服务端Crash后需要手动启动)", _, true, 0.0);

	cv_exclusive.AddChangeHook(OnExclusiveChanged);
	cv_exclusiveLock.AddChangeHook(OnExclusiveChanged);
}

public void OnExclusiveChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (cv_exclusiveLock.IntValue >= 0 && cv_exclusiveLock.IntValue != cv_exclusive.IntValue)
		cv_exclusive.IntValue = cv_exclusiveLock.IntValue;
}

public void OnMapStart()
{
	if (GetHumans(true) == 0)
	{
		if (cv_autoLobby.IntValue == 1)
		{
			cv_onlyLobby.IntValue = 1;
		}
		if (cv_autoHibernate.IntValue == 1 && g_crashCountDown == 0)
		{
			cv_allowBotGame.IntValue = 0;
			cv_allowHibernate.IntValue = 1;
		}
	}
}

public bool OnClientConnect(int client)
{
	if (!IsFakeClient(client))
	{
		if (cv_autoLobby.IntValue == 1)
		{
			cv_onlyLobby.SetInt(0);
			if (cv_hostingLobby.IntValue == 1)
				L4D_LobbyUnreserve();
		}
		if ((cv_autoHibernate.IntValue == 1 || cv_autoCrash.IntValue > 0) && cv_allowBotGame.IntValue == 0)
			cv_allowBotGame.IntValue = 1;
	}
	return true;
}

public void OnClientDisconnect(int client)
{
	if (IsFakeClient(client))
		return;
	CreateTimer(1.0, Timer_CheckHasHuman);
}

public Action Timer_CheckHasHuman(Handle timer)
{
	if (GetHumans(true) == 0)
	{
		if (cv_autoCrash.IntValue > 0)
		{
			if (0 == g_crashCountDown)
			{
				g_crashCountDown = cv_autoCrash.IntValue;
				CreateTimer(1.0, Timer_AutoCrash, 0, TIMER_REPEAT);
			}
		}
		else if (cv_autoHibernate.IntValue == 1)
		{
			if (cv_autoLobby.IntValue == 1)
			{
				cv_onlyLobby.IntValue = 1;
			}
			cv_allowBotGame.IntValue = 0;
			cv_allowHibernate.IntValue = 1;
		}
	}
}

public Action Timer_AutoCrash(Handle timer, any data)
{
	g_crashCountDown--;
	if (GetHumans(true) > 0)
	{
		g_crashCountDown = 0;
		return Plugin_Stop;
	}
	if (g_crashCountDown <= 0)
	{
		g_crashCountDown = 0;
		cv_cheats.IntValue = 1;
		ServerCommand("sv_crash");
		return Plugin_Stop;
	}
	return Plugin_Continue;
}