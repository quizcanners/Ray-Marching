using System.Collections;
using System.Collections.Generic;
using NodeNotes_Visual.ECS;
using PlayerAndEditorGUI;
using QuizCannersUtilities;
using UnityEngine;
using System;

#if UNITY_EDITOR
using UnityEditor;
#endif

namespace RayMarching
{

    [ExecuteAlways]
    public class RayMarchingManager : MonoBehaviour, IPEGI, ICfg
    {
     

        ShaderProperty.FloatValue _maxStepsInShader = new ShaderProperty.FloatValue("_maxRayMarchSteps");
        [SerializeField] private float _maxSteps = 50;

        ShaderProperty.FloatValue _maxDistanceInShader = new ShaderProperty.FloatValue("_MaxRayMarchDistance");
        [SerializeField] private float _maxDistance = 10000;

        LinkedLerp.MaterialFloat _rayMarchSmoothness = new LinkedLerp.MaterialFloat("_RayMarchSmoothness", 1, 30);
        LinkedLerp.MaterialFloat _rayMarchShadowSoftness = new LinkedLerp.MaterialFloat("_RayMarchShadowSoftness", 1, 30);
        LinkedLerp.MaterialColor _RayMarchLightColor = new LinkedLerp.MaterialColor("_RayMarchLightColor", Color.grey, 10);
        LinkedLerp.MaterialColor _RayMarchFogColor = new LinkedLerp.MaterialColor("_RayMarchFogColor", Color.grey, 10);
        LinkedLerp.MaterialColor _RayMarchReflectionColor = new LinkedLerp.MaterialColor("_RayMarchReflectionColor", Color.grey, 10);

        [NonSerialized] private QcUtils.DynamicRangeFloat smoothness = new QcUtils.DynamicRangeFloat(0.01f, 10, 1);
        [NonSerialized] private QcUtils.DynamicRangeFloat shadowSoftness = new QcUtils.DynamicRangeFloat(0.01f, 10, 1);
        [NonSerialized] private Color _lightColor = Color.grey;
        [NonSerialized] private Color _reflectionColor = Color.grey;
        [NonSerialized] private Color _fogColor = Color.grey;

        [SerializeField] private RayMarchingConfigs configs;

        LerpData ld =new LerpData();

        void UpdateShadeVariables()
        {
            _maxStepsInShader.GlobalValue = _maxSteps;
            _maxDistanceInShader.GlobalValue = _maxDistance;
        }

        void OnEnable()
        {
            UpdateShadeVariables();
        }

        public void Update()
        {
            ld.Reset();

            var cfg = RayMarchingConfig.ActiveConfig;

            _rayMarchSmoothness.Portion(ld, smoothness.Value);
            _RayMarchLightColor.Portion(ld, _lightColor);
            _rayMarchShadowSoftness.Portion(ld, shadowSoftness.Value);
            _RayMarchFogColor.Portion(ld, _fogColor);
            _RayMarchReflectionColor.Portion(ld, _reflectionColor);

            _rayMarchSmoothness.Lerp(ld);
            _RayMarchLightColor.Lerp(ld);
            _rayMarchShadowSoftness.Lerp(ld);
            _RayMarchFogColor.Lerp(ld);
            _RayMarchReflectionColor.Lerp(ld);
        }

        #region Inspector
        public static RayMarchingManager inspected;
        
        public bool Inspect()
        {

            var changed = false;

            inspected = this;

            "Max Steps".edit(ref _maxSteps, 1, 400).nl(ref changed);

            "Max Distance".edit(ref _maxDistance, 1, 50000).nl(ref changed);

            "CONFIGS".nl();

            "Smoothness:".nl();
            smoothness.Inspect().nl(ref changed);
            "Shadow Softness".nl();
            shadowSoftness.Inspect().nl(ref changed);
            "Light Color".edit(ref _lightColor).nl(ref changed);
            "Fog Color".edit(ref _fogColor).nl(ref changed);
            "Reflection Tint".edit(ref _reflectionColor).nl(ref changed);

            ConfigurationsListBase.Inspect(ref configs).changes(ref changed);



            if (changed)
                UpdateShadeVariables();

            return changed;
        }
        #endregion

        #region Encode & Decode
        public CfgEncoder Encode() => new CfgEncoder()
            .Add("sm", smoothness)
            .Add("col", _lightColor)
            .Add("shSo", shadowSoftness)
            .Add("fog",_fogColor)
            .Add("refl", _reflectionColor);
        
        public bool Decode(string tg, string data)
        {
            switch (tg)
            {
                case "sm": smoothness.Decode(data); break;
                case "col": _lightColor = data.ToColor(); break;
                case "shSo": shadowSoftness.Decode(data); break;
                case "fog": _fogColor = data.ToColor(); break;
                case "refl": _reflectionColor = data.ToColor(); break;
                default: return false;
            }

            return true;
        }

        public void Decode(string data) => new CfgDecoder(data).DecodeTagsFor(this);
        #endregion
    }





#if UNITY_EDITOR
    [CustomEditor(typeof(RayMarchingManager))]
    public class RayMarchingManagerDrawer : PEGI_Inspector_Mono<RayMarchingManager> { }
#endif

}