using QuizCanners.Inspect;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;

#if UNITY_EDITOR
using UnityEditor;
#endif

namespace QuizCanners.RayTracing
{
    public class VolumeShapeDraw : MonoBehaviour, IPEGI
    {
        public Material BakeMaterial;

        [NonSerialized] public int BakedForLocation_Version = -1;

        public void Inspect()
        {
            pegi.toggleDefaultInspector(this); pegi.nl();

            
        }
    }



    #if UNITY_EDITOR
    [CustomEditor(typeof(VolumeShapeDraw))] internal class VolumeShapeDrawInspectorOverride : PEGI_Inspector_Mono<VolumeShapeDraw> { }
    #endif

}
