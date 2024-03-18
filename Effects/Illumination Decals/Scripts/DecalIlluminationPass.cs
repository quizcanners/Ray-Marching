using QuizCanners.Inspect;
using QuizCanners.Utils;
using QuizCanners.VolumeBakedRendering;
using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace QuizCanners.SpecialEffects
{
    [Serializable]
    public class DecalIlluminationPass : IPEGI
    {
        [Header("AO Materials")]
        public Material materialCenter;
        public Material materialSide;
        public Material materialEdge;
        public Material materialCorner;

        [Header("Shadow Materials")]
        public Material shad_CapsuleMaterial;
        public Material shad_BoxMaterial;
        public Material shad_SphereMaterial;


        public Mesh mesh;
        private CommandBuffer staticCmdBuffer;
        private CommandBuffer dynamicCmdBuffer;

        private RenderTexture renderTarget;

        private int _updatesVersion;

        private readonly Gate.Integer _staticDecalsVersion = new();
        private readonly Gate.Integer _dynamicDecalsVersion = new();

        private readonly ShaderProperty.FloatValue USE_AO_DECALS = new("QC_AO_DECALS");
        private readonly ShaderProperty.TextureValue QC_DECAL_TEXTURE = new("qc_DecalAoTex");

        const CameraEvent RENDER_EVENT = CameraEvent.AfterDepthTexture;

        private readonly Gate.Bool dynamicAdded = new();
        private readonly Gate.Bool _textureCleared = new();

        bool anyTargets;

        private RenderTexture GetRenderTexture()
        {
            if (renderTarget)
                return renderTarget;

            renderTarget = new RenderTexture(Screen.width, Screen.height, 0);

            QC_DECAL_TEXTURE.GlobalValue = renderTarget;

            return renderTarget;
        }

        public void OnPreRender() 
        {
            if (_staticDecalsVersion.TryChange(IlluminationDecals.StaticDecalsVersion)) 
            {
                ClearStatics();
                if (IlluminationDecals.AnyStatics)
                {
                    UpdateStatics();
                }
            }

            if (_dynamicDecalsVersion.TryChange(IlluminationDecals.DynamicDecalsVersion))
            {
                if (IlluminationDecals.AnyDynamics)
                {
                    dynamicCmdBuffer ??= new CommandBuffer { name = "Dynamic AO Decals" };
                } else 
                {
                    ClearDynamics();
                }
            }

            anyTargets = IlluminationDecals.AnyTargets;

            if (!anyTargets && _textureCleared.CurrentValue)
            {
                USE_AO_DECALS.GlobalValue = 0;
                return;
            }

            USE_AO_DECALS.GlobalValue = 1;


            RenderTexture pre = RenderTexture.active;
            RenderTexture.active = GetRenderTexture();
            GL.Clear(false, true, Color.clear);
            _textureCleared.TryChange(true);

            RenderTexture.active = pre;

            if (anyTargets)
                _textureCleared.TryChange(false);

            if (!IlluminationDecals.AnyDynamics)
                return;
            
            dynamicCmdBuffer.Clear();
            dynamicCmdBuffer.SetRenderTarget(GetRenderTexture());

            var cam = IlluminationDecals.MGMT.Camera;

            dynamicCmdBuffer.SetViewProjectionMatrices(cam.worldToCameraMatrix, cam.projectionMatrix);
            PopulateBuffer(IlluminationDecals.s_dynamicAoDecalTargets, dynamicCmdBuffer);
            PopulateBuffer(IlluminationDecals.s_dynamicShadowDecalTargets, dynamicCmdBuffer);

            IlluminationDecals.MGMT.Camera.AddCommandBuffer(RENDER_EVENT, dynamicCmdBuffer);

            dynamicAdded.TryChange(true);
        }

        public void OnPostRender() 
        {
            RemoveDynamicCommndBuffer();
        }

        private void RemoveDynamicCommndBuffer() 
        {
            if (dynamicAdded.ValueIsDefined && dynamicAdded.TryChange(false))
                IlluminationDecals.MGMT.Camera.RemoveCommandBuffer(RENDER_EVENT, dynamicCmdBuffer);

            USE_AO_DECALS.GlobalValue = 0;
        }

        public void OnEnable() 
        {
            _dynamicDecalsVersion.ValueIsDefined = false;
            _staticDecalsVersion.ValueIsDefined = false;
        }

        private void PopulateBuffer(List<C_ShadowDecalTarget> targets, CommandBuffer buffer)
        {
            var sunDirection = Vector3.zero;
            
            if (Singleton.TryGet<Singleton_SunAndMoonRotator>(out var sun)) 
            {
                sunDirection = sun.SunDirection;
            }

            var rot = Quaternion.LookRotation(sunDirection);

            foreach (C_ShadowDecalTarget target in targets)
            {
                var mesh = target.GetMesh();
                if (!mesh)
                {
                    continue;
                }

                var mat = GetMaterial(target);

                if (!mat)
                    continue;

                var tf = target.transform;
                var scale = tf.lossyScale.MaxAbs() * 2;



                buffer.DrawMesh(target.GetMesh(), Matrix4x4.TRS(tf.position + scale * sunDirection, rot, new Vector3(scale, scale, scale * 3)), GetMaterial(target), 0, 0);

                Material GetMaterial(C_ShadowDecalTarget trget)
                {
                    return trget.Mode switch
                    {
                        IlluminationDecals.ShadowMode.Capsule => shad_CapsuleMaterial,
                        IlluminationDecals.ShadowMode.Box => shad_BoxMaterial,
                        IlluminationDecals.ShadowMode.Sphere => shad_SphereMaterial,
                        IlluminationDecals.ShadowMode.Sdf => trget.GetMaterial(),
                        _ => shad_CapsuleMaterial,
                    };
                }
            }
        }

        private void PopulateBuffer(List<C_AODecalTarget> targets, CommandBuffer buffer) 
        {
            foreach (C_AODecalTarget target in targets)
            {
                var mesh = target.GetMesh();
                if (!mesh)
                {
                    continue;
                }

                var mat = GetMaterial(target);

                if (!mat)
                    continue;

                var tf = target.transform;

                buffer.DrawMesh(target.GetMesh(), Matrix4x4.TRS(tf.position, tf.rotation, tf.lossyScale), GetMaterial(target), 0, 0);

                Material GetMaterial(C_AODecalTarget trget)
                {
                    return trget.Mode switch
                    {
                        IlluminationDecals.AoMode.Edge => materialEdge,
                        IlluminationDecals.AoMode.Corner => materialCorner,
                        IlluminationDecals.AoMode.Side => materialSide,
                        _ => materialCenter,
                    };
                }
            }
        }

        private void UpdateStatics() 
        {

            staticCmdBuffer ??= new CommandBuffer { name = "Static Illumination Decals" };

            staticCmdBuffer.SetRenderTarget(GetRenderTexture());

            PopulateBuffer(IlluminationDecals.s_staticAoDecalTargets, staticCmdBuffer);
            PopulateBuffer(IlluminationDecals.s_staticShadowDecalTargets, staticCmdBuffer);

            IlluminationDecals.MGMT.Camera.AddCommandBuffer(RENDER_EVENT, staticCmdBuffer);

            _updatesVersion++;
        }


        private void ClearStatics() 
        {
            if (staticCmdBuffer != null)
            {
                if (IlluminationDecals.MGMT.Camera)
                {
                    IlluminationDecals.MGMT.Camera.RemoveCommandBuffer(RENDER_EVENT, staticCmdBuffer);
                }
                staticCmdBuffer.Clear();
            }
        }

        private void ClearDynamics() 
        {
            if (dynamicCmdBuffer != null)
            {
                RemoveDynamicCommndBuffer();
                dynamicCmdBuffer.Clear();
            }
        }



        public void OnDisable() 
        {
            renderTarget.DestroyWhatever();
            ClearStatics();
            ClearDynamics();

            _dynamicDecalsVersion.ValueIsDefined = false;
            _staticDecalsVersion.ValueIsDefined = false;

            if (dynamicCmdBuffer != null)
            {
                dynamicCmdBuffer.Dispose();
                dynamicCmdBuffer = null;
            }

            if (staticCmdBuffer != null) 
            {
                staticCmdBuffer.Dispose();
                staticCmdBuffer = null;
            }
        }

        public override string ToString() => "AO Decals";

        public void Inspect()
        {
            "Material".PegiLabel().Edit(ref materialCenter).Nl();
            "Mesh".PegiLabel().Edit(ref mesh).Nl();

            if (Application.isPlaying)
            {
                "Updates: {0}".F(_updatesVersion).PegiLabel().Nl();
                if ("Set Dirty".PegiLabel().Click())
                {
                    _staticDecalsVersion.ValueIsDefined = false;
                    _dynamicDecalsVersion.ValueIsDefined = false;
                }

                pegi.Nl();

                IlluminationDecals.Inspect();
                pegi.Nl();

                "Target".PegiLabel().Edit(ref renderTarget).Nl();
            }
        }
    }
}
