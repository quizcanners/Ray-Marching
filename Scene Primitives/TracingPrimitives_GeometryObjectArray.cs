using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using System.Collections.Generic;
using UnityEngine;

namespace QuizCanners.RayTracing
{
    public static partial class TracingPrimitives
    {
        [Serializable]
        internal class GeometryObjectArray : IGotName, IPEGI, IPEGI_Handles
        {
            const int MAX_BOUNDING_BOXES_COUNT = 8;
            const int MAX_ELEMENTS_COUNT = 64;

            [SerializeField] private string _parameterName;
            [SerializeField] public Shape ShapeToReflect = Shape.Cube;
           // [SerializeField] public bool SupportsRotation = true;

            [SerializeField] internal C_RayRendering_PrimitiveObjectForArray primitivePrefab;

            [SerializeField] internal List<C_RayRendering_PrimitiveObjectForArray> registeredPrimitives = new();

            ShaderProperty.VectorArrayValue _positionAndMaterial;
            ShaderProperty.VectorArrayValue _size;
            ShaderProperty.VectorArrayValue _colorAndRoughness;
            ShaderProperty.VectorArrayValue _rotation;

            ShaderProperty.VectorValue _boundingPositionAll;
            ShaderProperty.VectorValue _boundingExtendsAll;

            ShaderProperty.VectorArrayValue _boundingPosition;
            ShaderProperty.VectorArrayValue _boundingExtents;

            private readonly Gate.Bool _setInShader = new();

            readonly Vector4[] positionArray = new Vector4[MAX_ELEMENTS_COUNT];
            readonly Vector4[] colorArray = new Vector4[MAX_ELEMENTS_COUNT];
            readonly Vector4[] rotationArray = new Vector4[MAX_ELEMENTS_COUNT];
            readonly Vector4[] sizeArray = new Vector4[MAX_ELEMENTS_COUNT];

            readonly Vector4[] boundingPosition = new Vector4[MAX_BOUNDING_BOXES_COUNT];
            readonly Vector4[] boundingExtents = new Vector4[MAX_BOUNDING_BOXES_COUNT];

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

                while (registeredPrimitives.Count> MAX_ELEMENTS_COUNT) 
                {
                    var last = registeredPrimitives.Count-1;
                    registeredPrimitives[last].gameObject.DestroyWhatever();
                    registeredPrimitives.RemoveAt(last);
                }


                Singleton.Try<Singleton_TracingPrimitivesController>(s =>
                {
                    while (registeredPrimitives.Count < MAX_ELEMENTS_COUNT)
                    {
                        var inst = UnityEngine.Object.Instantiate(primitivePrefab, s.transform);
                        inst.gameObject.name = _parameterName + " " + registeredPrimitives.Count;
                        //inst.arrayVariableName = _parameterName;

                        registeredPrimitives.Add(inst);
                    }
                });
            }

            struct Efficiency 
            {
                public int Index_J;
                public int Index_I;
                public float Value;
            }

            private readonly List<BoundingBox> boxes = new();

            private void GroupBoundingBoxes() 
            {
                boxes.Clear();
                foreach (var prim in registeredPrimitives) 
                {
                    if (!prim.IsHidden)
                    {
                        boxes.Add(new BoundingBox(prim));
                    }
                }

                int iterations = 0;

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
                                    bestEfficiency.Index_J = j;
                                    bestEfficiency.Index_I = i;
                                }
                            }

