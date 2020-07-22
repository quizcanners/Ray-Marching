// Some references for lighting
// https://www.shadertoy.com/view/XlBSRz
// https://www.shadertoy.com/view/MdlyDs
//

#if defined (TWOD)
static const int CLOUD_MARCH_STEPS = 2;
static const int CLOUD_SELF_SHADOW_STEPS = 1;
#else

#if defined (ULTRA)
uniform int CLOUD_MARCH_STEPS = 100;
static const int CLOUD_SELF_SHADOW_STEPS = 5;
#elif defined (HIGH)
static const int CLOUD_MARCH_STEPS = 80;
static const int CLOUD_SELF_SHADOW_STEPS = 5;
#elif defined(MEDIUM)
static const int CLOUD_MARCH_STEPS = 40;
static const int CLOUD_SELF_SHADOW_STEPS = 5;
#else
static const int CLOUD_MARCH_STEPS = 20;
static const int CLOUD_SELF_SHADOW_STEPS = 5;
#endif

#endif

// Sun and lighting uniforms
uniform float4 _uSunColor; // sun color
uniform float4 _uSunDir; // sun direction (forward vector)
uniform float _uAttenuation; // not used as attenuation - used as light intensity
uniform float DISTANT_CLOUD_MARCH_STEPS;

uniform float4 _uMoonDir;
uniform float4 _uMoonColor;
uniform float _uMoonAttenuation;

uniform float _uCloudsBaseEdgeSoftness; // fluffiness of the edge of clouds
uniform float _uCloudsBottomSoftness; // fluffiness of the bottom of the clouds
uniform float _uCloudsDensity; // density of the clouds - different from coverage
uniform float _uCloudsForwardScatteringG; // forward light scattering
uniform float _uCloudsBackwardScatteringG; // backward light scattering

uniform float3 _uLightningColor;
uniform float _uLightning = 0.0f;

// Fog and color uniforms
uniform float4 _uCloudsColor; // overall color of the clouds - not physically based
uniform float4 _uFogColor; // color of the fog
uniform float _uFogAmount; // amount of fog

uniform float3 _uCloudsAmbientColorTop; // color of the top of the clouds
uniform float3 _uCloudsAmbientColorBottom; // color of the bottom of the clouds

// Scale and movement uniforms
//uniform float _uEarthRadius; // radius of the earth in meters
#define _uEarthRadius 637100.0f
uniform float _uCloudsBottom; // bottom layer in meters
uniform float _uCloudsHeight; // top layer in meters
uniform float _uCloudsBearing; // heading of the clouds - radians

uniform float _uCloudsBaseScale; // scale of the cloud shapes
uniform float _uCloudsDetailScale; // scale of the cloud detail erosion
uniform float _uCloudsCoverage; // coverage (not linear, it depends on other settings
uniform float _uCloudsCoverageBias;
uniform float _uCurlScale;
uniform float _uCurlStrength;

uniform float _uCloudsMovementSpeed; // movement speed - meters per second
uniform float _uCloudsTurbulenceSpeed; // movement speed of the turbulence - meters per second
uniform float _uBaseCloudOffset;
uniform float _uDetailCloudOffset;
uniform float _uCloudNoiseScale;

uniform float _uRaymarchOffset; // offset for the raymarching
uniform float2 _uJitter; // Used so that the clouds can be rendered at a lower resolution

uniform float _uCloudsDetailStrength; // strength of the erosion of the details

// get a hash value from a float3 - no sine wave 
// https://www.shadertoy.com/view/4djSRW
float hash13(float3 p3) 
{
    p3 = frac(p3 * 1031.1031f);
    p3 += dot(p3, p3.yzx + 19.19f);
    return frac((p3.x + p3.y) * p3.z);
}

// phase function
float HenyeyGreenstein(float sundotrd, float g)
{
    float gg = g * g;
    return (1.0f - gg) / pow(1.0f + gg - 2.0f * g * sundotrd, 1.5f);
}

// ray intersect sphere from outside
float intersectCloudSphereOuter(float3 ro, float3 rd, float sr)
{
    float a = dot(rd, rd);
    float b = 2.0f * dot(rd, ro);
    float c = dot(ro, ro) - (sr * sr);

    float facto = b * b - 4.0f * a * c ;

    if (facto < 0.0) 
    {
        return -1.0f;
    }
    return (-b - sqrt(facto)) / (2.0f * a);
}

// ray intersect sphere from inside, guaranteed to hit
float intersectCloudSphereInner(float3 ro, float3 rd, float sr)
{
    float t = dot(-ro, rd);
    float y = length(ro + rd * t);

    float x = sqrt(sr * sr - y * y);
    return t + x;
}

