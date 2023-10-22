using PainterTool;
using UnityEngine;
using QuizCanners.Utils;
using QuizCanners.Inspect;
using QuizCanners.Lerp;

namespace QuizCanners.RayTracing
{
    public partial class Singleton_VolumeTracingBaker : Singleton.BehaniourBase, IPEGI, IPEGI_Handles
    {
        [SerializeField] private LogicWrappers.CountDownFromMax framesToBake = new(300);

        [SerializeField] internal C_VolumeTexture volume;
        [SerializeField] internal CubeMapped cubeMapped;
        [SerializeField] protected Shader bakingShader;
        [SerializeField] protected Shader offsetShader;
        [SerializeField] protected Shader smoothingShader;
       

        private readonly OnDemandRenderTexture.DoubleBuffer _doubleBuffer = new("Baking Volume", size: 1024, precision: OnDemandRenderTexture.PrecisionType.Half);
        private readonly ShaderProperty.Feature Qc_OffsetRGBA = new("Qc_OffsetRGBA");

        //  [NonSerialized] private readonly ShaderProperty.FloatValue SMOOTHING_BAKING_TRANSPARENCY = new("Qc_SmoothingBakingTransparency");

        private bool VolumeActive;

        private readonly Gate.DirtyVersion _bakedToSmoothedBufferDirtyVersion = new();
        private readonly Gate.Vector4Value _bakedPositionAndSize = new();
        private readonly Gate.Vector4Value _bakedslicesInShader = new();
        private readonly Gate.Frame _renderFrameGate = new();
     //   private readonly Gate.Float _volumeHeight = new();

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

        public int PositionVersion;

        private bool _positioNManagedExternally;

