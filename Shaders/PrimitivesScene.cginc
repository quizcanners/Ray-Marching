#ifndef QC_RTX_PRIM
#define QC_RTX_PRIM

#include "Assets/Ray-Marching/Shaders/inc/IntersectOperations.cginc"
#include "Assets/Ray-Marching/Shaders/inc/RayMathHelpers.cginc"
#include "Assets/Ray-Marching/Shaders/inc/SDFoperations.cginc"
#include "Assets/Ray-Marching/Shaders/Savage_VolumeSampling.cginc"


#include "UnityCG.cginc"
#include "UnityLightingCommon.cginc" 
#include "Lighting.cginc"
#include "AutoLight.cginc"


//static const float GAMMA_TO_LINEAR = 2.2;
//static const float LINEAR_TO_GAMMA = 1 / GAMMA_TO_LINEAR;

// CUBES

#define ARRAY_BOX_COUNT 8
#define ARRAY_SIZE 64
#define QC_NATIVE_SHADOW_DISTANCE 50
//1e10


//uniform float4 RAY_FLOOR_Mat;
//RayMarchCube_Unrotated
uniform float4 RayMarchUnRot[ARRAY_SIZE];
uniform float4 RayMarchUnRot_Size[ARRAY_SIZE];
uniform float4 RayMarchUnRot_Mat[ARRAY_SIZE];
//uniform float4 RayMarchUnRot_Rot[ARRAY_SIZE];

uniform float4 RayMarchUnRot_BoundPos[ARRAY_BOX_COUNT];
uniform float4 RayMarchUnRot_BoundSize[ARRAY_BOX_COUNT];

uniform float4 RayMarchUnRot_BoundPos_All;
uniform float4 RayMarchUnRot_BoundSize_All;

// Rotated Cubes
uniform float4 RayMarchCube[ARRAY_SIZE];
uniform float4 RayMarchCube_Size[ARRAY_SIZE];
uniform float4 RayMarchCube_Mat[ARRAY_SIZE];
uniform float4 RayMarchCube_Rot[ARRAY_SIZE];

uniform float4 RayMarchCube_BoundPos[ARRAY_BOX_COUNT];
uniform float4 RayMarchCube_BoundSize[ARRAY_BOX_COUNT];

uniform float4 RayMarchCube_BoundPos_All;
uniform float4 RayMarchCube_BoundSize_All;

// Dynamics

#define DYNAMIC_ARRAY_SIZE 6

uniform float4 DYNAMIC_PRIM[DYNAMIC_ARRAY_SIZE];
uniform float4 DYNAMIC_PRIM_Size[DYNAMIC_ARRAY_SIZE];
uniform float4 DYNAMIC_PRIM_Mat[DYNAMIC_ARRAY_SIZE];
uniform float4 DYNAMIC_PRIM_Rot[DYNAMIC_ARRAY_SIZE];

uniform float4 DYNAMIC_PRIM_BoundPos;
uniform float4 DYNAMIC_PRIM_BoundSize;

uniform int DYNAMIC_PRIM_COUNT;

// SUBTRACTIVE
uniform float4 RayMarchSubtractiveCube_0;
uniform float4 RayMarchSubtractiveCube_0_Size;
uniform float4 RayMarchSubtractiveCube_0_Mat;

uniform float4 RayMarchSubtractiveCube_1;
uniform float4 RayMarchSubtractiveCube_1_Size;
uniform float4 RayMarchSubtractiveCube_1_Mat;

uniform float4 RayMarchSubtractiveCube_2;
uniform float4 RayMarchSubtractiveCube_2_Size;
uniform float4 RayMarchSubtractiveCube_2_Mat;

//Spheres
uniform float4 RayMarchSphere_0;
uniform float4 RayMarchSphere_0_Size;
uniform float4 RayMarchSphere_0_Mat;

uniform float4 RayMarchSphere_1;
uniform float4 RayMarchSphere_1_Size;
uniform float4 RayMarchSphere_1_Mat;

// Ambient Light
uniform float4 RayMarchLight_0;
uniform float4 RayMarchLight_0_Mat;
uniform float4 RayMarchLight_0_Size;

//uniform float4 _RayMarchSkyColor;
uniform float4 _RayMarthMinLight;

uniform samplerCUBE  Qc_SkyBox;


uniform float4 _qc_PointLight_Position;
uniform float4 _qc_PointLight_Color;

uniform float _qc_SunVisibility;
//_qc_USE_SUN



uniform float _RayTraceDofDist;
uniform float _RayTraceDOF;
uniform sampler2D _RayTracing_SourceBuffer;
uniform float4 _RayTracing_SourceBuffer_ScreenFillAspect;

uniform float _RayTraceTransparency;

uniform float4 _RayTracing_TargetBuffer_ScreenFillAspect;

uniform sampler2D _qcPp_DestBuffer;


uniform float _MaxRayMarchDistance;
float _maxRayMarchSteps;
float _RayMarchSmoothness;
float _RayMarchShadowSoftness;



#define MAX_VOLUME_ALPHA 10500//1e10
#define MATCH_RAY_TRACED_SUN_COEFFICIENT 0.5
#define MATCH_RAY_TRACED_SKY_COEFFICIENT 0.5
#define MATCH_RAY_TRACED_SUN_LIGH_GLOSS 0.2

#define LAMBERTIAN 0.
#define METAL 1.
#define DIELECTRIC 2.
#define GLASS 3.
#define EMISSIVE 4.
#define SUBTRACTIVE 5.

inline float3 GetDirectional()
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	return _LightColor0.rgb * _qc_SunVisibility;// *MATCH_RAY_TRACED_SUN_COEFFICIENT;// * smoothstep(0, 0.1, _WorldSpaceLightPos0.y);
}

float getShadowAttenuation(float3 worldPos)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

#if defined(SHADOWS_CUBE)
	{
		unityShadowCoord3 shadowCoord = worldPos - _LightPositionRange.xyz;
		float result = UnitySampleShadowmap(shadowCoord);
		return result;
	}
