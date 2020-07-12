using PlayerAndEditorGUI;
using QuizCannersUtilities;
using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace RayMarching
{
    
    [ExecuteAlways]
    public class PrimitiveObject : MonoBehaviour, IPEGI, ICfg, ILinkedLerping
    {

        public string variableName;
        
        [SerializeField] private QcUtils.DynamicRangeFloat _size = new QcUtils.DynamicRangeFloat(0.01f, 5f, 1);
        [SerializeField] private QcUtils.DynamicRangeFloat _material = new QcUtils.DynamicRangeFloat(0.01f, 5f, 0.2f);

        private ShaderProperty.VectorValue positionAndSize;
        private ShaderProperty.VectorValue sizeAndMaterial;
        private ShaderProperty.VectorValue rotationValue;

        void InitializeProperties()
        {
            if (positionAndSize == null)
            {
                positionAndSize = new ShaderProperty.VectorValue(variableName);
                sizeAndMaterial = new ShaderProperty.VectorValue(variableName + "_Size");
                rotationValue = new ShaderProperty.VectorValue(variableName + "_Rot");
            }
        }

        public GameObject RenderingVolume;


        void OnEnable()
        {
            InitializeProperties();

            /*if (RenderingVolume)
                RenderingVolume.SetActive(!Application.isPlaying);*/
        }

        private bool _isDirty = false;
        
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
                RayRenderingManager.instance.SetDirty("Inspector");

            if (!RayRenderingManager.instance)
                "No manager Singleton".writeWarning();

            if (changed)
                _isDirty = true;

            return changed;
        }

        #region Linked Lerp




        // Update is called once per frame
        void Update()
        {

            var tf = transform;

            var localScaleForShader = tf.localScale * 0.5f;

            if (_isDirty || (Vector3.Distance(positionAndSize.GlobalValue, tf.position) +
                             Vector3.Distance(localScaleForShader, sizeAndMaterial.latestValue.XYZ())) > float.Epsilon * 100000)
            {
                _isDirty = false;

                positionAndSize.GlobalValue = tf.position.ToVector4(transform.localScale.x);
                sizeAndMaterial.GlobalValue = localScaleForShader.ToVector4(_material.Value);
                rotationValue.GlobalValue = tf.eulerAngles.ToVector4();

                if (RayRenderingManager.instance)
                    RayRenderingManager.instance.SetDirty(gameObject.name);
            }
        }

        LinkedLerp.TransformLocalPosition lrpPosition;
        LinkedLerp.TransformLocalScale lrpScale;

        private bool _isLerping;

        public void Portion(LerpData ld)
        {
            if (_isLerping)
            {
                lrpPosition.Portion(ld);
                lrpScale.Portion(ld);
            }
        }

        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            if (_isLerping)
            {
                lrpPosition.Lerp(ld);
                lrpScale.Lerp(ld);
                if (ld.MinPortion == 1)
                    _isLerping = false;
            }
        }

        #endregion

        #region Encode & Decode
        public CfgEncoder Encode()
        {
            var cody = new CfgEncoder();
            if (_isLerping)
            {
                cody.Add("pos", lrpPosition.TargetValue)
                    .Add("size", lrpScale.TargetValue);
            }
            else
            {
                cody.Add("pos", transform.localPosition)
                    .Add("size", transform.localScale);
            
            }

            cody.Add("mat", _material);

            return cody;
        }
        
        public bool Decode(string tg, string data)
        {
            switch (tg)
            {
                case "pos": lrpPosition.TargetValue = data.ToVector3(); break;
                case "size": lrpScale.TargetValue = data.ToVector3(); break;
                case "mat": _material.Decode(data); break;
                default: return false;
            }

            return true;
        }

        public void Decode(string data)
        {
            _isLerping = true;

            if (lrpPosition == null)
            {
                lrpPosition = new LinkedLerp.TransformLocalPosition(transform, 100);
                lrpPosition.lerpMode = LinkedLerp.LerpSpeedMode.Unlimited;
                lrpScale = new LinkedLerp.TransformLocalScale(transform, 100);
                lrpScale.lerpMode = LinkedLerp.LerpSpeedMode.Unlimited;
            }

            new CfgDecoder(data).DecodeTagsFor(this);
        }

        #endregion
    }




#if UNITY_EDITOR
    [CustomEditor(typeof(PrimitiveObject))]
    public class RayMarchingObjectDrawer : PEGI_Inspector_Mono<PrimitiveObject> { }
#endif

}