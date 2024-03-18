using QuizCanners.Utils;
using System;
using System.Collections.Generic;
using UnityEngine;

namespace QuizCanners.StampTerrain
{
    public static partial class TerrainBaking
    {
        /// <summary>
        /// Class that stores all instance-independent Stamps data for Terrain Baking.
        /// </summary>
        public static class Stamps
        {
            /// <summary>
            /// Higher priority elements will be visible on top of the ones with lower priority.
            /// This also implies that lower priority stamps has to be rendered first.
            /// </summary>
            public enum VisiblePriority 
            { 
                EarlyTerraforming = 5,
                Terraforming = 10,
                NeighboringTerraforming = 15,
                BuildingElevation = 20,
                TreeGrass = 25,
                TreeGrassNearTree = 26,
                FinerDetails = 30, 
                Max = 999,
            }



            /// <summary>
            /// Baking mode will affect stamp sorting and batching.
            /// Content Aware stamps can't be batched if they overlap, as the next stamp needs the output of previous stamp as an input
            /// Additive Shader and possible future modes allow batched because their blending can be handled by shader's Blend Mode.
            /// </summary>
            public enum BakingMode 
            {
                ContentAware = 0,
                OverlapFriendly = 1,
            }


            /// <summary>
            /// Communication with baker is indirect. Scene changes that affect baked terrain modify the StampArrangementVersion.
            /// </summary>
            public static void SetDirty() => StampArrangementVersion++;

            public static int StampArrangementVersion;
            private static int _batchIndex = 0;

            /// <summary>
            /// All stamps that are active in the scene register themselves into this list to be managed.
            /// </summary>
            internal static List<TerrainStampComponent> s_activeStamps = new();

            private static int _latestCheckedStamp = -1;

            internal static void CheckForStampChanges() 
            {
                if (s_activeStamps.Count == 0)
                    return;

                _latestCheckedStamp = (_latestCheckedStamp + 1) % s_activeStamps.Count;

                if (Application.isEditor)
                    s_activeStamps[_latestCheckedStamp].ManagedCheck();
            }

            /// <summary>
            /// The object that has Hex Grid Remapper shader attached to it.
            /// We don't interract with it's material directly, only set global shader parameters that the shader reads from.
            /// </summary>
            public static GameObject GridObject;

            /// <summary>
            /// First step of baking is rendering entire Hex Grid in one go.
            /// </summary>
            public static void SetGridVisible() 
            {
                if (GridObject)
                    GridObject.SetActive(true);
                else
                    Debug.LogError("Grid Object not found");

                foreach (TerrainStampComponent stamp in s_activeStamps)
                {
                    stamp.IsVisible = false;
                }
            }

            /// <summary>
            /// After all stamps are rendered or rendering interrupted, hide the stamps of the last batch.
            /// </summary>
            public static void HideAllStamps()
            {
                foreach (TerrainStampComponent stamp in s_activeStamps)
                {
                     stamp.IsVisible = false;
                     stamp.batchIndex = -1;
                }
                _batchIndex = 0;
            }

