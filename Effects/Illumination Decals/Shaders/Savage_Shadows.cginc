			inline float3 filmicGamma(float3 l) {
				float3 x = max(0.0, l - 0.004);
				return (x*(x*6.2 + 0.5)) / (x*(x*6.2 + 1.7) + 0.06);
			}

			inline float sphereShadow(in float3 ro, in float3 rd, in float4 sph, in float k)
			{
			// k approx 1/3

				float3 oc = ro - sph.xyz;
				float b = dot(oc, rd);
				float c = dot(oc, oc) - sph.w*sph.w;
				float h = b * b - c;

				// physically plausible shadow
				float d = sqrt(max(0.0, sph.w*sph.w - h)) - sph.w;
				float t = -b - sqrt(max(h, 0.0));
				return (t < 0.0) ? /*1.0*/step(-0.00001, c) : smoothstep(0.0, 1.0, 2.5*k*d / t);
				//return (t < 0.0) ? /*1.0*/step(-0.00001, c) : saturate(2.5*k*d / t);
				//return (t < 0.0) ? /*1.0*/step(-0.00001, c) : smoothstep(0.0, 1.0, lerp(2.5*k*d / t, 1.0, saturate(c/sph.w / 500)));

				// cheap alternative
				//return (b > 0.0) ? step(-0.0001, c) : smoothstep(0.0, 1.0, h*k*4 / b);
			}

			inline float capsuleShadow(in float3 ro, in float3 rd, in float3 a, in float3 b, in float r, in float k)
			{
				float3 ba = b - a;
				float3 oa = ro - a;

				// closest distance between ray and segment
				// naive way to solve the 2x2 system of equations
				float oad = dot(oa, rd);
				float dba = dot(rd, ba);
				float baba = dot(ba, ba);
				float oaba = dot(oa, ba);
				float2 th = float2(-oad * baba + dba * oaba, oaba - oad * dba) / (baba - dba * dba);
				// fizzer's way to solve the 2x2 system of equations
				//float3 th = mul(transpose(float3x3(-rd, ba, cross(rd, ba))), oa);//can cpu calculate this? transpose(float3x3(-rd, ba, cross(rd, ba)))

				th.x = max(th.x, 0.0001);
				th.y = saturate(th.y);
				float3  p = a + ba * th.y;
				float3  q = ro + rd * th.x;
				float d = length(p - q) - r;

				// fake shadow
				float s = saturate(k*d / th.x);
				return s * s*(3.0 - 2.0*s);
			}
			//inline float dot2(in float3 v) { return dot(v, v); }
			inline float segShadow(in float3 ro, in float3 rd, in float3 pa, float sh)
			{
				float dm = dot(rd.yz, rd.yz);
				float k1 = (ro.x - pa.x)*dm;
				float k2 = (ro.x + pa.x)*dm;
				float2  k5 = (ro.yz + pa.yz)*dm;
				float k3 = dot(ro.yz + pa.yz, rd.yz);
				float2  k4 = (pa.yz + pa.yz)*rd.yz;
				float2  k6 = (pa.yz + pa.yz)*dm;

				for (int i = 0; i < 4; i++)
				{
					float2  s = float2(i & 1, i >> 1);
					float t = dot(s, k4) - k3;

					if (t > 0.0)
						sh = min(sh, dot2(float3(clamp(-rd.x*t, k1, k2), k5 - k6 * s) + rd * t) / (t*t));
						//sh = min(sh, lerp(dot2(float3(clamp(-rd.x*t, k1, k2), k5 - k6 * s) + rd * t) / (t*t), 1.0, t / 1000.0));//distfade tests<V
					//lerp(2.5*k*d / t, 1.0, saturate(c / sph.w / 500)
				}
				return sh;
			}

			inline float sdBox(float3 p, float3 b)
			{
				float3 d = abs(p) - b;
				return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
			}

			inline float boxShadow(float3 ro, float3 rd, float4x4 txx, float3 rad, float sk, float fadeDist)
			{
				float3 rdd = mul(txx, float4(rd, 0.0)).xyz;
				float3 roo = mul(txx, float4(ro, 1.0)).xyz;


				float3 m = 1.0 / rdd;
				float3 n = m * roo;
				float3 k = abs(m)*rad;

				float3 t1 = -n - k;
				float3 t2 = -n + k;

				float tN = max(max(t1.x, t1.y), t1.z);
				float tF = min(min(t2.x, t2.y), t2.z);

				float dist = sdBox(roo, rad);
				dist = smoothstep(0, 1, dist / fadeDist / sk);

				/*
				if (cheap)
				{
					if (tN < tF && tF >= 0.0) return lerp(0.0, 1.0, dist);
					if (tF < 0.0) return 1.0;
					float sh = saturate(0.3*(sk*2.0)*(tN - tF) / tN);
					return lerp(sh * sh*(3.0 - 2.0*sh), 1.0, dist);
				}
				else*/
				{
				
					if (tN<tF && tF>=0.0) return lerp(0.0, 1.0, dist);
					float sh = 1.0;
					sh = segShadow(roo.xyz, rdd.xyz, rad.xyz, sh);
					sh = segShadow(roo.yzx, rdd.yzx, rad.yzx, sh);
					sh = segShadow(roo.zxy, rdd.zxy, rad.zxy, sh);
					sh = saturate(sk*sqrt(sh));
					return lerp(sh * sh*(3.0 - 2.0*sh), 1.0, dist);
				}
			}


			//
			#define PI 3.14159265359
			float acosFast(float inX)
			{
				float x = abs(inX);
				float res = -0.156583f * x + (0.5 * PI);
				res *= sqrt(1.0f - x);
				return (inX >= 0) ? res : PI - res;
			}

			float SphericalCapIntersectionAreaFast(float fRadius0, float fRadius1, float fDist)
			{
				float fArea;

				if (fDist <= max(fRadius0, fRadius1) - min(fRadius0, fRadius1))
				{
					// One cap is completely inside the other
					fArea = 6.283185308f - 6.283185308f * cos(min(fRadius0, fRadius1));
				}
				else if (fDist >= fRadius0 + fRadius1)
				{
					// No intersection exists
					fArea = 0;
				}
				else
				{
					float fDiff = abs(fRadius0 - fRadius1);
					fArea = smoothstep(0.0f,
						1.0f,
						1.0f - saturate((fDist - fDiff) / (fRadius0 + fRadius1 - fDiff)));
					//fArea = 1.0f - saturate((fDist - fDiff) / (fRadius0 + fRadius1 - fDiff));
					fArea *= 6.283185308f - 6.283185308f * cos(min(fRadius0, fRadius1));
				}
				return fArea;
			}

			float atanFastPos(float x)
			{
				float t0 = (x < 1.0f) ? x : 1.0f / x;
				float t1 = t0 * t0;
				float poly = 0.0872929f;
				poly = -0.301895f + poly * t1;
				poly = 1.0f + poly * t1;
				poly = poly * t0;
				return (x < 1.0f) ? poly : (0.5 * PI) - poly;
			}

			void GenerateCoordinateSystem(float3 ZAxis, out float3 XAxis, out float3 YAxis)
			{
				// Generates arbitrary but valid perpendicular unit vectors to ZAxis(UP). ZAxis should be unit length.
				if (abs(ZAxis.x) > abs(ZAxis.y))
				{
					float InverseLength = 1.0f / sqrt(dot(ZAxis.xz, ZAxis.xz));
					XAxis = float3(-ZAxis.z * InverseLength, 0.0f, ZAxis.x * InverseLength);
				}
				else
				{
					float InverseLength = 1.0f / sqrt(dot(ZAxis.yz, ZAxis.yz));
					XAxis = float3(0.0f, ZAxis.z * InverseLength, -ZAxis.y * InverseLength);
				}

				YAxis = cross(ZAxis, XAxis);
			}

			// ALGO

			float sphereShadow(float3 WorldRayStart, float3 UnitRayDirection, float LightAngle, float4 SphereCenterAndRadius, float MaxDist, float LightVectorLength) 
			{
				float DistanceToShadowSphere = length(SphereCenterAndRadius.xyz - WorldRayStart);
				float3 UnitVectorToShadowSphere = (SphereCenterAndRadius.xyz - WorldRayStart) / DistanceToShadowSphere;

				float AngleBetween = acosFast(dot(UnitVectorToShadowSphere, UnitRayDirection));
				float IntersectionArea = SphericalCapIntersectionAreaFast(LightAngle, atanFastPos(SphereCenterAndRadius.w / DistanceToShadowSphere), AngleBetween);
				float LightW = 1;

				//if (_Light.w > 0) 
				//{
					// To prevent discontinuity, we use the ratio of the distance difference to the sphere's radius as a smooth factor
					IntersectionArea = lerp(IntersectionArea, 0, saturate((DistanceToShadowSphere - LightVectorLength + SphereCenterAndRadius.w) / SphereCenterAndRadius.w));
				//}
				float AreaOfLight = 6.283185308f - 6.283185308f * cos(LightAngle);
				float ConeConeIntersection = 1 - saturate(IntersectionArea / AreaOfLight);
				
				float MaxOcclusionDistance = MaxDist * SphereCenterAndRadius.w / (LightW > 0 ? LightVectorLength / LightW : 1);
				ConeConeIntersection = lerp(ConeConeIntersection, 1, saturate(DistanceToShadowSphere * (1.0 / MaxOcclusionDistance) * 3 - 2));

				return ConeConeIntersection;
			}
			
			float capsuleShadow(float3 WorldRayStart, float3 UnitRayDirection, float LightAngle, float4 CapsuleCenterAndRadius, float4 CapsuleOrientationAndLength, float MaxDist, float LightVectorLength)
			{
				float3 CapsuleSpaceX;
				float3 CapsuleSpaceY;
				float3 CapsuleSpaceZ = CapsuleOrientationAndLength.xyz;
				GenerateCoordinateSystem(CapsuleSpaceZ, CapsuleSpaceX, CapsuleSpaceY);

				float CapsuleZScale = CapsuleCenterAndRadius.w / (.5f * CapsuleOrientationAndLength.w + CapsuleCenterAndRadius.w);
				CapsuleSpaceZ *= CapsuleZScale;

				float3 CapsuleCenterToRayStart = WorldRayStart - CapsuleCenterAndRadius.xyz;
				float3 CapsuleSpaceRayStart = float3(dot(CapsuleCenterToRayStart, CapsuleSpaceX), dot(CapsuleCenterToRayStart, CapsuleSpaceY), dot(CapsuleCenterToRayStart, CapsuleSpaceZ));

				float3 CapsuleSpaceRayDirection = float3(dot(UnitRayDirection, CapsuleSpaceX), dot(UnitRayDirection, CapsuleSpaceY), dot(UnitRayDirection, CapsuleSpaceZ));

				float DistanceToShadowSphere = length(CapsuleSpaceRayStart);
				float3 UnitVectorToShadowSphere = -CapsuleSpaceRayStart / DistanceToShadowSphere;
				UnitRayDirection = normalize(CapsuleSpaceRayDirection);

				float AngleBetween = acosFast(dot(UnitVectorToShadowSphere, UnitRayDirection));
				float IntersectionArea = SphericalCapIntersectionAreaFast(LightAngle, atanFastPos(CapsuleCenterAndRadius.w / DistanceToShadowSphere), AngleBetween);

				float LightW = 1;

			//	if (_Light.w > 0)
				//{
					// To prevent discontinuity, we use the ratio of the distance difference to the capsule's radius as a smooth factor
					IntersectionArea = lerp(IntersectionArea, 0, saturate((DistanceToShadowSphere - LightVectorLength + CapsuleCenterAndRadius.w) / CapsuleCenterAndRadius.w));
				//}
				float AreaOfLight = 6.283185308f - 6.283185308f * cos(LightAngle);
				float ConeConeIntersection = 1 - saturate(IntersectionArea / AreaOfLight);

				//float MaxOcclusionDistance = 10. * CapsuleCenterAndRadius.w / LightAngle;
				float MaxOcclusionDistance = MaxDist * CapsuleCenterAndRadius.w / (LightW > 0 ? LightVectorLength / LightW : 1);
				ConeConeIntersection = lerp(ConeConeIntersection, 1, saturate(DistanceToShadowSphere * (1.0 / MaxOcclusionDistance) * 3 - 2));

				//ConeConeIntersection = lerp(MinVisibility, 1, ConeConeIntersection);
				//ConeConeIntersection = smoothstep(0, 1, ConeConeIntersection);

				return ConeConeIntersection;
			}
			//

