using System;
using System.Collections.Generic;
using UnityEngine;

namespace UniStorm.Utility
{
    public class GenerateNoise
    {
        public static string baseFolder = "Assets/UniStorm Weather System/Resources/";

        private static ComputeShader _noiseCompute = null;
        public static ComputeShader noiseCompute
        {
            get
            {
                if (_noiseCompute == null)
                {
                    _noiseCompute = Resources.Load<ComputeShader>("Clouds/noiseGeneration");
                }
                return _noiseCompute;
            }
        }

        private static Texture2D _baseNoiseTexturePrecomputed = null;
        private static RenderTexture _baseNoiseTexture = null;
        public static Texture baseNoiseTexture
        {
            get
            {
                if (SystemInfo.supportsComputeShaders)
                {
                    if (_baseNoiseTexture == null)
                    {
                        GenerateBaseCloudNoise();
                    }
                    return _baseNoiseTexture;
                }

                if (_baseNoiseTexturePrecomputed == null)
                {
                    GenerateBaseCloudNoise();
                }

                return _baseNoiseTexturePrecomputed;
            }
        }

        private static Texture3D _detailNoiseTexture;
        public static Texture3D detailNoiseTexture
        {
            get
            {
                if (_detailNoiseTexture == null)
                {
                    GenerateCloudDetailNoise();
                }
                return _detailNoiseTexture;
            }
        }

        private static Texture2D _curlNoiseTexture;
        public static Texture2D curlNoiseTexture
        {
            get
            {
                if (_curlNoiseTexture == null)
                {
                    GenerateCloudCurlNoise();
                }
                return _curlNoiseTexture;
            }
        }

#if UNITY_EDITOR

        public static void EditorGenerateBaseCloudNoise()
        {
            int resolution = 256;

            Texture2D cpuBaseNoiseTexture = new Texture2D(resolution, resolution, TextureFormat.RGBAFloat, false, true);
            cpuBaseNoiseTexture.wrapMode = TextureWrapMode.Repeat;
            cpuBaseNoiseTexture.filterMode = FilterMode.Trilinear;

            Vector4[] pixels = new Vector4[resolution * resolution];

            for (int x = 0; x < resolution; x++)
            {
                for (int y = 0; y < resolution; y++)
                {
                    Vector4 result = Vector4.zero;
                    Vector3 coord = new Vector3(x / (float)(resolution), y / (float)(resolution), 0.5f);
                    result.x = 0.5f - (0.75f * WNG.ModifiedOctaveNoise(coord, 8, 9, 1, 0.0f, -0.25f)) + (0.2f * WNG.ModifiedOctaveNoise(coord, 4, 4, 1, 0.25f, -0.25f));
                    result.y = 0.5f - (0.75f * WNG.ModifiedOctaveNoise(coord, 4, 20, 1, 0.5f, -0.25f) + (0.2f * WNG.ModifiedOctaveNoise(coord, 8, 10, 1, 0.0f, -0.25f)));
                    result.z = WNG.ModifiedOctaveNoise(coord, 2, 40, 1, 0.25f, -0.25f);
                    pixels[x + y * resolution] = result;
                }
            }

            List<byte> data = new List<byte>();

            foreach (Vector4 v in pixels)
            {
                byte[] buff = new byte[sizeof(float) * 4];
                Buffer.BlockCopy(BitConverter.GetBytes(v.x), 0, buff, 0 * sizeof(float), sizeof(float));
                Buffer.BlockCopy(BitConverter.GetBytes(v.y), 0, buff, 1 * sizeof(float), sizeof(float));
                Buffer.BlockCopy(BitConverter.GetBytes(v.z), 0, buff, 2 * sizeof(float), sizeof(float));
                Buffer.BlockCopy(BitConverter.GetBytes(v.w), 0, buff, 3 * sizeof(float), sizeof(float));

                data.AddRange(buff);
            }

            cpuBaseNoiseTexture.LoadRawTextureData(data.ToArray());
            cpuBaseNoiseTexture.Apply();

            UnityEditor.AssetDatabase.CreateAsset(cpuBaseNoiseTexture, string.Format("{0}Clouds/baseNoise.asset", baseFolder));
            UnityEditor.AssetDatabase.SaveAssets();
        }

