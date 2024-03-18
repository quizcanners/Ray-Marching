using QuizCanners.Inspect;
using QuizCanners.Lerp;
using QuizCanners.Migration;
using System;
using UnityEngine;
 
namespace QuizCanners.Utils
{
    [AddComponentMenu(QcUtils.QUIZCANNERS + "/Camera Operator Configurable")]
    public class Singleton_CameraOperatorConfigurable : Singleton_CameraOperatorGodMode, ICfgCustom, ILinkedLerping
    {
        [SerializeField] private QcMath.DynamicRangeFloat _height = new(0.001f, 10, 0.2f);
        [SerializeField] private DepthTextureMode _depthTextureMode = DepthTextureMode.None;
        [SerializeField] private bool _overrideDepthTextureMode;

        private LinkedLerp.TransformLocalPosition _positionLerp;
        private LinkedLerp.TransformLocalRotation _rotationLerp;
        private readonly LinkedLerp.FloatValue _heightLerp = new(name: "Height");

        private readonly Gate.Frame _cameraControlsGate = new();
        private UnityEngine.Object _externalCameraController;

        public enum Mode { FPS = 0, STATIC = 1, LERP = 2 }
        public Mode mode;


        private bool IsControlledExternally => !_cameraControlsGate.IsFramesPassed(5);

        public void SetDepthTexture(DepthTextureMode mode, bool isOn) 
        {
            _overrideDepthTextureMode = true;
            if (isOn) 
            {
                _depthTextureMode |= mode;
            } else 
            {
                _depthTextureMode &= ~mode;
            }

            if (_depthTextureMode == DepthTextureMode.MotionVectors)
            {
                _depthTextureMode |= DepthTextureMode.Depth;
            }

            _mainCam.depthTextureMode = _depthTextureMode;
        }

        protected override void OnAfterEnable()
        {
            base.OnAfterEnable();

            if (mode == Mode.LERP)
                mode = Mode.FPS;

            if (_overrideDepthTextureMode && _mainCam)
                _mainCam.depthTextureMode = _depthTextureMode;
        }

        public virtual CameraClearFlags ClearFlags
        {
            get => _mainCam.clearFlags;
            set => _mainCam.clearFlags = value;
        }

        public float CameraHeight 
        {
            get => _height.Value;
            set 
            {
                if (_height.Value == value)
                    return;

                _height.Value = value;
                _heightLerp.CurrentValue = value;
            }
        }

        public float DesiredCameraNearClip()
        {
            float val = (CameraHeight / Mathf.Tan(Mathf.Deg2Rad * _mainCam.fieldOfView * 0.5f));

            return val;
        }

        public float CameraClipDistance
        {
            get => _mainCam.farClipPlane - DesiredCameraNearClip();
            set
            {
                _mainCam.farClipPlane = DesiredCameraNearClip() + value;
                AdjsutCamera();
            }
        }

        private Vector3 _adjustedPosition;

        

        protected virtual void AdjsutCamera()
        {
            var camTf = _mainCam.transform;

            if (!camTf.parent || camTf.parent != transform)
                return;

            float clip = DesiredCameraNearClip();
            _adjustedPosition = transform.position - camTf.forward * clip;
            camTf.position = _adjustedPosition;
            _mainCam.nearClipPlane = clip * Mathf.Clamp(1 - offsetClip, 0.01f, 0.99f);
            _mainCam.farClipPlane = clip + _mainCam.farClipPlane - clip;// CameraClipDistance;
        }



        #region Encode & Decode

        public CfgEncoder Encode()
        {
            var cody = new CfgEncoder()
                .Add("pos", transform.localPosition)
                .Add("h", _heightLerp.CurrentValue)
                .Add("sp", speed);

            if (_mainCam)
                cody.Add("rot", _mainCam.transform.localRotation);
                   // .Add("depth", (int)_mainCam.depthTextureMode);

            return cody;
        }

        public void DecodeTag(string tg, CfgData data)
        {
            switch (tg)
            {
                case "pos": _positionLerp.TargetValue = data.ToVector3(); break;
                case "rot": _rotationLerp.TargetValue = data.ToQuaternion(); break;
                case "h": _heightLerp.TargetValue = data.ToFloat(); break;
                case "sp": speed = data.ToFloat(); break;
               // case "depth": _mainCam.depthTextureMode = (DepthTextureMode)data.ToInt(); break;
            }
        }

        public void DecodeInternal(CfgData data)
        {
            IsLerpInitialized();
            new CfgDecoder(data).DecodeTagsFor(this);
            mode = Mode.LERP;
        }
        #endregion

        #region Linked Lerp

        private bool IsLerpInitialized()
        {
            if (_positionLerp != null)
                return true;

            if (_positionLerp == null && _mainCam)
            {
                _positionLerp = new LinkedLerp.TransformLocalPosition(transform, 1000);
                _rotationLerp = new LinkedLerp.TransformLocalRotation(_mainCam.transform, 180);
                return true;
            }

            return false;
        }

        public void Portion(LerpData ld)
        {
            if (IsLerpInitialized() && mode != Mode.FPS)
            {
                _positionLerp.Portion(ld);
                _rotationLerp.Portion(ld);
                _heightLerp.Portion(ld);
            }
        }

        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            if (mode != Mode.FPS)
            {
                _positionLerp.Lerp(ld, canSkipLerp);
                _rotationLerp.Lerp(ld, canSkipLerp);
                _heightLerp.Lerp(ld, canSkipLerp);
                CameraHeight = _heightLerp.CurrentValue;
            }
        }

        private readonly LerpData _lerpData = new(unscaledTime: true);

