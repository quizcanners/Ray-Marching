using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;


namespace QuizCanners.RayTracing
{

    [Serializable]

    public class RayRandering_BuffersManager : IPEGI, IPEGI_ListInspect, INeedAttention
    {
       
        [Header("PROCESS CONTROLLERS")]
        private readonly ShaderProperty.FloatValue RAY_TRACE_TRANSPARENCY = new ShaderProperty.FloatValue("_RayTraceTransparency");
        private readonly ShaderProperty.ShaderKeyword MOTION_TRACING = new ShaderProperty.ShaderKeyword("RT_MOTION_TRACING");
        private readonly ShaderProperty.ShaderKeyword DENOISING = new ShaderProperty.ShaderKeyword("RT_DENOISING");
        private readonly ShaderProperty.TextureValue PATH_TRACING_SOURCE_BUFFER = new ShaderProperty.TextureValue("_RayTracing_SourceBuffer", set_ScreenFillAspect: true);
        private readonly ShaderProperty.TextureValue PATH_TRACING_TARGET_BUFFER = new ShaderProperty.TextureValue("_RayTracing_TargetBuffer", set_ScreenFillAspect: true);

       // [SerializeField] private VolumeTracingBaker _volumeTracingBaker;
        [SerializeField] private RenderTexture[] _twoBuffers;
        [NonSerialized] private bool _firstIsSourceBuffer;

        private RenderTexture SourceBuffer => _firstIsSourceBuffer ? _twoBuffers[0] : _twoBuffers[1];
        private RenderTexture TargetBuffer => _firstIsSourceBuffer ? _twoBuffers[1] : _twoBuffers[0];
        protected RayRenderingManager Mgmt => RayRenderingManager.instance;

        public void OnSwap(out RenderTexture targetBuff)
        {
            _firstIsSourceBuffer = !_firstIsSourceBuffer;

            targetBuff = TargetBuffer;

            PATH_TRACING_SOURCE_BUFFER.GlobalValue = SourceBuffer;
            PATH_TRACING_TARGET_BUFFER.GlobalValue = targetBuff;

        }

        public void ManagedUpdate(float stableFrames) 
        {
            RAY_TRACE_TRANSPARENCY.GlobalValue = stableFrames < 2 ? 1f : Mathf.Clamp(2f / stableFrames, 0.001f, 0.5f);
            DENOISING.Enabled = stableFrames < 16;//(_stopUpdatingAfter * 0.25f);
            MOTION_TRACING.Enabled = stableFrames < 2;
        }

        #region Inspector
        public void Inspect()
        {
            pegi.nl();
            "Buffers".edit_Array(ref _twoBuffers).nl();
        }

        public void InspectInList(ref int edited, int ind)
        {
            if (icon.Enter.Click())
                edited = ind;

            if (!this.isAttentionWrite())
            {
                if ("Buffers MGMT".ClickLabel())
                    edited = ind;
            }
            
            
        }

        public string NeedAttention()
        {
            if (_twoBuffers.IsNullOrEmpty())
                return "No Buffers";

            if (_twoBuffers.Length != 2)
                return "Incorrect Buffers count";

            for (int i = 0; i < 2; i++)
                if (!_twoBuffers[i])
                    return "Buffer {0} is Null".F(i);

            return null;
        }

        #endregion
    }
}