#elif defined(SHADOWS_SCREEN)
	{
#ifdef UNITY_NO_SCREENSPACE_SHADOWS
		unityShadowCoord4 shadowCoord = mul(unity_WorldToShadow[0], worldPos);
#else
		unityShadowCoord4 shadowCoord = ComputeScreenPos(mul(UNITY_MATRIX_VP, float4(worldPos, 1.0)));
#endif
		float result = unitySampleShadow(shadowCoord);
		return result;
	}
#elif defined(SHADOWS_DEPTH) && defined(SPOT)
	{
		unityShadowCoord4 shadowCoord = mul(unity_WorldToShadow[0], float4(worldPos, 1.0));
		float result = UnitySampleShadowmap(shadowCoord);
		return result;
	}
#else
	return 1.0;
#endif  
}

float3 SampleSkyBox(float3 rd)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	return lerp(texCUBElod(Qc_SkyBox, float4(rd,0)).rgb, GetAmbientLight(), _qc_AmbientColor.a); //GetDirectional();
}

float3 SampleSkyBox(float3 rd, float smoothness)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	return lerp(texCUBElod(Qc_SkyBox, float4(rd,(1-smoothness) * 5)).rgb, GetAmbientLight(), _qc_AmbientColor.a); //GetDirectional();
}


// Scenes
float3 getSkyColor(float3 rd, float shadow)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	float3 col = SampleSkyBox(rd);

	if (_qc_SunVisibility<=0.01)
	{
		return col; //float4(0,0,0,distance);
	}

#if defined(_qc_AMBIENT_SIMULATION)
#else
	float sun = smoothstep(1, 0, dot(_WorldSpaceLightPos0.xyz, rd));
	col.rgb += GetDirectional() 
	* shadow * (1 / (0.01 + sun * 6000));
#endif

	return col;
}

float3 getSkyColor(float3 rd) 
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	return getSkyColor(rd, 1);
}


float SceneSdf_Dynamic(float3 position, float smoothness, float edges)
{
	float dist = 9999;

	for (int i = 0; i < DYNAMIC_PRIM_COUNT; i++) 
	{
		float cDst =
		//CubeDistanceRot(position, DYNAMIC_PRIM_Rot[i] ,DYNAMIC_PRIM[i], DYNAMIC_PRIM_Size[i].xyz, edges);
		CapsuleDistanceRot(position, DYNAMIC_PRIM_Rot[i] ,DYNAMIC_PRIM[i], DYNAMIC_PRIM_Size[i].xyz);
		
		dist = CubicSmin(dist, cDst, edges);
	}

	return dist;
}


float SceneSdf(float3 position, float smoothness) 
{
	float edges = _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w * 0.5 * smoothness;

	//float s0 = SphereDistance(position, float4(RayMarchSphere_0.xyz, RayMarchSphere_0_Size.x));
	//float s1 = SphereDistance(position, float4(RayMarchSphere_1.xyz, RayMarchSphere_1_Size.x));

	float dist = 999999;//CubicSmin(s0, s1, edges);

	#define ADD(d) dist = CubicSmin(dist, d, edges)

	float boxDetection = 1 + edges * 2;


	//RayMarchUnRot
	float toBound = CubeDistance_Inernal(position - RayMarchUnRot_BoundPos_All.xyz, RayMarchUnRot_BoundSize_All.xyz);

	UNITY_BRANCH
	if (toBound < boxDetection)
	{		
		for (int b = 0; b < ARRAY_BOX_COUNT; b++)
		{
			float4 pos = RayMarchUnRot_BoundPos[b];
			float4 size = RayMarchUnRot_BoundSize[b];

			//type < EMISSIVE + 1

			toBound = CubeDistance_Inernal(position - pos.xyz, size.xyz);

			UNITY_BRANCH
			if (toBound < boxDetection)
			{
				for (int i = pos.w; i < size.w; i++) 
				{
					float4 posNType = RayMarchUnRot[i];
					if (posNType.w>= EMISSIVE)
						continue;
					ADD(CubeDistance(position, posNType, RayMarchUnRot_Size[i].xyz, edges));
				}
					//TRACE_BOX_ROT(RayMarchCube[i], RayMarchCube_Rot[i], RayMarchCube_Size[i], RayMarchCube_Mat[i]);
			} else 
			{
				dist = min(dist, toBound + boxDetection * 1.1);
			}
		}
	} else 
	{
		dist = min(dist, toBound + boxDetection*1.1);
	}

	// Cube Rotated
	toBound = CubeDistance_Inernal(position - RayMarchCube_BoundPos_All.xyz, RayMarchCube_BoundSize_All.xyz);
	
	UNITY_BRANCH
	if (toBound < boxDetection)
	{		
		for (int b = 0; b < ARRAY_BOX_COUNT; b++)
		{
			float4 pos = RayMarchCube_BoundPos[b];
			float4 size = RayMarchCube_BoundSize[b];

			toBound = CubeDistance_Inernal(position - pos.xyz, size.xyz);

			UNITY_BRANCH
			if (toBound < boxDetection)
			{
				for (int i = pos.w; i < size.w; i++) 
				{
					float4 posNType = RayMarchCube_Rot[i];

					if (posNType.w>= EMISSIVE)
						continue;

					ADD(CubeDistanceRot(position, posNType, RayMarchCube[i], RayMarchCube_Size[i].xyz, edges));
				}
					//TRACE_BOX_ROT(RayMarchCube[i], RayMarchCube_Rot[i], RayMarchCube_Size[i], RayMarchCube_Mat[i]);
			} else 
			{
				dist = min(dist, toBound + boxDetection * 1.1);
			}
		}
	} else 
	{
		dist = min(dist, toBound + boxDetection*1.1);
	}

	#if defined(RAYMARCH_DYNAMICS)
	ADD(SceneSdf_Dynamic(position, smoothness, edges));
	#endif

	/*
	float sub0 = CubeDistance(position, RayMarchSubtractiveCube_0, RayMarchSubtractiveCube_0_Size.xyz, edges);
	float sub1 = CubeDistance(position, RayMarchSubtractiveCube_1, RayMarchSubtractiveCube_1_Size.xyz, edges); 
	float sub2 = CubeDistance(position, RayMarchSubtractiveCube_2, RayMarchSubtractiveCube_2_Size.xyz, edges);
	*/

	/*
	#if !defined(IGNORE_FLOOR)
	float plane = Plane(position); 

	ADD(plane);
	#endif
	*/
	/*
	dist = OpSmoothSubtraction(dist, sub0, edges);
	dist = OpSmoothSubtraction(dist, sub1, edges);
	dist = OpSmoothSubtraction(dist, sub2, edges);
	*/

	return dist;
}

