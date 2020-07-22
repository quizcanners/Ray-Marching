using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.RayTracing
{
    public static class QcRTX 
    {
        public enum Shape { Cube, Sphere, AmbientLightSource, SubtractiveCube, Capsule }
        public enum PrimitiveMaterialType { lambertian = 0, metallic = 1, dialectric = 2, glass = 3, emissive = 4, Subtractive = 5 }

        public static bool MOBILE 
        { 
            get
            {
                if (Application.isMobilePlatform)
                    return true;

                return Singleton.TryGetValue<Singleton_RayRendering, bool>(s => s.qualityManager.MOBILE.Enabled, defaultValue: false);
            } 
        }

    }
}
