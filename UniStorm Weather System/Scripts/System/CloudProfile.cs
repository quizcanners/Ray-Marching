using QuizCanners.Inspect;
using QuizCanners.Utils;
using UniStorm.Utility;
using UnityEngine;

namespace UniStorm
{
    [CreateAssetMenu(fileName = "New Cloud Profile", menuName = QcUnity.SO_CREATE_MENU + "UniStorm/New Cloud Profile")]
    public class CloudProfile : ScriptableObject, IPEGI
    {
        public string ProfileName = "New Cloud Profile Name";
        public float EdgeSoftness = 0.067f;
        public float BaseSoftness = 0.13f;
        public float DetailStrength = 0.114f;
        public float Density = 0.9f;
        public float CoverageBias = 0.0175f;
        public int DetailScale = 730;
        public float cloudThickness = 1000;
        public override string ToString() => "Cloud Profile: " + name;

        Material SkyMaterial => Singleton.Get<UniStormClouds>().skyMaterial;


        internal static readonly ShaderProperty.FloatValue COVERAGE = new("_uCloudsCoverage");
        internal static readonly ShaderProperty.FloatValue BASE_SCALE = new("_uCloudsBaseScale");
        internal static readonly ShaderProperty.FloatValue DETAIL_SCALE = new("_uCloudsDetailScale");
        internal static readonly ShaderProperty.FloatValue EDGE_SOFTNESS = new("_uCloudsBaseEdgeSoftness");
        internal static readonly ShaderProperty.FloatValue BOTTOM_SOFTNESS = new("_uCloudsBottomSoftness");
        internal static readonly ShaderProperty.FloatValue DETAIL_STRENGTH = new("_uCloudsDetailStrength");
        internal static readonly ShaderProperty.FloatValue DENSIY = new("_uCloudsDensity");
        internal static readonly ShaderProperty.FloatValue COVERAGE_BIAS = new("_uCloudsCoverageBias");
        internal static readonly ShaderProperty.FloatValue BOTTOM = new("_uCloudsBottom");
        internal static readonly ShaderProperty.FloatValue _uCloudsHeight = new("_uCloudsHeight");

        internal void SetToShader() 
        {
            SkyMaterial.Set(EDGE_SOFTNESS, EdgeSoftness);
            SkyMaterial.Set(BOTTOM_SOFTNESS, BaseSoftness);
            SkyMaterial.Set(DETAIL_STRENGTH, DetailStrength);
            SkyMaterial.Set(DENSIY, Density);
            SkyMaterial.Set(_uCloudsHeight, cloudThickness);
        }

        public void Inspect()
        {
            var changes = pegi.ChangeTrackStart();

            "Edge Softness".PegiLabel().Edit(ref EdgeSoftness, 0.001f, 0.5f).Nl();
            "Base Softness".PegiLabel().Edit(ref BaseSoftness, 0.02f, 2).Nl();
            "Detail Strength".PegiLabel().Edit(ref DetailStrength, 0.02f, 0.2f).Nl();
            "Density".PegiLabel().Edit(ref Density, 0.1f, 1).Nl();
            "Coverage Bias".PegiLabel().Edit(ref CoverageBias, -0.05f, 0.1f).Nl();
            "Height".PegiLabel().Edit(ref cloudThickness, 500, 4000).Nl();

            if (changes)
                SetToShader();
        }
    }

    [PEGI_Inspector_Override(typeof(CloudProfile))] internal class CloudProfileDraer : PEGI_Inspector_Override { }
}