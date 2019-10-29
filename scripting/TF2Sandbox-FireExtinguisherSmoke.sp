#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BattlefieldDuck"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] Sandbox - Fire Extinguisher Smoke",
	author = PLUGIN_AUTHOR,
	description = "Pressure the Fire Extinguisher - SMOKE!",
	version = PLUGIN_VERSION,
	url = "https://tf2sandbox.tatlead.com/"
};

#define MODEL_EXTINGUISHER "models/props_2fort/fire_extinguisher.mdl"
#define MATERIAL_SMOKE "particle/particle_smokegrenade1.vmt"
#define SOUND_SMOKE "ambient/gas/steam2.wav"

Handle g_hSyncPreBar;
Handle g_hSyncHudBox;

ConVar g_TraceDistance;
ConVar g_CoolDown;

public void OnPluginStart()
{
	CreateConVar("sm_tf2sb_extinguisher_version", PLUGIN_VERSION, "", FCVAR_SPONLY | FCVAR_NOTIFY);
	
	g_TraceDistance = CreateConVar("sm_tf2sb_extinguisher_distance", "250", "(100 - 500) Set the tracable distance between the client and extinguisher.", 0, true, 100.0, true, 500.0);
	g_CoolDown = CreateConVar("sm_tf2sb_extinguisher_cooldown", "5.0", "(5.0 - 30.0) Set the cooldown of extinguisher explosion.", 0, true, 5.0, true, 30.0);
	
	g_hSyncPreBar = CreateHudSynchronizer();
	g_hSyncHudBox = CreateHudSynchronizer();
}

public void OnMapStart()
{
	PrecacheSound(SOUND_SMOKE);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrContains(classname, "prop_dynamic") != -1)
	{
		SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawned);
	}
}

