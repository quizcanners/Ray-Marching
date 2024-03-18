using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using UnityEngine;
using UnityEngine.Rendering;

namespace QuizCanners.VolumeBakedRendering
{
    public static partial class QcRender
    {
        [Serializable]
        public class Shadowmap : IPEGI
        {
            const string TEXTURE_NAME = "qc_SunCascadedShadowMap";

            private CommandBuffer commandBuffer;

            private Light Sun => Singleton.Get<Singleton_SunAndMoonRotator>().SharedLight;

            public void ManagedOnEnable()
            {
                commandBuffer = new CommandBuffer();

                RenderTargetIdentifier shadowMapRenderTextureIdentifier = BuiltinRenderTextureType.CurrentActive;
                commandBuffer.SetGlobalTexture(TEXTURE_NAME, shadowMapRenderTextureIdentifier);

                Sun.AddCommandBuffer(LightEvent.AfterShadowMap, commandBuffer);
            }

            public void ManagedOnDisable()
            {
                if (Sun)
                    Sun.RemoveCommandBuffer(LightEvent.AfterShadowMap, commandBuffer);

                commandBuffer.Clear();
            }


            #region Inspector

            public override string ToString() => "Shadow Map";

            public void Inspect()
            {
                if ("Reset".PegiLabel().Click().Nl()) 
                {
                    ManagedOnDisable();
                    ManagedOnEnable();
                }
            }

            #endregion
        }
    }
}