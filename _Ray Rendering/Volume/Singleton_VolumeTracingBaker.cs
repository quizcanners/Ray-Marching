using PainterTool;
using UnityEngine;
using QuizCanners.Utils;
using QuizCanners.Inspect;
using QuizCanners.Lerp;

namespace QuizCanners.VolumeBakedRendering
{
    [ExecuteAlways]
    public partial class Singleton_VolumeTracingBaker : Singleton.BehaniourBase, IPEGI, IPEGI_Handles
    {
        [SerializeField] private LogicWrappers.CountDownFromMax framesToBake = new(300);

        [SerializeField] internal C_VolumeTexture volume;
        [SerializeField] internal CubeMapped cubeMapped;
        [SerializeField] protected Shader bakingShader;
        [SerializeField] protected Shader offsetShader;
        [SerializeField] protected Shader smoothingShader;
        [SerializeField] protected Shader postEffectsShader;

        private readonly OnDemandRenderTexture.DoubleBuffer _doubleBuffer = new("Baking Volume", size: 1024, precision: OnDemandRenderTexture.PrecisionType.Half, clearOnCreate: true, isColor: false);
        private readonly ShaderProperty.Feature Qc_OffsetRGBA = new("Qc_OffsetRGBA");
      

        private bool VolumeActive;

        // Dynamic Volume Transform
        public bool IsDymanicVolume;
        private readonly ShaderProperty.MatrixValue DYMANIC_VOLUME_WTL_MATRIX = new(name: "qc_RtxVolumeWorldToLocal");
        private readonly ShaderProperty.MatrixValue DYMANIC_VOLUME_LTW_MATRIX = new(name: "qc_RtxVolumeLocalToWorld");
        private readonly ShaderProperty.FloatValue USE_DYNAMIC_VOLUME = new(name: "qc_USE_DYNAMIC_RTX_VOLUME");

        // Baking
        private readonly Gate.DirtyVersion _bakedToSmoothedBufferDirtyVersion = new();
        private readonly Gate.Vector4Value _bakedPositionAndSize = new();
        private readonly Gate.Vector4Value _bakedslicesInShader = new();
        private readonly Gate.Frame _renderFrameGate = new();

        protected readonly MaterialInstancer.ByShader material = new();

        private readonly Gate.Integer _sceneConfigsVersion = new();
        private readonly Gate.Integer _volumeCfgVersion = new();

        private ShaderProperty.VectorValue _slicesInShader_Previous;
        private ShaderProperty.VectorValue _positionNsizeInShader_Previous;

        private ShaderProperty.VectorValue SlicesShadeProperty_Previous
        {
            get
            {
                if (_slicesInShader_Previous != null)
                    return _slicesInShader_Previous;

                _slicesInShader_Previous = new ShaderProperty.VectorValue(C_VolumeTexture.NAME + "VOLUME_H_SLICES_PREVIOUS");

                return _slicesInShader_Previous;
            }
        }
        private ShaderProperty.VectorValue PositionAndScaleProperty_Previous
        {
            get
            {
                if (_positionNsizeInShader_Previous != null)
                    return _positionNsizeInShader_Previous;

                _positionNsizeInShader_Previous = new ShaderProperty.VectorValue(C_VolumeTexture.NAME + "VOLUME_POSITION_N_SIZE_PREVIOUS");

                return _positionNsizeInShader_Previous;
            }
        }


        private MainBakingStage _mainBakingStage;

        private enum MainBakingStage { Tracing, FinalSmoothing, PostEffect, Finished }

        private Gate.GateGenericValue<VolumeTracing.MotionMode> _positionManagement = new();

        public VolumeTracing.MotionMode PositionUpdateMode 
        {
            get => _positionManagement.CurrentValue;
            set 
            {
                if (!_positionManagement.TryChange(value))
                    return;

                volume.DiscretePosition = value == VolumeTracing.MotionMode.DiscreteSteps;

                Singleton.Get<Singleton_QcRendering>().SetBakingDirty("Position update mode changed", invalidateResult: true);

                if (volume.DiscretePosition)
                    return;
                
                Inst_RtxVolumeSettings last = VolumeTracing.Stack.TryGetLast();

                if (!last)
                    return;
                
                transform.position = last.transform.position;
            }
        }


