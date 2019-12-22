using PlayerAndEditorGUI;
using QuizCannersUtilities;
using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace NodeNotes.RayTracing
{
    
    [ExecuteAlways]
    public class PrimitiveObject : MonoBehaviour, IPEGI, ICfg, ILinkedLerping
    {

        public string variableName;

        [SerializeField] private QcUtils.DynamicRangeFloat _size = new QcUtils.DynamicRangeFloat(0.01f, 5f, 1);
        [SerializeField] private Color color = Color.gray;
        [SerializeField] private float roughtness = 0.5f;
        [SerializeField] private MaterialType matType = MaterialType.dialectric;

        public enum MaterialType { disabled = 0, dialectric = 1, metallic = 2, emissive = 3, glass = 4 }

        private ShaderProperty.VectorValue positionAndMat;
        private ShaderProperty.VectorValue sizeAndNothing;
        private ShaderProperty.VectorValue colorAndRoughness;

        private void SetShaderValues()
        {
            var tf = transform;
            var localScaleForShader = tf.localScale * 0.5f;

            positionAndMat.GlobalValue = tf.position.ToVector4((int)matType);
            sizeAndNothing.GlobalValue = localScaleForShader.ToVector4();
            colorAndRoughness.GlobalValue = color.Alpha(roughtness);
        }

        void InitializeProperties()
        {
            if (positionAndMat == null)
            {
                positionAndMat = new ShaderProperty.VectorValue(variableName);
                sizeAndNothing = new ShaderProperty.VectorValue(variableName + "_Size");
                colorAndRoughness = new ShaderProperty.VectorValue(variableName + "_Mat");
            }
        }
        
        void OnEnable()
        {
            InitializeProperties();

            /*if (RenderingVolume)
                RenderingVolume.SetActive(!Application.isPlaying);*/
        }

        private bool _isDirty = false;

        #region Inspector

        public bool Inspect()
        {
            var changed = false;

            pegi.toggleDefaultInspector(this).nl();

            if ("Name".editDelayed(ref variableName).nl(ref changed))
                InitializeProperties();
            
            if (_size.Inspect().nl(ref changed))
                transform.localScale = Vector3.one * _size.Value;

            "Color".edit(ref color).nl(ref changed); // = Color.gray;
            "Roughness".edit(ref roughtness, 0, 1).nl(ref changed);

            "Surface".editEnum(ref matType).nl(ref changed);

            if (changed && RayRenderingManager.instance)
                RayRenderingManager.instance.SetDirty("Inspector");

            if (!RayRenderingManager.instance)
                "No manager Singleton".writeWarning();

            if (changed)
                _isDirty = true;

            return changed;
        }

        #endregion

        #region Linked Lerp




        // Update is called once per frame
        void Update()
        {

            var tf = transform;
            var localScaleForShader = tf.localScale * 0.5f;

            if (_isDirty || (Vector3.Distance(positionAndMat.GlobalValue, tf.position) +
                             Vector3.Distance(localScaleForShader, sizeAndNothing.latestValue.XYZ())) > float.Epsilon * 100000)
            {
                _isDirty = false;

                SetShaderValues();

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
            var cody = new CfgEncoder()
                .Add("t", (int)matType)
                .Add("col", color)
                .Add("gl", roughtness);

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

            return cody;
        }
        
        public bool Decode(string tg, string data)
        {
            switch (tg)
            {
                case "pos": lrpPosition.TargetValue = data.ToVector3(); break;
                case "size": lrpScale.TargetValue = data.ToVector3(); break;
                //case "mat": _material.Decode(data); break;
                case "t": matType = (MaterialType)data.ToInt(); break;
                case "col": color = data.ToColor(); break;
                case "gl": roughtness = data.ToFloat(); break;
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