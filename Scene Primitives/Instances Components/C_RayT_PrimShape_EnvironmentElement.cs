using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using UnityEngine;
using static QuizCanners.RayTracing.TracingPrimitives;

namespace QuizCanners.RayTracing
{

    [DisallowMultipleComponent]
    [ExecuteInEditMode]
    [SelectionBase]
    [AddComponentMenu("PrimitiveTracing/Scene Prefab/Primitive Shape")]
    public class C_RayT_PrimShape_EnvironmentElement : MonoBehaviour, IPEGI, INeedAttention, IPEGI_Handles
    {
        [SerializeField] private MeshRenderer _renderer;

        [SerializeField] internal Shape Shape;
        [SerializeField] private Vector3 primitiveSize = Vector3.one;
        [SerializeField] private Vector3 primitiveOffset = Vector3.zero;

        [SerializeField] private float _offsetFromCollider;

        [Header("Optional")]
        [SerializeField] private Collider _colliderAndPrimitive;

        private readonly Gate.Vector3Value _previousPosition = new();
        private readonly Gate.Vector3Value _previousSize = new();
        private readonly Gate.QuaternionValue _previousRotation = new();
        private readonly Gate.Integer _previousConfigVersion = new();

    
        [Header("Material")]
     //   [SerializeField] private bool useExclusiveMaterial;
        [SerializeField] private PrimitiveMaterial excludiveMaterial;

        [NonSerialized] public bool Registered;
        private readonly Gate.Bool _attemptToAutoregister = new();

        public float LatestVolumeOverlap;

        public bool Unrotated => Shape != Shape.Sphere && transform.rotation == Quaternion.identity;

        protected Singleton_EnvironmentElementsManager Tracking => Singleton.Get<Singleton_EnvironmentElementsManager>();

        public Vector3 PrimitiveSize
        {
            get 
            {
                var upscale = transform.lossyScale;
                return Vector3.Scale(PrimitiveUpscale, upscale);
            }
        }

        private Vector3 PrimitiveUpscale
        {
            get
            {
                if (!_colliderAndPrimitive)
                    return primitiveSize;

                switch (Shape)
                {
                    case Shape.Cube:
                        var b = _colliderAndPrimitive as BoxCollider;
                        if (b)
                        {
                            return b.size + _offsetFromCollider*Vector3.one;
                        }
                        break;
                    case Shape.Sphere:

                        var s = _colliderAndPrimitive as SphereCollider;
                        if (s)
                        {
                            return (s.radius + _offsetFromCollider) * Vector3.one;
                        }

                        break;

                }
                return primitiveSize;
            }

            set
            {
                primitiveSize = value;

                if (_colliderAndPrimitive)
                {
                    switch (Shape)
                    {
                        case Shape.Cube:
                            var b = _colliderAndPrimitive as BoxCollider;
                            if (b)
                            {
                                b.size = value;
                            }
                            break;
                        case Shape.Sphere:

                            var s = _colliderAndPrimitive as SphereCollider;
                            if (s)
                            {
                                s.radius = value.x;
                            }
                            break;
                    }
                }
            }
        }

        public Vector3 PrimitiveOffset
        {
            get
            {
                if (!_colliderAndPrimitive)
                    return primitiveOffset;

                switch (Shape)
                {
                    case Shape.Cube:
                        var b = _colliderAndPrimitive as BoxCollider;
                        if (b) return b.center;
                        break;
                    case Shape.Sphere:
                        var s = _colliderAndPrimitive as SphereCollider;
                        if (s) return s.center;
                        break;
                }
                return primitiveOffset;
            }

            private set
            {
                primitiveOffset = value;

                if (_colliderAndPrimitive)
                    switch (Shape)
                    {
                        case Shape.Cube:
                            var b = _colliderAndPrimitive as BoxCollider;
                            if (b) b.center = value;
                            break;
                        case Shape.Sphere:
                            var s = _colliderAndPrimitive as SphereCollider;
                            if (s) s.center = value;
                            break;
                    }
            }
        }

        public PrimitiveMaterialType Material => Shape == Shape.SubtractiveCube ? PrimitiveMaterialType.Subtractive : Config.MatType;

        public PrimitiveMaterial Config
        {
            get
            {
               // if (useExclusiveMaterial)
                    return excludiveMaterial;

               // _priMatCached ??= Singleton.GetValue<Singleton_TracingPrimitivesController, PrimitiveMaterial>(s=> s.primitiveMaterials[_renderer ? _renderer.sharedMaterial : null], logOnServiceMissing: false);

             //   return _priMatCached;
            }
        }
        public float GetOverlap(Vector3 worldPos, float width, float height) =>  GetOverlap(worldPos, new Vector3(width, height, width));
        

