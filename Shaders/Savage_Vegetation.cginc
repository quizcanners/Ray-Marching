
//Savage_VolumeSampling

				#include "Signed_Distance_Functions.cginc"
	#include "Savage_VolumeSampling.cginc"

float4 qc_WindDirection;
float4 qc_WindParameters;

float3 WindShakeWorldPos(float3 worldPos, float shakeCoefficient)
{
	float outOfBounds;
	float sdfWorld = SampleSDF(worldPos, outOfBounds).a;
	//float useSdf = smoothstep(0, -0.05 * coef, sdfWorld.w);

	shakeCoefficient *= shakeCoefficient;

	//float offGround = smoothstep(0.25,1, worldPos.y);

	//float offset = smoothstep(0.25, -0.25, sdfWorld.w);
	//worldPos.xyz += offset * sdfWorld.xyz * offGround;

	float distance = lerp(smoothstep(0,5,sdfWorld),1, outOfBounds);

	float3 gyrPos = worldPos;
	gyrPos.y *= 0.1;
	gyrPos.y += _Time.x * 80;
	float gyr = sdGyroid(gyrPos, 1);
	//float power = smoothstep(0,3, distance);

	//float3 shake = qc_WindDirection.xyz * _SinTime.x;// * (gyr + abs(gyr) * 0.5); 
	
	//float3(sin(gyrPos.x + _Time.z), gyr, sin(gyrPos.z + _Time.z));// *gyr;
				
	//float len = dot(shake, shake);

	float intense = smoothstep(0.975, 1, shakeCoefficient);

	//shake.y = gyr * 0.1;

	gyr = sign(gyr) * (1-pow(1-gyr, 2));

	float3 intenseShaking = intense * gyr;

	worldPos.xyz += intenseShaking * distance * 0.1;// * qc_WindDirection.xyz;

	float offset = sin(qc_WindParameters.x * _Time.x + worldPos.x * 0.03) * sin(qc_WindParameters.x + worldPos.z * 0.1 + _Time.y * 1.234);

	//offset = sign(offset) * (1-pow(1-abs(offset), 1.5));

	worldPos.xyz += shakeCoefficient * distance * qc_WindDirection.xyz * offset; //shake * len * 0.02 * distance; // *(gyr - 0.5);
	
	worldPos.y -= abs(offset) * length(qc_WindDirection.xyz) * 0.2 * distance * shakeCoefficient * shakeCoefficient;

	return worldPos;
}
