using PlaytimePainter;
using UnityEngine;
using QuizCanners.Utils;
using QuizCanners.Inspect;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace QuizCanners.RayTracing
{

    public class VolumeTracingBaker : MonoBehaviour, IPEGI
    {
        public bool bakingEnabled = true;
        public int LocationVersion 
        {
            get;
            private set;
        }

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

        public void Paint(Material withMaterial) 
        {
            if (Target && Source && withMaterial)
            {
                RenderTextureBuffersManager.BlitGL(Source, Target, withMaterial);
                if (volume)
                    volume.Texture = Target;

                targetIsA = !targetIsA;

                _renderedAtFrame = Time.frameCount;
            }
        }

        private Vector3 _previous = Vector3.zero;
        private Vector4 _previousDiff = Vector3.zero;
        private int _renderedAtFrame;

        public void SetBakeDirty() => framesToBake = 300;

        private int framesToBake = 300;

        public void LateUpdate()
        {
            if (bakingEnabled)
            {
                if (volume)
                {
                    var current = volume.PosSize4Shader.XYZ();

                    var diff = (current - _previous).ToVector4(volume.size); 
                    if (diff != _previousDiff)
                    {
                        PositionOffsetAndScale.GlobalValue = diff;
                        LocationVersion++;
                        SetBakeDirty();
                    }
                    _previousDiff = diff;
                    _previous = current;
                }

                if (framesToBake > 0 && (_renderedAtFrame != Time.frameCount))
                {
                    framesToBake--;
                    Paint(material);
                }
            }
        }

        public void Inspect()
        {

            pegi.toggleDefaultInspector(this);

            "Bake {0}".F(framesToBake).toggleIcon(ref bakingEnabled);

            if (framesToBake < 1 && "Reset Baking".Click())
                SetBakeDirty();

            pegi.nl();

            "Volume".edit(ref volume);
            if (!volume && icon.Search.Click())
                volume = GetComponent<VolumeTexture>();
            pegi.nl();
            "Texture:".edit(ref _texA).nl();

            if (!_texA && volume && volume.Texture)
            {
                if (volume.Texture is Texture2D)
                    "Volume need to Use Render Texture for Baking".writeWarning();
                else if ("Assign Tex A from volume".Click().nl())
                    _texA = volume.Texture as RenderTexture;
            } 

            "Back Buffer:".edit(ref _texB);
            pegi.FullWindow.DocumentationClickOpen("Second buffer needs to be same kind of RenderTexture as Texture");
            pegi.nl();
            "Material".edit(ref material).nl();

            if ("Render".Click().nl())
                Paint(material);

        }

    }

#if UNITY_EDITOR
    [CustomEditor(typeof(VolumeTracingBaker))] internal class VolumeTracingBakerDrawer : PEGI_Inspector_Mono<VolumeTracingBaker>
    {
    }
#endif
}