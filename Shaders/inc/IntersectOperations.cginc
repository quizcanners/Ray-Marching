
// Ray Tracing - Primitives. Created by Reinder Nijhoff 2019
// The MIT License
// @reindernijhoff
//
// https://www.shadertoy.com/view/tl23Rm
//
// I wanted to create a reference shader similar to "Raymarching - Primitives" 
// (https://www.shadertoy.com/view/Xds3zN), but with ray-primitive intersection 
// routines instead of sdf routines.
// 
// As usual, I ended up mostly just copy-pasting code from Íñigo Quílez: 
// 
// http://iquilezles.org/www/articles/intersectors/intersectors.htm
// 
// Please let me know if there are other routines that I should add to this shader.
// 
// Sphere:          https://www.shadertoy.com/view/4d2XWV
// Box:             https://www.shadertoy.com/view/ld23DV
// Capped Cylinder: https://www.shadertoy.com/view/4lcSRn
// Torus:           https://www.shadertoy.com/view/4sBGDy
// Capsule:         https://www.shadertoy.com/view/Xt3SzX
// Capped Cone:     https://www.shadertoy.com/view/llcfRf
// Ellipsoid:       https://www.shadertoy.com/view/MlsSzn
// Rounded Cone:    https://www.shadertoy.com/view/MlKfzm
// Triangle:        https://www.shadertoy.com/view/MlGcDz
// Sphere4:         https://www.shadertoy.com/view/3tj3DW
// Goursat:         https://www.shadertoy.com/view/3lj3DW
// Rounded Box:     https://www.shadertoy.com/view/WlSXRW
//
// Disk:            https://www.shadertoy.com/view/lsfGDB
//

#define MAX_DIST 10000//1e10
#define MAX_DIST_EDGE MAX_DIST - 10//1e10


float dot2(in float3 v) { return dot(v, v); }

// Plane 
float iPlane(in float3 ro, in float3 rd, in float2 distBound, inout float3 normal,
	in float3 planeNormal//, in float planeDist
) {
	
	float a = dot(rd, planeNormal);

	if (a > 0)
		return MAX_DIST;

	float d = -(dot(ro, planeNormal) //+ planeDist
		) / a;

	if (d < distBound.x || d > distBound.y) {
		
		return MAX_DIST;
	}
	else 
	{
		normal = planeNormal;////(a > 0.) ? -planeNormal : planeNormal;//Now will only work from above;
		return d;
	}
}

bool isPlane(in float3 ro, in float3 rd, in float3 planeNormal, in float2 distBound)
{
	float a = dot(rd, planeNormal);

	if (a > 0)
		return false;

	float d = -(dot(ro, planeNormal)) / a;

	return (d >= distBound.x && d < distBound.y);
}

float3 hitPlane(in float3 ro, in float3 rd, in float3 planePosition, in float3 planeNormal)// in float planeDist
 {
	ro -= planePosition;

	float a = dot(rd, planeNormal);

	float d = -(dot(ro, planeNormal) //+ planeDist
		) / a;
	return ro + planePosition + rd*d;
}

/*
// Sphere:          https://www.shadertoy.com/view/4d2XWV
float iSphere(in float3 Origin, in float3 Dir, in float2 distBound, inout float3 normal, float Radius)
{
	float VoV = dot(Dir, Dir);

	float Acc = VoV * Radius * Radius;
	Acc += 2.0 * Origin.x * dot(Origin.yz, Dir.yz) * Dir.x;
	Acc += 2.0 * Origin.y * Origin.z * Dir.y * Dir.z;
	Acc -= dot(Origin * Origin, float3(dot(Dir.yz, Dir.yz), dot(Dir.xz, Dir.xz), dot(Dir.xy, Dir.xy)));

	if (Acc < 0.0)
	{
		return -1.0;
	}

	Acc = sqrt(Acc);

	float Dist1 = (Acc - dot(Origin, Dir)) / VoV;
	float Dist2 = -(Acc + dot(Origin, Dir)) / VoV;

	if (Dist1 >= 0.0 && Dist2 >= 0.0)
	{
		normal = normalize(Origin + Dir * Dist1);
		return min(Dist1, Dist2);
	}
	else
	{
		normal = normalize(Origin + Dir * Dist2);
		return max(Dist1, Dist2);
	}
}
*/

// Sphere:          https://www.shadertoy.com/view/4d2XWV
float iSphere(in float3 ro, in float3 rd, in float2 distBound, inout float3 normal,	float sphereRadius) 
{
	float b = dot(ro, rd);
	float c = dot(ro, ro) - sphereRadius * sphereRadius;
	float h = b * b - c;

	if (h <= 0)
		return MAX_DIST;

	h = sqrt(h);
	float d1 = -b - h;
	float d2 = -b + h;
	if (d1 >= distBound.x && d1 <= distBound.y) 
	{
		normal = normalize(ro + rd * d1);
		return d1;
	}
	 
	if (d2 >= distBound.x && d2 <= distBound.y) 
	{
		normal = -normalize(ro + rd * d2);
		return d2;
	}
	 
	return MAX_DIST;
}

bool isHitSphere(in float3 ro, in float3 rd, float sphereRadius, in float2 distBound)
{
	float b = dot(ro, rd);
	float c = dot(ro, ro) - sphereRadius * sphereRadius;
	float h = b * b - c;

	if (h < 0.)
		return false;
	
	h = sqrt(h);
	float d1 = -b - h;
	float d2 = -b + h;

	//if (d1 >= distBound.x && d1 <= distBound.y) 
		//return true;
		
	

	return (d1 >= distBound.x && d1 <= distBound.y) || (d2 >= distBound.x && d2 <= distBound.y);
}


