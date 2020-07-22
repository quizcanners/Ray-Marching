// Himalayas. Created by Reinder Nijhoff 2018
// @reindernijhoff
//
// https://www.shadertoy.com/view/MdGfzh
//
// This is my first attempt to render volumetric clouds in a fragment shader.
//
// 1 unit correspondents to SCENE_SCALE meter.

#define SCENE_SCALE (10.)
#define INV_SCENE_SCALE (.1)

#define MOUNTAIN_HEIGHT (5000.)
#define MOUNTAIN_HW_RATIO (0.00016)

#define FLAG_POSITION (float3(3900.5,720.,-2516.)*INV_SCENE_SCALE)
#define HUMANOID_SCALE (2.)

#define CAMERA_RO (float3(3980.,730.,-2650.)*INV_SCENE_SCALE)
#define CAMERA_FL 2.

#define HEIGHT_BASED_FOG_B 0.02
#define HEIGHT_BASED_FOG_C 0.05

//
// Noise functions
//
// Hash without Sine by DaveHoskins 
//
// https://www.shadertoy.com/view/4djSRW
//
float hash12( float2 p ) {
    p  = 50.0*frac( p*0.3183099 );
    return frac( p.x*p.y*(p.x+p.y) );
}

float hash13(float3 p3) {
    p3  = frac(p3 * 1031.1031);
    p3 += dot(p3, p3.yzx + 19.19);
    return frac((p3.x + p3.y) * p3.z);
}

float3 hash33(float3 p3) {
	p3 = frac(p3 * float3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+19.19);
    return frac((p3.xxy + p3.yxx)*p3.zyx);
}

float valueHash(float3 p3) {
    p3  = frac(p3 * 0.1031);
    p3 += dot(p3, p3.yzx + 19.19);
    return frac((p3.x + p3.y) * p3.z);
}

//
// Noise functions used for cloud shapes
//
float valueNoise( in float3 x, float tile ) {
    float3 p = floor(x);
    float3 f = frac(x);
    f = f*f*(3.0-2.0*f);
	
    return lerp(lerp(lerp( valueHash(fmod(p+float3(0,0,0),tile)), 
                        valueHash(fmod(p+float3(1,0,0),tile)),f.x),
                   lerp( valueHash(fmod(p+float3(0,1,0),tile)), 
                        valueHash(fmod(p+float3(1,1,0),tile)),f.x),f.y),
               lerp(lerp( valueHash(fmod(p+float3(0,0,1),tile)), 
                        valueHash(fmod(p+float3(1,0,1),tile)),f.x),
                   lerp( valueHash(fmod(p+float3(0,1,1),tile)), 
                        valueHash(fmod(p+float3(1,1,1),tile)),f.x),f.y),f.z);
}

float voronoi( float3 x, float tile ) {
    float3 p = floor(x);
    float3 f = frac(x);

    float res = 100.;
    for(int k=-1; k<=1; k++){
        for(int j=-1; j<=1; j++) {
            for(int i=-1; i<=1; i++) {
                float3 b = float3(i, j, k);
                float3 c = p + b;

                if( tile > 0. ) {
                    c = fmod( c, float3(tile, tile, tile) );
                }

                float3 r = float3(b) - f + hash13( c );
                float d = dot(r, r);

                if(d < res) {
                    res = d;
                }
            }
        }
    }

    return 1.-res;
}

float tilableVoronoi( float3 p, const int octaves, float tile ) {
    float f = 1.;
    float a = 1.;
    float c = 0.;
    float w = 0.;

    if( tile > 0. ) f = tile;

    for( int i=0; i<octaves; i++ ) {
        c += a*voronoi( p * f, f );
        f *= 2.0;
        w += a;
        a *= 0.5;
    }

    return c / w;
}

float tilableFbm( float3 p, const int octaves, float tile ) {
    float f = 1.;
    float a = 1.;
    float c = 0.;
    float w = 0.;

    if( tile > 0. ) f = tile;

    for( int i=0; i<octaves; i++ ) {
        c += a*valueNoise( p * f, f );
        f *= 2.0;
        w += a;
        a *= 0.5;
    }

    return c / w;
}