            /// <summary>
            /// This method can be called few times before terrain baking is complete.
            /// Each time it will enable a batch of stamps to be baked.
            /// </summary>
            /// <param name="bakingVersion"></param>
            /// <param name="lastBatch"></param>
            public static void SetStampsVisible(int bakingVersion, out bool lastBatch) 
            {
                if (GridObject)
                    GridObject.SetActive(false);
               // else
                 //   Debug.LogError("Grid Object not found");

            //    List<TerrainStampComponent> stampBatch = new();

                int totalUnbakedStamps = 0;

                List<TerrainStampComponent> unbakedStamps = new();

                VisiblePriority _firstOverlapFriendlyPriority = VisiblePriority.Max;
                VisiblePriority _firstPriority = VisiblePriority.Max;

                foreach (var stamp in s_activeStamps) 
                {
                    stamp.IsVisible = false;
                  
                    if (stamp.bakedForVersion == bakingVersion)
                    {
                        continue;
                    }

                    if (stamp.Priority < _firstPriority)
                        _firstPriority = stamp.Priority;

                    if (stamp.BakingMode == BakingMode.OverlapFriendly && stamp.Priority<_firstOverlapFriendlyPriority)
                        _firstOverlapFriendlyPriority = stamp.Priority;

                    totalUnbakedStamps++;
                    unbakedStamps.Add(stamp);
                }

                int stampsInBatchCount = 0;

                if (_firstOverlapFriendlyPriority <= _firstPriority)
                {
                    FilterUnbaked(BakingMode.OverlapFriendly, priority: _firstOverlapFriendlyPriority);

                    foreach (var unbaked in unbakedStamps)
                        AddToBatch(unbaked);
                }
                else
                {
                    FilterUnbaked(BakingMode.ContentAware, priority: _firstPriority);

                    FilterByOverlap();
                }
 
                void FilterByOverlap()
                {
                    int unBakedStampCount = unbakedStamps.Count;

                    BoundsTopDown[] bounds = new BoundsTopDown[unBakedStampCount];

                    for (int i = 0; i < unBakedStampCount; i++)
                    {
                        bounds[i] = unbakedStamps[i].GetBounds();
                    }

                    System.Diagnostics.Stopwatch _timer = new();
                    _timer.Start();

                    for (int i = 0; i < unBakedStampCount; i++) //
                    {
                        if (_timer.Elapsed.Seconds > 1)
                            break;

                        if (!CheckOverlap(i) || bounds[i].State == BoundsProcessing.Discarded)
                            continue;

                        var bnd = bounds[i];
                        bnd.State = BoundsProcessing.Added;
                        bounds[i] = bnd;

                        TerrainStampComponent stamp = unbakedStamps[i];

                        AddToBatch(stamp);

                        continue;

                        bool CheckOverlap(int index)
                        {
                            BoundsTopDown currentStamp = bounds[index];

                            for (int i = index + 1; i < unBakedStampCount; i++)
                            {
                                var otherStamp = bounds[i];

                                if (!otherStamp.IntersectsWith(currentStamp))
                                    continue;

                                if (currentStamp.SiblingIndex > otherStamp.SiblingIndex)
                                {
                                    DiscardThis();
                                    continue;
                                }

                                DiscardOther();
                                continue;

                                void DiscardThis()
                                {
                                    currentStamp.State = BoundsProcessing.Discarded;
                                }

                                void DiscardOther()
                                {
                                    otherStamp.State = BoundsProcessing.Discarded;
                                    bounds[i] = otherStamp;
                                }
                            }

                            bounds[index] = currentStamp;

                            return true;
                        }
                    }

                    _timer.Stop();
                }

                void FilterUnbaked(BakingMode mode, VisiblePriority priority)
                {
                    for (int i=unbakedStamps.Count - 1; i >= 0; i--) 
                    {
                        var unbaked = unbakedStamps[i];

                        if (unbaked.BakingMode != mode || unbaked.Priority != priority)
                        {
                            unbakedStamps.RemoveAt(i);
                        }
                    }
                }


                void AddToBatch(TerrainStampComponent stamp)
                {
                    stamp.batchIndex = _batchIndex;
                    stamp.IsVisible = true;
                    stamp.bakedForVersion = bakingVersion;
                    stamp.OnBaked();
                    stampsInBatchCount++;
                }

                lastBatch = stampsInBatchCount >= totalUnbakedStamps;
                _batchIndex++;
            }
        }

        internal enum BoundsProcessing { Unprocessed, Added, Discarded }

        public struct BoundsTopDown
        {
            private readonly float minX;
            private readonly float maxX;
            private readonly float minZ;
            private readonly float maxZ;
            public readonly Stamps.VisiblePriority Priority;
            internal BoundsProcessing State;
            public int SiblingIndex;

            public bool IntersectsWith(BoundsTopDown other)
            {
                if (maxX < other.minX || maxZ < other.minZ || other.maxX < minX || other.maxZ < minZ)
                    return false;

                return true;
            }

            public BoundsTopDown(Bounds bounds, Stamps.VisiblePriority priority, int siblingIndex)
            {
                minX = bounds.min.x;
                maxX = bounds.max.x;
                minZ = bounds.min.z;
                maxZ = bounds.max.z;
                Priority = priority;
                SiblingIndex = siblingIndex;
                State = BoundsProcessing.Unprocessed;
            }
        }


        /// <summary>
        /// Will generate and set Terrain Texture Arrays as global variables. 
        /// </summary>
        public static class Layers
        {
            public static ShaderProperty.TextureValue ALBEDO_ARRAY = new("civ_Albedo_Arr");
            public static ShaderProperty.TextureValue NORMAL_ARRAY = new("civ_Normal_Arr");
            public static ShaderProperty.TextureValue MOHS_ARRAY = new("civ_MOHS_Arr");

