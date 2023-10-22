

// Helper functions


#define INIT_SDF_NORMAL(normal, pos, spherePos, SDF_OPERATION)                              \
    float EPSILON = 0.01f;                                                                  \
    float center = SDF_OPERATION(float3(pos.x, pos.y, pos.z), spherePos);                   \
    float3 normal = normalize(float3(                                                       \
        center - SDF_OPERATION(float3(pos.x - EPSILON, pos.y, pos.z), spherePos),           \
        center - SDF_OPERATION(float3(pos.x, pos.y - EPSILON, pos.z), spherePos),           \
        center - SDF_OPERATION(float3(pos.x, pos.y, pos.z - EPSILON), spherePos)));         

 #define INIT_SDF_NORMAL_ROT(normal, pos, spherePos, SDF_OPERATION)              \
    float EPSILON = 0.01f;                                                                  \
    float center = SDF_OPERATION(float3(pos.x, pos.y, pos.z), spherePos, i.meshQuaternion, i.meshSize);        \
    float3 normal = normalize(float3(                                                       \
        center - SDF_OPERATION(float3(pos.x - EPSILON, pos.y, pos.z), spherePos, i.meshQuaternion, i.meshSize), \
        center - SDF_OPERATION(float3(pos.x, pos.y - EPSILON, pos.z), spherePos, i.meshQuaternion, i.meshSize), \
        center - SDF_OPERATION(float3(pos.x, pos.y, pos.z - EPSILON), spherePos, i.meshQuaternion, i.meshSize)));         


float2 RotateV2(float2 p, float a)
{
    float c = cos(a);
    float s = sin(a);

    p = mul(p, float2x2(c, s, -s, c));
    return p;
}

float Dot2(in float2 v) { return dot(v, v); }

float Ndot(in float2 a, in float2 b) { return a.x * b.x - a.y * b.y; }

float SphereDistance(float3 pos, float radius)
{
	return length(pos) - radius;
}

// Effects
float Shrapnel(float3 p)
{
	for (int i = 0; i < 8; ++i)
	{
		float t = _Time.x;
		p.xz = RotateV2(p.xz, t);
		p.xy = RotateV2(p.xy, t * 1.89);
		p.xz = abs(p.xz);
		p.xz -= .5;
	}
	return dot(sign(p), p) / 5.;
}





float sdRoundCone(in float3 p)
{
    p.y = -p.y + 0.1;

    float r1 = 0.4;
    float r2 = 0.2;
    float h = 0.4;

    float2 q = float2(length(p.xz), p.y);

    float b = (r1 - r2) / h;
    float a = sqrt(1.0 - b * b);
    float k = dot(q, float2(-b, a));

    if (k < 0.0)
        return length(q) - r1;
    if (k > a * h)
        return length(q - float2(0.0, h)) - r2;

    return dot(q, float2(a, b)) - r1;
}


float sdGyroid(float3 p, float thickness)
{
    return dot(sin(p), cos(p.yzx)) + thickness;
}


float sdGyroid(float3 p, float scale, float bias, float thickness)
{
    p *= scale;
    float d = abs(dot(sin(p), cos(p.yzx)) + bias) - thickness;
    return d / scale;
}


float sdBoundingBox(float3 p, float3 b, float e)
{
    p = abs(p) - b;
    float3 q = abs(p + e) - e;

    return min(min(
        length(max(float3(p.x, q.y, q.z), 0.0)) + min(max(p.x, max(q.y, q.z)), 0.0),
        length(max(float3(q.x, p.y, q.z), 0.0)) + min(max(q.x, max(p.y, q.z)), 0.0)),
        length(max(float3(q.x, q.y, p.z), 0.0)) + min(max(q.x, max(q.y, p.z)), 0.0));
}

float sdEllipsoid(in float3 p, in float3 r) // approximated
{
    float k0 = length(p / r);
    float k1 = length(p / (r * r));
    return k0 * (k0 - 1.0) / k1;
}

float sdTorus(float3 p, float2 t)
{
    return length(float2(length(p.xz) - t.x, p.y)) - t.y;
}

float sdCappedTorus(in float3 p, in float2 sc, in float ra, in float rb)
{
    p.x = abs(p.x);
    float k = (sc.y * p.x > sc.x * p.y) ? dot(p.xy, sc) : length(p.xy);
    return sqrt(dot(p, p) + ra * ra - 2.0 * ra * k) - rb;
}

