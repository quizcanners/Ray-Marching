#include "Lighting.cginc"

uniform sampler2D _Global_Noise_Lookup;
uniform sampler3D _Global_Noise_Lookup3D;



#define TRANSFER_WTANGENT(o) o.wTangent.xyz = UnityObjectToWorldDir(v.tangent.xyz); o.wTangent.w = v.tangent.w * unity_WorldTransformParams.w;

#define TRANSFER_TANGENT_VIEW_DIR(o) \
float3x3 objectToTangent = float3x3(v.tangent.xyz,cross(v.normal, v.tangent.xyz) * v.tangent.w,v.normal);\
o.tangentViewDir = mul(objectToTangent, ObjSpaceViewDir(v.vertex));\

#define PrimitiveLight(directional, ambient, outOfBounds, pos, normal)\
	float  outOfBounds;\
	float4 vol = SampleVolume(pos, outOfBounds);\
	float3 ambient = lerp(vol, 0.5, outOfBounds);\
	float direct = saturate((dot(normal, _WorldSpaceLightPos0.xyz)));\
	float3 directional = GetDirectional() * direct; \
	
float2 Rotate(float2 uv, float angle) 
{
	float si = sin(angle);
	float co = cos(angle);
	return float2(co * uv.x - si * uv.y, si * uv.x + co * uv.y);
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

float4 Noise3D(float3 pos)
{
	return tex3Dlod(_Global_Noise_Lookup3D, float4(pos,0));
}

float4 LerpTransparent(float4 col1, float4 col2, float transition)
{
    float4 col;
    col.rgb = lerp(col1.rgb * col1.a, col2.rgb * col2.a, transition);
    col.a = lerp(col1.a, col2.a, transition);
    col.rgb /= col.a + 0.001;
    return col;
}

float4 BlendTransparent(float4 col1, float4 col2)
{	
	float4 col;
	col.rgb = lerp(col1.rgb * col1.a, col2.rgb, col2.a);
	col.a = lerp(col1.a, 1, col2.a); 
	col.rgb /= col.a + 0.001;
	return col;
}


// To Output shadow from Shadow Pass
float calculateShadowDepth(float3 worldPos)
{
	float4 projPos = mul(UNITY_MATRIX_VP, float4(worldPos, 1));
	projPos = UnityApplyLinearShadowBias(projPos);
	return projPos.z / projPos.w;
}

// To output depth from fragment function
float calculateFragmentDepth(float3 worldPos)
{
	float4 depthVec = mul(UNITY_MATRIX_VP, float4(worldPos, 1.0));
	return depthVec.z / depthVec.w;
}

// from http://www.java-gaming.org/index.php?topic=35123.0
float4 cubic_Interpolation(float v) 
{
	float4 n = float4(1.0, 2.0, 3.0, 4.0) - v;
	float4 s = n * n * n;
	float x = s.x;
	float y = s.y - 4.0 * s.x;
	float z = s.z - 4.0 * s.y + 6.0 * s.x;
	float w = 6.0 - x - y - z;
	return float4(x, y, z, w) * (1.0 / 6.0);
}

float GetAngle01 (float2 uv)
{
	const float PI2 = 3.14159265359 *2;
	return atan2(uv.x, uv.y)/ PI2 + 0.5;
}
