#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "UnityLightingCommon.cginc"

uniform sampler2D Ct_Control; // b = height
uniform sampler2D Ct_Control_Previous;
uniform sampler2D _Ct_Normal;

uniform float4 Ct_Control_TexelSize;
uniform float4 Ct_Pos;
uniform float4 Ct_Pos_Bake;
uniform float4 Ct_Size; // x=size, y=1/size
uniform float4 Ct_Size_Bake;
uniform float4 Ct_HeightRange;//_minHeight, _maxHeight, _maxHeight - _minHeight, 0
uniform float4 Ct_TerrainDefault;
uniform float4 Ct_WaterLevel;


UNITY_DECLARE_TEX2DARRAY(civ_Albedo_Arr);
UNITY_DECLARE_TEX2DARRAY(civ_Normal_Arr);
UNITY_DECLARE_TEX2DARRAY(civ_MOHS_Arr);

#define TRANSFER_WTANGENT(o) o.wTangent.xyz = UnityObjectToWorldDir(v.tangent.xyz); o.wTangent.w = v.tangent.w * unity_WorldTransformParams.w;


float GetAlphaToHideForUvBorders(float2 uv) 
{
	float2 offUv = uv - 0.5;
	offUv *= offUv;
	float len = offUv.x*offUv.x + offUv.y*offUv.y;
	return smoothstep(0.0625, 0.04, len);
}

float3 GetSpecular(float3 normal, float3 viewDir, float4 mads)
{
	float ao = mads.g;
	float fresnel = 1 - max(0, dot(normal, viewDir));

	return fresnel * ao * mads.a * 0.2;
}


float GetAttenuation(float3 normal, float ao)
{
	float angle = max(0, dot(_WorldSpaceLightPos0.xyz, normal));

	angle = 1-pow(1-angle,1 + (1-ao) * 3);

	return  angle;
}


void ApplyLight(inout float3 col, float3 normal, float4 mads, float shadow) 
{
    float toLight = GetAttenuation(normal,  mads.g);

    float isUp = smoothstep(0,1, normal.y);
    col.rgb = col * (_LightColor0.rgb *  (toLight * shadow + 0.5 * mads.g)
	); 
}

void ApplyTangent (inout float3 normal, float3 tnormal, float4 wTangent)
{
	float3 wBitangent = cross(normal, wTangent.xyz) * wTangent.w;

	float3 tspace0 = float3(wTangent.x, wBitangent.x, normal.x);
	float3 tspace1 = float3(wTangent.y, wBitangent.y, normal.y);
	float3 tspace2 = float3(wTangent.z, wBitangent.z, normal.z);																												

	normal.x = dot(tspace0, tnormal);
	normal.y = dot(tspace1, tnormal);
	normal.z = dot(tspace2, tnormal);

	normal = normalize(normal);
}

float2 WorldPosToTerrainUV(float3 worldPos)
{
	return (worldPos.xz - Ct_Pos.xz) * Ct_Size.y + 0.5;
}

float2 WorldPosToTerrainUV_Baking(float3 worldPos)
{
	return (worldPos.xz - Ct_Pos_Bake.xz) * Ct_Size_Bake.y + 0.5;
}

float gyroid(float3 pos) 
{
    return abs(dot(sin(pos), cos(pos.zxy)));
}


float4 Ct_SampleTerrain(float3 worldPos)
{
	float2 uv = WorldPosToTerrainUV(worldPos);
	float4 control = tex2Dlod(Ct_Control, float4(uv,0,0));

	float alpha = GetAlphaToHideForUvBorders(uv);
	control = lerp (float4(0,0,0,0), control, alpha);
	return control;
}

float GetTerrainHeight(float4 terrainControl)
{
	return Ct_HeightRange.x + terrainControl.a * Ct_HeightRange.z;
}


void ApplyRefraction(inout float3 worldPos, float3 viewDir)
{
	float4 control = Ct_SampleTerrain(worldPos);

	float height = GetTerrainHeight(control);

	 float isUnderwater = smoothstep(0, -1,height);

	 float3 gyrPos = worldPos;
	float gyr = gyroid(float3(gyrPos.x, height + _Time.y, gyrPos.z));

	worldPos += 0.1 * gyr * viewDir * isUnderwater * height;

	//worldPos.xz += gyr *gyr * 0.01 * gyrPos.y * isUnderwater;
}

