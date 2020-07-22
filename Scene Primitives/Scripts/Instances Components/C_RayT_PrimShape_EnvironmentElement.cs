using QuizCanners.Inspect;
using QuizCanners.Migration;
using QuizCanners.Utils;
using System;
using UnityEngine;
using static QuizCanners.RayTracing.QcRTX;
using static UnityEngine.GraphicsBuffer;

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

        [Header("Optional")]
        [SerializeField] private Collider _colliderAndPrimitive;

        private readonly Gate.Vector3Value _previousPosition = new();
        private readonly Gate.Vector3Value _previousSize = new();
        private readonly Gate.Vector3Value _previousRotation = new();
        private readonly Gate.Integer _previousConfigVersion = new();

        [NonSerialized] private PrimitiveMaterial _priMat;
        [NonSerialized] public bool Registered;
        private readonly Gate.Bool _attemptToAutoregister = new();


       
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
                            return b.size;
                        }
                        break;
                    case Shape.Sphere:

                        var s = _colliderAndPrimitive as SphereCollider;
                        if (s)
                        {
                            return s.radius * Vector3.one;
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
                _priMat ??= Singleton.TryGetValue<Singleton_TracingPrimitivesController, PrimitiveMaterial>(s=> s.primitiveMaterials[_renderer ? _renderer.sharedMaterial : null], logOnServiceMissing: false);

                return _priMat;
            }
        }
        public float GetOverlap(Vector3 worldPos, float width, float height) 
        {
            return GetOverlap(worldPos, new Vector3(width * 0.5f, height, width * 0.5f));
            /*
            var upscale = transform.localScale;
            var size = Vector3.Scale(PrimitiveSize, upscale);
            Vector3 elementCenter = PrimitiveCenter;

            Vector3 elementMin = elementCenter - size;
            Vector3 elementMax = elementCenter + size;

            elementMin.y = worldPos.y; // Roof will have strong affect on the underlying area


            var volumeVec = new Vector3(width * 0.5f, height, width * 0.5f);

            Vector3 volumeMin = worldPos - new Vector3(volumeVec.x, 0, volumeVec.y); // volumeVec.XY().ToVector3(0);
            Vector3 volumeMax = worldPos + volumeVec;


            Vector3 overlapMin = Vector3.Max(elementMin, volumeMin);
            Vector3 overlapMax = Vector3.Min(elementMax, volumeMax);

            Vector3 overlap = Vector3.Max(Vector3.zero, overlapMax - overlapMin);

            float overlapVolume = overlap.x * overlap.y * overlap.z;

            //TODO: If overlay is zero, create a negative value that accounts for Size, Distance, Elevation

            if (overlapVolume <= 0) 
            {
                float distance = Vector3.Distance(elementCenter, worldPos);

                overlapVolume = -Mathf.Abs(((1 + distance) * 10) / (1 + size.magnitude * transform.localScale.magnitude));

                overlapVolume /= GetMaterialWeight(Material);

            } else 
            {
                overlapVolume *= GetMaterialWeight(Material);
            }

            return overlapVolume;
            */
        }

        public float GetOverlap(Vector3 worldPos, Vector3 volumeVec)
        {
            // TODO: Calculate overlap
            var upscale = transform.localScale;
            var size = Vector3.Scale(PrimitiveUpscale, upscale);
            Vector3 elementCenter = PrimitiveCenter;

            Vector3 elementMin = elementCenter - size;
            Vector3 elementMax = elementCenter + size;

            elementMin.y = worldPos.y; // Roof will have strong affect on the underlying area

            Vector3 volumeMin = worldPos - new Vector3(volumeVec.x, 0, volumeVec.y); // volumeVec.XY().ToVector3(0);
            Vector3 volumeMax = worldPos + volumeVec;


            Vector3 overlapMin = Vector3.Max(elementMin, volumeMin);
            Vector3 overlapMax = Vector3.Min(elementMax, volumeMax);

            Vector3 overlap = Vector3.Max(Vector3.zero, overlapMax - overlapMin);

            float overlapVolume = overlap.x * overlap.y * overlap.z;

            //TODO: If overlay is zero, create a negative value that accounts for Size, Distance, Elevation

            if (overlapVolume <= 0)
            {
                float distance = Vector3.Distance(elementCenter, worldPos);

                overlapVolume = -Mathf.Abs(((1 + distance) * 10) / (1 + size.magnitude * transform.localScale.magnitude));

                overlapVolume /= GetMaterialWeight(Material);

            }
            else
            {
                overlapVolume *= GetMaterialWeight(Material);
            }

            return overlapVolume;
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

            if (Registered)
            {
                if (_previousSize.TryChange(transform.localScale) | 
                    _previousPosition.TryChange(transform.position) | 
                    _previousConfigVersion.TryChange(Config.Version) |
                    _previousRotation.TryChange(transform.eulerAngles)
                    )
                    OnPrimitiveDirty();
            }
        }

        void OnDisable() 
        {
            OnPrimitiveDirty();
        }

        void OnEnable() 
        {
            OnPrimitiveDirty();
        }

        private void OnPrimitiveDirty() 
        {
            Singleton.Try<Singleton_RayRendering>(s => s.SetBakingDirty(reason: "{0} moved".F(name)), logOnServiceMissing: false);
            Singleton.Try<Singleton_EnvironmentElementsManager>(s => s.OnArrangementChanged(), logOnServiceMissing: false);
        }

        private void CopyPrimitiveData_UpdatePrefab(C_RayT_PrimShape_EnvironmentElement other) 
        {
            PrimitiveOffset = other.PrimitiveOffset;
            PrimitiveUpscale = other.PrimitiveUpscale;
            Shape = other.Shape;
            gameObject.SetToDirty();
        }

        public Vector3 PrimitiveCenter => transform.position + transform.rotation * Vector3.Scale(PrimitiveOffset, transform.localScale);

        public void OnSceneDraw()
        {
            if (_colliderAndPrimitive)
                return;

            float displaySize = Shape == Shape.Sphere ? 2 : 1; 

             pegi.Handle.DrawWireCube(PrimitiveCenter, transform.rotation, size: Vector3.Scale(PrimitiveUpscale * displaySize, transform.localScale)); 
        }

        void Reset() 
        {
            _renderer = GetComponent<MeshRenderer>();
        }



        #region Inspector

        public override string ToString() => gameObject.name;


        [NonSerialized] private readonly LogicWrappers.Request _primitiveDataChanged = new();
        public virtual void Inspect()
        {
            if (QcUnity.IsPartOfAPrefab(gameObject))
                "Ic a Prefab. Will not register".PegiLabel().WriteWarning().Nl();


            pegi.Nl();

            var change = pegi.ChangeTrackStart();

            pegi.Nl();

            var primitivesChange = pegi.ChangeTrackStart();

            "Primitive Mirroring (Prefab Only)".PegiLabel(pegi.Styles.ListLabel).Nl();

            "Collider".PegiLabel(60).Edit(ref _colliderAndPrimitive, gameObject);

            if (!_colliderAndPrimitive)
                Icon.Refresh.Click(()=>
                {
                    _colliderAndPrimitive = GetComponent<BoxCollider>();
                    if (!_colliderAndPrimitive)
                        _colliderAndPrimitive = GetComponent<SphereCollider>();
                });

            pegi.Nl();

            if (!_colliderAndPrimitive)
            {
                var pOff = PrimitiveOffset;
                "Offset".PegiLabel(60).Edit(ref pOff).Nl().OnChanged(() => PrimitiveOffset = pOff);

                var ps = PrimitiveUpscale;
                "Size".PegiLabel(60).Edit(ref ps).Nl().OnChanged(() => PrimitiveUpscale = ps);

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
                var sg = Singleton.Get<Singleton_TracingPrimitivesController>();
                if (sg)
                {
                    var mats = sg.primitiveMaterials;

                    if (!mats)
                        "{0} doesnt have Primitive Materials".F(nameof(Singleton_TracingPrimitivesController)).PegiLabel().WriteWarning().Nl();
                    else
                    {
                        if (mats.TryGetMaterial(_renderer.sharedMaterial, out PrimitiveMaterial primitiveMaterial))
                        {
                            if (primitiveMaterial.Nested_Inspect())
                                mats.SetToDirty();
                        }
                        else if ("Create Material Config".PegiLabel().Click())
                        {
                            mats.CreateFor(_renderer.sharedMaterial);
                            _priMat = null;
                        }

                        if (Icon.Refresh.Click("Refresh material"))
                            _priMat = null;
                    }
                }
                pegi.Nl();
            }
            

            if (primitivesChange)
                _primitiveDataChanged.CreateRequest();

            pegi.Nl();

            if (change)
            {
                OnPrimitiveDirty();
            }
        }

        public virtual string NeedAttention()
        {
            if (!_renderer)
                return "Renderer not set";

            return null;
        }

        #endregion
    }

    [PEGI_Inspector_Override(typeof(C_RayT_PrimShape_EnvironmentElement))] internal class EnvironmentElementWithPrimitiveShapeDrawer : PEGI_Inspector_Override { }
}
