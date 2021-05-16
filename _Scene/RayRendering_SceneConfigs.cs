using QuizCanners.CfgDecode;
using System;
using UnityEngine;

namespace QuizCanners.RayTracing
{

    [CreateAssetMenu(fileName = FILE_NAME, menuName = "Quiz Canners/Ray Renderer/" + FILE_NAME)]
    public class RayRendering_SceneConfigs : ConfigurationsSO_Generic<SceneConfig>
    {
        public const string FILE_NAME = "Ray Renderer Scene Config";
    }

    [Serializable]
    public class SceneConfig : Configuration
    {

        public static Configuration ActiveConfig;

        public override Configuration ActiveConfiguration
        {
            get { return ActiveConfig; }
            set
            {
                ActiveConfig = value;
                RayRenderingManager.instance.sceneManager.Decode(ActiveConfig.data);
            }

        }

        public override CfgEncoder EncodeData() => RayRenderingManager.instance.sceneManager.Encode();
    }
}