        public Vector3 VolumeCenter
        {
            get => volume.VolumeCenter;
            set => volume.VolumeCenter = value;
        }

        public bool TryChangeOffset()
        {
            if (volume && _bakedPositionAndSize.ValueIsDefined)
            {
                var newSlices = volume.GetSlices4Shader();
                var newPosition = volume.GetPositionAndSizeForShader();

                if ( _bakedslicesInShader.CurrentValue != newSlices
                    || _bakedPositionAndSize.CurrentValue != newPosition)
                {

                    if (!TracedVolume.HasValidData || (Vector3.Distance(newPosition.XYZ(), _bakedPositionAndSize.CurrentValue.XYZ()) > volume.SliceWidth * volume.size)) 
                    {
                        ClearBake(eraseResult: true);
                        return true;
                    }

                    UpdatePreviousShaderValues();

                    void UpdatePreviousShaderValues()
                    {
                        PositionAndScaleProperty_Previous.SetGlobal(_bakedPositionAndSize.CurrentValue);
                        SlicesShadeProperty_Previous.SetGlobal(_bakedslicesInShader.CurrentValue);
                        _bakedslicesInShader.TryChange(newSlices);
                        _bakedPositionAndSize.TryChange(newPosition);
                    }

                    RestartBaker();

                    volume.UpdateShaderVariables();

                    RenderTexture rt = volume.GetOrCreate() as RenderTexture;
                    if (rt)
                    {
                        volume.Texture = _doubleBuffer.RenderFromAndSwapIn(rt, offsetShader);
                    }

                    cubeMapped.OffsetResults(this);
                    Qc_OffsetRGBA.Enabled = true;
                    _doubleBuffer.Blit(offsetShader);
                    Qc_OffsetRGBA.Enabled = false;
                    return true;
                }
            }

            return false;
        }

        public void Blit(RenderTexture source, RenderTexture target, Shader bufferBlitter)
        {
            if (target && bufferBlitter)
            {
                _renderFrameGate.TryEnter();
                RenderTextureBuffersManager.BlitGL(source, target, material.Get(bufferBlitter));
            }
        }

        public void RestartBaker()
        {
            framesToBake.Restart();
            _mainBakingStage = MainBakingStage.Tracing;
        }
        private void ClearDoubleBuffer() 
        {
            if (_doubleBuffer.Target)
            {
                RenderTextureBuffersManager.Blit(Color.clear, _doubleBuffer.Target);
            }
        }

        public void ClearBake(bool eraseResult = true) 
        {
            cubeMapped.Invalidate(this);
            ClearDoubleBuffer();

            if (eraseResult && volume.Texture)
            {
                var asRt = volume.Texture as RenderTexture;
                RenderTextureBuffersManager.Blit(Color.clear, asRt);
            }

            _bakedPositionAndSize.TryChange(volume.GetPositionAndSizeForShader());
            _bakedslicesInShader.TryChange(volume.GetSlices4Shader());
            RestartBaker();
            volume.UpdateShaderVariables();
            TracedVolume.HasValidData = false;
        }

        protected override void OnAfterEnable()
        {
            base.OnAfterEnable();
            cubeMapped.ManagedOnEnable();
        }

        protected override void OnBeforeOnDisableOrEnterPlayMode(bool afterEnableCalled)
        {
            base.OnBeforeOnDisableOrEnterPlayMode(afterEnableCalled);
            cubeMapped.ManagedOnDisable();
            _doubleBuffer.Release();
        }