// Sphere:          https://www.shadertoy.com/view/4d2XWV
float iSphere_FrontCull(in float3 ro, in float3 rd, in float2 distBound, inout float3 normal, float sphereRadius)
{
	float b = dot(ro, rd);
	float c = dot(ro, ro) - sphereRadius * sphereRadius;
	float h = b * b - c;

	if (h < 0.)
	{
		normal = float3(0,0,0);
		return MAX_DIST;
	}
	else
	{
		h = sqrt(h);
		float d1 = -b - h;
		float d2 = -b + h;
		if (d1 >= distBound.x && d1 <= distBound.y) 
		{
			normal = float3(0, 0, 0);
			return MAX_DIST;
			//normal = normalize(ro + rd * d1);
			//return d1;
		}
		//else

		//if (d2 >= distBound.x && d2 <= distBound.y) 
		//{
			normal = normalize(ro + rd * d2);
			return d2;
		//}
		//else {
		//	return MAX_DIST;
		//}
	}
}

/*
void iBox( in vec3 ro, in vec3 m, in vec3 boxSize, inout vec2 nearestCast)
{

	vec3 n = m*ro;
	vec3 k = abs(m)*boxSize;

	vec3 t1 = -n - k;
	vec3 t2 = -n + k;

	float tN = max( max( t1.x, t1.y ), t1.z );
	float tF = min( min( t2.x, t2.y ), t2.z );

	float isNear = step(tN, tF) * step(0., tF) * step(tN, nearestCast.x);

	nearestCast = mix(nearestCast, vec2(tN, tF), isNear);
}

*/

/*
bool slabs(in float3 p0, in float3 p1, float3 rayOrigin, float3 raydir, inout float3 normal) {

	float3 invRaydir = 1 / raydir;

	float3 t1 = (p0 - rayOrigin) * invRaydir;
	float3 t2 = (p1 - rayOrigin) * invRaydir;
	float3 tmin = min(t1, t2);
	float3 tmax = max(t1, t2);

	if (max_component(tmin) <= min_component(tmax)) 
	{
		normal = -sign(raydir)*step(t1.yzx, t1.xyz)*step(t1.zxy, t1.xyz);
		return tmin;
	}
	else {
		return MAX_DIST;
	}
}*/



// Box:             https://www.shadertoy.com/view/ld23DV
float iBoxTrigger(in float3 ro, in float3 rd, in float2 distBound, in float3 boxSize, in float3 m) {

	float3 n = m * ro;
	float3 k = abs(m) * boxSize;

	float3 t1 = -n - k;
	float3 t2 = -n + k;

	float tN = max(max(t1.x, t1.y), t1.z);
	float tF = min(min(t2.x, t2.y), t2.z);

	if (tN > tF || tF <= 0.0)
	{
		return MAX_DIST;
	}
	else 
	{
		return tF;
	}
}


// Box:             https://www.shadertoy.com/view/ld23DV
float iBox(in float3 ro, in float3 rd, in float2 distBound, inout float3 normal, in float3 boxSize, in float3 m) {

	float3 n = m * ro;
	float3 k = abs(m)*boxSize;

	float3 t1 = -n - k;
	float3 t2 = -n + k;

	float tN = max(max(t1.x, t1.y), t1.z);
	float tF = min(min(t2.x, t2.y), t2.z);

	if (tN > tF || tF <= 0.0)
	{
		return MAX_DIST;
	}
	else {

		UNITY_FLATTEN
		if (tN >= distBound.x && 
			tN <= distBound.y) {
			normal = -sign(rd)*step(t1.yzx, t1.xyz)*step(t1.zxy, t1.xyz);
			return tN;
		}
		else if (tF >= distBound.x && tF <= distBound.y) 
		{
			normal = -sign(rd)*step(t2.xyz, t2.yzx)*step(t2.xyz, t2.zxy);
			return tF;
		}
		else {
			return MAX_DIST;
		}
	}
}

bool IsHitBox(in float3 ro, in float3 rd, in float3 boxSize, in float2 distBound, in float3 m)
{

	float3 n = m * ro;
	float3 k = abs(m) * boxSize;

	float3 t1 = -n - k;
	float3 t2 = -n + k;

	float tF = min(min(t2.x, t2.y), t2.z);

	float tN = max(max(t1.x, t1.y), t1.z);

	//if (tF <= 0 || tN > tF)
	//	return false;


	return (tF > 0) && (tN < tF) && ((tN <= distBound.y)
		|| (tF <= distBound.y));

	//return (tN >= distBound.x && tN <= distBound.y) 
	//	|| (tF >= distBound.x && tF <= distBound.y);
}

bool IsHitBox(in float3 ro, in float3 rd, in float3 boxSize, in float3 m)  
{

	float3 n = m * ro;
	float3 k = abs(m)*boxSize;

	float3 t1 = -n - k;
	float3 t2 = -n + k;

	float tN = max(max(t1.x, t1.y), t1.z);
	float tF = min(min(t2.x, t2.y), t2.z);

	return tN < tF && tF > 0.0;
}


float3 Rotate (in float3 vec, in float4 q)
{
	float3 crossA = cross(q.xyz, vec) + q.w * vec;
	vec += 2 * cross(q.xyz, crossA);	
	return vec;
}


