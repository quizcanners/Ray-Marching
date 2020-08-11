using PlayerAndEditorGUI;
using QuizCannersUtilities;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace NodeNotes.RayTracing
{
    public class PrimitiveObjectPostBlit : MonoBehaviour, IPEGI, ICfg
    {

        public string prefabKey;
        
        public static List<PrimitiveObjectPostBlit> allCurrentObjects = new List<PrimitiveObjectPostBlit>();

        void OnEnable() => allCurrentObjects.Add(this);
        
        void OnDisable() => allCurrentObjects.Remove(this);
        
        
        #region Inspector

        public bool Inspect()
        {
            var changed = false;

            pegi.toggleDefaultInspector(this).nl();

            "Prefab".select(ref prefabKey, Shortcuts.Assets.GetRayTracedObjectsKeys()).nl();

            return changed;
        }

        #endregion

        #region Encode & Decode

        public CfgEncoder Encode()
        {
            var cody = new CfgEncoder()
                .Add("pos", transform.localPosition)
                .Add("size", transform.localScale)
                .Add_String("pf", prefabKey);
            
            return cody;
        }

        public bool Decode(string tg, string data)
        {
            switch (tg)
            {
                case "pos": transform.localPosition = data.ToVector3(); break;
                case "size": transform.localScale = data.ToVector3(); break;
                case "pf": prefabKey = data; break;
                default: return false;
            }

            return true;
        }

        public void Decode(string data) =>
            new CfgDecoder(data).DecodeTagsFor(this);
        

        #endregion

    }
}