        public bool PositionManagedExternally 
        {
            get => _positioNManagedExternally;
            set 
            {
                if (_positioNManagedExternally == value)
                    return;

                _positioNManagedExternally = value;
                volume.DiscretePosition = value;

                if (!value)
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

        /*
        public ShaderProperty.VectorValue SHADER_OFFSET_BLIT
        {
            get
            {
                if (_positionOffset != null)
                    return _positionOffset;

                _positionOffset = new ShaderProperty.VectorValue(volume.name + "VOLUME_POSITION_OFFSET");

                return _positionOffset;
            }
        }
        */

        public bool TryChangeOffset()
        {
            if (volume && _bakedPositionAndSize.ValueIsDefined)
            {

                var newSlices = volume.GetSlices4Shader();
                var newPosition = volume.GetPositionAndSizeForShader();

                if ( _bakedslicesInShader.CurrentValue != newSlices
                    || _bakedPositionAndSize.CurrentValue != newPosition)
                {

                    PositionVersion++;

                    if (!volume.IsVisible || (Vector3.Distance(newPosition.XYZ(), _bakedPositionAndSize.CurrentValue.XYZ()) > volume.TextureWidth * volume.size)) 
                    {
                        ClearBake(eraseResult: true);
                        return true;
                    }

                    UpdatePreviousShaderValues();

                    void UpdatePreviousShaderValues()
                    {
                        PositionAndScaleProperty_Previous.SetGlobal(_bakedPositionAndSize.CurrentValue);
                        SlicesShadeProperty_Previous.SetGlobal(_bakedslicesInShader.CurrentValue);

                        //Debug.Log("Offsetting from " + _bakedPositionAndSize.CurrentValue + " to " + newPosition);

                        _bakedslicesInShader.TryChange(newSlices);
                        _bakedPositionAndSize.TryChange(newPosition);
                    }


                    // SHADER_OFFSET_BLIT.GlobalValue = diff.ToVector4(volume.size);

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
                        
                      //  SHADER_OFFSET_BLIT.GlobalValue = Vector3.zero.ToVector4(volume.size);

                       // volume.UpdateShaderVariables();
                        
                        // _positionToShaderVersion.IsDirty = true;

                        return true;
                    
                }
            }

            return false;
        }

        public void Paint(RenderTexture source, RenderTexture target, Shader bufferBlitter)
        {
            if (target && bufferBlitter)
            {
                _renderFrameGate.TryEnter();
                RenderTextureBuffersManager.BlitGL(source, target, material.Get(bufferBlitter));
            }
        }

        public void RestartBaker() => framesToBake.Restart();

        private void ClearDoubleBuffer() 
        {
            if (_doubleBuffer.Target)
            {
                RenderTextureBuffersManager.Blit(Color.clear, _doubleBuffer.Target);
            }
        }

        public void ClearBake(bool eraseResult = true) 
        {
           // Debug.Log("Clearing Bake");

            cubeMapped.Invalidate(this);
            ClearDoubleBuffer();

            if (eraseResult && volume.Texture)
            {
                var asRt = volume.Texture as RenderTexture;
                RenderTextureBuffersManager.Blit(Color.clear, asRt);
            }

            _bakedPositionAndSize.TryChange(volume.GetPositionAndSizeForShader());
            _bakedslicesInShader.TryChange(volume.GetSlices4Shader());
           // _volumeHeight.TryChange(volume.Height);
            RestartBaker();
            volume.UpdateShaderVariables();
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
            _doubleBuffer.Clear();
        }

        public void LateUpdate()
        {
            if (_sceneConfigsVersion.TryChange(VolumeTracing.Version)) 
            {
                Inst_RtxVolumeSettings last = VolumeTracing.Stack.TryGetLast();

                VolumeActive = last;

                if (last) 
                {
                    C_VolumeTexture.VOLUME_VISIBILITY.GlobalValue = 1;

                    if (!PositionManagedExternally)
                    {
                        transform.position = last.transform.position;
                    }

                    volume.Set(heightSlices: last.hSlices, size: last.Size);
                } 
            }

            if (!VolumeActive)
            {
                C_VolumeTexture.VOLUME_VISIBILITY.GlobalValue = QcLerp.LerpBySpeed(C_VolumeTexture.VOLUME_VISIBILITY.GlobalValue, 0, 1, unscaledTime: true);
                return;
            }

            if (_volumeCfgVersion.TryChange(volume.Dirty.ShaderData.Version))
            {
                ClearBake();
            }

            if (volume)
                volume.ManagedExternally = true;

            if (TryChangeOffset())
            {
                cubeMapped.UpdateVisibility();
                return;
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
                if (_bakedToSmoothedBufferDirtyVersion.TryClear(versionDifference: 8))
                {
                    if (!volume)
                    {
                        QcLog.ChillLogger.LogErrorOnce(()=> "{0} didn't find a Volume".F(name), key: "vtmNoRt", gameObject);
                        return true;
                    }

                    RenderTexture rt = volume.GetOrCreate() as RenderTexture;
                    if (!rt)
                    {
                        QcLog.ChillLogger.LogErrorOnce(()=> "Volume didn't provide a RenderTexture".F(gameObject.name), key: "vshart", gameObject);
                        return true;
                    }

                    _doubleBuffer.BlitTargetWithPreviousAndSwap(ref rt, smoothingShader);
                    volume.Texture = rt;

                    return true;
                }

                if (!framesToBake.IsFinished)
                {
                    framesToBake.RemoveOne();
                    Paint(null, _doubleBuffer.Target, bakingShader);
                    _bakedToSmoothedBufferDirtyVersion.IsDirty = true;
                    return true;
                }

                return false;
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

                InspectShader("Bakign Shader", ref bakingShader);
                InspectShader("Displacement", ref offsetShader);
                InspectShader("Smoothing Shader", ref smoothingShader);

                static void InspectShader(string role, ref Shader shader)
                        => role.PegiLabel(90).Edit(ref shader).Nl();
                break;

                case BAKING:
                    var baking = enabled;
                    if ("Bake {0}".F(framesToBake).PegiLabel().ToggleIcon(ref baking))
                        enabled = baking;
                    pegi.Nl();

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

                    if (Application.isPlaying)
                    {
                        "Clear Bake".PegiLabel().Click(()=> ClearBake(eraseResult: true));
                        Icon.Refresh.Click(RestartBaker);
                        pegi.Nl();
                    }

                    material.Nested_Inspect().Nl();
                break;
            }

            "Test Content".PegiLabel().Nl();
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