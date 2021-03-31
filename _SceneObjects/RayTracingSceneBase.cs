using QuizCanners.CfgDecode;
using QuizCanners.Lerp;
using UnityEngine;

namespace QuizCanners.RayTracing
{

    public abstract class RayTracingSceneBase : MonoBehaviour, ILinkedLerping, ICfg
    {

        #region Encode & Decode

        public virtual void Decode(string tg, CfgData data)
        {
        }

        public virtual CfgEncoder Encode() => new CfgEncoder();

        #endregion

        #region Linked Lerp

        public abstract void Lerp(LerpData ld, bool canSkipLerp);

        public abstract void Portion(LerpData ld);

        #endregion
    }
}
