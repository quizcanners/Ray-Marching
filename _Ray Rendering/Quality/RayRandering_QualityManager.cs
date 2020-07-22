using QuizCanners.Inspect;
using QuizCanners.Migration;
using QuizCanners.Utils;

namespace QuizCanners.RayTracing
{
    internal partial class Singleton_RayRendering
    {
        public class QualityManager : IPEGI, ICfg, IPEGI_ListInspect
        {
            internal readonly ShaderProperty.Feature MOBILE = new("_qc_Rtx_MOBILE");

            internal void ManagedOnEnable() 
            {
                MOBILE.Enabled = QcRTX.MOBILE;
            }

            public void DecodeTag(string key, CfgData data)
            {
                switch (key) 
                {
                    case "mob": MOBILE.Enabled = data.ToBool(); break;
                }
            }

            public CfgEncoder Encode() => new CfgEncoder()
                .Add_Bool("mob", MOBILE.Enabled);

            #region Inspector

            public void Inspect()
            {
               // REFLECTIONS.Nested_Inspect();
                MOBILE.Nested_Inspect();
            }

            public void InspectInList(ref int edited, int index)
            {

                if (Icon.Enter.Click())
                    edited = index;

                if ("Quality".PegiLabel().ClickLabel())
                    edited = index;

            }
            #endregion
        }
    }
}