        public static void EditorGenerateCloudDetailNoise()
        {
            int resolution = 45; //Was 45

            Texture3D cpuDetailNoiseTexture = new Texture3D(resolution, resolution, resolution, TextureFormat.RGBAFloat, false);
            cpuDetailNoiseTexture.wrapMode = TextureWrapMode.Repeat;
            cpuDetailNoiseTexture.filterMode = FilterMode.Trilinear;
            cpuDetailNoiseTexture.anisoLevel = 16;

            Color[] pixels = new Color[resolution * resolution * resolution];

            for (int x = 0; x < resolution; x++)
            {
                for (int y = 0; y < resolution; y++)
                {
                    for (int z = 0; z < resolution; z++)
                    {
                        Vector3 coord = new Vector3(x / (float)(resolution), y / (float)(resolution), z / (float)(resolution));

                        float r = WNG.OctaveNoise(coord, 4, 4, 0, 0.4f);
                        float g = WNG.OctaveNoise(coord, 1, 1, 0, 0.2f);
                        float b = WNG.OctaveNoise(coord, 2, 25);

                        float c = Mathf.Max(0.0f, 1.0f - (r + g * 0.5f + b * 0.25f) / 1.75f);
                        float c2 = Mathf.Max(0.0f, 1.0f - (g + r * 0.5f + b * 0.25f) / 1.75f);
                        float c3 = Mathf.Max(0.0f, 1.0f - (r + b * 0.5f + g * 0.25f) / 1.75f);

                        pixels[x + y * resolution + z * resolution * resolution] = new Color(c, c2, c3, 1);
                    }
                }
            }

            cpuDetailNoiseTexture.SetPixels(pixels);
            cpuDetailNoiseTexture.Apply();

            UnityEditor.AssetDatabase.CreateAsset(cpuDetailNoiseTexture, string.Format("{0}Clouds/detailNoise.asset", baseFolder));
            UnityEditor.AssetDatabase.SaveAssets();
        }

        public static void EditorGenerateCloudCurlNoise()
        {
            int resolution = 64;

            Texture2D cpuCurlNoiseTexture = new Texture2D(resolution, resolution, TextureFormat.RGBAFloat, false);
            cpuCurlNoiseTexture.wrapMode = TextureWrapMode.Repeat;
            cpuCurlNoiseTexture.filterMode = FilterMode.Trilinear;

            Color[] pixels = new Color[resolution * resolution];
            float eps = 1.0f;// / resolution;
            float n1, n2, a, b;

            for (int x = 0; x < resolution; x++)
            {
                for (int y = 0; y < resolution; y++)
                {
                    n1 = PNG.OctaveNoise(new Vector3(x, y + eps) / (float)resolution, 16, 4);
                    n2 = PNG.OctaveNoise(new Vector3(x, y - eps) / (float)resolution, 16, 4);
                    a = (n1 - n2) / (2);
                    n1 = PNG.OctaveNoise(new Vector3(x + eps, y) / (float)resolution, 16, 4);
                    n2 = PNG.OctaveNoise(new Vector3(x - eps, y) / (float)resolution, 16, 4);
                    b = (n1 - n2) / (2);

                    pixels[x + y * resolution] = new Color(a, -b, 0);
                }
            }

            cpuCurlNoiseTexture.SetPixels(pixels);
            cpuCurlNoiseTexture.Apply();

            UnityEditor.AssetDatabase.CreateAsset(cpuCurlNoiseTexture, string.Format("{0}Clouds/curlNoise.asset", baseFolder));
            UnityEditor.AssetDatabase.SaveAssets();
        }

        public static void EditorGeneratePrecomputedBaseCloudNoise()
        {
            Texture2D cpuBaseNoise = Resources.Load<Texture2D>("Clouds/baseNoise");
            int resolution = cpuBaseNoise.width;

            // Create the render texture
            _baseNoiseTexture = new RenderTexture(resolution, resolution, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Default);
            _baseNoiseTexture.name = "baseNoise";
            _baseNoiseTexture.enableRandomWrite = true;
            _baseNoiseTexture.wrapMode = TextureWrapMode.Repeat;
            _baseNoiseTexture.filterMode = FilterMode.Trilinear;
            _baseNoiseTexture.Create();

            // Generate the base shapes of the clouds here
            int kernel = noiseCompute.FindKernel("CSBaseNoiseMain");
            noiseCompute.SetFloat("_TextureDim", (float)resolution);
            noiseCompute.SetInt("_Seed", DateTime.Now.Millisecond);
            noiseCompute.SetTexture(kernel, "_CPUBase", cpuBaseNoise);
            noiseCompute.SetTexture(kernel, "_Base", _baseNoiseTexture);
            noiseCompute.Dispatch(kernel, resolution / 8, resolution / 8, 1);

            // Store it in a Texture2D again
            Texture2D cpuBaseNoisePrecomputed = new Texture2D(_baseNoiseTexture.width, _baseNoiseTexture.height, TextureFormat.RGBAFloat, false, true);
            cpuBaseNoisePrecomputed.wrapMode = TextureWrapMode.Repeat;
            cpuBaseNoisePrecomputed.filterMode = FilterMode.Trilinear;
            cpuBaseNoisePrecomputed.name = "baseNoisePrecomputed";

            RenderTexture.active = _baseNoiseTexture;
            cpuBaseNoisePrecomputed.ReadPixels(new Rect(0, 0, _baseNoiseTexture.width, _baseNoiseTexture.height), 0, 0);
            cpuBaseNoisePrecomputed.Apply();

            // Save the precomputed cloud texture into the base noise asset. This will be loaded by platforms which do not support compute shaders
            UnityEditor.AssetDatabase.CreateAsset(cpuBaseNoisePrecomputed, string.Format("{0}Clouds/baseNoisePrecomputed.asset", baseFolder));
            UnityEditor.AssetDatabase.SaveAssets();
        }

#endif

