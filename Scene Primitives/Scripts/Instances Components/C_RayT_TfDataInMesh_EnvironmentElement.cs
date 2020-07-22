using QuizCanners.Inspect;
using QuizCanners.Migration;
using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.RayTracing
{
    [DisallowMultipleComponent]
    [ExecuteAlways]
    [AddComponentMenu("PrimitiveTracing/Scene Prefab/Primitive Shape With Mesh Data")]
    public class C_RayT_TfDataInMesh_EnvironmentElement : C_RayT_PrimShape_EnvironmentElement, IPEGI
    {
        [SerializeField] private MeshFilter meshFilter;
        [SerializeField] private Mesh originalMesh;
        private Mesh meshInstance;
        

        void UpdateMeshData() 
        {
            if (meshFilter && meshFilter.sharedMesh && !QcUnity.IsPartOfAPrefab(gameObject))
            {
                if (!meshInstance)
                {
                    originalMesh = meshFilter.sharedMesh;
                    meshInstance = Instantiate(meshFilter.sharedMesh); // meshFilter.mesh;
                    meshInstance.name = "Instanciated Mesh";
                }

                meshInstance.SetUVs(0, CreateData(transform.position.ToVector4()));
                meshInstance.SetUVs(1, CreateData(transform.localScale.ToVector4(0)));

                var rot = transform.rotation.ToVector4();
                rot = new Vector4(-rot.x, -rot.y, -rot.z, rot.w);

                meshInstance.SetUVs(2, CreateData(rot));

                if (Config != null)
                {
                    meshInstance.colors = CreateData(Config.Color);
                }

                T[] CreateData<T>(T value)
                {
                    var arr = new T[meshInstance.vertexCount];
                    for (int i = 0; i < arr.Length; i++)
                        arr[i] = value;

                    return arr;
                }

                meshFilter.sharedMesh = meshInstance;
            }
        }

        protected void OnDisable() 
        {
            if (meshInstance)
            {
                meshInstance.DestroyWhateverUnityObject();
                meshInstance = null;
            }

            if (originalMesh)
            {
                meshFilter.sharedMesh = originalMesh;
                originalMesh = null;
            }
        }

        protected void OnEnable()
        {
            if (originalMesh)
            {
                meshFilter.sharedMesh = originalMesh;
                originalMesh = null;
            }

            UpdateMeshData();
        }

        #region Linked Lerp
        private readonly Gate.Vector3Value _position = new();
        private readonly Gate.Vector3Value _sizeGate = new();
        private readonly Gate.QuaternionValue _rotation = new();

        protected override void LateUpdate()
        {
            base.LateUpdate();

            if (_position.TryChange(transform.position) | _rotation.TryChange(transform.rotation) | _sizeGate.TryChange(transform.lossyScale))
                UpdateMeshData();

        }
        #endregion

        #region Inspector


        public override string NeedAttention()
        {
            if (!meshFilter)
                return "Mesh filter is NULL";

            if (!meshFilter.sharedMesh)
                return "meshFilter.sharedMesh in NULL";

            if (meshFilter.sharedMesh.vertexCount < 3)
                return "There are less then 3 vertices in the mesh. Something went wrong";

             return base.NeedAttention();
        }

        public override void Inspect()
        {
            pegi.Nl();
            var changed = pegi.ChangeTrackStart();

            base.Inspect();

            if (!Application.isPlaying && QcUnity.IsPartOfAPrefab(gameObject))
                "Will not modify mesh of a prefab - this will lead to errors".PegiLabel().WriteWarning().Nl();

            if (!meshFilter)
            {
                Icon.Refresh.Click(() => Reset());
                pegi.Edit_Property(() => meshFilter, this);
            }
            else
            {
                if (meshFilter.sharedMesh
                   && meshFilter.sharedMesh.vertexCount >= 3
                    && Application.isPlaying
                 &&  !QcUnity.IsPartOfAPrefab(gameObject))
                    pegi.Click(UpdateMeshData).Nl();
            }
            if (changed)
                UpdateMeshData();

            pegi.Nl();

            "Dynamic batching needs to be enabled for this to work correctly".PegiLabel().Write_Hint().Nl() ;

            if (Config == null)
                "No Config".PegiLabel().WriteWarning().Nl();

        }
        #endregion

        void Reset()
        {
            meshFilter = GetComponent<MeshFilter>();
        }
    }

    [PEGI_Inspector_Override(typeof(C_RayT_TfDataInMesh_EnvironmentElement))] internal class MeshWithBakedTransformDataDrawer : PEGI_Inspector_Override { }
}