float SceneSdf(float3 position)
{
	return SceneSdf(position, _RayMarchSmoothness);
}

float3 opU(float3 d, float distance, float4 newMat, inout float4 currentMat, float type) 
{
	currentMat = d.y > distance ? newMat : currentMat;
	return d.y > distance ? float3(d.x, distance, type) : d; // if closer make new result
}

/*
float SampleBoxRotated(in float3 ro, in float3 rd, in float4 q, in float2 distBound, inout float3 normal, in float3 boxSize) 
{
	rd = Rotate(rd, q);
	ro = Rotate(ro, q);

	float3 absRd = abs(rd) + 0.000001f;
	float3 signRd = rd / absRd;
	float3 m = signRd / (absRd);
	float3 n = m * ro;
	float3 k = abs(m) * boxSize;

	float3 t1 = -n - k;
	float3 t2 = -n + k;

	float tN = max(max(t1.x, t1.y), t1.z);
	float tF = min(min(t2.x, t2.y), t2.z);

	if (tN > tF || tF <= 0.0)
	{
		return MAX_DIST;
	}
	else 
	{
		if (tN >= distBound.x && tN <= distBound.y) 
		{
			normal = -signRd * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);
			normal = Rotate(normal, float4(-q.x,-q.y,-q.z, q.w));
			return tN;
		}
		else if (tF >= distBound.x && tF <= distBound.y)
		{
			normal = -signRd * step(t2.xyz, t2.yzx) * step(t2.xyz, t2.zxy);
			normal = Rotate(normal, float4(-q.x, -q.y, -q.z, q.w));
			return tF;
		}
		else 
		{
			return MAX_DIST;
		}
	}
}
*/

#define IS_HIT_BOX(pos, size) IsHitBox(ro - pos.xyz, rd, size.xyz, d.xy, m)
#define IS_HIT_SPHERE(pos, radius) isHitSphere(ro - pos.xyz, rd, radius, d.xy)
#define IS_HIT_BOX_ROT(pos, rot, size) isHitBoxRot(ro - pos.xyz, rd, rot, size.xyz, d.xy)
#define IS_HIT_BOX_ROT_DEPTH(pos, rot, size) IsHitBoxRot_ModifyDepth(ro - pos.xyz, rd, rot, size.xyz, dTmp.xy)

#define IS_HIT_CAPSULE_ROT(pos, rot, size) isHitCapsuleRot(ro - pos.xyz, rd, rot, d.xy, size.y, size.x)

#define TRACE_BOX(posNmat, size,objmat) d = opU(d, iBox(ro - posNmat.xyz, rd, d.xy, normal, size.xyz, m), objmat, mat, posNmat.w)
#define TRACE_BOX_ROT(posNmat, rot, size,objmat) d = opU(d, iBoxRot(ro - posNmat.xyz, rd, rot, d.xy, normal, size.xyz), objmat, mat, posNmat.w)
#define TRACE_CAPSULE_ROT(posNmat, rot, size,objmat) d = opU(d, iCapsuleRot(ro - posNmat.xyz, rd, rot, d.xy, normal, size.y, size.x), objmat, mat, posNmat.w)

//float iCapsuleRot(in float3 ro, in float3 rd, in float4 q, in float2 distBound, inout float3 normal,
	//in float3 pa, in float3 pb, in float r) 


void WorldHit_Dynamic(float3 ro, in float3 rd, inout float3 d, inout float3 normal, inout float4 mat, in float3 m) 
{
	if (IS_HIT_BOX(DYNAMIC_PRIM_BoundPos, DYNAMIC_PRIM_BoundSize))
	{
		for (int i=0; i< DYNAMIC_PRIM_COUNT; i++)
			TRACE_CAPSULE_ROT(DYNAMIC_PRIM[i], DYNAMIC_PRIM_Rot[i], DYNAMIC_PRIM_Size[i], DYNAMIC_PRIM_Mat[i]);
	}
}


