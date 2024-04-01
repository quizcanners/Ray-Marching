using PainterTool;
using QuizCanners.Inspect;
using QuizCanners.Utils;
using System.Collections.Generic;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    public static partial class TracingPrimitives
    {
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

                private readonly Gate.Integer _volumeVersion = new();

                protected abstract int GetMaxCount();

                protected abstract string GetPrefix();

                public void FeedToShader(List<C_RayT_PostAffector> list)
                {
                    var vol = C_VolumeTexture.LatestInstance;

                    bool volumeChanged = vol && _volumeVersion.TryChange(vol.LocationVersion);

                    if (!volumeChanged)
                        return;


                    if (_setInShader.TryChange(true))
                    {
                        countValue = new(GetPrefix() + COUNT);
                        InitializeInternal();
                    }

                    FeedElements(out var totalCount);

                 
                    countValue.GlobalValue = totalCount;
                    SetGlobalInternal(list);

                    return;

                  

                    void FeedElements(out int count)
                    {
                        count = System.Math.Min(GetMaxCount(), list.Count);

                        if (list.Count <= GetMaxCount())
                        {
                            FeedSequantially(count);
                            return;
                        }
                        
                        if (!vol)
                        {
                            FeedSequantially(count);
                            return;
                        }

                        void FeedSequantially(int count)
                        {
                            for (int i = 0; i < count; i++)
                            {
                                ExtractDataInternal(list[i], i);
                            }
                        }

                        List<C_RayT_PostAffector> inVolumelist = new(count);
                        List<C_RayT_PostAffector> nearVolume = new(count);

                        var volBounds = vol.GetBounds();

                        foreach (C_RayT_PostAffector el in list)
                        {
                            var dist = volBounds.SqrDistance(el.transform.position);

                            if (dist <= 0)
                            {
                                inVolumelist.Add(el);
                                if (inVolumelist.Count >= count)
                                    break;

                                continue;
                            }

                            if (dist < 10)
                                nearVolume.Add(el);
                        }

                        var freeSpots = count - inVolumelist.Count;

                        var canAdd = Mathf.Min(freeSpots, nearVolume.Count);

                        if (canAdd > 0)
                            inVolumelist.AddRange(nearVolume.GetRange(0, canAdd));

                        for (int i = 0; i < inVolumelist.Count; i++) //  var p in list) 
                        {
                            ExtractDataInternal(inVolumelist[i], i);
                        }
                    }
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

                const int MAX_COUNT = 32;

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
