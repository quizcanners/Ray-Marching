#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "UnityLightingCommon.cginc"
#include "Qc_Common.cginc"

uniform sampler2D Ct_Control; // b = height
uniform sampler2D Ct_Control_Previous;
uniform float4 Ct_Control_TexelSize;

uniform sampler2D _Ct_Normal;

uniform float4 Ct_Pos;
uniform float4 Ct_Pos_Bake;
uniform float4 Ct_Size; // x=size, y=1/size
uniform float4 Ct_Size_Bake;

uniform float4 Ct_TerrainSettings;
uniform float4 Ct_TerrainDefault;

UNITY_DECLARE_TEX2DARRAY(civ_Albedo_Arr);
UNITY_DECLARE_TEX2DARRAY(civ_Normal_Arr);
UNITY_DECLARE_TEX2DARRAY(civ_MOHS_Arr);

uniform float4 Ct_LayersTiling;
uniform float4 Ct_LayersNormals;
uniform float4 Ct_LayersHeightMod;
uniform float4 Ct_LayersRotation;

uniform float Ct_WaterGyroidNoise;
uniform float Ct_WaterGyroidHeight;

uniform float Ct_WetnessHeight;
uniform float Ct_WetnessGloss;

uniform sampler2D Ct_Cliff_Albedo;
uniform sampler2D Ct_Cliff_Normal;
uniform sampler2D Ct_Cliff_MOHS;
uniform float4 Ct_CliffTiling;


void SampleCliff(float2 uv, out float3 albedo, out float3 normal, out float4 mohs)
{
	uv *= Ct_CliffTiling.x;
	albedo = tex2D(Ct_Cliff_Albedo, uv);
	normal = UnpackNormal(tex2D(Ct_Cliff_Normal, uv));
	mohs = tex2D(Ct_Cliff_MOHS, uv);
}

void TriplanarSampleLayer(float isFar01, float2 uv, out float3 albedo, out float3 normal, out float4 mohs)
{
	float3 albedoNear;
	float3 normalNear;
	float4 mohsNear;
	SampleCliff(uv, albedoNear, normalNear, mohsNear);


	float2 distantUv = uv * 0.23;
	float3 albedoFar;
	float3 normalFar;
	float4 mohsFar;
	SampleCliff(distantUv, albedoFar, normalFar, mohsFar);

	albedo = lerp(albedoNear, albedoFar, isFar01);
	normal = lerp(normalNear, normalFar, isFar01);
	mohs = lerp(mohsNear, mohsFar, isFar01);
}

void TriplanarCombine(float4 madsA, float4 madsB, float weightB, out float4 mads, out float transition)
{
	float blendA = (madsA.g * madsA.b) * (1-weightB);
	float blendB = (madsB.g * madsB.b) * weightB;

	transition = smoothstep(0, 0.2, blendB - blendA);

	mads = lerp(madsA, madsB, transition);
}

void TriplanarSampling(float3 position, float3 normal, out float3 albedo, out float3 newNormal, out float4 mads)
{
	float3 weights = abs(normal);

	float isFar01 = smoothstep(10, 50, length(_WorldSpaceCameraPos - position));

	float3 cubeUv = Ct_CliffTiling.x * position;
	
	float2 uxX = position.zy;
	float2 uxY = position.xz;
	float2 uxZ = position.xy;

	float3 albedoX; 
	float3 normalX;
	float4 mohsX;
	TriplanarSampleLayer(isFar01, uxX,  albedoX,  normalX,  mohsX);

	float3 albedoZ; 
	float3 normalZ;
	float4 mohsZ;
	TriplanarSampleLayer(isFar01, uxZ,  albedoZ,  normalZ,  mohsZ);

	float transition;
	TriplanarCombine(mohsX, mohsZ, weights.z, mads, transition);

	albedo = lerp(albedoX, albedoZ, transition);
	newNormal = lerp(float3(0, normalX.g, normalX.x), float3(normalZ.r, normalZ.g, 0), transition);



	float3 albedoY; 
	float3 normalY;
	float4 mohsY;
	TriplanarSampleLayer(isFar01, uxY,  albedoY,  normalY,  mohsY);

	TriplanarCombine(mads, mohsY, weights.y, mads, transition);
	albedo = lerp(albedo, albedoY, transition);
	newNormal = lerp(newNormal, float3(normalY.r,0,normalY.g), transition);

}


