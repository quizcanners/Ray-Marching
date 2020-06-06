Shader "Node Notes/Fog Tunnel" {
	Properties{

		_Test0("0", Range(0,4)) = 1
		_Test1("1", Range(0,4)) = 1
		_Test2("2", Range(0,4)) = 1
		_Test3("3", Range(0,4)) = 1
	}

		Category{
			Tags{
				"Queue" = "Transparent"
			}

			Blend SrcAlpha OneMinusSrcAlpha
			ColorMask RGB
			Cull off
			ZTest off
			ZWrite off

			SubShader{
				Pass{

					CGPROGRAM

					#pragma vertex vert
					#pragma fragment frag
					#include "UnityCG.cginc"


					uniform float _Test0;
					uniform float _Test1;
					uniform float _Test2;
					uniform float _Test3;


				struct v2f {
					float4 pos : POSITION;
					float2 texcoord : TEXCOORD0;
				};

				v2f vert(appdata_full v) {
					v2f o;
					o.pos = UnityObjectToClipPos(v.vertex);
					o.texcoord = v.texcoord.xy;
					return o;
				}

				float Mix(float a,float b, float x){
					return a * (1 - x) + b * x;
				}


				float2 Rot(float2 uv, float angle) {
					float si = sin(angle);
					float co = cos(angle);
					return float2(co * uv.x - si * uv.y, si * uv.x + co * uv.y);
				}

				float2x2 rot(in float a) { float c = cos(a), s = sin(a);
				return float2x2(c, s, -s, c); }
				const float3x3 m3 = float3x3(0.33338, 0.56034, -0.71817, -0.87887, 0.32651, -0.15323, 0.15162, 0.69596, 0.61339)*1.93;
				float mag2(float2 p) { return dot(p, p); }
				float linstep(in float mn, in float mx, in float x) { return saturate((x - mn) / (mx - mn)); }
			
				float2 disp(float t) { return float2(sin(t*0.22)*1., cos(t*0.175)*1.)*2.; }

				float2 map(float3 p, float iTime, float prm1)
				{
					

					float3 p2 = p;
					p2.xy -= disp(p.z).xy;
					p.xy = Rot(p.xy, sin(p.z + iTime)*(0.1 + prm1 * 0.05) + iTime * 0.09); //rot(sin(p.z + _Time.x)*(0.1 + prm1 * 0.05) + _Time.x * 0.09);
					float cl = mag2(p2.xy);
					float d = 0.;
					p *= .61;
					float z = 1.;
					float trk = 1.;
					float dspAmp = 0.1 + prm1 * 0.2;
					for (int i = 0; i < 5; i++)
					{
						p += sin(p.zxy*0.75*trk + iTime * trk*.8)*dspAmp;
						d -= abs(dot(cos(p), sin(p.yzx))*z);
						z *= 0.57;
						trk *= 1.4;
						p = mul(p, m3);
					}
					d = abs(d + prm1 * 3.) + prm1 * .3 - 2.5;
					return float2(d + cl * 0.2 + 0.25, cl);
				}


				float4 render(in float3 ro, in float3 rd, float time, float iTime, inout float prm1)
				{
					float4 rez = 0;
					const float ldst = 8.;
					float3 lpos = float3(disp(time + ldst)*0.5, time + ldst);
					float t = 1.5;
					float fogT = 0.;
					for (int i = 0; i < 60; i++)
					{
						if (rez.a > 0.99)break;

						float3 pos = ro + t * rd;
						float2 mpv = map(pos, iTime, prm1);
						float den = saturate(mpv.x - 0.3)*1.12;
						float dn = clamp((mpv.x + 2. ), 0.0, 3.0);

						float4 col = 0;
						if (mpv.x > 0.6)
						{

							col = float4(sin(float3(5., 0.4, 0.2) + mpv.y*0.1 + sin(pos.z*0.4)*0.5 + 1.8)*0.5 + 0.5, 0.08);
							col *= den * den * den;
							col.rgb *= linstep(4., -2.5, mpv.x)*2.3;
							float dif = clamp((den - map(pos + .8, iTime, prm1).x) / 9., 0.001, 1.);
							dif += clamp((den - map(pos + .35, iTime, prm1).x) / 2.5, 0.001, 1.);
							col.xyz *= den * (float3(0.005, .045, .075) + 1.5*float3(0.033, 0.07, 0.03)*dif);
						}

						float fogC = exp(t*0.2 - 2.2 );
						col += float4(0.06, 0.11, 0.11, 0.1)*clamp(fogC - fogT, 0., 1.);
						fogT = fogC;
						rez += col * (1. - rez.a);
						t += clamp(0.5 - dn * dn*.05, 0.09, 0.3);
					}
					return float4(saturate(rez.rgb) ,1);
				}

				float getsat(float3 c)
				{
					float mi = min(min(c.x, c.y), c.z);
					float ma = max(max(c.x, c.y), c.z);
					return (ma - mi) / (ma + 1e-7);
				}

				float4 frag(v2f i) : COLOR{


					float iTime = _Time.y * 2;

					float2 q = i.texcoord.xy;//fragCoord.xy / iResolution.xy;
					float2 p = (i.texcoord.xy - 0.5) * float2(2,1); //(gl_FragCoord.xy - 0.5*iResolution.xy) / iResolution.y;

					float time = iTime * 3.;
					float3 ro = float3(0,0,time);

					ro += float3(sin(iTime)*0.5,sin(iTime*1.)*0.,0);

					float dspAmp = .85;
					ro.xy += disp(ro.z)*dspAmp;
					float tgtDst = 3.5;

					float3 target = normalize(ro - float3(disp(time + tgtDst)*dspAmp, time + tgtDst));
					
					float3 rightdir = normalize(cross(target, float3(0,1,0)));
					float3 updir = normalize(cross(rightdir, target));
					rightdir = normalize(cross(updir, target));
					float3 rd = normalize((p.x*rightdir + p.y*updir)*1. - target);
					rd.xy = Rot(rd.xy, -disp(time + 3.5).x*0.2);
					float prm1 = smoothstep(-0.4, 0.4,sin(iTime*0.3));
					
					return render(ro, rd, time, iTime, prm1);


				

				}
				ENDCG
			}
		}
}
}