float sdHexPrism(float3 p, float2 h)
{
    float3 q = abs(p);

    const float3 k = float3(-0.8660254, 0.5, 0.57735);
    p = abs(p);
    p.xy -= 2.0 * min(dot(k.xy, p.xy), 0.0) * k.xy;
    float2 d = float2(
        length(p.xy - float2(clamp(p.x, -k.z * h.x, k.z * h.x), h.x)) * sign(p.y - h.x),
        p.z - h.y);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float sdOctogonPrism(in float3 p, in float r, float h)
{
    const float3 k = float3(-0.9238795325,   // sqrt(2+sqrt(2))/2 
        0.3826834323,   // sqrt(2-sqrt(2))/2
        0.4142135623); // sqrt(2)-1 
// reflections
    p = abs(p);
    p.xy -= 2.0 * min(dot(float2(k.x, k.y), p.xy), 0.0) * float2(k.x, k.y);
    p.xy -= 2.0 * min(dot(float2(-k.x, k.y), p.xy), 0.0) * float2(-k.x, k.y);
    // polygon side
    p.xy -= float2(clamp(p.x, -k.z * r, k.z * r), r);
    float2 d = float2(length(p.xy) * sign(p.y), p.z - h);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float sdCapsule(float3 p, float3 a, float3 b, float r)
{
    float3 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

float sdRoundCone(in float3 p, in float r1, float r2, float h)
{
    float2 q = float2(length(p.xz), p.y);

    float b = (r1 - r2) / h;
    float a = sqrt(1.0 - b * b);
    float k = dot(q, float2(-b, a));

    if (k < 0.0) return length(q) - r1;
    if (k > a * h) return length(q - float2(0.0, h)) - r2;

    return dot(q, float2(a, b)) - r1;
}

float sdRoundCone(float3 p, float3 a, float3 b, float r1, float r2)
{
    // sampling independent computations (only depend on shape)
    float3  ba = b - a;
    float l2 = dot(ba, ba);
    float rr = r1 - r2;
    float a2 = l2 - rr * rr;
    float il2 = 1.0 / l2;

    // sampling dependant computations
    float3 pa = p - a;
    float y = dot(pa, ba);
    float z = y - l2;
    float x2 = Dot2(pa * l2 - ba * y);
    float y2 = y * y * l2;
    float z2 = z * z * l2;

    // single square root!
    float k = sign(rr) * rr * rr * x2;
    if (sign(z) * a2 * z2 > k) return  sqrt(x2 + z2) * il2 - r2;
    if (sign(y) * a2 * y2 < k) return  sqrt(x2 + y2) * il2 - r1;
    return (sqrt(x2 * a2 * il2) + y * rr) * il2 - r1;
}

float sdTriPrism(float3 p, float2 h)
{
    const float k = sqrt(3.0);
    h.x *= 0.5 * k;
    p.xy /= h.x;
    p.x = abs(p.x) - 1.0;
    p.y = p.y + 1.0 / k;
    if (p.x + k * p.y > 0.0) p.xy = float2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
    p.x -= clamp(p.x, -2.0, 0.0);
    float d1 = length(p.xy) * sign(-p.y) * h.x;
    float d2 = abs(p.z) - h.y;
    return length(max(float2(d1, d2), 0.0)) + min(max(d1, d2), 0.);
}

// vertical
float sdCylinder(float3 p, float2 h)
{
    float2 d = abs(float2(length(p.xz), p.y)) - h;
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

// arbitrary orientation
float sdCylinder(float3 p, float3 a, float3 b, float r)
{
    float3 pa = p - a;
    float3 ba = b - a;
    float baba = dot(ba, ba);
    float paba = dot(pa, ba);

    float x = length(pa * baba - ba * paba) - r * baba;
    float y = abs(paba - baba * 0.5) - baba * 0.5;
    float x2 = x * x;
    float y2 = y * y * baba;
    float d = (max(x, y) < 0.0) ? -min(x2, y2) : (((x > 0.0) ? x2 : 0.0) + ((y > 0.0) ? y2 : 0.0));
    return sign(d) * sqrt(abs(d)) / baba;
}

// vertical
float sdCone(in float3 p, in float2 c, float h)
{
    float2 q = h * float2(c.x, -c.y) / c.y;
    float2 w = float2(length(p.xz), p.y);

    float2 a = w - q * clamp(dot(w, q) / dot(q, q), 0.0, 1.0);
    float2 b = w - q * float2(clamp(w.x / q.x, 0.0, 1.0), 1.0);
    float k = sign(q.y);
    float d = min(dot(a, a), dot(b, b));
    float s = max(k * (w.x * q.y - w.y * q.x), k * (w.y - q.y));
    return sqrt(d) * sign(s);
}

float sdCappedCone(in float3 p, in float h, in float r1, in float r2)
{
    float2 q = float2(length(p.xz), p.y);

    float2 k1 = float2(r2, h);
    float2 k2 = float2(r2 - r1, 2.0 * h);
    float2 ca = float2(q.x - min(q.x, (q.y < 0.0) ? r1 : r2), abs(q.y) - h);
    float2 cb = q - k1 + k2 * clamp(dot(k1 - q, k2) / dot(k2, k2), 0.0, 1.0);
    float s = (cb.x < 0.0 && ca.y < 0.0) ? -1.0 : 1.0;
    return s * sqrt(min(dot(ca,ca), dot(cb,cb)));
}

float sdCappedCone(float3 p, float3 a, float3 b, float ra, float rb)
{
    float rba = rb - ra;
    float baba = dot(b - a, b - a);
    float papa = dot(p - a, p - a);
    float paba = dot(p - a, b - a) / baba;

    float x = sqrt(papa - paba * paba * baba);

    float cax = max(0.0, x - ((paba < 0.5) ? ra : rb));
    float cay = abs(paba - 0.5) - 0.5;

    float k = rba * rba + baba;
    float f = clamp((rba * (x - ra) + paba * baba) / k, 0.0, 1.0);

    float cbx = x - ra - f * rba;
    float cby = paba - f;

    float s = (cbx < 0.0 && cay < 0.0) ? -1.0 : 1.0;

    return s * sqrt(min(cax * cax + cay * cay * baba,
        cbx * cbx + cby * cby * baba));
}

// c is the sin/cos of the desired cone angle
float sdSolidAngle(float3 pos, float2 c, float ra)
{
    float2 p = float2(length(pos.xz), pos.y);
    float l = length(p) - ra;
    float m = length(p - c * clamp(dot(p, c), 0.0, ra));
    return max(l, m * sign(c.y * p.x - c.x * p.y));
}

float sdOctahedron(float3 p, float s)
{
    p = abs(p);
    float m = p.x + p.y + p.z - s;

    // exact distance
#if 0
    float3 o = min(3.0 * p - m, 0.0);
    o = max(6.0 * p - m * 2.0 - o * 3.0 + (o.x + o.y + o.z), 0.0);
    return length(p - s * o / (o.x + o.y + o.z));
#endif

    // exact distance
#if 1
    float3 q;
    if (3.0 * p.x < m) q = p.xyz;
    else if (3.0 * p.y < m) q = p.yzx;
    else if (3.0 * p.z < m) q = p.zxy;
    else return m * 0.57735027;
    float k = clamp(0.5 * (q.z - q.y + s), 0.0, s);
    return length(float3(q.x, q.y - s + k, q.z - k));
#endif

    // bound, not exact
#if 0
    return m * 0.57735027;
#endif
}

float sdPyramid(in float3 p, in float h)
{
    float m2 = h * h + 0.25;

    // symmetry
    p.xz = abs(p.xz);
    p.xz = (p.z > p.x) ? p.zx : p.xz;
    p.xz -= 0.5;

    // project into face plane (2D)
    float3 q = float3(p.z, h * p.y - 0.5 * p.x, h * p.x + 0.5 * p.y);

    float s = max(-q.x, 0.0);
    float t = clamp((q.y - 0.5 * p.z) / (m2 + 0.25), 0.0, 1.0);

    float a = m2 * (q.x + s) * (q.x + s) + q.y * q.y;
    float b = m2 * (q.x + 0.5 * t) * (q.x + 0.5 * t) + (q.y - m2 * t) * (q.y - m2 * t);

    float d2 = min(q.y, -q.x * m2 - q.y * 0.5) > 0.0 ? 0.0 : min(a, b);

    // recover 3D and scale, and add sign
    return sqrt((d2 + q.z * q.z) / m2) * sign(max(q.z, -p.y));;
}

// la,lb=semi axis, h=height, ra=corner
float sdRhombus(float3 p, float la, float lb, float h, float ra)
{
    p = abs(p);
    float2 b = float2(la, lb);
    float f = clamp((Ndot(b, b - 2.0 * p.xz)) / dot(b, b), -1.0, 1.0);
    float2 q = float2(length(p.xz - 0.5 * b * float2(1.0 - f, 1.0 + f)) * sign(p.x * b.y + p.z * b.x - b.x * b.y) - ra, p.y - h);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0));
}

