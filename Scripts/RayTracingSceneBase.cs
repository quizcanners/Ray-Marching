using System.Collections;
using System.Collections.Generic;
using PlayerAndEditorGUI;
using QuizCannersUtilities;
using UnityEngine;

namespace NodeNotes.RayTracing
{

    public abstract class RayTracingSceneBase : MonoBehaviour, IPEGI, ILinkedLerping, ICfg
    {
        #region Inspector

        public bool Inspect()
        {
            var changed = false;

            return changed;
        }

        #endregion

        #region Encode & Decode

        public virtual void Decode(string data) => new CfgDecoder(data).DecodeTagsFor(this);

        public virtual bool Decode(string tg, string data) => false;
        
        public virtual CfgEncoder Encode() => new CfgEncoder();

        #endregion

        #region Linked Lerp

        public abstract void Lerp(LerpData ld, bool canSkipLerp);

        public abstract void Portion(LerpData ld);

        #endregion
    }
}
