using QuizCanners.CfgDecode;
using QuizCanners.Inspect;
using System.Collections.Generic;
using UnityEngine;

namespace QuizCanners.RayTracing
{
    public class PrimitiveObjectPostBlit : MonoBehaviour, IPEGI, ICfg
    {

        public string prefabKey;
        
        public static List<PrimitiveObjectPostBlit> allCurrentObjects = new List<PrimitiveObjectPostBlit>();

        private void OnEnable() => allCurrentObjects.Add(this);

        private void OnDisable() => allCurrentObjects.Remove(this);
        
        
        #region Inspector

        public void Inspect()
        {

            pegi.toggleDefaultInspector(this).nl();
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

        public void Decode(string tg, CfgData data)
        {
            switch (tg)
            {
                case "pos": transform.localPosition = data.ToVector3(); break;
                case "size": transform.localScale = data.ToVector3(); break;
                case "pf": prefabKey = data.ToString(); break;
            }
        }
        

        #endregion

    }
}