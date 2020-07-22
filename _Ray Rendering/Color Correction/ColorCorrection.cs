using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using UnityEngine;

namespace QuizCanners.RayTracing
{
    internal partial class Singleton_RayRendering
    {
        [Serializable]
        public class ColorManager : IPEGI
        {
            private readonly ShaderProperty.ColorFloat4Value COLOR_CORRECT_COLOR = new("_qc_ColorCorrection_Color", Color.white);
            private readonly ShaderProperty.VectorValue COLOR_CORRECT_PARAMETERS = new("_qc_ColorCorrection_Params");

            private float Shadow 
            {
                get => COLOR_CORRECT_PARAMETERS.latestValue.x;
                set => COLOR_CORRECT_PARAMETERS.SetGlobal(COLOR_CORRECT_PARAMETERS.latestValue.X(value));
            }

            private float FadeBrightness
            {
                get => COLOR_CORRECT_PARAMETERS.latestValue.y;
                set => COLOR_CORRECT_PARAMETERS.SetGlobal(COLOR_CORRECT_PARAMETERS.latestValue.Y(value));
            }

            private float Saturate
            {
                get => COLOR_CORRECT_PARAMETERS.latestValue.z;
                set => COLOR_CORRECT_PARAMETERS.SetGlobal(COLOR_CORRECT_PARAMETERS.latestValue.Z(value));
            }

            private float Colorize
            {
                get => COLOR_CORRECT_PARAMETERS.latestValue.w;
                set => COLOR_CORRECT_PARAMETERS.SetGlobal(COLOR_CORRECT_PARAMETERS.latestValue.W(value));
            }

            internal void ManagedOnEnable() 
            {
                UpdateGlobalParameters();
            }

            void UpdateGlobalParameters() 
            {
                COLOR_CORRECT_COLOR.SetGlobal();
                COLOR_CORRECT_PARAMETERS.SetGlobal();
            }

            public override string ToString() => "Color correction";

            public void Inspect()
            {
                var changed = pegi.ChangeTrackStart();

                COLOR_CORRECT_COLOR.Nested_Inspect();

                float val = Shadow;
                "Shadow".PegiLabel(60).Edit(ref val, 0, 0.5f).Nl().OnChanged(()=> Shadow = val);
                val = FadeBrightness;
                "Fade".PegiLabel(60).Edit(ref val, 0, 0.5f).Nl().OnChanged(() => FadeBrightness = val);
                val = Saturate;
                "DeSaturate".PegiLabel(60).Edit(ref val, 0, 1f).Nl().OnChanged(() => Saturate = val);
                val = Colorize;
                "Colorize".PegiLabel(60).Edit(ref val, 0, 1f).Nl().OnChanged(() => Colorize = val);

                if (changed)
                UpdateGlobalParameters();
            }
        }
    }
}