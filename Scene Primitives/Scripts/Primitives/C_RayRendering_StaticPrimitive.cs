using UnityEngine;
using QuizCanners.Inspect;
using QuizCanners.Migration;
using QuizCanners.Lerp;
using QuizCanners.Utils;
using static QuizCanners.RayTracing.QcRTX;

namespace QuizCanners.RayTracing
{

    [DisallowMultipleComponent]
    [ExecuteInEditMode]
    public abstract class C_RayRendering_StaticPrimitive : C_RayRendering_PrimitiveBase, IPEGI, ICfgCustom, ILinkedLerping
    {
        private PrimitiveMaterial _config = new();
        private Shape _shape;

        public override Vector4 SHD_ColorAndRoughness => _config.Color.Alpha(_config.Roughtness);

        protected override Shape GetShape() => _shape;
        protected Singleton_TracingPrimitivesController GetMgmt() => Singleton.Get<Singleton_TracingPrimitivesController>();


       
        public void Hide() 
        {
            var myTf = transform;

            myTf.position = Vector3.down * 1000;
            myTf.localScale = Vector3.one;
            myTf.rotation = Quaternion.identity;

            _config = new PrimitiveMaterial();
        }

        public virtual bool TryReflect(C_RayT_PrimShape_EnvironmentElement el)
        {
            if (!el)
            {
                Hide();
                return false;
            }

            _isLerping = false;
        
            bool changed = false;

            var targetTf = el.transform;
            var myTf = transform;

            var upscale = targetTf.lossyScale;

            var pos = el.PrimitiveCenter;//targetTf.position + targetTf.rotation * Vector3.Scale(el.primitiveOffset, upscale);
            changed |= myTf.position != pos;
            myTf.position = pos;

            var size = el.PrimitiveSize; //Vector3.Scale(el.PrimitiveUpscale, upscale);
            changed |= myTf.localScale != size;
            myTf.localScale = size;

            changed |= myTf.rotation != targetTf.rotation;
            myTf.rotation = targetTf.rotation;

            changed |= _config != el.Config;
            _config = el.Config;
            _shape = el.Shape;
            Material = el.Material;

            ClearPosition();

            return changed;
        }

        protected virtual void Update()
        {
            bool shaderValDisrty = shaderValuesVersion.IsDirty;
            bool posChanged = IsDirtyPosition();

            if (shaderValDisrty || posChanged)
            {
                Singleton.Try<Singleton_RayRendering>(mgmt =>
                {
                    mgmt.SetBakingDirty(gameObject.name + (shaderValDisrty ? " Shader Values" : " Position Changed"));
                    shaderValuesVersion.IsDirty = false;
                    OnDirty();
                });
            }
        }


        #region Linked Lerp
        protected readonly Gate.DirtyVersion shaderValuesVersion = new();
        private readonly Gate.Vector3Value _rotChange = new();
        private readonly Gate.Vector4Value _posChange = new();
        private readonly Gate.Vector3Value _sizeChange = new();

        private void ClearPosition() 
        {
            var tf = transform;

            _rotChange.TryChange(tf.eulerAngles);
            _posChange.TryChange(tf.position);
            _sizeChange.TryChange(GetExtents());
        }

        private bool IsDirtyPosition() 
        {
            var tf = transform;

            return _rotChange.TryChange(tf.eulerAngles) |
                    _posChange.TryChange(tf.position) |
                    _sizeChange.TryChange(GetExtents());
        }

        protected virtual void OnDirty() { } 


        private LinkedLerp.TransformLocalPosition lrpPosition;
        private LinkedLerp.TransformLocalScale lrpScale;

        private bool _isLerping;

        public void Portion(LerpData ld)
        {
            if (_isLerping && lrpPosition != null)
            {
                lrpPosition.Portion(ld);
                lrpScale.Portion(ld);
            }
        }

        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            if (_isLerping && lrpPosition != null)
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
                 .Add("s", (int)_shape);


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

        public void DecodeTag(string tg, CfgData data)
        {
            switch (tg)
            {
                case "pos": lrpPosition.TargetValue = data.ToVector3(); break;
                case "size": lrpScale.TargetValue = data.ToVector3(); break;
                case "s": _shape = (Shape)data.ToInt(); break;
            }
        }

        public void DecodeInternal(CfgData data)
        {
            if (_rendy)
                _rendy.enabled = true;

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

        #region Inspector

        public virtual void Inspect()
        {
            var changed = pegi.ChangeTrackStart();

            pegi.Click(Hide).Nl();

            _config.Nested_Inspect().Nl();

            pegi.Nl();

            var mgmt = Singleton.Get<Singleton_RayRendering>();

            if (!mgmt)
                "No manager Singleton".PegiLabel().WriteWarning();

            if (changed)
            {
                shaderValuesVersion.IsDirty = true;
                if (mgmt)
                    mgmt.SetBakingDirty("Inspector");
            }
        }

        #endregion
    }
}