bool Raycast(float3 ro, in float3 rd, in float2 dist) {

	rd += 0.001; // rd * 0.01;

	float3 d = float3(dist, 0.);

	/*
#if !defined(IGNORE_FLOOR)
	if (isPlane(ro, rd, float3(0, 1, 0), d.xy))
		return true;
#endif
*/

	float3 m = sign(rd) / max(abs(rd), 0.00001);//1e-8);

	UNITY_BRANCH
	if (IS_HIT_BOX(RayMarchCube_BoundPos_All, RayMarchCube_BoundSize_All))
	{
		for (int b = 0; b < ARRAY_BOX_COUNT; b++)
		{
			float4 pos = RayMarchCube_BoundPos[b];
			float4 size = RayMarchCube_BoundSize[b];

			UNITY_BRANCH
			if (IS_HIT_BOX(pos, size))
			{
				for (int i = pos.w; i < size.w; i++) 
				{
					float4 posNmat = RayMarchCube[i];
					float type = posNmat.w;
					if (type < GLASS && IS_HIT_BOX_ROT(posNmat, RayMarchCube_Rot[i], RayMarchCube_Size[i]))
						return true;//(isBoxRotHit(RayMarchCube[i], RayMarchCube_Rot[i], RayMarchCube_Size[i], RayMarchCube_Mat[i]);
				}
			}
		}
	}


	// Unrotated Cubes
	UNITY_BRANCH
	if (IS_HIT_BOX(RayMarchUnRot_BoundPos_All, RayMarchUnRot_BoundSize_All))
	{
		for (int b = 0; b < ARRAY_BOX_COUNT; b++)
		{
			float4 pos = RayMarchUnRot_BoundPos[b];
			float4 size = RayMarchUnRot_BoundSize[b];

			UNITY_BRANCH
			if (IS_HIT_BOX(pos, size))
			{
				for (int i = pos.w; i < size.w; i++) 
				{
					float4 posNmat = RayMarchUnRot[i];
					float type = posNmat.w;
					if (type < GLASS && IS_HIT_BOX(posNmat, RayMarchUnRot_Size[i]))
						return true;//(isBoxRotHit(RayMarchCube[i], RayMarchCube_Rot[i], RayMarchCube_Size[i], RayMarchCube_Mat[i]);
				}
			}
		}
	}

	/*
	if (IS_HIT_SPHERE(RayMarchSphere_0, RayMarchSphere_0_Size.x))
		return true;

	if (IS_HIT_SPHERE(RayMarchSphere_1, RayMarchSphere_1_Size.x))
		return true;
*/
	//d = opU(d, iSphere(ro - RayMarchSphere_0.xyz, rd, d.xy, normal, RayMarchSphere_0_Size.x), RayMarchSphere_0_Mat, mat, RayMarchSphere_0.w);
	//d = opU(d, iSphere(ro - RayMarchSphere_1.xyz, rd, d.xy, normal, RayMarchSphere_1_Size.x), RayMarchSphere_1_Mat, mat, RayMarchSphere_1.w);

	
#if defined(RENDER_DYNAMICS)

	UNITY_BRANCH
	if (IS_HIT_BOX(DYNAMIC_PRIM_BoundPos, DYNAMIC_PRIM_BoundSize))
	{
		for (int i = 0; i < DYNAMIC_PRIM_COUNT; i++)
			if (IS_HIT_CAPSULE_ROT(DYNAMIC_PRIM[i], DYNAMIC_PRIM_Rot[i], DYNAMIC_PRIM_Size[i]))
				return true;
			//TRACE_CAPSULE_ROT(DYNAMIC_PRIM[i], DYNAMIC_PRIM_Rot[i], DYNAMIC_PRIM_Size[i], DYNAMIC_PRIM_Mat[i]);
	}
#endif

	return false;
}

bool Raycast(float3 start, in float3 end)
{
	float3 dir = end.xyz - start;

	float distance = length(dir);

	float2 MIN_MAX = float2(0.0001, distance);

	return Raycast(start , normalize(dir), MIN_MAX);
}

bool RaycastStaticPhisics(float3 ro, in float3 rd, in float2 dist) {

	rd += 0.001; // rd * 0.01;

	float3 d = float3(dist, 0.);

	/*
#if !defined(IGNORE_FLOOR)
	if (isPlane(ro, rd, float3(0, 1, 0), d.xy))
		return true;
#endif
*/

	float3 m = sign(rd) / max(abs(rd), 0.0001);//1e-8);

	UNITY_BRANCH
	if (IS_HIT_BOX(RayMarchCube_BoundPos_All, RayMarchCube_BoundSize_All))
	{
		for (int b = 0; b < ARRAY_BOX_COUNT; b++)
		{
			float4 pos = RayMarchCube_BoundPos[b];
			float4 size = RayMarchCube_BoundSize[b];

			UNITY_BRANCH
			if (IS_HIT_BOX(pos, size))
			{
				for (int i = pos.w; i < size.w; i++)
				{
					float4 posNmat = RayMarchCube[i];
					float type = posNmat.w;
					if (IS_HIT_BOX_ROT(posNmat, RayMarchCube_Rot[i], RayMarchCube_Size[i]))
						return true;//(isBoxRotHit(RayMarchCube[i], RayMarchCube_Rot[i], RayMarchCube_Size[i], RayMarchCube_Mat[i]);
				}
			}
		}
	}

	UNITY_BRANCH
	if (IS_HIT_BOX(RayMarchUnRot_BoundPos_All, RayMarchUnRot_BoundSize_All))
	{
		for (int b = 0; b < ARRAY_BOX_COUNT; b++)
		{
			float4 pos = RayMarchUnRot_BoundPos[b];
			float4 size = RayMarchUnRot_BoundSize[b];

			UNITY_BRANCH
			if (IS_HIT_BOX(pos, size))
			{
				for (int i = pos.w; i < size.w; i++)
				{
					float4 posNmat = RayMarchUnRot[i];
					float type = posNmat.w;
					if (IS_HIT_BOX(posNmat, RayMarchUnRot_Size[i]))
						return true;//(isBoxRotHit(RayMarchCube[i], RayMarchCube_Rot[i], RayMarchCube_Size[i], RayMarchCube_Mat[i]);
				}
			}
		}
	}

	/*
	if (IS_HIT_SPHERE(RayMarchSphere_0, RayMarchSphere_0_Size.x))
		return true;

	if (IS_HIT_SPHERE(RayMarchSphere_1, RayMarchSphere_1_Size.x))
		return true;
		*/
	return false;
}




float3 GetPointLight(float3 position, float3 normal, float ao)
{
	if (_qc_PointLight_Color.a==0)
	{
		return 0;
	}

	float3 lightDir = _qc_PointLight_Position.xyz - position;

	float distance = length(lightDir);

	lightDir = normalize(lightDir);

	float2 MIN_MAX = float2(0.0001, distance);

	bool isHit = RaycastStaticPhisics(position + normal * 0.01 , lightDir, MIN_MAX);

	if (isHit) 
		return 0;
	
	float distFade = 1/(distance + 1);
	float distFadeSquare =  distFade * distFade;
	float direct = smoothstep( -ao * distFadeSquare, 1.5 - ao * 0.5, saturate(dot(normal, lightDir)));
	direct = lerp(direct, 1, distFadeSquare);
	
	float3 col = _qc_PointLight_Color.rgb * direct * distFadeSquare;

	return col;
}

