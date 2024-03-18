#include "Savage_Sampler_Tracing.cginc"
#include "Savage_DepthSampling.cginc"
#include "Assets/Qc_Rendering/Shaders/Savage_Shadowmap.cginc"
#include "Savage_Sampler_VolumetricFog.cginc"

#define BLOOD_SPECULAR 0.9


float _GridSize_Col;
float _GridSize_Row;
				
float2 FrameToUv (float frameIndex)
{
    float row = frameIndex % _GridSize_Row;
    float column = floor(frameIndex / _GridSize_Row);
    float2 uv = (float2(row, column)) / float2(_GridSize_Row, _GridSize_Col);
    uv.y = 1-uv.y;
    return uv;
}


void SetupBlend(float2 uv, float frame01, out float4 texcoord, out float2 texcoordInternal, out float blending)
{
    frame01 *= 0.99; // = UNITY_ACCESS_INSTANCED_PROP(Props, _Frame)*0.99;
    float maxFrames = _GridSize_Col * _GridSize_Row;
    float frame = frame01 * maxFrames;
    float firstFrame = floor(frame);
    float secondFrame = min(maxFrames - 1, firstFrame + 1);
                    
                    
    texcoord.xy = FrameToUv(firstFrame);
    texcoord.zw =FrameToUv(secondFrame); 

    float2 deGrid = 1 / float2(_GridSize_Col, _GridSize_Row);

    texcoordInternal =  uv * deGrid;
    texcoordInternal.y = - texcoordInternal.y;

    blending = frame - firstFrame;
}


float3 ClipToWorldPos(float4 clipPos)
{
#ifdef UNITY_REVERSED_Z
	// unity_CameraInvProjection always in OpenGL matrix form
	// that doesn't match the current view matrix used to calculate the clip space
 
	// transform clip space into normalized device coordinates
	float3 ndc = clipPos.xyz / clipPos.w;
 
	// convert ndc's depth from 1.0 near to 0.0 far to OpenGL style -1.0 near to 1.0 far
	ndc = float3(ndc.x, ndc.y * _ProjectionParams.x, (1.0 - ndc.z) * 2.0 - 1.0);
 
	// transform back into clip space and apply inverse projection matrix
	float3 viewPos =  mul(unity_CameraInvProjection, float4(ndc * clipPos.w, clipPos.w));
#else
	// using OpenGL, unity_CameraInvProjection matches view matrix
	float3 viewPos = mul(unity_CameraInvProjection, clipPos);
#endif
 
	// transform from view to world space
	return mul(unity_MatrixInvV, float4(viewPos, 1.0)).xyz;
}

float4 GetBillboardPos(float3 v_vertex)
{
	float3x3 m = UNITY_MATRIX_M;
    float objectScale = length(float3( m[0][0], m[1][0], m[2][0]));
                    
    return mul(UNITY_MATRIX_P,
	mul(UNITY_MATRIX_MV, float4(0.0, 0.0, 0.0, 1.0))
	+ float4(v_vertex.x, v_vertex.y, 0.0, 0.0)
    * float4(objectScale, objectScale, 1.0, 1.0)
    );
}

float4 GetBillboardPos(float3 v_vertex, out float3 worldPos)
{
	float4 clipPos = GetBillboardPos(v_vertex); 
	worldPos = ClipToWorldPos(clipPos);
	return clipPos;
}


float GetSoftParticleFade(float2 screenUV, float screenPosZ, float3 worldPos, float invFade, out float distToCamera)
{
	float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
	float sceneZ = LinearEyeDepth(UNITY_SAMPLE_DEPTH(depth));
	//float partZ = i.screenPos.z;
	float differ = sceneZ - screenPosZ;
	float fade = smoothstep(0,1, invFade * (sceneZ - screenPosZ));

	distToCamera = length(_WorldSpaceCameraPos - worldPos);
	float nearCamFade = smoothstep(0,1, distToCamera- _ProjectionParams.y);

	return fade * nearCamFade;
}

float3 GetPointLight_Transpaent(float3 position, float3 viewDir, float alpha)
{
	if (_qc_PointLight_Color.a==0)
	{
		return 0;
	}

	float3 lightDir = _qc_PointLight_Position.xyz - position;

	float distance = length(lightDir);

	lightDir = normalize(lightDir);

	float2 MIN_MAX = float2(0.0001, distance);

	bool isHit = Raycast(position , lightDir, MIN_MAX);

	if (isHit)
		return 0;
	
	float dott = dot(viewDir, lightDir);

	float direct = smoothstep(0, 1, dott);
	float backLight = smoothstep(0, -1, dott);

	float effect = lerp(pow(backLight,2)*3, direct, alpha);

	float distFade = 1/distance;
	float distSquare =  distFade * distFade;

	float3 col = _qc_PointLight_Color.rgb * effect * distSquare;

	return col;

}

