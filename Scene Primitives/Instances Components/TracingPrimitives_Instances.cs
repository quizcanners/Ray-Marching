using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using System.Collections.Generic;
using UnityEngine;

namespace QuizCanners.RayTracing
{
    using static Singleton_EnvironmentElementsManager;

    public static partial class TracingPrimitives
    {
        public static readonly List<CfgAndInstance> s_instances = new();
   
        public static readonly PostBakingEffects s_postEffets = new();

        [NonSerialized] public static int ArrangementVersion = -1;
        public static void OnArrangementChanged() => ArrangementVersion++;

        public static void Register(C_RayT_PrimShape_EnvironmentElement el)
        {
            s_instances.Add(new CfgAndInstance(el));
            OnArrangementChanged();
        }

        public static void UnRegister(C_RayT_PrimShape_EnvironmentElement el)
        {
            OnArrangementChanged();
        }




        public class PostBakingEffects : IPEGI
        {
            const string POST_RTX_ = "PostRtx_";
            const string POS = "Pos";
            const string COLOR = "Color";
            const string COUNT = "Count";
            public enum ElementType { PointLight, Projector, AmbientOcclusionSphere }

            public readonly List<C_RayT_PostAffector_EnvironmentElement> PostAffectors = new();

            private readonly pegi.CollectionInspectorMeta _inspectedAfterEffect = new("After Baking");


            private readonly PointLights _pointLigts = new();

            public void UpdateDataInGPU()
            {
                var lights = new List<C_RayT_PostAffector_EnvironmentElement>();

                foreach (var l in PostAffectors)
                    if (l.Type == ElementType.PointLight)
                        lights.Add(l);

                _pointLigts.SetGlobal(lights);
            }

            private class PointLights 
            {
                const string POINT_LIGHT_ = "PointLight_";

                const int MAX_POINT_LIGHTS_COUNT = 8;

                ShaderProperty.VectorArrayValue _pointLightPositions;
                ShaderProperty.VectorArrayValue _pointLightColors;
                ShaderProperty.IntValue _pointLightsCount;

                private readonly Vector4[] positionsArray = new Vector4[MAX_POINT_LIGHTS_COUNT];
                private readonly Vector4[] colorArray = new Vector4[MAX_POINT_LIGHTS_COUNT];

                private readonly Gate.Bool _setInShader = new();

                private void InitializeIfNotInitialized()
                {
                    if (!_setInShader.TryChange(true))
                        return;

                    _pointLightPositions = new(POST_RTX_ + POINT_LIGHT_ + POS);
                    _pointLightColors = new(POST_RTX_ + POINT_LIGHT_ + COLOR);
                    _pointLightsCount = new(POST_RTX_ + POINT_LIGHT_ + COUNT);
                }

                public void SetGlobal(List<C_RayT_PostAffector_EnvironmentElement> list) 
                {
                    InitializeIfNotInitialized();

                    var count = Math.Min(MAX_POINT_LIGHTS_COUNT, list.Count);

                    for (int i=0; i< count; i++) //  var p in list) 
                    {
                        var p = list[i];

                        positionsArray[i] = p.transform.position;
                        colorArray[i] = p.LightColor;
                    }

                    _pointLightsCount.GlobalValue = count;
                    _pointLightPositions.GlobalValue = positionsArray;
                    _pointLightColors.GlobalValue = colorArray;
                }
            }

            public override string ToString() => "Post Baking";

            void IPEGI.Inspect()
            {
                _inspectedAfterEffect.Edit_List(PostAffectors).Nl();
            }

            public void Register(C_RayT_PostAffector_EnvironmentElement el)
            {
                PostAffectors.Add(el);
                OnArrangementChanged();
            }

            public void UnRegister(C_RayT_PostAffector_EnvironmentElement el)
            {
                PostAffectors.Remove(el);
                OnArrangementChanged();
            }
        }
    }
}