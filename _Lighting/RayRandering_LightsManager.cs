using QuizCanners.CfgDecode;
using QuizCanners.Inspect;
using QuizCanners.Lerp;
using System;
using UnityEngine;

namespace QuizCanners.RayTracing
{
    [Serializable]
    public class RayRandering_LightsManager : IPEGI, ILinkedLerping, ICfgCustom
    {
        [SerializeField] private RayRendering_LightConfigs configs;


        private LinkedLerp.MaterialColor _sunLightColor = new LinkedLerp.MaterialColor("_RayMarchLightColor", Color.grey, 10);
        private LinkedLerp.MaterialColor _skyColor = new LinkedLerp.MaterialColor("_RayMarchSkyColor", Color.grey, 10);
        private LinkedLerp.ColorValue _fogColor = new LinkedLerp.ColorValue("Fog", speed: 10);

        protected RayRenderingManager Mgmt => RayRenderingManager.instance;

        public void Decode(CfgData data)
        {
            new CfgDecoder(data).DecodeTagsFor(this);
            Mgmt.RequestLerps();
        }
        public void Decode(string key, CfgData data)
        {
            switch (key)
            {
                case "col": _sunLightColor.TargetValue = data.ToColor(); break;
                case "sky": _skyColor.TargetValue = data.ToColor(); break;
                case "fog": _fogColor.TargetValue = data.ToColor(); break;
            }
        }

        public CfgEncoder Encode() => new CfgEncoder()
             .Add("col", _sunLightColor.TargetValue)
                .Add("sky", _skyColor.TargetValue)
                .Add("fog", _fogColor.TargetValue);

        public void Inspect()
        {
            "Light Color".edit(ref _sunLightColor.targetValue).nl();
            "Sky Color".edit(ref _skyColor.targetValue).nl();
            "Fog Color".edit(ref _fogColor.targetValue).nl();

            ConfigurationsListBase.Inspect(ref configs);
        }

       

        public void Portion(LerpData ld)
        {
            _sunLightColor.Portion(ld);
            _skyColor.Portion(ld);
            _fogColor.Portion(ld);
        }

        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            _sunLightColor.Lerp(ld, canSkipLerp);
            _skyColor.Lerp(ld, canSkipLerp);
            _fogColor.Lerp(ld, canSkipLerp);
            RenderSettings.fogColor = _fogColor.CurrentValue;
        }
    }
}