using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{

    [ExecuteAlways]
    [AddComponentMenu(QcUtils.QUIZCANNERS + "/PrimitiveTracing/Transform Into Mesh")]

    public class C_BakeTransformIntoMesh : MonoBehaviour, IPEGI, INeedAttention
    {
        [SerializeField] private TransformToMeshDataBake _meshDataBake = new();
        [SerializeField] private Color _color = Color.white;

        public Mesh GetMesh() => _meshDataBake.GetMesh(gameObject.isStatic);

        public Color MeshColor 
        {
            get => _color; 
            set
            {
                _color = value;
                _meshDataBake.MyColor = _color;
            }
        }

        public int Version => _meshDataBake.DataVersion;

        protected void OnEnable()
        {
            _meshDataBake.MyColor = _color;
            _meshDataBake.Managed_OnEnable();
        }

        protected void LateUpdate()
        {
            if (!gameObject.isStatic)
                _meshDataBake.Managed_LateUpdate();
        }

        protected void OnDisable()
        {
            _meshDataBake.Managed_OnDisable();
        }

        #region Inspector

        void IPEGI.Inspect()
        {
            pegi.Nl();

            var changed = pegi.ChangeTrackStart();

            "Color".PegiLabel().Edit(ref _color).Nl();

            _meshDataBake.Nested_Inspect().Nl();

            if (changed)
            {
                _meshDataBake.MyColor = _color;
            }
        }

        public string NeedAttention()
        {
            if (_meshDataBake.TryGetAttentionMessage(out var msg))
                return msg;

            return null;
        }

        #endregion

        protected void Reset()
        {
            _meshDataBake.OnReset(transform);
        }

    }
    [PEGI_Inspector_Override(typeof(C_BakeTransformIntoMesh))]
    internal class C_BakeTransformIntoMeshDrawer : PEGI_Inspector_Override { }
}