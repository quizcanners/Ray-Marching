using System.Collections;
using System.Collections.Generic;
using PlayerAndEditorGUI;
using PlaytimePainter;
using UnityEngine;
using QuizCannersUtilities;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace RayMarching
{

    public class VolumeTracingBaker : MonoBehaviour, IPEGI
    {
        public bool bakingEnabled = true;

        public RenderTexture _texA;
        public RenderTexture _texB;
        bool targetIsA;
        public RenderTexture Target => targetIsA ? _texA : _texB;
        public RenderTexture Source => targetIsA ? _texB : _texA;

        public Material material;
        public VolumeTexture volume;


        private ShaderProperty.VectorValue _positionOffset;

        public ShaderProperty.VectorValue PositionAndScaleProperty
        {
            get
            {
                if (_positionOffset != null)
                    return _positionOffset;

                _positionOffset = new ShaderProperty.VectorValue(volume.name + "VOLUME_POSITION_OFFSET");

                return _positionOffset;
            }
        }

        private void Paint()
        {
            if (Target && Source && material)
            {
                RenderTextureBuffersManager.BlitGL(Source, Target, material);
                if (volume)
                    volume.Texture = Target;
                targetIsA = !targetIsA;
              
            }
        }

        Vector3 _previous = Vector3.zero;
        Vector4 _previousDiff = Vector3.zero;

        public void LateUpdate()
        {
            if (bakingEnabled)
            {
                if (volume)
                {
                    var current = volume.PosSize4Shader.XYZ();

                    var diff = (current - _previous).ToVector4(0); 
                    if (diff != _previousDiff)
                    {
                       // Debug.Log("Updating pos n shader before baking" + Time.frameCount);
                        PositionAndScaleProperty.GlobalValue = diff;
                    }
                    _previousDiff = diff;
                    _previous = current;
                }


                Paint();
            }
        }

        public bool Inspect()
        {
            var changed = false;

            pegi.toggleDefaultInspector(this);

            "Bake".toggleIcon(ref bakingEnabled).nl();

            "Volume".edit(ref volume).changes(ref changed);
            if (!volume && icon.Search.Click())
                volume = GetComponent<VolumeTexture>();
            pegi.nl();
            "Texture:".edit(ref _texA).nl(ref changed);

            if (!_texA && volume && volume.Texture)
            {
                if (volume.Texture is Texture2D)
                    "Volume need to Use Render Texture for Baking".writeWarning();
                else if ("Assign Tex A from volume".Click().nl())
                    _texA = volume.Texture as RenderTexture;
            } 

            "Back Buffer:".edit(ref _texB).changes(ref changed);
            pegi.FullWindowService.fullWindowDocumentationClickOpen("Second buffer needs to be same kind of RenderTexture as Texture");
            pegi.nl();
            "Material".edit(ref material).nl(ref changed);

            if ("Render".Click().nl())
                Paint();

            return changed;
        }

    }

#if UNITY_EDITOR
    [CustomEditor(typeof(VolumeTracingBaker))]
    public class VolumeTracingBakerDrawer : PEGI_Inspector_Mono<VolumeTracingBaker>
    {
    }
#endif
}