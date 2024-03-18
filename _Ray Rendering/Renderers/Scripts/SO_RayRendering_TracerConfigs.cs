using QuizCanners.Migration;
using QuizCanners.Utils;
using System;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    [CreateAssetMenu(fileName = FILE_NAME, menuName = QcUnity.SO_CREATE_MENU + "Ray Renderer/" + FILE_NAME)]
    public class SO_RayRendering_TracerConfigs : SO_Configurations_Generic<QcRender.Config>
    {
        public const string FILE_NAME = "Ray Renderer Tracer Config";
    }

    public static partial class QcRender
    {
        [Serializable]
        public class Config : Configuration
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
                    Singleton.Get<Singleton_QcRendering>().tracerManager.Decode(value);
                }

            }

            public override CfgEncoder EncodeData() => Singleton.Get<Singleton_QcRendering>().tracerManager.Encode();
        }
    }
}