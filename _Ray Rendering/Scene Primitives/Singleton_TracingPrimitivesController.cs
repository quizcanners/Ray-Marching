using UnityEngine;
using System.Collections.Generic;
using PainterTool;

namespace QuizCanners.VolumeBakedRendering
{
    using Inspect;
    using static TracingPrimitives;
    using Utils;
    using System;

    [ExecuteAlways]
    [AddComponentMenu(QcUtils.QUIZCANNERS + "/Qc Rendering/Primitives Manager")]
    public class Singleton_TracingPrimitivesController : Singleton.BehaniourBase, IPEGI, IPEGI_Handles
    {
#if UNITY_EDITOR
        [SerializeField] internal SO_PrimitiveMaterial primitiveMaterials;
#endif

        [SerializeField] internal Dynamic dynamicObjects = new();
        [SerializeField] internal GeometryObjectArray rotatedCubes;
        [SerializeField] internal GeometryObjectArray unRotatedCubes;
        
        private readonly Gate.Integer _arrangementVersion = new();
        private readonly Gate.Integer _volumeVersion = new();

        const string CUBE_ARRAY_NAME = "RayMarchCube";

        [NonSerialized] private DebugShapes _debugShapes = DebugShapes.Off;

        private ShapesUpdateState _updateState = ShapesUpdateState.Standby;

        private enum DebugShapes { Off, HideRotated, HideUnrotated }

        private enum ShapesUpdateState { Standby, Gouping, Ready }

        public bool IsReady => _updateState == ShapesUpdateState.Ready;

        internal void ManagedUpdate()
        {
            var raySrv = Singleton.Get<Singleton_QcRendering>();

            if (!raySrv)
                return;

            switch (_updateState)
            {
                case ShapesUpdateState.Standby:
                case ShapesUpdateState.Ready:

                    //var environment = GetEnvironment();
                    var vol = C_VolumeTexture.LatestInstance;

                    bool arrangementDirty = _arrangementVersion.TryChange(ArrangementVersion);
                    bool volumeDirty = vol && _volumeVersion.TryChange(vol.LocationVersion);

                    if (!arrangementDirty && !volumeDirty)
                        break;

                        _updateState = ShapesUpdateState.Gouping;

                    if (_debugShapes == DebugShapes.HideRotated)
                        rotatedCubes.SortedElements = new SortedElement[0];
                    else
                        UpdateShapeLists(ref rotatedCubes.SortedElements, rotatedCubes.ShapeToReflect, rotated: true);

                    if (_debugShapes == DebugShapes.HideUnrotated)
                        unRotatedCubes.SortedElements = new SortedElement[0];
                    else
                        UpdateShapeLists(ref unRotatedCubes.SortedElements, unRotatedCubes.ShapeToReflect, rotated: false);

                    rotatedCubes.StartGroupingBoxesJob();
                    unRotatedCubes.StartGroupingBoxesJob();

                    break;

                    void UpdateShapeLists(ref SortedElement[] shapes, Shape shape, bool rotated)
                    {
                        var mgmt = s_EnvironmentElements;
                        var sortedForRotatedType = mgmt.GetSortedForVolume(rotated: rotated);

                        if (!sortedForRotatedType.TryGetValue(shape, out var sortedForShape)) 
                        {
                            shapes = new SortedElement[0];
                            return;
                        }

                        var count = Mathf.Min(GeometryObjectArray.MAX_ELEMENTS_COUNT, sortedForShape.Count);

                        shapes = new SortedElement[count];

                        for (int i=0; i<count; i++) 
                        {
                            var srtEl = new SortedElement();
                            shapes[i] = srtEl;
                            srtEl.Reflect(s_EnvironmentElements.GetByIndex(sortedForShape[i]));
                        }
                    }

                case ShapesUpdateState.Gouping:

                    if (!rotatedCubes.IsGroupingDone || !unRotatedCubes.IsGroupingDone)
                        break;

                    rotatedCubes.ProcessBoxesAfterJob();
                    unRotatedCubes.ProcessBoxesAfterJob();

                    rotatedCubes.PassToShader();
                    unRotatedCubes.PassToShader();

                    _updateState = ShapesUpdateState.Ready;
                    break;
            }
        }

        void LateUpdate() 
        {
            if (QcScenes.IsAnyLoading)
                return;

            dynamicObjects.ManagedUpdate();
        }

        protected override void OnBeforeOnDisableOrEnterPlayMode(bool afterEnableCalled)
        {
            base.OnBeforeOnDisableOrEnterPlayMode(afterEnableCalled);


            rotatedCubes.Clear();
            unRotatedCubes.Clear();
        }

        #region Inspector

        public override string ToString() => "Primitives";
        public override string InspectedCategory => nameof(VolumeBakedRendering);

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