float3 TransparentLightStandard(float4 tex, float3 worldPos, float3 normal, float3 viewDir, float shadow)
{
	float3 ambientCol = SampleVolume_CubeMap(worldPos, normal);

	TOP_DOWN_SETUP_UV(topdownUv, worldPos);
	float4 topDownAmbient = SampleTopDown_Ambient(topdownUv, viewDir, worldPos);
	float ao = topDownAmbient.a;
	ambientCol += topDownAmbient.rgb;


	float3 bakeStraight = SampleVolume_CubeMap(worldPos, -viewDir);
	bakeStraight += GetTranslucent_Sun(-viewDir) * shadow; 
	float4 tdSpec = SampleTopDown_Specular(topdownUv, -normal, worldPos, normal,0.5);
	bakeStraight.rgb += tdSpec.rgb * 2;


	ambientCol = lerp(bakeStraight, ambientCol, tex.a);

	float toSunAttenuation = smoothstep(0,1, dot(normal, _WorldSpaceLightPos0));


	ambientCol += GetPointLight_Transpaent(worldPos, viewDir, tex.a);


	return 	tex.rgb * ambientCol * ao + shadow * lerp(1, toSunAttenuation, tex.a) * GetDirectional();
}

float3 GetRayTraceSmooth(float3 position, float3 ray)
{
	return GetRayTrace_AndAo(position, ray, BLOOD_SPECULAR);
}

float GetShadowVolumetric(float3 pos, float depth, float3 viewDir)
{

	float3 off = viewDir * 0.1;
	float shadow = 
		GetSunShadowsAttenuation(pos - off, depth) + 
		GetSunShadowsAttenuation(pos + off, depth);

	return shadow * 0.5;
}

float4 GetTraced_Glassy_Vertex(float3 worldPos, float3 viewDir, float3 normal)
{
	float4 traced;
	traced.a = GetQcShadow(worldPos);

	float3 volumeSamplePosition = worldPos + normal*0.01;
	float fresnel = GetFresnel(normal, viewDir); // Will flip normal if backfacing 

	float ao = 1;

	float3 reflectedRay = reflect(-viewDir, normal);
	float3 bakeReflected = GetRayTraceSmooth(volumeSamplePosition, reflectedRay);//SampleReflection(i.worldPos, viewDir, normal, shadow, hit);
	
	float3 refractedRay =  refract(-viewDir, normal, 0.75);//normalize(-viewDir - normal * 0.2);
	float3 bakeStraight = GetRayTraceSmooth(volumeSamplePosition, refractedRay);

	float showStright = (1 - fresnel);

	traced.rgb = lerp(bakeReflected.rgb, bakeStraight.rgb, showStright * showStright);

	return traced;
}


float GetTranslucentTracedShadow(float3 pos, float3 refractedRay, float depth)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	if (_qc_SunVisibility == 0)
		return 0;

	return 1;

	//refractedRay *= depth;

	 //return
	//	(SampleRayShadow(pos + refractedRay *  0.3)
	//	+ SampleRayShadow(pos + refractedRay * 0.6)
	//	+ SampleRayShadow(pos + refractedRay * 0.9)) * 0.333;
}



float4 GetTraced_AlphaBlitted_Vertex(float3 worldPos, float3 viewDir)
{
	float4 traced;
	traced.a = GetQcShadow(worldPos);
	traced.rgb = SampleVolume_CubeMap(worldPos, viewDir);

	#if _PER_PIXEL_REFLECTIONS_MIXED || _PER_PIXEL_REFLECTIONS_INVERTEX
		float ao = 1;
		float3 bakeStraight = GetRayTraceSmooth(worldPos, -viewDir);
		traced.rgb = (traced.rgb + bakeStraight.rgb) * 0.5;
	#endif

	return traced;
}

float4 MotionVectorsVertex(float intensity, float blend, float2 deGrid)
{
	float2 strength = intensity * deGrid; // columns, rows
	float4 result;
	result.xy = -strength * blend;
	result.zw = strength * (1.0 - blend);

	return result;
}

void OffsetByMotionVectors(inout float2 uvCurrent, inout float2 uvNext, float4 motionVectorSampling, sampler2D map)
{
	float2 currentFrameMotionUV = tex2D(map, uvCurrent).rg * 2.0 - 1.0;
	float2 nextFrameMotionUV = tex2D(map, uvNext).rg * 2.0 - 1.0;

	uvCurrent += currentFrameMotionUV * motionVectorSampling.xy;
	uvNext += nextFrameMotionUV * motionVectorSampling.zw;
}