bool isHitBoxRot(in float3 ro, in float3 rd, in float4 q, in float3 boxSize, in float2 distBound)
{
	//q.y += 0.0001; // Raycsts disapper at z=-90

	rd = Rotate(rd, q);
	ro = Rotate(ro, q);

	float3 absRd = abs(rd) + 0.000001f;

	float3 signRd = rd / absRd;

	float3 m = signRd / (absRd);

	float3 n = m * ro;

	float3 k = abs(m) * boxSize;

	float3 t2 = -n + k;

	float tF = min(min(t2.x, t2.y), t2.z);

	if (tF <= 0.0)
		return false;

	float3 t1 = -n - k;

	float tN = max(max(t1.x, t1.y), t1.z);

	if (tN > tF)
		return false;
	
	return  (tN >= distBound.x && tN <= distBound.y)
		|| (tF >= distBound.x && tF <= distBound.y);
}

bool IsHitBoxRot_ModifyDepth(in float3 ro, in float3 rd, in float4 q, in float3 boxSize, inout float2 distBound)
{
	//q.y += 0.0001; // Raycsts disapper at z=-90

	rd = Rotate(rd, q);
	ro = Rotate(ro, q);

	float3 absRd = abs(rd) + 0.000001f;

	float3 signRd = rd / absRd;

	float3 m = signRd / (absRd);

	float3 n = m * ro;

	float3 k = abs(m) * boxSize;

	float3 t2 = -n + k;
	float tF = min(min(t2.x, t2.y), t2.z);

	float3 t1 = -n - k;
	float tN = max(max(t1.x, t1.y), t1.z);

	if (tF <= 0.0 ||  tF < tN)//tN > tF)
		return false;
	
    // tF distance is bigger

	if (tN >= distBound.x && tN <= distBound.y)
	{
		distBound.y = tN;
		return true;
	}

	if (tF >= distBound.x && tF <= distBound.y)
	{
		distBound.y = tF;
		return true;
	}

	return false;
}

/*
float iBoxRot_(in float3 ro, in float3 rd, in float4 q, in float2 distBound, inout float3 normal, in float3 boxSize)
{
	//#define ROTATE(q,val) val += 2.0 * cross(q.xyz, cross(q.xyz, val) + q.w * val); // Can create black dots when directions match
	//float3 orRd = rd;

	//q.y += 0.0001; // Raycsts disapper at z=-90

	rd = Rotate(rd, q);
	ro = Rotate(ro, q);


	float3 absRd = abs(rd) + 0.000001f;

	float3 signRd = rd / absRd;

	float3 m = signRd / absRd;

	float3 n = m * ro;

	float3 k = abs(m) * boxSize;

	float3 t1 = -n - k;
	float3 t2 = -n + k;

	float tN = max(max(t1.x, t1.y), t1.z);
	float tF = min(min(t2.x, t2.y), t2.z);

	float nValid = step(distBound.x, tN) * step(tN, distBound.y);
	float fValid = step(distBound.x, tF) * step(tF, distBound.y);

	float relationValid = step(tN, tF) * step(0, tF);

	if (relationValid * (nValid + fValid) < 0.5)
		return MAX_DIST;
	


	float3 forNormal = lerp(t2, t1.yzx, nValid);
	normal = -signRd * step(forNormal.xyz, forNormal.yzx) * step(forNormal.xyz, forNormal.zxy);
	normal = Rotate(normal, float4(-q.x, -q.y, -q.z, q.w));

	return lerp(tF, tN, nValid);
}*/


float iBoxRot(in float3 ro, in float3 rd, in float4 q, in float2 distBound, inout float3 normal, in float3 boxSize) 
{
	//#define ROTATE(q,val) val += 2.0 * cross(q.xyz, cross(q.xyz, val) + q.w * val); // Can create black dots when directions match
	//float3 orRd = rd;

	//q.y += 0.0001; // Raycsts disapper at z=-90

	rd = Rotate(rd, q);
	ro = Rotate(ro, q);


	float3 absRd = abs(rd) + 0.000001f;

	float3 signRd = rd / absRd;

	float3 m = signRd / (absRd);

	/*float3 signRd = sign(rd);
	float3 m = signRd / max(abs(rd), 1e-8);*/



	float3 n = m * ro;

	float3 k = abs(m) * boxSize;

	float3 t1 = -n - k;
	float3 t2 = -n + k;

	float tN = max(max(t1.x, t1.y), t1.z);
	float tF = min(min(t2.x, t2.y), t2.z);

	if (tN > tF || tF <= 0.0)
	{
		return MAX_DIST;
	}
	else {

		if (tN >= distBound.x &&
			tN <= distBound.y) {
			normal = -signRd * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);
			normal = Rotate(normal, float4(-q.x,-q.y,-q.z, q.w));
			return tN;
		}
		else if (tF >= distBound.x && tF <= distBound.y)
		{
			normal = -signRd * step(t2.xyz, t2.yzx) * step(t2.xyz, t2.zxy);
			normal = Rotate(normal, float4(-q.x, -q.y, -q.z, q.w));
			return tF;
		}
		else {
			return MAX_DIST;
		}
	}
}

