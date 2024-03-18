using QuizCanners.Utils;
using UnityEngine;
using static QuizCanners.VolumeBakedRendering.TracingPrimitives;

namespace QuizCanners.VolumeBakedRendering
{
    [DisallowMultipleComponent]
    [ExecuteInEditMode]
    public abstract class C_RayRendering_PrimitiveBase : MonoBehaviour
    {
        [SerializeField] protected MeshRenderer _rendy;

        public PrimitiveMaterialType Material;

        public Bounds GetBoundingBox()
        {
            if (_rendy)
                return _rendy.bounds;
            else
            {
                QcLog.ChillLogger.LogErrorOnce(() => "No Renderer on " + name, "noRndy", this);

                return new Bounds(transform.position, GetExtents());
            } 
                
        }
        public Vector4 SHD_PositionAndMaterial => transform.position.ToVector4((int)Material + 0.1f);
        public virtual Vector4 SHD_Rotation
        {
            get
            {
                Quaternion rot = transform.rotation;
                if (GetShape() == Shape.Capsule)
                    rot *= Quaternion.Euler(-35, 0, 45);

                return new Vector4(-rot.x, -rot.y,
                    -rot.z + 0.0001f // There is an error at Euler.z=-90
                    , rot.w);
            }
        }
        public Vector4 SHD_Extents => GetExtents().ToVector4();
        public abstract Vector4 SHD_ColorAndRoughness { get; }

        protected abstract Shape GetShape();

        public Vector3 GetExtents()
        {
            var scale = transform.localScale;

            return GetShape() switch
            {
                Shape.SubtractiveCube => scale * 0.5f,
                Shape.Capsule => new Vector3(Mathf.Min(scale.x,scale.z) * 0.5f, scale.y * 0.25f, Mathf.Min(scale.x, scale.z) * 0.5f),
                Shape.Cube => scale * 0.5f,
                Shape.Sphere => scale.x * Vector3.one,
                _ => scale,
            };
        }

        protected virtual void OnEnable()
        {
            if (!_rendy)
                _rendy = GetComponent<MeshRenderer>();
        }

    }
}