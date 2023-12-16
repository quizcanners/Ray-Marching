using QuizCanners.Migration;
using QuizCanners.Inspect;
using QuizCanners.Lerp;
using QuizCanners.Utils;
using System;
using UnityEngine;

namespace QuizCanners.RayTracing
{
    public static partial class RayRendering
    {
        [Serializable]
        internal class SceneManager : IPEGI, ILinkedLerping, ICfgCustom, IPEGI_ListInspect, INeedAttention
        {
            private Singleton_TracingPrimitivesController TracingPrimitives => Singleton.Get<Singleton_TracingPrimitivesController>();
            private Singleton_RayRenderingCameraAndOutput TracingToCameraSource => Singleton.Get<Singleton_RayRenderingCameraAndOutput>();
            private Singleton_RayRendering_UiScreenSpaceOutput UiScreenSpaceOutput => Singleton.Get<Singleton_RayRendering_UiScreenSpaceOutput>();

            [NonSerialized] public float StableFrames;
            [NonSerialized] private Vector3 _previousCamPosition = Vector3.zero;
            [NonSerialized] private Quaternion _previousCamRotation = Quaternion.identity;
            [NonSerialized] public float CameraMotion;
           

            private Singleton_CameraOperatorConfigurable GodModeCamera => Singleton.Get<Singleton_CameraOperatorConfigurable>();
            public Camera MainCamera => TracingToCameraSource.WorldCamera; //GodModeCamera ? GodModeCamera.MainCam : null;


            public void OnSetBakingDirty()
            {
                StableFrames = 0;
            
            }

            public void ManagedOnEnable() 
            {
                OnSetBakingDirty();
            }

            public void ManagedOnDisable() 
            {
                //Configs.IndexOfActiveConfiguration = -1;
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

            #region Linked Lerp
            public void Lerp(LerpData ld, bool canSkipLerp)
            {
                if (GodModeCamera)
                    GodModeCamera.Lerp(ld, canSkipLerp);

                if (ld.IsDone)
                {
                    if (GodModeCamera)
                        GodModeCamera.mode = Singleton_CameraOperatorConfigurable.Mode.FPS;
                }
            }

            public void Portion(LerpData ld)
            {
                if (GodModeCamera)
                    GodModeCamera.Portion(ld);
            }
            #endregion

            #region Encode & Decode
            public void DecodeTag(string key, CfgData data)
            {
                switch (key)
                {
                    case "gm":
                        if (GodModeCamera)
                        {
                            GodModeCamera.DecodeInternal(data);
                        }
                        break;
                }
            }

            public CfgEncoder Encode()
            {
                var cody = new CfgEncoder()
                    .Add("gm", GodModeCamera)
                     ;

                return cody;
            }

            public void DecodeInternal(CfgData data)
            {
                new CfgDecoder(data).DecodeTagsFor(this);

                if (GodModeCamera)
                    GodModeCamera.mode = Singleton_CameraOperatorConfigurable.Mode.LERP;

                Mgmt.RequestLerps("Scene Decoder");
            }
            #endregion

            #region Inspector
            public void InspectInList(ref int edited, int ind)
            {
                if (Icon.Enter.Click() | ("Scene".PegiLabel().ClickLabel()))
                    edited = ind;
            }

            private readonly pegi.EnterExitContext _context = new();

            void IPEGI.Inspect()
            {
                using (_context.StartContext())
                {
                    pegi.Nl();

                    if (!_context.IsAnyEntered)
                    {
                        if (GodModeCamera && GodModeCamera.mode == Singleton_CameraOperatorConfigurable.Mode.STATIC && "Edit Camera".PegiLabel().Click().Nl())
                            GodModeCamera.mode = Singleton_CameraOperatorConfigurable.Mode.FPS;
                    }

                    if ("Primitives".PegiLabel().IsConditionally_Entered(Primitives).Nl())
                    {
                        Primitives.Nested_Inspect();
                    }
                }
            }

            public override string ToString() => "RTX Scene Manager";

            public string NeedAttention()
            {
                if (Application.isPlaying && GodModeCamera.TryGetAttentionMessage(out var msg))
                    return msg;

                if (TracingPrimitives.TryGetAttentionMessage(out msg))
                    return msg;

                if (UiScreenSpaceOutput.TryGetAttentionMessage(out msg))
                    return msg;

                if (TracingToCameraSource.TryGetAttentionMessage(out msg))
                    return msg;

                return null;
            }

            #endregion

            protected Singleton_EnvironmentElementsManager Primitives => Singleton.Get<Singleton_EnvironmentElementsManager>();

           
        }
    }
}
