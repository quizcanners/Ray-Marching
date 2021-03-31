using QuizCanners.CfgDecode;
using System;
using UnityEngine;


namespace QuizCanners.RayTracing
{
    [CreateAssetMenu(fileName = FILE_NAME, menuName = "Quiz Canners/Ray Renderer/"+FILE_NAME)]
    public class RayRendering_LightConfigs : ConfigurationsListGeneric<LightConfig>
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
                RayRenderingManager.inspected.LightsManager.Decode(data);
            }

        }

        public override CfgEncoder EncodeData() => RayRenderingManager.inspected.LightsManager.Encode();
    }
}