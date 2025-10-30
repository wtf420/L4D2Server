#define PLUGIN_VERSION "1.0"

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>

#define GAMEDATA 	"l4d_reload_fix"
#define CONFIG_DATA	"data/l4d_batch_shotgun_reload.cfg"

bool g_bLeft4Dead2;
StringMap g_hClipSize;
StringMap g_hDefaults;
ArrayList g_hWeaponSettings;
int g_iPreviousReloadingClip[MAXPLAYERS + 1];
int g_iMaxClip[MAXPLAYERS + 1];
int g_iReserveAmmo[MAXPLAYERS + 1];

char g_sWeapons[][] =
{
	"weapon_autoshotgun",
	"weapon_shotgun_spas",
	"weapon_pumpshotgun",
	"weapon_shotgun_chrome",
};

// From Left4Dhooks - put here to prevent using include and left4dhooks requirement for L4D1.
enum L4D2IntWeaponAttributes
{
	L4D2IWA_Damage,
	L4D2IWA_Bullets,
	L4D2IWA_ClipSize,
	MAX_SIZE_L4D2IntWeaponAttributes
};

native int L4D2_GetIntWeaponAttribute(const char[] weaponName, L4D2IntWeaponAttributes attr);



// ====================================================================================================
//										PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Batch Shotgun Reload - Faster Shotgun Reload",
	author = "SauceMaster",
	description = "Reloading shotgun now insert multiple shells at once.",
	version = PLUGIN_VERSION,
	url = ""
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test == Engine_Left4Dead) g_bLeft4Dead2 = false;
	else if(test == Engine_Left4Dead2) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}

	if (!g_bLeft4Dead2)
		MarkNativeAsOptional("L4D2_GetIntWeaponAttribute");

	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	if (g_bLeft4Dead2 && LibraryExists("left4dhooks") == false)
	{
		SetFailState("\n==========\nMissing required plugin: \"Left 4 DHooks Direct\".\nRead installation instructions again.\n==========");
	}
}

Handle g_hSDK_Call_AbortReload;
Handle g_hSDK_Call_FinishReload;
Handle g_hSDK_Call_StartReload;

public void OnPluginStart()
{
	// =========================
	// GAMEDATA
	// =========================
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if (FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if (hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	// =========================
	// SDKCALLS
	// =========================
	StartPrepSDKCall(SDKCall_Entity);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTerrorGun::AbortReload") == false )
		SetFailState("Failed to find offset: CTerrorGun::AbortReload");
	g_hSDK_Call_AbortReload = EndPrepSDKCall();
	if( g_hSDK_Call_AbortReload == null )
		SetFailState("Failed to create SDKCall: CTerrorGun::AbortReload");

	StartPrepSDKCall(SDKCall_Entity);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTerrorGun::FinishReload") == false )
		SetFailState("Failed to find offset: CTerrorGun::FinishReload");
	g_hSDK_Call_FinishReload = EndPrepSDKCall();
	if( g_hSDK_Call_FinishReload == null )
		SetFailState("Failed to create SDKCall: CTerrorGun::FinishReload");

	StartPrepSDKCall(SDKCall_Entity);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTerrorGun::Reload") == false )
		SetFailState("Failed to find offset: CTerrorGun::Reload");
	g_hSDK_Call_StartReload = EndPrepSDKCall();
	if( g_hSDK_Call_StartReload == null )
		SetFailState("Failed to create SDKCall: CTerrorGun::Reload");

	delete hGameData;

	// =========================
	// CLIP SIZE
	// =========================
	g_hDefaults = new StringMap();

	g_hDefaults.SetValue("weapon_autoshotgun",		10);
	g_hDefaults.SetValue("weapon_pumpshotgun",		8);

	if (g_bLeft4Dead2)
	{
		g_hDefaults.SetValue("weapon_shotgun_spas",		10);
		g_hDefaults.SetValue("weapon_shotgun_chrome",	8);
	}

	// =========================
	// EVENT
	// =========================
	// Event_Reload will trigger before the reload related values are set, use the SDKHook instead
	// HookEvent("weapon_reload", Event_Reload);
}

void LoadDataConfig()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_DATA);

	if(FileExists(sPath) == false )
	{
		// Load default config
		BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_DATA);
		if( !FileExists(sPath) )
		{
			SetFailState("Missing config '%s' please re-install.", CONFIG_DATA);
		}
	}

	KeyValues kv = new KeyValues("weapon_settings");
	if( !kv.ImportFromFile(sPath) )
	{
		delete kv;
		SetFailState("Error reading config '%s' please re-install.", CONFIG_DATA);
	}
	if (!kv.GotoFirstSubKey())
	{
		SetFailState("Where the settings at?");
	}

	g_hWeaponSettings = new ArrayList();
	do
	{
		StringMap weaponSetting = new StringMap();
		char buffer[255];
		
		kv.GetSectionName(buffer, sizeof(buffer));
		weaponSetting.SetString("weapon", buffer);

		kv.GetString("shells_per_load", buffer, sizeof(buffer));
		weaponSetting.SetString("shells_per_load", buffer);
		
		g_hWeaponSettings.Push(weaponSetting);
	} while (kv.GotoNextKey());
	delete kv;
	
	LogMessage("Successfully loaded %d settings.", g_hWeaponSettings.Length);
}

