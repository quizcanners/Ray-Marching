using QuizCanners.Inspect;
using QuizCanners.Utils;
using QuizCanners.VolumeBakedRendering;
using UnityEngine;

namespace QuizCanners.SpecialEffects
{
    [ExecuteAlways]
    public class C_AODecalTarget : MonoBehaviour, IPEGI, INeedAttention
    {
        [SerializeField] private TransformToMeshDataBake _meshDataBake = new();
        [SerializeField] private MeshRenderer _renderer;
        public IlluminationDecals.AoMode Mode;
        [SerializeField] private Color _color = Color.white;

        public Color IlluminationData
        {
            get => _color;
            set
            {
                _color = value;
                _meshDataBake.MyColor = _color;
            }
        }

        public float Ambient
        {
            get => IlluminationData.g;
            set
            {
                var col = IlluminationData;
                col.g = value;
                IlluminationData = col;
            }
        }

        public float Shadow
        {
            get => IlluminationData.b;
            set
            {
                var col = IlluminationData;
                col.b = value;
                IlluminationData = col;
            }
        }

        public int Version => _meshDataBake.DataVersion;

        public Mesh GetMesh() => _meshDataBake.GetMesh(gameObject.isStatic);//baker.GetMesh();

        private void OnEnable()
        {
            _meshDataBake.MyColor = _color;
            _meshDataBake.Managed_OnEnable();

            if (Application.isPlaying)
            {
                if (gameObject.isStatic)
                    IlluminationDecals.s_staticAoDecalTargets.Add(this);
                else
                    IlluminationDecals.s_dynamicAoDecalTargets.Add(this);

                SetDirty();
                _renderer.enabled = false;
            }
        }

        private void SetDirty()
        {
            if (gameObject.isStatic)
                IlluminationDecals.StaticDecalsVersion++;
            else
                IlluminationDecals.DynamicDecalsVersion++;
        }

        private void LateUpdate()
        {
            if (!gameObject.isStatic || !Application.isPlaying)
                _meshDataBake.Managed_LateUpdate();

#if UNITY_EDITOR
            if (_bakerVersion.TryChange(Version))
                SetDirty();
#endif
        }

        private void OnDisable()
        {
            _meshDataBake.Managed_OnDisable();

            if (Application.isPlaying)
            {
                if (gameObject.isStatic)
                    IlluminationDecals.s_staticAoDecalTargets.Remove(this);
                else
                    IlluminationDecals.s_dynamicAoDecalTargets.Remove(this);

                SetDirty();
            }
        }

#if UNITY_EDITOR
        private readonly Gate.Integer _bakerVersion = new();

        void IPEGI.Inspect()
        {
            if (!Application.isPlaying && !gameObject.isStatic)
            {
                "Will be rendered s Dynamic Decal since object is not static".PegiLabel().Nl();
                if ("Make Static".PegiLabel().Click().Nl())
                    gameObject.isStatic = true;
            }

            if (!Application.isPlaying)
                _meshDataBake.Nested_Inspect().Nl();

            "Renderer".PegiLabel().Edit_IfNull(ref _renderer, gameObject).Nl();

            "Mode".PegiLabel(50).Edit_Enum(ref Mode).Nl();

            float ao = Ambient; 
            "Ambient".PegiLabel(50).Edit(ref ao, 0, 1).Nl(() => Ambient = ao);

            float shad = Shadow;
            "Shadow".PegiLabel(50).Edit(ref shad, 0, 1).Nl(() => Shadow = shad);            
        }
#endif

        void Reset() 
        {
            _renderer = GetComponent<MeshRenderer>();
            _meshDataBake.OnReset(transform);
        }

        public string NeedAttention()
        {
            if (_meshDataBake.TryGetAttentionMessage(out var msg))
                return msg;

            if (Shadow < 0.01f && Ambient < 0.01f)
                return "Values are low, no result will be visible";

            return null;
        }
    }

    [PEGI_Inspector_Override(typeof(C_AODecalTarget))]
    internal class C_AODecalTargetDrawer : PEGI_Inspector_Override { }
}
