#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <sdkhooks>

#define PLUGIN_NAME "[L4D1/2] AK with Underbarrel grenade launcher"
#define PLUGIN_AUTHOR "SauceMaster"
#define PLUGIN_DESC "Press middle mouse with weapon to shoot out a grenade."
#define PLUGIN_VERSION "1.0"
#define PLUGIN_URL ""

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESC,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
}

#define SOUND_GRENADE_LAUNCHER_FIRE "weapons/grenade_launcher/grenadefire/grenade_launcher_fire_1.wav"

ConVar g_hCvar_glprj_cooldown, g_hCvar_molotov_cooldown, g_hCvar_pipebomb_cooldown, g_hCvar_vomitjar_cooldown;
ConVar g_hCvar_weapon;
ConVar g_hCvar_sticky_pipebomb, g_hCvar_sticky_pipebomb_timer;
float g_fCvar_glprj_cooldown, g_fCvar_molotov_cooldown, g_fCvar_pipebomb_cooldown, g_fCvar_vomitjar_cooldown;
char g_cCvar_weapon[32];
bool g_bCvar_sticky_pipebomb;
float g_fCvar_sticky_pipebomb_timer;

float g_fPlayerLastShotTime[MAXPLAYERS+1];
float g_fPlayerCooldownTime[MAXPLAYERS+1];

#define IsEntity(%1) (2048 >= %1 > MaxClients)
#define IsClient(%1) ((1 <= %1 <= MaxClients) && IsClientInGame(%1))

native int L4D_DetonateProjectile(int entity);
native int L4D_PipeBombPrj(int client, const float vecPos[3], const float vecAng[3], bool effects, const float vecVel[3]);
native int L4D_MolotovPrj(int client, const float vecPos[3], const float vecAng[3], bool effects, const float vecVel[3]);
native int L4D2_VomitJarPrj(int client, const float vecPos[3], const float vecAng[3], bool effects, const float vecVel[3]);
native int L4D_TankRockPrj(int client, const float vecPos[3], const float vecAng[3], bool effects, const float vecVel[3]);
native int L4D2_GrenadeLauncherPrj(int client, const float vecPos[3], const float vecAng[3], const float vecVel[3] = NULL_VECTOR, const float vecRot[3] = NULL_VECTOR, bool bIncendiary = false);

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	
	MarkNativeAsOptional("L4D_DetonateProjectile");
	MarkNativeAsOptional("L4D_MolotovPrj");
	MarkNativeAsOptional("L4D_PipeBombPrj");
	MarkNativeAsOptional("L4D2_SpitterPrj");
	MarkNativeAsOptional("L4D2_VomitJarPrj");
	MarkNativeAsOptional("L4D_TankRockPrj");
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hCvar_weapon =				CreateConVar("l4d_ubgl_weapon", "weapon_rifle_ak47", "The weapon that this thing attachs to.", FCVAR_NOTIFY);
	g_hCvar_glprj_cooldown =		CreateConVar("l4d_ubgl_glprj_cooldown", "5.0", "Cooldown after shooting out a grenade launcher grenade.", FCVAR_NOTIFY);
	g_hCvar_molotov_cooldown =		CreateConVar("l4d_ubgl_molotov_cooldown", "15.0", "Cooldown after shooting out a molotov.", FCVAR_NOTIFY);
	g_hCvar_pipebomb_cooldown =		CreateConVar("l4d_ubgl_pipebomb_cooldown", "15.0", "Cooldown after shooting out a pipe bomb.", FCVAR_NOTIFY);
	g_hCvar_vomitjar_cooldown =		CreateConVar("l4d_ubgl_vomitjar_cooldown", "15.0", "Cooldown after shooting out a vomit jar.", FCVAR_NOTIFY);
	g_hCvar_sticky_pipebomb =		CreateConVar("l4d_ubgl_sticky_pipebomb", "true", "Is the pipe bomb sticky?.", FCVAR_NOTIFY);
	g_hCvar_sticky_pipebomb_timer =	CreateConVar("g_hCvar_l4d_ubgl_sticky_pipebomb_timer", "3.0", "Sticky pipe bomb fuse?.", FCVAR_NOTIFY);
	AutoExecConfig(true, "l4d_underbarrel_gl");
	
	g_hCvar_weapon.AddChangeHook(OnConVarChanged);
	g_hCvar_glprj_cooldown.AddChangeHook(OnConVarChanged);
	g_hCvar_molotov_cooldown.AddChangeHook(OnConVarChanged);
	g_hCvar_pipebomb_cooldown.AddChangeHook(OnConVarChanged);
	g_hCvar_vomitjar_cooldown.AddChangeHook(OnConVarChanged);
	g_hCvar_sticky_pipebomb.AddChangeHook(OnConVarChanged);
	g_hCvar_sticky_pipebomb_timer.AddChangeHook(OnConVarChanged);

	HookEvent("player_spawn", OnPlayerSpawn);	
}

void OnConVarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_hCvar_weapon.GetString(g_cCvar_weapon, sizeof(g_cCvar_weapon));
	g_fCvar_glprj_cooldown = g_hCvar_glprj_cooldown.FloatValue;
	g_fCvar_molotov_cooldown = g_hCvar_molotov_cooldown.FloatValue;
	g_fCvar_pipebomb_cooldown = g_hCvar_pipebomb_cooldown.FloatValue;
	g_fCvar_vomitjar_cooldown = g_hCvar_vomitjar_cooldown.FloatValue;

	g_bCvar_sticky_pipebomb = g_hCvar_sticky_pipebomb.BoolValue;
	g_fCvar_sticky_pipebomb_timer = g_hCvar_sticky_pipebomb_timer.FloatValue;
}
// ====================================================================================================
// EVENTS
// ====================================================================================================

public void OnMapStart()
{
	PrecacheSound(SOUND_GRENADE_LAUNCHER_FIRE);
	for (int i = 0; i < MAXPLAYERS; i++)
	{
		g_fPlayerLastShotTime[i] = 0.0;
		g_fPlayerCooldownTime[i] = 0.0;
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	float gameTime = GetGameTime();
	if(!IsFakeClient(client) && IsPlayerAlive(client))
	{
		if( buttons & IN_ZOOM && (gameTime - g_fPlayerLastShotTime[client] > g_fPlayerCooldownTime[client]))
		{
			int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if (IsValidEntity(weapon))
			{
				char classname[32];
				GetEdictClassname(weapon, classname, sizeof(classname));
				if(StrEqual(classname, g_cCvar_weapon))
				{
					int projectile = CreateAndLaunchProjectile(client);
					if (projectile != INVALID_ENT_REFERENCE)
					{
						g_fPlayerLastShotTime[client] = gameTime;
					}
				}
			}
		}
	}

	return Plugin_Continue;
}

void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));  
	g_fPlayerLastShotTime[client] = 0.0;
	g_fPlayerCooldownTime[client] = 0.0;
}

// ====================================================================================================
// PLUGIN
// ====================================================================================================

int CreateAndLaunchProjectile(int client)
{
	ConVar g_hCvar_velocity = FindConVar("grenadelauncher_velocity");

	float vPos[3], vAng[3], vDir[3];
	GetClientEyeAngles(client, vAng);
	GetClientEyePosition(client, vPos);
	GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vDir, vDir);
	ScaleVector(vDir, GetConVarFloat(g_hCvar_velocity));

	int projectile = INVALID_ENT_REFERENCE;
	int weapon = GetPlayerWeaponSlot(client, 2);
	if (weapon != INVALID_ENT_REFERENCE)
	{
		char classname[32];
		GetEdictClassname(weapon, classname, sizeof(classname));
		if (StrEqual(classname, "weapon_molotov"))
		{
			projectile = L4D_MolotovPrj(client, vPos, vAng, true, vDir);
			g_fPlayerCooldownTime[client] = g_fCvar_molotov_cooldown;
		}
		else if (StrEqual(classname, "weapon_pipe_bomb"))
		{
			projectile = L4D_PipeBombPrj(client, vPos, vAng, true, vDir);
			if (g_bCvar_sticky_pipebomb)
			{
				SDKHook(projectile, SDKHook_Touch, OnTouch);
				CreateTimer(g_fCvar_sticky_pipebomb_timer, TimerDetonate, EntIndexToEntRef(projectile));
			}
			g_fPlayerCooldownTime[client] = g_fCvar_pipebomb_cooldown;
		}
		else if (StrEqual(classname, "weapon_vomitjar"))
		{
			projectile = L4D2_VomitJarPrj(client, vPos, vAng, true, vDir);
			g_fPlayerCooldownTime[client] = g_fCvar_vomitjar_cooldown;
		}
	}
	else
	{
		projectile = L4D2_GrenadeLauncherPrj(client, vPos, vAng, vDir);
		g_fPlayerCooldownTime[client] = g_fCvar_glprj_cooldown;
	}
	
	if(projectile != INVALID_ENT_REFERENCE)
	{
		EmitSoundToAll(SOUND_GRENADE_LAUNCHER_FIRE, client);
		TeleportEntity(projectile, vPos, vAng, vDir);
		DispatchSpawn(projectile);
		// SetEntityMoveType(projectile, MOVETYPE_FLY);
		if (g_fPlayerCooldownTime[client] > 5.0)
			CreateTimer(g_fPlayerCooldownTime[client], TimerReadyHint, EntIndexToEntRef(client));
	}
	return projectile;
}

void OnTouch(int entity, int target)
{
	SDKUnhook(entity, SDKHook_Touch, OnTouch);
	SetEntProp(entity, Prop_Send, "m_nSolidType", 0);
	SetEntityMoveType(entity, MOVETYPE_NONE);

	if (target != INVALID_ENT_REFERENCE)
	{
		char classname[64];
		GetEntityClassname(target, classname, sizeof(classname));

		if (StrEqual(classname, "player") || StrEqual(classname, "infected"))
		{
			SetVariantString("!activator");
			AcceptEntityInput(entity, "SetParent", target);

			float pos[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
		}
	}
}

Action TimerDetonate(Handle timer, int entity) 
{
	entity = EntRefToEntIndex(entity);
	if (entity != INVALID_ENT_REFERENCE) 
		L4D_DetonateProjectile(entity);

	return Plugin_Stop;
}

Action TimerReadyHint(Handle timer, int client) 
{
	client = EntRefToEntIndex(client);
	if (client != INVALID_ENT_REFERENCE)
		PrintHintText(client, "Your special underbarrel grenade launcher is ready.");

	return Plugin_Stop;
}