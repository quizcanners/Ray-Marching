using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    public static partial class QcRender
    {
        [Serializable]
        internal class TracingPrimitivesManager : IPEGI, IPEGI_ListInspect, INeedAttention
        {
            [NonSerialized] public float StableFrames;
            [NonSerialized] private Vector3 _previousCamPosition = Vector3.zero;
            [NonSerialized] private Quaternion _previousCamRotation = Quaternion.identity;
            [NonSerialized] public float CameraMotion;

            private Singleton_RayRenderingCameraAndOutput TracingToCameraSource => Singleton.Get<Singleton_RayRenderingCameraAndOutput>();
            private Singleton_RayRendering_UiScreenSpaceOutput UiScreenSpaceOutput => Singleton.Get<Singleton_RayRendering_UiScreenSpaceOutput>();
            public Camera MainCamera => TracingToCameraSource.WorldCamera; 


            public void OnSetBakingDirty()
            {
                StableFrames = 0;
            
            }

            public void OnSwap(RenderTexture currentTargetBuffer)
            {
                if (MainCamera)
                    MainCamera.targetTexture = currentTargetBuffer;

                if (UiScreenSpaceOutput)
                    UiScreenSpaceOutput.RawImage.texture = currentTargetBuffer;
            }

            public void ManagedUpdate(out int stableFrames)
            {
                var isScreen = Mgmt.TargetIsScreenBuffer;

                Singleton.Try<Singleton_TracingPrimitivesController>(s => s.ManagedUpdate());

                TracingToCameraSource.ShowTracing = isScreen;

                if (MainCamera)
                {
                    var tf = MainCamera.transform;

                    if (isScreen)
                    {
                        var position = tf.position;
                        var rotation = tf.rotation;
                        CameraMotion = (_previousCamPosition - position).magnitude * 10 +
                                           Quaternion.Angle(_previousCamRotation, rotation);

                        if (Mgmt.Target == RayRenderingTarget.ProgressiveRayMarching)
                            CameraMotion *= 10000;

                        _previousCamPosition = position;
                        _previousCamRotation = rotation;

                        CameraMotion = 1 - Mathf.Clamp01(CameraMotion);

                        StableFrames = StableFrames * CameraMotion + CameraMotion;
                    }
                    else
                        StableFrames += 1;
                }

                if (UiScreenSpaceOutput)
                    UiScreenSpaceOutput.ShowTracing = isScreen;

                stableFrames = (int)StableFrames;

            }

            #region Inspector
            public void InspectInList(ref int edited, int ind)
            {
                "Scene".PegiLabel().ClickEnter(ref edited, ind);
            }

            void IPEGI.Inspect()
            {
                pegi.Nl();
                TracingPrimitives.Inspect();
            }

            public override string ToString() => "Tracing Primitives";

            public string NeedAttention()
            {
                if (Singleton.Get<Singleton_TracingPrimitivesController>().TryGetAttentionMessage(out var msg))
                    return msg;

                if (UiScreenSpaceOutput.TryGetAttentionMessage(out msg))
                    return msg;

                if (TracingToCameraSource.TryGetAttentionMessage(out msg))
                    return msg;

                return null;
            }

            #endregion

            public void ManagedOnEnable()
            {
                OnSetBakingDirty();
            }

            public void ManagedOnDisable()
            {
            }
        }
    }
}
