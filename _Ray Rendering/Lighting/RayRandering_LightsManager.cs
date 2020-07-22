
using QuizCanners.Migration;
using QuizCanners.Inspect;
using QuizCanners.Lerp;
using System;
using UnityEngine;
using QuizCanners.Utils;

using UniStorm;


namespace QuizCanners.RayTracing
{
    internal partial class Singleton_RayRendering
    {

        [Serializable]
        internal class WeatherManager : IPEGI, ILinkedLerping, ICfgCustom, IPEGI_ListInspect
        {
            [SerializeField] public SO_RayRenderingLightCfgs Configs;
            [SerializeField] private Texture _cloudShadowsTexture;

            private readonly ShaderProperty.TextureValue CLOUD_SHADOWS_TEXTURE = new("_qc_CloudShadows_Mask");
            private readonly ShaderProperty.FloatFeature CLOUD_SHADOWS_VISIBILITY = new("_qc_Rtx_CloudShadowsVisibility", "_qc_CLOUD_SHADOWS");

            private readonly LinkedLerp.ColorValue SUN_COLOR = new("Sun Colo", maxSpeed: 10);
        
            private readonly LinkedLerp.ShaderColor SKY_COLOR = new("_RayMarchSkyColor", Color.grey, 10);
            private readonly LinkedLerp.ShaderColor MIN_LIGH_COLOR = new("_RayMarthMinLight", Color.black, 10);
            // private readonly LinkedLerp.ShaderVector4 LIGHT_DIRECTION = new("_WorldSpaceLightPos0", Vector3.up.ToVector4(1), maxSpeed: 100);
            private readonly LinkedLerp.ShaderFloatFeature STARS_VISIBILITY = new(nName: "_StarsVisibility", featureDirective: "_RAY_MARCH_STARS");
            private readonly LinkedLerp.ColorValue FOG_COLOR = new("Fog", maxSpeed: 10);
            
            private bool lerpDone;

            protected Singleton_RayRendering RTX_Mgmt => Singleton.Get<Singleton_RayRendering>();
            protected Singleton_SunAndMoonRotator SunAndMoon => Singleton.Get<Singleton_SunAndMoonRotator>();

            private Light Sun
            {
                get => RenderSettings.sun;
                set { RenderSettings.sun = value; }
            }

            
            protected float Intensity 
            {
                get => Singleton.TryGetValue<Singleton_SunAndMoonRotator, float>(s => s.Intensity, logOnServiceMissing: false);
                set 
                {
                    Singleton.Try<Singleton_SunAndMoonRotator>(s => s.Intensity = value);

                  //  var val = LIGHT_DIRECTION.TargetValue;
                   // val.w = value;
                    //LIGHT_DIRECTION.TargetValue = val;
                }
            }

            protected Vector3 LightDirection 
            {
                get => Sun ? -Sun.transform.forward : Vector3.up;// LIGHT_DIRECTION.TargetValue.XYZ();
                set 
                {
                    if (Sun)
                        Sun.transform.forward = -value;
                   // LIGHT_DIRECTION.TargetValue = value.normalized.ToVector4(LIGHT_DIRECTION.TargetValue.w);
                }
            }

            private void UpdateEffectiveSunColor() 
            {

                Singleton.Try<Singleton_SunAndMoonRotator>(s =>  s.SharedLight.color = SUN_COLOR.TargetValue, logOnServiceMissing: false);

                // * Mathf.SmoothStep(-0.05f, 0.05f, LIGHT_DIRECTION.CurrentValue.y);
            }

            internal int MaxRenderFrames = 1500;

         

            #region Encode & Decode

            public void ManagedOnEnable() 
            {
                if (_cloudShadowsTexture)
                    CLOUD_SHADOWS_TEXTURE.GlobalValue = _cloudShadowsTexture;

                CLOUD_SHADOWS_VISIBILITY.GlobalValue = CLOUD_SHADOWS_VISIBILITY.latestValue;

                UpdateEffectiveSunColor();

                this.SkipLerp();
            }

            public void ManagedOnDisable()
            {
                Configs.IndexOfActiveConfiguration = -1;
                CLOUD_SHADOWS_VISIBILITY.GlobalValue = 0;
            }


