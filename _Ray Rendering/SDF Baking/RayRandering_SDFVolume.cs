using QuizCanners.Inspect;
using QuizCanners.Lerp;
using QuizCanners.Utils;
using System;
using UnityEngine;

namespace QuizCanners.RayTracing
{
    public static partial class RayRendering
    {
        [Serializable]
        public class SDFVolume : IPEGI, IPEGI_ListInspect
        {
            [SerializeField] private Shader bakingShader;

            private RenderTexture _SDFtexture;
            private readonly OnDemandRenderTexture.Single _renderTexture = new("QcSDF", 1024, isFloat: false);
            private readonly ShaderProperty.TextureValue QC_SDF = new("Qc_SDF_Volume");
            private readonly ShaderProperty.FloatFeature QC_USE_SDF = new(name: "Qc_SDF_Visibility", "QC_USE_SDF_VOL");

            private readonly Gate.Integer _volumePositionVersion = new();
            private readonly Gate.Integer _bakerVersion = new();

            private readonly Gate.Frame _afterEnableGap = new();

            private int _bakeCounter;

            private bool Dirty
            {
                get
                {
                    return _bakerVersion.IsDirty(Mgmt.Version) 
                        || Singleton.GetValue<Singleton_VolumeTracingBaker, bool>(s => _volumePositionVersion.IsDirty(s.PositionVersion));
                }
                set
                {
                    if (value)
                    {
                        _bakerVersion.TryChange(Mgmt.Version);
                        Singleton.GetValue<Singleton_VolumeTracingBaker, bool>(s => _volumePositionVersion.TryChange(s.PositionVersion));
                    } else 
                    {
                        _bakerVersion.ValueIsDefined = false;
                    }
                }
            }
            internal void ManagedUpdate() 
            {
                if (!_afterEnableGap.IsFramesPassed(2))
                    return;

                if (Dirty)
                {
                    Render();
                }

                QC_USE_SDF.GlobalValue = QcLerp.LerpBySpeed(QC_USE_SDF.GlobalValue, Dirty ? 1 : 0, 1, unscaledTime: true);
            }

            internal void ManagedOnEnable()
            {
                _afterEnableGap.ValueIsDefined = false;
            }

            internal void ManagedOnDisable() 
            {
                if (_SDFtexture)
                {
                    _SDFtexture.DestroyWhatever();
                    _SDFtexture = null;
                }

                QC_USE_SDF.GlobalValue = 0;
            }

            void Render()
            {
                Dirty = false;
                _bakeCounter++;
                _renderTexture.Blit(bakingShader);
                QC_SDF.GlobalValue = _renderTexture.GetRenderTexture();
               
              //  Debug.Log("Updating SDF");
            }

            #region Inspector
            public void Inspect()
            {

                "Bakes done: {0}".F(_bakeCounter).PegiLabel().Nl();

                "Baking SHader".PegiLabel().Edit(ref bakingShader).Nl();
                if (bakingShader && "Blit".PegiLabel().Click())
                    Render();

                _renderTexture.Nested_Inspect();
            }

            public override string ToString() => "SDF Baker";

            public void InspectInList(ref int edited, int index)
            {
                if (Icon.Enter.Click() | ToString().PegiLabel().ClickLabel())
                    edited = index;

                if (Icon.Play.Click()) 
                {

                }
            }
            #endregion
        }
    }
}