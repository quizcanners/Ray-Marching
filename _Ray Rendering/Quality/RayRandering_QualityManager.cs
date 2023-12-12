using QuizCanners.Inspect;
using QuizCanners.Migration;

namespace QuizCanners.RayTracing
{
    public static partial class RayRendering
    {
        public class QualityManager : IPEGI, ICfg, IPEGI_ListInspect
        {

            internal void ManagedOnEnable() 
            {
            }

            public void DecodeTag(string key, CfgData data)
            {
               
            }

            public CfgEncoder Encode() => new CfgEncoder()
                //Add_Bool("mob", MOBILE.Enabled)
                ;

            #region Inspector

            void IPEGI.Inspect()
            {
               // REFLECTIONS.Nested_Inspect();
               // MOBILE.Nested_Inspect();
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