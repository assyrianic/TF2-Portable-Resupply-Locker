#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
//#undef REQUIRE_PLUGIN
//#tryinclude <updater>

#pragma semicolon			1
#pragma newdecls			required

#define PLUGIN_VERSION			"1.0"

public Plugin myinfo = {
	name 				= "Custom Structures",
	author 				= "nergal/assyrian",
	description 			= "Allows Players to take their resupply lockers with them anywhere!",
	version 			= PLUGIN_VERSION,
	url 				= "hue"
};

//defines
#define PLYR				MAXPLAYERS+1
#define nullvec				NULL_VECTOR
#define int(%1)				view_as<int>(%1)
//#define int(%1)			Roundreal(%1)
#define bool(%1)			view_as<bool>(%1)

#define real				float

#define COOLDOWN			30.0
#define ARENAMODE			true
#define ALLORNONE			true

//cvar handles
ConVar
	bEnabled = null,
	AllowBlu = null,
	AllowRed = null
;


int
	Locker[PLYR],
	iRedResuppliesBuilt = 0,
	iBluResuppliesBuilt = 0
;

real
	Timer[PLYR]
;

methodmap MConstruct
{
	public MConstruct (const int ind, bool uid = false) {
		if (uid) {
			return view_as<MConstruct>( ind );
		}
		return view_as<MConstruct>( GetClientUserId(ind) );
	}

	property int userid {
		public get()				{ return int(this); }
	}
	property int index {
		public get()				{ return GetClientOfUserId( this.userid ); }
	}

	property int iBase
	{
		public get()				{ return Locker [ this.index ] ; }
		public set( const int val )		{ Locker [ this.index ] = val ; }
	}
	property real flTimer
	{
		public get()				{ return Timer [ this.index ] ; }
		public set( const real val )		{ Timer [ this.index ] = val ; }
	}

	public void Resupply (const real cooldown) {
		if ( IsValidClient(this.index) && IsPlayerAlive(this.index) )
		{
			bool bArena = ARENAMODE;
			bool bAllOrNone = ALLORNONE;
			if (bArena)
				TF2_RegeneratePlayer(this.index);
			else SetEntityHealth( this.index, GetEntProp(this.index, Prop_Data, "m_iMaxHealth") );

			PrecacheSound("items/regenerate.wav", true);
			EmitSoundToClient(this.index, "items/regenerate.wav");
			if (bAllOrNone) {
				MConstruct player; float currtime = GetGameTime();
				for (int i=MaxClients; i ; i--) {
					if ( !IsValidClient(i) )
						continue;

					player = MConstruct(i);
					if (GetClientTeam(player.index) == GetClientTeam(this.index))
						player.flTimer = currtime+cooldown;
				}
			}
			else this.flTimer = GetGameTime()+cooldown;
		}
		return;
	}
}


