Shader "Hidden/UniStorm/CloudShadows"
{
    Properties
    {
        _MainTex("Source", 2D) = "white" {}
    }

    CGINCLUDE

    #include "UnityCG.cginc"

    sampler2D _MainTex;
    float4 _MainTex_TexelSize;

    // http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
    half4 gaussian_filter(float2 uv, float2 stride)
    {
        half4 s = tex2D(_MainTex, uv) * 0.227027027;

        float2 d1 = stride * 1.3846153846;
        s += tex2D(_MainTex, uv + d1) * 0.3162162162;
        s += tex2D(_MainTex, uv - d1) * 0.3162162162;

        float2 d2 = stride * 3.2307692308;
        s += tex2D(_MainTex, uv + d2) * 0.0702702703;
        s += tex2D(_MainTex, uv - d2) * 0.0702702703;

        return s;
    }

    // Quarter downsampler
    half4 frag_quarter(v2f_img i) : SV_Target
    {
        float4 d = _MainTex_TexelSize.xyxy * float4(1, 1, -1, -1);
        half4 s;
        s  = tex2D(_MainTex, i.uv + d.xy);
        s += tex2D(_MainTex, i.uv + d.xw);
        s += tex2D(_MainTex, i.uv + d.zy);
        s += tex2D(_MainTex, i.uv + d.zw);
        return s * 0.25;
    }

    // Separable Gaussian filters
    half4 frag_blur_h(v2f_img i) : SV_Target
    {
        return gaussian_filter(i.uv, float2(_MainTex_TexelSize.x, 0));
    }

    half4 frag_blur_v(v2f_img i) : SV_Target
    {
        return gaussian_filter(i.uv, float2(0, _MainTex_TexelSize.y));
    }

    uniform float _uCloudsCoverage, _uCloudsCoverageBias, _uCloudsDensity, _uCloudsDetailStrength, _uCloudsBaseEdgeSoftness, _uCloudsBottomSoftness;

    float remap(float v, float s, float e)
    {
        return (v - s) / (e - s);
    }

    float linearstep0(const float e, float v)
    {
        return min(v*(1.0f / e), 1.0f);
    }

    float cloudMapBase(float2 p, float norY)
    {
        float2 offset = float2(0.0f, 0.0f);
        float2 uv = (p + offset);

        float3 cloud = tex2Dlod(_MainTex, float4(uv.xy, 0.0f, 1.0f)).rgb - float3(0.0f, 1.0f, 0.0f);

        float n = norY * norY;
        //n *= cloud.b;
        n += pow(1.0f - norY, 36.0f);
        return remap(cloud.r - n, cloud.g - n, 1.0f);
    }

    float cloudMap(float2 pos, float norY)
    {
        float m = cloudMapBase(pos, norY);
        //m *= cloudGradient(norY);

        float dstrength = smoothstep(1.0f, 0.5f, m);
		//m -= dstrength * _uCloudsDetailStrength * 0.5f;
        m -= dstrength * _uCloudsDetailStrength * 0.6f;

        //m = smoothstep(0.0f, _uCloudsBaseEdgeSoftness, m + ((_uCloudsCoverage + _uCloudsCoverageBias + 0.15f) - 1.0f));
#if UNITY_COLORSPACE_GAMMA
		m = smoothstep(0.0f, clamp(_uCloudsBaseEdgeSoftness, 0.01, 0.05), m + ((_uCloudsCoverage + _uCloudsCoverageBias + 0.14f) - 1.0f)); //Was  + _uCloudsCoverageBias + 0.15f
#else
		m = smoothstep(0.0f, clamp(_uCloudsBaseEdgeSoftness, 0.01, 0.05), m + ((_uCloudsCoverage + _uCloudsCoverageBias + 0.07f) - 1.0f)); //Was  + _uCloudsCoverageBias + 0.15f
#endif

        m *= linearstep0(0.05, norY);

		//return 1.0f - saturate(m * _uCloudsDensity) * 2.0f;
        return 1.0f - saturate(m * clamp(_uCloudsDensity, 0.9, 1)) * 2.0f;
    }

    uniform float _uSimulatedCloudAlpha = 0.3f;
    half4 cheap_cloud_shadows(v2f_img i) : SV_Target
    {
        return lerp(cloudMap(i.uv, 0.5f), 1, _uSimulatedCloudAlpha);
    }

    ENDCG

    Subshader
    {
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_quarter
            ENDCG
        }
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_blur_h
            #pragma target 3.0
            ENDCG
        }
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_blur_v
            #pragma target 3.0
            ENDCG
        }
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment cheap_cloud_shadows
            #pragma target 3.0
            ENDCG
        }
    }
}