float iCapsuleRot(in float3 ro, in float3 rd, in float4 q, in float2 distBound, inout float3 normal, in float len, in float r) 
	{

	rd = Rotate(rd, q);
	ro = Rotate(ro, q);

	float3  ba = 2 * len; 
	float3  oa = ro + len;

	float baba = len * len * 12;
	float bard = dot(ba, rd);
	float baoa = dot(ba, oa);
	float rdoa = dot(rd, oa);
	float oaoa = dot(oa, oa);

	float r2 = r*r;

	float a = baba - bard * bard;
	float b = baba * rdoa - baoa * bard;
	float c = baba * oaoa - baoa * baoa - r2 * baba;
	float h = b * b - a * c;
	if (h >= 0.) {

		float t = (-b - sqrt(h)) / a;
		float d = MAX_DIST;

		float y = baoa + t * bard;

		// body
		if (y > 0. && y < baba) {
			d = t;
		}
		else {
			// caps
			float3 oc = (y <= 0.) ? oa : ro - len;
			b = dot(rd, oc);
			c = dot(oc, oc) - r2;
			h = b * b - c;
			if (h > 0.0) {
				d = - b - sqrt(h);
			}
		}
		if (d >= distBound.x && d <= distBound.y) {
			float3  pa2 = ro + rd * d + len;
			h = clamp(dot(pa2, ba) / baba , 0.0, 1.0);
			normal = (pa2 - h * ba) / r;
			normal = Rotate(normal, float4(-q.x,-q.y,-q.z, q.w));
			return d;
		}
	}
	return MAX_DIST;
}

bool isHitCapsuleRot(in float3 ro, in float3 rd, in float4 q, in float2 distBound, in float len, in float r)
{

	rd = Rotate(rd, q);
	ro = Rotate(ro, q);

	float3  ba = 2 * len;
	float3  oa = ro + len;

	float baba = len * len * 12;
	float bard = dot(ba, rd);
	float baoa = dot(ba, oa);
	float rdoa = dot(rd, oa);
	float oaoa = dot(oa, oa);

	float r2 = r * r;

	float a = baba - bard * bard;
	float b = baba * rdoa - baoa * bard;
	float c = baba * oaoa - baoa * baoa - r2 * baba;
	float h = b * b - a * c;

	if (h < 0.) 
		return false;

	float t = (-b - sqrt(h)) / a;
	float d = MAX_DIST;

	float y = baoa + t * bard;

	// body
	if (y > 0. && y < baba) 
	{
		return t >= distBound.x && t <= distBound.y;
	}
		
	// caps
	float3 oc = (y <= 0.) ? oa : ro - len;
	b = dot(rd, oc);
	c = dot(oc, oc) - r2;
	h = b * b - c;
	if (h <= 0.0)
		return false;

	d = -b - sqrt(h);
		
	return (d >= distBound.x && d <= distBound.y);
}


// Capped Cylinder: https://www.shadertoy.com/view/4lcSRn
float iCylinder(in float3 ro, in float3 rd, in float2 distBound, inout float3 normal,
	in float3 pa, in float3 pb, float ra) {
	float3 ca = pb - pa;
	float3 oc = ro - pa;

	float caca = dot(ca, ca);
	float card = dot(ca, rd);
	float caoc = dot(ca, oc);

	float a = caca - card * card;
	float b = caca * dot(oc, rd) - caoc * card;
	float c = caca * dot(oc, oc) - caoc * caoc - ra * ra*caca;
	float h = b * b - a * c;

	if (h < 0.) return MAX_DIST;

	h = sqrt(h);
	float d = (-b - h) / a;

	float y = caoc + d * card;
	if (y > 0. && y < caca && d >= distBound.x && d <= distBound.y) {
		normal = (oc + d * rd - ca * y / caca) / ra;
		return d;
	}

	d = ((y < 0. ? 0. : caca) - caoc) / card;

	if (abs(b + a * d) < h && d >= distBound.x && d <= distBound.y) {
		normal = normalize(ca*sign(y) / caca);
		return d;
	}
	else {
		return MAX_DIST;
	}
}

