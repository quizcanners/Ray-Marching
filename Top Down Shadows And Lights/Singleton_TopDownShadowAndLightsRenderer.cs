using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.RayTracing
{
    [ExecuteAlways]
    public class Singleton_TopDownShadowAndLightsRenderer : Singleton.BehaniourBase, IPEGI
    {
        [SerializeField] private Camera _orthogonalCamera;
        [SerializeField] private int _orthoSize = 16;
        [SerializeField] private float _height = 100;
        [SerializeField] private int _renderLayer = 10;
       // private readonly ShaderProperty.Feature TOP_DOWN_LIGHT_AND_SHADOW = new("TOP_DOWN_LIGHT_AND_SHADOW");
        private readonly ShaderProperty.TextureValue TOP_DOWN_RESULT = new("_RayTracing_TopDownBuffer");
        private readonly ShaderProperty.VectorValue TOP_DOWN_RENDERER_POSITION = new("_RayTracing_TopDownBuffer_Position");


        #region Inspector
        public override string InspectedCategory => nameof(RayTracing);

        public override string ToString() => "Top Down";
        public override void Inspect()
        {
            var changed = pegi.ChangeTrackStart();

            if (_orthogonalCamera) 
            {
                Icon.Refresh.Click(toolTip: "Refresh Camera stuff");

                if (!_orthogonalCamera.targetTexture)
                    "Target texture is not found. Shders will not recieve the result".PegiLabel().WriteWarning();

                if (_orthogonalCamera.orthographic == false) 
                    "{0} Camera is not orthographic".F(_orthogonalCamera.gameObject.name).PegiLabel().WriteWarning();

                if (_orthogonalCamera.clearFlags != CameraClearFlags.SolidColor || _orthogonalCamera.backgroundColor != Color.clear) 
                {
                    "Camera need Solid Color Clear Flags".PegiLabel().WriteWarning();
                    if ("Set Clear Black".PegiLabel().Click().Nl())
                    {
                        _orthogonalCamera.clearFlags = CameraClearFlags.SolidColor;
                        _orthogonalCamera.backgroundColor = Color.clear;
                    }
                }
            } 
            else 
            {
                "Camera".PegiLabel(50).Edit_IfNull(ref _orthogonalCamera, gameObject).Nl();
            }

            "Size".PegiLabel(50).Edit(ref _orthoSize).Nl().OnChanged(()=> _orthoSize = Mathf.Max(1, _orthoSize));

            "Height".PegiLabel(60).Edit(ref _height, 0.2f, (float)_orthoSize).Nl();

            "Rendering Layer".PegiLabel(90).Edit_Layer(ref _renderLayer).Nl();

            if (changed)
                UpdateCamera();
        }

        #endregion

        void UpdateCamera() 
        {
            if (!_orthogonalCamera)
                return;

            _orthogonalCamera.orthographicSize = _orthoSize;

            _orthogonalCamera.transform.localPosition = new Vector3(0,_height,0);
            _orthogonalCamera.nearClipPlane = 0.03f;
            _orthogonalCamera.farClipPlane = _height * 2;
            _orthogonalCamera.SetMaskRemoveOthers(layerIndex: _renderLayer);

            TOP_DOWN_RESULT.GlobalValue = _orthogonalCamera.targetTexture;
            TOP_DOWN_RENDERER_POSITION.GlobalValue = transform.position.ToVector4(0.5f/_orthoSize);

        }

        protected override void OnAfterEnable()
        {
            base.OnAfterEnable();

            QcUnity.SetLayerMaskForSceneView(_renderLayer, false);

           // TOP_DOWN_LIGHT_AND_SHADOW.Enabled = true;

            UpdateCamera();
        }

        protected override void OnBeforeOnDisableOrEnterPlayMode(bool afterEnableCalled)
        {
            base.OnBeforeOnDisableOrEnterPlayMode(afterEnableCalled);
           // TOP_DOWN_LIGHT_AND_SHADOW.Enabled = false;
        }

        private readonly Gate.Vector3Value _positionGate = new();

        void Update() 
        {
            if (_positionGate.TryChange(transform.position)) 
            {
                UpdateCamera();
            }
        }

    }

    [PEGI_Inspector_Override(typeof(Singleton_TopDownShadowAndLightsRenderer))] internal class TopDownShadowAndLightsRendererSingletonDrawer : PEGI_Inspector_Override { }

}