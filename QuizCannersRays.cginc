uniform float4 RayMarchCube_0;
uniform float4 RayMarchCube_0_Size;

uniform float4 RayMarchCube_1;
uniform float4 RayMarchCube_1_Size;
uniform float4 RayMarchCube_1_Reps;

uniform float4 RayMarchSphere_0;
uniform float4 RayMarchSphere_0_Reps;
uniform float4 RayMarchSphere_0_Size;

uniform float4 RayMarchSphere_1;
uniform float4 RayMarchSphere_1_Reps;
uniform float4 RayMarchSphere_1_Size;

uniform float4 GlassCube_0;
uniform float4 GlassCube_0_Size;

uniform float4 _RayMarchLightColor;
uniform float4 _RayMarchSkyColor;
uniform float _RayTraceTransparency;


uniform float _MaxRayMarchDistance;

uniform float4 RayMarchLight_0;

uniform sampler2D _RayMarchingVolume;
uniform sampler2D _qcPp_DestBuffer;
uniform float4 _RayMarchingVolumeVOLUME_POSITION_N_SIZE;
uniform float4 _RayMarchingVolumeVOLUME_H_SLICES;
