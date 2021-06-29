#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <LinGe_Function>
#include <builtinvotes>

public Plugin myinfo = {
	name = "l4d2 votes",
	author = "LinGe",
	description = "多功能投票：弹药、自动红外、友伤、服务器人数设置、特感击杀回血等",
	version = "1.0",
	url = "https://github.com/LinGe515"
};

ConVar cv_svmaxplayers; // sv_maxplayers
ConVar cv_ammoMode; // 弹药模式
ConVar cv_autoLaser; // 自动红外
ConVar cv_teamHurt; // 是否允许投票改变友伤系数
ConVar cv_restartChapter; // 是否允许投票重启当前章节
ConVar cv_players; // 服务器默认人数
ConVar cv_playersLower; // 投票改变服务器人数下限
ConVar cv_playersUpper; // 投票改变服务器人数上限
ConVar cv_returnBlood; // 击杀回血
ConVar cv_specialReturn; // 特感击杀回血量
ConVar cv_witchReturn; // witch击杀回血量
ConVar cv_healthLimit; // 回血上限
int g_zombieClassOffset;

// 武器备弹量设置
ConVar cv_ammoInfinite; // 无限弹药无需换弹
ConVar cv_ammoMax[7]; // 最大弹药量
char cvar_ammoMax[7][50] = { // 控制台变量名
	"ammo_shotgun_max", // 单喷
	"ammo_autoshotgun_max", // 连喷
	"ammo_assaultrifle_max", // 步枪
	"ammo_grenadelauncher_max", // 榴弹
	"ammo_huntingrifle_max", // 连狙
	"ammo_sniperrifle_max", // 狙击
	"ammo_smg_max" // 冲锋枪
};

public void OnPluginStart()
{
	cv_svmaxplayers	= FindConVar("sv_maxplayers");
	cv_ammoInfinite = FindConVar("sv_infinite_ammo"); // 该变量为1时 主副武器开枪均不消耗子弹
	for (int i=0; i<7; i++)
	{
		cv_ammoMax[i] = FindConVar(cvar_ammoMax[i]);
		cv_ammoMax[i].SetBounds(ConVarBound_Upper, true, 999.0);
	}
	cv_ammoMode		= CreateConVar("l4d2_votes_ammomode", "1", "多倍弹药模式 -1:完全禁用 0:禁用多倍但允许投票补满所有人弹药 1:一倍且允许开启多倍弹药 2:双倍 3:三倍 4:无限(需换弹) 5:无限(无需换弹)",  FCVAR_SERVER_CAN_EXECUTE, true, -1.0, true, 5.0);
	cv_autoLaser	= CreateConVar("l4d2_votes_autolaser", "0", "自动获得红外 -1:完全禁用 0:关闭 1:开启", FCVAR_SERVER_CAN_EXECUTE, true, -1.0, true, 1.0);
	cv_teamHurt		= CreateConVar("l4d2_votes_teamhurt", "1", "是否允许投票改变友伤系数 0:不允许 1:允许", FCVAR_SERVER_CAN_EXECUTE, true, 0.0, true, 1.0);
	cv_restartChapter = CreateConVar("l4d2_votes_restartchapter", "1", "是否允许投票重启当前章节 0:不允许 1:允许", FCVAR_SERVER_CAN_EXECUTE, true, 0.0, true, 1.0);
	cv_players		= CreateConVar("l4d2_votes_players", "8", "服务器人数，若为0则不改变人数。游戏时改变本参数是无效的。", FCVAR_SERVER_CAN_EXECUTE, true, 0.0, true, 32.0);
	cv_playersLower	= CreateConVar("l4d2_votes_players_lower", "4", "投票更改服务器人数的下限", FCVAR_SERVER_CAN_EXECUTE, true, 1.0, true, 32.0);
	cv_playersUpper	= CreateConVar("l4d2_votes_players_upper", "12", "投票更改服务器人数的上限。若下限>=上限，则不允许投票更改服务器人数。（这不影响本插件更改默认人数）", FCVAR_SERVER_CAN_EXECUTE, true, 1.0, true, 32.0);
	cv_returnBlood	= CreateConVar("ReturnBlood", "0", "特感击杀回血总开关 -1:完全禁用 0:关闭 1:开启", FCVAR_SERVER_CAN_EXECUTE, true, -1.0, true, 1.0);
	cv_specialReturn = CreateConVar("l4d2_votes_returnblood_special", "2", "击杀一只特感回多少血", FCVAR_SERVER_CAN_EXECUTE, true, 0.0, true, 100.0);
	cv_witchReturn	= CreateConVar("l4d2_votes_returnblood_witch", "10", "击杀一只Witch回多少血", FCVAR_SERVER_CAN_EXECUTE, true, 0.0, true, 100.0);
	cv_healthLimit	= CreateConVar("l4d2_votes_returnblood_limit", "100", "最高回血上限。（仅影响回血时的上限，不影响其它情况下的血量上限）", FCVAR_SERVER_CAN_EXECUTE, true, 40.0, true, 500.0);
	cv_ammoMode.AddChangeHook(AmmoModeChanged);

	HookEvent("player_death", Event_player_death, EventHookMode_Post);
	g_zombieClassOffset = FindSendPropInfo("CTerrorPlayer", "m_zombieClass");

	RegConsoleCmd("sm_votes", Cmd_votes, "多功能投票菜单");
}