public void OnEntityCreated(int entity, const char[] name_entity) {
	StringMap weaponSetting = GetWeaponSetting(name_entity);
	if (weaponSetting != INVALID_HANDLE)
	{
		SDKHook(entity, SDKHook_ReloadPost, OnReloadPost);
	}
}

void OnReloadPost(int weapon, bool agree) {
	static char classname[32];
	GetEdictClassname(weapon, classname, sizeof(classname));
	StringMap weaponSetting = GetWeaponSetting(classname);
	if (agree && weaponSetting != INVALID_HANDLE) 
	{
		int shellsToLoad = 3;
		weaponSetting.GetValue("shells_to_load", shellsToLoad);
		int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");

		if (weapon == -1) return;

		int currentAmmo = GetEntProp(weapon, Prop_Send, "m_iClip1");
		g_iMaxClip[client] = GetMaxAmmo(weapon);
		g_iReserveAmmo[client] = GetReserveAmmo(weapon, client);

		int maxAmmo = g_iMaxClip[client] <= g_iReserveAmmo[client] + currentAmmo ? g_iMaxClip[client] : g_iReserveAmmo[client] + currentAmmo;
		int reloadNumShells = (maxAmmo - currentAmmo) / shellsToLoad;
		reloadNumShells += (maxAmmo - currentAmmo) % shellsToLoad > 0 ? 1 : 0;
		g_iPreviousReloadingClip[client] = currentAmmo;
		SetEntProp(weapon, Prop_Send, "m_reloadNumShells", reloadNumShells);

		CreateTimer(0.01, TimerReload, EntIndexToEntRef(weapon), TIMER_REPEAT);
	}
}

public void OnMapStart()
{
	// Get L4D1 weapons max clip size, does not support any servers that dynamically change during gameplay.
	if (!g_bLeft4Dead2)
	{
		delete g_hClipSize;
		g_hClipSize = new StringMap();

		int index, entity;
		while (index < sizeof(g_sWeapons))
		{
			entity = CreateEntityByName(g_sWeapons[index]);
			DispatchSpawn(entity);

			g_hClipSize.SetValue(g_sWeapons[index], GetEntProp(entity, Prop_Send, "m_iClip1"));
			RemoveEdict(entity);
			index++;
		}
	}

	LoadDataConfig();
}

// void Event_Reload(Event event, const char[] name, bool dontBroadcast)
// {
// 	int client = GetClientOfUserId(event.GetInt("userid"));
// 	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
// 	if (weapon == -1) return;

// 	// Validate shotgun only
// 	static char classname[32];
// 	GetEdictClassname(weapon, classname, sizeof classname);
// 	if (
// 		(strcmp(classname[7], "autoshotgun") == 0 ||
// 		strcmp(classname[7], "pumpshotgun") == 0) ||
// 		(g_bLeft4Dead2 &&
// 		(strcmp(classname[7], "shotgun_spas") == 0 ||
// 		strcmp(classname[7], "shotgun_chrome") == 0))
// 	)
// 	{
// 		int maxAmmo;
// 		if( g_bLeft4Dead2 )
// 		{
// 			maxAmmo = L4D2_GetIntWeaponAttribute(classname, L4D2IWA_ClipSize);
// 		}
// 		else
// 		{
// 			if (!g_hClipSize.GetValue(classname, maxAmmo))
// 				return;
// 		}

// 		int currentAmmo = GetEntProp(weapon, Prop_Send, "m_iClip1");
// 		g_iPreviousReloadingClip[client] = currentAmmo;
// 		int reloadNumShells = GetEntProp(weapon, Prop_Send, "m_reloadNumShells");
// 		int shellsInserted = GetEntProp(weapon, Prop_Send, "m_shellsInserted");
// 		PrintToChatAll("Reload: classname - %s | ammo - %d | m_reloadNumShells - %d | m_shellsInserted - %d", classname, currentAmmo, reloadNumShells, shellsInserted);
// 		CreateTimer(0.01, TimerReload, EntIndexToEntRef(weapon), TIMER_REPEAT);
// 	}
// }

