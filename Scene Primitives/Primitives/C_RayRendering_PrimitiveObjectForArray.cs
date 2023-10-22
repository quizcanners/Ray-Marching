using UnityEngine;
using QuizCanners.Inspect;
using QuizCanners.Utils;

namespace QuizCanners.RayTracing
{

    [DisallowMultipleComponent]
    [ExecuteInEditMode]
    [AddComponentMenu("PrimitiveTracing/Proxy/Static For Array")]
    public class C_RayRendering_PrimitiveObjectForArray : C_RayRendering_StaticPrimitive
    {
       // public string arrayVariableName;

        public override void Inspect()
        {
            
            var cnt = Singleton.Get<Singleton_TracingPrimitivesController>();

            if (!cnt)
                "No {0} found".F(nameof(Singleton_TracingPrimitivesController)).PegiLabel().Write_Hint().Nl();

            pegi.Nl();
            
            base.Inspect();
        }

    }

    [PEGI_Inspector_Override(typeof(C_RayRendering_PrimitiveObjectForArray))] internal class PrimitiveObjectForArrayDrawer : PEGI_Inspector_Override { }

}