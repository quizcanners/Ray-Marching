// You can add/subtract sin(pos.x/y/y); but use: if  abs(dist)<0.1 
// abs(dist) - thickness to create a shell
float dot2(in float2 v) 
{ 
	return dot(v, v); 
}

float ndot(in float2 a, in float2 b) 
{ 
	return a.x * b.x - a.y * b.y;
}

float2 rotateV2(float2 p, float a) 
{
	float c = cos(a);
	float s = sin(a);

	p = mul(p, float2x2(c, s, -s, c));
	return p;
}

float3 RotateVec(in float3 vec, in float4 q)
{
	float3 crossA = cross(q.xyz, vec) + q.w * vec;
	vec += 2 * cross(q.xyz, crossA);

	return vec;
}

float4 GetGridAndSeed(float3 pos, float upscale, out float3 seed) 
{
	float4 result;

	float3 scaled = pos * upscale;

	result.xyz = ((scaled + 100) % 1);

	scaled -= result.xyz;
	
	result.xyz -= 0.5;

	seed = hash33(scaled);

	return result;
}

float3 GetFrid(float3 pos, float upscale) 
{
	return ((pos * upscale + 100) % 1) - 0.5;
}

// Sdf Functions
inline float Plane(float3 position) 
{
	return position.y;
}

inline float Plane(float3 rayOrigin, float3 direction)
{
	return dot(rayOrigin.y, direction);
}

inline float SphereDistance(float3 rayOrigin, float4 posNsize, float4 reps)
{
	return length(frac((rayOrigin - posNsize.xyz + reps.y)* reps.z) * reps.x - reps.y) - posNsize.w;
}

inline float SphereDistance(float3 rayOrigin, float4 posNsize) 
{
	return length(rayOrigin - posNsize.xyz) - posNsize.w;
}

inline float GridDistance(float3 p, float size, float thickness) 
{
	float halfSize = size * 0.5;

	float3 rem =  halfSize - abs(p % size);

	return min(min(length(rem.xy), length(rem.yz)) ,length(rem.xz))	- thickness;
}

float insideBox3D(float3 v, float3 center, float3 size)
{
	float3 bottomLeft = center - size;
	float3 topRight = center + size;
	float3 s = step(bottomLeft, v) - step(topRight, v);
	return s.x * s.y * s.z;
}

float sdfBox(float3 currentRayPosition, float3 boxPosition, float3 boxSize)
{
	float3 adjustedRayPosition = currentRayPosition - boxPosition;
	float3 distanceVec = abs(adjustedRayPosition) - boxSize;
	float maxDistance = max(distanceVec.x, max(distanceVec.y, distanceVec.z));
	float distanceToBoxSurface = min(maxDistance, 0.0) + length(max(distanceVec, 0.0));

	return distanceToBoxSurface;
}

inline float CubeDistance_Inernal(float3 p, float3 size)
{
	float3 q = abs(p) - size;
	return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float3 GetRotatedPos(float3 pos, float3 centerPos, float4 rotation)
{
	pos -= centerPos;
	pos = RotateVec(pos, rotation); 
	return pos;
}

#define ROTATE_APPLY(SDF_INTERNAL) \
float dist = SDF_INTERNAL(GetRotatedPos(p, posNsize.xyz, rotation), size) ; \

float3 GetTwistedPosition(in float3 p, in float k )
{
    float c = cos(k*p.y);
    float s = sin(k*p.y);
    float2x2  m = float2x2(c,-s,s,c);
    return float3(mul(m, p.xz),p.y);
}


inline float CubeDistanceRot(float3 p, float4 rotation , float4 posNsize, float3 size, float softness)
{
	size -= softness;
	ROTATE_APPLY(CubeDistance_Inernal);
	dist -= softness;

	return dist;
}

inline float CubeDistance(float3 p, float4 posNsize, float3 size, float softness) 
{
	size -= softness;
	p -= posNsize.xyz;
	float dist = CubeDistance_Inernal(p, size);
	dist -= softness;

//	p -= posNsize.xyz;
	//float3 q = abs(p) - size + softness;
//	float dist = length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - softness;

	return dist;
}

float CapsuleDistanceRot(float3 p, float4 rotation , float4 posNsize, float3 size)
{
	p -= posNsize.xyz;
	p = RotateVec(p, rotation);

	float len = size.y;
	float r = size.x;

    float3 pa = p - len;
	float3 ba = 2 * len;

	float dotBa = ba * ba * 3; //dot(ba, ba)

    float h = clamp(dot(pa, - ba) / dotBa 
	, 0.0, 1.0);
    return length(pa + ba * h) - r;
}

// Logic combinations
inline float CubicSmin(float a, float b, float k)
{
	float h = max(k - abs(a - b), 0.0) / (k + 0.0001);
	return min(a, b) - h * h*h*k*(1.0 / 6.0);
}

inline float SmoothIntersection(float d1, float d2, float k) 
{
	float h = saturate(0.5 - 0.5 * (d2 - d1) / k);
	return lerp(d2, d1, h) + k * h * (1.0 - h);
}


inline float OpSmoothSubtraction(float d1, float d2, float k) 
{
	float h = saturate((1 - (d2 + d1) / (k + 0.0001))*0.5);
	return lerp(d1, -d2, h) + k * h * (1 - h);
}

inline float DifferenceSDF(float distA, float distB) 
{
	return max(distA, -distB);
}
