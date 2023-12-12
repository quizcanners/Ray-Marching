using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
#if UNITY_EDITOR
using UnityEditor;
#endif
using UnityEngine;
using UnityEngine.Rendering;

namespace QuizCanners.RayTracing
{
  
    [AddComponentMenu(QcUtils.QUIZCANNERS + "/Top Down Light Camera")]
    [ExecuteAlways]
    public class Singleton_TopDownShadowAndLightsRenderer : Singleton.BehaniourBase, IPEGI
    {
        [SerializeField] private Camera _orthogonalCamera;
        [SerializeField] private int _orthoSize = 16;
        [SerializeField] private float _height = 100;
        [SerializeField] private int _renderLayer = 10;
        private readonly ShaderProperty.TextureValue TOP_DOWN_RESULT = new("_RayTracing_TopDownBuffer");
        private readonly ShaderProperty.VectorValue TOP_DOWN_RENDERER_POSITION = new("_RayTracing_TopDownBuffer_Position");

        [NonSerialized] private RenderTexture _renderTexture;

        private RenderTexture GetRenderTexture() 
        {
            if (_renderTexture)
                return _renderTexture;

            _renderTexture = new RenderTexture(1024, 1024, depth: 0, RenderTextureFormat.ARGBHalf)
            {
                wrapMode = TextureWrapMode.Clamp,
                useMipMap = false,
                depthStencilFormat = UnityEngine.Experimental.Rendering.GraphicsFormat.None,
            };

            return _renderTexture;
        }

        void RenderViaCommandBuffer() 
        {
            CommandBuffer command = new();

            command.SetViewMatrix(Matrix4x4.TRS(transform.position, transform.rotation, Vector3.one));
            command.SetProjectionMatrix(Matrix4x4.Ortho(-_orthoSize, _orthoSize, -_orthoSize, _orthoSize, 0.03f, 50));

            command.SetRenderTarget(GetRenderTexture());

            Graphics.ExecuteCommandBuffer(command);
        }
        

        void UpdateCamera() 
        {
            if (!_orthogonalCamera)
            {
                Debug.LogError("Top Down camera is not assigned");
                return;
            }

            _orthogonalCamera.orthographicSize = _orthoSize;

            _orthogonalCamera.transform.localPosition = new Vector3(0,_height,0);
            _orthogonalCamera.nearClipPlane = 0.03f;
            _orthogonalCamera.farClipPlane = _height * 2;
            _orthogonalCamera.SetMaskRemoveOthers(layerIndex: _renderLayer);

            _orthogonalCamera.targetTexture = GetRenderTexture();

            TOP_DOWN_RESULT.GlobalValue = _orthogonalCamera.targetTexture;

            _orthogonalCamera.enabled = true;

            UpdatePosition();
        }

        protected void UpdatePosition() 
        {
            TOP_DOWN_RENDERER_POSITION.GlobalValue = transform.position.ToVector4(0.5f / _orthoSize);
        }

        private readonly Gate.Vector3Value _positionGate = new();

        public void SetPosition(Vector3 newPosition) 
        {
            transform.position = new Vector3(Mathf.Round(newPosition.x), newPosition.y, Mathf.Round(newPosition.z));
            UpdatePosition();
        }

        void LateUpdate() 
        {
            if (_positionGate.TryChange(transform.position)) 
            {
                UpdatePosition();
            }
        }

        #region Inspector
        public override string InspectedCategory => nameof(RayTracing);

        public override string ToString() => "Top Down";
        public override void Inspect()
        {
            var changed = pegi.ChangeTrackStart();

#if UNITY_EDITOR

            if (!Application.isPlaying) 
            {
                if ("Allign to Scene Camera".PegiLabel().Click().Nl())
                    transform.position = SceneView.lastActiveSceneView.camera.transform.position; // TryGetOverla.position;
            }

#endif

            if (_orthogonalCamera)
            {
                Icon.Refresh.Click(toolTip: "Refresh Camera stuff");

                if (Application.isPlaying && !_orthogonalCamera.targetTexture)
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

            "Size".PegiLabel(50).Edit(ref _orthoSize).Nl().OnChanged(() => _orthoSize = Mathf.Max(1, _orthoSize));

            "Height".PegiLabel(60).Edit(ref _height, 0.2f, (float)_orthoSize).Nl();

            "Rendering Layer".PegiLabel(90).Edit_Layer(ref _renderLayer).Nl();

            if (changed)
                UpdateCamera();
        }

        public override string NeedAttention()
        {
            return base.NeedAttention();
        }

        #endregion


        protected override void OnAfterEnable()
        {
            base.OnAfterEnable();

            QcUnity.SetLayerMaskForSceneView(_renderLayer, false);

            UpdateCamera();
        }

        protected override void OnBeforeOnDisableOrEnterPlayMode(bool afterEnableCalled)
        {
            base.OnBeforeOnDisableOrEnterPlayMode(afterEnableCalled);
   
            if (_renderTexture)
            {
                _renderTexture.DestroyWhatever();
                _renderTexture = null;
            }
        }

    }

    [PEGI_Inspector_Override(typeof(Singleton_TopDownShadowAndLightsRenderer))] internal class TopDownShadowAndLightsRendererSingletonDrawer : PEGI_Inspector_Override { }

}