float3 GetPointLight(float3 position, float3 normal, float ao, float3 viewDir, float gloss, inout float3 lightSpecular)
{
	if (_qc_PointLight_Color.a==0)
	{
		return 0;
	}

	float3 lightDir = _qc_PointLight_Position.xyz - position;
	float distance = length(lightDir);
	lightDir = normalize(lightDir);

	float2 MIN_MAX = float2(0.0001, distance);

	bool isHit = Raycast(position + normal * 0.01 , lightDir, MIN_MAX);

	if (isHit) 
		return 0;
	
	float distFade = 1/(distance + 1);
	float distFadeSquare =  distFade * distFade;

	float direct = smoothstep( -ao * distFadeSquare, 1.5 - ao * 0.5, saturate(dot(normal, lightDir)));

	direct = lerp(direct, 1, distFadeSquare);
	
	float3 col = _qc_PointLight_Color.rgb * direct * distFadeSquare;

	float3 toCamera = normalize(_qc_PointLight_Position.xyz - _WorldSpaceCameraPos.xyz);
	 float3 reflectedRay = reflect(-viewDir,normal);
	float power = pow(gloss + 0.001,8) ;
    float specularTerm = pow(max(dot(lightDir,reflectedRay),0), power* 92) * power * distFade; 
	lightSpecular += specularTerm * _qc_PointLight_Color.rgb;

	return col;
}

float3 GetPointLight_Specualr(float3 position, float3 reflectedRay, float gloss)
{
	if (_qc_PointLight_Color.a==0)
	{
		return 0;
	}

	float3 lightDir = _qc_PointLight_Position.xyz - position;
	float distance = length(lightDir);
	lightDir = normalize(lightDir);

	float2 MIN_MAX = float2(0.0001, distance);

	bool isHit = Raycast(position, lightDir, MIN_MAX);

	if (isHit) 
		return 0;
	float distFade = 1/(distance + 1);
	float power = pow(gloss + 0.001,8) ;
    float specularTerm = pow(max(dot(lightDir,reflectedRay),0), power* 92) * power * distFade; 
	return specularTerm * _qc_PointLight_Color.rgb;

}

float3 worldhit(float3 ro, in float3 rd, in float2 dist, out float3 normal, inout float4 mat) {

	ro += rd * 0.01;
	// d.z <= z causes to show sky   d.z is material
	float3 d = float3(dist, 0.);
	//const float floorRoughness = 0.99;
	//const float floorMaterial = 0.1;
	//const float3 FLOOR_COLOR = float3(0.01, 0.5, 0.01);
	//const float4 RAY_FLOOR_Mat = float4(0.3, 0.3, 0.3, 0.2);

	normal = -rd;

	/*
	#if !defined(IGNORE_FLOOR)

	d = opU(d, iPlane(ro, rd, d.xy, normal, float3(0, 1, 0)), RAY_FLOOR_Mat, mat, floorMaterial);

	#endif
	*/

	float3 m = sign(rd) / max(abs(rd), 1e-8);

	int boxHit = -1;

	float3 dTmp = d;

	UNITY_BRANCH
	if (IS_HIT_BOX(RayMarchCube_BoundPos_All, RayMarchCube_BoundSize_All))
	{
		for (int b = 0; b < ARRAY_BOX_COUNT; b++) 
		{
			float4 pos = RayMarchCube_BoundPos[b];
			float4 size = RayMarchCube_BoundSize[b];

			UNITY_BRANCH
			if (IS_HIT_BOX(pos, size))
			{
				for (int i = pos.w; i < size.w; i++)
				{
					/*
					float4 posNmat = RayMarchCube[i];
					float type = posNmat.w;
					if (IS_HIT_BOX_ROT_DEPTH(posNmat, RayMarchCube_Rot[i], RayMarchCube_Size[i])) 
					{
						boxHit = i;
					}*/
						
					TRACE_BOX_ROT(RayMarchCube[i], RayMarchCube_Rot[i], RayMarchCube_Size[i], RayMarchCube_Mat[i]);
				}
			}
		}
	}
	/*
	if (boxHit>-1)
	{
		TRACE_BOX_ROT(RayMarchCube[boxHit], RayMarchCube_Rot[boxHit], RayMarchCube_Size[boxHit], RayMarchCube_Mat[boxHit]);
	}*/

	// Unrotated
	UNITY_BRANCH
	if (IS_HIT_BOX(RayMarchUnRot_BoundPos_All, RayMarchUnRot_BoundSize_All))
	{
		for (int b = 0; b < ARRAY_BOX_COUNT; b++) 
		{
			float4 pos = RayMarchUnRot_BoundPos[b];
			float4 size = RayMarchUnRot_BoundSize[b];

			UNITY_BRANCH
			if (IS_HIT_BOX(pos, size))
			{
				for (int i = pos.w; i < size.w; i++)
				{
					TRACE_BOX(RayMarchUnRot[i], RayMarchUnRot_Size[i],RayMarchUnRot_Mat[i]);
				}
			}
		}
	}

	/*
	d = opU(d, iSphere(ro - RayMarchSphere_0.xyz, rd, d.xy, normal, RayMarchSphere_0_Size.x), RayMarchSphere_0_Mat, mat, RayMarchSphere_0.w);
	d = opU(d, iSphere(ro - RayMarchSphere_1.xyz, rd, d.xy, normal, RayMarchSphere_1_Size.x), RayMarchSphere_1_Mat, mat, RayMarchSphere_1.w);

	
	d = opU(d, iBox(ro - RayMarchSubtractiveCube_0.xyz, rd, d.xy, normal, RayMarchSubtractiveCube_0_Size.xyz, m), RayMarchSubtractiveCube_0_Mat, mat, RayMarchSubtractiveCube_0.w);
	d = opU(d, iBox(ro - RayMarchSubtractiveCube_1.xyz, rd, d.xy, normal, RayMarchSubtractiveCube_1_Size.xyz, m), RayMarchSubtractiveCube_1_Mat, mat, RayMarchSubtractiveCube_1.w);
	d = opU(d, iBox(ro - RayMarchSubtractiveCube_2.xyz, rd, d.xy, normal, RayMarchSubtractiveCube_2_Size.xyz, m), RayMarchSubtractiveCube_2_Mat, mat, RayMarchSubtractiveCube_2.w);
	*/
	#if defined(RENDER_DYNAMICS)

	WorldHit_Dynamic(ro, rd, d, normal, mat, m);

	#endif

	return d;
}


