using UnityEngine;
using QuizCanners.Inspect;
using QuizCanners.Migration;
using QuizCanners.Lerp;
using QuizCanners.Utils;
using static QuizCanners.RayTracing.TracingPrimitives;

namespace QuizCanners.RayTracing
{

    [DisallowMultipleComponent]
    [ExecuteInEditMode]
    public abstract class C_RayRendering_StaticPrimitive : C_RayRendering_PrimitiveBase, IPEGI
    {
        private PrimitiveMaterial _config = new();
        private Shape _shape;
        protected readonly Gate.DirtyVersion shaderValuesVersion = new();
        public bool IsHidden { get; private set; }

        public override Vector4 SHD_ColorAndRoughness => _config.Color.Alpha(_config.Roughtness);

        protected override Shape GetShape() => _shape;
        protected Singleton_TracingPrimitivesController GetMgmt() => Singleton.Get<Singleton_TracingPrimitivesController>();

        public void Hide() 
        {
            var myTf = transform;

            myTf.position = Vector3.down * 10;
            myTf.localScale = Vector3.one;
            myTf.rotation = Quaternion.identity;

            _config = new PrimitiveMaterial();
            IsHidden = true;
        }

        public virtual bool TryReflect(C_RayT_PrimShape_EnvironmentElement el)
        {
            if (!el)
            {
                Hide();
                return false;
            }

            IsHidden = false;

            bool changed = false;

            var targetTf = el.transform;
            var myTf = transform;

            var pos = el.PrimitiveCenter;
            changed |= myTf.position != pos;
            myTf.position = pos;

            var size = el.PrimitiveSize; 
            changed |= myTf.localScale != size;
            myTf.localScale = size;

            changed |= myTf.rotation != targetTf.rotation;
            myTf.rotation = targetTf.rotation;

            changed |= _config != el.Config;
            _config = el.Config;
            _shape = el.Shape;
            Material = el.Material;

           // ClearPosition();

            return changed;
        }

      /*  
        protected virtual void Update()
        {
            if (!Application.isEditor) 
            {
                return;
            }

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


        
        private readonly Gate.QuaternionValue _rotChange = new();
        private readonly Gate.Vector4Value _posChange = new();
        private readonly Gate.Vector3Value _sizeChange = new();

        private void ClearPosition() 
        {
            var tf = transform;

            _rotChange.TryChange(tf.rotation);
            _posChange.TryChange(tf.position);
            _sizeChange.TryChange(GetExtents());
        }

        private bool IsDirtyPosition() 
        {
            var tf = transform;

            return _rotChange.TryChange(tf.rotation) |
                    _posChange.TryChange(tf.position) |
                    _sizeChange.TryChange(GetExtents());
        }
        */
        protected virtual void OnDirty() { } 

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