        private bool lerpYourself;

        #endregion

        public IDisposable ExternalUpdateStart(UnityEngine.Object controller) 
        {
            return QcSharp.DisposableAction(() =>
            {
                _externalCameraController = controller;
                _cameraControlsGate.TryEnter();
                AdjsutCamera();
            });
        }

        protected override void OnUpdateInternal()
        {
            if (_mainCam && _mainCam.depthTextureMode != _depthTextureMode)
                _mainCam.depthTextureMode = _depthTextureMode;

            if (!IsControlledExternally)
            {
                switch (mode)
                {
                    case Mode.FPS:
                        base.OnUpdateInternal();
                        break;
                    case Mode.LERP:
                        if (lerpYourself)
                        {
                            _lerpData.Reset();

                            Portion(_lerpData);

                            Lerp(_lerpData, canSkipLerp: false);

                            if (_lerpData.IsDone)
                            {
                                mode = Mode.FPS;
                                lerpYourself = false;
                            }
                        }
                        break;
                }

                AdjsutCamera();
            } 
        }


        #region Inspector
        public override void Inspect()
        {
            if (IsControlledExternally)
            {
                "Camera is controlled Externally by {0}".F(_externalCameraController).PegiLabel(pegi.Styles.WarningText).Write();
                pegi.ClickHighlight(_externalCameraController).Nl();
            }
            else
            {

                switch (mode)
                {
                    case Mode.FPS:
                        pegi.FullWindow.DocumentationClickOpen(() =>
                           "WASD - move {0} Q, E - Dwn, Up {0} Shift - faster {0} {1} {0} MMB - Orbit Collider".F(
                               pegi.EnvironmentNl,
                               _disableRotation ? "" : (rotateWithoutRmb ? "RMB - rotation" : "Mouse to rotate")
                           ));
                        break;


                    case Mode.STATIC:

                        "Not Lerping himself".PegiLabel().WriteWarning();

                        if ("Lepr Yourself".PegiLabel().Click().Nl())
                            lerpYourself = true;

                        if ("Enable first-person controls".PegiLabel().Click().Nl())
                            mode = Mode.FPS;
                        break;
                    case Mode.LERP:
                        "IS LERPING".PegiLabel().Write();
                        break;
                }
            }

            base.Inspect();

            if (MainCam)
            {
                if (!_mainCam.transform.IsChildOf(transform))
                {
                    "Make main camera a child object of this script".PegiLabel().WriteWarning().Nl();

                    if (_mainCam.transform == transform)
                    {
                        if (transform.childCount == 0)
                        {
                            if ("Add Empty Child".PegiLabel().Click().Nl())
                            {
                                var go = new GameObject("Advanced Camera");
                                var tf = go.transform;
                                tf.SetParent(transform, false);
                            }

                        }
                        else
                            "Delete Main Camera and create one on a child".PegiLabel().Write_Hint();
                    } else 
                    {
                        if ("Try Fix".PegiLabel().Click().Nl())
                        {
                            transform.SetPositionAndRotation(MainCam.transform.position, MainCam.transform.rotation);
                            MainCam.transform.parent = transform;
                        }
                    }

                }
                else 
                {
                    var changes = pegi.ChangeTrackStart();

                    float clipDistance = CameraClipDistance;
                    float fov = _mainCam.fieldOfView;

                    if ("FOV".PegiLabel(60).Edit(ref fov, 5, 170).Nl())
                        _mainCam.fieldOfView = fov;

                    "Height:".PegiLabel(60).Write();
                    pegi.Nested_Inspect_Value(ref _height);
                    pegi.Nl();

                    if ("Clip Range".PegiLabel(90).Edit_Delayed(ref clipDistance).Nl())
                        CameraClipDistance = Mathf.Clamp(clipDistance, 0.03f, 100000);

                    "Clip Distance (Debug): {0}".F(DesiredCameraNearClip()).PegiLabel().Nl();

                    "Offset Clip".PegiLabel(90).Edit(ref offsetClip, 0.01f, 0.99f).Nl();

              

                }

                DepthTextureMode depth = _mainCam.depthTextureMode;

                "Override Depth Mode ({0})".F(depth).PegiLabel().ToggleIcon(ref _overrideDepthTextureMode, hideTextWhenTrue: true);

                if (_overrideDepthTextureMode)
                {
                    if (depth != _depthTextureMode && "Set to {0}".F(_depthTextureMode).PegiLabel().Click().Nl())
                        SetDepthMode(_depthTextureMode);

                    if ("Depth".PegiLabel(55).Edit_EnumFlags(ref depth))
                        SetDepthMode(depth);


                    void SetDepthMode(DepthTextureMode newMode) 
                    {
                        if (newMode == DepthTextureMode.MotionVectors) 
                        {
                            newMode |= DepthTextureMode.Depth;
                        }

                        _depthTextureMode = newMode;

                        _mainCam.depthTextureMode = newMode;
                    }
                }

                pegi.Nl();

                if (MainCam.clearFlags == CameraClearFlags.Skybox) 
                {
                    var skybox = RenderSettings.skybox;
                    if ("Skybox material".PegiLabel().Edit(ref skybox))
                        RenderSettings.skybox = skybox;
                }
            }
        }

        #endregion

        protected override void OnRegisterServiceInterfaces()
        {
            base.OnRegisterServiceInterfaces();
            RegisterServiceAs<Singleton_CameraOperatorConfigurable>();
        }
    }

    [PEGI_Inspector_Override(typeof(Singleton_CameraOperatorConfigurable))] internal class CameraOperatorConfigurableDrawer : PEGI_Inspector_Override { }

}