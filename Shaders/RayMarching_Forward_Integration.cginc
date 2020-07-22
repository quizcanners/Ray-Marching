//#include "Assets/The-Fire-Below/Common/Shaders/quizcanners_cg.cginc"

sampler2D_float _CameraDepthTexture;

struct appdata
{
	float4 vertex : POSITION;
};


struct FragColDepth
{
	float4 col: SV_Target;
	float depth : SV_Depth;
};

struct v2fMD
{
	float4 vertex : SV_POSITION;
	float3 rayDir: TEXCOORD0;
	float3 rayPos: TEXCOORD1;
	float4 centerPos: TEXCOORD2;
};

// Color Part

float4 PositionAndSizeFromMatrix()
{
	float4 posNSize;
	posNSize.xyz = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));	

	float3 scale = float3(										
		length(unity_ObjectToWorld._m00_m10_m20),				
		length(unity_ObjectToWorld._m01_m11_m21),				
		length(unity_ObjectToWorld._m02_m12_m22));	
	
	posNSize.w = min(scale.z, min(scale.x, scale.y));

	return posNSize;
}


float SampleTrueDepth(float3 viewDir, float2 screenUv)
{
	float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUv);		\		
	float orthoToPresp = dot(-viewDir, -UNITY_MATRIX_V[2].xyz);				\		
	depth = Linear01Depth(depth) * _ProjectionParams.z / orthoToPresp;	
	return depth;
}


float3 GetRayPoint(float3 viewDir, float2 screenUv)
{
	float depth = SampleTrueDepth(viewDir, screenUv);							
	float3 rd = -viewDir;														
	float3 ro = _WorldSpaceCameraPos.xyz;										
	return ro + depth * rd;											
}

float3 GetRayPointFromDepth(float depth, float3 viewDir)
{
	float orthoToPresp = dot(-viewDir, -UNITY_MATRIX_V[2].xyz);				\		
	depth = Linear01Depth(depth) * _ProjectionParams.z / orthoToPresp;	
	float3 rd = -viewDir;														
	float3 ro = _WorldSpaceCameraPos.xyz;										
	return ro + depth * rd;		
}

#define MARCH_FROM_DEPTH(NEW_POS, SPHERE_POS, SHADOW, VIEW_DIR, SCREEN_UV)	\
float3 VIEW_DIR = normalize(i.viewDir.xyz); 								\
float2 SCREEN_UV = i.screenPos.xy / i.screenPos.w;							\
float3 NEW_POS = GetRayPoint(VIEW_DIR, SCREEN_UV);  						\
float4 SPHERE_POS = i.centerPos;											\
float dist = SampleSDF(NEW_POS, SPHERE_POS);								\
clip(0.02 - dist);															\
float SHADOW = getShadowAttenuation(NEW_POS);								


#define MARCH_FROM_DEPTH_ROT(NEW_POS, SPHERE_POS, SHADOW, VIEW_DIR, SCREEN_UV)	\
float3 VIEW_DIR = normalize(i.viewDir.xyz); 								\
float2 SCREEN_UV = i.screenPos.xy / i.screenPos.w;							\
float3 NEW_POS = GetRayPoint(VIEW_DIR, SCREEN_UV);							\
float4 SPHERE_POS = i.centerPos;											\
float dist = SampleSDF(NEW_POS, SPHERE_POS, i.meshQuaternion, i.meshSize);	\
clip(0.02 - dist);															\
float SHADOW = getShadowAttenuation(NEW_POS);	

// Depth part


inline float3 GetRayDir(float3 worldPos)
{
	if (_WorldSpaceLightPos0.w > 0)										
		return worldPos.xyz - _WorldSpaceLightPos0.xyz;				
	else 
	{			
		if ((unity_OrthoParams.w > 0) || ((UNITY_MATRIX_P[3].x == 0.0) && (UNITY_MATRIX_P[3].y == 0.0) && (UNITY_MATRIX_P[3].z == 0.0))) 
			return -UNITY_MATRIX_V[2].xyz;							
		else
			return worldPos - _WorldSpaceCameraPos;
		
	}						
}

inline void GetRayOrigin(float3 worldPos, float size, out float3 payPos, out float3 rayDir)
{

	if (_WorldSpaceLightPos0.w > 0)		
	{
		rayDir = worldPos.xyz - _WorldSpaceLightPos0.xyz;	
		payPos = worldPos - rayDir;// * size;
	}
	else 
	{			
		if ((unity_OrthoParams.w > 0) || ((UNITY_MATRIX_P[3].x == 0.0) && (UNITY_MATRIX_P[3].y == 0.0) && (UNITY_MATRIX_P[3].z == 0.0))) 
		{
			rayDir = -UNITY_MATRIX_V[2].xyz;	
			payPos = worldPos - rayDir * size;
		}
		else
		{
			rayDir = worldPos - _WorldSpaceCameraPos;

			
			// Depth Marcher doesn't like normalizing
			payPos = _WorldSpaceCameraPos; // worldPos - rayDir;// * size;
		}
	}		
	

	
	//float3 rayNorm = normalize(rayDir);	
	
}


