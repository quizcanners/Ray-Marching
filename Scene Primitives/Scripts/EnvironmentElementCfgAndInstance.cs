using PainterTool;
using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.RayTracing
{
    public partial class Singleton_EnvironmentElementsManager
    {
        public class CfgAndInstance : IPEGI_ListInspect, IPEGI
        {
            public C_RayT_PrimShape_EnvironmentElement EnvironmentElement;
            //private CfgData _data;

            private readonly Gate.Frame _instanceWeightGate = new();
            private float _weight = 0;

            public bool UsePrimitive => EnvironmentElement;

            public float GetOverlap(Vector3 center, Vector3 size) 
            {
                return EnvironmentElement.GetOverlap(worldPos: center, size);
            }

            public float VolumeWeight
            {
                get
                {
                    if (!UsePrimitive)
                        return -1000;

                    if (EnvironmentElement && _instanceWeightGate.TryEnter())
                    {
                        _weight = 0;

                        var vol = C_VolumeTexture.LatestInstance;
                        if (vol)
                        {
                            var size = vol.size;

                            _weight = EnvironmentElement.GetOverlap(
                                worldPos: vol.GetPositionAndSizeForShader().XYZ(),
                                width: vol.Width * size,
                                height: vol.Height * size);
                        }
                    }

                    return _weight;
                }
            }

            public void Destroy()
            {
                if (EnvironmentElement)
                    EnvironmentElement.gameObject.DestroyWhatever();
            }

            #region Inspector
            public void InspectInList(ref int edited, int index)
            {
                ToString().PegiLabel().Write();

                if (Icon.Enter.Click())
                    edited = index;

                if (EnvironmentElement)
                    pegi.ClickHighlight(EnvironmentElement);
            }

            public void Inspect()
            {
                if (EnvironmentElement)
                    EnvironmentElement.Nested_Inspect();
                else
                    "No instance".PegiLabel().Write_Hint();
            }

            public override string ToString() => (EnvironmentElement ? ((Application.isPlaying ? "[W:{0}] ".F(((int)VolumeWeight).ToString())  : "") + EnvironmentElement.GetNameForInspector_Uobj()) : "Not Instanced");
            
            #endregion

            public CfgAndInstance(C_RayT_PrimShape_EnvironmentElement el)
            {
                EnvironmentElement = el;
                el.Registered = true;
            }
            public CfgAndInstance()
            {

            }
        }
    }
}