            public static ShaderProperty.TextureValue CLIFF_ALBEDO = new("Ct_Cliff_Albedo");
            public static ShaderProperty.TextureValue CLIFF_NORMAL = new("Ct_Cliff_Normal");
            public static ShaderProperty.TextureValue CLIFF_MOHS = new("Ct_Cliff_MOHS");
            public static ShaderProperty.VectorValue CLIFF_TILING = new("Ct_CliffTiling");

            public static ShaderProperty.VectorValue LAYERS_TILING = new("Ct_LayersTiling");
            public static ShaderProperty.VectorValue LAYERS_NORMALS = new("Ct_LayersNormals");
            public static ShaderProperty.VectorValue LAYERS_HEIGHT_MOD = new("Ct_LayersHeightMod");
            public static ShaderProperty.VectorValue LAYERS_TRIP_ROTATION = new("Ct_LayersRotation");

            private static readonly ShaderProperty.TextureValue CAUSTICS = new("Ct_Caustics");

            private static readonly ShaderProperty.VectorValue SETTINGS = new("Ct_TerrainSettings");

            private static RenderTexture Albedo_Array;
            private static RenderTexture Normal_Array;
            private static RenderTexture MOHS_Array;

            private static void InitializeArrays()
            {
                var texWidthLimit = SystemInfo.maxTextureSize;
                var texturePixelsLimit = (texWidthLimit * texWidthLimit) / 4;
                var textureWidth = Mathf.NextPowerOfTwo(Mathf.FloorToInt(Mathf.Sqrt(texturePixelsLimit))) / 2;

                if (Albedo_Array == null)
                    Albedo_Array = CreateRenderTextureArray("Terrain Albedos", needsAlpha: false, isColor: true);

                if (Normal_Array == null)
                    Normal_Array = CreateRenderTextureArray("Terrain Normals", needsAlpha: true, isColor: false);

                if (MOHS_Array == null)
                    MOHS_Array = CreateRenderTextureArray("Terrain MOHSs", needsAlpha: true, isColor: false);
            }

            private static RenderTexture CreateRenderTextureArray(string name, bool needsAlpha, bool isColor) 
            {
                const int TEXTURE_SIZE = 1024;

                var res = new RenderTexture(width: TEXTURE_SIZE, TEXTURE_SIZE, depth: 0, needsAlpha ? RenderTextureFormat.ARGB32 : RenderTextureFormat.Default, readWrite: isColor ? RenderTextureReadWrite.sRGB :  RenderTextureReadWrite.Linear)
                {
                    dimension = UnityEngine.Rendering.TextureDimension.Tex2DArray,
                    useMipMap = true,
                    autoGenerateMips = true,
                    wrapMode = TextureWrapMode.Repeat,
                    volumeDepth = 4,
                    name = name + " Array",
                    filterMode = FilterMode.Trilinear,
                };

               

                return res;
            }

            private static TerrainLayersConfig_ScriptableObject currentlySet;

            private static readonly LogicWrappers.Request _layersInGPUAreDirty = new();
            private static readonly Gate.Frame _layersGenerationGate = new();


