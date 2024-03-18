sampler2D_float _CameraDepthTexture;
//TEXTURE2D_X_FLOAT(_CameraDepthTexture);
float4 _CameraDepthTexture_TexelSize;


uniform float4x4 qc_MATRIX_VP;
uniform float4x4 qc_MATRIX_I_VP;

//Texture2D<float4> _CameraDepthTexture;
//SamplerState sampler_CameraDepthTexture;
float FetchCameraDepth(float2 uv)
{
    float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);//_CameraDepthTexture.Sample(sampler_CameraDepthTexture, GetFlippedUV(uv)).x;
#if !defined(UNITY_REVERSED_Z)
    depth = 1.0 - depth;
#endif
    return depth;
}


float3 WorldNormalToCameraNormal(float3 normal)
{
	float3 res = mul(qc_MATRIX_VP, normal);

//	res.b = 0.5;

	#if UNITY_UV_STARTS_AT_TOP
		res.y = -res.y;
	#endif
	return res;
}

float SampleTrueDepth(float3 viewDir, float2 screenUv)
{
	float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUv);
	float orthoToPresp = dot(-viewDir, -UNITY_MATRIX_V[2].xyz);	
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

float3 ReconstructWorldSpacePositionFromDepth(float2 uv, float deviceDepth)
{
	float4 positionCS = float4(uv * 2.0 - 1.0, deviceDepth, 1.0);
	#if UNITY_UV_STARTS_AT_TOP
		positionCS.y = -positionCS.y;
	#endif
	
	float4 hpositionWS = mul(qc_MATRIX_I_VP, positionCS);
	return hpositionWS.xyz / hpositionWS.w;
}