using QuizCanners.Inspect;
using UnityEngine;
using System;
using QuizCanners.Utils;



namespace QuizCanners.RayTracing
{
    public class VolumeShapeDraw : MonoBehaviour, IPEGI
    {
        [SerializeField] private Material _bakeMaterial;
        [NonSerialized] private Material _workingInstance;
        [NonSerialized] public int BakedForLocation_Version = -1;
        [NonSerialized] private Vector3 _previousPosition;


        ShaderProperty.VectorValue MATERIAL_POS = new ShaderProperty.VectorValue("_ObjectPos");
        ShaderProperty.VectorValue MATERIAL_SIZE = new ShaderProperty.VectorValue("_ObjectSize");

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
                RayRenderingManager.instance.SetBakingDirty("Volume Shape Moved");
                BakedForLocation_Version = -1;
                _previousPosition = transform.position;
            }
        }

        public void Inspect()
        {
            pegi.nl();

            "Material Prototype".edit(ref _bakeMaterial).nl();

            "Material Instance".write(_workingInstance);

            pegi.nl();

            if ("Render".Click())
            {
                BakedForLocation_Version = -1;
                gameObject.SetActive(true);
                enabled = true;
            }
        }
    }

    [PEGI_Inspector_Override(typeof(VolumeShapeDraw))] internal class VolumeShapeDrawInspectorOverride : PEGI_Inspector_Override { }

}