        public float GetOverlap(Vector3 bottomCenter, Vector3 volumeSize)
        {
            // TODO: Calculate overlap
            var upscale = transform.localScale;
            var size = Vector3.Scale(PrimitiveUpscale, upscale);
            Vector3 elementCenter = PrimitiveCenter;

            Vector3 elementMin = elementCenter - size * 0.5f;
            Vector3 elementMax = elementCenter + size * 0.5f;

            //elementMin.y = bottomCenter.y; // Roof will have strong affect on the underlying area

            Vector3 volumeMin = bottomCenter - new Vector3(volumeSize.x, 0, volumeSize.z)*0.5f; // volumeVec.XY().ToVector3(0);
            Vector3 volumeMax = bottomCenter + new Vector3(volumeSize.x * 0.5f, volumeSize.y, volumeSize.z * 0.5f) ;


            Vector3 overlapMin = Vector3.Max(elementMin, volumeMin);
            Vector3 overlapMax = Vector3.Min(elementMax, volumeMax);

            Vector3 overlap = Vector3.Max(Vector3.zero, overlapMax - overlapMin);

            LatestVolumeOverlap = overlap.x //* overlap.y 
                                    * overlap.z;

            //TODO: If overlay is zero, create a negative value that accounts for Size, Distance, Elevation

            if (LatestVolumeOverlap <= 0)
            {
                float distance = Vector3.Distance(elementCenter, bottomCenter);

                LatestVolumeOverlap = -Mathf.Abs((1 + distance) * 10 / (1 + size.magnitude * transform.lossyScale.magnitude));

                LatestVolumeOverlap /= GetMaterialWeight(Material);

            }
            else
            {
                LatestVolumeOverlap *= GetMaterialWeight(Material);
            }

            return LatestVolumeOverlap;
        }

        private float GetMaterialWeight(PrimitiveMaterialType type) 
        {
            return type switch
            {
                PrimitiveMaterialType.emissive => 5,
                PrimitiveMaterialType.glass => 0.3f,
                _ => 1,
            };
        }

        protected virtual void LateUpdate() 
        {
            if (!Registered && Tracking && !QcUnity.IsPartOfAPrefab(gameObject))
            {
                if (_attemptToAutoregister.TryChange(true))
                {
                    Tracking.Register(this);
                }
            }
        }

        void OnDisable() 
        {
            if (Registered)
                Tracking.UnRegister(this);

        }

        private void OnPrimitiveDirty() 
        {
            Singleton.Try<Singleton_RayRendering>(s => s.SetBakingDirty(reason: "{0} moved".F(name)), logOnServiceMissing: false);
            Singleton.Try<Singleton_EnvironmentElementsManager>(s => s.OnArrangementChanged(), logOnServiceMissing: false);
        }

        public Vector3 PrimitiveCenter
        {
            get => transform.position + transform.rotation * Vector3.Scale(PrimitiveOffset, transform.localScale);
        }



        void Reset() 
        {
            _renderer = GetComponent<MeshRenderer>();
            _colliderAndPrimitive = GetComponent<BoxCollider>();
            if (!_colliderAndPrimitive)
                _colliderAndPrimitive = GetComponent<SphereCollider>();
        }



        #region Inspector

        bool TryCheckDirty() => _previousPosition.TryChange(transform.position) | _previousSize.TryChange(transform.localScale) | _previousRotation.TryChange(transform.rotation);

      

        public void OnSceneDraw()
        {
            if (_colliderAndPrimitive)
            {
                if (_colliderAndPrimitive.GetType() == typeof(BoxCollider) && Unrotated)
                    pegi.Handle.BoxBoundsHandle(transform, Color.blue);

                return;
            }

            float displaySize = Shape == Shape.Sphere ? 2 : 1;

            pegi.Handle.DrawWireCube(PrimitiveCenter, transform.rotation, size: Vector3.Scale(PrimitiveUpscale * displaySize, transform.localScale));

        }

        public override string ToString() => gameObject.name;