// Torus:           https://www.shadertoy.com/view/4sBGDy
float iTorus(in float3 ro, in float3 rd, in float2 distBound, inout float3 normal,
	in float2 torus) {
	// bounding sphere
	float3 tmpnormal;
	if (iSphere(ro, rd, distBound, tmpnormal, torus.y + torus.x) > distBound.y) {
		return MAX_DIST;
	}

	float po = 1.0;

	float Ra2 = torus.x*torus.x;
	float ra2 = torus.y*torus.y;

	float m = dot(ro, ro);
	float n = dot(ro, rd);

#if 1
	float k = (m + Ra2 - ra2) / 2.0;
	float k3 = n;
	float k2 = n * n - Ra2 * dot(rd.xy, rd.xy) + k;
	float k1 = n * k - Ra2 * dot(rd.xy, ro.xy);
	float k0 = k * k - Ra2 * dot(ro.xy, ro.xy);
#else
	float k = (m - Ra2 - ra2) / 2.0;
	float k3 = n;
	float k2 = n * n + Ra2 * rd.z*rd.z + k;
	float k1 = k * n + Ra2 * ro.z*rd.z;
	float k0 = k * k + Ra2 * ro.z*ro.z - Ra2 * ra2;
#endif

#if 1
	// prevent |c1| from being too close to zero
	if (abs(k3*(k3*k3 - k2) + k1) < 0.01) {
		po = -1.0;
		float tmp = k1; k1 = k3; k3 = tmp;
		k0 = 1.0 / k0;
		k1 = k1 * k0;
		k2 = k2 * k0;
		k3 = k3 * k0;
	}
#endif

	// reduced cubic
	float c2 = k2 * 2.0 - 3.0*k3*k3;
	float c1 = k3 * (k3*k3 - k2) + k1;
	float c0 = k3 * (k3*(c2 + 2.0*k2) - 8.0*k1) + 4.0*k0;

	c2 /= 3.0;
	c1 *= 2.0;
	c0 /= 3.0;

	float Q = c2 * c2 + c0;
	float R = c2 * c2*c2 - 3.0*c2*c0 + c1 * c1;

	float h = R * R - Q * Q*Q;
	float t = MAX_DIST;

	if (h >= 0.0) {
		// 2 intersections
		h = sqrt(h);

		float v = sign(R + h)*pow(abs(R + h), 1.0 / 3.0); // cube root
		float u = sign(R - h)*pow(abs(R - h), 1.0 / 3.0); // cube root

		float2 s = float2((v + u) + 4.0*c2, (v - u)*sqrt(3.0));

		float y = sqrt(0.5*(length(s) + s.x));
		float x = 0.5*s.y / y;
		float r = 2.0*c1 / (x*x + y * y);

		float t1 = x - r - k3; t1 = (po < 0.0) ? 2.0 / t1 : t1;
		float t2 = -x - r - k3; t2 = (po < 0.0) ? 2.0 / t2 : t2;

		if (t1 >= distBound.x) t = t1;
		if (t2 >= distBound.x) t = min(t, t2);
	}
	else {
		// 4 intersections
		float sQ = sqrt(Q);
		float w = sQ * cos(acos(-R / (sQ*Q)) / 3.0);

		float d2 = -(w + c2); if (d2 < 0.0) return MAX_DIST;
		float d1 = sqrt(d2);

		float h1 = sqrt(w - 2.0*c2 + c1 / d1);
		float h2 = sqrt(w - 2.0*c2 - c1 / d1);
		float t1 = -d1 - h1 - k3; t1 = (po < 0.0) ? 2.0 / t1 : t1;
		float t2 = -d1 + h1 - k3; t2 = (po < 0.0) ? 2.0 / t2 : t2;
		float t3 = d1 - h2 - k3; t3 = (po < 0.0) ? 2.0 / t3 : t3;
		float t4 = d1 + h2 - k3; t4 = (po < 0.0) ? 2.0 / t4 : t4;

		if (t1 >= distBound.x) t = t1;
		if (t2 >= distBound.x) t = min(t, t2);
		if (t3 >= distBound.x) t = min(t, t3);
		if (t4 >= distBound.x) t = min(t, t4);
	}

	if (t >= distBound.x && t <= distBound.y) {
		float3 pos = ro + rd * t;
		normal = normalize(pos*(dot(pos, pos) - torus.y*torus.y - torus.x*torus.x*float3(1, 1, -1)));
		return t;
	}
	else {
		return MAX_DIST;
	}
}

// Capsule:         https://www.shadertoy.com/view/Xt3SzX
float iCapsule(in float3 ro, in float3 rd, in float2 distBound, inout float3 normal,
	in float3 pa, in float3 pb, in float r) {
	float3  ba = pb - pa;
	float3  oa = ro - pa;

	float baba = dot(ba, ba);
	float bard = dot(ba, rd);
	float baoa = dot(ba, oa);
	float rdoa = dot(rd, oa);
	float oaoa = dot(oa, oa);

	float a = baba - bard * bard;
	float b = baba * rdoa - baoa * bard;
	float c = baba * oaoa - baoa * baoa - r * r*baba;
	float h = b * b - a * c;
	if (h >= 0.) {
		float t = (-b - sqrt(h)) / a;
		float d = MAX_DIST;

		float y = baoa + t * bard;

		// body
		if (y > 0. && y < baba) {
			d = t;
		}
		else {
			// caps
			float3 oc = (y <= 0.) ? oa : ro - pb;
			b = dot(rd, oc);
			c = dot(oc, oc) - r * r;
			h = b * b - c;
			if (h > 0.0) {
				d = -b - sqrt(h);
			}
		}
		if (d >= distBound.x && d <= distBound.y) {
			float3  pa2 = ro + rd * d - pa;
			float h = clamp(dot(pa2, ba) / dot(ba, ba), 0.0, 1.0);
			normal = (pa2 - h * ba) / r;
			return d;
		}
	}
	return MAX_DIST;
}

// Capped Cone:     https://www.shadertoy.com/view/llcfRf
/*float iCone(in float3 ro, in float3 rd, in float2 distBound, inout float3 normal,
	in float3  pa, in float3  pb, in float ra, in float rb) {
	float3  ba = pb - pa;
	float3  oa = ro - pa;
	float3  ob = ro - pb;

	float m0 = dot(ba, ba);
	float m1 = dot(oa, ba);
	float m2 = dot(ob, ba);
	float m3 = dot(rd, ba);

	//caps
	if (m1 < 0.) {
		if (dot2(oa*m3 - rd * m1) < (ra*ra*m3*m3)) {
			float d = -m1 / m3;
			if (d >= distBound.x && d <= distBound.y) {
				normal = -ba * inversesqrt(m0);
				return d;
			}
		}
	}
	else if (m2 > 0.) {
		if (dot2(ob*m3 - rd * m2) < (rb*rb*m3*m3)) {
			float d = -m2 / m3;
			if (d >= distBound.x && d <= distBound.y) {
				normal = ba * inversesqrt(m0);
				return d;
			}
		}
	}

	// body
	float m4 = dot(rd, oa);
	float m5 = dot(oa, oa);
	float rr = ra - rb;
	float hy = m0 + rr * rr;

	float k2 = m0 * m0 - m3 * m3*hy;
	float k1 = m0 * m0*m4 - m1 * m3*hy + m0 * ra*(rr*m3*1.0);
	float k0 = m0 * m0*m5 - m1 * m1*hy + m0 * ra*(rr*m1*2.0 - m0 * ra);

	float h = k1 * k1 - k2 * k0;
	if (h < 0.) return MAX_DIST;

	float t = (-k1 - sqrt(h)) / k2;

	float y = m1 + t * m3;
	if (y > 0. && y < m0 && t >= distBound.x && t <= distBound.y) {
		normal = normalize(m0*(m0*(oa + t * rd) + rr * ba*ra) - ba * hy*y);
		return t;
	}
	else {
		return MAX_DIST;
	}
}*/

