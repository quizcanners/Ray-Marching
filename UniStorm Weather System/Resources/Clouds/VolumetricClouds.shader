Shader "UniStorm/Clouds/Volumetric"
{
	Properties
	{
		_uHorizonColor("_uHorizonColor", Color) = (1.0, 1.0, 1.0, 1.0)
		_uCloudsColor("_uCloudsColor", Color) = (1.0, 1.0, 1.0, 1.0)
		_uLightningColor("_uLightningColor", Color) = (1.0, 1.0, 1.0, 1.0)
		_uFogColor("_uFogColor", Color) = (1.0, 1.0, 1.0, 1.0)
		_uSunDir("_uSunDir", Vector) = (0.0, 1.0, 0.0, 0.0)
		_uSunColor("_uSunColor", Color) = (1.4, 1.26, 1.19, 0.0)

		_uLightningContrast("_uLightningContrast", Range(0.0, 3.0)) = 3.0
		_uMoonAttenuation("_uMoonAttenuation", Float) = 1.0

		_uCloudsBottom("_uCloudsBottom", Float) = 1350.0

		_uCloudsCoverage("_uCloudsCoverage", Range(0.0, 1.0)) = 0.52
		_uCloudsCoverageBias("_uCloudsCoverageBias", Range(-1.0, 1.0)) = 0.0

		_uAttenuation("_uAttenuation", Float) = 1.0
		_uCloudsMovementSpeed("_uCloudsMovementSpeed", Range(0.0, 150)) = 20
		_uCloudsTurbulenceSpeed("_uCloudsTurbulenceSpeed", Range(0.0, 50)) = 50.0

		//_uCloudsDetailStrength("_uCloudsDetailStrength", Range(0.0, 0.4)) = 0.2
		//_uCloudsBaseEdgeSoftness("_uCloudsBaseEdgeSoftness", Float) = 0.1
		_uCloudsBottomSoftness("_uCloudsBottomSoftness", Float) = 0.25
		_uCloudsDensity("_uCloudsDensity", Range(0.0, 1.0)) = 0.03
		_uCloudsForwardScatteringG("_uCloudsForwardScatteringG", Float) = 0.8
		_uCloudsBackwardScatteringG("_uCloudsBackwardScatteringG", Float) = -0.2

		_uCloudsAmbientColorTop("_uCloudsAmbientColorTop", Color) = (0.87674, 0.98235, 1.1764, 0.0)
		_uCloudsAmbientColorBottom("_uCloudsAmbientColorBottom", Color) = (0.2294, 0.3941, 0.5117, 0.0)

		_uCloudsBaseScale("_uCloudsBaseScale", Float) = 1.51
		_uCloudsDetailScale("_uCloudsDetailScale", Float) = 20.0
		_uCurlScale("_uCurlScale", Float) = 20.0
		_uCurlStrength("_uCurlStrength", Range(0.0, 2.5)) = 1.0

		_uHorizonDarkness("_uHorizonDarkness", Range(0.0, 2.0)) = 1.0
		_uCloudAlpha("_uCloudAlpha", Range(0.0, 4.55)) = 3.25
		
		_FogColor("Fog Color", Color) = (1, 0.99, 0.87, 1)
		_MoonColor("Moon Color", Color) = (1, 0.99, 0.87, 1)
		_FogBlendHeight("-", Range(0, 1)) = 1.0

		//_SunIntensity("Fog Sun Intensity", float) = 2.0
		//_MoonIntensity("Fog Moon Intensity", float) = 1.0

		_SunVector("Sun Vector", Vector) = (0.269, 0.615, 0.740, 0)
		_MoonVector("Moon Vector", Vector) = (0.269, 0.615, 0.740, 0)

		_SunControl("Sun Control", float) = 1
		_MoonControl("Moon Control", float) = 1

		[Toggle] _VRSinglePassEnabled("VR Enabled", Float) = 0
		[Toggle] _MaskMoon("Moon Masked", Float) = 0
		[Toggle] _EnableDithering("Enable Dithering", Float) = 0
		[Toggle] _UseHighConvergenceSpeed("Use High Convergence Speed", Float) = 0

		_CloudCurl("Cloud Curls (RGB)", 2D) = "white" 

	}

		SubShader
	{
		Tags{ "Queue" = "Transparent" "IgnoreProjector" = "True" }
		LOD 100
		ZWrite Off

		Pass
		{

		CGPROGRAM

		#if defined(D3D11)
		#pragma warning disable x3595 // private field assigned but not used.
		#endif

		#pragma vertex vert
		#pragma fragment frag
		#pragma multi_compile LOW MEDIUM HIGH ULTRA
		#pragma multi_compile TWOD VOLUMETRIC
		#pragma multi_compile SHADOW __

	sampler2D _Global_Noise_Lookup;
	float _EnableDithering;
    
    uniform sampler2D _uBaseNoise;
    uniform sampler2D _uCurlNoise;
    uniform sampler3D _uDetailNoise;

    uniform float _Seed; 
    uniform float _uSize;
	uniform float _uCloudAlpha;

    uniform float3 _uWorldSpaceCameraPos;
	half3 _MoonColor;
	half3 _FogColor;
	float _FogBlendHeight;
	half3 _SunVector;
	half3 _MoonVector;
	float _SunControl;
	float _MoonControl;

    #include "UnityCG.cginc"
    #include "cloudsInclude.cginc"

    struct appdata
    {
        float2 uv : TEXCOORD0;
        float4 vertex : POSITION;
    };

    struct v2f
    {
        float4 vertex : SV_POSITION;
        float2 uv : TEXCOORD0;
		float3 worldPos : TEXCOORD1;
    };

    sampler2D _MainTex;
    float4 _MainTex_ST;

    v2f vert(appdata v)
    {
        v2f o;

        UNITY_INITIALIZE_OUTPUT(v2f, o);
		o.worldPos = mul(unity_ObjectToWorld, v.vertex);

        o.uv = v.uv;
        o.vertex = UnityObjectToClipPos(v.vertex);
        return o;
    }

    uniform float _uHorizonDarkness;
	uniform float _MaskMoon;
	uniform float _VRSinglePassEnabled;

	float4 _uHorizonColor;
	float _uCloudHeight;
	
	float4 _Effect_Time;

    fixed4 frag(v2f i) : SV_Target
    {
        float2 lon = (i.uv.xy + _uJitter * (1.0 / _uSize)) - 0.5;
		float lonLen = length(lon);
        float a1 = lonLen * 3.181592;
        float sin1 = sin(a1);
        float cos1 = cos(a1);
        float cos2 = lon.x / lonLen;
        float sin2 = lon.y / lonLen;

        float4 clouds = 0.0;

		float3 ro = float3(0, 0, 0);
        float3 rd = normalize(float3(sin1 * cos2, cos1, sin1 * sin2));

        renderClouds(clouds, ro, rd);

        float rddotup = rd.y;//dot(float3(0, 1, 0), rd);
        float sstep = smoothstep(-0.05, 0.5, rddotup);
		float sstep2 = smoothstep(-0.2, 0.32, rddotup);
		float HorizonStep = smoothstep(0, 0.045f, rddotup);

		float step12 =  sstep * sstep2;

		float cloudCoverage = _uCloudsCoverage + _uCloudsCoverageBias;

		//return cloudCoverage;

		float4 final = float4(
			lerp(_uCloudsAmbientColorBottom.rgb //* 2 * (1.0 - remap(cloudCoverage, 0.77, 0.25))
				,
				clouds.rgb*1.035 * step12,  step12),
			lerp((1.0 - remap(cloudCoverage, 0.9, 0.185))
				,  (1.0 - clouds.a) * sstep,  sstep)
			);

        return final;
    }
        ENDCG
}

Pass
{
	Cull Off ZWrite Off ZTest Always
	CGPROGRAM
	#pragma vertex vert
	#pragma fragment frag

	#pragma multi_compile LOW MEDIUM HIGH ULTRA
	#pragma multi_compile TWOD VOLUMETRIC
	#pragma multi_compile __ PREWARM

	#include "UnityCG.cginc"

		uniform float _DistantCloudUpdateSpeed;
        uniform float       _uSize;
        uniform float2      _uJitter;
        uniform sampler2D   _uPreviousCloudTex;
        uniform sampler2D   _uLowresCloudTex;

        uniform float _uCloudsCoverageBias;
		uniform float _UseHighConvergenceSpeed;
        uniform float _uLightningTimer = 0.0;

        uniform float _uConverganceRate;
		
	float4 _Effect_Time;
	
	

        struct appdata
		{
			float4 vertex : POSITION;
			float2 uv : TEXCOORD0;
		};

		struct v2f
		{
			float4 vertex : SV_POSITION;
			float2 uv : TEXCOORD0;
			
		};

        v2f vert(appdata v)
        {
            v2f o;
            o.vertex = UnityObjectToClipPos(v.vertex);
            o.uv = v.uv;
			
            return o;
        }

        half CurrentCorrect(float2 uv, float2 jitter) {
            float2 texelRelativePos = floor(fmod(uv * _uSize, 4.0)); //between (0, 4.0)

            texelRelativePos = abs(texelRelativePos - jitter);

            return saturate(texelRelativePos.x + texelRelativePos.y);
        }

		half4 SamplePrev(float2 uv) {
			return tex2D(_uPreviousCloudTex, uv);
		}

        float4 SampleCurrent(float2 uv) {
            return tex2D(_uLowresCloudTex, uv);
        }

        float _uCloudsMovementSpeed;
        float remap(float v, float s, float e)
        {
            return (v - s) / (e - s);
        }

        half4 frag(v2f i) : SV_Target
        {
            float2 uvN = i.uv * 2.0 - 1.0;

            float4 currSample = SampleCurrent(i.uv);
            half4 prevSample = SamplePrev(i.uv);

            float luvN = length(uvN);

            half correct = CurrentCorrect(i.uv, _uJitter);

#if defined(PREWARM)
            return lerp(currSample, prevSample, correct); // No converging on prewarm
#endif

			
#if defined(ULTRA) || defined (HIGH)

			float ms01 = remap(lerp(_uCloudsMovementSpeed, _DistantCloudUpdateSpeed, _UseHighConvergenceSpeed), 0, 150);
			float converganceSpeed = lerp(0.4, 0.99, ms01);

#else
			float ms01 = remap(_uCloudsMovementSpeed, 0, 150);
            float converganceSpeed = lerp(lerp(0.4, 0.95, ms01), 0.85, saturate(_uLightningTimer - _Effect_Time.y) * 5.0);
			
#endif		

		return lerp(prevSample, lerp(currSample, prevSample, correct), lerp(converganceSpeed, lerp(0.15, 0.25, ms01), luvN));
        }

        ENDCG
    }
}
Fallback Off
}
