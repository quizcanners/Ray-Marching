using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using UnityEngine;


namespace QuizCanners.VolumeBakedRendering
{
    public static partial class QcRender
    {
        [Serializable]
        internal class BuffersManager : IPEGI, IPEGI_ListInspect, INeedAttention
        {

            [Header("PROCESS CONTROLLERS")]
            private readonly ShaderProperty.FloatValue RAY_TRACE_TRANSPARENCY = new("_RayTraceTransparency");
            private readonly ShaderProperty.Feature MOTION_TRACING = new("RT_MOTION_TRACING");
            private readonly ShaderProperty.Feature DENOISING = new("RT_DENOISING");
            private readonly ShaderProperty.Feature PROGRESSIVE_BUFFER = new("RT_PROGRESSIVE_BUFFER");
            private readonly ShaderProperty.TextureValue PATH_TRACING_SOURCE_BUFFER = new("_RayTracing_SourceBuffer", set_ScreenFillAspect: true);
            private readonly ShaderProperty.TextureValue PATH_TRACING_TARGET_BUFFER = new("_RayTracing_TargetBuffer", set_ScreenFillAspect: true);
            private readonly ShaderProperty.TextureValue PATH_TRACING_MARCHING_PROGRESSIVE = new("_RayTracing_MarchingProgressive", set_ScreenFillAspect: true);


            [NonSerialized] private RenderTexture[] _twoBuffers;
            [NonSerialized] private RenderTexture _marchingIntermadiateBuffer;
            [NonSerialized] private bool _firstIsSourceBuffer;


            public RenderTexture UseMarchingIntermadiateTexture() 
            {
                
                int targetWidth = Math.Max(8, (int)(Screen.width * 0.25f));
                int targetHeight = Math.Max(8, (int)(Screen.height * 0.25f));
                if (!_marchingIntermadiateBuffer || _marchingIntermadiateBuffer.width!= targetHeight || _marchingIntermadiateBuffer.height != targetHeight)
                {
                    if (_marchingIntermadiateBuffer)
                        UnityEngine.Object.Destroy(_marchingIntermadiateBuffer);

                    _marchingIntermadiateBuffer = new RenderTexture(width: targetWidth, height: targetHeight, depth: 0, RenderTextureFormat.ARGBFloat, mipCount: 0);
                }

                PATH_TRACING_MARCHING_PROGRESSIVE.GlobalValue = _marchingIntermadiateBuffer;
                PATH_TRACING_TARGET_BUFFER.GlobalValue = _marchingIntermadiateBuffer;
                PROGRESSIVE_BUFFER.Enabled = true;

                return _marchingIntermadiateBuffer;
            }

            private void CheckDoubleBuffer(out bool recreate) 
            {
                bool recreated = false;

                if (_twoBuffers.IsNullOrEmpty() || _twoBuffers.Length != 2 || !_twoBuffers[0])
                {
                    ClearAndRequest();
                }
                else
                {
                    var rt = _twoBuffers[0];
                    if (Screen.width != rt.width || Screen.height != rt.height)
                    {
                        ClearAndRequest();
                    }
                }
                     
                void ClearAndRequest() 
                {
                    if (_twoBuffers != null)
                    {
                        foreach (var t in _twoBuffers)
                        {
                            UnityEngine.Object.Destroy(t);
                        }
                    }

                    if (_twoBuffers == null || _twoBuffers.Length != 2)
                        _twoBuffers = new RenderTexture[2];

                    recreated = true;
                }

                if (recreated) 
                {
                    for (int i = 0; i < 2; i++)
                    {
                        _twoBuffers[i] = new RenderTexture(width: Screen.width, height: Screen.height, depth: 0, RenderTextureFormat.ARGBFloat, mipCount: 0);
                    }

                    Debug.Log("Buffers Recreated on resolution change");
                    Mgmt.SetBakingDirty(reason: "Texture Buffers Changed");
                }

                recreate = recreated;
            }

            private RenderTexture SourceBuffer
            {
                get
                {
                    CheckDoubleBuffer(out _); 
                    return _firstIsSourceBuffer ? _twoBuffers[0] : _twoBuffers[1];
                }
            }
            private RenderTexture TargetBuffer
            {
                get
                {
                    CheckDoubleBuffer(out _);
                    return _firstIsSourceBuffer ? _twoBuffers[1] : _twoBuffers[0];
                }
            }

            protected Singleton_QcRendering Mgmt => Singleton.Get<Singleton_QcRendering>(); //.instance;

            public void OnSwap(out RenderTexture targetBuff)
            {
                _firstIsSourceBuffer = !_firstIsSourceBuffer;

                targetBuff = TargetBuffer;

                PATH_TRACING_SOURCE_BUFFER.GlobalValue = SourceBuffer;
                PATH_TRACING_TARGET_BUFFER.GlobalValue = targetBuff;
                PROGRESSIVE_BUFFER.Enabled = false;
            }

            public void ManagedUpdate(float stableFrames)
            {
                if (Mgmt.TargetIsScreenBuffer)
                {
                    CheckDoubleBuffer(out bool recreated);
                    if (recreated)
                        Mgmt.SetBakingDirty();
                }

                RAY_TRACE_TRANSPARENCY.GlobalValue = stableFrames < 2 ? 1f 
                     //: Mgmt.Constants.TransparentFrames > stableFrames ? 1 
                     : Mathf.Clamp(2f / stableFrames, 0.001f, 0.5f);
                DENOISING.Enabled = stableFrames < 16;//(_stopUpdatingAfter * 0.25f);
                MOTION_TRACING.Enabled = stableFrames < 2;
            }

            #region Inspector
            void IPEGI.Inspect()
            {
                pegi.Nl();
                "Dynamic Buffers".PegiLabel().Edit_Array(ref _twoBuffers).Nl();
            }

            public void InspectInList(ref int edited, int ind)
            {
                if (!this.isAttentionWrite())
                {
                    "Buffers MGMT".PegiLabel().ClickEnter(ref edited, ind);
                }
            }

            public string NeedAttention()
            {
               /* if (_twoBuffers.IsNullOrEmpty())
                    return "No Buffers";

                if (_twoBuffers.Length != 2)
                    return "Incorrect Buffers count";

                for (int i = 0; i < 2; i++)
                    if (!_twoBuffers[i])
                        return "Buffer {0} is Null".F(i);*/

                return null;
            }

            #endregion
        }
    }
}
