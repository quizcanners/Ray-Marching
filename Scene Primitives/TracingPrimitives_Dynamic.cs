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
        public class Dynamic : IPEGI, IPEGI_Handles
        {
            const int MAX_DYNAMICS = 6;
            const string PARAMETER_NAME = "DYNAMIC_PRIM";

            public static List<C_RayRendering_DynamicPrimitive> instances = new();
            private readonly Gate.Bool _setInShader = new();

            readonly BoundingBoxCalculator _box = new();

            ShaderProperty.VectorArrayValue _positionAndMaterial;
            ShaderProperty.VectorArrayValue _size;
            ShaderProperty.VectorArrayValue _colorAndRoughness;
            ShaderProperty.VectorArrayValue _rotation;

            ShaderProperty.IntValue _dynamicObjects;
            ShaderProperty.VectorValue _boundsCenter;
            ShaderProperty.VectorValue _boundsExtents;

            readonly Vector4[] positionArray = new Vector4[MAX_DYNAMICS];
            readonly Vector4[] colorArray = new Vector4[MAX_DYNAMICS];
            readonly Vector4[] rotationArray = new Vector4[MAX_DYNAMICS];
            readonly Vector4[] sizeArray = new Vector4[MAX_DYNAMICS];

            private void InitializeIfNotInitialized()
            {
                if (_setInShader.TryChange(true))
                {
                    _positionAndMaterial = new(PARAMETER_NAME);
                    _size = new(PARAMETER_NAME + "_Size");
                    _colorAndRoughness = new(PARAMETER_NAME + "_Mat");
                    _rotation = new(PARAMETER_NAME + "_Rot");
                    _boundsCenter = new(PARAMETER_NAME + "_BoundPos");
                    _boundsExtents = new(PARAMETER_NAME + "_BoundSize");

                    _dynamicObjects = new ShaderProperty.IntValue(PARAMETER_NAME + "_COUNT");
                }
            }

            public void ManagedUpdate()
            {
                InitializeIfNotInitialized();

                if (instances.Count == 0)
                {
                    _dynamicObjects.SetGlobal(0);
                    return;
                }

                int count = Math.Min(instances.Count, MAX_DYNAMICS);
                _dynamicObjects.SetGlobal(count);

                _box.Reset();

                for (int i = 0; i < count; i++)
                {
                    var el = instances[i];

                    positionArray[i] = el.SHD_PositionAndMaterial;
                    colorArray[i] = el.SHD_ColorAndRoughness;
                    rotationArray[i] = el.SHD_Rotation;
                    sizeArray[i] = el.SHD_Extents;

                    _box.Add(el.GetBoundingBox());
                }

                _boundsCenter.SetGlobal(_box.Center);
                _boundsExtents.SetGlobal(_box.Extents);

                _positionAndMaterial.GlobalValue = positionArray;
                _size.GlobalValue = sizeArray;
                _colorAndRoughness.GlobalValue = colorArray;
                _rotation.GlobalValue = rotationArray;
            }

            #region Inspector

            public void OnSceneDraw()
            {
                _box.OnSceneDraw_Nested();
            }

            private readonly pegi.CollectionInspectorMeta _instancesMeta
                = new("Instances", showEditListButton: false, showAddButton: false);

            public void Inspect()
            {
                if (!_instancesMeta.IsAnyEntered)
                    "Parameter".PegiLabel().Write_ForCopy(PARAMETER_NAME).Nl();

                _instancesMeta.Edit_List(instances).Nl();

            }

            #endregion
        }
    }
}