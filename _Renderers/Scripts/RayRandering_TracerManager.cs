using QuizCanners.CfgDecode;
using QuizCanners.Inspect;
using QuizCanners.Lerp;
using QuizCanners.Utils;
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace QuizCanners.RayTracing
{

    [Serializable]
    public class RayRandering_TracerManager : IPEGI, ILinkedLerping, ICfgCustom, IPEGI_ListInspect
    {
        [SerializeField] private RayRendering_TracerConfigs configs;

        private ShaderProperty.ShaderKeyword _usingRayMarching = new ShaderProperty.ShaderKeyword("_IS_RAY_MARCHING");


        [SerializeField] private RayRenderingTarget _target;
        public RayRenderingTarget Target
        {
            get { return _target; }
            set
            {
                _target = value;
                _usingRayMarching.Enabled = value == RayRenderingTarget.RayMarching;
            }
        }

        [Header("Ray-Marthing")] private ShaderProperty.FloatValue _maxStepsInShader = new ShaderProperty.FloatValue("_maxRayMarchSteps");
        [SerializeField] private float _maxSteps = 50;

        private ShaderProperty.FloatValue _maxDistanceInShader = new ShaderProperty.FloatValue("_MaxRayMarchDistance");
        [SerializeField] private float _maxDistance = 10000;

        private LinkedLerp.MaterialFloat _rayMarchSmoothness = new LinkedLerp.MaterialFloat("_RayMarchSmoothness", 1, 30);
        private LinkedLerp.MaterialFloat _rayMarchShadowSoftness = new LinkedLerp.MaterialFloat("_RayMarchShadowSoftness", 1, 30);


        [NonSerialized] private QcUtils.DynamicRangeFloat smoothness = new QcUtils.DynamicRangeFloat(0.01f, 10, 1);
        [NonSerialized] private QcUtils.DynamicRangeFloat shadowSoftness = new QcUtils.DynamicRangeFloat(0.01f, 10, 1);

        [Header("Ray-Tracing")]
        [NonSerialized] private QcUtils.DynamicRangeFloat DOFdistance = new QcUtils.DynamicRangeFloat(min: 0.01f, max: 50, value: 1);
        [NonSerialized] private LinkedLerp.MaterialFloat _RayTraceDepthOfField = new LinkedLerp.MaterialFloat("_RayTraceDofDist", startingValue: 1f, startingSpeed: 100f); // x - distance 
        [NonSerialized] private LinkedLerp.MaterialFloat DOFTargetStrength = new LinkedLerp.MaterialFloat("_RayTraceDOF", startingValue: 0.0001f, startingSpeed: 10);
        [NonSerialized] private ShaderProperty.ShaderKeyword _rayTraceUseDielecrtic = new ShaderProperty.ShaderKeyword("RT_USE_DIELECTRIC");
        [NonSerialized] private ShaderProperty.ShaderKeyword _rayTraceUseCheckerboard = new ShaderProperty.ShaderKeyword("RT_USE_CHECKERBOARD");

        public void OnConfigurationChanged()
        {
            _maxStepsInShader.GlobalValue = _maxSteps;
            _maxDistanceInShader.GlobalValue = _maxDistance;
        }

        #region Encode & Decode

        public CfgEncoder Encode()
        {
            var cody = new CfgEncoder()
                .Add("targ", (int)Target)
                .Add("dofD", DOFdistance)
                .Add("dofPow", DOFTargetStrength.TargetValue);

            if (_usingRayMarching.Enabled) cody
                .Add("sm", smoothness)
                .Add("shSo", shadowSoftness);

            if (Target != RayRenderingTarget.RayMarching) cody
                .Add_Bool("diEl", _rayTraceUseDielecrtic.Enabled)
                .Add_Bool("rtCB", _rayTraceUseCheckerboard.Enabled);

            return cody;
        }

        public void Decode(string tg, CfgData data)
        {
            switch (tg)
            {
                case "sm": smoothness.Decode(data); break;
                case "shSo": shadowSoftness.Decode(data); break;


                case "targ": Target = (RayRenderingTarget)data.ToInt(); break;

                case "dofD": DOFdistance.Decode(data); break;
                case "dofPow": DOFTargetStrength.TargetValue = data.ToFloat(); break;
                case "diEl": _rayTraceUseDielecrtic.Enabled = data.ToBool(); break;
                case "rtCB": _rayTraceUseCheckerboard.Enabled = data.ToBool(); break;
            }
        }

        public void Decode(CfgData data)
        {
            new CfgDecoder(data).DecodeTagsFor(this);
        }

        #endregion

        #region Inspect
        public void Inspect()
        {

            pegi.nl();

            var changed = pegi.ChangeTrackStart();

            var trg = Target;
            if ("Target".editEnum(ref trg).nl())
                Target = trg;


            if (Target == RayRenderingTarget.RayMarching)
            {
                "RAY-MARCHING".nl(PEGI_Styles.ListLabel);

                "Max Steps".edit(ref _maxSteps, 1, 400).nl();

                "Max Distance".edit(ref _maxDistance, 1, 50000).nl();

                "Smoothness:".nl();
                pegi.Nested_Inspect(ref smoothness); //.Inspect();
                pegi.nl();

                "Shadow Softness".nl();
                pegi.Nested_Inspect(ref shadowSoftness).nl();
            }
            else
            {
                _rayTraceUseDielecrtic.Nested_Inspect().nl();
                _rayTraceUseCheckerboard.Nested_Inspect().nl();
            }

            "DOF".nl();
            pegi.Nested_Inspect(ref DOFdistance).nl();
            var targ = DOFTargetStrength.TargetValue;
            if ("DOF Strength".edit(90, ref targ, 0.0001f, 3f).nl())
                DOFTargetStrength.TargetValue = targ;

            ConfigurationsSO_Base.Inspect(ref configs);

            if (changed)
                OnConfigurationChanged();
        }

        public void InspectInList(int ind, ref int edited)
        {
  
            if (icon.Enter.Click())
                edited = ind;

            var trg = Target;
            if (pegi.editEnum(ref trg))
                Target = trg;

            if (!configs)
                "CFG".edit(60, ref configs);
            else
                configs.InspectShortcut();

        }
        #endregion

        #region Lerps
        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            var isMarching = Target == RayRenderingTarget.RayMarching;

            _rayMarchSmoothness.Lerp(ld, canSkipLerp || !isMarching);
            _rayMarchShadowSoftness.Lerp(ld, canSkipLerp || !isMarching);

            _RayTraceDepthOfField.Lerp(ld, canSkipLerp);
            DOFTargetStrength.Lerp(ld, canSkipLerp);
        }

        public void Portion(LerpData ld)
        {
            _rayMarchSmoothness.Portion(ld, smoothness.Value);
            _rayMarchShadowSoftness.Portion(ld, shadowSoftness.Value);

            _RayTraceDepthOfField.Portion(ld, DOFdistance.Value);
            DOFTargetStrength.Portion(ld);
        }
        #endregion

    }
}
