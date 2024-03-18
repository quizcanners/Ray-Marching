using UnityEngine;
using QuizCanners.Utils;
using QuizCanners.Inspect;

namespace QuizCanners.VolumeBakedRendering
{
    public static partial class TracingPrimitives
    {

        public class SortedElement : IPEGI, IPEGI_ListInspect
        {
            public Vector3 Position;
            public Quaternion Rotation;
            public Vector3 Size;
         
            public Bounds BoundingBox;

            public C_RayT_PrimShape Original { get; private set; }

            public PrimitiveMaterialType Material => Original.Material;
            public Shape Shape => Original.Shape;
            public PrimitiveMaterial Config => Original.Config; // new();

            protected readonly Gate.DirtyVersion shaderValuesVersion = new();

         

            public Vector4 SHD_PositionAndMaterial => Position.ToVector4((int)Material + 0.1f);

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



            public void Reflect(C_RayT_PrimShape el)
            {
                Original = el;

                Position = el.PrimitiveCenter;

                var size = el.PrimitiveSize;

                if (el.Shape == Shape.Cube)
                    size *= 0.5f;

                Size = size;

                Rotation = el.transform.rotation;

                BoundingBox = el.GetBounds();
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
*/

            #region Inspector
            public override string ToString() => Original ? Original.gameObject.name : "Error, showing object that was destroyed";

            public void Inspect()
            {
                var changed = pegi.ChangeTrackStart();


                pegi.ClickHighlight(Original);

                pegi.Nl();

                Config.Nested_Inspect().Nl();

                pegi.Nl();

                var mgmt = Singleton.Get<Singleton_QcRendering>();

                if (!mgmt)
                    "No manager Singleton".PegiLabel().WriteWarning();

                if (changed)
                {
                    shaderValuesVersion.IsDirty = true;
                    if (mgmt)
                        mgmt.SetBakingDirty("Inspector", invalidateResult: true);
                }
            }

            public void InspectInList(ref int edited, int index)
            {
                ToString().PegiLabel().Write();


                pegi.ClickHighlight(Original);

                if (Icon.Enter.Click())
                    edited = index;

            }

            #endregion

        }
    }
}