float worldhitSubtractive(float3 ro, in float3 rd, in float2 dist) 
{
	float3 d = float3(dist, 0.);

	float3 m = sign(rd) / max(abs(rd), 1e-8);

	float distance = iBoxTrigger(ro - RayMarchSubtractiveCube_0.xyz, rd, d.xy, RayMarchSubtractiveCube_0_Size.xyz, m);
	distance = min(distance, iBoxTrigger(ro - RayMarchSubtractiveCube_1.xyz, rd, d.xy, RayMarchSubtractiveCube_1_Size.xyz, m));
	distance = min(distance, iBoxTrigger(ro - RayMarchSubtractiveCube_2.xyz, rd, d.xy, RayMarchSubtractiveCube_2_Size.xyz, m));

	return distance;
}

float SampleRayShadowAndAttenuation(float3 pos, float3 normal)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	if (_qc_SunVisibility == 0)
			return 0;

	float2 MIN_MAX = float2(0.0001, MAX_DIST_EDGE);

	bool isHit = Raycast(pos + normal * 0.0001, _WorldSpaceLightPos0.xyz, MIN_MAX);

	return isHit ? 0 : smoothstep(0, 1, dot(normalize(_WorldSpaceLightPos0.xyz), normal));
}

float SampleRayShadow(float3 pos)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	UNITY_BRANCH
	if (_qc_SunVisibility == 0){
			return 0;
			}
	else 
	{

		float2 MIN_MAX = float2(0.0001, MAX_DIST_EDGE);

		bool isHit = Raycast(pos, _WorldSpaceLightPos0.xyz, MIN_MAX);

		return isHit ? 0 : 1;
	}
}


// ****************** Intersections

#if RT_MOTION_TRACING
	#define PATH_LENGTH 2
#elif _qc_IGNORE_SKY
	#define PATH_LENGTH 6
#else
	#define PATH_LENGTH 4
#endif

float3 modifyDirectionWithRoughnessFast(in float3 normal, in float3 refl, in float roughness, in float4 seed) {

	return lerp(normalize(normal + seed.wzx), refl, step(seed.y, roughness));

	float2 r = seed.wx;//hash2(seed);

	float nyBig = step(.5, refl.y);

	float3  uu = normalize(cross(refl, float3(nyBig, 1. - nyBig, 0.)));
	float3  vv = cross(uu, refl);

	float a = roughness * roughness;

	float rz = sqrt(abs((1.0 - seed.y) / clamp(1. + (a - 1.) * seed.y, .00001, 1.)));
	float ra = sqrt(abs(1. - rz * rz));
	float preCmp = 6.28318530718 * seed.x;
	float rx = ra * cos(preCmp);
	float ry = ra * sin(preCmp);
	float3 rr = float3(rx * uu + ry * vv + rz * refl);

	return normalize(rr + (seed.xyz - 0.5) * 0.1);
}

