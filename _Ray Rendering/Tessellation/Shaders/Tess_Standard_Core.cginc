// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_STANDARD_CORE_INCLUDED
#define UNITY_STANDARD_CORE_INCLUDED

#include "Tess_Standard_Input.cginc"
#include "FreeTess_Tessellator.cginc"

#include "AutoLight.cginc"
//-------------------------------------------------------------------------------------
// counterpart for NormalizePerPixelNormal
// skips normalization per-vertex and expects normalization to happen per-pixel
half3 NormalizePerVertexNormal (float3 n) // takes float to avoid overflow
{
    #if (SHADER_TARGET < 30) || UNITY_STANDARD_SIMPLE
        return normalize(n);
    #else
        return n; // will normalize per-pixel instead
    #endif
}

float3 NormalizePerPixelNormal (float3 n)
{
    #if (SHADER_TARGET < 30) || UNITY_STANDARD_SIMPLE
        return n;
    #else
        return normalize((float3)n); // takes float to avoid overflow
    #endif
}


//-------------------------------------------------------------------------------------
// Common fragment setup


float3 PerPixelWorldNormal(float4 i_tex, float4 tangentToWorld[3])
{
#ifdef _NORMALMAP
    half3 tangent = tangentToWorld[0].xyz;
    half3 binormal = tangentToWorld[1].xyz;
    half3 normal = tangentToWorld[2].xyz;

    #if UNITY_TANGENT_ORTHONORMALIZE
        normal = NormalizePerPixelNormal(normal);

        // ortho-normalize Tangent
        tangent = normalize (tangent - normal * dot(tangent, normal));

        // recalculate Binormal
        half3 newB = cross(normal, tangent);
        binormal = newB * sign (dot (newB, binormal));
    #endif

    half3 normalTangent = NormalInTangentSpace(i_tex);
    float3 normalWorld = NormalizePerPixelNormal(tangent * normalTangent.x + binormal * normalTangent.y + normal * normalTangent.z); // @TODO: see if we can squeeze this normalize on SM2.0 as well
#else
    float3 normalWorld = normalize(tangentToWorld[2].xyz);
#endif
    return normalWorld;
}

#ifdef _PARALLAXMAP
    #define IN_VIEWDIR4PARALLAX(i) NormalizePerPixelNormal(half3(i.tangentToWorldAndPackedData[0].w,i.tangentToWorldAndPackedData[1].w,i.tangentToWorldAndPackedData[2].w))
    #define IN_VIEWDIR4PARALLAX_FWDADD(i) NormalizePerPixelNormal(i.viewDirForParallax.xyz)
#else
    #define IN_VIEWDIR4PARALLAX(i) half3(0,0,0)
    #define IN_VIEWDIR4PARALLAX_FWDADD(i) half3(0,0,0)
#endif

#if UNITY_REQUIRE_FRAG_WORLDPOS
    #if UNITY_PACK_WORLDPOS_WITH_TANGENT
        #define IN_WORLDPOS(i) half3(i.tangentToWorldAndPackedData[0].w,i.tangentToWorldAndPackedData[1].w,i.tangentToWorldAndPackedData[2].w)
    #else
        #define IN_WORLDPOS(i) i.posWorld
    #endif
    #define IN_WORLDPOS_FWDADD(i) i.posWorld
#else
    #define IN_WORLDPOS(i) half3(0,0,0)
    #define IN_WORLDPOS_FWDADD(i) half3(0,0,0)
#endif

float3 W2ONormal (float3 inNormal)
{
	return normalize(mul((float3x3)unity_WorldToObject, inNormal));
} 

void phongIt3 (inout float3 pos, float3 vp0, float3 vp1, float3 vp2, float3 vn0, float3 vn1, float3 vn2, float3 bary) {
	float3 phPos0 = dot(vp0.xyz - pos.xyz, vn0) * vn0;
	float3 phPos1 = dot(vp1.xyz - pos.xyz, vn1) * vn1;
	float3 phPos2 = dot(vp2.xyz - pos.xyz, vn2) * vn2;

	float3 vecOffset = bary.x * phPos0 + bary.y * phPos1 + bary.z * phPos2;

	pos += vecOffset * _Phong;
}

void phongIt4 (inout float4 pos, float4 vp0, float4 vp1, float4 vp2, float3 vn0, float3 vn1, float3 vn2, float3 bary) {
	vn0 = W2ONormal(vn0);
	vn1 = W2ONormal(vn1);
	vn2 = W2ONormal(vn2);

	float3 phPos0 = dot(vp0.xyz - pos.xyz, vn0) * vn0;
	float3 phPos1 = dot(vp1.xyz - pos.xyz, vn1) * vn1;
	float3 phPos2 = dot(vp2.xyz - pos.xyz, vn2) * vn2;

	float3 vecOffset = bary.x * phPos0 + bary.y * phPos1 + bary.z * phPos2;

	pos.xyz += vecOffset * _Phong;
}

#endif // UNITY_STANDARD_CORE_INCLUDED
