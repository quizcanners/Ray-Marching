using PainterTool;
using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using System.Collections.Generic;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    public static partial class TracingPrimitives
    {
        public static readonly PostBakingEffects s_postEffets = new();

        public static readonly EnvironmentElements s_EnvironmentElements = new();

        private static readonly pegi.EnterExitContext _context = new();

        [NonSerialized] public static int ArrangementVersion = -1;
        public static void OnArrangementChanged() => ArrangementVersion++;


        public static void Inspect() 
        {
            using (_context.StartContext())
            {
                s_EnvironmentElements.Enter_Inspect().Nl();
                s_postEffets.Enter_Inspect().Nl();
            }
        }

        public class EnvironmentElements : IPEGI, IGotCount
        {
            private readonly Dictionary<Shape, List<int>> _sortedRotated = new();
            private readonly Dictionary<Shape, List<int>> _sortedUnRotated = new();
            private readonly Gate.Integer _sortedInstancesVersion = new();
            private readonly Gate.Integer _volumeVersion = new();

            public readonly List<CfgAndInstance> s_instances = new();

            public void Register(C_RayT_PrimShape el)
            {
                s_instances.Add(new CfgAndInstance(el));
                OnArrangementChanged();
            }

            public void UnRegister(C_RayT_PrimShape el)
            {
                for (int i = 0; i < s_instances.Count; i++)
                {
                    var inst = s_instances[i];

                    if (inst.EnvironmentElement == el)
                    {
                        s_instances.RemoveAt(i);
                        break;
                    }
                }

                OnArrangementChanged();
            }

            public C_RayT_PrimShape GetByIndex(int i) 
            {
                var inst = s_instances.TryGet(i);
                return inst?.EnvironmentElement;
            }

            /*
            public C_RayT_PrimShape GetInstanceForShape(Shape shape, bool rotated, int index)
            {
                List<int> l = GetSortedForVolume(rotated).GetOrCreate(shape);

                if (l.Count > index)
                {
                    var inst = s_instances.TryGet(l[index]);
                    return inst?.EnvironmentElement;
                }

                return null;
            }*/


            private bool GetShapeCollection(Shape shape, bool isRotated, out List<int> list)
            {
                var dic = isRotated ? _sortedRotated : _sortedUnRotated;
                return dic.TryGetValue(shape, out list);
            }

            public List<CfgAndInstance> GetSortedForBox(Vector3 pos, Vector3 size, Shape shape, bool rotated, bool prioratizeHigher)
            {
                List<CfgAndInstance> lst = new();

                if (!GetShapeCollection(shape, rotated, out List<int> byShapeIndexes))
                {
                    Debug.LogWarning("Sorted for {0} {1} not found".F(rotated ? "rotated" : "unrotated", shape.ToString()));
                    return lst;
                }

                List<Pair> pairs = new();

                foreach (var ind in byShapeIndexes)
                {
                    var el = s_instances[ind];

                    if (!el.EnvironmentElement)
                        continue;

                    var overlap = el.GetOverlap(pos, size, prioratizeHigher: prioratizeHigher);
                    if (overlap > 0)
                    {
                        pairs.Add(new Pair() { cfg = el, overlap = overlap });
                    }
                }

                pairs.Sort((a, b) => Mathf.FloorToInt((b.overlap - a.overlap) * 100));

                foreach (var p in pairs)
                    lst.Add(p.cfg);

                return lst;
            }

            struct Pair
            {
                public CfgAndInstance cfg;
                public float overlap;
            }

            public Dictionary<Shape, List<int>> GetSortedForVolume(bool rotated)
            {
                var ltst = C_VolumeTexture.LatestInstance;

                bool volumeChanged = ltst && _volumeVersion.TryChange(ltst.LocationVersion);
                var arrangementChanged = _sortedInstancesVersion.TryChange(ArrangementVersion);

                if (arrangementChanged | volumeChanged)
                {
                    UpdateLists();

                    // Sort
                    foreach (KeyValuePair<Shape, List<int>> pair in _sortedRotated)
                        SortList(pair.Value);

                    foreach (KeyValuePair<Shape, List<int>> pair in _sortedUnRotated)
                        SortList(pair.Value);

                    void SortList(List<int> sortedIndexes)
                    {
                        if (sortedIndexes.Count < 2)
                            return;

                        bool dirty = true;

                        while (dirty)
                        {
                            dirty = false;

                            for (int i = 0; i < sortedIndexes.Count - 1; i++)
                            {
                                var sortedIndexA = sortedIndexes[i];
                                var sortedIndexB = sortedIndexes[i + 1];

                                if (s_instances[sortedIndexB].VolumeWeight > s_instances[sortedIndexA].VolumeWeight)
                                {
                                    dirty = true;
                                    sortedIndexes[i] = sortedIndexB;
                                    sortedIndexes[i + 1] = sortedIndexA;
                                }
                            }
                        }
                    }
                }

                return rotated ? _sortedRotated : _sortedUnRotated;


                void UpdateLists()
                {
                    for (int i = s_instances.Count - 1; i >= 0; i--)
                    {
                        if (!s_instances[i].IsValid)
                            s_instances.RemoveAt(i);
                    }

                    // Indexes to sort
                    HashSet<int> rotatedDistributionList = new();
                    HashSet<int> unRotatedDistributionList = new();
                    for (int i = 0; i < s_instances.Count; i++)
                    {
                        if (s_instances[i].EnvironmentElement.Unrotated)
                            unRotatedDistributionList.Add(i);
                        else
                            rotatedDistributionList.Add(i);
                    }

                    Process(_sortedRotated, rotatedDistributionList, unRotated: false);

                    Process(_sortedUnRotated, unRotatedDistributionList, unRotated: true);

                    void Process(Dictionary<Shape, List<int>> sorted, HashSet<int> listToClear, bool unRotated)
                    {
                        // Remove invalid 
                        foreach (KeyValuePair<Shape, List<int>> pair in sorted)
                            RemoveInvalidFromList(pair, listToClear);

                        foreach (int el in listToClear)
                        {
                            CfgAndInstance ins = s_instances[el];
                            if (ins.IsValid)
                                sorted.GetOrCreate(ins.EnvironmentElement.Shape).Add(el);
                        }

                        void RemoveInvalidFromList(KeyValuePair<Shape, List<int>> pair, HashSet<int> listToClear)
                        {
                            List<int> list = pair.Value;

                            for (int i = list.Count - 1; i >= 0; i--)
                            {
                                int indexOfInstance = list[i];
                                CfgAndInstance el = s_instances.TryGet(indexOfInstance);
                                if (el == null || !el.IsValid || el.EnvironmentElement.Shape != pair.Key || el.Unroated != unRotated)
                                    list.RemoveAt(i);
                                else
                                    listToClear.Remove(indexOfInstance); // to leave only ones we haven't assigned yet
                            }
                        }
                    }

                }

            }

            public void Clear()
            {
                _sortedRotated.Clear();
                _sortedUnRotated.Clear();
                _sortedInstancesVersion.ValueIsDefined = false;
            }

            #region Inspector

            private Shape _debugShape = Shape.Cube;

            private readonly pegi.EnterExitContext _context = new();

            private readonly pegi.CollectionInspectorMeta _inspectedInstance = new("Primitives");

            public void Inspect()
            {
                pegi.Nl();
                using (_context.StartContext())
                {
                    _inspectedInstance.Enter_List(s_instances).Nl();

                    if ("Sorted".PegiLabel().IsEntered().Nl())
                    {
                        "Shape".PegiLabel().Edit_Enum(ref _debugShape).Nl();
                        List<int> rotL = GetSortedForVolume(rotated: true).GetOrCreate(_debugShape);
                        "Rotated".PegiLabel().Edit_List(rotL).Nl();
                        List<int> unRotL = GetSortedForVolume(rotated: false).GetOrCreate(_debugShape);
                        "Un Rotated".PegiLabel().Edit_List(unRotL).Nl();
                    }
                }
            }

            public int GetCount() => s_instances.Count;

            #endregion
        }

        public class PostBakingEffects : IPEGI
        {
            const string POST_RTX_ = "PostRtx_";
            const string POS = "Pos";
            const string DIRnANGLE = "DirAngle";
            const string SIZE = "Size";
            const string COLOR = "Color";
            const string COUNT = "Count";
            public enum ElementType { PointLight, Projector, AmbientOcclusionSphere, SunLightPortal }

            public readonly List<C_RayT_PostAffector> PostAffectors = new();

            private readonly pegi.CollectionInspectorMeta _inspectedAfterEffect = new("All Post Bakers Baking");


            private readonly PointLights _pointLights = new();
            private readonly ProjectorLights _projectorLigts = new();
            private readonly SunPortals _sunLightPortals = new();
            private readonly AmbientSpheres _ambientOcclusionSpheres = new();

            public void UpdateDataInGPU()
            {
                List<C_RayT_PostAffector> pointLights = new();
                List<C_RayT_PostAffector> projectorLights = new();
                List<C_RayT_PostAffector> ambientSpheres = new();
                List<C_RayT_PostAffector> sunLightPortals = new();

                foreach (var l in PostAffectors)
                    switch (l.Type)
                    {
                        case ElementType.PointLight: pointLights.Add(l); break;
                        case ElementType.Projector: projectorLights.Add(l); break;
                        case ElementType.SunLightPortal: sunLightPortals.Add(l); break;
                        case ElementType.AmbientOcclusionSphere: ambientSpheres.Add(l); break;
                    }
                

                _pointLights.FeedToShader(pointLights);
                _projectorLigts.FeedToShader(projectorLights);
                _sunLightPortals.FeedToShader(sunLightPortals);
                _ambientOcclusionSpheres.FeedToShader(ambientSpheres);
            }

            public override string ToString() => "Post Baking";

            private readonly pegi.EnterExitContext _context = new();

            void IPEGI.Inspect()
            {
                using (_context.StartContext())
                {
                    _pointLights.Enter_Inspect().Nl();
                    _projectorLigts.Enter_Inspect().Nl();
                    _sunLightPortals.Enter_Inspect().Nl();
                    _ambientOcclusionSpheres.Enter_Inspect().Nl();


                    _inspectedAfterEffect.Edit_List(PostAffectors).Nl();
                }
            }

            public void Register(C_RayT_PostAffector el)
            {
                PostAffectors.Add(el);
                OnArrangementChanged();
            }

            public void UnRegister(C_RayT_PostAffector el)
            {
                PostAffectors.Remove(el);
                OnArrangementChanged();
            }


            private abstract class PostAffectorBase : IPEGI, IPEGI_ListInspect
            {
                protected ShaderProperty.IntValue countValue = null;

                private readonly Gate.Bool _setInShader = new();

                protected abstract int GetMaxCount();

                protected abstract string GetPrefix();

                public void FeedToShader(List<C_RayT_PostAffector> list)
                {
                    if (_setInShader.TryChange(true))
                    {
                        countValue = new(GetPrefix() + COUNT);
                        InitializeInternal();
                    }

                    var count = Math.Min(GetMaxCount(), list.Count);

                    for (int i = 0; i < count; i++) //  var p in list) 
                    {
                        ExtractDataInternal(list[i], i);
                    }

                    countValue.GlobalValue = count;

                    SetGlobalInternal(list);
                }

                protected abstract void InitializeInternal();

                protected abstract void ExtractDataInternal(C_RayT_PostAffector el, int index);

                protected abstract void SetGlobalInternal(List<C_RayT_PostAffector> list);

                #region Inspector

                public void InspectInList(ref int edited, int index)
                {
                    if (Icon.Enter.Click())
                        edited = index;

                    "{0} {1}".F(GetPrefix(), _setInShader.CurrentValue ? countValue.GlobalValue.ToString() : "").PegiLabel().Nl();
                }

                public virtual void Inspect()
                {
                    "Prefix".PegiLabel().Write_ForCopy(GetPrefix()).Nl();
                    if (_setInShader.CurrentValue)
                    {
                        "Count: {0}".F(countValue.GlobalValue).PegiLabel().Nl();
                    }
                }

                #endregion
            }

            private class PointLights : PostAffectorBase
            {
                const string POINT_LIGHT_ = "PointLight_";

                const int MAX_COUNT = 16;

                private ShaderProperty.VectorArrayValue positions;
                private ShaderProperty.VectorArrayValue colors;

                protected readonly Vector4[] positionsArray = new Vector4[MAX_COUNT];
                private readonly Vector4[] colorArray = new Vector4[MAX_COUNT];

                protected override int GetMaxCount() => MAX_COUNT;
                protected override string GetPrefix() => POST_RTX_ + POINT_LIGHT_;

                protected override void InitializeInternal()
                {
                    positions = new(GetPrefix() + POS);
                    colors = new(GetPrefix() + COLOR);
                }

                protected override void ExtractDataInternal(C_RayT_PostAffector el, int index)
                {
                    positionsArray[index] = el.transform.position;
                    colorArray[index] = el.LightColor;
                }

                protected override void SetGlobalInternal(List<C_RayT_PostAffector> list)
                {
                    positions.GlobalValue = positionsArray;
                    colors.GlobalValue = colorArray;
                }

                public override string ToString() => "Point Lights";
            }

            private class ProjectorLights : PostAffectorBase
            {
                const string PREFIX_ = "ProjectorLight_";

                const int MAX_COUNT = 16;

                private ShaderProperty.VectorArrayValue positions;
                private ShaderProperty.VectorArrayValue directions;
                private ShaderProperty.VectorArrayValue colors;

                private readonly Vector4[] positionsArray = new Vector4[MAX_COUNT];
                private readonly Vector4[] colorArray = new Vector4[MAX_COUNT];
                private readonly Vector4[] directionsArray = new Vector4[MAX_COUNT];

                protected override int GetMaxCount() => MAX_COUNT;
                protected override string GetPrefix() => POST_RTX_ + PREFIX_;

                protected override void InitializeInternal()
                {
                    positions = new(GetPrefix() + POS);
                    colors = new(GetPrefix() + COLOR);
                    directions = new(GetPrefix() + DIRnANGLE);
                }

                protected override void ExtractDataInternal(C_RayT_PostAffector el, int index)
                {
                    Vector4 posAndAngle = el.transform.position;
                    posAndAngle.w = el.Angle;

                    positionsArray[index] = el.transform.position;
                    colorArray[index] = el.LightColor;


                    Vector4 dirAndAngle = el.transform.forward;
                    dirAndAngle.w = el.Angle;

                    directionsArray[index] = dirAndAngle;
                }

                protected override void SetGlobalInternal(List<C_RayT_PostAffector> list)
                {
                    positions.GlobalValue = positionsArray;
                    colors.GlobalValue = colorArray;
                    directions.GlobalValue = directionsArray;
                }

                public override string ToString() => "Projector Lights";
            }

            private class SunPortals : PostAffectorBase
            {
                const string PREFIX_ = "SunPortal_";

                const int MAX_COUNT = 16;

                private ShaderProperty.VectorArrayValue positions;
                private ShaderProperty.VectorArrayValue sizes;
                private ShaderProperty.VectorArrayValue colors;

                protected readonly Vector4[] positionsArray = new Vector4[MAX_COUNT];
                private readonly Vector4[] sizesArray = new Vector4[MAX_COUNT];
                private readonly Vector4[] colorArray = new Vector4[MAX_COUNT];

                protected override int GetMaxCount() => MAX_COUNT;
                protected override string GetPrefix() => POST_RTX_ + PREFIX_;

                protected override void InitializeInternal()
                {
                    positions = new(GetPrefix() + POS);
                    sizes = new(GetPrefix() + SIZE);
                    colors = new(GetPrefix() + COLOR);
                }

                protected override void ExtractDataInternal(C_RayT_PostAffector el, int index)
                {
                    positionsArray[index] = el.transform.position;
                    sizesArray[index] = el.transform.lossyScale;
                    colorArray[index] = el.LightColor;
                }

                protected override void SetGlobalInternal(List<C_RayT_PostAffector> list)
                {
                    positions.GlobalValue = positionsArray;
                    sizes.GlobalValue = sizesArray;
                    colors.GlobalValue = colorArray;
                }

                public override string ToString() => "Sun Light Portals";
            }

            private class AmbientSpheres : PostAffectorBase
            {
                const string PREFIX_ = "AmbientSphere_";

                const int MAX_COUNT = 16;

                private ShaderProperty.VectorArrayValue positions;
                private ShaderProperty.VectorArrayValue colors;

                protected readonly Vector4[] positionsArray = new Vector4[MAX_COUNT];
                private readonly Vector4[] colorArray = new Vector4[MAX_COUNT];

                protected override int GetMaxCount() => MAX_COUNT;
                protected override string GetPrefix() => POST_RTX_ + PREFIX_;

                protected override void InitializeInternal()
                {
                    positions = new(GetPrefix() + POS);
                    colors = new(GetPrefix() + COLOR);
                }

                protected override void ExtractDataInternal(C_RayT_PostAffector el, int index)
                {
                    positionsArray[index] = el.transform.position;
                    colorArray[index] = el.LightColor;
                }

                protected override void SetGlobalInternal(List<C_RayT_PostAffector> list)
                {
                    positions.GlobalValue = positionsArray;
                    colors.GlobalValue = colorArray;
                }

                public override string ToString() => "Ambient Spheres";
            }
        }
    }
}