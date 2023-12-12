using QuizCanners.Inspect;
using UnityEngine;

namespace QuizCanners.RayTracing
{
    public class C_RayT_PostAffector_EnvironmentElement : MonoBehaviour, IPEGI
    {
        public TracingPrimitives.PostBakingEffects.ElementType Type;
        public Color LightColor;


        void OnEnable() 
        {
            TracingPrimitives.s_postEffets.Register(this);
        }

        void OnDisable() 
        {
            TracingPrimitives.s_postEffets.UnRegister(this);
        }

        #region Inspector
        void IPEGI.Inspect()
        {
            "Type".PegiLabel(50).Edit_Enum(ref Type).Nl();
            "Color".PegiLabel(60).Edit(ref LightColor, hdr: true).Nl();

        }
        #endregion
    }

    [PEGI_Inspector_Override(typeof(C_RayT_PostAffector_EnvironmentElement))]
    internal class C_RayT_PostAffector_EnvironmentElementDrawer : PEGI_Inspector_Override { }
}
