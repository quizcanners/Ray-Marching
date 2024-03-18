using QuizCanners.Inspect;
using QuizCanners.Migration;
using QuizCanners.Utils;
using QuizCanners.VolumeBakedRendering;
using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace QuizCanners.SpecialEffects
{
    [ExecuteAlways]
    public class Singleton_LayeredVolumetricFog : Singleton.BehaniourBase, IPEGI, IPEGI_ListInspect, ICfg
    {
        [SerializeField] private Camera _camera;
        [SerializeField] private ShaderAndMaterial _pass_1_Depth;
        [SerializeField] private ShaderAndMaterial _pass_2_Baking;
        [SerializeField] private ShaderAndMaterial _pass_3_Denoising;
        [SerializeField] private ShaderAndMaterial _pass_4_AppendingToFar;
        [SerializeField] private ShaderAndMaterial _pass_5_ToScreen;

        [Header("Options")]
        [SerializeField] private bool _smoothResult;


        [Serializable]
        private class ShaderAndMaterial 
        {
            public Shader Shader;
            [SerializeField] private Material _optionalMaterial;

            private Material _runtimeMaterial;

            public Material Material 
            {
                get 
                {
                    if (_runtimeMaterial)
                        return _runtimeMaterial;

                    if (_optionalMaterial)
                        return _optionalMaterial;

                    _runtimeMaterial = new Material(Shader);
                    
                    return _runtimeMaterial;
                }
            }

        }

        private int _debugRefreshCounter = 0;

        const int LAYERS_GRID = 4;
      //  const int LAYERS_COUNT = LAYERS_GRID * LAYERS_GRID;
        const int TEX_RESOLUTION = 1024;
        const int DEPTH_TEX_SIZE = TEX_RESOLUTION / LAYERS_GRID;

        private readonly OnDemandRenderTexture.Single _bakeTarget = new("Baked", TEX_RESOLUTION, isFloat: false, isColor: false);
        private readonly OnDemandRenderTexture.Single _denoiseTarget = new("Denoised", TEX_RESOLUTION, isFloat: false, isColor: false   );
        private readonly OnDemandRenderTexture.Single _publishedTexture = new("Published", TEX_RESOLUTION, isFloat: false, isColor: false);
        private readonly OnDemandRenderTexture.Single _depthMax = new("Max Depth", DEPTH_TEX_SIZE, isFloat: true, singleChannel: true, isColor: false);

        private readonly ShaderProperty.TextureValue _downscaledDepth = new("qc_DepthMax");
        private readonly ShaderProperty.TextureValue _finalResult = new("qc_FogLayers");

        private CommandBuffer cmdBakeBuffer;
        private CommandBuffer cmdDrawBuffer;

        private readonly Gate.Bool _initialized = new();

        private readonly LayeredFogSettings _settings = new();

        const CameraEvent BEFORE_OPAQUE = CameraEvent.BeforeForwardOpaque;
        const CameraEvent AFTER_SKY_BOX = CameraEvent.AfterSkybox;

        void Refresh() 
        {
            Clear();

            _initialized.TryChange(true);

            _debugRefreshCounter++;

            cmdBakeBuffer ??= new CommandBuffer { name = "Bake Fog Command" };

            cmdDrawBuffer ??= new CommandBuffer { name = "Apply Fog" };

            RenderTexture depthRt = _depthMax.GetRenderTexture();
            _downscaledDepth.GlobalValue = depthRt;

            var final = _publishedTexture.GetRenderTexture();
            _finalResult.GlobalValue = final;

            cmdBakeBuffer.Clear();
            cmdBakeBuffer.Blit(null, depthRt, _pass_1_Depth.Material);

            var resultToAppend = _bakeTarget.GetRenderTexture();

            cmdBakeBuffer.Blit(null, resultToAppend, _pass_2_Baking.Material);

            if (_smoothResult)
            {
                cmdBakeBuffer.Blit(resultToAppend, _denoiseTarget.GetRenderTexture(), _pass_3_Denoising.Material);
                resultToAppend = _denoiseTarget.GetRenderTexture();
            }

            cmdBakeBuffer.Blit(resultToAppend, final, _pass_4_AppendingToFar.Material);

            _camera.AddCommandBuffer(BEFORE_OPAQUE, cmdBakeBuffer);

            cmdDrawBuffer.Clear();
            cmdDrawBuffer.Blit(final, BuiltinRenderTextureType.CameraTarget, _pass_5_ToScreen.Material);
            _camera.AddCommandBuffer(AFTER_SKY_BOX, cmdDrawBuffer);

        }

        void LateUpdate() 
        {
            if (!Application.isPlaying)
                return;

            bool shouldRender = _settings.Visibility > 0.01;

            if (!shouldRender) 
            {
                Clear();
                return;
            }

            SetMatrix();

            if (!_initialized.CurrentValue)
                Refresh();

         
        }

        private readonly ShaderProperty.MatrixValue _mainCamMatrix = new("qc_MATRIX_VP");
        private readonly ShaderProperty.MatrixValue _mainCamMatrixInverted = new("qc_MATRIX_I_VP");

        private void SetMatrix() 
        {
            var cameraProjectionMatrix = _camera.projectionMatrix;
     
            var matrix_V = GL.GetGPUProjectionMatrix(cameraProjectionMatrix, true);
            var maitix_P = _camera.worldToCameraMatrix;
            var CurrentVPMatrix = matrix_V * maitix_P;

            _mainCamMatrix.SetGlobal(CurrentVPMatrix);
            _mainCamMatrixInverted.SetGlobal(CurrentVPMatrix.inverse);
        }

        protected override void OnAfterEnable()
        {
            base.OnAfterEnable();
            if (Application.isPlaying)
                Refresh();
        }

        protected override void OnBeforeOnDisableOrEnterPlayMode(bool afterEnableCalled)
        {
            base.OnBeforeOnDisableOrEnterPlayMode(afterEnableCalled);

            if (Application.isPlaying)
                Clear();
        }

        void Clear() 
        {
            if (!_initialized.CurrentValue)
                return;

            _initialized.TryChange(false);

            _camera.RemoveCommandBuffer(BEFORE_OPAQUE, cmdBakeBuffer);
            _camera.RemoveCommandBuffer(AFTER_SKY_BOX, cmdDrawBuffer);
            cmdBakeBuffer.Dispose();
            cmdBakeBuffer = null;

            cmdDrawBuffer.Dispose();
            cmdDrawBuffer = null;
        }

        void Reset() 
        {
            _camera = GetComponent<Camera>();
        }

        #region Inspector
        private readonly pegi.EnterExitContext _context = new();

        public override void Inspect()
        {
            var changes = pegi.ChangeTrackStart();

            if (!_camera)
                pegi.Edit_Property(() => _camera, this);

            if (Application.isPlaying)
                "v. {0}".F(_debugRefreshCounter).PegiLabel().Write();

            pegi.Nl();

            using (_context.StartContext())
            {
                if (!_context.IsAnyEntered)
                {
                    "Smooth Result".PegiLabel().ToggleIcon(ref _smoothResult).Nl();
                    _settings.Nested_Inspect().Nl();
                }

                _bakeTarget.Enter_Inspect().Nl();
                _publishedTexture.Enter_Inspect().Nl();
                _depthMax.Enter_Inspect().Nl();
            }

            if (changes)
                Refresh();
        }

        public override void InspectInList(ref int edited, int ind)
        {
            _settings.InspectInList_Nested(ref edited, ind);
        }
        #endregion


        public CfgEncoder Encode() => new CfgEncoder().Add("params", _settings);

        public void DecodeTag(string key, CfgData data)
        {
            switch (key) 
            {
                case "params": _settings.Decode(data); break;
            }
        }

        private class LayeredFogSettings : ICfg, IPEGI_ListInspect, IPEGI
        {
            private readonly ShaderProperty.FloatFeature _visibility = new(name: "qc_LayeredFog_Alpha", featureDirective: "qc_LAYARED_FOG");
            private readonly ShaderProperty.FloatValue _distance = new(name: "qc_LayeredFog_Distance");

            public float Visibility
            {
                get => _visibility.latestValue;
                set => _visibility.GlobalValue = value;
            }

            public float Distance
            {
                get => _distance.latestValue;
                set => _distance.GlobalValue = value;
            }

            public void DecodeTag(string key, CfgData data)
            {
                switch (key) 
                {
                    case "vis": _visibility.Decode(data); break;
                    case "dist": _distance.Decode(data); break;
                }
            }

            public CfgEncoder Encode() => new CfgEncoder()
                .Add("vis", _visibility)
                .Add("dist", _distance);

            public void Inspect()
            {
                _visibility.Nested_Inspect().Nl();
                _distance.Nested_Inspect().Nl();
            }

            public void InspectInList(ref int edited, int index)
            {
                var vis = Visibility;

                "Layered Fog".PegiLabel(90).Edit_01(ref vis).OnChanged(()=> Visibility = vis);

                if (vis>0 && Distance < 1) 
                {
                    Icon.Warning.Draw("Distance is too small");
                    "Set Distance 500".PegiLabel().Click(()=> Distance = 500);
                }

                if (Icon.Enter.Click())
                    edited = index;
            }
        }

    }

    [PEGI_Inspector_Override(typeof(Singleton_LayeredVolumetricFog))]
    internal class Singleton_LayeredVolumetricFogDrawer : PEGI_Inspector_Override { }
}