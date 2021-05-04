using QuizCanners.CfgDecode;
using QuizCanners.Inspect;
using QuizCanners.Lerp;
using System;
using UnityEngine;

namespace QuizCanners.RayTracing
{
    [Serializable]
    public class RayRandering_LightsManager : IPEGI, ILinkedLerping, ICfgCustom, IPEGI_ListInspect
    {
        [SerializeField] private RayRendering_LightConfigs configs;

        private LinkedLerp.MaterialColor _sunLightColor = new LinkedLerp.MaterialColor("_RayMarchLightColor", Color.grey, 10);
        private LinkedLerp.MaterialColor _skyColor = new LinkedLerp.MaterialColor("_RayMarchSkyColor", Color.grey, 10);
        private LinkedLerp.ColorValue _fogColor = new LinkedLerp.ColorValue("Fog", speed: 10);

        protected RayRenderingManager Mgmt => RayRenderingManager.instance;

        #region Encode & Decode
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

        #endregion

        #region Lerp
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

        #endregion

        #region Inspector
        public void Inspect()
        {
            pegi.nl();

            var col = _sunLightColor.TargetValue;
            if ("Light Color".edit(ref col).nl())
                _sunLightColor.TargetValue = col;

            col = _skyColor.TargetValue;
            if ("Sky Color".edit(ref col).nl())
                _skyColor.TargetValue = col;

            col = _fogColor.TargetValue;
            if ("Fog Color".edit(ref col).nl())
                _fogColor.TargetValue = col;

            ConfigurationsSO_Base.Inspect(ref configs);
        }

        public void InspectInList(int ind, ref int edited)
        {
            if (icon.Enter.Click() || "Lights".ClickLabel())
                edited = ind;

            if (!configs)
                "CFG".edit(60, ref configs);
            else
                configs.InspectShortcut();
        }

        #endregion
    }
}