public void OnConfigsExecuted()
{
	if (cv_players.IntValue > 0 && null != cv_svmaxplayers)
		cv_svmaxplayers.IntValue = cv_players.IntValue;
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

public Action Cmd_votes(int client, int args)
{

}

// 多倍弹药
public void AmmoModeChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetAmmoMode();
}

void SetAmmoMode()
{
	int mode = cv_ammoMode.IntValue;

	if (5 == mode) // 无限弹药无需换弹
	{
		cv_ammoInfinite.IntValue = 1;
		RestoreSurvivorAmmo();
		return;
	}
	cv_ammoInfinite.IntValue = 0;

	if (2==mode || 3==mode) // 2倍、3倍弹药
	{
		int mult = 1; // 默认弹药量的乘数
		char buffer[10];
		mult = mode;
		// 设置的新弹药量
		for (int i=0; i<7; i++)
		{
			cv_ammoMax[i].GetDefault(buffer, sizeof(buffer));
			cv_ammoMax[i].IntValue = StringToInt(buffer) * mult;
			PrintToChatAll("%s : %d", cvar_ammoMax[i], cv_ammoMax[i].IntValue);
		}
	}

	if (mode > 0)
		RestoreSurvivorAmmo();
}

// 重置所有生还者弹药量
void RestoreSurvivorAmmo()
{
	int weapon = 0;
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			weapon = GetPlayerWeaponSlot(i, 0);
			if (IsValidEntity(weapon) && HasEntProp(weapon, Prop_Send, "m_iExtraPrimaryAmmo"))
			{
				PrintToChatAll("weapon ammo : %d", GetEntProp(weapon, Prop_Send, "m_iExtraPrimaryAmmo"));
				SetEntProp(weapon, Prop_Send, "m_iExtraPrimaryAmmo", 0); // 备弹置0再给予
				CheatCommand(i, "give", "ammo");
			}
		}
	}
}

// 自动获得红外
#define UPGRADE_LASER  (1 << 2) // 100b
public void OnClientPutInServer(int client)
{
	if (IsValidClient(client))
		SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
}

public void OnClientDisconnect(int client)
{
	if (IsValidClient(client))
		SDKUnhook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
}

// 开关开启后，切换一下武器即可让主武器获得红外，懒得写开关开启所有人都获得红外的代码
public Action OnWeaponSwitch(int client, int weapon)
{
	if (1 == cv_autoLaser.IntValue)
	{
		if (IsValidClient(client) && GetClientTeam(client) == 2 && IsValidEntity(weapon))
		{
			if (HasEntProp(weapon, Prop_Send, "m_upgradeBitVec"))
			{
				int flags = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
				if (!(flags & UPGRADE_LASER)) // 如果当前没有红外，则使其获得
					SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", flags | UPGRADE_LASER);
			}
		}
	}
}