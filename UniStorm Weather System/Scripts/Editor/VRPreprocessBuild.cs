/*
using UnityEngine;
using UnityEditor;
using UnityEditor.Build;

namespace UniStorm.Utility
{
    /// <summary>
    /// When building, check the state of VR, along with the StereoRenderingPath, and cache it within VR State Data so it can be used during runtime for VR related features.
    /// </summary>
    public class VRPreprocessBuild : IPreprocessBuildWithReport
    {
        public int callbackOrder { get { return 0; } }
        public void OnPreprocessBuild(UnityEditor.Build.Reporting.BuildReport report)
        {
            var VRStateData = Resources.Load("VR State Data") as VRState;
            VRStateData.VREnabled = UnityEngine.XR.XRSettings.enabled;

            if (PlayerSettings.stereoRenderingPath == StereoRenderingPath.SinglePass)
                VRStateData.StereoRenderingMode = VRState.StereoRenderingModes.SinglePass;
            else if (PlayerSettings.stereoRenderingPath == StereoRenderingPath.MultiPass)
                VRStateData.StereoRenderingMode = VRState.StereoRenderingModes.MultiPass;
        }
    }
}*/