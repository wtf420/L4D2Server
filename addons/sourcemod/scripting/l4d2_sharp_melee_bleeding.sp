#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS FCVAR_NOTIFY

public Plugin myinfo =
{
	name = "[L4D2] Sharp melee bleeding",
	author = "SauceMaster",
	description = "Sharp melee weapons causes bleeding damage.",
	version = "1.0",
	url = ""
}

ConVar g_hBleedChance, g_hBleedTickInterval;
ConVar g_hBleedDamagePerTick, g_hBleedDuration, g_hBleedSlowMultiplier;
// FF stands for friendly fire
ConVar g_hBleedDamagePerTick_ff, g_hBleedDDuration_ff, g_hBleedSlowMultiplier_ff;

float g_fBleedChance, g_fBleedTickInterval;
float g_fBleedDamagePerTick, g_fBleedDuration, g_fBleedSlowMultiplier;
// FF stands for friendly fire
float g_fBleedDamagePerTick_ff, g_fBleedDDuration_ff, g_fBleedSlowMultiplier_ff;

enum struct BleedData {
	int target;
	int attacker;
	int remainingDuration;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	g_hBleedChance = 			CreateConVar("sm_bleed_chance", 			"100", 		"The chance for the victim to start bleeding each hit. (0.0 - 100.0)", 							CVAR_FLAGS);
	g_hBleedTickInterval = 		CreateConVar("sm_bleed_tick_interval", 		"0.25", 	"Time in seconds between each bleed tick. (in seconds, Minimum 0.1)", 							CVAR_FLAGS);

	g_hBleedDamagePerTick = 	CreateConVar("sm_bleed_dmg_per_tick", 		"5", 		"How much damage the victim receive each bleed tick.", 											CVAR_FLAGS);
	g_hBleedDuration = 			CreateConVar("sm_bleed_duration", 			"3", 		"How low the victim bleeds for. (in seconds)", 													CVAR_FLAGS);
	g_hBleedSlowMultiplier = 	CreateConVar("sm_bleed_slow_mult", 			"0.9", 		"The victim when bleeding will be slowed down to this much. (0.0 - 1.0)", 						CVAR_FLAGS);

	g_hBleedDamagePerTick_ff = 	CreateConVar("sm_bleed_dmg_per_tick_ff",	"2", 		"How much damage the victim (friendly survior) receive each bleed tick.", 						CVAR_FLAGS);
	g_hBleedDDuration_ff = 		CreateConVar("sm_bleed_duration_ff", 		"1.5", 		"How low the victim (friendly survior) bleeds for. (in seconds)", 								CVAR_FLAGS);
	g_hBleedSlowMultiplier_ff = CreateConVar("sm_bleed_slow_mult_ff", 		"0.95", 	"The victim (friendly survior) when bleeding will be slowed down to this much. (0.0 - 1.0)", 	CVAR_FLAGS);

	g_hBleedChance.AddChangeHook(ConVarChanged_Cvars);
	g_hBleedTickInterval.AddChangeHook(ConVarChanged_Cvars);
	g_hBleedDamagePerTick.AddChangeHook(ConVarChanged_Cvars);
	g_hBleedDuration.AddChangeHook(ConVarChanged_Cvars);
	g_hBleedSlowMultiplier.AddChangeHook(ConVarChanged_Cvars);
	g_hBleedDamagePerTick_ff.AddChangeHook(ConVarChanged_Cvars);
	g_hBleedDDuration_ff.AddChangeHook(ConVarChanged_Cvars);
	g_hBleedSlowMultiplier_ff.AddChangeHook(ConVarChanged_Cvars);

	AutoExecConfig(true, "l4d2_sharp_melee_bleeding");

	HookEvent("player_hurt", 	Event_PlayerHurt, 	EventHookMode_Post);
	HookEvent("infected_hurt", 	Event_InfectedHurt, EventHookMode_Post);
}

void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{ 
	GetCvars(); 
}

void GetCvars()
{
	g_fBleedChance 				= g_hBleedChance.FloatValue;
	g_fBleedTickInterval 		= g_hBleedTickInterval.FloatValue;
	g_fBleedDamagePerTick 		= g_hBleedDamagePerTick.FloatValue;
	g_fBleedDuration 			= g_hBleedDuration.FloatValue;
	g_fBleedSlowMultiplier 		= g_hBleedSlowMultiplier.FloatValue;
	g_fBleedDamagePerTick_ff 	= g_hBleedDamagePerTick_ff.FloatValue;
	g_fBleedDDuration_ff 		= g_hBleedDDuration_ff.FloatValue;
	g_fBleedSlowMultiplier_ff 	= g_hBleedSlowMultiplier_ff.FloatValue;
}

public void OnConfigsExecuted()
{
    GetCvars();
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int victim = EntIndexToEntRef(GetEventInt(event, "userid"));
	if (victim)
	{
		int hp = GetEntProp(victim, Prop_Data, "m_iHealth");
		if (hp <= 0) return;

		char weapon[10];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		if (StrEqual(weapon, "melee") && (GetEventInt(event, "type") & 4))
		{
			PrintToChatAll("StartBleeding");
			// Start bleeding
		}
	}
}

void Event_InfectedHurt(Event event, const char[] name, bool dontBroadcast)
{
	int victim = EntIndexToEntRef(GetEventInt(event, "entityid"));

	static char classname[20];
	GetEdictClassname(victim, classname, sizeof(classname));

	if (victim && strcmp(classname, "witch") == 0)
	{
		int hp = GetEntProp(victim, Prop_Data, "m_iHealth");
		if (hp <= 0) return;

		char weapon[10];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		if (StrEqual(weapon, "melee") && (GetEventInt(event, "type") & 4))
		{
			PrintToChatAll("StartBleeding");
			// Start bleeding
		}
	}
}