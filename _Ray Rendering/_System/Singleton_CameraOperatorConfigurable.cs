using QuizCanners.Inspect;
using QuizCanners.Lerp;
using QuizCanners.Migration;
using System;
using UnityEngine;

namespace QuizCanners.Utils
{

    public class Singleton_CameraOperatorConfigurable : Singleton_CameraOperatorGodMode, ICfgCustom, ILinkedLerping
    {
        [SerializeField] private QcUtils.DynamicRangeFloat _height = new(0.001f, 10, 0.2f);
        [SerializeField] private DepthTextureMode _depthTextureMode = DepthTextureMode.None;
        [SerializeField] private bool _overrideDepthTextureMode;

        private LinkedLerp.TransformLocalPosition _positionLerp;// = new LinkedLerp.TransformLocalPosition("Position");
        private LinkedLerp.TransformLocalRotation _rotationLerp;// = new LinkedLerp.TransformLocalRotation("Rotation");
        private readonly LinkedLerp.FloatValue _heightLerp = new(name: "Height");

        public enum Mode { FPS = 0, STATIC = 1, LERP = 2 }
        public Mode mode;

        [NonSerialized] public IGodModeCameraController controller;

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
                _height.Value = value;
                _heightLerp.CurrentValue = value;
            }
        }

        private float CameraWindowNearClip()
        {
            float val = (CameraHeight / Mathf.Tan(Mathf.Deg2Rad * _mainCam.fieldOfView * 0.5f));

            return val;
        }

        private float CameraClipDistance
        {
            get => _mainCam.farClipPlane - CameraWindowNearClip();
            set => _mainCam.farClipPlane = CameraWindowNearClip() + value;
        }

        protected virtual void AdjsutCamera()
        {
            var camTf = _mainCam.transform;

            if (!camTf.parent || camTf.parent != transform)
                return;

            float clip = CameraWindowNearClip();
            camTf.position = transform.position - camTf.forward * clip;
            _mainCam.nearClipPlane = clip * Mathf.Clamp(1 - offsetClip, 0.01f, 0.99f);
            _mainCam.farClipPlane = clip + CameraClipDistance;
        }

        #region Encode & Decode

        public CfgEncoder Encode()
        {
            var cody = new CfgEncoder()
                .Add("pos", transform.localPosition)
                .Add("h", _heightLerp.CurrentValue)
                .Add("sp", speed);

            if (_mainCam)
                cody.Add("rot", _mainCam.transform.localRotation)
                    .Add("depth", (int)_mainCam.depthTextureMode);

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
                case "depth": _mainCam.depthTextureMode = (DepthTextureMode)data.ToInt(); break;
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

        protected override void OnUpdateInternal()
        {
            if (controller != null && QcUnity.IsNullOrDestroyed_Obj(controller))
                controller = null;

            if (controller != null)
            {
                var trg = controller.GetTargetPosition();
                transform.position = trg + controller.GetCameraOffsetPosition();

                if (controller.TryGetCameraHeight(out var height))
                    CameraHeight = height;

                _mainCam.transform.LookAt(trg, Vector3.up);
            }
            else
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

                            if (_lerpData.Done)
                            {
                                mode = Mode.FPS;
                                lerpYourself = false;
                            }
                        }

                        break;
                }
            }

            AdjsutCamera();
        }

        public override void Inspect()
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
                            transform.position = MainCam.transform.position;
                            transform.rotation = MainCam.transform.rotation;
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
                    _height.Inspect();
                    pegi.Nl();

                    if ("Clip Range".PegiLabel(90).Edit_Delayed(ref clipDistance).Nl())
                        clipDistance = Mathf.Clamp(clipDistance, 0.03f, 100000);

                    "Clip Distance (Debug): {0}".F(CameraWindowNearClip()).PegiLabel().Nl();

                    "Offset Clip".PegiLabel(90).Edit(ref offsetClip, 0.01f, 0.99f).Nl();

                    if (changes)
                    {
                        CameraClipDistance = clipDistance;
                        AdjsutCamera();
                    } 

                }

                var depth = _mainCam.depthTextureMode;

                "Override Depth Mode ({0})".F(depth).PegiLabel().ToggleIcon(ref _overrideDepthTextureMode, hideTextWhenTrue: true);

                if (_overrideDepthTextureMode)
                {
                    if (depth != _depthTextureMode)
                        _mainCam.depthTextureMode = _depthTextureMode;

                    if ("Depth".PegiLabel(55).Edit_Enum(ref _depthTextureMode))
                        _mainCam.depthTextureMode = _depthTextureMode;
                }

                pegi.Nl();

                if (MainCam.clearFlags == CameraClearFlags.Skybox) 
                {
                    var skybox = RenderSettings.skybox;
                    if ("Skybox material".PegiLabel().Edit(ref skybox))
                        RenderSettings.skybox = skybox;
                }
            }

            if (controller != null)
            {
                "Controller Assigned".PegiLabel().Write(); pegi.ClickHighlight(controller as UnityEngine.Object).Nl();
            }
        }

        protected override void OnRegisterServiceInterfaces()
        {
            base.OnRegisterServiceInterfaces();
            RegisterServiceAs<Singleton_CameraOperatorConfigurable>();
        }
    }

    [PEGI_Inspector_Override(typeof(Singleton_CameraOperatorConfigurable))] internal class CameraOperatorConfigurableDrawer : PEGI_Inspector_Override { }

}