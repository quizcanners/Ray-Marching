using System.Collections;
using System.Collections.Generic;
using PlayerAndEditorGUI;
using QuizCannersUtilities;
using UnityEngine;

#if UNITY_EDITOR
using UnityEditor;
#endif

namespace RayMarching
{
    
    [ExecuteAlways]
    public class RayMarchingObject : MonoBehaviour, IPEGI
    {

        public string variableName;

        private ShaderProperty.VectorValue positionAndSize;
        private ShaderProperty.VectorValue sizeCubic;
        private ShaderProperty.VectorValue repeatProps;

        [SerializeField] private QcUtils.DynamicRangeFloat _size = new QcUtils.DynamicRangeFloat(0.01f, 1000f, 1);

        public GameObject RenderingVolume;

        void InitializeProperties()
        {
            positionAndSize = new ShaderProperty.VectorValue(variableName);
            sizeCubic = new ShaderProperty.VectorValue(variableName+"_Size");
            repeatProps = new ShaderProperty.VectorValue(variableName + "_Reps");
        }

        void OnEnable()
        {
            InitializeProperties();

            if (RenderingVolume)
                RenderingVolume.SetActive(!Application.isPlaying);
        }

        // Update is called once per frame
        void Update()
        {

            positionAndSize.GlobalValue = transform.position.ToVector4(transform.localScale.x);
            sizeCubic.GlobalValue = transform.localScale.ToVector4(0);

            float repeat = 10 + 5 * transform.localScale.x;
            repeatProps.GlobalValue = new Vector4(repeat, repeat*0.5f, 1f/repeat, 0);

            //float2 repeat;
            //repeat.x = 10 + 5 * posNsize.w;
            //repeat.y = repeat * 0.5;
        }

        public bool Inspect()
        {
            if ("Name".editDelayed(ref variableName).nl())
                InitializeProperties();

            if (!RenderingVolume)
                "Rendering volume".edit(ref RenderingVolume).nl();

            if (_size.Inspect())
                transform.localScale = Vector3.one * _size.Value;

            return false;
        }
    }




#if UNITY_EDITOR
    [CustomEditor(typeof(RayMarchingObject))]
    public class RayMarchingObjectDrawer : PEGI_Inspector_Mono<RayMarchingObject> { }
#endif

}