            public CfgEncoder EncodeSelectedIndex => Configs.Encode();
            public void DecodeInternal(CfgData data)
            {
                //LIGHT_DIRECTION.TargetValue = new Vector3(-.8f, 1.7f, 2.6f).normalized.ToVector4(1f);
                new CfgDecoder(data).DecodeTagsFor(this);
                lerpDone = false;
                UpdateEffectiveSunColor();
                RTX_Mgmt.RequestLerps("Light Decoder");
                this.SkipLerp();
            }
            public void DecodeTag(string key, CfgData data)
            {
                switch (key)
                {
                    case "col": SUN_COLOR.TargetValue = data.ToColor();  break;
                    case "sky": SKY_COLOR.TargetValue = data.ToColor(); break;
                    case "fog": FOG_COLOR.TargetValue = data.ToColor(); break;
                    case "maxFrms": MaxRenderFrames = data.ToInt(); break;
                    case "ml": MIN_LIGH_COLOR.TargetValue = data.ToColor();   break;
                    case "liDir": LightDirection = data.ToVector3(); break;
                    case "intn": Intensity = data.ToFloat(); break;
                    case "stars": STARS_VISIBILITY.TargetValue = data.ToFloat(); break;
                    case "UniStorm": Singleton.Try<UniStormSystem>(s => s.Decode(data), logOnServiceMissing: false); break;
                    case "Shad": CLOUD_SHADOWS_VISIBILITY.SetGlobal(data.ToFloat()); break;
                    case "SnM": SunAndMoon.Decode(data); break;
                }
            }

            public CfgEncoder Encode() => new CfgEncoder()
                .Add("col", SUN_COLOR.TargetValue)
                .Add("sky", SKY_COLOR.TargetValue)
                .Add("fog", FOG_COLOR.TargetValue)
                .Add("maxFrms", MaxRenderFrames)
                .Add("ml", MIN_LIGH_COLOR.TargetValue)
                .Add("liDir", LightDirection)
                .Add("intn", Intensity)
                .Add("stars", STARS_VISIBILITY.TargetValue)
                .Add("UniStorm", Singleton.Get<UniStormSystem>())
                .Add("Shad", CLOUD_SHADOWS_VISIBILITY.latestValue)
                .Add("SnM", SunAndMoon)
              ;

            #endregion

            #region Update

            private readonly LerpData _lerpData = new(unscaledTime: true);

            public void ManagedUpdate() 
            {
                if (!lerpDone)
                {
                    _lerpData.Update(this, canSkipLerp: false);
                }

                Singleton.Try<Singleton_SunAndMoonRotator>(onFound: s =>
                {
                    if (!s.SharedLight)
                        return;

                    var targetLightSource = s.SharedLight;// s.Light.Sun.transform.forward.y > 0 ? s.Light.Moon : s.Light.Sun;

                    LightDirection = -targetLightSource.transform.forward;
                    //Intensity = targetLightSource.intensity;
                    SUN_COLOR.TargetAndCurrentValue = targetLightSource.color;
                    UpdateEffectiveSunColor();
                }, onFailed: () =>
                {
                  
                });
            }


            public void Portion(LerpData ld)
            {
                SUN_COLOR.Portion(ld);
                SKY_COLOR.Portion(ld);
                FOG_COLOR.Portion(ld);
                MIN_LIGH_COLOR.Portion(ld);
                //LIGHT_DIRECTION.Portion(ld);
                STARS_VISIBILITY.Portion(ld);
            }

            public void Lerp(LerpData ld, bool canSkipLerp)
            {
                SUN_COLOR.Lerp(ld, canSkipLerp);
                SKY_COLOR.Lerp(ld, canSkipLerp);
                FOG_COLOR.Lerp(ld, canSkipLerp);
                MIN_LIGH_COLOR.Lerp(ld, canSkipLerp);
                //LIGHT_DIRECTION.Lerp(ld, canSkipLerp);
                STARS_VISIBILITY.Lerp(ld, canSkipLerp);

                lerpDone |= ld.Done;

                RenderSettings.fogColor = FOG_COLOR.CurrentValue;
                Singleton.Try<Singleton_CameraOperatorConfigurable>(s => s.MainCam.backgroundColor = FOG_COLOR.CurrentValue, logOnServiceMissing: false);

                UpdateEffectiveSunColor();

            }

