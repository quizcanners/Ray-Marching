
#define TOP_DOWN_SETUP_UV(UV, WORLD_POS)  \
float2 UV = (WORLD_POS.xz - _RayTracing_TopDownBuffer_Position.xz) * _RayTracing_TopDownBuffer_Position.w + 0.5;

#define TOP_DOWN_OFFSET_UV_BY_WORLD_VECTOR(UV, VEC)   \
UV += VEC.xz * _RayTracing_TopDownBuffer_Position.w;

#define TOP_DOWN_SAMPLE_LIGHT(COLOR, UV)   \
float4 COLOR = tex2Dlod(_RayTracing_TopDownBuffer, float4(UV,0,0));

#define TOP_DOWN_VISIBILITY(ALPHA, POS, OUT_OF_BOUNDS)     \
float ALPHA = (1 - OUT_OF_BOUNDS) * smoothstep(3, 0, abs(_RayTracing_TopDownBuffer_Position.y - POS.y));


inline void TopDownSample(float3 pos, inout float3 baked, float outOfBounds)
{
	TOP_DOWN_SETUP_UV(uv, pos);
	TOP_DOWN_SAMPLE_LIGHT(light, uv);
	TOP_DOWN_VISIBILITY(alpha, pos, outOfBounds);
	light *= alpha;
	baked *= max(0.25f, 1 - light.a);
	baked.rgb += light.rgb;
}