Action TimerReload(Handle timer, int weapon)
{
	// Valid shotgun weapon and is reloading
	if ((weapon = EntRefToEntIndex(weapon)) != INVALID_ENT_REFERENCE && GetEntProp(weapon, Prop_Send, "m_bInReload") )
	{
		// Verify equipped in hand
		int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
		if (weapon != GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"))
			return Plugin_Stop;

		static char classname[32];
		GetEdictClassname(weapon, classname, sizeof(classname));
		StringMap weaponSetting = GetWeaponSetting(classname);
		int shellsToLoad = 3;
		weaponSetting.GetValue("shells_to_load", shellsToLoad);
		int currentAmmo = GetEntProp(weapon, Prop_Send, "m_iClip1");
		g_iReserveAmmo[client] = GetReserveAmmo(weapon, client);

		if (g_iPreviousReloadingClip[client] != currentAmmo)
		{
			// int reloadNumShells = GetEntProp(weapon, Prop_Send, "m_reloadNumShells");
			// int shellsInserted = GetEntProp(weapon, Prop_Send, "m_shellsInserted");
			// PrintToChatAll("	Reloading: classname - %s | previous_ammo - %d | ammo - %d | m_reloadNumShells - %d | m_shellsInserted - %d", classname, g_iPreviousReloadingClip[client], currentAmmo, reloadNumShells, shellsInserted);

			currentAmmo -= 1;
			g_iReserveAmmo[client] += 1;
			int maxAmmo = g_iMaxClip[client] <= g_iReserveAmmo[client] + currentAmmo ? g_iMaxClip[client] : g_iReserveAmmo[client] + currentAmmo;

			int shellsToInsert = (maxAmmo - currentAmmo > shellsToLoad) ? shellsToLoad : maxAmmo - currentAmmo;
			currentAmmo += shellsToInsert;
			SetEntProp(weapon, Prop_Send, "m_iClip1", currentAmmo);
			g_iReserveAmmo[client] -= shellsToInsert;
			SetReserveAmmo(weapon, client, g_iReserveAmmo[client]);
			g_iPreviousReloadingClip[client] = currentAmmo;

			if (currentAmmo >= maxAmmo)
			{
				// needs both to cancel reload, or else can not shoot for some time after reload
				SDKCall(g_hSDK_Call_AbortReload, weapon);
				SDKCall(g_hSDK_Call_FinishReload, weapon);
				return Plugin_Stop;
			}
			
			// int reloadState = GetEntProp(weapon, Prop_Send, "m_reloadState");
			// int reloadAnimState = GetEntProp(weapon, Prop_Send, "m_reloadAnimState");
			// int sequence = GetEntProp(weapon,Prop_Send,"m_nSequence");
			// PrintToChatAll("		Reloading: reloadState - %d| reloadAnimState - %d | sequence - %d", reloadState, reloadAnimState, sequence);
		
			// reloadNumShells = GetEntProp(weapon, Prop_Send, "m_reloadNumShells");
			// shellsInserted = GetEntProp(weapon, Prop_Send, "m_shellsInserted");
			// PrintToChatAll("			Reloading: ammo - %d | m_reloadNumShells - %d | m_shellsInserted - %d", currentAmmo, reloadNumShells, shellsInserted);
		}
		return Plugin_Continue;
	}

	// PrintToChatAll("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA");
	return Plugin_Stop;
}

int GetReserveAmmo(int weapon, int client)
{
	int ammo_offset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
	int ammo_type = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	return GetEntData(client, ammo_offset + ammo_type * 4);
}

void SetReserveAmmo(int weapon, int client, int ammo)
{
	int ammo_offset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
	int ammo_type = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	SetEntData(client, ammo_offset + ammo_type * 4, ammo);
}

int GetMaxAmmo(int weapon)
{
	static char classname[32];
	GetEdictClassname(weapon, classname, sizeof(classname));
	
	int maxAmmo;
	if (g_bLeft4Dead2)
	{
		maxAmmo = L4D2_GetIntWeaponAttribute(classname, L4D2IWA_ClipSize);
	}
	else
	{
		maxAmmo = -1;
	}
	return maxAmmo;
}

StringMap GetWeaponSetting(const char[] name)
{
	char buffer[255];
	for (int i = 0; i < g_hWeaponSettings.Length; i++)
	{
		StringMap setting = g_hWeaponSettings.Get(i);
		setting.GetString("weapon", buffer, sizeof(buffer));
		if (StrEqual(name, buffer, false))
		{
			return setting;
		}
	}

	return view_as<StringMap>(INVALID_HANDLE);
}