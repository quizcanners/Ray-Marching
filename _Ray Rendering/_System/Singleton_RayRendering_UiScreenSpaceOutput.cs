using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;
using UnityEngine.UI;

namespace QuizCanners.RayTracing
{
    [ExecuteAlways]
    [AddComponentMenu("Quiz ñ'Anners/Ray Rendering/Output")]
    internal class Singleton_RayRendering_UiScreenSpaceOutput : Singleton.BehaniourBase
    {
        public RawImage RawImage;

        public bool ShowTracing
        {
            set
            {
                RawImage.enabled = value;
            }
        }

        protected override void OnAfterEnable()
        {
            base.OnAfterEnable();
            ShowTracing = false;
        }

        private void Reset()
        {
            RawImage = GetComponent<RawImage>();
        }

        #region Inspector
        public override string InspectedCategory => nameof(RayTracing);

        public override void Inspect()
        {
            "Ray Rendering Ui Screen Space Output".PegiLabel(pegi.Styles.ListLabel).Nl();
            "Raw Image".PegiLabel().Edit(ref RawImage).Nl();   
        }

        public override string ToString() => "Output";

        public override string NeedAttention()
        {
            if (!RawImage)
                return "{0} Not Assigned".F(nameof(RawImage));

            return base.NeedAttention();
        }

        #endregion
    }
}