#define TRANSFER_WTANGENT(o) o.wTangent.xyz = UnityObjectToWorldDir(v.tangent.xyz); o.wTangent.w = v.tangent.w * unity_WorldTransformParams.w;




float GetAlphaToHideForUvBordersTerrain(float2 uv) 
{
	float2 offUv = uv - 0.5;
	offUv *= offUv;
	float len = offUv.x*offUv.x + offUv.y*offUv.y;
	return smoothstep(0.0625, 0.04, len);
}



float2 WorldPosToTerrainUV(float3 worldPos)
{
	return (worldPos.xz - Ct_Pos.xz) * Ct_Size.y + 0.5;
}

float2 WorldPosToTerrainUV_Baking(float3 worldPos)
{
	return (worldPos.xz - Ct_Pos_Bake.xz) * Ct_Size_Bake.y + 0.5;
}


float4 Ct_SampleTerrain(float3 worldPos)
{
	float2 uv = WorldPosToTerrainUV(worldPos);
	float4 control = tex2Dlod(Ct_Control, float4(uv,0,0));

	float alpha = GetAlphaToHideForUvBordersTerrain(uv);
	control = lerp (Ct_TerrainDefault, control, alpha);
	return control;
}

void GetTerrainHeight(float4 terrainControl, out float height)
{
	height = Ct_HeightRange.x + terrainControl.a * Ct_HeightRange.z;
}

void SampleTerrainHeight(float3 worldPos, out float height)
{
	float2 uv = WorldPosToTerrainUV(worldPos);
	float4 control = tex2Dlod(Ct_Control, float4(uv,0,0));

	float alpha = GetAlphaToHideForUvBordersTerrain(uv);

	height = Ct_HeightRange.x + control.a * alpha * Ct_HeightRange.z;
}


inline void ApplySettings(inout float3 bump, inout float4 mads, int index) 
{
	bump.rg *= Ct_LayersNormals[index];
	bump = normalize(bump);
}

inline float MergeLayer(inout float3 col, inout float3 bump, inout float4 mads, inout float currentHeight, int index, float2 uv, float control, float sharpness)
{
	float4 mads_B =UNITY_SAMPLE_TEX2DARRAY(civ_MOHS_Arr, float3(uv.xy, index));

	float coefA = mads.b*mads.g;
	float coefB = mads_B.b*mads_B.g;

	float transition = saturate((control * 2.0 + coefB - currentHeight - coefA) * sharpness);


	currentHeight = max(currentHeight, control);

	float3 col_B = UNITY_SAMPLE_TEX2DARRAY(civ_Albedo_Arr, float3(uv.xy, index));//tex2D(civ_Albedo_Hill, uv);
	col = lerp(col, col_B, transition);
	float3 bump_B = UnpackNormal(UNITY_SAMPLE_TEX2DARRAY(civ_Normal_Arr, float3(uv, index)));
	
	ApplySettings(bump_B, mads_B, index);
	
	mads = lerp(mads, mads_B, transition);
	bump = lerp(bump, bump_B, transition);

	return transition;
}

float2 RotUv(float2 uv, float angle) 
{
	float si = sin(angle);
	float co = cos(angle);
	return float2(co * uv.x - si * uv.y, si * uv.x + co * uv.y);
}

