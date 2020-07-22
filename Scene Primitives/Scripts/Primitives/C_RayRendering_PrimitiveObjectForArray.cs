using UnityEngine;
using QuizCanners.Inspect;
using QuizCanners.Migration;
using QuizCanners.Lerp;
using QuizCanners.Utils;
using System;

namespace QuizCanners.RayTracing
{

    [DisallowMultipleComponent]
    [ExecuteInEditMode]
    [AddComponentMenu("PrimitiveTracing/Proxy/Static For Array")]
    public class C_RayRendering_PrimitiveObjectForArray : C_RayRendering_StaticPrimitive
    {
        public string arrayVariableName;

        private void PassToArray()
        {
            var mgmt = GetMgmt();
            if (mgmt)
            {
                GetMgmt().RegisterToArray(this);
            }
        }

        protected void Start()
        {
             PassToArray();
        }

        public override void Inspect()
        {
            
            var cnt = Singleton.Get<Singleton_TracingPrimitivesController>();

            if (!cnt)
                "No {0} found".F(nameof(Singleton_TracingPrimitivesController)).PegiLabel().Write_Hint().Nl();
            else
            if ("Array".PegiLabel(60).Select(ref arrayVariableName, Singleton.Get<Singleton_TracingPrimitivesController>().objectArrays))
                PassToArray();
            

            pegi.Nl();
            

            base.Inspect();
        }

    }

    [PEGI_Inspector_Override(typeof(C_RayRendering_PrimitiveObjectForArray))] internal class PrimitiveObjectForArrayDrawer : PEGI_Inspector_Override { }

}