#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <LinGe_Library>

public Plugin myinfo = {
	name = "l4d2 votes",
	author = "LinGe",
	description = "多功能投票：弹药、特感击杀回血、自动红外、友伤、服务器人数设置等功能",
	version = "1.0",
	url = "https://github.com/LinGe515"
};

ConVar cv_returnBlood;
ConVar cv_specialReturn;
ConVar cv_witchReturn;
ConVar cv_healthLimit;
int g_zombieClassOffset;
public void OnPluginStart()
{
	cv_returnBlood = CreateConVar("ReturnBlood", "0", "特感击杀回血总开关", FCVAR_SERVER_CAN_EXECUTE, true, 0.0, true, 1.0);
	cv_specialReturn = CreateConVar("l4d2_votes_kill_special_return", "2", "每击杀一只特感可回多少血.", FCVAR_SERVER_CAN_EXECUTE, true, 0.0, true, 100.0);
	cv_witchReturn = CreateConVar("l4d2_votes_kill_witch_return", "10", "击杀一只Witch可回多少血.", FCVAR_SERVER_CAN_EXECUTE, true, 0.0, true, 100.0);
	cv_healthLimit = CreateConVar("l4d2_votes_kill_health_limit", "100", "最高回血上限.", FCVAR_SERVER_CAN_EXECUTE, true, 40.0, true, 500.0);
	cv_returnBlood.AddChangeHook(cv_ReturnBloodChanged);

	HookEvent("player_death", Event_player_death, EventHookMode_Post);
	g_zombieClassOffset = FindSendPropInfo("CTerrorPlayer", "m_zombieClass");
}

public void OnConfigsExecuted()
{
}

public void cv_ReturnBloodChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (cv_returnBlood.BoolValue)
		PrintToChatAll("\x04特感击杀回血 \x03已开启");
	else
		PrintToChatAll("\x04特感击杀回血 \x03已关闭");
}

public Action Event_player_death(Event event, const char[] name, bool dontBroadcast)
{
	// 特感击杀回血
	if (cv_returnBlood.BoolValue)
	{
		int victim = GetClientOfUserId(event.GetInt("userid"));
		int attacker = GetClientOfUserId(event.GetInt("attacker"));
		// 被攻击者必须是有效特感 攻击者必须是有效生还者并且没有倒地
		if (IsValidClient(victim) && GetClientTeam(victim) == 3
		&& IsValidClient(attacker) && GetClientTeam(attacker) == 2
		&& !IsIncapacitated(attacker) )
		{
			int surHealth = GetHealth(attacker);
			int zombieClass = GetEntData(victim, g_zombieClassOffset); // 获取特感类型
			if (zombieClass >= 1 && zombieClass <= 6
			&& cv_specialReturn.IntValue > 0) // 如果是普通特感
				surHealth += cv_specialReturn.IntValue;
			else if (7 == zombieClass
			&& cv_witchReturn.IntValue > 0) // 如果是witch
				surHealth += cv_witchReturn.IntValue;
			else
				return Plugin_Continue;
			if (surHealth > cv_healthLimit.IntValue)
				surHealth = cv_healthLimit.IntValue;
			SetHealth(attacker, surHealth);
		}
	}
	return Plugin_Continue;
}