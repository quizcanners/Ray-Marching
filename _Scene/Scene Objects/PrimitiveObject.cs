using UnityEngine;
using QuizCanners.Inspect;
using QuizCanners.Migration;
using QuizCanners.Lerp;
using QuizCanners.Utils;


namespace QuizCanners.RayTracing
{
    
    [ExecuteAlways]
    public class PrimitiveObject : MonoBehaviour, IPEGI, ICfgCustom, ILinkedLerping
    {
        public string variableName;
        public Shape shape;

        [SerializeField] private QcUtils.DynamicRangeFloat _size = new QcUtils.DynamicRangeFloat(0.01f, 5f, 1);
        [SerializeField] private Color color = Color.gray;
        [SerializeField] private float roughtness = 0.5f;
        [SerializeField] private MaterialType matType = MaterialType.dialectric;

        public Vector3 GetSize() 
        {
            switch(shape) 
            {
                case Shape.Cube: return transform.localScale * 0.5f;
                case Shape.Sphere: return transform.localScale.x * Vector3.one;
                default: return transform.localScale;
            }
        }

        public enum MaterialType { disabled = 0, dialectric = 1, metallic = 2, emissive = 3, glass = 4 }

        private ShaderProperty.VectorValue positionAndMat;
        private ShaderProperty.VectorValue sizeAndNothing;
        private ShaderProperty.VectorValue colorAndRoughness;

        private void SetShaderValues()
        {
            var tf = transform;
            positionAndMat.GlobalValue = tf.position.ToVector4((int)matType);
            sizeAndNothing.GlobalValue = GetSize().ToVector4();
            colorAndRoughness.GlobalValue = color.Alpha(roughtness);
        }

        private void InitializeProperties()
        {
            if (positionAndMat == null)
            {
                positionAndMat = new ShaderProperty.VectorValue(variableName);
                sizeAndNothing = new ShaderProperty.VectorValue(variableName + "_Size");
                colorAndRoughness = new ShaderProperty.VectorValue(variableName + "_Mat");
            }
        }

        private void OnEnable()
        {
            InitializeProperties();

            /*if (RenderingVolume)
                RenderingVolume.SetActive(!Application.isPlaying);*/
        }

        private bool _isDirty;

        #region Inspector

        public void Inspect()
        {
            pegi.nl();

            "Shape".editEnum(ref shape).nl();

           //if (shape == Shape.Cube)
             //   "For Cube put position in the bottom courner".writeHint();

            if ("Name".editDelayed(60, ref variableName))
                InitializeProperties();

            if (gameObject.name != variableName && "Set GO name".Click())
                gameObject.name = variableName;

            pegi.nl();

            var changed = pegi.ChangeTrackStart();

            _size.Inspect();



            if (changed)
            {
                transform.localScale = Vector3.one * _size.Value;
            }

            pegi.nl();

            "Color".edit(60, ref color).nl(); // = Color.gray;
            "Roughness".edit(ref roughtness, 0, 1).nl();

            "Surface".editEnum(ref matType).nl();

          
               

            if (!RayRenderingManager.instance)
                "No manager Singleton".writeWarning();

            if (changed)
            {
                _isDirty = true;
                if (RayRenderingManager.instance)
                    RayRenderingManager.instance.SetBakingDirty("Inspector");
            }
        }

        #endregion

        #region Linked Lerp




        // Update is called once per frame
        private void Update()
        {

            var tf = transform;
            var localScaleForShader = tf.localScale * 0.5f;

            if (_isDirty || (Vector3.Distance(positionAndMat.GlobalValue, tf.position) +
                             Vector3.Distance(localScaleForShader, sizeAndNothing.latestValue.XYZ())) > float.Epsilon * 100000)
            {
                _isDirty = false;

                SetShaderValues();

                if (RayRenderingManager.instance)
                    RayRenderingManager.instance.SetBakingDirty(gameObject.name);
            }
        }

        private LinkedLerp.TransformLocalPosition lrpPosition;
        private LinkedLerp.TransformLocalScale lrpScale;

        private bool _isLerping;

        public void Portion(LerpData ld)
        {
            if (_isLerping && lrpPosition!= null)
            {
                lrpPosition.Portion(ld);
                lrpScale.Portion(ld);
            }
        }

        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            if (_isLerping && lrpPosition!= null)
            {
                lrpPosition.Lerp(ld, canSkipLerp);
                lrpScale.Lerp(ld, canSkipLerp);
                if (ld.Done)
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
        
        public void Decode(string tg, CfgData data)
        {
            switch (tg)
            {
                case "pos": lrpPosition.TargetValue = data.ToVector3(); break;
                case "size": lrpScale.TargetValue = data.ToVector3(); break;
                //case "mat": _material.Decode(data); break;
                case "t": matType = (MaterialType)data.ToInt(); break;
                case "col": color = data.ToColor(); break;
                case "gl": roughtness = data.ToFloat(); break;
            }
        }

        public void Decode(CfgData data)
        {
            _isLerping = true;
            if (lrpPosition == null)
            {
                var transform1 = transform;
                lrpPosition = new LinkedLerp.TransformLocalPosition(transform1, 100)
                {
                    lerpMode = LinkedLerp.LerpSpeedMode.Unlimited
                };

                lrpScale = new LinkedLerp.TransformLocalScale(transform1, 100)
                {
                    lerpMode = LinkedLerp.LerpSpeedMode.Unlimited
                };
            }
            
            new CfgDecoder(data).DecodeTagsFor(this);
        }

        #endregion

        public enum Shape 
        {
            Cube, Sphere
        } 
    }

    [PEGI_Inspector_Override(typeof(PrimitiveObject))] internal class RayMarchingObjectDrawer : PEGI_Inspector_Override { }

}