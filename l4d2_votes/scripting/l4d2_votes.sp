#include <sourcemod>
#include <builtinvotes>
#include <LinGe_Function>

public Plugin myinfo = {
	name = "Votes 多功能投票",
	author = "LinGe",
	description = "多功能投票",
	version = "0.1",
	url = "https://github.com/LinGe515"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion game = GetEngineVersion();
	if (game!=Engine_Left4Dead2)
	{
		strcopy(error, err_max, "本插件只支持 Left 4 Dead 2 ");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	
}

// 所有生还者回复状态
void RestoreHealth()
{
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			BypassAndExecuteCommand(i, "give", "health");
			SetEntPropFloat(i, Prop_Send, "m_healthBuffer", 0.0);
			SetEntProp(i, Prop_Send, "m_currentReviveCount", 0);
			SetEntProp(i, Prop_Send, "m_bIsOnThirdStrike", 0);
		}
	}
}