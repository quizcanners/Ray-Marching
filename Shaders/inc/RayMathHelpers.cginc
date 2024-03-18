#ifndef QC_RMTH
#define QC_RMTH
static const float GAMMA_TO_LINEAR = 2.2;
static const float LINEAR_TO_GAMMA = 1 / GAMMA_TO_LINEAR;

float dot2(in float3 v) { return dot(v, v); }

float3 Rotate (in float3 vec, in float4 q)
{
	float3 crossA = cross(q.xyz, vec) + q.w * vec;
	vec += 2 * cross(q.xyz, crossA);	
	return vec;
}

float3 hash33(float3 p3)
{
	p3 = (p3 * float3(.1031, .11369, .13787)) % 1;
	p3 += dot(p3, p3.yxz + 19.19);
	return -1.0 + 2.0 * ((float3((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y, (p3.y + p3.z) * p3.x)) % 1);
}

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

float sharpstep(float a, float b, float x) 
{
	return saturate((x - a)/(b - a));
}
#endif