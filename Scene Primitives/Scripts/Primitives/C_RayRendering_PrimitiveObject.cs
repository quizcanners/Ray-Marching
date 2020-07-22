using UnityEngine;
using QuizCanners.Inspect;
using QuizCanners.Utils;

namespace QuizCanners.RayTracing
{

    [DisallowMultipleComponent]
    [ExecuteInEditMode]
    [AddComponentMenu("PrimitiveTracing/Proxy/Static")]
    public class C_RayRendering_PrimitiveObject : C_RayRendering_StaticPrimitive
    {
        public string variableName;
        private ShaderProperty.VectorValue positionAndMat;
        private ShaderProperty.VectorValue sizeAndNothing;
        private ShaderProperty.VectorValue rotation;
        private ShaderProperty.VectorValue colorAndRoughness;

        protected override void OnEnable()
        {
            base.OnEnable();
            InitializeProperties();
        }

        private void InitializeProperties()
        {
            if (positionAndMat == null)
            {
                positionAndMat = new(variableName);
                sizeAndNothing = new(variableName + "_Size");
                colorAndRoughness = new(variableName + "_Mat");
                rotation = new(variableName + "_Rot");
            }
        }

        private void UpdateShaderValues()
        {
            positionAndMat.GlobalValue = SHD_PositionAndMaterial;
            sizeAndNothing.GlobalValue = SHD_Extents;
            colorAndRoughness.GlobalValue = SHD_ColorAndRoughness;
            rotation.GlobalValue = SHD_Rotation;
        }

        protected override void OnDirty()
        {
            base.OnDirty();
            UpdateShaderValues();
        }


        public override bool TryReflect(C_RayT_PrimShape_EnvironmentElement el)
        {
            var changes = base.TryReflect(el);

            UpdateShaderValues();

            return changes;
        }

        public override string ToString() => variableName;


        public override void Inspect()
        {
            if ("Name".PegiLabel(60).Edit_Delayed(ref variableName))
                InitializeProperties();

            if (gameObject.name != variableName && "Set GO name".PegiLabel().Click())
                gameObject.name = variableName;


            base.Inspect();
        }
    }

    [PEGI_Inspector_Override(typeof(C_RayRendering_PrimitiveObject))] internal class RayMarchingObjectDrawer : PEGI_Inspector_Override { }

}