// Ellipsoid:       https://www.shadertoy.com/view/MlsSzn
float iEllipsoid(in float3 ro, in float3 rd, in float2 distBound, inout float3 normal,
	in float3 rad) {
	float3 ocn = ro / rad;
	float3 rdn = rd / rad;

	float a = dot(rdn, rdn);
	float b = dot(ocn, rdn);
	float c = dot(ocn, ocn);
	float h = b * b - a * (c - 1.);

	if (h < 0.) {
		return MAX_DIST;
	}

	float d = (-b - sqrt(h)) / a;

	if (d < distBound.x || d > distBound.y) {
		return MAX_DIST;
	}
	else {
		normal = normalize((ro + d * rd) / rad);
		return d;
	}
}

// Rounded Cone:    https://www.shadertoy.com/view/MlKfzm
float iRoundedCone(in float3 ro, in float3 rd, in float2 distBound, inout float3 normal,
	in float3  pa, in float3  pb, in float ra, in float rb) {
	float3  ba = pb - pa;
	float3  oa = ro - pa;
	float3  ob = ro - pb;
	float rr = ra - rb;
	float m0 = dot(ba, ba);
	float m1 = dot(ba, oa);
	float m2 = dot(ba, rd);
	float m3 = dot(rd, oa);
	float m5 = dot(oa, oa);
	float m6 = dot(ob, rd);
	float m7 = dot(ob, ob);

	float d2 = m0 - rr * rr;

	float k2 = d2 - m2 * m2;
	float k1 = d2 * m3 - m1 * m2 + m2 * rr*ra;
	float k0 = d2 * m5 - m1 * m1 + m1 * rr*ra*2. - m0 * ra*ra;

	float h = k1 * k1 - k0 * k2;
	if (h < 0.0) {
		return MAX_DIST;
	}

	float t = (-sqrt(h) - k1) / k2;

	float y = m1 - ra * rr + t * m2;
	if (y > 0.0 && y < d2) {
		if (t >= distBound.x && t <= distBound.y) {
			normal = normalize(d2*(oa + t * rd) - ba * y);
			return t;
		}
		else {
			return MAX_DIST;
		}
	}
	else {
		float h1 = m3 * m3 - m5 + ra * ra;
		float h2 = m6 * m6 - m7 + rb * rb;

		if (max(h1, h2) < 0.0) {
			return MAX_DIST;
		}

		float3 n = 0;//float3(0);
		float r = MAX_DIST;

		if (h1 > 0.) {
			r = -m3 - sqrt(h1);
			n = (oa + r * rd) / ra;
		}
		if (h2 > 0.) {
			t = -m6 - sqrt(h2);
			if (t < r) {
				n = (ob + t * rd) / rb;
				r = t;
			}
		}
		if (r >= distBound.x && r <= distBound.y) {
			normal = n;
			return r;
		}
		else {
			return MAX_DIST;
		}
	}
}

// Triangle:        https://www.shadertoy.com/view/MlGcDz
float iTriangle(in float3 ro, in float3 rd, in float2 distBound, inout float3 normal,
	in float3 v0, in float3 v1, in float3 v2) {

	float3 v1v0 = v1 - v0; // Can be passed in
	float3 v2v0 = v2 - v0; // Can be passed in
	float3 rov0 = ro - v0;

	float3  n = cross(v1v0, v2v0);
	float3  q = cross(rov0, rd);
	float d = 1.0 / dot(rd, n);
	float u = d * dot(-q, v2v0);
	float v = d * dot(q, v1v0);
	float t = d * dot(-n, rov0);

	if (u < 0. || v<0. || (u + v) > 1. || t<distBound.x || t>distBound.y) {
		return MAX_DIST;
	}
	else {
		normal = normalize(-n);
		return t;
	}
}