        public void LateUpdate()
        {
            UpdateDynamicRootIfNeeded();

            if (QcScenes.IsAnyLoading)
                return;

            if (!Singleton.GetValue<Singleton_TracingPrimitivesController, bool>(s => s.IsReady, defaultValue: false))
                return;

            if (_sceneConfigsVersion.TryChange(VolumeTracing.ActiveConfigVersion)) 
            {
                Inst_RtxVolumeSettings last = VolumeTracing.Stack.TryGetLast();

                VolumeActive = last;

                if (last) 
                {
                    if (PositionUpdateMode == VolumeTracing.MotionMode.Static)
                    {
                        transform.position = last.transform.position;
                    }

                    volume.TryChange(heightSlices: last.hSlices, size: last.Size);
                } 
            }

            if (!VolumeActive)
            {
                TracedVolume.VOLUME_VISIBILITY.GlobalValue = QcLerp.LerpBySpeed(TracedVolume.VOLUME_VISIBILITY.GlobalValue, 0, 1, unscaledTime: true);
                return;
            }

            if (_volumeCfgVersion.TryChange(volume.Dirty.ShaderData.Version))
            {
                ClearBake();
                return;
            }

            if (volume)
                volume.ManagedExternally = true;

            if (Singleton.Get<Singleton_QcRendering>().sdfVolume.Dirty)
                return;

            void UpdateDynamicRootIfNeeded() 
            {
                if (PositionUpdateMode != VolumeTracing.MotionMode.DynaimicRoot)
                    return;

                Inst_RtxVolumeSettings last = VolumeTracing.Stack.TryGetLast();
                if (!last)
                    return;

                transform.position = last.transform.position;
                DYMANIC_VOLUME_WTL_MATRIX.GlobalValue = last.transform.worldToLocalMatrix;
                DYMANIC_VOLUME_LTW_MATRIX.GlobalValue = last.transform.localToWorldMatrix;
                USE_DYNAMIC_VOLUME.GlobalValue = 1;
            }

            switch (PositionUpdateMode) 
            {
                case VolumeTracing.MotionMode.DynaimicRoot:

                    /*Inst_RtxVolumeSettings last = VolumeTracing.Stack.TryGetLast();
                    if (last)
                    {
                        transform.position = last.transform.position;
                        DYMANIC_VOLUME_WTL_MATRIX.GlobalValue = last.transform.worldToLocalMatrix;
                        DYMANIC_VOLUME_LTW_MATRIX.GlobalValue = last.transform.localToWorldMatrix;
                        USE_DYNAMIC_VOLUME.GlobalValue = 1;
                    }
                    */
                    break;
                default:
                    USE_DYNAMIC_VOLUME.GlobalValue = 0;

                    if (TryChangeOffset())
                    {
                        VolumeTracing.Version++;
                        cubeMapped.UpdateVisibility();
                        return;
                    }
                    break;
            }

            if (BakeMainVolume()) 
            {
                cubeMapped.UpdateVisibility();
                return;
            }

            cubeMapped.ManagedUpdate(this);

            return;


            bool BakeMainVolume()
            {
                if (_mainBakingStage == MainBakingStage.Finished)
                    return false;

                switch (_mainBakingStage) 
                {
                    case MainBakingStage.FinalSmoothing:
                        Smooth();
                        _mainBakingStage = MainBakingStage.PostEffect;
                        return true;
                    case MainBakingStage.PostEffect:

                        TracingPrimitives.s_postEffets.UpdateDataInGPU();
                        RenderTexture rt = volume.GetOrCreate() as RenderTexture;
                        _doubleBuffer.BlitTargetWithPreviousAndSwap(ref rt, postEffectsShader);
                        volume.Texture = rt;
                        _mainBakingStage = MainBakingStage.Finished;
                        return true;
                }

                if (_bakedToSmoothedBufferDirtyVersion.TryClear(versionDifference: 8))
                {
                    Smooth();
                    return true;
                }

                framesToBake.RemoveOne();
                Blit(null, _doubleBuffer.Target, bakingShader);
                _bakedToSmoothedBufferDirtyVersion.IsDirty = true;

                if (framesToBake.IsFinished)
                    _mainBakingStage = MainBakingStage.FinalSmoothing;
                
                return true;

                void Smooth()
                {
                    if (!volume)
                    {
                        QcLog.ChillLogger.LogErrorOnce(() => "{0} didn't find a Volume".F(name), key: "vtmNoRt", gameObject);
                        return;
                    }

                    RenderTexture rt = volume.GetOrCreate() as RenderTexture;
                    if (!rt)
                    {
                        QcLog.ChillLogger.LogErrorOnce(() => "Volume didn't provide a RenderTexture".F(gameObject.name), key: "vshart", gameObject);
                        return;
                    }

                    _doubleBuffer.BlitTargetWithPreviousAndSwap(ref rt, smoothingShader);
                    volume.Texture = rt;
                    TracedVolume.HasValidData = true;
                }
            }
        }