// utility functions
//-------------------------------
float linearstep(const float s, const float e, float v)
{
    return clamp((v - s)*(1.0f / (e - s)), 0.0f, 1.0f);
}

float linearstep0(const float e, float v)
{
    return min(v*(1.0f / e), 1.0f);
}

float remap(float v, float s, float e)
{
    return (v - s) / (e - s);
}

float3 remap(float3 v, float s, float e)
{
    return (v - s) / (e - s);
}

// http://squircular.blogspot.com/2015/09/fg-squircle-mapping.html
// To make the most of a square texture, the two following functions are used

/*
float2 sqr2Ccl(float2 sqrUV)
{
    float u = sqrUV.x;
    float v = sqrUV.y;

    float x2 = sqrUV.x * sqrUV.x;
    float y2 = sqrUV.y * sqrUV.y;
    float r2 = x2 + y2;
    float rad = sqrt(r2 - x2 * y2);

    // avoid division by zero if (x,y) is closed to origin
    if (r2 < 0.00001f) {
        return float2(u, v);
    }

    float reciprocalSqrt = 1.0f / sqrt(r2);

    u = sqrUV.x * rad * reciprocalSqrt;
    v = sqrUV.y * rad * reciprocalSqrt;

    return float2(u, v);
}
*/
/*
float2 ccl2Sqr(float2 cclUV)
{
    float x = cclUV.x;
    float y = cclUV.y;

    float r2 = x * x + y * y;
    float uv = x * y;
    float rad = r2 * (r2 - 4.0f * uv * uv);
    float sgnuv = sign(uv);
    float sqrto = sqrt(0.5f * (r2 - sqrt(rad)));

    sqrto *= sgnuv;
    
    return sqrto / float2( (y + 0.00001),(x + 0.00001));
}*/
//-------------------------------

// an exponential fog density of 0.0003. Works really well with the earth radius
float getFogAmount(float dist)
{
    return 1.0f - (0.1f + exp(-dist * 0.0003f));
}

// map the clouds base shape
float cloudMapBase(float3 p, float norY)
{
    float3 offset = float3(cos(_uCloudsBearing), 0.0f, sin(_uCloudsBearing)) * (_uBaseCloudOffset);

    float3 uv = (p + offset) * (0.00005f * _uCloudsBaseScale);
	float distance = length(uv.xz);

#ifdef IS_COMPUTE_SHADER
    float3 cloud = _uBaseNoise.SampleLevel(_TrilinearRepeat, uv.xz, 0).rgb - float3(0.0f, 1.0f, 0.0f);
#else
    float3 cloud = tex2Dlod(_uBaseNoise, float4(uv.xz, 0.0f, 1.0f)).rgb - float3(0.0f, 1.0f, 0.0f);
#endif

    float n = norY * norY;
	n += pow(1.0f - norY, 36);
	return remap(cloud.r - n, cloud.g - n, 1.0f);
}

// map the cloud noise
float3 cloudMapDetail(float3 p, float norY, float speed)
{
    float3 offset = float3(cos(_uCloudsBearing), 1.0f, sin(_uCloudsBearing)) * (_uDetailCloudOffset) * speed;

#if defined(ULTRA)
    float2 curl_noise = tex2Dlod(_uCurlNoise, float4(p.xz / _uCurlScale, 0.0, 1.0)).rg;
    offset.xz += curl_noise.rg * (1.0 - norY) * _uCurlScale * _uCurlStrength;
#endif

    float3 uv = abs(p + offset) * (0.00005f * _uCloudsBaseScale * _uCloudsDetailScale);

#ifdef IS_COMPUTE_SHADER
    return _uDetailNoise.SampleLevel(_TrilinearRepeat, uv * 0.02f, 0).r;
#else
    return tex3Dlod(_uDetailNoise, float4(uv * 0.02f, 0.0f));
#endif
}

float cloudGradient(float norY) 
{
    return linearstep(0.0f, 0.05f, norY) - linearstep(0.8f, 1.2f, norY);
}