float4 render(in float3 ro, in float3 rd, in float4 seed) 
{
	const float MIN_DIST = 0.000001;

	float3 albedo, normal;
	float3 col = 1;
	float roughness, type;

	float isFirst = 1;
	float distance = MAX_DIST_EDGE;
	float4 mat = 0;

#if !RT_DENOISING && !RT_TO_CUBEMAP
	for (int i = 0; i < PATH_LENGTH; ++i)
	{
#endif
		
		//rd = normalize(rd);

		float3 res = worldhit(ro, rd, float2(MIN_DIST, MAX_DIST_EDGE), normal, mat);
		roughness = mat.a;
		albedo = mat.rgb;
		type = res.z;
		// res.x =
		// res.y = dist
		// res.z = material

#if RT_DENOISING

		distance = isFirst > 0.5 ?
			res.y +
			dot(rd, normal)
			: distance;
		isFirst = 0;
#endif

		if (res.z <= 0.)
		{
			#if _qc_IGNORE_SKY
				return float4(0,0,0, distance);
			#endif

			float3 skyCol = getSkyColor(rd);
			return float4(col * skyCol, distance);
		}

		ro += rd * res.y;


#if RT_TO_CUBEMAP && _qc_IGNORE_SKY
	
	UNITY_FLATTEN
	if (type < EMISSIVE + 1 &&  type >= EMISSIVE ) 
	{	
		return float4(col * albedo * 4, distance);
	} else 
	{
		float outOfBounds1;
		col = SampleVolume(_RayMarchingVolume, ro + normal * min(distance * 0.5, _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w)
		, outOfBounds1).rgb * (1 - outOfBounds1);
			
		return float4(col * albedo, distance);
	}

#endif





			/*
#define LAMBERTIAN 0.
#define METAL 1.
#define DIELECTRIC 2.


#define GLASS 3.
#define EMISSIVE 4.
#define SUBTRACTIVE 5.*/

UNITY_BRANCH
if (type < DIELECTRIC + 0.5)
{
			UNITY_BRANCH
			if (type < LAMBERTIAN + 0.5) 
			{ 
				col *= albedo;
				rd = cosWeightedRandomHemisphereDirection(normal, seed);

				#if !_qc_IGNORE_SKY
				if (_qc_SunVisibility > 0)
				{
					float attenuation = smoothstep(0, 1, dot(normalize(_WorldSpaceLightPos0.xyz), normal));

					if (attenuation > (seed.x) && !Raycast(ro + normal*0.001, _WorldSpaceLightPos0.xyz + (seed.zyx-0.5)*0.3, float2(0.0001, MAX_DIST_EDGE)))
					{
						col.rgb *= GetDirectional() * attenuation;
						return float4(col, distance);
					}
				}
				#endif
			}
			else
			if (type < METAL + 0.5) 
			{ 
				col *= albedo;
				rd = modifyDirectionWithRoughness(normal, reflect(rd, normal), roughness, seed);
			} else  //if (type < DIELECTRIC + 0.5)
			{
			
					ro += rd * 0.25;// +(seed.zyx - 0.5) * 0.1;
					normal = -normal;
					
					rd = cosWeightedRandomHemisphereDirection(normal, seed);

					#if !_qc_IGNORE_SKY
					if (_qc_SunVisibility > 0) 
					{
						if (!Raycast(ro + normal * 0.001, _WorldSpaceLightPos0.xyz + (seed.zyx - 0.5) * 0.3, float2(0.0001, MAX_DIST_EDGE)))
						{
							float toSUn = smoothstep(0, -1, dot(_WorldSpaceLightPos0.xyz, normal));
						
							col *= albedo;
							col.rgb *= GetDirectional() * (1 + toSUn * 16);
							return float4(col, distance);
						}
					}
					#endif
			}
} 
else  
{
//#if RT_USE_DIELECTRIC

			UNITY_BRANCH
			if (type < GLASS + 0.5) //DIELECTRIC + GLASS
			{ 
				float3 normalOut;
				float3 refracted = 0;
				float ni_over_nt, cosine, reflectProb = 1.;
				float theDot = dot(rd, normal);

				if (theDot > 0.) {
					normalOut = -normal;
					ni_over_nt = 1.4;
					cosine = theDot;
					cosine = sqrt(max(0.001, 1. - (1.4*1.4) - (1.4*1.4)*cosine*cosine));
				}
				else {
					normalOut = normal;
					ni_over_nt = 1. / 1.4;
					cosine = -theDot;
				}

				float modRf = modifiedRefract(rd, normalOut, ni_over_nt, refracted);

				float r0 = (1. - ni_over_nt) / (1. + ni_over_nt);
				reflectProb = 
					lerp(reflectProb, FresnelSchlickRoughness(cosine, r0 * r0, roughness), modRf);

				rd = (seed.b) <= reflectProb ? reflect(rd, normal) : refracted;
				rd = modifyDirectionWithRoughnessFast(-normalOut, rd, roughness, seed);
			}
			else if (type < EMISSIVE + 1) // EMISSIVE
			{
				return float4(col * albedo * 4, distance);
			} else // Subtractive
			{
				ro += 0.001 * rd;
				float dist = worldhitSubtractive(ro, rd, float2(MIN_DIST, MAX_DIST_EDGE));
				if (dist < MAX_DIST)
				{
					ro += (dist + 0.001) * rd;
				}
			}
}
		

#if !RT_DENOISING && !RT_TO_CUBEMAP
	}
#endif

	float3 light = 0; 
	
	#if !qc_NO_VOLUME
		float outOfBounds;
		light += SampleVolume(_RayMarchingVolume, ro + normal *  min(distance * 0.5, _RayMarchingVolumeVOLUME_POSITION_N_SIZE.w), outOfBounds).rgb * (1 - outOfBounds);
	#endif

	#if !_qc_IGNORE_SKY
	if (_qc_SunVisibility>0) 
	{
		float shadow = SampleRayShadowAndAttenuation(ro, normal);
		light += GetDirectional() * shadow;
	}
	#endif
	
	col.rgb *= light;

	return float4(col, distance);

}

// ****************** SDF


float Softshadow(float3 start, float3 direction, float mint, float k, float maxSteps)
{
	float res = 1.0;
	float ph = 1e20;

	float distance = mint;

	for (int i = 0; i < maxSteps; i++)
	{
		float dist = SceneSdf(start + direction * distance);

		float dsq = dist * dist;

		float y = dsq / (2 * ph);
		float d = sqrt(dsq - y * y);
		res = min(res, k*d / max(0.0000001, distance - y));
		ph = dist;
		distance += dist;

		maxSteps--;

		if (dist*maxSteps < 0.001)
			return 0;

	}
	return res;
}

float Softshadow2(float3 start, float3 direction, float mint, float maxt, float k, int maxSteps)
{
	float t = mint;
	float res = 1.0;
	for (int i = 0; i < maxSteps; i++)
	{
		float h = SceneSdf(start + t * direction);
		res = min(res, h / (k * t));
		t += clamp(h, 0.005, 0.50);
		if (res<-1.0 || t>maxt) break;
	}
	res = max(res, -1.0); // clamp to [-1,1]

	return 0.25 * (1.0 + res) * (1.0 + res) * (2.0 - res); // smoothstep
}


float Reflection(float3 start, float3 direction, float mint, float k, out float totalDist, out float3 pos, float maxSteps)
{

	float closest = mint;
	totalDist = mint;
	pos = start;
	float h = 999;
	
	for (int i = 0; i < maxSteps; i += 1)
	{
		pos = start + direction * totalDist;

		h = SceneSdf(pos);

		closest = min(h / totalDist, closest);

		if (h < 0.01)
			return 0.0;

		totalDist += h;
	}

	return  closest / mint;
}

float4 NormalAndDistance(float3 pos, float smoothness) {

	float EPSILON = 0.01f;

	float center = SceneSdf(pos, smoothness);

	float3 normal = normalize(float3(
		center - SceneSdf(float3(pos.x - EPSILON, pos.y, pos.z), smoothness),
		center - SceneSdf(float3(pos.x, pos.y - EPSILON, pos.z), smoothness),
		center - SceneSdf(float3(pos.x, pos.y, pos.z - EPSILON), smoothness)
		));

	return float4(normal, center);
}