                            return false;
                        }
                    }

                    iterations++;

                    if (bestEfficiency.Value > 0)
                    {
                        boxes[bestEfficiency.Index_J].Encapsulate(boxes[bestEfficiency.Index_I]);
                        boxes.RemoveAt(bestEfficiency.Index_I);
                    } else 
                    {
                        break;
                    }
                }
            }

            public void PassElementsToShader()
            {
                RemoveEmpty();

                InitializeIfNotInitialized();

                _box.Reset();

                for (int i = registeredPrimitives.Count - 1; i >= 0; i--)
                {
                    if (!registeredPrimitives[i])
                        registeredPrimitives.RemoveAt(i);
                }

                GroupBoundingBoxes();

                int totalIndex = 0;
                int startIndex = 0;

                for (int b=0; b<boxes.Count; b++) 
                {
                    var box = boxes[b];

                    for (int p =0; p< box.Primitives.Count; p++) 
                    {
                        var prim = box.Primitives[p];

                        positionArray[totalIndex] = prim.SHD_PositionAndMaterial;
                        colorArray[totalIndex] = prim.SHD_ColorAndRoughness;
                        rotationArray[totalIndex] = prim.SHD_Rotation;
                        sizeArray[totalIndex] = prim.SHD_Extents;

                        _box.Add(prim.GetBoundingBox());

                        totalIndex++;
                    }

                    boundingPosition[b] = box.Calculator.Center.ToVector4(startIndex);
                    boundingExtents[b] = box.Calculator.Extents.ToVector4(totalIndex);

                    startIndex = totalIndex;
                }

                /*
                int max = Math.Min(registeredPrimitives.Count, MAX_ELEMENTS_COUNT);

                for (int i = 0; i < max; i++)
                {
                    C_RayRendering_PrimitiveObjectForArray el = registeredPrimitives[i];

                    positionArray[i] = el.SHD_PositionAndMaterial;
                    colorArray[i] = el.SHD_ColorAndRoughness;
                    rotationArray[i] = el.SHD_Rotation;
                    sizeArray[i] = el.SHD_Extents;

                    _box.Add(el.GetBoundingBox());
                }*/

                _boundingPositionAll.GlobalValue = _box.Center;
                _boundingExtendsAll.GlobalValue = _box.Extents;

                _boundingPosition.GlobalValue = boundingPosition;
                _boundingExtents.GlobalValue = boundingExtents;

                _positionAndMaterial.GlobalValue = positionArray;
                _size.GlobalValue = sizeArray;
                _colorAndRoughness.GlobalValue = colorArray;
                _rotation.GlobalValue = rotationArray;
            }

            void RemoveEmpty()
            {
                for (int i = Math.Min(MAX_ELEMENTS_COUNT, registeredPrimitives.Count) - 1; i >= 0; i--)
                {
                    var el = registeredPrimitives[i];
                    if (!el) //|| !el.arrayVariableName.Equals(_parameterName))
                        registeredPrimitives.RemoveAt(i);
                }
            }

            public void ClearInstances() 
            {
                registeredPrimitives.DestroyAndClear();
            }

            #region Inspector

            readonly BoundingBoxCalculator _box = new();

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

            public void Inspect()
            {
                using (context.StartContext())
                {
                    if (context.IsAnyEntered == false)
                    {
                        "Name".PegiLabel().Edit_Delayed(ref _parameterName).Nl(()=> _setInShader.ValueIsDefined = false);
                        "Prefab".PegiLabel(50).Edit(ref primitivePrefab).Nl();
                      //  "Rotation".PegiLabel().ToggleIcon(ref SupportsRotation).Nl();
                    }
                    "Registered primitives".PegiLabel().Enter_List_UObj(registeredPrimitives).Nl();

                    if (context.IsCurrentEntered)
                    {
                        if ("Fix Names".PegiLabel().Click().Nl())
                        {
                            for (int i = 0; i < registeredPrimitives.Count; i++) // var rp in registeredPrimitives)
                            {
                                var pr = registeredPrimitives[i];
                                if (pr)
                                {
                                    pr.gameObject.name = _parameterName + " " + i.ToString();
                                    pr.transform.SetAsLastSibling();
                                }
                            }

                        }

                        pegi.Click(ClearInstances).Nl();
                        "Pass {0} Elements To Array".F(MAX_ELEMENTS_COUNT).PegiLabel().Click(PassElementsToShader).Nl();
                    }

                    "Bounding Boxes".PegiLabel().Enter_List(boxes).Nl();

                    if (context.IsCurrentEntered)
                    {
                        pegi.Click(GroupBoundingBoxes).Nl();
                    }
                }
            }

            public void OnSceneDraw()
            {
                _box.OnSceneDraw_Nested();

                foreach (var b in boxes)
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
                public List<C_RayRendering_PrimitiveObjectForArray> Primitives = new();

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

                public BoundingBox(C_RayRendering_PrimitiveObjectForArray startElement)
                {
                    Primitives.Add(startElement);
                    Calculator.Add(startElement.GetBoundingBox());
                }
            }

        }
    }
}