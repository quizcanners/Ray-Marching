using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace UniStorm.Utility
{
    public class VRState : ScriptableObject
    {
        [HideInInspector] public bool VREnabled;
        [HideInInspector] public StereoRenderingModes StereoRenderingMode = StereoRenderingModes.SinglePass;
        public enum StereoRenderingModes { SinglePass, MultiPass };
    }
}