float4 NormalAndDistance(float3 pos) {

	float EPSILON = 0.01f;

	float center = SceneSdf(pos);

	float3 normal = normalize(float3(
		center - SceneSdf(float3(pos.x - EPSILON, pos.y, pos.z)),
		center - SceneSdf(float3(pos.x, pos.y - EPSILON, pos.z)),
		center - SceneSdf(float3(pos.x, pos.y, pos.z - EPSILON))
		));

	return float4(normal, center);
}

float3 EstimateNormal(float3 pos, float smoothness) {

	float EPSILON = 0.01f;

	float center = SceneSdf(pos, smoothness);

	return normalize(float3(
		center - SceneSdf(float3(pos.x - EPSILON, pos.y, pos.z), smoothness),
		center - SceneSdf(float3(pos.x, pos.y - EPSILON, pos.z), smoothness),
		center - SceneSdf(float3(pos.x, pos.y, pos.z - EPSILON), smoothness)
		));
}
float3 EstimateNormal(float3 pos) 
{
	return EstimateNormal(pos, _RayMarchSmoothness);
}


float4 SdfNormalAndDistance(float3 pos, float smoothness) {

	float EPSILON = 0.01f;

	float center = SceneSdf(float3(pos.x, pos.y, pos.z), smoothness);

	return float4(normalize(float3(
		center - SceneSdf(float3(pos.x - EPSILON, pos.y, pos.z), smoothness),
		center - SceneSdf(float3(pos.x, pos.y - EPSILON, pos.z), smoothness),
		center - SceneSdf(float3(pos.x, pos.y, pos.z - EPSILON), smoothness)
		)), center);
}

float4 SdfNormalAndDistance(float3 pos)
{
	//_RayMarchSmoothness
	return SdfNormalAndDistance(pos, _RayMarchSmoothness);
}

float4 renderSdfProgression(in float3 ro, in float3 rd, float pixelScale)
{
	float totalDistance = 0;
	float dist = 0;

	for (int i = 0; i < 100; i++) {

		dist = SceneSdf(ro);

		float rng = pixelScale * totalDistance;

		if (dist < rng || dist > 9999)
		{
			i = 999;
		}
		else 
		{
			//dist -= rng;

			ro += dist * rd ;
			totalDistance += dist;
		}
	}

	return float4(EstimateNormal(ro), totalDistance);
}

float4 renderSdf(in float3 ro, in float3 rd, in float4 seed) {

	float dist = 0;

	float totalDistance = 0;

	float max_steps =
#if RT_MOTION_TRACING
		50;
#else
		_maxRayMarchSteps;
#endif

	for (int i = 0; i < max_steps; i++) {

		dist = SceneSdf(ro);

		ro += dist * rd;

		totalDistance += dist;

		if (dist < 0.01) 
		{
			i = 999;
		}
	}

	float3 normal = EstimateNormal(ro);

	float deDott = max(0, dot(-rd, normal));

	float dott = 1 - deDott;

	float3 lightSource = RayMarchLight_0.xyz;

	float3 toCenterVec = lightSource - ro;

	float toCenter = length(toCenterVec);

	float3 lightDir = normalize(toCenterVec);

	float lightRange = RayMarchLight_0_Size.x + 1;
	float deLightRange = 1 / lightRange;

	float lightBrightness = lightRange / (1 + toCenter); // max(0, lightRange - toCenter) * deLightRange;

	float deFog = saturate(1 - totalDistance / _MaxRayMarchDistance);
	deFog *= deFog;

	float precision = 1 + deFog * deFog * max_steps;

	float shadow = Softshadow(ro, lightDir, 5, _RayMarchShadowSoftness, precision);

	float toview = dot(normal, rd);

	float fresnel = smoothstep(-1, 1, 1 + toview);

	float3 reflected = -normalize(rd - 2 * (toview)*normal 
#if !RT_MOTION_TRACING
		+ (seed - 0.5) * 0.3 * pow(1 - fresnel, 2)
#endif
	); 

	float reflectedDistance;

	float3 reflectionPos;

	float reflectedSky = Reflection(ro, -reflected, 0.1, 1,	reflectedDistance, reflectionPos, precision);


	float lightRelected = smoothstep(0, 1 , dot(-reflected, lightDir));

	float3 reflectedNormal = EstimateNormal(reflectionPos);

	float reflectedDott = max(0, dot(reflected, reflectedNormal));

	float3 toCenterVecRefl = lightSource - reflectionPos;

	float toCenterRefl = length(toCenterVecRefl);

	float3 lightDirRef = normalize(toCenterVecRefl);

	float lightAttenRef = max(0, dot(lightDirRef, reflectedNormal));

	float reflectedShadow = 0;

	precision = 1 + precision * max(0, 1 - reflectedDistance / _MaxRayMarchDistance) * 0.5f;

	if (lightRange > toCenterRefl)
		reflectedShadow = Softshadow(reflectionPos, lightDirRef, 2,
			_RayMarchShadowSoftness, precision);

	float4 col = 1;

	float lightBrightnessReflected = max(0, lightRange - toCenterRefl) *deLightRange;


	col.rgb = RayMarchLight_0_Mat.rgb * shadow * lightBrightness;

	float reflectedFog = max(0, 1 - reflectedDistance / _MaxRayMarchDistance);

	float reflAmount = pow(deFog * reflectedFog, 1);

	reflectedFog *= reflAmount;

	reflectedSky = reflectedSky * (reflAmount)+(1 - reflAmount);

	lightBrightnessReflected *= reflAmount;

	float3 reflCol = (RayMarchLight_0_Mat.rgb * reflectedShadow * lightAttenRef * (lightBrightnessReflected + 1));


	float3 skyCol = getSkyColor(lerp( -rd, -reflected, saturate(reflectedSky)), 1);

	//return float4(skyCol,1);
	
	float3 fresnelReflection = //(1 + dott * 0.5)
		//*
		(reflCol * (1 - reflectedSky) +
			skyCol * reflectedSky +
			lightRelected * shadow
			);


	col.rgb = lerp(col.rgb, fresnelReflection, fresnel);


	col.rgb = lerp(skyCol, col.rgb, deFog);
	
	return 	max(0, col);

}

#endif