// You can add/subtract sin(pos.x/y/y); but use: if  abs(dist)<0.1 
// abs(dist) - thickness to create a shell

// Sdf Functions
inline float Plane(float3 position) {
	return position.y;
}

inline float Plane(float3 position, float3 direction) {
	return dot(position.y, direction);
}

inline float SphereDistance(float3 position, float4 posNsize, float4 reps) {

	return length(frac((position - posNsize.xyz + reps.y)* reps.z) * reps.x - reps.y) - posNsize.w;
}

inline float SphereDistance(float3 position, float4 posNsize) {
	return length(position - posNsize.xyz) - posNsize.w;
}

inline float GridDistance(float3 p, float size, float thickness) {

	float halfSize = size * 0.5;

	float3 rem =  halfSize - abs(p % size);

	return min(
		min(
			length(rem.xy),
			length(rem.yz)
		)
		,length(rem.xz)
	) 
		- thickness;
}

inline float CubeDistance(float3 p, float4 posNsize, float3 size, float softness) {

	p -= posNsize.xyz;

	float3 q = abs(p) - size + softness;

	float dist = length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - softness;

	return dist;
}

// Logic combinations
inline float CubicSmin(float a, float b, float k)
{
	float h = max(k - abs(a - b), 0.0) / (k + 0.0001);
	return min(a, b) - h * h*h*k*(1.0 / 6.0);
}

inline float OpSmoothSubtraction(float d1, float d2, float k) {

	float h = saturate((1 - (d2 + d1) / (k + 0.0001))*0.5);

	return Mix(d1, -d2, h) + k * h * (1 - h);
}

inline float DifferenceSDF(float distA, float distB) {
	return max(distA, -distB);
}