        public static void GenerateBaseCloudNoise()
        {
            // Compute shaders allow us to use the GPU to quickly create a random channel in the base cloud texture,
            // effectively seeding a random cloud
            if (SystemInfo.supportsComputeShaders)
            {
                Texture2D cpuBaseNoise = Resources.Load<Texture2D>("Clouds/baseNoise");
                int resolution = cpuBaseNoise.width;
            
                // Create the render texture
                _baseNoiseTexture = new RenderTexture(resolution, resolution, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Default);
                _baseNoiseTexture.name = "baseNoise";
                _baseNoiseTexture.enableRandomWrite = true;
                _baseNoiseTexture.wrapMode = TextureWrapMode.Repeat;
                _baseNoiseTexture.filterMode = FilterMode.Trilinear;
                _baseNoiseTexture.Create();
            
                // Generate the base shapes of the clouds here
                int kernel = noiseCompute.FindKernel("CSBaseNoiseMain");
                noiseCompute.SetFloat("_TextureDim", (float)resolution);
                noiseCompute.SetInt("_Seed", DateTime.Now.Millisecond);
                noiseCompute.SetTexture(kernel, "_CPUBase", cpuBaseNoise);
                noiseCompute.SetTexture(kernel, "_Base", _baseNoiseTexture);
                noiseCompute.Dispatch(kernel, resolution / 8, resolution / 8, 1);
            }
            else // Lower-end systems can still use high detail clouds, but they will be precomputed
            {
                _baseNoiseTexturePrecomputed = Resources.Load<Texture2D>("Clouds/baseNoisePrecomputed");
            }
        }

        public static void GenerateCloudDetailNoise()
        {
            _detailNoiseTexture = Resources.Load<Texture3D>("Clouds/detailNoise");
        }

        public static void GenerateCloudCurlNoise()
        {
            _curlNoiseTexture = Resources.Load<Texture2D>("Clouds/curlNoise");
        }
    }

    public class WNG
    {
        public static float brightness = 1.0f;
        public static float contrast = 1.0f;
        public static int octaves = 4;

        private static int wrap(int n, int period)
        {
            return n >= 0 ? n % period : period + n;
        }

        public static float Noise(Vector3 pos, int period, int seed)
        {
            pos *= period;
            var x = Mathf.FloorToInt(pos.x);
            var y = Mathf.FloorToInt(pos.y);
            var z = Mathf.FloorToInt(pos.z);
            Vector3 boxPos = new Vector3(x, y, z);
            float minDistance = float.MaxValue;

            for (int xoffset = -1; xoffset <= 1; xoffset++)
            {
                for (int yoffset = -1; yoffset <= 1; yoffset++)
                {
                    for (int zoffset = -1; zoffset <= 1; zoffset++)
                    {
                        var newboxPos = boxPos + new Vector3(xoffset, yoffset, zoffset);
                        var hashValue = (wrap((int)newboxPos.x, period) + wrap((int)newboxPos.y, period) * 131 + wrap((int)newboxPos.z, period) * 17161) % int.MaxValue;
                        UnityEngine.Random.InitState(hashValue + seed);
                        var featurePoint = new Vector3(UnityEngine.Random.value + newboxPos.x, UnityEngine.Random.value + newboxPos.y, UnityEngine.Random.value + newboxPos.z);
                        minDistance = Mathf.Min(minDistance, Vector3.Distance(pos, featurePoint));
                    }
                }
            }
            return 1.0f - minDistance;
        }

