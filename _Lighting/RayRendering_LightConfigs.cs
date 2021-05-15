using QuizCanners.CfgDecode;
using System;
using UnityEngine;


namespace QuizCanners.RayTracing
{
    [CreateAssetMenu(fileName = FILE_NAME, menuName = "Quiz Canners/Ray Renderer/"+FILE_NAME)]
    public class RayRendering_LightConfigs : ConfigurationsSO_Generic<LightConfig>
    {
        public const string FILE_NAME = "Ray Renderer Light Config";
    }

    [Serializable]
    public class LightConfig : Configuration
    {

        public static Configuration ActiveConfig;

        public override Configuration ActiveConfiguration
        {
            get { return ActiveConfig; }
            set
            {
                ActiveConfig = value;
                RayRenderingManager.instance.LightsManager.Decode(ActiveConfig.data);
            }

        }

        public override CfgEncoder EncodeData() => RayRenderingManager.instance.LightsManager.Encode();
    }
}