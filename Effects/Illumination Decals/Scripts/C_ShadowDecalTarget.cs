using QuizCanners.Inspect;
using QuizCanners.Utils;
using QuizCanners.VolumeBakedRendering;
using UnityEngine;

namespace QuizCanners.SpecialEffects
{
    [ExecuteAlways]
    public class C_ShadowDecalTarget : MonoBehaviour, IPEGI, INeedAttention
    {
        // [SerializeField] private C_BakeTransformIntoMesh baker;
        [SerializeField] private TransformToMeshDataBake _meshDataBake = new();
        [SerializeField] private MeshRenderer _renderer;
        [SerializeField] private Material _decalMaterialReplacement;
        public IlluminationDecals.ShadowMode Mode;
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

        public int Version => _meshDataBake.DataVersion;

        public Mesh GetMesh() => _meshDataBake.GetMesh(gameObject.isStatic);//baker.GetMesh();

        public Material GetMaterial() => _decalMaterialReplacement ? _decalMaterialReplacement : _renderer.sharedMaterial;

        private void OnEnable()
        {
            _meshDataBake.MyColor = _color;
            _meshDataBake.Managed_OnEnable();

            if (Application.isPlaying)
            {
                SetDirty();

                if (gameObject.isStatic)
                {
                    IlluminationDecals.s_staticShadowDecalTargets.Add(this);
                }
                else
                {
                    IlluminationDecals.s_dynamicShadowDecalTargets.Add(this);
                }
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
                SetDirty();

                if (gameObject.isStatic)
                    IlluminationDecals.s_staticShadowDecalTargets.Remove(this);
                else
                    IlluminationDecals.s_dynamicShadowDecalTargets.Remove(this);

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
            
            if (Mode == IlluminationDecals.ShadowMode.Sdf) 
            {
                "Material (Optional)".PegiLabel().Edit(ref _decalMaterialReplacement).Nl();
            }
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
            return null;
        }
    }

    [PEGI_Inspector_Override(typeof(C_ShadowDecalTarget))]
    internal class C_ShadowDecalTargetDrawer : PEGI_Inspector_Override { }
}
