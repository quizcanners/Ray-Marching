static const float GAMMA_TO_LINEAR = 2.2;
static const float LINEAR_TO_GAMMA = 1 / GAMMA_TO_LINEAR;

uniform float _RayTraceDofDist;
uniform float _RayTraceDOF;
uniform sampler2D _RayTracing_SourceBuffer;
uniform float4 _RayTracing_SourceBuffer_ScreenFillAspect;

uniform float _RayTraceTransparency;

uniform float4 _RayTracing_TargetBuffer_ScreenFillAspect;




uniform sampler2D _RayMarchingVolume;
uniform sampler2D _qcPp_DestBuffer;
uniform float4 _RayMarchingVolumeVOLUME_POSITION_N_SIZE;
uniform float4 _RayMarchingVolumeVOLUME_H_SLICES;
uniform float4 _RayMarchingVolumeVOLUME_POSITION_OFFSET;

uniform float _MaxRayMarchDistance;
float _maxRayMarchSteps;
float _RayMarchSmoothness;
float _RayMarchShadowSoftness;



float gpuIndepentHash(float p) {
	p = (p * 0.1031) % 1;
	p *= p + 19.19;
	p *= p + p;
	return p % 1;
}

float3 Pallete(in float t, in float3 a, in float3 b, in float3 c, in float3 d) {
	return a + b * cos(6.28318530718*(c*t + d));
}

float checkerBoard(float2 p) {
	return abs((floor(p.x) + floor(p.y)) % 2);
}
