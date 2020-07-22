using QuizCanners.Migration;
using QuizCanners.Utils;
using System;
using UnityEngine;

namespace QuizCanners.RayTracing
{
    [CreateAssetMenu(fileName = FILE_NAME, menuName = QcUnity.SO_CREATE_MENU + "Ray Renderer/" + FILE_NAME)]
    public class SO_RayRendering_TracerConfigs : SO_Configurations_Generic<RendererConfig>
    {
        public const string FILE_NAME = "Ray Renderer Tracer Config";
    }

    [Serializable]
    public class RendererConfig : Configuration
    {

        public static Configuration ActiveConfig;

        protected override Configuration ActiveConfig_Internal
        {
            get => ActiveConfig;
            set
            {
                if (ActiveConfig == value)
                    return;
                ActiveConfig = value;
                Singleton.Get<Singleton_RayRendering>().tracerManager.Decode(value);
            }

        }

        public override CfgEncoder EncodeData() => Singleton.Get<Singleton_RayRendering>().tracerManager.Encode();
    }
}