public void OnEntitySpawned(int entity)
{
	char strModelName[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", strModelName, sizeof(strModelName));
	
	if (StrEqual(strModelName, MODEL_EXTINGUISHER))
	{
		//Set initial pressure
		SetPressureBySequence(entity, 0);
		
		SetEntityRenderColor(entity, _, _, _, 255);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	//Return if player is not alive
	if (!IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}
	
	//Return if the aiming entity is invalid
	int entity = GetClientAimTarget(client, false);
	if(!IsValidEntity(entity))
	{
		return Plugin_Continue;
	}
	
	//Return if the aiming entity is not canister
	char strModelName[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", strModelName, sizeof(strModelName));
	if (!StrEqual(strModelName, MODEL_EXTINGUISHER))
	{
		return Plugin_Continue;
	}
	
	//Return if the canister is grabbed by physgun
	float entityVecOrigin[3], clientVecOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityVecOrigin);
	if (entityVecOrigin[0] == 0.0 && entityVecOrigin[1] == 0.0 && entityVecOrigin[2] == 0.0)
	{
		return Plugin_Continue;
	}
	
	//Return if the canister is not within the distance
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", clientVecOrigin);
	if (GetVectorDistance(entityVecOrigin, clientVecOrigin) > g_TraceDistance.FloatValue)
	{
		return Plugin_Continue;
	}
	
	//Return if the canister is cooling down
	int alpha;
	GetEntityRenderColor(entity, alpha, alpha, alpha, alpha);
	if (alpha != 255)
	{
		return Plugin_Continue;
	}
	
	int pressure = GetPressureBySequence(entity);
	
	SetHudTextParams(-1.0, 0.25, 0.05, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
	ShowSyncHudText(client, g_hSyncHudBox, "Pressure\n[                 ]");
	SetHudTextParams(-1.0, 0.2871, 0.05, (pressure > 75) ? 255 : 0, (pressure > 75) ? 0 : 255, (pressure > 75) ? 0 : 128, 255, 0, 0.0, 0.0, 0.0);
	ShowSyncHudText(client, g_hSyncPreBar, "%s\n \nHold Mouse3 to add pressure", GetPressureBar(pressure));
	
	if (buttons & IN_ATTACK3)
	{
		//Increase the pressure
		SetPressureBySequence(entity, ++pressure);
		
		if (pressure >= 100)
		{
			//Reset Pressure
			SetPressureBySequence(entity, 0);
			
			SetEntityRenderColor(entity, _, _, _, 100);
			
			CreateSmoke(entity);
			
			int clients[MAXPLAYERS], numClients;
			numClients = GetClientsInRange(entityVecOrigin, RangeType_Audibility, clients, sizeof(clients));
			
			EmitSound(clients, numClients, SOUND_SMOKE, entity, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, SNDPITCH_NORMAL, 0, NULL_VECTOR, NULL_VECTOR, true, g_CoolDown.FloatValue);
			
			CreateTimer(g_CoolDown.FloatValue, Timer_StopExtinguisherSound, EntIndexToEntRef(entity));
		}
	}
	
	return Plugin_Continue;
}

void CreateSmoke(int extinguisher)
{
	int Smoke = CreateEntityByName("env_smokestack");
	
	float entityVecOrigin[3];
	GetEntPropVector(extinguisher, Prop_Send, "m_vecOrigin", entityVecOrigin);
	
	char Origin[64];
	Format(Origin, sizeof(Origin), "%f %f %f", entityVecOrigin[0], entityVecOrigin[1], entityVecOrigin[2]);
	
	if(IsValidEntity(Smoke))
	{
		char targetname[128];
		Format(targetname, sizeof(targetname), "Smoke%i", extinguisher);
		DispatchKeyValue(Smoke,"targetname", targetname);
		DispatchKeyValue(Smoke,"Origin", Origin);
		DispatchKeyValue(Smoke,"BaseSpread", "100");
		DispatchKeyValue(Smoke,"SpreadSpeed", "70");
		DispatchKeyValue(Smoke,"Speed", "80");
		DispatchKeyValue(Smoke,"StartSize", "200");
		DispatchKeyValue(Smoke,"EndSize", "2");
		DispatchKeyValue(Smoke,"Rate", "30");
		DispatchKeyValue(Smoke,"JetLength", "400");
		DispatchKeyValue(Smoke,"Twist", "20"); 
		DispatchKeyValue(Smoke,"RenderColor", "255 255 255");
		DispatchKeyValue(Smoke,"RenderAmt", "255");
		DispatchKeyValue(Smoke,"SmokeMaterial", MATERIAL_SMOKE);
		
		DispatchSpawn(Smoke);
		AcceptEntityInput(Smoke, "TurnOn");
		
		CreateTimer(g_CoolDown.FloatValue, Timer_StopSmokePost, EntIndexToEntRef(Smoke));
	}
}

public Action Timer_StopSmokePost(Handle timer, int smokeRef)
{
	int smoke = EntRefToEntIndex(smokeRef);
	
	if(smoke != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(smoke, "TurnOff");
		
		CreateTimer(5.0, Timer_KillSmokePost, EntIndexToEntRef(smoke));
	}
}

public Action Timer_KillSmokePost(Handle timer, int smokeRef)
{
	int smoke = EntRefToEntIndex(smokeRef);
	
	if(smoke != INVALID_ENT_REFERENCE)
	{	
		AcceptEntityInput(smoke, "Kill");
	}
}

public Action Timer_StopExtinguisherSound(Handle timer, int entityRef)
{
	int entity = EntRefToEntIndex(entityRef);
	
	if(entity != INVALID_ENT_REFERENCE)
	{
		StopSound(entity, SNDCHAN_AUTO, SOUND_SMOKE);
		
		CreateTimer(5.0, Timer_ResetExtinguisher, EntIndexToEntRef(entity));
	}
}

public Action Timer_ResetExtinguisher(Handle timer, int entityRef)
{
	int entity = EntRefToEntIndex(entityRef);
	
	if(entity != INVALID_ENT_REFERENCE)
	{
		SetEntityRenderColor(entity, _, _, _, 255);
	}
}

char[] GetPressureBar(int pressure)
{
	int barCount = RoundFloat(float(pressure) / 10.0);
	
	char strPressureBar[11] = "";
	while (barCount--)
	{
		Format(strPressureBar, sizeof(strPressureBar), "%s|", strPressureBar);
	}
	
	return strPressureBar;
}

int GetPressureBySequence(int entity)
{
	int sequence = GetEntProp(entity, Prop_Send, "m_nSequence");
	return (sequence < 0) ? 0 : RoundFloat(FloatAbs(float(sequence)));
}

int SetPressureBySequence(int entity, int pressure)
{
	SetEntProp(entity, Prop_Send, "m_nSequence", pressure);
}
