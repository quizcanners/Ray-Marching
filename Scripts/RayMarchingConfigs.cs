using System;
using QuizCannersUtilities;

namespace NodeNotes.RayTracing
{
    
    public class RayMarchingConfigs : ConfigurationsListGeneric<RayMarchingConfig>
    {
    }

    [Serializable]
    public class RayMarchingConfig : Configuration
    {

        public static Configuration ActiveConfig;

        public override Configuration ActiveConfiguration
        {
            get { return ActiveConfig; }
            set
            {
                ActiveConfig = value;
                RayRenderingManager.inspected.Decode(data);
            }

        }

        public override CfgEncoder EncodeData() => RayRenderingManager.inspected.Encode();
    }
}