        [NonSerialized] private readonly LogicWrappers.Request _primitiveDataChanged = new();
        public virtual void Inspect()
        {
            if (QcUnity.IsPartOfAPrefab(gameObject))
                "Ic a Prefab. Will not register".PegiLabel().WriteWarning().Nl();


            pegi.Nl();

            var change = pegi.ChangeTrackStart();


            (Unrotated ? "Unrotated" : "Rotated").PegiLabel("Unrotated ones have performance benefit").Nl();

            pegi.Nl();

            //if (overlapVolume > 0)
                "Latest Overlap: {0}".F(LatestVolumeOverlap).PegiLabel().Nl();

            var primitivesChange = pegi.ChangeTrackStart();

            "Primitive Mirroring (Prefab Only)".PegiLabel(pegi.Styles.ListLabel).Nl();

            "Collider".PegiLabel(60).Edit(ref _colliderAndPrimitive);

            if (!_colliderAndPrimitive)
                Icon.Refresh.Click(()=>
                {
                    _colliderAndPrimitive = GetComponent<BoxCollider>();
                    if (!_colliderAndPrimitive)
                        _colliderAndPrimitive = GetComponent<SphereCollider>();
                });

            pegi.Nl();

            if (_colliderAndPrimitive)
                "Offset From Collider".PegiLabel().Edit(ref _offsetFromCollider).Nl();

            if (!_colliderAndPrimitive)
            {
                var pOff = PrimitiveOffset;
                var upscale = PrimitiveUpscale;

              
                var changes = pegi.ChangeTrackStart();


                var max = pOff + upscale * 0.5f;
                "Max".PegiLabel().Edit(ref max).Nl();

                var min = pOff - upscale * 0.5f;
                "Min".PegiLabel().Edit(ref min).Nl();

                if (_renderer && "Match Bounding Box".PegiLabel().Click().Nl())
                {
                    min = _renderer.localBounds.min;
                    max = _renderer.localBounds.max;
                }

                if (changes) 
                {
                    PrimitiveOffset = (min + max) * 0.5f;
                    PrimitiveUpscale = (max - min);
                }
            }


            "Shape".PegiLabel(60).Edit_Enum(ref Shape).Nl();

            if (_colliderAndPrimitive)
            {
                var cType = _colliderAndPrimitive.GetType();
                if (cType == typeof(SphereCollider) && Shape != Shape.Sphere)
                {
                    "Set Shape to Sphere".PegiLabel().WriteWarning().Nl();
                }
            }

            "Renderer".PegiLabel(toolTip: "Will be used to get material. Which in turn will be used as key for Primitive's material" ,0.33f).Edit_IfNull(ref _renderer, gameObject);

            if (_renderer)
            {
             /*   "Exclusive Material".PegiLabel().ToggleIcon(ref useExclusiveMaterial).Nl().OnChanged(()=> 
                {
                    excludiveMaterial ??= new();
                });*/

               // if (useExclusiveMaterial) 
               // {
                    excludiveMaterial.Nested_Inspect();
                // }
                // else
                // {
                var mat = _renderer.sharedMaterial;
                    "Material for ".PegiLabel().Edit(ref mat).Nl(()=> _renderer.sharedMaterial  = mat);

#if UNITY_EDITOR
                if (!Singleton.Try<Singleton_TracingPrimitivesController>(sg =>
                    {
                        SO_PrimitiveMaterial mats = sg.primitiveMaterials;

                        if (!mats)
                            return;

                        if (mats.TryGetMaterial(_renderer.sharedMaterial, out PrimitiveMaterial primitiveMaterial))
                        {
                            if (!excludiveMaterial.Equals(primitiveMaterial)) 
                            {
                                if ("Override Global".PegiLabel().Click().Nl())
                                {
                                    primitiveMaterial.CopyFrom(excludiveMaterial);
                                    mats.SetToDirty();
                                }

                                if ("Override this".PegiLabel().Click().Nl()) 
                                {
                                    excludiveMaterial.CopyFrom(primitiveMaterial);
                                }
                            }
                        }
                        else if ("Create Global Material Config".PegiLabel().Click())
                        {
                            mats.CreateFor(_renderer.sharedMaterial);
                            mats.SetToDirty();
                        }

                    }))
                        "{0} not found".F(nameof(Singleton_TracingPrimitivesController)).PegiLabel().Nl();
#endif
                // }

                pegi.Nl();
            }
            

            if (primitivesChange)
                _primitiveDataChanged.CreateRequest();

            pegi.Nl();

            if (change | TryCheckDirty())
            {
                OnPrimitiveDirty();
            }
        }

        public virtual string NeedAttention()
        {
            if (!_renderer)
                return "Renderer not set";

            if (PrimitiveUpscale.x <= 0)
                return "Primitive Upscale == " + PrimitiveUpscale.x;

            if (PrimitiveUpscale.y <= 0)
                return "Primitive Upscale == " + PrimitiveUpscale.y;

            if (PrimitiveUpscale.z <= 0)
                return "Primitive Upscale == " + PrimitiveUpscale.z;

            return null;
        }

        #endregion
    }

    [PEGI_Inspector_Override(typeof(C_RayT_PrimShape_EnvironmentElement))] internal class EnvironmentElementWithPrimitiveShapeDrawer : PEGI_Inspector_Override { }
}
