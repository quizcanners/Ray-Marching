using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    [DisallowMultipleComponent]
    public class C_TopDownLight : MonoBehaviour, INeedAttention
    {
        public float BaseSize = 1;
        [SerializeField] private MeshRenderer _meshRenderer;
        //private readonly ShaderProperty.FloatValue Distance = new("_Distance", 0.01f, 5f);

        Quaternion targetRotation;

     //   MaterialPropertyBlock _block;

        private float _size;

        const float MAX_HEIGHT = 5;

        float DistanceFromProjector => transform.position.y - Singleton.GetValue<Singleton_TopDownShadowAndLightsRenderer, float>(s => s.transform.position.y, 0);

        float Upscale
        {
            get
            {
                return (1 + QcMath.SmoothStep(0, MAX_HEIGHT, DistanceFromProjector) * 3);
            }
        }

        public float Size
        {
            get => _size;// transform.localScale.x;
            set
            {
                _size = value;
                transform.localScale = Vector3.one * _size;
            }
        }

        public float DistanceFromSurface 
        {
            set 
            {
             //   Distance.SetOn(_block, value);
               // _meshRenderer.SetPropertyBlock(_block);
            }
        }

        private Quaternion rotationQ;

        private void Reset()
        {
            _meshRenderer = GetComponent<MeshRenderer>();
        }

        void OnEnable()
        {
            targetRotation = Quaternion.Euler(90, 0, 0); 

           // _block ??= new MaterialPropertyBlock();

            if (!_meshRenderer)
                _meshRenderer = GetComponent<MeshRenderer>();
        }

      
        void LateUpdate()
        {
            transform.rotation = targetRotation;
            Size = BaseSize * Upscale;
            DistanceFromSurface = Mathf.Clamp01(Mathf.Abs(DistanceFromProjector) / MAX_HEIGHT);
        }

        public string NeedAttention()
        {
          

            return null;
        }
    }
}