// map the cloud with details
float cloudMap(float3 pos, float3 rd, float norY)
{
	float fadeOriginal = sqrt(pow(_uEarthRadius + _uCloudsBottom,2) - _uEarthRadius * _uEarthRadius);
	float d2 = length(pos.xz);
	float fade2 = smoothstep(0, fadeOriginal, d2 * 2);

#if defined(TWOD)
	float m = cloudMapBase(pos, norY);
	m *= cloudGradient(norY);
#else
    float m = cloudMapBase(pos, norY * lerp(0.8, 8, fade2 * 0.25));
	m *= cloudGradient(norY);
#endif
    
	//float dstrength = smoothstep(1.0f, 0.5f, m);
	float dstrength = smoothstep(1.0f, 0.5f, fade2 * 0.6);

#if defined(MEDIUM) || defined(HIGH) || defined(ULTRA)
    // erode with detail
    if (dstrength > 0.)
    {		
        float3 detail = cloudMapDetail(pos, norY, 1) * dstrength * _uCloudsDetailStrength;
        float detailSampleResult = (detail.r * 0.625f) + (detail.g * 0.2f) + (detail.b * 0.125f);
        m -= detailSampleResult;
    }
#else
    m -= dstrength * _uCloudsDetailStrength * 0.5f;
#endif
 
    
    float d = length(pos.xz);

	float fade = smoothstep(fadeOriginal * 6, 0, d);

#if defined(TWOD)
    m = smoothstep(0.0f, lerp(25.0f, _uCloudsBaseEdgeSoftness, fade), m + (lerp(_uCloudsCoverage + _uCloudsCoverageBias + 0.7f, _uCloudsCoverage + _uCloudsCoverageBias + 0.05, fade) - 1.));
#else
    m = smoothstep(0.0f, lerp(2.5f, _uCloudsBaseEdgeSoftness, fade), m + (lerp(_uCloudsCoverage + _uCloudsCoverageBias - 1.0f, _uCloudsCoverage + _uCloudsCoverageBias , fade) - 1.));
#endif

	//Controls fading softness distance
	m *= linearstep0(_uCloudsBottomSoftness, norY);

    return clamp(m * _uCloudsDensity * (1.0f + max((d - 7000.0f)*0.0005f, 0.0f)), 0.0f, 1.0f);
}

float volumetricShadow(in float3 from, in float sundotrd, in float3 sunDir) {

	float sundotup = max(0.0f, -_uSunDir.y); // dot(float3(0, 1, 0), -_uSunDir));

    float dd = 12;
    float3 rd = -sunDir;
    float d = dd * 2.0f;
	float shadow = 1.0 * lerp(1.5, 1, sundotup);

    float deBot =  (1.0f / (_uCloudsBottom + _uCloudsHeight - _uCloudsBottom));

    float posOff = _uEarthRadius + _uCloudsBottom;

#if defined(TWOD)
    UNITY_UNROLL
#else
    UNITY_LOOP
#endif
    for (int s = 0; s < CLOUD_SELF_SHADOW_STEPS; s++)
    {
        float3 pos = from + rd * d;
        float norY = (length(pos) - posOff) * deBot;

        if (norY > 1.0f) return shadow;

        float muE = cloudMap(pos, rd, norY);
        shadow *= exp(-muE * dd / 8);

        dd *= 1.0 * lerp(1.8, 1, sundotup);
        d += dd;
    }
    return shadow;
}