inline void MergeRotatedLayer(inout float3 col, inout float3 bump, inout float4 mads, inout float totalWeight, float hexRot, int index, float2 uv, float2 distortion, float3 terrainBump)
{
	float pi = 3.14159265359;
	float segment = Ct_LayersRotation[index];// pi / 3;
	float rotation = (pi / 3) * hexRot + segment;

	float alligned = abs(dot(normalize(RotUv(float2(1,0),  rotation)), terrainBump.xz));

	uv = RotUv(uv + distortion * (1-alligned), -rotation - segment*0.5 );

	float4 mads_B = UNITY_SAMPLE_TEX2DARRAY(civ_MOHS_Arr, float3( uv, index)); //UNITY_SAMPLE_TEX2DARRAY(civ_MOHS_Arr, float3(uv.xy, index));

	float weight = pow(alligned, 4) * (0.1 + mads_B.b*mads_B.g);

	mads += mads_B * weight; 

	float3 col_B = UNITY_SAMPLE_TEX2DARRAY(civ_Albedo_Arr, float3( uv, index));
	col += col_B * weight; 

	float3 bump_B = UnpackNormal(UNITY_SAMPLE_TEX2DARRAY(civ_Normal_Arr, float3( uv, index)));

	bump_B.rg = RotUv(bump_B.rg,  rotation + segment*0.5);

	bump += bump_B * weight;

	totalWeight+= weight; 
}

inline void SampleLayerAllignToShore(out float3 col, out float3 bump, out float4 mads, int index, float2 uv, float3 terrainBump)
{
	float2 distortion = terrainBump.xz * Ct_LayersTiling[index];

	//sharpness *= 0.5; 
	terrainBump.y = 0;
	terrainBump.xz += 0.01;
	terrainBump = normalize(terrainBump);
	float weight = 0.01;

	col = 0;
	bump = 0;
	mads = 0;

	MergeRotatedLayer(col, bump, mads, weight, 1, index, uv, distortion, terrainBump);
	MergeRotatedLayer(col, bump, mads, weight, 2, index, uv, distortion, terrainBump);
	MergeRotatedLayer(col, bump, mads, weight, 3, index, uv, distortion, terrainBump);

	col /= weight;
	bump/= weight;
	mads/= weight;

	ApplySettings(bump, mads, index);
}

inline void MergeLayerAllignToShore(inout float3 col, inout float3 bump, inout float4 mads, inout float currentHeight, int index, float2 uv, float3 terrainBump, float control, float sharpness)
{
	float2 distortion = terrainBump.xz * Ct_LayersTiling[index];

	//sharpness *= 0.5; 
	terrainBump.y = 0;
	terrainBump.xz += 0.01;
	terrainBump = normalize(terrainBump);
	float weight = 0.01;

	float3 col_B = 0;
	float3 bump_B = 0;
	float4 mads_B = 0;

	MergeRotatedLayer(col_B, bump_B, mads_B, weight, 1, index, uv, distortion, terrainBump);
	MergeRotatedLayer(col_B, bump_B, mads_B, weight, 2, index, uv, distortion, terrainBump);
	MergeRotatedLayer(col_B, bump_B, mads_B, weight, 3, index, uv, distortion, terrainBump);

	col_B /= weight;
	bump_B/= weight;
	mads_B/= weight;

	float coefA = mads.b*mads.g;
	float coefB = mads_B.b*mads_B.g;

	ApplySettings(bump_B, mads_B, index);

	float transition = saturate((control * 2.0 + coefB - currentHeight - coefA) * sharpness);
	currentHeight = max(currentHeight, control);

	col = lerp(col, col_B, transition);
	bump = lerp(bump, bump_B, transition);
	mads = lerp(mads, mads_B, transition);
}

