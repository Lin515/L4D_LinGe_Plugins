#if defined  _LinGe_Library_included_
	#endinput
#endif
#define _LinGe_Library_included_

public SharedPlugin:__pl_LinGe_Library =
{
	name = "LinGe_Library",
	file = "LinGe_Library.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
}

// 游戏基础模式
enum BaseModeType {
	INVALID = 0,
	OnCoop,
	OnVersus,
	OnSurvival,
	OnScavenge
};
native BaseModeType GetBaseMode(); // 获取当前游戏的基础模式
native int GetLobbySlots(); // 获取当前大厅的最大人数

#if !defined REQUIRE_PLUGIN
public __pl_LinGe_Library_SetNTVOptional()
{
	MarkNativeAsOptional("GetBaseMode");
	MarkNativeAsOptional("GetLobbySlots");
}
#endif