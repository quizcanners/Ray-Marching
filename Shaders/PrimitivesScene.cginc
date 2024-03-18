#ifndef QC_RTX_PRIM
#define QC_RTX_PRIM

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
uniform float4 RayMarchCube_BoundSize_All; // W - box count

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
uniform float4 qc_SunBackDirection; // Direction, same as _WorldSpaceLightPos0.xyz
uniform float4 _qc_AmbientColor;
uniform float _qc_SunVisibility;
uniform float4 _qc_SunColor;
//_qc_USE_SUN

uniform sampler2D _qcPp_DestBuffer;

#define MAX_VOLUME_ALPHA 10500//1e10
#define LAMBERTIAN 0.
#define METAL 1.
#define DIELECTRIC 2.
#define GLASS 3.
#define EMISSIVE 4.
#define SUBTRACTIVE 5.



inline float3 GetAmbientLight()
{
	return _qc_AmbientColor.rgb;
}

float3 SampleSkyBox(float3 rd)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	//rd.y = -abs(rd.y);

	return lerp(texCUBElod(Qc_SkyBox, float4(rd,0)).rgb, GetAmbientLight(), _qc_AmbientColor.a);
}

float3 SampleSkyBox(float3 rd, float smoothness)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	rd.y = -abs(rd.y);

	return lerp(texCUBElod(Qc_SkyBox, float4(rd,(1-smoothness) * 5)).rgb, GetAmbientLight(), _qc_AmbientColor.a);
}

// Scenes


#endif