#define INITIALIZE_DEPTH_MARCHER(o)										\
    o.vertex = UnityObjectToClipPos(v.vertex);							\
	float3 worldPos = mul(unity_ObjectToWorld, v.vertex);				\
	o.centerPos = PositionAndSizeFromMatrix();							\
	GetRayOrigin(worldPos, o.centerPos.w, o.rayPos, o.rayDir); 
	
	
	
	// worldPos - o.rayDir * o.centerPos.w;//GetFurtherestPoint(worldPos, worldPos - rayNorm * o.centerPos.w, _WorldSpaceCameraPos + _ProjectionParams.y * rayNorm); 
	// worldPos - o.rayDir * o.centerPos.w;						

 
#define MARCH_INTERNAL(POS, SDF_FUNCTION, RO, RD, OBJECT, MAX_DIST)		\
float dist = 0;															\
float3 POS = RO;														\
for (int ind = 0; ind < 256; ind++) {									\
	float step = SDF_FUNCTION(POS, OBJECT);								\
	dist += step;														\
	POS = RO + dist * RD;												\
	if (step < 0.01 || dist > MAX_DIST) {								\
		clip(MAX_DIST - dist);											\ 
		break;															\
	}																	\
}	

#define MARCH_INTERNAL_ROT(POS, SDF_FUNCTION, RO, RD, OBJECT, ROT, SIZE, MAX_DIST)		\
float dist = 0;															\
float3 POS = RO;														\
for (int ind = 0; ind < 256; ind++) {									\
	float step = SDF_FUNCTION(POS, OBJECT, ROT, SIZE);								\
	dist += step;														\
	POS = RO + dist * RD;												\
	if (step < 0.005 || dist > MAX_DIST) {								\
		clip(MAX_DIST - dist);											\ 
		break;															\
	}																	\
}	


#define MARCH_DEPTH_ROT(SDF_FUNCTION)									\
i.rayDir = normalize(i.rayDir);											\
float3 ro = i.rayPos + _ProjectionParams.y * i.rayDir;					\
float3 rd = i.rayDir;													\
float4 spherePos = i.centerPos;											\
float max_distance = length(ro - spherePos.xyz) + i.centerPos.w;		\
MARCH_INTERNAL_ROT(newPos, SDF_FUNCTION, ro, rd, spherePos, i.meshQuaternion, i.meshSize, max_distance);	\
return calculateShadowDepth(newPos);


#define MARCH_DEPTH(SDF_FUNCTION)\
i.rayDir = normalize(i.rayDir);\
float3 ro = i.rayPos + _ProjectionParams.y * i.rayDir;\
float3 rd = i.rayDir;\
float4 spherePos = i.centerPos;\
float max_distance = length(ro - spherePos.xyz) + i.centerPos.w;\
MARCH_INTERNAL(newPos, SDF_FUNCTION, ro, rd, spherePos, max_distance); \
return calculateShadowDepth(newPos);


#define RAYMARCH_WORLD(SDF_FUNCTION, POS, VIEW_DIR, DEPTH, TARGET)\
	float3 ro = _WorldSpaceCameraPos.xyz;\
	float RM_DIST = 0;\
	float3 rd = -VIEW_DIR;\
	float maxDist = min(DEPTH, length(ro - TARGET.xyz) + TARGET.w);\
MARCH_INTERNAL(POS, SDF_FUNCTION, ro, rd, TARGET, maxDist); \
	

struct v2fMarchBatchable 
{
	float4 vertex: SV_POSITION;
	float4 meshSize : TEXCOORD0; // w - minimal size
	float4 meshQuaternion : TEXCOORD1;
	float3 rayPos: TEXCOORD2; 
	float3 rayDir: TEXCOORD3;
	float4 centerPos: TEXCOORD4; // w - maximum size (bounding)
};

void InitializeBatchableMarcher(appdata_full v, inout v2fMarchBatchable o)
{
	 o.vertex = UnityObjectToClipPos(v.vertex);							
				
	float3 worldPos = mul(unity_ObjectToWorld, v.vertex);			
				
	float3 meshPos = v.texcoord.xyz;
	o.meshSize = v.texcoord1;
	o.meshQuaternion = v.texcoord2;

	float size = max(o.meshSize.z, max(o.meshSize.x, o.meshSize.y));

	o.centerPos = float4(meshPos, size);	
				
	o.meshSize.w = min(o.meshSize.z, min(o.meshSize.x, o.meshSize.y));

//	o.rayDir = GetRayDir(worldPos);
//	o.rayPos = worldPos - o.rayDir * size;			
	

	GetRayOrigin(worldPos, size, o.rayPos, o.rayDir);

}


