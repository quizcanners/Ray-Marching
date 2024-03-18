using QuizCanners.Inspect;
using UnityEngine;
using System;
using QuizCanners.Utils;



namespace QuizCanners.VolumeBakedRendering
{
    public class VolumeShapeDraw : MonoBehaviour, IPEGI
    {
        [SerializeField] private Material _bakeMaterial;
        [NonSerialized] private Material _workingInstance;
        [NonSerialized] public int BakedForLocation_Version = -1;
        [NonSerialized] private Vector3 _previousPosition;
        readonly ShaderProperty.VectorValue MATERIAL_POS = new("_ObjectPos");
        readonly ShaderProperty.VectorValue MATERIAL_SIZE = new("_ObjectSize");

        public Material GetMaterialForBake()
        {
            if (!_bakeMaterial)
                return null;

            if (!_workingInstance) 
                _workingInstance = new Material(_bakeMaterial);
            
            _workingInstance.Set(MATERIAL_POS, transform.position);
            _workingInstance.Set(MATERIAL_SIZE, transform.lossyScale);

            return _workingInstance;
        }

        void LateUpdate() 
        {
            if (Vector3.Distance(_previousPosition, transform.position) > 0.01f)
            {
               if (Singleton.TryGet<Singleton_QcRendering>(out var m))
                    m.SetBakingDirty("Volume Shape Moved");

                BakedForLocation_Version = -1;
                _previousPosition = transform.position;
            }
        }

        void IPEGI.Inspect()
        {
            pegi.Nl();

            "Material Prototype".PegiLabel().Edit(ref _bakeMaterial).Nl();

            "Material Instance".PegiLabel().Write(_workingInstance);

            pegi.Nl();

            if ("Render".PegiLabel().Click())
            {
                BakedForLocation_Version = -1;
                gameObject.SetActive(true);
                enabled = true;
            }
        }
    }

    [PEGI_Inspector_Override(typeof(VolumeShapeDraw))] internal class VolumeShapeDrawInspectorOverride : PEGI_Inspector_Override { }

}
