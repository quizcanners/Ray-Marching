using UnityEngine;
using System.Collections.Generic;
using PainterTool;

namespace QuizCanners.RayTracing
{
    using Inspect;
    using static TracingPrimitives;
    using Utils;
    using System;

    [ExecuteAlways]
    [AddComponentMenu(QcUtils.QUIZCANNERS + "/Ray Rendering/Primitives Manager")]
    public class Singleton_TracingPrimitivesController : Singleton.BehaniourBase, IPEGI, IPEGI_Handles
    {
#if UNITY_EDITOR
        [SerializeField] internal SO_PrimitiveMaterial primitiveMaterials;
#endif

        [SerializeField] internal Dynamic dynamicObjects = new();
        [SerializeField] internal GeometryObjectArray rotatedCubes;
        [SerializeField] internal GeometryObjectArray unRotatedCubes;
        [SerializeField] private Color _floorColor = Color.gray;
        
        private readonly Gate.Integer _arrangementVersion = new();
        private readonly Gate.Integer _volumeVersion = new();

        const string CUBE_ARRAY_NAME = "RayMarchCube";

        [NonSerialized] private DebugShapes _debugShapes = DebugShapes.Off; 

        private enum DebugShapes { Off, HideRotated, HideUnrotated }

        protected Singleton_EnvironmentElementsManager GetEnvironment() => Singleton.Get<Singleton_EnvironmentElementsManager>();

        protected void Update()
        {
            if (!Application.isPlaying)
                return;

            var raySrv = Singleton.Get<Singleton_RayRendering>();

            if (!raySrv)
                return;

            var environment = GetEnvironment();

            var vol = C_VolumeTexture.LatestInstance;

            if ((environment && _arrangementVersion.TryChange(ArrangementVersion)) | (vol && _volumeVersion.TryChange(vol.LocationVersion)))
            {
                bool changed = false;

                if (_debugShapes == DebugShapes.HideRotated)
                    HideAll(rotatedCubes.SortedElements);
                else
                    UpdateShapes(rotatedCubes.SortedElements, rotatedCubes.ShapeToReflect, rotated: true);
                
                if (_debugShapes == DebugShapes.HideUnrotated)
                    HideAll(unRotatedCubes.SortedElements);
                else
                    UpdateShapes(unRotatedCubes.SortedElements, unRotatedCubes.ShapeToReflect, rotated: false);
                
                rotatedCubes.PassElementsToShader();
                unRotatedCubes.PassElementsToShader();

                void HideAll<T>(List<T> shapes) where T : SortedElement
                {
                    for (int i = 0; i < shapes.Count; i++)
                    {
                        shapes[i].Hide();
                    }
                }

                void UpdateShapes<T>(List<T> shapes, Shape shape, bool rotated ) where T: SortedElement
                {
                    for (int i = 0; i < shapes.Count; i++)
                    {
                        T el = shapes[i];
                        changed |= el.TryReflect(environment.GetInstanceForShape(shape, rotated:rotated, i));
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
        }

        protected override void OnBeforeOnDisableOrEnterPlayMode(bool afterEnableCalled)
        {
            base.OnBeforeOnDisableOrEnterPlayMode(afterEnableCalled);
        }

        #region Inspector

        public override string ToString() => "Primitives";
        public override string InspectedCategory => nameof(RayTracing);

        [SerializeField] private pegi.EnterExitContext context = new();
        readonly pegi.CollectionInspectorMeta _arrays = new("Object Arrays");

        public static Singleton_TracingPrimitivesController inspected;

        public override void Inspect()
        {
            inspected = this;

            using (context.StartContext())
            {
                pegi.Nl();
                if (context.IsAnyEntered == false)
                {
                    /*
                    if ("Floor Color".PegiLabel().Edit(ref _floorColor).Nl())
                        FLOOR_COLOR.GlobalValue = _floorColor;*/

                    "Debug Shapes".PegiLabel().Edit_Enum(ref _debugShapes).Nl(()=> _arrangementVersion.ValueIsDefined = false);
                }

                pegi.Nl();

                "Dynamic Objects".PegiLabel().Enter_Inspect(dynamicObjects).Nl();
               // _arrays.Enter_Dictionary(objectArrays).Nl();
                rotatedCubes.Enter_Inspect().Nl();
                unRotatedCubes.Enter_Inspect().Nl();
                //  "Speheres".PegiLabel().Enter_List(spheres).Nl();
                //  "Lights".PegiLabel().Enter_List(lights).Nl();
                //  "Subtractive Cubes".PegiLabel().Enter_List(subtractiveCubes).Nl();
#if UNITY_EDITOR
                "Materials".PegiLabel().Edit_Enter_Inspect(ref primitiveMaterials).Nl();
#endif
            }
        }

        public void OnSceneDraw()
        {
            /*
            foreach (var a in objectArrays) 
            {
                a.Value.OnSceneDraw_Nested();
            }*/

            rotatedCubes.OnSceneDraw_Nested();
            unRotatedCubes.OnSceneDraw_Nested();
            dynamicObjects.OnSceneDraw_Nested();
        }

        public void OnDrawGizmos() => this.OnSceneDraw_Nested();

        #endregion

    }
    
    [PEGI_Inspector_Override(typeof(Singleton_TracingPrimitivesController))] internal class TracingPrimitivesControllerDrawer : PEGI_Inspector_Override { }
}
