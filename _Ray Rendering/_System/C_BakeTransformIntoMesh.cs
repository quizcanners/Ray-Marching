using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.RayTracing
{

    [ExecuteAlways]
    [AddComponentMenu(QcUtils.QUIZCANNERS + "/PrimitiveTracing/Transform Into Mesh")]

    public class C_BakeTransformIntoMesh : MonoBehaviour, IPEGI, INeedAttention
    {
        [SerializeField] private TransformToMeshDataBake _meshDataBake = new();
        [SerializeField] private Color _color = Color.white;

        public Color MeshColor 
        {
            get => _color; 
            set
            {
                _color = value;
                _meshDataBake.MyColor = _color;
            }
        }

        protected void LateUpdate()
        {
           _meshDataBake.Managed_LateUpdate();
        }

        protected void OnDisable()
        {
            _meshDataBake.Managed_OnDisable();
        }

        protected void OnEnable()
        {
            _meshDataBake.MyColor = _color;
            _meshDataBake.Managed_OnEnable();
        }

        protected void Reset()
        {
            _meshDataBake.OnReset(transform);
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

    }
    [PEGI_Inspector_Override(typeof(C_BakeTransformIntoMesh))]
    internal class C_BakeTransformIntoMeshDrawer : PEGI_Inspector_Override { }
}