            public static void ManagedUpdate() 
            {
                if (!_layersInGPUAreDirty.IsRequested)
                    return;

                if (!_layersGenerationGate.TryEnterIfFramesPassed(3))
                    return;

                _layersInGPUAreDirty.Use();

                if (!currentlySet)
                    return;

                if (currentlySet.CliffSO)
                {
                    CLIFF_ALBEDO.GlobalValue = currentlySet.CliffSO.TextureSet.Albedo;
                    CLIFF_NORMAL.GlobalValue = currentlySet.CliffSO.TextureSet.Bump;
                    CLIFF_MOHS.GlobalValue = currentlySet.CliffSO.TextureSet.MADS;
                    CLIFF_TILING.GlobalValue = new Vector4(currentlySet.CliffSO.TextureSet.Settings.Tiling, 0, 0, 0);
                }

                // bool canCopy = SystemInfo.copyTextureSupport != UnityEngine.Rendering.CopyTextureSupport.None;

                TrySetArrays();

                void TrySetArrays()
                {
                    if (!currentlySet.GotTerrainLayers())
                    {
                        Clear();
                        return;
                    }

                    InitializeArrays();

                    Shader shader = Shader.Find("Hidden/BlitCopy");
                    Material mat = new(shader);

                    for (int i = 0; i < 4; i++)
                    {
                        LayerTextureSet set = currentlySet[i];

                        /* if (canCopy)
                              Graphics.CopyTexture(set.Albedo, 0, 0, Albedo_Array, i, 0);
                          else 
                              texture2DArray.SetPixelData(t.GetRawTextureData(), 0, i);

                          texture2DArray.Apply();*/

                        Blit(set.Albedo, Albedo_Array, i);
                        Blit(set.Bump, Normal_Array, i);
                        Blit(set.MADS, MOHS_Array, i);

                        /*  Graphics.Blit(source: set.Albedo, dest: Albedo_Array, mat: mat, pass: 0, destDepthSlice: i);
                          Graphics.Blit(set.Bump, Normal_Array, mat, 0, i);
                          Graphics.Blit(set.MADS, MOHS_Array, mat, 0, i);*/

                        void Blit(Texture from, RenderTexture destination, int index)
                        {

                            //Graphics.CopyTexture(src: from, srcElement: 0, srcMip: 0, destination, dstElement: index, dstMip: 0);
                            Graphics.Blit(source: from, dest: destination, mat: mat, pass: 0, destDepthSlice: i);
                        }

                    }


                    ALBEDO_ARRAY.GlobalValue = Albedo_Array;
                    NORMAL_ARRAY.GlobalValue = Normal_Array;
                    MOHS_ARRAY.GlobalValue = MOHS_Array;

                    LAYERS_TILING.GlobalValue = new Vector4(
                        currentlySet[0].Settings.Tiling,
                        currentlySet[1].Settings.Tiling,
                        currentlySet[2].Settings.Tiling,
                        currentlySet[3].Settings.Tiling);

                    LAYERS_NORMALS.GlobalValue = new Vector4(
                        currentlySet[0].Settings.NormalStrength,
                        currentlySet[1].Settings.NormalStrength,
                        currentlySet[2].Settings.NormalStrength,
                        currentlySet[3].Settings.NormalStrength);

                    LAYERS_HEIGHT_MOD.GlobalValue = new Vector4(
                        currentlySet[0].Settings.HeightCoef,
                        currentlySet[1].Settings.HeightCoef,
                        currentlySet[2].Settings.HeightCoef,
                        currentlySet[3].Settings.HeightCoef);

                    LAYERS_TRIP_ROTATION.GlobalValue = new Vector4(
                        currentlySet[0].Settings.TriplanarRotation,
                        currentlySet[1].Settings.TriplanarRotation,
                        currentlySet[2].Settings.TriplanarRotation,
                        currentlySet[3].Settings.TriplanarRotation);
                }

                SETTINGS.GlobalValue = new Vector4(currentlySet.Settings.Sharpness, 0, 0, 0);
                CAUSTICS.GlobalValue = currentlySet.Settings.Caustics;
            }


            public static void Set(TerrainLayersConfig_ScriptableObject config, bool dirty = false)
            {
                if (!config)
                    return;

                if (!dirty && currentlySet && (config == currentlySet))
                {
                    Debug.Log("Already Set");
                    return;
                }

                currentlySet = config;

                _layersInGPUAreDirty.CreateRequest();
                _layersGenerationGate.TryEnter();

                return;
            }

            public static void Clear()
            {
                if (Albedo_Array)
                {
                    Albedo_Array.DestroyWhatever();
                    Albedo_Array = null;
                }

                if (Normal_Array)
                {
                    Normal_Array.DestroyWhatever();
                    Normal_Array = null;
                }

                if (MOHS_Array)
                {
                    MOHS_Array.DestroyWhatever();
                    MOHS_Array = null;
                }

                currentlySet = null;
            }

     
        
        }

        [Serializable]
        public class LayerTextureSet
        {

            public Texture Albedo;
            public Texture MADS;
            public Texture Bump;



            void ClearTextures() 
            {
                Albedo = null;
                MADS = null;
                Bump = null;
            }

            public Configuration Settings;

            [Serializable]
            public class Configuration
            {
                public float Tiling = 1;
                public float HeightCoef = 1;
                public float Smoothness = 1;
                public float NormalStrength = 1;
                [Header("If applicable")]
                public float TriplanarRotation = 0;
            }
        }


        /// <summary>
        /// TODO: This is a duplicate from Hex Utils. Will need to bring this into the same Utils file.
        /// </summary>
        public enum EnvironmentBackground
        {
            Ocean,
            Shallows,
            Beach,
            Desert,
            Grassland,
            Forest,
            Rainforest
        };
    }
}
