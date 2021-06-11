using PlaytimePainter;
using UnityEngine;
using QuizCanners.Utils;
using QuizCanners.Inspect;
using System.Collections.Generic;

namespace QuizCanners.RayTracing
{
    public class VolumeTracingBaker : MonoBehaviour, IPEGI
    {
        public int LocationVersion 
        {
            get;
            private set;
        }

        [SerializeField] private int _stopUpdatingAfterFrames = 500;
        private Vector3 _renderedPosition = Vector3.zero;
        private Vector3 _currentPosition = Vector3.zero;
        private int _renderedAtFrame;
        private int framesToBake = 1;
        public void SetBakeDirty() => framesToBake = _stopUpdatingAfterFrames;


        public RenderTexture _texA;
        public RenderTexture _texB;
        private bool targetIsA;
        public RenderTexture Target => targetIsA ? _texA : _texB;
        public RenderTexture Source => targetIsA ? _texB : _texA;

        public Material material;
        public VolumeTexture volume;

        private ShaderProperty.VectorValue _positionOffset;

        public ShaderProperty.VectorValue PositionOffsetAndScale
        {
            get
            {
                if (_positionOffset != null)
                    return _positionOffset;

                _positionOffset = new ShaderProperty.VectorValue(volume.name + "VOLUME_POSITION_OFFSET");

                return _positionOffset;
            }
        }

        private void OnOffsetRendered() 
        {
            _renderedPosition = _currentPosition;
            PositionOffsetAndScale.GlobalValue = Vector3.zero.ToVector4(volume.size);
        }

        private void CheckOffsetDirty(out bool isDirty) 
        {
            if (volume)
            {
                _currentPosition = volume.PosSize4Shader.XYZ();

                var diff = _currentPosition - _renderedPosition;

                if (diff.magnitude > 0)
                {
                    PositionOffsetAndScale.GlobalValue = diff.ToVector4(volume.size);
                    LocationVersion++;
                    SetBakeDirty();
                    isDirty = true;
                    return;
                }
            }

            isDirty = false;
        }

        public void Paint(Material withMaterial) 
        {
            if (Target && Source && withMaterial)
            {
                PlaytimePainter_RenderTextureBuffersManager.BlitGL(Source, Target, withMaterial);
                if (volume)
                    volume.Texture = Target;

                targetIsA = !targetIsA;

                _renderedAtFrame = Time.frameCount;
            }
        }

        public void ManagedUpdate(List<VolumeShapeDraw> shapes, int stableFrames) 
        {
            if (shapes.IsNullOrEmpty())
                return;

            if (stableFrames < 10)
                SetBakeDirty();
            else
            {
                bool isDirty;

                CheckOffsetDirty(out isDirty);

                if (isDirty)
                    return;

                foreach (var s in shapes)
                {
                    if (s && s.enabled && s.gameObject.activeInHierarchy && s.BakedForLocation_Version != LocationVersion)
                    {
                        var mat = s.GetMaterialForBake();

                        if (mat)
                        {
                            s.BakedForLocation_Version = LocationVersion;
                            Paint(mat);
                            return;
                        }
                    }
                }
            }
        }

        public void LateUpdate()
        {
            bool isDirty;
            
            CheckOffsetDirty(out isDirty);

            if (isDirty || (framesToBake > 0 && (_renderedAtFrame != Time.frameCount)))
            {
                framesToBake--;
                Paint(material);
                OnOffsetRendered();
            }
        }

        private int _inspectedStuff = -1;

        public void Inspect()
        {

            pegi.nl();

            "Volume".edit_enter_Inspect(ref volume, ref _inspectedStuff, 0).nl();

            if ("Baking".isEntered(ref _inspectedStuff, 1).nl())
            {
                var baking = enabled;
                if ("Bake {0}".F(framesToBake).toggleIcon(ref baking))
                    enabled = baking;

                if (framesToBake < 1 && "Reset Baking".Click())
                    SetBakeDirty();

                pegi.nl();

                "Texture:".edit(ref _texA).nl();

                "Back Buffer:".edit(ref _texB);
                pegi.FullWindow.DocumentationClickOpen("Second buffer needs to be same kind of RenderTexture as Texture");
                pegi.nl();
                "Material".edit(ref material).nl();

                if ("Render".Click().nl())
                    Paint(material);
            }


            if (_inspectedStuff == -1) 
            {
                "Position: {0}".F(_currentPosition.ToString()).nl();
            }

            if (!_texA && volume && volume.Texture)
            {
                if (volume.Texture is Texture2D)
                    "Volume need to Use Render Texture for Baking".writeWarning();
                else if ("Assign Tex A from volume".Click().nl())
                    _texA = volume.Texture as RenderTexture;
            }

        }

    }

    [PEGI_Inspector_Override(typeof(VolumeTracingBaker))] internal class VolumeTracingBakerDrawer : PEGI_Inspector_Override   {  }

}