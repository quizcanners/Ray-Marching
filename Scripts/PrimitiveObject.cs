using PlayerAndEditorGUI;
using QuizCannersUtilities;
using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace RayMarching
{
    
    [ExecuteAlways]
    public class PrimitiveObject : MonoBehaviour, IPEGI
    {

        public string variableName;

        private ShaderProperty.VectorValue positionAndSize;
        private ShaderProperty.VectorValue sizeAndMaterial;
        private ShaderProperty.VectorValue repeatProps;

        [SerializeField] private QcUtils.DynamicRangeFloat _size = new QcUtils.DynamicRangeFloat(0.01f, 1000f, 1);

        [SerializeField] private QcUtils.DynamicRangeFloat _material = new QcUtils.DynamicRangeFloat(0.01f, 5f, 0.2f);
        

        public GameObject RenderingVolume;

        void InitializeProperties()
        {
            positionAndSize = new ShaderProperty.VectorValue(variableName);
            sizeAndMaterial = new ShaderProperty.VectorValue(variableName+"_Size");
            //repeatProps = new ShaderProperty.VectorValue(variableName + "_Reps");
        }

        void OnEnable()
        {
            InitializeProperties();

            if (RenderingVolume)
                RenderingVolume.SetActive(!Application.isPlaying);
        }

        private bool _isDirty = false;

        // Update is called once per frame
        void Update()
        {

            var tf = transform;

            if (_isDirty || (Vector3.Distance(positionAndSize.GlobalValue, tf.position) + 
                 Vector3.Distance(tf.localScale, sizeAndMaterial.latestValue.XYZ()))>float.Epsilon * 10)
            {
                _isDirty = false;

                positionAndSize.GlobalValue = tf.position.ToVector4(transform.localScale.x);
                sizeAndMaterial.GlobalValue = tf.localScale.ToVector4(_material.Value);

                if (RayRenderingManager.instance)
                    RayRenderingManager.instance.SetDirty();
            }


           // float repeat = 10 + 5 * tf.localScale.x;
           // repeatProps.GlobalValue = new Vector4(repeat, repeat*0.5f, 1f/repeat, 0);
        }

        public bool Inspect()
        {
            var changed = false;

            pegi.toggleDefaultInspector(this).nl();

            if ("Name".editDelayed(ref variableName).nl(ref changed))
                InitializeProperties();

            if (!RenderingVolume)
                "Rendering volume".edit(ref RenderingVolume).nl(ref changed);

            if (_size.Inspect().nl(ref changed))
                transform.localScale = Vector3.one * _size.Value;

            "Material:".nl();
            _material.Inspect().nl(ref changed);

            if (changed && RayRenderingManager.instance)
                RayRenderingManager.instance.SetDirty();

            if (changed)
                _isDirty = true;

            return changed;
        }
    }




#if UNITY_EDITOR
    [CustomEditor(typeof(PrimitiveObject))]
    public class RayMarchingObjectDrawer : PEGI_Inspector_Mono<PrimitiveObject> { }
#endif

}