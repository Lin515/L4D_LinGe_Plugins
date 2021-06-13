#if defined  _LinGe_Library_included_
	#endinput
#endif
#define _LinGe_Library_included_
#include <LinGe_Function>

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
enum BaseMode {
	INVALID = 0,
	OnCoop,
	OnVersus,
	OnSurvival,
	OnScavenge
};
native BaseMode GetBaseMode(); // 获取当前游戏的基础模式
native bool IsOnVersus(); // 当前游戏模式是否是基于对抗类模式（生还者对抗与清道夫模式也视为对抗类模式）

#if !defined REQUIRE_PLUGIN
public __pl_LinGe_Library_SetNTVOptional()
{
	MarkNativeAsOptional("GetBaseMode");
	MarkNativeAsOptional("IsOnVersus");
}
#endif