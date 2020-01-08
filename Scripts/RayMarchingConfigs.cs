using QuizCannersUtilities;
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace RayMarching
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
                RayMarchingManager.inspected.Decode(data);
            }

        }

        public override CfgEncoder EncodeData() => RayMarchingManager.inspected.Encode();
    }
}