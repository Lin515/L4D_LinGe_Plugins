#include <sourcemod>
#include <sdktools>
#include <LinGe_Library>

public Plugin myinfo = {
	name = "[L4D] LinGe Library",
	author = "LinGe",
	description = "求生之路 一个简单的自用库",
	version = "0.1",
	url = "https://github.com/Lin515/L4D_LinGe_Plugins"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion game = GetEngineVersion();
	if (game!=Engine_Left4Dead && game != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "本插件只支持 Left 4 Dead 1&2 .");
		return APLRes_SilentFailure;
	}

	CreateNative("GetBaseMode", Native_GetBaseMode);
	CreateNative("IsOnVersus", Native_IsOnVersus);
	RegPluginLibrary("LinGe_Library");

	return APLRes_Success;
}

BaseMode g_iCurrentMode = INVALID;
public any Native_GetBaseMode(Handle plugin, int numParams)
{
	g_iCurrentMode = INVALID;
	int entity = CreateEntityByName("info_gamemode");
	if (IsValidEntity(entity))
	{
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "PostSpawnActivate");
		if (IsValidEntity(entity))
			RemoveEdict(entity);
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

// 是否是基于对抗的模式（生还者对抗以及清道夫模式也视为对抗）
public any Native_IsOnVersus(Handle plugin, int numParams)
{
	char gamemode[30];
	GetConVarString(FindConVar("mp_gamemode"), gamemode, sizeof(gamemode));
	if (strcmp(gamemode, "mutation15") == 0) // 生还者对抗
		return true;

	BaseMode baseMode = Native_GetBaseMode(null, 0);
	if (OnVersus == baseMode)
		return true;
	if (OnScavenge == baseMode)
		return true;

	return false;
}