float4 renderCloudsInternal(float3 ro, float3 rd, inout float dist)
{
    ro.y = _uEarthRadius + ro.y;

    float start = 0, end = 0;

    start = intersectCloudSphereInner(ro, rd, _uEarthRadius + _uCloudsBottom);
    end = intersectCloudSphereInner(ro, rd, _uEarthRadius + (_uCloudsBottom + _uCloudsHeight));
	float Fade = length(end);

    float sundotrd = dot(rd, _uSunDir);
    float sundotup = max(0.0f, dot(float3(0, 1, 0), -_uSunDir));

    float moondotrd = dot(rd, -_uMoonDir);
    float moondotup = max(0.0f, dot(float3(0, 1, 0), -_uMoonDir));

    float up = rd.y;

#if defined(TWOD)
    int nSteps = CLOUD_MARCH_STEPS; // 2D is always the same
#elif defined(ULTRA)
    int nSteps = lerp(DISTANT_CLOUD_MARCH_STEPS, CLOUD_MARCH_STEPS, up);//dot(rd, float3(0, 1, 0))); // Samples are applied through UniStormSystem. If Customize Quality is enabled, these are controlled through the UniStorm Editor. 
#elif defined(HIGH)
	int nSteps = lerp(10, CLOUD_MARCH_STEPS, up); // 10 samples for the distant clouds
#elif defined(MEDIUM)
    int nSteps = lerp(10, CLOUD_MARCH_STEPS, up); // 10 samples for the distant clouds
#else
    int nSteps = lerp(10, CLOUD_MARCH_STEPS, up); // 10 samples for the distant clouds
#endif

    // raymarch
#if defined(TWOD)
    float d = start + ((end - start) * 0.4f);
    float dD = 7.0f;
#else
	float d = start;
	float dD = min(100.0f, (end - start) / float(nSteps));
#endif

    float h = frac(_uRaymarchOffset);
    d -= dD * h;

    float scattering = lerp(HenyeyGreenstein(sundotrd, 0.8f),
        HenyeyGreenstein(sundotrd, -0.35f), 0.65f);	

    float moonScattering = lerp(HenyeyGreenstein(moondotrd, 0.3f),
        HenyeyGreenstein(moondotrd, 0.75f), 0.5f);

    float transmittance = 1.0f;
    float3 scatteredLight = 0.0f;

    dist = _uEarthRadius;

    float deHeight =  (1.0f / _uCloudsHeight);
    float radius_and_bottom = _uEarthRadius + _uCloudsBottom;

    UNITY_LOOP
    for (int s = 0; s < nSteps; s++)
    {
        float3 p = ro + d * rd;

        float norY = saturate((length(p) - radius_and_bottom) * deHeight);

        float alpha = cloudMap(p, rd, norY);

        if (alpha > 0.005f)
        {
			float3 detail2 = cloudMapDetail(p * 0.35, norY, 1.0);
			float3 detail3 = cloudMapDetail(p * 1, norY, 1.0);
			
			dist = min(dist, d);

			float3 ambientLight = lerp(
				lerp(_uCloudsAmbientColorBottom - (detail2.r * lerp(0.25, 0.75, sundotup)) * (lerp(0.2, 0.05, (_uCloudsCoverage)) * _uAttenuation * 0.4f), 0.0f, saturate(_uLightning * 3.0f)),
				lerp(_uCloudsAmbientColorTop - detail2.r * lerp(1, 4, sundotup) * (0.1 * _uAttenuation * 0.9), _uCloudsAmbientColorTop + (_uLightningColor * lerp(0.35f, 0.75f, sundotup)), saturate(_uLightning * 10.0f)),
				norY) * _uCloudsColor;

#if defined(TWOD)
            float3 light = _uSunColor * _uAttenuation * 0.6f;
            light *= smoothstep(-0.03f, 0.075f, sundotup);
			light *= lerp(smoothstep(0.9f, 0.4f, sundotrd), 1.0f, smoothstep(0.01, 0.65f, sundotup));

            float3 moonLight = _uMoonColor * _uMoonAttenuation * 0.6f;
            moonLight *= smoothstep(-0.03f, 0.075f, moondotup);
#else
			float3 light = _uSunColor * _uAttenuation * 1.5 * smoothstep(0.04, 0.055, sundotup);

            

#if UNITY_COLORSPACE_GAMMA
			light *= smoothstep(-0.03f, 0.075f, sundotup) - lerp(clamp(lerp(detail2.r * 1.6, detail3.r * 1.6, norY), 1.25, 0.9), clamp(detail3.r * 1.3, 0, 1.25), norY * 4);
#else
			light *= smoothstep(-0.03f, 0.075f, sundotup) - lerp(clamp(lerp(detail2.r * 1.6, detail3.r * 1.6, norY), 0.75, 0.9), clamp(detail3.r * 1.3, 0, 0.8), norY * 4);
#endif           
			//Smooth opposite clouds
			light *= lerp(smoothstep(0.99f, 0.55f, sundotrd), 1.0f, smoothstep(0.1, 0.99f, sundotup));

            float3 moonLight = _uMoonColor * _uMoonAttenuation * 0.6f *smoothstep(0.11, 0.35, moondotup);
            moonLight *= smoothstep(-0.03f, 0.075f, moondotup);
#endif

            float3 S = (
                ambientLight + 
                light * (scattering * volumetricShadow(p, sundotrd, _uSunDir)) +
                moonLight * (moonScattering * volumetricShadow(p, moondotrd, _uMoonDir)))
                * alpha;	

            float dTrans = exp(-alpha * dD);
            float3 Sint = (S - (S * dTrans)) * (1.0f / alpha);

            scatteredLight += transmittance * Sint;
            transmittance *= dTrans;		
        }

        if (transmittance <= 0.035f) 
            break;

        d += dD;
    }

    return float4(scatteredLight, transmittance);
}

void renderClouds(out float4 fragColor, in float3 ro, in float3 rd)
{
    float dist = 300000.0f;
    float4 col = float4(0, 0, 0, 1);

  //  float fogAmount = smoothstep(0.0025f, 0.02f, _uFogColor.a);
  //  float3 fogColor = lerp(1.0f, _uFogColor.rgb, fogAmount);

    col = renderCloudsInternal(ro, rd, dist);

    if (col.w > 1.0f) 
    {
        fragColor = float4(0, 0, 0, 1);
    }
    else 
    {
        fragColor = float4(clamp(col.rgb, 0, 0.9), col.a);
    }
}