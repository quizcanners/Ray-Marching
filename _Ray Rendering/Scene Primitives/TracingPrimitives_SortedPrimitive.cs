using UnityEngine;
using QuizCanners.Utils;
using QuizCanners.Inspect;

namespace QuizCanners.RayTracing
{

    public static partial class TracingPrimitives
    {

        public class SortedElement : IPEGI
        {
            public PrimitiveMaterialType Material;
            public Vector3 Position;
            public Quaternion Rotation;
            public Vector3 Size;
            public Shape Shape;
            public Bounds BoundingBox;

            public PrimitiveMaterial Config = new();

            protected readonly Gate.DirtyVersion shaderValuesVersion = new();

            public bool IsHidden { get; private set; } = true;

            public Vector4 SHD_PositionAndMaterial => Position.ToVector4((int)Material + 0.1f);

            public void Hide()
            {
                Position = Vector3.down * 100;
                Size = Vector3.one;
                Rotation = Quaternion.identity;

                Config = new PrimitiveMaterial();
                IsHidden = true;
            }

            public bool TryReflect(C_RayT_PrimShape_EnvironmentElement el)
            {
                if (!el)
                {
                    Hide();
                    return false;
                }

                IsHidden = false;

                bool changed = false;

                var pos = el.PrimitiveCenter;
                changed |= Position != pos;
                Position = pos;

                var size = el.PrimitiveSize;

                if (el.Shape == Shape.Cube)
                    size *= 0.5f;

                changed |= Size != size;
                Size = size;

                var rpt = el.transform.rotation;
                changed |= Rotation != rpt;
                Rotation = rpt;

                changed |= Config != el.Config;
                Config = el.Config;
                Shape = el.Shape;
                Material = el.Material;

                BoundingBox = el.GetBounds();

                return changed;
            }

            /*
            public Vector3 GetExtents()
            {
                return Shape switch
                {
                    Shape.SubtractiveCube => Scale * 0.5f,
                    Shape.Capsule => new Vector3(Mathf.Min(Scale.x, Scale.z) * 0.5f, Scale.y * 0.25f, Mathf.Min(Scale.x, Scale.z) * 0.5f),
                    Shape.Cube => Vector3.one * Scale.MaxAbs() * 0.5f,
                    Shape.Sphere => Scale.x * Vector3.one,
                    _ => Scale,
                };
            }




            public Bounds GetBoundingBox()
            {
                return BoundingBox; //new Bounds(Position, GetExtents());
            }*/

            public void Inspect()
            {
                var changed = pegi.ChangeTrackStart();

                pegi.Click(Hide).Nl();

                Config.Nested_Inspect().Nl();

                pegi.Nl();

                var mgmt = Singleton.Get<Singleton_RayRendering>();

                if (!mgmt)
                    "No manager Singleton".PegiLabel().WriteWarning();

                if (changed)
                {
                    shaderValuesVersion.IsDirty = true;
                    if (mgmt)
                        mgmt.SetBakingDirty("Inspector", invalidateResult: true);
                }
            }

            public virtual Vector4 SHD_Rotation
            {
                get
                {
                    Quaternion rot = Rotation;
                    if (Shape == Shape.Capsule)
                        rot *= Quaternion.Euler(-35, 0, 45);

                    return new Vector4(-rot.x, -rot.y,
                        -rot.z + 0.0001f // There is an error at Euler.z=-90
                        , rot.w);
                }
            }

           // public Vector4 SHD_Extents => BoundingBox.extents;//GetExtents().ToVector4();
            public Vector4 SHD_ColorAndRoughness => Config.Color.Alpha(Config.Roughtness);

        }
    }
}