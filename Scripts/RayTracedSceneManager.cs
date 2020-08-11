using System.Collections;
using System.Collections.Generic;
using PlayerAndEditorGUI;
using UnityEngine;

namespace NodeNotes.RayTracing
{
    public class RayTracedSceneManager : IPEGI
    {

        private List<PrimitiveObjectPostBlit> All => PrimitiveObjectPostBlit.allCurrentObjects;


        public bool Inspect()
        {
            var changed = false;

            "For creating Scene objects that are connected to a primitive".writeHint();

            pegi.nl();


            return changed;
        }
    }
}
