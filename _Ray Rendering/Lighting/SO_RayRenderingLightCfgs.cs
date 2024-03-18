using QuizCanners.Migration;
using QuizCanners.Utils;
using System;
using UnityEngine;


namespace QuizCanners.VolumeBakedRendering
{
    [CreateAssetMenu(fileName = FILE_NAME, menuName = QcUnity.SO_CREATE_MENU + "Ray Renderer/" + FILE_NAME)]
    internal class SO_RayRenderingLightCfgs : SO_Configurations_Generic<LightConfig>
    {
        public const string FILE_NAME = "Ray Renderer Light Config";
    }

    [Serializable]
    internal class LightConfig : Configuration
    {

        public static Configuration ActiveConfig;

        protected override Configuration ActiveConfig_Internal
        {
            get => ActiveConfig; 
            set
            {
                ActiveConfig = value;
                Singleton.Get<Singleton_QcRendering>().lightsManager.Decode(ActiveConfig);
            }
        }

        public override CfgEncoder EncodeData() => Singleton.Get<Singleton_QcRendering>().lightsManager.Encode();
    }
}