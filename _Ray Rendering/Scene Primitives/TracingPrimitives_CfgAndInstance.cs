using PainterTool;
using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    public static partial class TracingPrimitives
    {
        public class CfgAndInstance : IPEGI_ListInspect, IPEGI
        {
            public C_RayT_PrimShape EnvironmentElement;
            //private CfgData _data;

            public float LatestOverlapCheck => EnvironmentElement.LatestVolumeOverlap;
            private readonly Gate.Frame _instanceWeightGate = new();
            private float _weight = 0;

            public bool Unroated => EnvironmentElement.Unrotated;

            public bool IsValid => EnvironmentElement && EnvironmentElement.gameObject.activeInHierarchy;//Instances[i].EnvironmentElement || !Instances[i].EnvironmentElement.gameObject.activeInHierarchy

            public float GetOverlap(Vector3 bottomCenter, Vector3 size, bool prioratizeHigher) 
            {
                return EnvironmentElement.GetOverlap(bottomCenter: bottomCenter, size, prioratizeHigher: prioratizeHigher);
            }

            public float VolumeWeight
            {
                get
                {
                    if (!EnvironmentElement)
                        return -1000;

                    if (_instanceWeightGate.TryEnter())
                    {
                        _weight = 0;

                        var vol = C_VolumeTexture.LatestInstance;
                        if (vol)
                        {
                            var size = vol.size;

                            _weight = EnvironmentElement.GetOverlap(
                                worldPos: vol.GetPositionAndSizeForShader().XYZ(),
                                width: vol.SliceWidth * size,
                                height: vol.TextureHeight * size, prioratizeHigher: true);
                        }
                    }

                    return _weight;
                }
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

            void IPEGI.Inspect()
            {
                if (EnvironmentElement)
                    EnvironmentElement.Nested_Inspect();
                else
                    "No instance".PegiLabel().Write_Hint();
            }

            public override string ToString() => (EnvironmentElement ? ((Application.isPlaying ? "[W:{0}] ".F(((int)VolumeWeight).ToString())  : "") + EnvironmentElement.GetNameForInspector_Uobj()) : "Not Instanced");
            
            #endregion

            public CfgAndInstance(C_RayT_PrimShape el)
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