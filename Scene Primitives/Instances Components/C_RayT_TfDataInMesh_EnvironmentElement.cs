using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.RayTracing
{
    [DisallowMultipleComponent]
    [ExecuteAlways]
    [AddComponentMenu(QcUtils.QUIZCANNERS + "/PrimitiveTracing/Scene Prefab/Primitive Shape With Mesh Data")]
    public class C_RayT_TfDataInMesh_EnvironmentElement : C_RayT_PrimShape_EnvironmentElement, IPEGI
    {
        [SerializeField] private TransformToMeshDataBake meshDataBake = new();

        Color MyColor => Config != null ? Config.Color : Color.white;

  
        protected void OnDisable() 
        {
            meshDataBake.Managed_OnDisable();
        }

        protected void OnEnable()
        {
            meshDataBake.MyColor = MyColor;
            meshDataBake.Managed_OnEnable();
        }


        protected override void LateUpdate()
        {
            base.LateUpdate();

            meshDataBake.Managed_LateUpdate();

        }

        #region Inspector


        public override string NeedAttention()
        {
            if (meshDataBake.TryGetAttentionMessage(out var msg))
                return msg;

             return base.NeedAttention();
        }

        public override void Inspect()
        {
            pegi.Nl();

            var changed = pegi.ChangeTrackStart();

            base.Inspect();

            meshDataBake.Nested_Inspect().Nl();

            if (Config == null)
                "No Config".PegiLabel().WriteWarning().Nl();

            if (changed) 
            {
                meshDataBake.MyColor = MyColor;
            }

        }
        #endregion

        void Reset()
        {
            if (!meshDataBake.meshFilter)
                meshDataBake.meshFilter = GetComponent<MeshFilter>();
        }
    }

    [PEGI_Inspector_Override(typeof(C_RayT_TfDataInMesh_EnvironmentElement))] internal class MeshWithBakedTransformDataDrawer : PEGI_Inspector_Override { }
}