void ApplyWater(float3 worldPos, inout float3 col, inout float3 normal, inout float4 mads, out float foam)
{
	worldPos.y += (mads.b - 0.5)*0.25;

	float isWet = smoothstep(0.2, 0.1, worldPos.y);

	float isWater = smoothstep(0, -0.5, worldPos.y);
	isWet*= (1-isWater);

	float isDeep = smoothstep(0, -10, worldPos.y) * 0.5;

	float3 gyrPos = (worldPos + _Time.x)*0.1 ;
	float gyr = gyroid(float3(gyrPos.x, gyrPos.y*3 + _Time.x*0.2, gyrPos.z));

	col *= (1-isWet*0.5); 

	float foamUp = (sin(worldPos.y*20 - _Time.w ) + 1) * 0.5; 
	float foamDown = (cos(worldPos.y*20 + _Time.w*0.2 ) + 1 ) * 0.5; 

	foam = lerp(foamUp, foamDown, saturate(gyr));

	foam *= smoothstep(0.2, 0, abs(worldPos.y));

	col = lerp(col, float4(0.2,0.3,1,0), isDeep);
    normal = lerp(normal, float3(0,1,0), isWater);
    mads = lerp(mads, float4(0,1,1,1), isWater);
	
}

inline void ApplyFoam(inout float3 col, float4 mads, float foam)
{
	col = lerp(col, 0.9, saturate(foam*4 - 2) * 0.5);
}

inline float MergeLayer(inout float3 col, inout float3 bump, inout float4 mads, inout float currentHeight, int index, float2 uv, float control)
{
	float4 mads_B =UNITY_SAMPLE_TEX2DARRAY(civ_MOHS_Arr, float3(uv.xy, index));

	float transition = saturate((control * 2 + mads_B.b - currentHeight - mads.b) * 20);
	mads = lerp (mads, mads_B, transition);

	currentHeight = max(currentHeight, control);

	float3 col_B = UNITY_SAMPLE_TEX2DARRAY(civ_Albedo_Arr, float3(uv.xy, index));//tex2D(civ_Albedo_Hill, uv);
	col = lerp(col, col_B, transition);
	float3 bump_B = UnpackNormal(UNITY_SAMPLE_TEX2DARRAY(civ_Normal_Arr, float3(uv.xy, index)));
	bump = lerp(bump, bump_B, transition);

	return transition;
}

float3 GetTerrainBlend(float3 worldPos, float4 control, out float4 mads, inout float3 normal)
{
	float2 uv = worldPos.xz * 0.1;

	float3 col = UNITY_SAMPLE_TEX2DARRAY(civ_Albedo_Arr, float3(uv.xy, 0)); 
	mads = UNITY_SAMPLE_TEX2DARRAY(civ_MOHS_Arr, float3(uv.xy, 0));
	float3 bump = UnpackNormal(UNITY_SAMPLE_TEX2DARRAY(civ_Normal_Arr, float3(uv.xy, 0))); 
	//mads.b *= smoothstep(0.01, 0, control.r * control.g + control.r * control.b + control.g * control.b); // To prevent default layer show up in seams
	
	float currentHeight = 0.25 * smoothstep(0.1, 0, control.r * control.g + control.r * control.b + control.g * control.b);

	MergeLayer(col, bump, mads, currentHeight, 1, uv, control.r);
	MergeLayer(col, bump, mads, currentHeight, 2, uv, control.g);
	MergeLayer(col, bump, mads, currentHeight, 3, uv, control.b);

	bump = bump.xzy;

	normal = normalize(lerp(normal,  bump, 0.5));

	return col;
}

float4 Ct_SampleTerrainPrevious(float3 worldPos)
{
	float2 uv = WorldPosToTerrainUV_Baking(worldPos);
	return tex2Dlod(Ct_Control_Previous, float4(uv,0,0));
}


float4 Ct_SampleTerrainAndNormal(float3 worldPos, out float3 normal)
{
	float2 uv = WorldPosToTerrainUV(worldPos);
	float4 control = tex2Dlod(Ct_Control, float4(uv,0,0));
	float alpha = GetAlphaToHideForUvBorders(uv);
	control = lerp ( float4(0,0,0,0), control,alpha);

	float4 bumpAndSdf = tex2Dlod(_Ct_Normal, float4(uv,0,0));
	normal = bumpAndSdf.xyz;
	normal = lerp(float3(0,1,0), normal, alpha);
	float sdf = bumpAndSdf.a;

	return control;
}


//Ct_HeightRange  _minHeight, _maxHeight, _maxHeight - _minHeight, 0


float HeightToColor(float height)
{
	return saturate((height - Ct_HeightRange.x) /  Ct_HeightRange.z);

}

float3 SampleTerrainPosition(float3 worldPos)
{
    float4 terrain = Ct_SampleTerrain(worldPos);
    worldPos.y = GetTerrainHeight(terrain);
    return worldPos;
}

