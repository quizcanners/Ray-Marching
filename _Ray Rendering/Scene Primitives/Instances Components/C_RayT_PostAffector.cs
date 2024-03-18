using QuizCanners.Inspect;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    [ExecuteAlways]
    public class C_RayT_PostAffector : MonoBehaviour, IPEGI
    {
        public TracingPrimitives.PostBakingEffects.ElementType Type;
        public Color LightColor;
        public float Angle = 0.5f;

        void OnEnable() 
        {
            TracingPrimitives.s_postEffets.Register(this);
        }

        void OnDisable() 
        {
            TracingPrimitives.s_postEffets.UnRegister(this);
        }

        #region Inspector

        public override string ToString() => Type.ToString() + " " + gameObject.name;

        void IPEGI.Inspect()
        {
            "Type".PegiLabel(50).Edit_Enum(ref Type).Nl();
            "Color".PegiLabel(60).Edit(ref LightColor, hdr: true).Nl();

            if (Type == TracingPrimitives.PostBakingEffects.ElementType.Projector)
            {
                
                "Angle".PegiLabel().Edit(ref Angle, 0f, 1f).Nl();
            }

        }
        #endregion
    }

    [PEGI_Inspector_Override(typeof(C_RayT_PostAffector))]
    internal class C_RayT_PostAffector_EnvironmentElementDrawer : PEGI_Inspector_Override { }
}
