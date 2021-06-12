#include <sourcemod>
#include <LinGe_Function>

public Plugin myinfo = {
	name = "插件名",
	author = "LinGe",
	description = "描述",
	version = "0.1",
	url = "https://github.com/LinGe515"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion game = GetEngineVersion();
	if (game!=Engine_Left4Dead && game!=Engine_Left4Dead2)
	{
		strcopy(error, err_max, "本插件只支持 Left 4 Dead 1&2 ");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	
}