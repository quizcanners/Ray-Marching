sampler2D_float _CameraDepthTexture;

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