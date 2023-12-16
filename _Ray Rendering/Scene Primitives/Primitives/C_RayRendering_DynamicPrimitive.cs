using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.RayTracing
{
    [ExecuteAlways]
    [AddComponentMenu(QcUtils.QUIZCANNERS + "/PrimitiveTracing/Proxy/Dynamic Primitive")]
    public class C_RayRendering_DynamicPrimitive : C_RayRendering_PrimitiveBase, IPEGI
    {
        [SerializeField] private Color _color = Color.gray;

        public Color Color
        {
            get => _color;
            set => _color = value;
        } 

        public override Vector4 SHD_ColorAndRoughness => _color.Alpha(0.5f);
        protected override TracingPrimitives.Shape GetShape() => TracingPrimitives.Shape.Capsule;

        protected override void OnEnable()
        {
            base.OnEnable();
            TracingPrimitives.Dynamic.instances.Add(this);
        }

        private void OnDisable()
        {
            TracingPrimitives.Dynamic.instances.Remove(this);
        }

        #region Inspector
        void IPEGI.Inspect()
        {
            pegi.TryDefaultInspect(this);
        }

       
        #endregion
    }

    [PEGI_Inspector_Override(typeof(C_RayRendering_DynamicPrimitive))]
    internal class C_RayRendering_DynamicPrimitiveDrawer : PEGI_Inspector_Override { }
}