            #endregion

            #region Inspector

            private readonly pegi.EnterExitContext _context = new(playerPrefId: "rtxWthInsp");

            public void Inspect()
            {
                var changed = pegi.ChangeTrackStart();

                using (_context.StartContext())
                {

                    pegi.Nl();

                    if ("Uni Storm System".PegiLabel(pegi.Styles.ListLabel).IsEntered())
                    {
                        pegi.Nl();

                        Singleton.Try<UniStormSystem>(s =>
                        {
                            s.Nested_Inspect();
                        }, onFailed: () =>
                        {
                            "No UniStorm System Found".PegiLabel().Write_Hint();
                        });
                    }
                    pegi.Nl();


                    if (_context.IsAnyEntered == false)
                    {
                        var sky = RenderSettings.skybox;

                        if ("Skybox".PegiLabel().Edit(ref sky).Nl())
                            RenderSettings.skybox = sky;

                        Singleton.Try<UniStormSystem>(s => pegi.Nested_Inspect(s.InspectShort, s), logOnServiceMissing: false);

                        "Frames needed for baking".PegiLabel().Edit(ref MaxRenderFrames).Nl();

                        var sun = RenderSettings.sun;
                        "Sun (Render Settings)".PegiLabel().Edit(ref sun).OnChanged(() => RenderSettings.sun = sun);

                        pegi.ClickHighlight(sun);

                        pegi.Nl();

                        if (Sun)
                        {
                            Color sl = sun.color;
                            sl.a = sun.intensity;
                            SUN_COLOR.TargetValue = sl;
                        }

                        var col = SUN_COLOR.TargetValue;
                        if ("Light Color".PegiLabel().Edit(ref col).Nl())
                        {
                            SUN_COLOR.TargetValue = col;
                            if (sun)
                                sun.color = col;
                        }

                        var inten = Intensity;
                        if ("Intensity".PegiLabel(70).Edit(ref inten, 0, 5).Nl())
                            Intensity = inten;

                        col = SKY_COLOR.TargetValue;
                        if ("Sky Color".PegiLabel().Edit(ref col).Nl())
                            SKY_COLOR.TargetValue = col;

                        col = FOG_COLOR.TargetValue;
                        if ("Fog Color".PegiLabel().Edit(ref col).Nl())
                            FOG_COLOR.TargetValue = col;

                        var dc = MIN_LIGH_COLOR.TargetValue;
                        if ("Dark Color".PegiLabel().Edit(ref dc).Nl())
                            MIN_LIGH_COLOR.TargetValue = dc;

                        var stars = STARS_VISIBILITY.TargetValue;

                        bool useStars = stars > 0;
                        if (pegi.ToggleIcon(ref useStars))
                            STARS_VISIBILITY.TargetValue = useStars ? 1 : 0;

                        if ("Stars".PegiLabel(60).Edit_01(ref stars).Nl())
                            STARS_VISIBILITY.TargetAndCurrentValue = stars;

                        CLOUD_SHADOWS_VISIBILITY.InspectInList_Nested().Nl();

                        "Cloud Shadows".PegiLabel().Edit(ref _cloudShadowsTexture).Nl().OnChanged(()=> CLOUD_SHADOWS_TEXTURE.GlobalValue = _cloudShadowsTexture);
                            
                        ConfigurationsSO_Base.Inspect(ref Configs);
                    }



                    if (changed)
                    {
                        UpdateEffectiveSunColor();
                        this.SkipLerp();
                    }
                }
            }

            public void InspectInList(ref int edited, int ind)
            {
                var changes = pegi.ChangeTrackStart();
                if (Icon.Enter.Click() | "Weather".PegiLabel().ClickLabel())
                    edited = ind;

                if (!Configs)
                    "CFG".PegiLabel(60).Edit(ref Configs);
                else
                    pegi.Nested_Inspect(Configs.InspectShortcut, Configs);
                
                if (changes) 
                {
                    this.SkipLerp();
                }
            }

#endregion
        }
    }
}