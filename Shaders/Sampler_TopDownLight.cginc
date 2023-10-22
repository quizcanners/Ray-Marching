
float4 _RayTracing_TopDownBuffer_Position;
sampler2D _RayTracing_TopDownBuffer;

#define TOP_DOWN_SETUP_UV(UV, WORLD_POS)  \
float2 UV = (WORLD_POS.xz - _RayTracing_TopDownBuffer_Position.xz) * _RayTracing_TopDownBuffer_Position.w + 0.5;

#define TOP_DOWN_OFFSET_UV_BY_WORLD_VECTOR(UV, VEC)   \
UV += VEC.xz * _RayTracing_TopDownBuffer_Position.w;

#define TOP_DOWN_SAMPLE_LIGHT(COLOR, UV)   \
float4 COLOR = tex2Dlod(_RayTracing_TopDownBuffer, float4(UV,0,0));

#define TOP_DOWN_ALPHA(ALPHA, POS, UV)\
	float2 offUv = (UV - 0.5);\
	float ALPHA = (1 - smoothstep(0.2, 0.25, length(offUv * offUv))) / (1 + pow(abs(POS.y - _RayTracing_TopDownBuffer_Position.y),3));

inline float TopDownSample(float3 pos, inout float3 baked)
{
	TOP_DOWN_SETUP_UV(uv, pos);
	TOP_DOWN_SAMPLE_LIGHT(light, uv);
	TOP_DOWN_ALPHA(alpha, pos, uv);

	light *= alpha;
	//baked *= max(0.25f, 1 - light.a);
	baked.rgb += light.rgb;

	return 0.25 + smoothstep(1,0,light.a) * 0.75;
}

inline float TopDownSample_Shadow(float3 pos)
{
	TOP_DOWN_SETUP_UV(uv, pos);
	TOP_DOWN_SAMPLE_LIGHT(light, uv);

	return light.a;
}