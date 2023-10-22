sampler2D Qc_CameraDepthTextureLowRes;
sampler2D Qc_AmbientOcclusionTexture;

float GetAmbientOccusion(float2 screenUV, float3 viewDir, float3 worldPos)
{
	float depth = tex2Dlod(Qc_AmbientOcclusionTexture, float4(screenUV,0,0));
	//float3 newPos = GetRayPointFromDepth(depth, viewDir);

	float orthoToPresp = dot(-viewDir, -UNITY_MATRIX_V[2].xyz);					
	float smoothedDepth = Linear01Depth(depth) * _ProjectionParams.z / orthoToPresp;	
	//float3 rd = -viewDir;														
	//float3 ro = _WorldSpaceCameraPos.xyz;										
	//return ro + depth * rd;		

	float diff = length(_WorldSpaceCameraPos - worldPos) - smoothedDepth;

	return smoothstep(0, 0.25, diff); // * smoothstep(0.3, 0.25, diff) ;
}