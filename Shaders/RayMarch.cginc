
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

	float3 q = abs(p) - size;

	float dist = length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - softness;

	return dist;
}

inline float Mix(float a, float b, float p) {
	return a * (1 - p) + b * p;
}

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

inline bool IntersectSphere(float3 center, float3 orig, float3 dir, float radius2) 
{
	float t0, t1; // solutions for t if the ray intersects 

		// geometric solution
	float3 L = center - orig;
	float tca = dot(L, dir);
	// if (tca < 0) return false;
	float d2 = dot(L, L) - tca * tca;
	if (d2 > radius2) 
		return false;

	float thc = sqrt(radius2 - d2);
	t0 = tca - thc;
	t1 = tca + thc;

	/*if (t0 > t1) {
		float tmp = t0;
		t0 = t1;
		t1 = tmp;
	}

	if (t0 < 0) {
		t0 = t1; // if t0 is negative, let's use t1 instead 
		if (t0 < 0) return false; // both t0 and t1 are negative 
	}

	t = t0;*/

	return true;
}