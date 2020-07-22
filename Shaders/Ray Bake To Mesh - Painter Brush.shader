Shader "RayTracing/Brush/Baking"
{
	Category{

		 Tags{ "Queue" = "Transparent"}

		 ColorMask RGBA
		 Cull off
		 ZTest off
		 ZWrite off

		 SubShader{
			 Pass{

				 CGPROGRAM

				 #include "Assets/The-Fire-Below/Playtime-Painter/Shaders/PlaytimePainter cg.cginc"

				 #pragma vertex vert
				 #pragma fragment frag

				 struct v2f {
					 float4 pos : POSITION;
					 float4 texcoord : TEXCOORD0;
					 float4 worldPos : TEXCOORD1;
					 float2 srcTexAspect : TEXCOORD3;
				 };

				 v2f vert(appdata_brush_qc v) 
				 {

					 v2f o;

					 float t = _Time.w * 50;

					 float2 jitter = _qcPp_AlphaBufferCfg.y * _qcPp_TargetTexture_TexelSize.xy * float2(sin(t), cos(t * 1.3));

					 float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1));

					 o.worldPos = worldPos;

					 float4 uv = v.texcoord;

					 #if BRUSH_3D_TEXCOORD2
						 uv.xy = v.texcoord1.xy;
					 #endif

					 float2 suv = _qcPp_SourceTexture_TexelSize.zw;
					 o.srcTexAspect = max(1, float2(suv.y / suv.x, suv.x / suv.y));

					 // ATLASED CALCULATION
					 float atY = floor(uv.z / _qcPp_brushAtlasSectionAndRows.z);
					 float atX = uv.z - atY * _qcPp_brushAtlasSectionAndRows.z;
					 uv.xy = (float2(atX, atY) + uv.xy) / _qcPp_brushAtlasSectionAndRows.z
						 * _qcPp_brushAtlasSectionAndRows.w + uv.xy * (1 - _qcPp_brushAtlasSectionAndRows.w);

					 worldPos.xyz = _qcPp_RTcamPosition.xyz;
					 worldPos.z += 100;
					 worldPos.xy += (uv.xy * _qcPp_brushEditedUVoffset.xy + _qcPp_brushEditedUVoffset.zw - 0.5 + jitter) * 256;

					 v.vertex = mul(unity_WorldToObject, float4(worldPos.xyz, v.vertex.w));

					 o.pos = UnityObjectToClipPos(v.vertex);

					 o.texcoord.xy = ComputeScreenPos(o.pos);

					 o.texcoord.zw = o.texcoord.xy - 0.5;

					 return o;
				 }

				 float4 frag(v2f o) : COLOR
				 {
					 #if BRUSH_3D || BRUSH_3D_TEXCOORD2
						 float alpha = prepareAlphaSphere(o.texcoord, o.worldPos.xyz);
						 clip(alpha - 0.000001);
					 #endif

					return 1;
				 }
				 ENDCG
			 }
		 }
	}
}
