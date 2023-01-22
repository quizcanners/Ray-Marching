using PainterTool;
using UnityEngine;
using QuizCanners.Utils;
using QuizCanners.Inspect;
using System;

namespace QuizCanners.RayTracing
{
    public class Singleton_VolumeTracingBaker : Singleton.BehaniourBase, IPEGI, IPEGI_Handles
    {
        [SerializeField] private LogicWrappers.CountDownFromMax framesToBake = new(100);

        [SerializeField] internal C_VolumeTexture volume;
        [SerializeField] protected Shader bakingShader;
        [SerializeField] protected Shader offsetShader;
        [SerializeField] protected Shader smoothingShader;

        private readonly OnDemandRenderTexture.DoubleBuffer _doubleBuffer = new("Baking Volume", size: 1024, isFloat: true);
        [NonSerialized] private ShaderProperty.VectorValue _positionOffset;

        private readonly Gate.DirtyVersion _bakedToSmoothedBufferDirtyVersion = new();
        private readonly Gate.Vector4Value _bakedPositionAndSize = new();
        private readonly Gate.Frame _renderFrameGate = new();
        private readonly Gate.Float _volumeHeight = new();

        protected readonly MaterialInstancer.ByShader material = new();

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

        public bool TryChangeOffset()
        {
            if (volume)
            {
                var currentPosAndSize = volume.GetPositionAndSizeForShader();
                var previousPosAndSize = _bakedPositionAndSize.CurrentValue;

                float newSize = currentPosAndSize.w;

                if (_volumeHeight.TryChange(volume.Height) | (newSize != previousPosAndSize.w)) 
                {
                    ClearBake();
                    return true;
                }

                if (_bakedPositionAndSize.TryChange(currentPosAndSize))
                {
                    var diff = currentPosAndSize.XYZ() - previousPosAndSize.XYZ();

                    if (diff.magnitude > 0)
                    {
                        SHADER_OFFSET_BLIT.GlobalValue = diff.ToVector4(volume.size);
                        BakeNewAreas();
                       
                        OffsetSmoothedBaking();
                        _doubleBuffer.BlitToTarget(offsetShader);

                        void OffsetSmoothedBaking()
                        {
                            RenderTexture rt = volume.Texture as RenderTexture;
                            if (rt)
                            {
                                _doubleBuffer.ReuseAndSwapPrevious(ref rt, offsetShader);
                                volume.Texture = rt;
                            }
                        }
                        
                        SHADER_OFFSET_BLIT.GlobalValue = Vector3.zero.ToVector4(volume.size);

                        volume.UpdateShaderVariables();
                        
                        // _positionToShaderVersion.IsDirty = true;

                        return true;
                    }
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

        public void BakeNewAreas() => framesToBake.Restart();

        public void ClearBake() 
        {
            RenderTextureBuffersManager.Blit(Color.clear, _doubleBuffer.Target);
            _bakedPositionAndSize.TryChange(volume.GetPositionAndSizeForShader());
            _volumeHeight.TryChange(volume.Height);
            BakeNewAreas();
            
        }

        public void LateUpdate()
        {
            if (volume)
                volume.enabled = false;

            if (TryChangeOffset())
                return;

            if (_bakedToSmoothedBufferDirtyVersion.TryClear(versionDifference: 5)) 
            {
                _bakedToSmoothedBufferDirtyVersion.TryClear();

                if (volume && volume.Texture) 
                {
                    RenderTexture rt = volume.Texture as RenderTexture;
                    if (rt)
                    {
                        _doubleBuffer.BlitTargetWithPreviousAndSwap(ref rt, smoothingShader);
                        volume.Texture = rt;

                        //Paint(_doubleBuffer.Target, rt, smoothingShader);

                       
                    }
                    else 
                    {
                        QcLog.ChillLogger.LogErrorOnce("Volume should have a RenderTexture".F(gameObject.name), key: "vshart", gameObject);
                    }
                } else 
                {
                    QcLog.ChillLogger.LogErrorOnce("{0} didn't find a Texture on Volume".F(name), key: "vtmNoRt", gameObject);
                }
            }
            else if (!framesToBake.IsFinished)
            {
                framesToBake.RemoveOne();
                Paint(null, _doubleBuffer.Target, bakingShader);
                _bakedToSmoothedBufferDirtyVersion.IsDirty = true;
            }
            
        }

        #region Inspector
        [SerializeField] protected pegi.EnterExitContext context = new();
        [SerializeField] protected string _editorTab;

        public override void Inspect()
        {
            const string SHADERS = "Shaders";
            const string BAKING = "Baking";
            const string DEBUG = "Debug";

            pegi.Tabs(ref _editorTab, new string[] { BAKING, SHADERS, DEBUG });
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

                case DEBUG:

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
                        "Clear Bake".PegiLabel().Click(ClearBake);
                        Icon.Refresh.Click(BakeNewAreas);
                        pegi.Nl();
                    }

                    material.Nested_Inspect().Nl();

                    break;
            }

            "Test Content".PegiLabel().Nl();
            
        }

        public void OnSceneDraw()
        {
            pegi.Handle.Label(framesToBake.GetNameForInspector(), transform. position);
        }
        #endregion

        void Reset() 
        {
            volume = GetComponent<C_VolumeTexture>();
        }
    }

    [PEGI_Inspector_Override(typeof(Singleton_VolumeTracingBaker))] internal class Singleton_VolumeTracingBakerDrawer : PEGI_Inspector_Override   {  }
}