using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.SpecialEffects
{
    public class Singleton_IlluminationDecals : Singleton.BehaniourBase, IPEGI
    {
        public Camera Camera;
        [SerializeField] private DecalIlluminationPass IlluminationDecals = new();

        protected override void OnAfterEnable()
        {
            base.OnAfterEnable();
            IlluminationDecals.OnEnable();
        }

        protected override void OnBeforeOnDisableOrEnterPlayMode(bool afterEnableCalled)
        {
            base.OnBeforeOnDisableOrEnterPlayMode(afterEnableCalled);

            IlluminationDecals.OnDisable();
        }

        void OnPreRender()
        {
            IlluminationDecals.OnPreRender();
        }

        void OnPostRender() 
        {
            IlluminationDecals.OnPostRender();
        }

        #region Inspector

        public override void Inspect()
        {
            "Camera".PegiLabel().Edit_IfNull(ref Camera, gameObject).Nl();
            IlluminationDecals.Nested_Inspect();
        }

        #endregion
    }

    [PEGI_Inspector_Override(typeof(Singleton_IlluminationDecals))]
    internal class Singleton_IlluminationDecalsDrawer : PEGI_Inspector_Override { }
}