void GetTerrainBlend(float3 worldPos, float4 control,  float3 normal, out float3 newNormal, out float3 col, out float4 mads)
{
	float2 uv = worldPos.xz * 0.1;

	float2 uv1 = uv * Ct_LayersTiling.x;

	col = 0;
	mads = 0;
	float3 bump = float3(0,1,0);

	float derrivedWeight = smoothstep(0.1, 0, control.r * control.g + control.r * control.b + control.g * control.b);

	float sharpnessMin = 1.5;

	float sharpnessCoef = Ct_TerrainSettings.x; 

	float currentHeight = derrivedWeight;//
	float sharpness = max(sharpnessMin, sharpnessCoef/length(fwidth(uv1)));

	SampleLayerAllignToShore(col, bump, mads,  0, uv1 , normal);

	float2 uv2 = uv * Ct_LayersTiling.y;
	sharpness = max(sharpnessMin, sharpnessCoef/length(fwidth(uv2)));

	MergeLayer(col, bump, mads, currentHeight, 1, uv2*0.97, control.r, sharpness);

	float2 uv3 = uv * Ct_LayersTiling.z;
	sharpness = max(sharpnessMin, sharpnessCoef/length(fwidth(uv3)));

	MergeLayer(col, bump, mads, currentHeight, 2, uv3, control.g, sharpness);

	float2 uv4 = uv * Ct_LayersTiling.w;
	sharpness = max(sharpnessMin, sharpnessCoef/length(fwidth(uv4)));

	MergeLayerAllignToShore(col, bump, mads, currentHeight, 3, uv4 , normal, control.b, sharpness);

	bump = normalize(bump.xzy);

	bump.xz*=3;

	newNormal = normalize(lerp(normal,  bump, 0.5));
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

	float alpha = GetAlphaToHideForUvBordersTerrain(uv);
	control = lerp ( Ct_TerrainDefault, control,alpha);

	float4 bumpAndSdf = tex2Dlod(_Ct_Normal, float4(uv,0,0));
	bumpAndSdf = lerp (float4(0,1,0,-6),bumpAndSdf, alpha);

	normal = bumpAndSdf.xyz;
	float sdf = bumpAndSdf.a;

	return control;
}


float HeightToColor(float height)
{
	return saturate((height - Ct_HeightRange.x) /  Ct_HeightRange.z);

}

float3 SampleTerrainPosition(float3 worldPos)
{
    float4 terrain = Ct_SampleTerrain(worldPos);
	float yheight;
     GetTerrainHeight(terrain, yheight);
	 worldPos.y = yheight;
    return worldPos;
}


void GetIntegration(float4 terrainControl, float4 terrainMOHS, float4 objectMohs, float3 objectNormal, float3 worldPos, float blendHeight, float blendSharpness, out float showTerrain)
{
	float terrainHeight;
	GetTerrainHeight(terrainControl, terrainHeight);

	float objectDisplacement = objectMohs.b;
    float objectAO = objectMohs.g;
	float terrainAO = terrainMOHS.g;

	float diff = ((worldPos.y + objectDisplacement) - (terrainHeight + terrainMOHS.b));

	float objectWeight = diff; // Bland mask
    objectWeight *= (4-(objectAO)*3); // Darker areas should preserve normal
	objectWeight *= (0.5 + terrainAO * 0.5); // Darker terrain areas should persist
	//objectWeight*= (1-isUp);

    showTerrain = smoothstep(blendHeight, blendHeight * blendSharpness * 0.99 - 0.00001, objectWeight) ;

	float isUp = smoothstep(0.5,1, objectNormal.y);
	showTerrain *= isUp; // Verticality
}

void GetIntegration_Complimentary(float4 terrainControl, float4 terrainMOHS, float4 objectMohs, float3 objectNormal, float3 worldPos, float blendHeight, float blendSharpness, out float showTerrain)
{
	float terrainHeight;
	GetTerrainHeight(terrainControl, terrainHeight);

	float isUp = smoothstep(0.5,1, objectNormal.y);
	float objectDisplacement = objectMohs.b;
    float objectAO = objectMohs.g;
	float terrainAO = terrainMOHS.g;

	float diff = ((worldPos.y + objectDisplacement) - (terrainHeight + terrainMOHS.b));

	float objectWeight = diff; //(1-blendMap.r) * diff; // Bland mask
    objectWeight *= (4-(objectAO)*3); // Darker areas should preserve normal
	objectWeight *= (0.5 + terrainAO * 0.5); // Darker terrain areas should persist
	objectWeight *= 1 - isUp * 0.9;

    showTerrain = smoothstep(blendHeight, blendHeight * blendSharpness * 0.99 - 0.00001, objectWeight);

	//showTerrain*= isUp;
}