        public static float OctaveNoise(Vector3 pos, int octaves, int period, int seed = 0, float persistence = 0.5f)
        {
            float result = 0.0f;
            float amp = .5f;
            float freq = 1.0f;
            float totalAmp = 0.0f;
            for (int i = 0; i < octaves; i++)
            {
                totalAmp += amp;
                result += Noise(pos, Mathf.RoundToInt(freq * period), seed) * amp;
                amp *= persistence;
                freq /= persistence;
            }
            if (octaves == 0)
                return 0.0f;
            return result / totalAmp;
        }

        public static float ModifiedOctaveNoise(Vector3 pos, int octaves, int period, int seed = 0, float persistence = 0.5f, float fade = 0.0f)
        {
            float result = fade;
            float amp = .5f;
            float freq = 1.0f;
            float totalAmp = 0.0f;
            for (int i = 0; i < octaves; i++)
            {
                totalAmp += amp;
                result += Noise(pos, Mathf.RoundToInt(freq * period), seed) * amp;
                amp *= persistence;
                freq /= persistence;
            }
            if (octaves == 0)
                return 0.0f;
            return result / totalAmp;
        }
    }

    public class PNG
    {
        public int octaves = 4;

        static float Fade(float t)
        {
            return t * t * t * (t * (t * 6 - 15) + 10);
        }

        static float Lerp(float t, float a, float b)
        {
            return a + t * (b - a);
        }

        static float Grad(int hash, float x, float y, float z)
        {
            var h = hash & 15;
            var u = h < 8 ? x : y;
            var v = h < 4 ? y : (h == 12 || h == 14 ? x : z);
            return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v);
        }

        static int[] perm = {
        151,160,137,91,90,15,
        131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
        190, 6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
        88,237,149,56,87,174,20,125,136,171,168, 68,175,74,165,71,134,139,48,27,166,
        77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
        102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,187,208, 89,18,169,200,196,
        135,130,116,188,159,86,164,100,109,198,173,186, 3,64,52,217,226,250,124,123,
        5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
        223,183,170,213,119,248,152, 2,44,154,163, 70,221,153,101,155,167, 43,172,9,
        129,22,39,253, 19,98,108,110,79,113,224,232,178,185, 112,104,218,246,97,228,
        251,34,242,193,238,210,144,12,191,179,162,241, 81,51,145,235,249,14,239,107,
        49,192,214, 31,181,199,106,157,184, 84,204,176,115,121,50,45,127, 4,150,254,
        138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180,
        151
    };
        private static int wrap(int n, int period)
        {
            n++;
            return period > 0 ? n % period : n;
        }

        public static float Noise(Vector3 pos, int period)
        {
            pos *= period;
            var x = pos.x;
            var y = pos.y;
            var z = pos.z;
            var X = Mathf.FloorToInt(x) & 0xff;
            var Y = Mathf.FloorToInt(y) & 0xff;
            var Z = Mathf.FloorToInt(z) & 0xff;
            x -= Mathf.Floor(x);
            y -= Mathf.Floor(y);
            z -= Mathf.Floor(z);
            var u = Fade(x);
            var v = Fade(y);
            var w = Fade(z);
            var A = (perm[wrap(X, period)] + Y) & 0xff;
            var B = (perm[wrap(X + 1, period)] + Y) & 0xff;
            var AA = (perm[wrap(A, period)] + Z) & 0xff;
            var BA = (perm[wrap(B, period)] + Z) & 0xff;
            var AB = (perm[wrap(A + 1, period)] + Z) & 0xff;
            var BB = (perm[wrap(B + 1, period)] + Z) & 0xff;
            var result = Lerp(w, Lerp(v, Lerp(u, Grad(perm[AA], x, y, z), Grad(perm[BA], x - 1, y, z)),
                                   Lerp(u, Grad(perm[AB], x, y - 1, z), Grad(perm[BB], x - 1, y - 1, z))),
                           Lerp(v, Lerp(u, Grad(perm[AA + 1], x, y, z - 1), Grad(perm[BA + 1], x - 1, y, z - 1)),
                                   Lerp(u, Grad(perm[AB + 1], x, y - 1, z - 1), Grad(perm[BB + 1], x - 1, y - 1, z - 1))));
            return (result + 1.0f) / 2.0f;
        }

        public static float OctaveNoise(Vector3 pos, int period, int octaves, float persistence = 0.5f)
        {
            float total = 0.0f;
            float result = 0.0f;
            float amp = .5f;
            float freq = 1.0f;
            for (int i = 0; i < octaves; i++)
            {
                total += amp;
                result += (Noise(pos, Mathf.RoundToInt(freq * period)) * 2.0f - 1.0f) * amp;
                amp *= persistence;
                freq *= 2.0f;
            }
            if (octaves == 0)
                return 0.0f;
            return (result / total + 1.0f) / 2.0f;
        }
    }
}