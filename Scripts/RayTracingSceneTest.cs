using System.Collections;
using System.Collections.Generic;
using PlayerAndEditorGUI;
using QuizCannersUtilities;
using UnityEngine;

namespace NodeNotes.RayTracing
{
    public class RayTracingSceneTest : RayTracingSceneBase
    {
        public PrimitiveObject cube0, cube1, cube2, cube3, cube4, cube5, sphere0, sphere1, light0;
        
        #region Encode & Decode
        
        public override bool Decode(string tg, string data)
        {
            switch (tg)
            {
                case "b": base.Decode(data); break;
                case "c0": cube0.Decode(data); break;
                case "c1": cube1.Decode(data); break;
                case "c2": cube2.Decode(data); break;
                case "c3": cube3.Decode(data); break;
                case "c4": cube4.Decode(data); break;
                case "c5": cube5.Decode(data); break;
                case "s0": sphere0.Decode(data); break;
                case "s1": sphere1.Decode(data); break;
                case "l0": light0.Decode(data); break;
                default: return false;
            }
            return true;
        }

        public override CfgEncoder Encode() => new CfgEncoder()
            .Add("b", base.Encode)
            .Add("c0", cube0)
            .Add("c1", cube1)
            .Add("c2", cube2)
            .Add("c3", cube3)
            .Add("c4", cube4)
            .Add("c5", cube5)
            .Add("s0", sphere0)
            .Add("s1", sphere1)
            .Add("l0", light0);

        #endregion

        #region Linked Lerp

        public override void Lerp(LerpData ld, bool canSkipLerp)
        {
            cube0.Lerp(ld, canSkipLerp);
            cube1.Lerp(ld, canSkipLerp);
            cube2.Lerp(ld, canSkipLerp);
            cube3.Lerp(ld, canSkipLerp);
            cube4.Lerp(ld, canSkipLerp);
            cube5.Lerp(ld, canSkipLerp);
            sphere0.Lerp(ld, canSkipLerp);
            sphere1.Lerp(ld, canSkipLerp);
            light0.Lerp(ld, canSkipLerp);
        }

        public override void Portion(LerpData ld)
        {
            cube0.Portion(ld);
            cube1.Portion(ld);
            cube2.Portion(ld);
            cube3.Portion(ld);
            cube4.Portion(ld);
            cube5.Portion(ld);
            sphere0.Portion(ld);
            sphere1.Portion(ld);
            light0.Portion(ld);
        }

        #endregion
    }
}
