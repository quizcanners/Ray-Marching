using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;
using UnityEngine.Rendering;

namespace QuizCanners.VolumeBakedRendering
{
    public class LowResolutionDepth : MonoBehaviour, IPEGI, IPEGI_ListInspect
    {
        [SerializeField] private Camera CameraToUse;
        [SerializeField] private Material DepthBlurMaterial;
        [SerializeField] private Material AmbientGenerationMaterial;
        private static readonly ShaderProperty.TextureValue _cameraDepthTextureLowRes = new("Qc_CameraDepthTextureLowRes");
        private static readonly ShaderProperty.TextureValue _ambientOcclusionTextures = new("Qc_AmbientOcclusionTexture");

        private void OnEnable()
        {
            // Camera.onPreCull += MyPreCull;
            //  Camera.onPostRender += MyPostRender;

            if (CameraToUse) 
            {
                CameraToUse.AddCommandBuffer(CameraEvent.AfterDepthTexture, GenerateCommandBuffer());

            }
        }

        void OnDisable()
        {
            if (CameraToUse)
            {
                CameraToUse.RemoveCommandBuffer(CameraEvent.AfterDepthTexture, cmd);
            }

            if (_sceneDepthRT) 
            {
                _sceneDepthRT.DestroyWhatever();
                _sceneDepthRT = null;
            }

            if (_ambientOcclusionRT) 
            {
                _ambientOcclusionRT.DestroyWhatever();
                _ambientOcclusionRT = null;
            }
        }

        private CommandBuffer cmd;
        RenderTexture _sceneDepthRT;
        RenderTexture _ambientOcclusionRT;

        public CommandBuffer GenerateCommandBuffer()
        {

            if (cmd == null)
                cmd = new CommandBuffer() 
                { 
                    name = "Low Resolution Depth" 
                };

            cmd.Clear();

            if (!_sceneDepthRT)
            {
                _sceneDepthRT = new RenderTexture(512, 512, 0, RenderTextureFormat.RFloat)
                {
                    name = "Scene Depth Downscaled"
                };
                _cameraDepthTextureLowRes.GlobalValue = _sceneDepthRT;

                _ambientOcclusionRT = new RenderTexture(512, 512, 0, RenderTextureFormat.RFloat)
                {
                    name = "AO Texture"
                };
                _ambientOcclusionTextures.GlobalValue = _ambientOcclusionRT;
            }


          //  cmd.SetRenderTarget(_sceneDepthRT);
            //cmd.Blit(null, DepthBlurMaterial);
            cmd.Blit(BuiltinRenderTextureType.None, _sceneDepthRT, DepthBlurMaterial);
            cmd.Blit(BuiltinRenderTextureType.None, _ambientOcclusionRT, AmbientGenerationMaterial);

            return cmd;
        }

        



        #region Inspector

        void IPEGI.Inspect()
        {
            // REFLECTIONS.Nested_Inspect();
            // MOBILE.Nested_Inspect();

            pegi.Draw(_sceneDepthRT, 256, alphaBlend: false).Nl();
        }

        public void InspectInList(ref int edited, int index)
        {

            if (Icon.Enter.Click())
                edited = index;

            if ("Low resultion AO".PegiLabel().ClickLabel())
                edited = index;

        }
        #endregion
    }

    [PEGI_Inspector_Override(typeof(LowResolutionDepth))]
    internal class LowResolutionDepthDrawer : PEGI_Inspector_Override { }
}
