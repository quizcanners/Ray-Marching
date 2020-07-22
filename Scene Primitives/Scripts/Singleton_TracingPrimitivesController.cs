using UnityEngine;
using System;
using QuizCanners.Migration;
using QuizCanners.Lerp;
using QuizCanners.Utils;
using System.Collections.Generic;
using QuizCanners.Inspect;
using static QuizCanners.RayTracing.QcRTX;
using PainterTool;

namespace QuizCanners.RayTracing
{
    [ExecuteAlways]
    public class Singleton_TracingPrimitivesController : Singleton.BehaniourBase, ILinkedLerping, ICfg, IPEGI, IPEGI_Handles
    {
        [SerializeField] internal SO_PrimitiveMaterial primitiveMaterials;
        [SerializeField] internal TracingPrimitives_Dynamic dynamicObjects = new();

        [SerializeField] internal DictionaryOfArrays objectArrays;

        [SerializeField] protected List<C_RayRendering_PrimitiveObject> spheres;
        [SerializeField] protected List<C_RayRendering_PrimitiveObject> lights;
        [SerializeField] protected List<C_RayRendering_PrimitiveObject> subtractiveCubes;

        [SerializeField] private Color _floorColor = Color.gray;
        
        private readonly ShaderProperty.ColorFloat4Value FLOOR_COLOR = new("RAY_FLOOR_Mat");

        private readonly Gate.Integer _arrangementVersion = new();
        private readonly Gate.Integer _volumeVersion = new();

        const string CUBE_ARRAY_NAME = "RayMarchCube";

        protected Singleton_EnvironmentElementsManager GetMgmt() => Singleton.Get<Singleton_EnvironmentElementsManager>();

        public void GetCubesInsideVolume(int count, Vector3 center, Vector3 size, out List<C_RayRendering_PrimitiveObject> objects)
        {
            objects = new List<C_RayRendering_PrimitiveObject>();

            if (objectArrays.TryGetValue(CUBE_ARRAY_NAME, out GeometryObjectArray cubes)) 
            {
                
            }
        }

        internal void RegisterToArray(C_RayRendering_PrimitiveObjectForArray primitive) 
        {
            if (primitive.arrayVariableName.IsNullOrEmpty())
                return;

            if (!objectArrays.TryGetValue(primitive.arrayVariableName, out var arr))
            {
                Debug.LogError("Primitive Array {0} not found".F(primitive.arrayVariableName));
                return;
            }

            if (!arr.registeredPrimitives.Contains(primitive)) 
               arr.registeredPrimitives.Add(primitive);
        }

        protected void Update()
        {
            var raySrv = Singleton.Get<Singleton_RayRendering>();

            if (!raySrv)
                return;

            var mgmt = GetMgmt();

            var vol = C_VolumeTexture.LatestInstance;

            if ((mgmt && _arrangementVersion.TryChange(mgmt.ArrangementVersion)) | (vol && _volumeVersion.TryChange(vol.LocationVersion)))
            {
                bool changed = false;

                foreach (var pair in objectArrays) 
                {
                    GeometryObjectArray el = pair.Value;
                    UpdateShapes(el.registeredPrimitives, el.ShapeToReflect);
                    el.PassElementsToShader();
                }

                UpdateShapes(spheres, Shape.Sphere);
                UpdateShapes(lights, Shape.AmbientLightSource);
                UpdateShapes(subtractiveCubes, Shape.SubtractiveCube);

                void UpdateShapes<T>(List<T> shapes, Shape shape) where T: C_RayRendering_StaticPrimitive
                {
                    for (int i = 0; i < shapes.Count; i++)
                    {
                        T el = shapes[i];
                        if (el)
                            changed |= el.TryReflect(mgmt.GetInstanceForShape(shape, i));
                    }
                }

                if (changed && raySrv.TargetIsScreenBuffer)
                {
                    raySrv.SetBakingDirty();
                }
            }
        }

        void LateUpdate() 
        {
            dynamicObjects.ManagedUpdate();
        }


        protected override void OnAfterEnable()
        {
            base.OnAfterEnable();
            FLOOR_COLOR.GlobalValue = _floorColor;
        }

        #region Encode & Decode

        public void DecodeTag(string tg, CfgData data)
        {
            switch (tg)
            {
                case "spheres": data.TryToListElements(spheres); break;
                case "lights": data.TryToListElements(lights); break;
                case "subCubes": data.TryToListElements(subtractiveCubes); break;
            }
        }

        public CfgEncoder Encode() => new CfgEncoder()
            .Add("spheres", spheres)
            .Add("lights", lights)
            .Add("subCubes", subtractiveCubes);

        #endregion

        #region Linked Lerp

        public void Portion(LerpData ld)
        {
            foreach (var arr in objectArrays)
                arr.Value.Portion(ld);

            spheres.Portion(ld);
            lights.Portion(ld);
            subtractiveCubes.Portion(ld);
        }

        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            foreach (var arr in objectArrays)
                arr.Value.Lerp(ld, canSkipLerp);

            spheres.Lerp(ld, canSkipLerp);
            lights.Lerp(ld, canSkipLerp);
            subtractiveCubes.Lerp(ld, canSkipLerp);
        }

        #endregion

        #region Inspector

        public override string ToString() => "Primitives";
        public override string InspectedCategory => nameof(RayTracing);

        [SerializeField] private pegi.EnterExitContext context = new();
        readonly pegi.CollectionInspectorMeta _arrays = new("Object Arrays");

        public override void Inspect()
        {
            using (context.StartContext())
            {
                pegi.Nl();
                if (context.IsAnyEntered == false)
                {
                    if ("Floor Color".PegiLabel().Edit(ref _floorColor).Nl())
                        FLOOR_COLOR.GlobalValue = _floorColor;
                }

                pegi.Nl();

                "Dynamic Objects".PegiLabel().Enter_Inspect(dynamicObjects).Nl();
                _arrays.Enter_Dictionary(objectArrays).Nl();
                "Speheres".PegiLabel().Enter_List(spheres).Nl();
                "Lights".PegiLabel().Enter_List(lights).Nl();
                "Subtractive Cubes".PegiLabel().Enter_List(subtractiveCubes).Nl();
                "Materials".PegiLabel().Edit_Enter_Inspect(ref primitiveMaterials).Nl();
            }
        }

        public void OnSceneDraw()
        {
            foreach (var a in objectArrays) 
            {
                a.Value.OnSceneDraw_Nested();
            }

            dynamicObjects.OnSceneDraw_Nested();
        }

        public void OnDrawGizmos() => this.OnSceneDraw_Nested();

        #endregion

        [Serializable] internal class DictionaryOfArrays : SerializableDictionary<string, GeometryObjectArray> {}
    }
    
    [PEGI_Inspector_Override(typeof(Singleton_TracingPrimitivesController))] internal class TracingPrimitivesControllerDrawer : PEGI_Inspector_Override { }
}
