using QuizCanners.Inspect;

namespace QuizCanners.VolumeBakedRendering
{
    public static partial class QcRender
    {
        public class QualityManager : IPEGI, IPEGI_ListInspect
        {

            internal void ManagedOnEnable() 
            {
            }



            #region Inspector

            void IPEGI.Inspect()
            {
               // REFLECTIONS.Nested_Inspect();
               // MOBILE.Nested_Inspect();
            }

            public void InspectInList(ref int edited, int index)
            {
                "Quality".PegiLabel().ClickEnter(ref edited, index);
            }
            #endregion
        }
    }
}