public void OnPluginStart ()
{
	bEnabled = CreateConVar("sm_structures_enabled", "1", "Enable Structures plugin", FCVAR_NONE, true, 0.0, true, 1.0);
	AllowBlu = CreateConVar("sm_structures_blu", "1", "(Dis)Allow Structures for BLU team", FCVAR_NONE|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	AllowRed = CreateConVar("sm_structures_red", "1", "(Dis)Allow Structures for RED team", FCVAR_NONE|FCVAR_NOTIFY, true, 0.0, true, 1.0);

	//AddCommandListener(Listener_Voice, "voicemenu");
	//RegAdminCmd("sm_portableresupply", CreatePortableResupply, ADMFLAG_KICK);

	RegConsoleCmd ("sm_resupply", CommandBuildings);

	for ( int i=MaxClients; i;--i ) {
		if ( !IsValidClient (i) )
			continue;
		OnClientPutInServer (i);
	}
}

public void OnClientPutInServer (int client)
{
	MConstruct player = MConstruct(client);
	player.iBase = -1;
}
public void OnClientDisconnect (int client)
{
	MConstruct player = MConstruct(client);
	if ( player.iBase != -1 && IsValidEdict (player.iBase) )
	{
		CreateTimer ( 0.1, RemoveEnt, player.iBase );
		player.iBase = -1;
	}
}
public void OnMapStart ()
{
	char extensions[][] = { ".mdl", ".dx80.vtx", ".dx90.vtx", ".sw.vtx", ".vvd", ".phy" };
	char extensionsb[][] = { ".vtf", ".vmt" };
	char s[PLATFORM_MAX_PATH];
	int i, size;
	for ( i = 0, size = sizeof(extensions) ; i < size ; ++i )
	{
		//Format(s, PLATFORM_MAX_PATH, "models/mrmof/sandbags01%s", extensions[i]);
		//CheckDownload (s);
	}
	for ( i = 0, size = sizeof(extensionsb) ; i < size ; ++i )
	{
		//Format(s, PLATFORM_MAX_PATH, "materials/models/mrmof/sandbags01%s", extensionsb[i]);
		//CheckDownload (s);
	}
}
public Action CommandBuildings (int client, int args)
{
	if ( !bEnabled.BoolValue )
		return Plugin_Handled;

	int team = GetClientTeam (client);
	if ( (!AllowBlu.BoolValue && (team == 3)) || (!AllowRed.BoolValue && (team == 2)) )
		return Plugin_Handled;

	GetBuilding(client);
	return Plugin_Handled;
}

public void GetBuilding ( const int client )
{
	if ( !IsValidClient (client) || !IsPlayerAlive (client) )
		return ;
	if ( (iRedResuppliesBuilt > 0 && GetClientTeam(client) == 2) || (iBluResuppliesBuilt > 0 && GetClientTeam(client) == 3) )
		return;

	MConstruct player = MConstruct(client);

	real flEyePos[3], flAng[3];
	GetClientEyePosition (client, flEyePos);
	GetClientEyeAngles (client, flAng);

	TR_TraceRayFilter ( flEyePos, flAng, MASK_PLAYERSOLID, RayType_Infinite, TraceFilterIgnorePlayers, client );

	if ( TR_GetFraction() < 1.0 ) {
		real flEndPos[3]; TR_GetEndPosition (flEndPos);

		GetClientAbsAngles (client, flAng); flAng[1] += 90.0;

		int pStruct = CreateEntityByName ("prop_dynamic_override");
		if ( pStruct <= 0 || !IsValidEdict (pStruct) )
			return;

		char szModelPath[] = "models/props_medieval/medieval_resupply.mdl";
		SetEntProp ( pStruct, Prop_Send, "m_iTeamNum", GetClientTeam(client) );

		PrecacheModel (szModelPath, true);
		SetEntityModel (pStruct, szModelPath);

		real mins[3], maxs[3];
		GetEntPropVector (pStruct, Prop_Send, "m_vecMins", mins );
		GetEntPropVector (pStruct, Prop_Send, "m_vecMaxs", maxs );

		if ( CanBuildHere (flEndPos, mins, maxs) )
		{
			DispatchSpawn (pStruct);
			SetEntProp ( pStruct, Prop_Send, "m_nSolidType", 6 );

			TeleportEntity (pStruct, flEndPos, flAng, nullvec);

			int beamcolor[4] = {0, 255, 90, 255};

			real vecMins[3], vecMaxs[3];
			GetEntPropVector (pStruct, Prop_Send, "m_vecMins", mins );
			GetEntPropVector (pStruct, Prop_Send, "m_vecMaxs", maxs );
			AddVectors (flEndPos, mins, vecMins);
			AddVectors (flEndPos, maxs, vecMaxs);
			TE_SendBeamBoxToAll ( vecMaxs, vecMins, PrecacheModel("sprites/laser.vmt", true), PrecacheModel("sprites/laser.vmt", true), 1, 1, 5.0, 8.0, 8.0, 5, 2.0, beamcolor, 0 );

			SetEntProp (pStruct, Prop_Data, "m_takedamage", 2, 1);
			SetEntProp (pStruct, Prop_Data, "m_iHealth", 200);

			if ( IsValidEntity (pStruct) && IsValidEdict (pStruct) )
			{
				if ( player.iBase != -1 ) {
					CreateTimer ( 0.1, RemoveEnt, player.iBase );
					player.iBase = -1;
					switch (GetClientTeam(client))
					{
						case 2: iRedResuppliesBuilt--;
						case 3: iBluResuppliesBuilt--;
					}
				}
				player.iBase = EntIndexToEntRef(pStruct);
				PrintStructureSize (client, pStruct);
				switch (GetClientTeam(client))
				{
					case 2:
					{
						CreateTimer(0.0, RedResupplyThink, EntIndexToEntRef(pStruct), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
						iRedResuppliesBuilt++;
					}
					case 3:
					{
						CreateTimer(0.0, BluResupplyThink, EntIndexToEntRef(pStruct), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
						iBluResuppliesBuilt++;
					}
				}
			}
		}
		else {
			PrintToChat (client, "Can't build structure there");
			CreateTimer ( 0.1, RemoveEnt, EntIndexToEntRef(pStruct) );
			switch (GetClientTeam(client))
			{
				case 2: iRedResuppliesBuilt--;
				case 3: iBluResuppliesBuilt--;
			}
		}
	}
	return ;
}

public Action RedResupplyThink (Handle timer, any entid)
{
	int pEnt = EntRefToEntIndex(entid) ;
	if ( !pEnt || !IsValidEntity(pEnt) ) {
		iRedResuppliesBuilt--;
		return Plugin_Stop;
	}
	MConstruct user;
	for (int i=MaxClients; i; --i) {
		if ( !IsValidClient(i) )
			continue;
		if ( !AllowRed.BoolValue && GetClientTeam(i) == 2 )
			continue;

		if ( GetEntProp ( pEnt, Prop_Send, "m_iTeamNum" ) != 2 )
			continue;

		user = MConstruct(i);
		if ( IsInRange(i, pEnt, 50.0, false) && user.flTimer <= GetGameTime() )
		{
			SetVariantString("open");
			AcceptEntityInput(pEnt, "SetAnimation");
			user.Resupply(COOLDOWN);
		}
		else {
			SetVariantString("close");
			AcceptEntityInput(pEnt, "SetAnimation");
		}
	}
	return Plugin_Continue;
}

public Action BluResupplyThink (Handle timer, any entid)
{
	int pEnt = EntRefToEntIndex(entid) ;
	if ( !pEnt || !IsValidEntity(pEnt) ) {
		iBluResuppliesBuilt--;
		return Plugin_Stop;
	}
	MConstruct user;
	for (int i=MaxClients; i; --i) {
		if ( !IsValidClient(i) )
			continue;
		if ( !AllowBlu.BoolValue && GetClientTeam(i) == 3 )
			continue;

		if ( GetEntProp ( pEnt, Prop_Send, "m_iTeamNum" ) != 3 )
			continue;

		user = MConstruct(i);
		if ( IsInRange(i, pEnt, 50.0, false) && user.flTimer <= GetGameTime() )
		{
			SetVariantString("open");
			AcceptEntityInput(pEnt, "SetAnimation");
			user.Resupply(COOLDOWN);
		}
		else {
			SetVariantString("close");
			AcceptEntityInput(pEnt, "SetAnimation");
		}
	}
	return Plugin_Continue;
}

//stocks
stock void PrintStructureSize (const int pOwner, const int pEnt)
{
	if ( pEnt <= 0 || !IsValidEdict(pEnt) )
		return;
	else if ( pOwner <= 0 || !IsValidClient(pOwner) )
		return;

	real mins[3], maxs[3];

	GetEntPropVector(pEnt, Prop_Send, "m_vecMins", mins );
	GetEntPropVector(pEnt, Prop_Send, "m_vecMaxs", maxs );
	PrintToConsole(pOwner, "Bridge Vec Mins %f x, %f y, %f z", mins[0], mins[1], mins[2]);
	PrintToConsole(pOwner, "Bridge Vec Maxs %f x, %f y, %f z", maxs[0], maxs[1], maxs[2]);
}
stock bool IsInRange ( const int pEnt, const int pTarget, const real dist, bool pTrace )
{
	real entitypos[3]; GetEntPropVector(pEnt, Prop_Data, "m_vecAbsOrigin", entitypos);
	real targetpos[3]; GetEntPropVector(pTarget, Prop_Data, "m_vecAbsOrigin", targetpos);

	if ( GetVectorDistance(entitypos, targetpos) <= dist )
	{
		if (!pTrace)
			return true;
		else {
			TR_TraceRayFilter( entitypos, targetpos, MASK_SHOT, RayType_EndPoint, TraceRayDontHitSelf, pEnt );
			if ( TR_GetFraction() > 0.98 ) return true;
			//if ( TR_DidHit() && TR_GetEntityIndex() == target ) return true;
		}
	}
	return false;
}
public bool TraceRayDontHitSelf (int entity, int contentsMask, any data)
{
	return ( entity != data ) ;
}
stock bool CanBuildHere (real flPos[3], const real flMins[3], const real flMaxs[3])
{
	bool bSuccess = false;
	for ( int i=8 ; i; --i )
	{
		TR_TraceHull ( flPos, flPos, flMins, flMaxs, MASK_PLAYERSOLID );
		if ( TR_GetFraction() > 0.98 )
			bSuccess = true;
		else flPos[2] += 2.0;
	}
	return bSuccess;
}
public bool TraceFilterIgnorePlayers(int entity, int contentsMask, any client)
{
	return ( !(entity > 0 && entity <= MaxClients) );
}
public Action RemoveEnt (Handle timer, any entid)
{
	int entity = EntRefToEntIndex(entid);
	if ( entity > 0 && IsValidEntity(entity) )
		AcceptEntityInput(entity, "Kill");
	return Plugin_Continue;
}
stock void CheckDownload (const char[] dlpath)
{
	if ( FileExists(dlpath) )
		AddFileToDownloadsTable(dlpath);
}
stock real Vector2DLength ( const real vec[2] )
{
	return SquareRoot( vec[0]*vec[0] + vec[1]*vec[1] );		
}
stock real fMax (real& a, real& b) { return (a > b) ? a : b; }
stock real fMin (real& a, real& b) { return (a < b) ? a : b; }

stock void TE_SendBeamBoxToAll (const real upc[3], const real btc[3], int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, const real Life, const real Width, const real EndWidth, int FadeLength, const real Amplitude, const int Color[4], const int Speed)
{
	// Create the additional corners of the box
	real tc1[] = {0.0, 0.0, 0.0};
	real tc2[] = {0.0, 0.0, 0.0};
	real tc3[] = {0.0, 0.0, 0.0};
	real tc4[] = {0.0, 0.0, 0.0};
	real tc5[] = {0.0, 0.0, 0.0};
	real tc6[] = {0.0, 0.0, 0.0};

	AddVectors(tc1, upc, tc1);
	AddVectors(tc2, upc, tc2);
	AddVectors(tc3, upc, tc3);
	AddVectors(tc4, btc, tc4);
	AddVectors(tc5, btc, tc5);
	AddVectors(tc6, btc, tc6);

	tc1[0] = btc[0];
	tc2[1] = btc[1];
	tc3[2] = btc[2];
	tc4[0] = upc[0];
	tc5[1] = upc[1];
	tc6[2] = upc[2];

	// Draw all the edges
	TE_SetupBeamPoints(upc, tc1, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(upc, tc2, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(upc, tc3, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc6, tc1, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc6, tc2, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc6, btc, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc4, btc, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc5, btc, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc5, tc1, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc5, tc3, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc4, tc3, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc4, tc2, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
}


stock bool IsValidClient (const int iClient, bool bReplay = true)
{
	if (iClient <= 0 || iClient > MaxClients)
		return false;
	if ( !IsClientInGame(iClient) )
		return false;
	if ( bReplay && (IsClientSourceTV(iClient) || IsClientReplay(iClient)) )
		return false;
	return true;
}
