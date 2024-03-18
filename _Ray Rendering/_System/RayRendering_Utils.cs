using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    public static partial class QcRender
    {
        internal static Singleton_QcRendering Mgmt => Singleton.Get<Singleton_QcRendering>();

        public enum RayRenderingTarget 
        { 
            Disabled = 0, 
            RayIntersection = 1, 
            RayMarching = 2, 
            Volume = 3, 
            ProgressiveRayMarching = 4 
        }

        public static bool MOBILE 
        { 
            get
            {
                if (Application.isMobilePlatform)
                    return true;

                return false; //Singleton.TryGetValue<Singleton_RayRendering, bool>(s => s.qualityManager.MOBILE.Enabled, defaultValue: false);
            } 
        }
    }
}