        public bool IsBaking() => !framesToBake.IsFinished || cubeMapped.Stage != CubeMapped.BakeStage.Finished;

        #region Inspector
        [SerializeField] protected pegi.EnterExitContext context = new();
        [SerializeField] protected string _editorTab;

        public override void Inspect()
        {
            const string SHADERS = "Shaders";
            const string BAKING = "Baking";
            const string CUBE_MAP = "Cube Map";
            const string DEBUG = "Debug";

            if (Application.isPlaying && !VolumeActive)
                "No Configs found. Volume is hidden".PegiLabel().WriteWarning().Nl();

            pegi.Tabs(ref _editorTab, new string[] { BAKING, SHADERS, CUBE_MAP, DEBUG });
            pegi.Nl();
            switch (_editorTab) 
            {
                case SHADERS:

                "Shaders".PegiLabel(pegi.Styles.HeaderText).Nl();

                InspectShader("Bakign", ref bakingShader);
                InspectShader("Displacement", ref offsetShader);
                InspectShader("Smoothing", ref smoothingShader);
                InspectShader("Post Effect", ref postEffectsShader);

                    static void InspectShader(string role, ref Shader shader)
                        => role.PegiLabel(90).Edit(ref shader).Nl();
                break;

                case BAKING:
                    var baking = enabled;
                    if ("Bake {0}".F(framesToBake).PegiLabel().ToggleIcon(ref baking))
                        enabled = baking;
                    pegi.Nl();

                    var mode = PositionUpdateMode;
                    "Movement mode".PegiLabel().Edit_Enum(ref mode).Nl(()=> PositionUpdateMode = mode);

                    pegi.FullWindow.DocumentationClickOpen("Second buffer needs to be same kind of RenderTexture as Texture");
                    pegi.Nl();

                    break;

                case CUBE_MAP:
                    cubeMapped.Inspect(this);
                    pegi.Nl();
                    break;
                case DEBUG:

                    "Pos and Size:".PegiLabel(pegi.Styles.BaldText).Nl();
                    _bakedPositionAndSize.Nested_Inspect().Nl();

                    _doubleBuffer.Nested_Inspect();

                    if (framesToBake.IsFinished)
                        "BAKE DONE".PegiLabel().Nl();
                    else
                    {
                        "Frames To Bake".PegiLabel().Nl();
                        pegi.Nested_Inspect(framesToBake).Nl();
                    }

                  
                    "Clear Bake".PegiLabel().Click(()=> ClearBake(eraseResult: true));
                    Icon.Refresh.Click(RestartBaker);
                    pegi.Nl();
                    

                    material.Nested_Inspect().Nl();
                break;
            }

           // "Test Content".PegiLabel().Nl();
        }

        public void OnSceneDraw()
        {
            pegi.Handle.Label(framesToBake.GetNameForInspector(), transform.position);
        }
        #endregion

        void Reset() 
        {
            volume = GetComponent<C_VolumeTexture>();
        }
    }

    [PEGI_Inspector_Override(typeof(Singleton_VolumeTracingBaker))] internal class Singleton_VolumeTracingBakerDrawer : PEGI_Inspector_Override   {  }
}