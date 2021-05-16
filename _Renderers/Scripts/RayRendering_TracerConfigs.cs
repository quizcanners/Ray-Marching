using QuizCanners.CfgDecode;
using System;
using UnityEngine;

namespace QuizCanners.RayTracing
{
    [CreateAssetMenu(fileName = FILE_NAME, menuName = "Quiz Canners/Ray Renderer/" + FILE_NAME)]
    public class RayRendering_TracerConfigs : ConfigurationsSO_Generic<RendererConfig>
    {
        public const string FILE_NAME = "Ray Renderer Tracer Config";
    }

    [Serializable]
    public class RendererConfig : Configuration
    {

        public static Configuration ActiveConfig;

        public override Configuration ActiveConfiguration
        {
            get { return ActiveConfig; }
            set
            {
                ActiveConfig = value;
                RayRenderingManager.instance.tracerManager.Decode(value.data);
            }

        }

        public override CfgEncoder EncodeData() => RayRenderingManager.instance.tracerManager.Encode();
    }
}