// Sphere4:         https://www.shadertoy.com/view/3tj3DW
float iSphere4(in float3 ro, in float3 rd, in float2 distBound, inout float3 normal,
	in float ra) {
	// -----------------------------
	// solve quartic equation
	// -----------------------------

	float r2 = ra * ra;

	float3 d2 = rd * rd; float3 d3 = d2 * rd;
	float3 o2 = ro * ro; float3 o3 = o2 * ro;

	float ka = 1.0 / dot(d2, d2);

	float k0 = ka * dot(ro, d3);
	float k1 = ka * dot(o2, d2);
	float k2 = ka * dot(o3, rd);
	float k3 = ka * (dot(o2, o2) - r2 * r2);

	// -----------------------------
	// solve cubic
	// -----------------------------

	float c0 = k1 - k0 * k0;
	float c1 = k2 + 2.0*k0*(k0*k0 - (3.0 / 2.0)*k1);
	float c2 = k3 - 3.0*k0*(k0*(k0*k0 - 2.0*k1) + (4.0 / 3.0)*k2);

	float p = c0 * c0*3.0 + c2;
	float q = c0 * c0*c0 - c0 * c2 + c1 * c1;
	float h = q * q - p * p*p*(1.0 / 27.0);

	// -----------------------------
	// skip the case of 3 real solutions for the cubic, which involves 
	// 4 complex solutions for the quartic, since we know this objcet is 
	// convex
	// -----------------------------
	if (h < 0.0) {
		return MAX_DIST;
	}

	// one real solution, two complex (conjugated)
	h = sqrt(h);

	float s = sign(q + h)*pow(abs(q + h), 1.0 / 3.0); // cuberoot
	float t = sign(q - h)*pow(abs(q - h), 1.0 / 3.0); // cuberoot

	float2 v = float2((s + t) + c0 * 4.0, (s - t)*sqrt(3.0))*0.5;

	// -----------------------------
	// the quartic will have two real solutions and two complex solutions.
	// we only want the real ones
	// -----------------------------

	float r = length(v);
	float d = -abs(v.y) / sqrt(r + v.x) - c1 / r - k0;

	if (d >= distBound.x && d <= distBound.y) {
		float3 pos = ro + rd * d;
		normal = normalize(pos*pos*pos);
		return d;
	}
	else {
		return MAX_DIST;
	}
}

// Goursat:         https://www.shadertoy.com/view/3lj3DW
float cuberoot(float x) { return sign(x)*pow(abs(x), 1.0 / 3.0); }

float iGoursat(in float3 ro, in float3 rd, in float2 distBound, inout float3 normal,
	in float ra, float rb) {
	// hole: x4 + y4 + z4 - (r2^2)·(x2 + y2 + z2) + r1^4 = 0;
	float ra2 = ra * ra;
	float rb2 = rb * rb;

	float3 rd2 = rd * rd; float3 rd3 = rd2 * rd;
	float3 ro2 = ro * ro; float3 ro3 = ro2 * ro;

	float ka = 1.0 / dot(rd2, rd2);

	float k3 = ka * (dot(ro, rd3));
	float k2 = ka * (dot(ro2, rd2) - rb2 / 6.0);
	float k1 = ka * (dot(ro3, rd) - rb2 * dot(rd, ro) / 2.0);
	float k0 = ka * (dot(ro2, ro2) + ra2 * ra2 - rb2 * dot(ro, ro));

	float c2 = k2 - k3 * (k3);
	float c1 = k1 + k3 * (2.0*k3*k3 - 3.0*k2);
	float c0 = k0 + k3 * (k3*(c2 + k2)*3.0 - 4.0*k1);

	c0 /= 3.0;

	float Q = c2 * c2 + c0;
	float R = c2 * c2*c2 - 3.0*c0*c2 + c1 * c1;
	float h = R * R - Q * Q*Q;


	// 2 intersections
	if (h > 0.0) {
		h = sqrt(h);

		float s = cuberoot(R + h);
		float u = cuberoot(R - h);

		float x = s + u + 4.0*c2;
		float y = s - u;

		float k2 = x * x + y * y*3.0;

		float k = sqrt(k2);

		float d = -0.5*abs(y)*sqrt(6.0 / (k + x))
			- 2.0*c1*(k + x) / (k2 + x * k)
			- k3;

		if (d >= distBound.x && d <= distBound.y) {
			float3 pos = ro + rd * d;
			normal = normalize(4.0*pos*pos*pos - 2.0*pos*rb*rb);
			return d;
		}
		else {
			return MAX_DIST;
		}
	}
	else {
		// 4 intersections
		float sQ = sqrt(Q);
		float z = c2 - 2.0*sQ*cos(acos(-R / (sQ*Q)) / 3.0);

		float d1 = z - 3.0*c2;
		float d2 = z * z - 3.0*c0;

		if (abs(d1) < 1.0e-4) {
			if (d2 < 0.0) return MAX_DIST;
			d2 = sqrt(d2);
		}
		else {
			if (d1 < 0.0) return MAX_DIST;
			d1 = sqrt(d1 / 2.0);
			d2 = c1 / d1;
		}

		//----------------------------------

		float h1 = sqrt(d1*d1 - z + d2);
		float h2 = sqrt(d1*d1 - z - d2);
		float t1 = -d1 - h1 - k3;
		float t2 = -d1 + h1 - k3;
		float t3 = d1 - h2 - k3;
		float t4 = d1 + h2 - k3;

		if (t2 < 0.0 && t4 < 0.0) return MAX_DIST;

		float result = 1e20;
		if (t1 > 0.0) result = t1;
		else if (t2 > 0.0) result = t2;
		if (t3 > 0.0) result = min(result, t3);
		else if (t4 > 0.0) result = min(result, t4);

		if (result >= distBound.x && result <= distBound.y) {
			float3 pos = ro + rd * result;
			normal = normalize(4.0*pos*pos*pos - 2.0*pos*rb*rb);
			return result;
		}
		else {
			return MAX_DIST;
		}
	}
}

// Ray Tracing - Primitives. Created by Reinder Nijhoff 2019
// @reindernijhoff
//
// https://www.shadertoy.com/view/tl23Rm
//
// I have combined different intersection routines in one shader (similar 
// to "Raymarching - Primitives": https://www.shadertoy.com/view/Xds3zN) and
// added a simple ray tracer to visualize a scene with all primitives.
//

//
// Ray tracer helper functions
//

float FresnelSchlickRoughness(float cosTheta, float F0, float roughness) {
	return F0 + (max((1. - roughness), F0) - F0) * pow(abs(1. - cosTheta), 5.0);
}

