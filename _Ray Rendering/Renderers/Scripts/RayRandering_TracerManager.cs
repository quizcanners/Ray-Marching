using QuizCanners.Migration;
using QuizCanners.Inspect;
using QuizCanners.Lerp;
using QuizCanners.Utils;
using System;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    public static partial class QcRender
    {
        [Serializable]
        internal class TracerManager : IPEGI, ILinkedLerping, ICfgCustom, IPEGI_ListInspect
        {
            [SerializeField] public SO_RayRendering_TracerConfigs Configs;
            [SerializeField] private RayRenderingTarget _target;

            private const string INTERSECTION = "INTERSECTION";
            private const string MARCHING = "IS_RAY_MARCHING";
            private const string MARCHING_PROGRESSIVE = "IS_PROGRESSIVE_MARCHING";

            private readonly ShaderProperty.KeywordEnum RAY_RENDERING_METHOD = new(name: "RAY_RENDERING_METHOD", INTERSECTION, MARCHING, MARCHING_PROGRESSIVE);
   
            internal RayRenderingTarget Target
            {
                get => _target;
                set
                {
                    _target = value;

                    switch (value) 
                    {
                        case RayRenderingTarget.Disabled: RAY_RENDERING_METHOD[-1] = true; break;
                        case RayRenderingTarget.RayIntersection: RAY_RENDERING_METHOD[0] = true; break;
                        case RayRenderingTarget.RayMarching: RAY_RENDERING_METHOD[1] = true; break;
                        case RayRenderingTarget.ProgressiveRayMarching: RAY_RENDERING_METHOD[2] = true; break;
                    }
                }
            }

            [Header("Ray-Marthing")]
            [SerializeField] private float _maxSteps = 50;
            [SerializeField] private float _maxDistance = 10000;
            [NonSerialized] private QcMath.DynamicRangeFloat smoothness = new(0.01f, 10, 1);
            [NonSerialized] private QcMath.DynamicRangeFloat shadowSoftness = new(0.01f, 10, 1);

            private readonly ShaderProperty.FloatValue MAX_STEPS_IN_SHADER = new("_maxRayMarchSteps");
            private readonly ShaderProperty.FloatValue MAX_DISTANCE_IN_SHADER = new("_MaxRayMarchDistance");
            private readonly LinkedLerp.ShaderFloat RAY_MARCHSMOOTHNESS = new("_RayMarchSmoothness", 1, 30);
            private readonly LinkedLerp.ShaderFloat RAY_MARCH_SHADOW_SMOOTHNESS = new("_RayMarchShadowSoftness", 1, 30);

            [Header("Ray-Tracing")]
            [NonSerialized] private QcMath.DynamicRangeFloat DOFdistance = new(min: 0.01f, max: 50, value: 1);
            [NonSerialized] private readonly LinkedLerp.ShaderFloat RAY_TRACE_DOF = new("_RayTraceDofDist", initialValue: 1f, maxSpeed: 100f); // x - distance 
            [NonSerialized] private readonly LinkedLerp.ShaderFloat DOF_STRENGTH = new("_RayTraceDOF", initialValue: 0.000001f, maxSpeed: 10);

            public void OnConfigurationChanged()
            {
                MAX_STEPS_IN_SHADER.GlobalValue = _maxSteps;
                MAX_DISTANCE_IN_SHADER.GlobalValue = _maxDistance;
            }

            #region Encode & Decode

            public void ManagedOnDisable()
            {
                Configs.IndexOfActiveConfiguration = -1;
            }

            public CfgEncoder Encode()
            {
                var cody = new CfgEncoder()
                    .Add("targ", (int)Target)
                    .Add("dofD", DOFdistance)
                    .Add("dofPow", DOF_STRENGTH.TargetValue)
                    .Add("sm", smoothness)
                    .Add("shSo", shadowSoftness);

                return cody;
            }

            public void DecodeTag(string tg, CfgData data)
            {
                switch (tg)
                {
                    case "sm": data.DecodeOverride(ref smoothness); break;
                    case "shSo": data.DecodeOverride(ref shadowSoftness); break;
                    case "targ": Target = (RayRenderingTarget)data.ToInt(); break;

                    case "dofD": data.DecodeOverride(ref DOFdistance); break;
                    case "dofPow": DOF_STRENGTH.TargetValue = data.ToFloat(); break;
                }
            }

            public void DecodeInternal(CfgData data)
            {
                new CfgDecoder(data).DecodeTagsFor(this);
            }

            #endregion

            #region Inspect
            void IPEGI.Inspect()
            {
                pegi.Nl();

                var changed = pegi.ChangeTrackStart();

                var trg = Target;
                if ("Target".PegiLabel().Edit_Enum(ref trg).Nl())
                    Target = trg;

                ConfigurationsSO_Base.Inspect(ref Configs);


                if (Target == RayRenderingTarget.RayMarching || Target == RayRenderingTarget.ProgressiveRayMarching || Target == RayRenderingTarget.Volume)
                {
                    "RAY-MARCHING".PegiLabel(pegi.Styles.ListLabel).Nl();

                    "Max Steps".PegiLabel().Edit(ref _maxSteps, 1, 400).Nl();

                    "Max Distance".PegiLabel().Edit(ref _maxDistance, 1, 50000).Nl();

                    "Smoothness:".PegiLabel().Nl();
                    pegi.Nested_Inspect(ref smoothness); 
                    pegi.Nl();

                    "Shadow Softness".PegiLabel().Nl();
                    pegi.Nested_Inspect(ref shadowSoftness).Nl();
                }

                if (Target == RayRenderingTarget.RayIntersection || Target == RayRenderingTarget.Volume)
                {
                    "RAY-TRACING".PegiLabel(pegi.Styles.ListLabel).Nl();
                }

                if (Target != RayRenderingTarget.Volume)
                {
                    "DOF".PegiLabel().Nl();
                    pegi.Nested_Inspect(ref DOFdistance).Nl();
                    var targ = DOF_STRENGTH.TargetValue;
                    if ("DOF Strength".PegiLabel(90).Edit(ref targ, 0, 3f).Nl())
                        DOF_STRENGTH.TargetValue = targ;
                }

                if (changed)
                    OnConfigurationChanged();
            }

            public void Inspect_Select() 
            {
                RayRenderingTarget trg = Target;
                if (pegi.Edit_Enum(ref trg))
                    Target = trg;
            }

            public void InspectInList(ref int edited, int ind)
            {
                "Tracing".PegiLabel(70).ClickEnter(ref edited, ind);

                Inspect_Select();

                if (!Configs)
                {
                    "CFG".PegiLabel(60).Edit(ref Configs);
                }

            }
            #endregion

            #region Lerps

            public void Portion(LerpData ld)
            {
                RAY_MARCHSMOOTHNESS.Portion(ld, smoothness.Value);
                RAY_MARCH_SHADOW_SMOOTHNESS.Portion(ld, shadowSoftness.Value);

                RAY_TRACE_DOF.Portion(ld, DOFdistance.Value);
                DOF_STRENGTH.Portion(ld);
            }

            public void Lerp(LerpData ld, bool canSkipLerp)
            {
                var isMarching = Target == RayRenderingTarget.RayMarching || Target == RayRenderingTarget.ProgressiveRayMarching;

                RAY_MARCHSMOOTHNESS.Lerp(ld, canSkipLerp || !isMarching);
                RAY_MARCH_SHADOW_SMOOTHNESS.Lerp(ld, canSkipLerp || !isMarching);

                RAY_TRACE_DOF.Lerp(ld, canSkipLerp);
                DOF_STRENGTH.Lerp(ld, canSkipLerp);
            }

          
            #endregion

        }
    }
}
