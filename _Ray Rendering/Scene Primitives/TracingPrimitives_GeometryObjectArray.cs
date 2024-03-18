using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using System.Collections.Generic;
using Unity.Collections;
using Unity.Jobs;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    public static partial class TracingPrimitives
    {
        [Serializable]
        internal class GeometryObjectArray : IGotName, IPEGI, IPEGI_Handles
        {
            public const int MAX_ELEMENTS_COUNT = 64;

            [SerializeField] private string _parameterName;
            [SerializeField] public Shape ShapeToReflect = Shape.Cube;

            internal SortedElement[] SortedElements;

            ShaderProperty.VectorArrayValue _positionAndMaterial;
            ShaderProperty.VectorArrayValue _size;
            ShaderProperty.VectorArrayValue _colorAndRoughness;
            ShaderProperty.VectorArrayValue _rotation;

            ShaderProperty.VectorValue _boundingPositionAll;
            ShaderProperty.VectorValue _boundingExtendsAll; // W is Boxes count

            ShaderProperty.VectorArrayValue _boundingPosition;
            ShaderProperty.VectorArrayValue _boundingExtents;

            private readonly Gate.Bool _setInShader = new();

            readonly Vector4[] positionArray = new Vector4[MAX_ELEMENTS_COUNT];
            readonly Vector4[] colorArray = new Vector4[MAX_ELEMENTS_COUNT];
            readonly Vector4[] rotationArray = new Vector4[MAX_ELEMENTS_COUNT];
            readonly Vector4[] sizeArray = new Vector4[MAX_ELEMENTS_COUNT];

            readonly Vector4[] boundingPosition = new Vector4[MAX_BOUNDING_BOXES_COUNT];
            readonly Vector4[] boundingExtents = new Vector4[MAX_BOUNDING_BOXES_COUNT];


            readonly BoundingBoxCalculator _allElementsBox = new();
            private readonly List<BoundingBox> elementsToGroup = new();
            private readonly Dictionary<C_RayT_PrimitiveRoot, List<SortedElement>> elementsPreGrouped = new();
            private NativeArray<BoxForJob> boxesForJob;
            private NativeArray<BoxJobMeta> _jobMeta;
            JobHandle handle;
            BoxesJob job;

            private BoxesSortingStage _sortingStage;

            public bool IsGroupingDone => handle.IsCompleted;

            private enum BoxesSortingStage { Uninitialized, JobStarted, Completed }

            private void InitializeIfNotInitialized()
            {
                if (_setInShader.TryChange(true))
                {
                    _positionAndMaterial = new(_parameterName);
                    _size = new(_parameterName + "_Size");
                    _colorAndRoughness = new(_parameterName + "_Mat");
                    _rotation = new(_parameterName + "_Rot");
                    _boundingPosition = new(_parameterName + "_BoundPos");
                    _boundingExtents = new(_parameterName + "_BoundSize");

                    _boundingPositionAll = new(_parameterName + "_BoundPos_All");
                    _boundingExtendsAll = new(_parameterName + "_BoundSize_All");
                }
            }

            /*
            private void GroupBoundingBoxes() 
            {
                boxes.Clear();
                foreach (var prim in SortedElements) 
                {
                    if (!prim.IsHidden)
                    {
                        boxes.Add(new BoundingBox(prim));
                    }
                }

                while (boxes.Count > MAX_BOUNDING_BOXES_COUNT)
                {
                    Efficiency bestEfficiency = new();

                    for (int i = boxes.Count - 1; i >= 0; i--)
                    {
                        var toEncapsulate_I = boxes[i];

                        if (TryEncapsulate())
                        {
                            bestEfficiency = new();
                            continue;
                        }

                        bool TryEncapsulate()
                        {
                            for (int j = 0; j < i; j++)
                            {
                                if (boxes[j].TryEncapsulate(toEncapsulate_I, out float efficiency))
                                {
                                    boxes.RemoveAt(i);
                                    return true;
                                }

                                if (efficiency > bestEfficiency.Value)
                                {
                                    bestEfficiency.Value = efficiency;
                                    bestEfficiency.Index_Bigger = j;
                                    bestEfficiency.Index_Smaller = i;
                                }
                            }

                            return false;
                        }
                    }

                    if (bestEfficiency.Value > 0)
                    {
                        boxes[bestEfficiency.Index_Bigger].Encapsulate(boxes[bestEfficiency.Index_Smaller]);
                        boxes.RemoveAt(bestEfficiency.Index_Smaller);
                    } else 
                    {
                        boxes[^1].Encapsulate(boxes[^2]);
                        boxes.RemoveAt(boxes.Count - 2);
                        Debug.LogError("Failed to group boxes. Merging random");
                    }
                }
            }*/

            public void Clear() 
            {
                if (_sortingStage == BoxesSortingStage.JobStarted) 
                {
                    handle.Complete();
                }

                DisposeJob();

                _sortingStage = BoxesSortingStage.Uninitialized;
            }

            #region ViaJobs

            private void DisposeJob()
            {
                if (boxesForJob.IsCreated)
                {
                    boxesForJob.Dispose();
                    _jobMeta.Dispose();
                }
            }

            public void StartGroupingBoxesJob()
            {
                if (_sortingStage == BoxesSortingStage.JobStarted)
                {
                    Clear();
                }

                elementsToGroup.Clear();
                elementsPreGrouped.Clear();

                if (SortedElements.Length == 0) 
                {
                    _sortingStage = BoxesSortingStage.Completed;
                    return;
                }

                _sortingStage = BoxesSortingStage.JobStarted;

                var timer = QcDebug.TimeProfiler.Instance["Box Grouping"];

                List<BoxForJob> jobBoxes;

                using (timer.Last("Creating List").Start())
                {
                    jobBoxes = new();

                    foreach (SortedElement prim in SortedElements)
                    {
                        var parent = prim.Original.RootParent;

                        if (parent) 
                        {
                            elementsPreGrouped.GetOrCreate(parent).Add(prim);
                            continue;
                        }

                        Bounds bounds = prim.BoundingBox;
                        BoxForJob el = new(bounds.min, bounds.max, jobBoxes.Count);
                        jobBoxes.Add(el);
                        elementsToGroup.Add(new BoundingBox(prim));
                    }
                }

                int boxesLeftToSort = MAX_BOUNDING_BOXES_COUNT - elementsPreGrouped.Count;

                if (elementsToGroup.Count == 0 || boxesLeftToSort <=0) 
                {
                    _sortingStage = BoxesSortingStage.Completed;
                    return;
                }

                using (timer.Last("Creating Native Array and Job").Start())
                {
                    boxesForJob = new NativeArray<BoxForJob>(jobBoxes.ToArray(), Allocator.Persistent);
                }

                using (timer.Last("Creating Job").Start())
                {
                    var meta = new BoxJobMeta()
                    {
                        LoopsCounter = 1000,
                        MaxVoundingBoxesCount = boxesLeftToSort,
                    };

                    _jobMeta = new NativeArray<BoxJobMeta>(1, Allocator.Persistent);

                    job = new BoxesJob(boxesForJob, _jobMeta);
                }

                using (timer.Last("Job").Start())
                {
                    handle = job.Schedule();
                }
            }

            public void ProcessBoxesAfterJob()
            {
                if (_sortingStage == BoxesSortingStage.Completed)
                    return;

                handle.Complete();

                _sortingStage = BoxesSortingStage.Completed;

                Dictionary<int, int> finalBoxes = new();

                for (int i = 0; i < elementsToGroup.Count; i++)
                {
                    BoxForJob boxFromJob = boxesForJob[i];

                    if (!boxFromJob.IsEncapsulaed)
                        continue;

                    BoundingBox box = elementsToGroup[i];

                    HashSet<int> path = new();

                    bool matched = false;

                    do
                    {
                        if (finalBoxes.TryGetValue(boxFromJob.EncapsulatedInto, out var finalBox1))
                        {
                            elementsToGroup[finalBox1].Encapsulate(box);
                            SetPath(finalBox1);
                            matched = true;
                            break;
                        }

                        path.Add(boxFromJob.Index);

                        boxFromJob = boxesForJob[boxFromJob.EncapsulatedInto];
                        
                    } while (boxFromJob.IsEncapsulaed);

                    if (matched)
                        continue;

                    var finalBox = boxFromJob.Index;


                    elementsToGroup[finalBox].Encapsulate(box);
                    SetPath(finalBox);


                    void SetPath(int index)
                    {
                        foreach (var p in path)
                            finalBoxes[p] = index;
                    }

                }

                for (int i = elementsToGroup.Count-1; i >= 0; i--)
                {
                    if (!boxesForJob[i].IsEncapsulaed)
                        continue;

                    elementsToGroup.RemoveAt(i);
                }

                DisposeJob();
            }

            #endregion

           



            public void PassToShader() 
            {
                InitializeIfNotInitialized();

                _allElementsBox.Reset();

                int totalIndex = 0;
                int startIndex = 0;

                if (elementsToGroup.Count == 0 && elementsPreGrouped.Count == 0)
                {
                    _allElementsBox.Center = Vector3.zero;
                    _allElementsBox.Size = Vector3.one;
                }

                int boxIndex = 0;

                foreach (var group in elementsPreGrouped) 
                {
                    var list = group.Value;

                    var box = new BoundingBoxCalculator();

                    foreach (SortedElement el in list) 
                    {
                        Add(el);
                        box.Add(el.BoundingBox);
                    }

                    FinalizeBox(box.Center, box.Extents);
                }

                for (int b = 0; b < elementsToGroup.Count; b++)
                {
                    BoundingBox box = elementsToGroup[b];

                    for (int p = 0; p < box.Primitives.Count; p++)
                    {
                        SortedElement prim = box.Primitives[p];

                        Add(prim);
                    }

                    FinalizeBox(box.Calculator.Center, box.Calculator.Extents);
                }

                void Add(SortedElement prim)
                {
                    _allElementsBox.Add(prim.BoundingBox);

                    positionArray[totalIndex] = prim.SHD_PositionAndMaterial;
                    colorArray[totalIndex] = prim.SHD_ColorAndRoughness;
                    rotationArray[totalIndex] = prim.SHD_Rotation;
                    sizeArray[totalIndex] = prim.Size;//SHD_Extents;
                    totalIndex++;
                }

                void FinalizeBox(Vector3 center, Vector3 extends)
                {
                    boundingPosition[boxIndex] = center.ToVector4(startIndex);
                    boundingExtents[boxIndex] = extends.ToVector4(totalIndex);
                    startIndex = totalIndex;
                    boxIndex++;
                }

                _boundingPositionAll.GlobalValue = _allElementsBox.Center;
                _boundingExtendsAll.GlobalValue = _allElementsBox.Extents.ToVector4(elementsToGroup.Count);

                _boundingPosition.GlobalValue = boundingPosition;
                _boundingExtents.GlobalValue = boundingExtents;

                _positionAndMaterial.GlobalValue = positionArray;
                _size.GlobalValue = sizeArray;
                _colorAndRoughness.GlobalValue = colorArray;
                _rotation.GlobalValue = rotationArray;
            }


            #region Inspector

            public override string ToString() => _parameterName;
            public string NameForInspector
            {
                get => _parameterName;
                set
                {
                    _setInShader.ValueIsDefined = false;
                    _parameterName = value;
                }
            }

            private readonly pegi.EnterExitContext context = new();

            void IPEGI.Inspect()
            {
                using (context.StartContext())
                {
                    if (context.IsAnyEntered == false)
                    {
                        "Name".PegiLabel().Edit_Delayed(ref _parameterName).Nl(()=> _setInShader.ValueIsDefined = false);
                      //  "Rotation".PegiLabel().ToggleIcon(ref SupportsRotation).Nl();
                    }
                    "Registered primitives".PegiLabel().Edit_Array(ref SortedElements).Nl();

                    if (context.IsCurrentEntered)
                    {
                        "Pass {0} Elements To Array".F(MAX_ELEMENTS_COUNT).PegiLabel().Click(StartGroupingBoxesJob).Nl();
                    }

                    "Bounding Boxes".PegiLabel().Enter_List(elementsToGroup).Nl();

                    /*
                    if (context.IsCurrentEntered)
                    {
                        pegi.Click(GroupBoundingBoxes).Nl();
                    }*/

                    if ("Boxes Job".PegiLabel().IsEntered().Nl()) 
                    {

                        switch (_sortingStage) 
                        {
                            case BoxesSortingStage.Uninitialized:
                                if ("Run Job".PegiLabel().Click().Nl())
                                {
                                    StartGroupingBoxesJob();
                                    
                                }
                                break;
                            case BoxesSortingStage.JobStarted:

                                if (handle.IsCompleted && "Complete".PegiLabel().Click())
                                    ProcessBoxesAfterJob();
                                 
                                break;
                            case BoxesSortingStage.Completed:

                                if (_jobMeta != null && _jobMeta.Length > 0)
                                {
                                    var meta = _jobMeta[0];
                                    pegi.Nested_Inspect(ref meta).Nl();
                                }

                                /*
                                if (boxesForJob != null)
                                    for (int i = 0; i < boxesForJob.Length; i++)
                                    {
                                        BoxForJob el = boxesForJob[i];
                                        if (el.EncapsulatedInto != -1)
                                            continue;

                                        el.Inspect();
                                    }
                                */
                                if ("Pass To Shader".PegiLabel().Click().Nl())
                                {
                                    _sortingStage = BoxesSortingStage.Uninitialized;
                                    PassToShader();
                                }

                                break;
                        }


                    }
                }
            }

            public void OnSceneDraw()
            {
                _allElementsBox.OnSceneDraw_Nested();

                foreach (var b in elementsToGroup)
                    b.OnSceneDraw_Nested();

                /*
                for (int i = 0; i < MAX_BOUNDING_BOXES_COUNT; i++)
                {
                    pegi.Handle.DrawWireCube(boundingPosition[i], boundingExtents[i]);
                }*/
            }

            #endregion

            private class BoundingBox : IPEGI_Handles, IPEGI_ListInspect
            {
                public BoundingBoxCalculator Calculator = new();
                public List<SortedElement> Primitives = new();

                public bool TryEncapsulate(BoundingBox other, out float efficiency)
                {
                    float coefficient = other.Primitives.Count + Primitives.Count;

                    efficiency = Calculator.GetEncapsulationEfficiency(other.Calculator, coefficient: 1f / coefficient);

                    if (efficiency >= 2)
                    {
                        Encapsulate(other);
                        return true;
                    }
                    return false;
                }

                public void Encapsulate(BoundingBox other)
                {
                    Calculator.Add(other.Calculator);
                    Primitives.AddRange(other.Primitives);
                }

                public void OnSceneDraw()
                {
                    using (pegi.SceneDraw.SetColorDisposible(Color.yellow))
                    {
                        Calculator.OnSceneDraw();
                    }
                }

                public override string ToString() => "{0} elements. Volume: {1}".F(Primitives.Count, Calculator.ToString());

                public void InspectInList(ref int edited, int index)
                {
                    ToString().PegiLabel().Nl();
                }

                public BoundingBox(SortedElement startElement)
                {
                    Primitives.Add(startElement);
                    Calculator.Add(startElement.BoundingBox);
                }
            }

        }
    }
}