float3 randomSpherePoint(float4 rand) {
	float PI = 3.14159265359;
	float ang1 = (rand.x) * 2 * PI; // [-1..1) -> [0..2*PI)
	float u = (rand.y - 0.5) * 2; // [-1..1), cos and acos(2v-1) cancel each other out, so we arrive at [-1..1)
	float u2 = u * u;
	float sqrt1MinusU2 = sqrt(1 - u2);
	float x = sqrt1MinusU2 * cos(ang1);
	float y = sqrt1MinusU2 * sin(ang1);
	float z = u;
	return float3(x, y, z);
}

float3 randomDiskPoint(float4 rand, float3 n)
{
	float PI = 3.14159265359;
	float r = rand.x;
	float angle = (rand.y) * 2 * PI;
	float sr = sqrt(r);
	float2 p = float2(sr * cos(angle), sr * sin(angle));
	float3 tangent = normalize((rand.yxz - 0.5) * 2);
	float3 bitangent = cross(tangent, n);
	tangent = cross(bitangent, n);

	/* Make our disk orient towards the normal. */

	return tangent * p.x + bitangent * p.y;
}

float3 cosWeightedRandomHemisphereDirection(float3 n, inout float4 seed)
{

	float3 v = randomSpherePoint(seed);
	return v * sign(dot(v, n));



	/*
	float2 r = seed.xy;
	float3  uu = normalize(cross(n, abs(n.y) > .5 ? float3(1., 0., 0.) : float3(0., 1., 0.)));
	float3  vv = cross(uu, n);
	float ra = sqrt(r.y);
	float mltp = 6.28318530718*r.x;
	float rx = ra * cos(mltp);
	float ry = ra * sin(mltp);
	float rz = sqrt(1. - r.y);
	float3  rr = float3(rx*uu + ry * vv + rz * n);
	return normalize(rr);*/
}

float modifiedRefract(in float3 v, in float3 n, in float ni_over_nt, inout float3 refracted) {
	float dt = dot(v, n);
	float discriminant = 1. - ni_over_nt * ni_over_nt*(1. - dt * dt);

	float isTrue = step(0.0, discriminant);
	float isFalse = 1. - isTrue;

	refracted = isTrue * (ni_over_nt*(v - n * dt) - n * sqrt(discriminant* isTrue + isFalse)) + refracted * isFalse;

	return isTrue;
}

float3 modifyDirectionWithRoughness(in float3 normal, in float3 refl, in float roughness, in float4 seed) {

	float2 r = seed.wx;//hash2(seed);

	float nyBig = step(.5, refl.y);

	float3  uu = normalize(cross(refl, float3(nyBig, 1. - nyBig, 0.)));
	float3  vv = cross(uu, refl);

	float a = roughness * roughness;

	float rz = sqrt(abs((1.0 - seed.y) / clamp(1. + (a - 1.)*seed.y, .00001, 1.)));
	float ra = sqrt(abs(1. - rz * rz));
	float preCmp = 6.28318530718*seed.x;
	float rx = ra * cos(preCmp);
	float ry = ra * sin(preCmp);
	float3 rr = float3(rx*uu + ry * vv + rz * refl);

	float3 ret = normalize(rr + (seed.xyz-0.5) *0.1);

	//float isRet = step(0.1, max(0., dot(ret,normal)));

	return //dot(ret, normal) > 0.001 ? ret : 
		normalize(refl + ret);  // Having gloss layer
				//normalize(+refl * 0.5);//refl;
	
	//ret * isRet + n * (1.-isRet); // Probably a div by zero somewhere
		//dot(ret, normal) > 0.1 ? ret : refl;

}

float2 randomInUnitDisk(inout float4 seed) {
	float2 h = seed.xy; //hash2(seed) * float2(1, 6.28318530718);
	float phi = h.y;
	float r = sqrt(h.x);
	return r * float2(sin(phi), cos(phi));
}

//
// Scene description
//

float3 rotateY(in float3 p, in float t) {
	float co = cos(t);
	float si = sin(t);
	float2 xz = float2(co * p.x - si * p.z, si * p.x + co * p.z);
	return float3(xz.x, p.y, xz.y);
}

float iMesh(in float3 ro, in float3 rd, in float2 distBound, inout float3 normal) {
	const float3 tri0 = float3(-2. / 3. * 0.43301270189, 0, 0);
	const float3 tri1 = float3(1. / 3. * 0.43301270189, 0, .25);
	const float3 tri2 = float3(1. / 3. * 0.43301270189, 0, -.25);
	const float3 tri3 = float3(0, 0.41079191812, 0);

	float2 d = distBound;
	d.y = min(d.y, iTriangle(ro, rd, d, normal, tri0, tri1, tri2));
	d.y = min(d.y, iTriangle(ro, rd, d, normal, tri0, tri3, tri1));
	d.y = min(d.y, iTriangle(ro, rd, d, normal, tri2, tri3, tri0));
	d.y = min(d.y, iTriangle(ro, rd, d, normal, tri1, tri3, tri2));

	return d.y < distBound.y ? d.y : MAX_DIST;
}

//
// Palette by Íñigo Quílez: 
// https://www.shadertoy.com/view/ll2GD3
//





float schlick(float cosine, float r0) {
	return r0 + (1. - r0)*pow((1. - cosine), 5.);
}

inline float3 Mix(float3 a, float3 b, float3 p) {
	return a * (1 - p) + b * p;
}

inline float Mix(float a, float b, float p) {
	return a * (1 - p) + b * p;
}

