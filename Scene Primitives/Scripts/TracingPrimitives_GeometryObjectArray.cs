using QuizCanners.Inspect;
using QuizCanners.Lerp;
using QuizCanners.Utils;
using System;
using System.Collections.Generic;
using UnityEngine;
using static QuizCanners.RayTracing.QcRTX;

namespace QuizCanners.RayTracing
{

    [Serializable]
    internal class GeometryObjectArray : IGotName, IPEGI, ILinkedLerping, IPEGI_Handles
    {
        const int MAX_BOUNDING_BOXES_COUNT = 2;
        const int MAX_ELEMENTS_COUNT = 10;

        [SerializeField] private string _parameterName;
        [SerializeField] public Shape ShapeToReflect = Shape.Cube;

        internal List<C_RayRendering_PrimitiveObjectForArray> registeredPrimitives = new();

        ShaderProperty.VectorArrayValue _positionAndMaterial;
        ShaderProperty.VectorArrayValue _size;
        ShaderProperty.VectorArrayValue _colorAndRoughness;
        ShaderProperty.VectorArrayValue _rotation;


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
            }
        }

        public void PassElementsToShader()
        {
            InitializeIfNotInitialized();
            
            RemoveEmpty();

            _box.Reset();

            for (int i = registeredPrimitives.Count-1; i >= 0; i--)
            {
                if (!registeredPrimitives[i])
                    registeredPrimitives.RemoveAt(i);
            }

            for (int i = 0; i < registeredPrimitives.Count; i++)
            {
                C_RayRendering_PrimitiveObjectForArray el = registeredPrimitives[i];

                positionArray[i] = el.SHD_PositionAndMaterial;
                colorArray[i] = el.SHD_ColorAndRoughness;
                rotationArray[i] = el.SHD_Rotation;
                sizeArray[i] = el.SHD_Extents;

                _box.Add(el.GetBoundingBox());
            }

            boundingPosition[0] = _box.Center;
            boundingExtents[0] = _box.Extents;

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
                if (!el || !el.arrayVariableName.Equals(_parameterName))
                    registeredPrimitives.RemoveAt(i);
            }
        }

        #region Inspector

        readonly BoundingBoxCalculator _box = new();

        public string NameForInspector
        {
            get => _parameterName;
            set
            {
                _setInShader.ValueIsDefined = false;
                _parameterName = value;
            }
        }

        public void Inspect()
        {
            "Registered primitives".PegiLabel().Edit_List(registeredPrimitives).Nl();
            "Pass {0} Elements To Array".F(MAX_ELEMENTS_COUNT).PegiLabel().Click(PassElementsToShader).Nl();

          
        }

        public void OnSceneDraw()
        {
            _box.OnSceneDraw_Nested();

            /*
            for (int i = 0; i < MAX_BOUNDING_BOXES_COUNT; i++)
            {
                pegi.Handle.DrawWireCube(boundingPosition[i], boundingExtents[i]);
            }*/
        }

        #endregion

        #region Linked Lerp
        public void Portion(LerpData ld)
        {
            foreach (var p in registeredPrimitives)
                p.Portion(ld);
        }

        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            foreach (var p in registeredPrimitives)
                p.Lerp(ld, canSkipLerp);
        }


        #endregion
    }


}