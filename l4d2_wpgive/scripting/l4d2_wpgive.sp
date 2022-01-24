#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <LinGe_Function>

public Plugin myinfo = {
	name = "!wpgive 获取武器",
	author = "LinGe",
	description = "!wpgive 获取武器",
	version = "0.1",
	url = "https://github.com/Lin515/L4D_LinGe_Plugins"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion game = GetEngineVersion();
	if (game!=Engine_Left4Dead2)
	{
		strcopy(error, err_max, "本插件只支持 Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_wpgive", Cmd_wpgive, "物品获取菜单");
}

public Action Cmd_wpgive(int client, int args)
{
	if (0 == client)
		return Plugin_Handled;

	Menu menu = new Menu(GiveMenu_Selected);
	menu.SetTitle("武器获取");
	menu.AddItem("give_melee", "近战");
	menu.AddItem("give_shotgun", "霰弹枪");
	menu.AddItem("give_smg", "冲锋枪");
	menu.AddItem("give_rifle", "步枪");
	menu.AddItem("give_sniper", "狙击枪");
	menu.AddItem("give_other", "其它武器");
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int GiveMenu_Selected(Menu menu, MenuAction action, int client, int curSel)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			char info[128];
			menu.GetItem(curSel, info, sizeof(info));
			Menu_Exec(client, info);
		}
	}
}

void Menu_Exec(int client, const char[] str)
{
	Menu menu = new Menu(GiveTowMenu_Selected);
	if (strcmp(str, "give_melee") == 0)
	{
		menu.AddItem("knife", "小刀");
		menu.AddItem("machete", "砍刀");
		menu.AddItem("katana", "武士刀");
		menu.AddItem("baseball_bat", "棒球棍");
		menu.AddItem("cricket_bat", "板球棍");
		menu.AddItem("fireaxe", "斧头");
		menu.AddItem("frying_pan", "平底锅");
		menu.AddItem("crowbar", "撬棍");
		menu.AddItem("electric_guitar", "吉他");
		menu.AddItem("tonfa", "警棍");
		menu.AddItem("pitchfork", "草叉");
		menu.AddItem("shovel", "铁锹");
		menu.AddItem("weapon_chainsaw", "电锯");
		menu.SetTitle("近战");
	}
	else if (strcmp(str, "give_shotgun") == 0)
	{
		menu.AddItem("pumpshotgun", "M870");
		menu.AddItem("shotgun_chrome", "Chrome");
		menu.AddItem("autoshotgun", "M1014");
		menu.AddItem("shotgun_spas", "SPAS");
		menu.SetTitle("霰弹枪");
	}
	else if (strcmp(str, "give_smg") == 0)
	{
		menu.AddItem("smg", "UZI");
		menu.AddItem("smg_silenced", "MAC");
		menu.AddItem("weapon_smg_mp5", "MP5");
		menu.SetTitle("冲锋枪");
	}
	else if (strcmp(str, "give_rifle") == 0)
	{
		menu.AddItem("rifle_ak47", "AK47");
		menu.AddItem("rifle", "M16");
		menu.AddItem("rifle_desert", "SCAR");
		menu.AddItem("weapon_rifle_sg552", "SG552");
		menu.SetTitle("步枪");
	}
	else if (strcmp(str, "give_sniper") == 0)
	{
		menu.AddItem("hunting_rifle", "M14");
		menu.AddItem("sniper_military", "G3SG1");
		menu.AddItem("weapon_sniper_scout", "Scout");
		menu.AddItem("weapon_sniper_awp", "AWP");
		menu.SetTitle("狙击枪");
	}
	else if (strcmp(str, "give_other") == 0)
	{
		menu.AddItem("pistol", "普通手枪");
		menu.AddItem("pistol_magnum", "马格南");
		menu.AddItem("weapon_grenade_launcher", "榴弹");
		menu.AddItem("rifle_m60", "M60");
		menu.SetTitle("其它武器");
	}
	else
	{
		delete menu;
		return;
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int GiveTowMenu_Selected(Menu menu, MenuAction action, int client, int curSel)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:
		{
			if( curSel == MenuCancel_ExitBack )
				Cmd_wpgive(client, 0);
		}
		case MenuAction_Select:
		{
			char info[128];
			menu.GetItem(curSel, info, sizeof(info));
			CheatCommand(client, "give", info);
		}
	}
}