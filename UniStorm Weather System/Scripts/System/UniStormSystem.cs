using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UniStorm.Effects;
using UniStorm.Utility;
using QuizCanners.Utils;
using System;
using Random = UnityEngine.Random;
using System.Linq;
using QuizCanners.Migration;
using QuizCanners.RayTracing;

namespace UniStorm
{
    [ExecuteAlways]
    public partial class UniStormSystem : Singleton.BehaniourBase, ICfg
    {
        public SO_WetherConfiguration Configuration;
        public UniStorm.Sounds SoundManager = new ();
        public UniStorm.Particles Particles = new ();
        public UniStorm.LightningStrikes LightingStrikes = new();


        public int ConvergenceSpeed = 75;
        public int NearMarchSteps = 100;
        public int DistantMarchSteps = 10;
        public EnableFeature UpdateMarchStepsDuringRuntime = EnableFeature.Disabled;
        public bool ColorSpaceSuggestionDismissed = false;
        public int RendersPerFrame = 1;
        UniStormClouds UniStormClouds => Singleton.Get<UniStormClouds>();

        public Color MoonlightColor;
        //Camera & Player
        public Transform PlayerTransform;
        public Camera PlayerCamera;
        public bool m_PlayerFound = false;
        public EnableFeature GetPlayerAtRuntime = EnableFeature.Disabled;
        public EnableFeature UseRuntimeDelay = EnableFeature.Disabled;

        public string PlayerTag = "Player";
        public string CameraTag = "MainCamera";
        public string CameraName = "MainCamera";

        public bool m_HourUpdate = false;

        public enum EnableFeature
        {
            Enabled = 0, Disabled = 1
        }

        public EnableFeature ForceLowClouds = EnableFeature.Disabled;
        public int LowCloudHeight = 225;
        public int CloudDomeTrisCountX = 48;
        public int CloudDomeTrisCountY = 32;
        public bool IgnoreConditions = false;
        public AnimationCurve CloudyFadeControl = AnimationCurve.Linear(0, 0.22f, 24, 0);
        public AnimationCurve PrecipitationGraph = AnimationCurve.Linear(1, 0, 13, 100);
        public List<SO_WeatherType> AllWeatherTypes = new();
        public SO_WeatherType CurrentWeatherType;
        public bool ByPassCoverageTransition = false;
        public static bool m_IsFading;
        public int TransitionSpeed = 5;
        public int HourToChangeWeather;
        Coroutine CloudCoroutine, CloudTallnessCoroutine, AuroraCoroutine;
        Coroutine  CloudHeightCoroutine, CloudProfileCoroutine;
        

        [Header("Lightning")]
        public LightningSystem m_UniStormLightningSystem;
        public LightningStrike m_LightningStrikeSystem;
        public int LightningSecondsMin = 5;
        public int LightningSecondsMax = 10;
        public Color LightningColor = new(0.725f,0.698f,0.713f, 1);
        public Color LightningLightColor = new(195f / 255f, 213f / 255f, 226f / 255f, 1);
        int m_LightningSeconds;
        float m_LightningTimer;
        public List<AnimationCurve> LightningFlashPatterns = new();
        public List<AudioClip> ThunderSounds = new();
        public int LightningGroundStrikeOdds = 50;
        public GameObject LightningStrikeEffect;
        public GameObject LightningStrikeFire;
        public EnableFeature LightningStrikes = EnableFeature.Enabled;
        public EnableFeature LightningStrikesEmeraldAI = EnableFeature.Disabled;
        public List<string> LightningFireTags = new();
        public float LightningLightIntensityMin = 1;
        public float LightningLightIntensityMax = 3;
        public int LightningGenerationDistance = 100;
        public int LightningDetectionDistance = 20;
        public GameObject LightningStruckObject;

        [Header("Emerald")]
        public string EmeraldAITag = "Respawn";
        public int EmeraldAIRagdollForce = 500;
        public int EmeraldAILightningDamage = 500;

        public float m_CurrentCloudHeight;
        public int CloudSpeed = 8;
        public int CloudTurbulence = 8;
        public LayerMask DetectionLayerMask;
     
        public int m_CloudSeed;
        public EnableFeature UseDithering = EnableFeature.Enabled;
        public float SnowAmount = 0;
        SO_WeatherType TempWeatherType;
        public AnimationCurve SunAttenuationCurve = AnimationCurve.Linear(0, 1, 24, 3);
        public AnimationCurve AmbientIntensityCurve = AnimationCurve.Linear(0, 0, 24, 1);
      
        public CloudTypeEnum CloudType = CloudTypeEnum.Volumetric;
        public enum CloudTypeEnum
        {
            _2D = 0, Volumetric
        }

        public CloudQualityEnum CloudQuality = CloudQualityEnum.High;
        public enum CloudQualityEnum
        {
            Low = 0, Medium, High, Ultra
        }

        public float FogLightFalloff = 9.7f;
        public float CameraFogHeight = 0.85f;

        internal Material m_CloudDomeMaterial;
        internal Material m_SkyBoxMaterial;
       
        public AnimationCurve SunIntensityCurve = AnimationCurve.Linear(0, 0, 24, 5);
       
        public AnimationCurve SunAtmosphericFogIntensity = AnimationCurve.Linear(0, 2, 24, 2);
        public AnimationCurve SunControlCurve = AnimationCurve.Linear(0, 1, 24, 1);
        public AnimationCurve MoonAtmosphericFogIntensity = AnimationCurve.Linear(0, 1, 24, 1);

        public float AtmosphericFogMultiplier = 1;
       
    
        public AnimationCurve AtmosphereThickness = AnimationCurve.Linear(0, 1, 24, 3);
        public AnimationCurve EnvironmentReflections = AnimationCurve.Linear(0, 0, 24, 1);

      
             
        [System.Serializable]
        public class MoonPhaseClass
        {
            public Texture MoonPhaseTexture = null;
            public float MoonPhaseIntensity = 1;
        }


        public GameObject m_AuroraParent;


        public CloudRenderTypeEnum CloudRenderType = CloudRenderTypeEnum.Transparent;
        public enum CloudRenderTypeEnum
        {
            Transparent = 0, Opaque
        }

        //Light Shafts
        public AnimationCurve SunLightShaftIntensity = AnimationCurve.Linear(0, 1, 24, 1);
        public Gradient SunLightShaftsColor;
        public float SunLightShaftsBlurSize = 4.86f;
        public int SunLightShaftsBlurIterations = 2;
        public AnimationCurve MoonLightShaftIntensity = AnimationCurve.Linear(0, 1, 24, 1);
        public Gradient MoonLightShaftsColor;
        public float MoonLightShaftsBlurSize = 3f;
        public int MoonLightShaftsBlurIterations = 2;


        //Colors
        public Gradient SunColor;
        public Gradient StormySunColor;
        public Gradient MoonColor;
        public Gradient SkyColor;
        public Gradient AmbientSkyLightColor;
        public Gradient StormyAmbientSkyLightColor;
        public Gradient AmbientEquatorLightColor;
        public Gradient StormyAmbientEquatorLightColor;
        public Gradient AmbientGroundLightColor;
        public Gradient StormyAmbientGroundLightColor;
        public Gradient CloudLightColor;
        public Gradient StormyCloudLightColor;
        public Gradient CloudBaseColor;
        public Gradient CloudStormyBaseColor;
        public Gradient SkyTintColor;
        [GradientUsage(true)]

        public Gradient FogLightColor;
        public Gradient StormyFogLightColor;


        //Internal
      //  float m_FadeValue;
        internal float m_ReceivedCloudValue;

        public Gradient DefaultCloudBaseColor;
        GradientColorKey[] CloudColorKeySwitcher;

        public Gradient DefaultCloudLightColor;
        GradientColorKey[] CloudLightColorKeySwitcher;

        public Gradient DefaultAmbientSkyLightBaseColor;
        GradientColorKey[] AmbientSkyLightColorKeySwitcher;

        public Gradient DefaultAmbientEquatorLightBaseColor;
        GradientColorKey[] AmbientEquatorLightColorKeySwitcher;

        public Gradient DefaultAmbientGroundLightBaseColor;
        GradientColorKey[] AmbientGroundLightColorKeySwitcher;

        public Gradient DefaultSunLightBaseColor;
        GradientColorKey[] SunLightColorKeySwitcher;

        public bool UniStormInitialized = false;
    
        public bool UpgradedToCurrentVersion = false;
        public VRState VRStateData;
        readonly float m_DetailStrength = 0.072f;


      

        internal readonly ShaderProperty.FloatValue CLOUD_SPEED = new("_uCloudsMovementSpeed");
        internal readonly ShaderProperty.ColorFloat4Value MOON_COLOR = new("_MoonColor");
        internal readonly ShaderProperty.FloatValue CLOUD_MARCH_STEPS = new("CLOUD_MARCH_STEPS");
        internal readonly ShaderProperty.FloatValue DISTANT_CLOUD_MARCH_STEPS = new("DISTANT_CLOUD_MARCH_STEPS");
        internal readonly ShaderProperty.FloatValue _DistantCloudUpdateSpeed = new("_DistantCloudUpdateSpeed");

        Material previousSkyBox;

        protected override void OnAfterEnable()
        {
            if (!Application.isPlaying)
                return;

            if (VRStateData == null)
            {
                //When in the Unity Editor, check the state of VR, along with the StereoRenderingPath, and cache it within VRState so can be used during runtime for VR related features.
                var m_VRStateData = Resources.Load("VR State Data") as VRState;
#if UNITY_EDITOR
                m_VRStateData.VREnabled = false;//UnityEditor.PlayerSettings.virtualRealitySupported;
                if (UnityEditor.PlayerSettings.stereoRenderingPath == UnityEditor.StereoRenderingPath.SinglePass)
                    m_VRStateData.StereoRenderingMode = VRState.StereoRenderingModes.SinglePass;
                else if (UnityEditor.PlayerSettings.stereoRenderingPath == UnityEditor.StereoRenderingPath.MultiPass)
                    m_VRStateData.StereoRenderingMode = VRState.StereoRenderingModes.MultiPass;
#endif
                VRStateData = m_VRStateData;
            }

            if (Application.isPlaying)
            {
                UniStormInitialized = false;

                InitializeCloudSettings();

                if (GetPlayerAtRuntime == EnableFeature.Enabled)
                {
                    PlayerCamera = GameObject.FindWithTag(CameraTag).GetComponent<Camera>();
                    PlayerTransform = PlayerCamera.transform;
                }


                if (!PlayerTransform || !PlayerCamera)
                {
                    Debug.LogWarning("(UniStorm has been disabled) - No player/camera has been assigned on the Player Transform/Player Camera slot." +
                        "Please go to the Player & Camera tab and assign one.");
                    enabled = false;
                    return;
                }
                else if (!PlayerTransform.gameObject.activeSelf || !PlayerCamera.gameObject.activeSelf)
                {
                    Debug.LogWarning("(UniStorm has been disabled) - The player/camera game object is disabled on the Player Transform/Player Camera slot is disabled. " +
                        "Please go to the Player & Camera tab and ensure your player/camera is enabled.");
                    enabled = false;
                    return;
                }

                //If our current weather type is not apart of the available weather type lists, assign it to the proper category.
                if (!AllWeatherTypes.Contains(CurrentWeatherType))
                    AllWeatherTypes.Add(CurrentWeatherType);

                SoundManager.Setup();
                Particles.Setup();

                //Initialize the color switching keys. This allows gradient colors to be switched between stormy and regular.
                CloudColorKeySwitcher = new GradientColorKey[7];
                CloudColorKeySwitcher = CloudBaseColor.colorKeys;
                DefaultCloudBaseColor.colorKeys = new GradientColorKey[7];
                DefaultCloudBaseColor.colorKeys = CloudBaseColor.colorKeys;

                CloudLightColorKeySwitcher = new GradientColorKey[7];
                CloudLightColorKeySwitcher = CloudLightColor.colorKeys;
                DefaultCloudLightColor.colorKeys = new GradientColorKey[7];
                DefaultCloudLightColor.colorKeys = CloudLightColor.colorKeys;

                AmbientSkyLightColorKeySwitcher = new GradientColorKey[7];
                AmbientSkyLightColorKeySwitcher = AmbientSkyLightColor.colorKeys;
                DefaultAmbientSkyLightBaseColor.colorKeys = new GradientColorKey[7];
                DefaultAmbientSkyLightBaseColor.colorKeys = AmbientSkyLightColor.colorKeys;

                AmbientEquatorLightColorKeySwitcher = new GradientColorKey[7];
                AmbientEquatorLightColorKeySwitcher = AmbientEquatorLightColor.colorKeys;
                DefaultAmbientEquatorLightBaseColor.colorKeys = new GradientColorKey[7];
                DefaultAmbientEquatorLightBaseColor.colorKeys = AmbientEquatorLightColor.colorKeys;

                AmbientGroundLightColorKeySwitcher = new GradientColorKey[7];
                AmbientGroundLightColorKeySwitcher = AmbientGroundLightColor.colorKeys;
                DefaultAmbientGroundLightBaseColor.colorKeys = new GradientColorKey[7];
                DefaultAmbientGroundLightBaseColor.colorKeys = AmbientGroundLightColor.colorKeys;

                SunLightColorKeySwitcher = new GradientColorKey[6];
                SunLightColorKeySwitcher = SunColor.colorKeys;
                DefaultSunLightBaseColor.colorKeys = new GradientColorKey[6];
                DefaultSunLightBaseColor.colorKeys = SunColor.colorKeys;

                m_CloudDomeMaterial = UniStormClouds.skyMaterial;
                GameObject AuroraSystem = Resources.Load("UniStorm Auroras") as GameObject;
                if (!m_AuroraParent)
                {
                    m_AuroraParent = Instantiate(AuroraSystem, transform.position, Quaternion.identity);
                    m_AuroraParent.transform.SetParent(UniStormClouds.transform);
                    m_AuroraParent.transform.localPosition = Vector3.zero;
                    m_AuroraParent.transform.localScale = Vector3.one * 0.001f;
                    m_AuroraParent.name = "UniStorm Auroras";
                }

                m_CloudDomeMaterial.SetFloat("_MaskMoon", 1);

                //Get randomized cloud amount 
                if (CurrentWeatherType.CloudLevel == SO_WeatherType.CloudLevelEnum.DontChange)
                {
                    m_CloudDomeMaterial.Set(CloudProfile.COVERAGE, Random.Range(0.4f, 0.55f));
                }

                m_SkyBoxMaterial = (Material)Resources.Load("UniStorm Skybox");
                previousSkyBox = RenderSettings.skybox;
                RenderSettings.skybox = m_SkyBoxMaterial;


  
                transform.position = new Vector3(PlayerTransform.position.x, transform.position.y, PlayerTransform.position.z);

                CreateLightning();
                UpdateColors();
                SkipWeatherTransition();

                if (CurrentWeatherType.UseAuroras == SO_WeatherType.Yes_No.Yes)
                {
                    m_AuroraParent.SetActive(true);
                    Shader.SetGlobalFloat("_LightIntensity", CurrentWeatherType.AuroraIntensity);
                    Shader.SetGlobalColor("_InnerColor", CurrentWeatherType.AuroraInnerColor);
                    Shader.SetGlobalColor("_OuterColor", CurrentWeatherType.AuroraOuterColor);
                }
                else
                {
                    m_AuroraParent.SetActive(false);
                }

                Material m_CloudsMaterial = UniStormClouds.skyMaterial;
                if (Configuration.CustomizeQuality && CloudType == CloudTypeEnum.Volumetric)
                {
                    if (CloudQuality == CloudQualityEnum.Ultra)
                    {
                        m_CloudsMaterial.SetFloat("_UseHighConvergenceSpeed", 1);
                        m_CloudDomeMaterial.SetFloat("_DistantCloudUpdateSpeed", ConvergenceSpeed);
                        Shader.SetGlobalFloat("CLOUD_MARCH_STEPS", NearMarchSteps);
                        Shader.SetGlobalFloat("DISTANT_CLOUD_MARCH_STEPS", DistantMarchSteps);
                    }
                    else
                    {
                        m_CloudsMaterial.SetFloat("_UseHighConvergenceSpeed", 0);
                        Shader.SetGlobalFloat("DISTANT_CLOUD_MARCH_STEPS", 10);
                    }
                }
                else
                {
                    if (CloudQuality == CloudQualityEnum.Ultra) //If CustomizeQuality is not used, apply the default Ultra settings.
                    {
                        m_CloudsMaterial.SetFloat("_UseHighConvergenceSpeed", 1);
                        m_CloudDomeMaterial.SetFloat("_DistantCloudUpdateSpeed", 75);

                
                        CLOUD_MARCH_STEPS.GlobalValue = 100;
                        DISTANT_CLOUD_MARCH_STEPS.GlobalValue = 10;
                    }
                    else
                    {
                        m_CloudsMaterial.SetFloat("_UseHighConvergenceSpeed", 0);
                        DISTANT_CLOUD_MARCH_STEPS.GlobalValue = 10;
                    }
                }

                //Enable Single Pass support for UniStorm's clouds, given that the VR settings are enabled.
                if (VRStateData.VREnabled && VRStateData.StereoRenderingMode == VRState.StereoRenderingModes.SinglePass)
                    m_CloudsMaterial.SetFloat("_VRSinglePassEnabled", 1);
                else if (!VRStateData.VREnabled || VRStateData.VREnabled && VRStateData.StereoRenderingMode == VRState.StereoRenderingModes.MultiPass)
                    m_CloudsMaterial.SetFloat("_VRSinglePassEnabled", 0);

                UniStormInitialized = true;


                Singleton.Try<UniStormClouds>(s => s.Initialize());
            }
        }


        protected override void OnBeforeOnDisableOrEnterPlayMode(bool afterEnableCalled)
        {
            base.OnBeforeOnDisableOrEnterPlayMode(afterEnableCalled);

            RenderSettings.skybox = previousSkyBox;
        }



        void InitializeCloudSettings()
        {
            Material m_CloudsMaterial = UniStormClouds.skyMaterial;
            UniStormClouds.performance = (UniStormClouds.CloudPerformance)CloudQuality;
            m_CloudsMaterial.Set(CLOUD_SPEED, CloudSpeed);
            m_CloudsMaterial.SetFloat("_uCloudsTurbulenceSpeed", CloudTurbulence);
            m_CloudsMaterial.SetColor("_uMoonColor", MoonlightColor);
            m_CloudsMaterial.SetColor("_uLightningColor", LightningLightColor);

            if (ForceLowClouds == EnableFeature.Enabled)
            {
                Shader.SetGlobalFloat("_uCloudNoiseScale", 1.8f);
            } 
            else
            {
                Shader.SetGlobalFloat("_uCloudNoiseScale", 0.7f);
            }

            if (CloudType == CloudTypeEnum.Volumetric)
            {
                UniStormClouds.cloudType = UniStormClouds.CloudType.Volumetric;

                CloudProfile m_CP = CurrentWeatherType.CloudProfileComponent;
                m_CP.SetToShader();
                m_CloudsMaterial.Set(CloudProfile.DETAIL_SCALE, 1000f);

                if (QualitySettings.activeColorSpace == ColorSpace.Gamma)
                {
                    m_CloudsMaterial.Set(CloudProfile.COVERAGE_BIAS, m_CP.CoverageBias);
                    m_CloudsMaterial.Set(CloudProfile.DETAIL_STRENGTH, m_CP.DetailStrength);
                }
                else
                {
                    m_CloudsMaterial.Set(CloudProfile.COVERAGE_BIAS, 0.02f);
                    m_CloudsMaterial.Set(CloudProfile.DETAIL_STRENGTH, m_DetailStrength);
                }

                m_CloudsMaterial.SetFloat("_uCloudsBaseScale", 1.72f);
            }
            else if (CloudType == CloudTypeEnum._2D)
            {
                UniStormClouds.cloudType = UniStormClouds.CloudType.TwoD;
                m_CloudsMaterial.Set(CloudProfile.EDGE_SOFTNESS, 0.05f);
                m_CloudsMaterial.Set(CloudProfile.BOTTOM_SOFTNESS, 0.15f);
                m_CloudsMaterial.Set(CloudProfile.DETAIL_STRENGTH, 0.1f);
                m_CloudsMaterial.Set(CloudProfile.DENSIY, 1f);
                m_CloudsMaterial.Set(CloudProfile.BASE_SCALE, 1.5f);
                m_CloudsMaterial.Set(CloudProfile.DETAIL_SCALE, 700f);
            }
        }

        //Initialize our starting weather so it fades in instantly on start
        public void SkipWeatherTransition()
        {
            if (Application.isPlaying == false)
                return;

            Particles.StopCoroutines();
            SoundManager.StopCoroutines();

            if (CloudCoroutine != null)  StopCoroutine(CloudCoroutine); 
            if (CloudHeightCoroutine != null) StopCoroutine(CloudHeightCoroutine); 
            if (CloudProfileCoroutine != null)  StopCoroutine(CloudProfileCoroutine); 
            if (AuroraCoroutine != null)  StopCoroutine(AuroraCoroutine); 

            //If our starting weather type's conditions are not met, keep rerolling weather until an appropriate one is found.
            TempWeatherType = CurrentWeatherType;

            CurrentWeatherType = TempWeatherType;
            m_ReceivedCloudValue = GetCloudLevel(true);
            m_CloudDomeMaterial.Set(CloudProfile.COVERAGE, m_ReceivedCloudValue);

            if (ForceLowClouds == EnableFeature.Disabled)
            {
                m_CloudDomeMaterial.Set(CloudProfile.BOTTOM, CurrentWeatherType.CloudHeight);
                m_CurrentCloudHeight = CurrentWeatherType.CloudHeight;
            }
            else
            {
                m_CloudDomeMaterial.Set(CloudProfile.BOTTOM, LowCloudHeight);
                m_CurrentCloudHeight = LowCloudHeight;
            }            

            Particles.SkipTransition();

            //Instantly change all of our gradients to the stormy gradients
            if (CurrentWeatherType.PrecipitationWeatherType == SO_WeatherType.Yes_No.Yes)
            {
                

                if (CurrentWeatherType.OverrideCloudColor == SO_WeatherType.Yes_No.No)
                {
                    SetColors(CloudColorKeySwitcher, CloudStormyBaseColor);
                }
                else if (CurrentWeatherType.OverrideCloudColor == SO_WeatherType.Yes_No.Yes)
                {
                    SetColors(CloudColorKeySwitcher, CurrentWeatherType.CloudColor);
                }
                
                SetColors(CloudLightColorKeySwitcher, StormyCloudLightColor);


                SetColors(AmbientSkyLightColorKeySwitcher, StormyAmbientSkyLightColor);

                SetColors(AmbientEquatorLightColorKeySwitcher, StormyAmbientEquatorLightColor);

                SetColors(AmbientGroundLightColorKeySwitcher, StormyAmbientGroundLightColor);

                SetColors(SunLightColorKeySwitcher, StormySunColor);


                CloudLightColor.SetKeys(CloudLightColorKeySwitcher, CloudLightColor.alphaKeys);
                CloudBaseColor.SetKeys(CloudColorKeySwitcher, CloudBaseColor.alphaKeys);
                AmbientSkyLightColor.SetKeys(AmbientSkyLightColorKeySwitcher, AmbientSkyLightColor.alphaKeys);
                AmbientEquatorLightColor.SetKeys(AmbientEquatorLightColorKeySwitcher, AmbientEquatorLightColor.alphaKeys);
                AmbientGroundLightColor.SetKeys(AmbientGroundLightColorKeySwitcher, AmbientGroundLightColor.alphaKeys);
                SunColor.SetKeys(SunLightColorKeySwitcher, SunColor.alphaKeys);
            }
            //Instantly change all of our gradients to the regular gradients
            else if (CurrentWeatherType.PrecipitationWeatherType == SO_WeatherType.Yes_No.No)
            {
                m_CloudDomeMaterial.SetFloat("_uCloudAlpha", 1);


                if (CurrentWeatherType.OverrideCloudColor == SO_WeatherType.Yes_No.No)
                {
                    SetColors(CloudColorKeySwitcher, DefaultCloudBaseColor);
                }
                else
                {
                    SetColors(CloudColorKeySwitcher, CurrentWeatherType.CloudColor);
                }
                
                SetColors(AmbientSkyLightColorKeySwitcher, DefaultAmbientSkyLightBaseColor);

                SetColors(CloudLightColorKeySwitcher, DefaultCloudLightColor);


                SetColors(AmbientEquatorLightColorKeySwitcher, DefaultAmbientEquatorLightBaseColor);

                SetColors(AmbientGroundLightColorKeySwitcher, DefaultAmbientGroundLightBaseColor);

                SetColors(SunLightColorKeySwitcher, DefaultSunLightBaseColor);

                CloudLightColor.SetKeys(CloudLightColorKeySwitcher, CloudLightColor.alphaKeys);
                CloudBaseColor.SetKeys(CloudColorKeySwitcher, CloudBaseColor.alphaKeys);
                AmbientSkyLightColor.SetKeys(AmbientSkyLightColorKeySwitcher, AmbientSkyLightColor.alphaKeys);
                AmbientEquatorLightColor.SetKeys(AmbientEquatorLightColorKeySwitcher, AmbientEquatorLightColor.alphaKeys);
                AmbientGroundLightColor.SetKeys(AmbientGroundLightColorKeySwitcher, AmbientGroundLightColor.alphaKeys);
                SunColor.SetKeys(SunLightColorKeySwitcher, SunColor.alphaKeys);
            }

            SoundManager.SkipTransition();

            static void SetColors(GradientColorKey[] A, Gradient B)
            {
                var grad = B.colorKeys;

                int max = Math.Min(A.Length, grad.Length);

                for (int i = 0; i < max; i++)
                    A[i].color = grad[i].color;
            }
        }

        //If follow player is enabled, adjust the distant UniStorm components to the player's position


        //Create and positioned UniStorm's moon
        
        //Sets up UniStorm's sun
 
   

        //Create, setup, and assign all needed lightning components
        void CreateLightning()
        {
            if (m_UniStormLightningSystem)
                return;

            GameObject CreatedLightningSystem = new("UniStorm Lightning System");
            m_UniStormLightningSystem = CreatedLightningSystem.AddComponent<LightningSystem>();
            m_UniStormLightningSystem.transform.SetParent(transform);

            for (int i = 0; i < ThunderSounds.Count; i++)
            {
                m_UniStormLightningSystem.ThunderSounds.Add(ThunderSounds[i]);
            }

           // GameObject CreatedLightningLight = new GameObject("UniStorm Lightning Light");
          //  CreatedLightningLight.AddComponent<Light>();
            /*
            m_LightningLight = CreatedLightningLight.GetComponent<Light>();
            m_LightningLight.type = LightType.Directional;
            m_LightningLight.transform.SetParent(this.transform);
            m_LightningLight.transform.localPosition = Vector3.zero;
            m_LightningLight.intensity = 0;
            m_LightningLight.shadowResolution = LightningShadowResolution;
            m_LightningLight.shadows = LightningShadowType;
            m_LightningLight.shadowStrength = LightningShadowStrength;
            m_LightningLight.color = LightningLightColor;*/
         //   m_UniStormLightningSystem.LightningLightSource = m_LightningLight;
            m_UniStormLightningSystem.PlayerTransform = PlayerTransform;
            m_UniStormLightningSystem.LightningGenerationDistance = LightningGenerationDistance;
            m_LightningSeconds = Random.Range(LightningSecondsMin, LightningSecondsMax);
            m_UniStormLightningSystem.LightningLightIntensityMin = LightningLightIntensityMin;
            m_UniStormLightningSystem.LightningLightIntensityMax = LightningLightIntensityMax;
        }

        //Move our sun according to the time of day
     
        void Update()
        {
            if (Application.isPlaying == false)
                return;

            //Only run UniStorm if it has been initialized.
            if (UniStormInitialized)
            {
                //Only allow runtime editing of Customize Quality settings if enabled.
                if (Configuration.CustomizeQuality && UpdateMarchStepsDuringRuntime == EnableFeature.Enabled && CloudQuality == CloudQualityEnum.Ultra)
                {
                    m_CloudDomeMaterial.Set(_DistantCloudUpdateSpeed, ConvergenceSpeed);
                    CLOUD_MARCH_STEPS.GlobalValue = NearMarchSteps;
                    DISTANT_CLOUD_MARCH_STEPS.GlobalValue = DistantMarchSteps;
                }

                UpdateColors();
                SoundManager.PlayTimeOfDaySound(UniStorm.Sounds.CurrentTimeOfDayEnum.Day);
                SoundManager.PlayTimeOfDayMusic(UniStorm.Sounds.CurrentTimeOfDayEnum.Day);

                //Generate our lightning, if the randomized lightning seconds have been met
                if (CurrentWeatherType.UseLightning == SO_WeatherType.Yes_No.Yes &&
                     (CurrentWeatherType.CloudLevel == SO_WeatherType.CloudLevelEnum.MostlyCloudy 
                     || CurrentWeatherType.CloudLevel == SO_WeatherType.CloudLevelEnum.Cloudy))
                    {
                        m_LightningTimer += Time.deltaTime;

                        //Only create a lightning strike if the clouds have fully faded in
                        if (m_LightningTimer >= m_LightningSeconds && m_CloudDomeMaterial.GetFloat("_uCloudsCoverage") >= 0.5f)
                        {
                            m_UniStormLightningSystem.LightningCurve = LightningFlashPatterns[Random.Range(0, LightningFlashPatterns.Count)];
                            m_UniStormLightningSystem.GenerateLightning();
                            m_LightningSeconds = Random.Range(LightningSecondsMin, LightningSecondsMax);
                            m_LightningTimer = 0;
                        }
                    }
                
            }
            else if (GetPlayerAtRuntime == EnableFeature.Enabled && !UniStormInitialized)
            {
                //Continue to look for our player until it's found. Once it is, UniStorm can be initialized.
                try
                {
                    PlayerTransform = GameObject.FindWithTag(PlayerTag).transform;
                    m_PlayerFound = true;
                }
                catch
                {
                    m_PlayerFound = false;
                }

            }
        }

        //Generate and return a random cloud intensity based on the current weather type cloud level
        float GetCloudLevel(bool InstantFade)
        {
            Random.InitState(System.DateTime.Now.Millisecond); //Initialize Random.Range with a random seed 
            float GeneratedCloudLevel = 0;

            if (CloudTallnessCoroutine != null) { StopCoroutine(CloudTallnessCoroutine); }
            
            if (CurrentWeatherType.CloudLevel == SO_WeatherType.CloudLevelEnum.Clear)
            {
                GeneratedCloudLevel = 0.36f;
            }
            else if (CurrentWeatherType.CloudLevel == SO_WeatherType.CloudLevelEnum.MostlyClear)
            {
                if (QualitySettings.activeColorSpace == ColorSpace.Gamma)
                    GeneratedCloudLevel = Random.Range(0.35f, 0.39f);
                else
                    GeneratedCloudLevel = Random.Range(0.41f, 0.44f);

     
            }
            else if (CurrentWeatherType.CloudLevel == SO_WeatherType.CloudLevelEnum.PartyCloudy)
            {
                if (QualitySettings.activeColorSpace == ColorSpace.Gamma)
                    GeneratedCloudLevel = Random.Range(0.43f, 0.47f);
                else
                    GeneratedCloudLevel = Random.Range(0.45f, 0.48f);

    
            }
            else if (CurrentWeatherType.CloudLevel == SO_WeatherType.CloudLevelEnum.MostlyCloudy)
            {
                if (QualitySettings.activeColorSpace == ColorSpace.Gamma)
                    GeneratedCloudLevel = Random.Range(0.5f, 0.55f);
                else
                    GeneratedCloudLevel = Random.Range(0.49f, 0.52f);
            }
            else if (CurrentWeatherType.CloudLevel == SO_WeatherType.CloudLevelEnum.Cloudy)
            {
    

                if (CurrentWeatherType.PrecipitationWeatherType == SO_WeatherType.Yes_No.No)
                {
                    if (QualitySettings.activeColorSpace == ColorSpace.Gamma)
                        GeneratedCloudLevel = 0.6f;
                    else
                        GeneratedCloudLevel = Random.Range(0.53f, 0.55f);

  
                }
                else if (CurrentWeatherType.PrecipitationWeatherType == SO_WeatherType.Yes_No.Yes)
                {
                    if (QualitySettings.activeColorSpace == ColorSpace.Gamma)
                        GeneratedCloudLevel = 0.6f;
                    else
                        GeneratedCloudLevel = Random.Range(0.53f, 0.55f);
                }
            }
            else if (CurrentWeatherType.CloudLevel == SO_WeatherType.CloudLevelEnum.DontChange)
            {
                GeneratedCloudLevel = m_CloudDomeMaterial.GetFloat("_uCloudsCoverage");
            }

            float RoundedCloudLevel = (float)Mathf.Round(GeneratedCloudLevel * 1000f) / 1000f;
            return RoundedCloudLevel;
        }

        /// <summary>
        /// Changes UniStorm's weather according to the Weather parameter.
        /// </summary>
        public void ChangeWeather (SO_WeatherType Weather)
        {
            if (!Weather)
                return;

            CurrentWeatherType = Weather;
            TransitionWeather();
        }

        public string CurrentWeatherTag 
        {
            get => CurrentWeatherType ? CurrentWeatherType.name : "NONE";
            set 
            {
                ChangeWeather(AllWeatherTypes.Where(w => w && w.name.Equals(value)).FirstOrDefault());
            }
        }

        void TransitionWeather()
        {
            if (Application.isPlaying == false)
            {
                return;
            }

            Particles.StopCoroutines();
            SoundManager.StopCoroutines();

            if (CloudCoroutine != null) { StopCoroutine(CloudCoroutine); }
            if (CloudHeightCoroutine != null) { StopCoroutine(CloudHeightCoroutine); }
            if (CloudProfileCoroutine != null) { StopCoroutine(CloudProfileCoroutine); }
            if (AuroraCoroutine != null) { StopCoroutine(AuroraCoroutine); }
     
            //Reset our time of day sounds timer so it doesn't play right after a weather change
            SoundManager.m_TimeOfDaySoundsTimer = 0;

            //Get randomized cloud amount based on cloud level from weather type.
            if (CurrentWeatherType.CloudLevel != SO_WeatherType.CloudLevelEnum.DontChange)
            {
                m_ReceivedCloudValue = GetCloudLevel(InstantFade: false);
            }


            CloudCoroutine = StartCoroutine(CloudFadeSequence(10 * TransitionSpeed, m_ReceivedCloudValue));


            if (ForceLowClouds == EnableFeature.Disabled)
            {
                CloudHeightCoroutine = StartCoroutine(CloudHeightSequence(10 * TransitionSpeed, CurrentWeatherType.CloudHeight));
            }

            if (CloudType == CloudTypeEnum.Volumetric && CurrentWeatherType.CloudLevel != SO_WeatherType.CloudLevelEnum.DontChange)
            {
                CloudProfile m_CP = CurrentWeatherType.CloudProfileComponent;

                if (QualitySettings.activeColorSpace == ColorSpace.Gamma)
                    CloudProfileCoroutine = StartCoroutine(CloudProfileSequence(10 * TransitionSpeed, m_CP.BaseSoftness, m_CP.Density, m_CP.CoverageBias));
                else
                    CloudProfileCoroutine = StartCoroutine(CloudProfileSequence(10 * TransitionSpeed,  m_CP.BaseSoftness,  m_CP.Density, 0.02f));
            }

 

            //Auroras
            if (CurrentWeatherType.UseAuroras == SO_WeatherType.Yes_No.Yes)
            {
                AuroraCoroutine = StartCoroutine(AuroraShaderFadeSequence(5 * TransitionSpeed, CurrentWeatherType.AuroraIntensity, CurrentWeatherType.AuroraInnerColor, CurrentWeatherType.AuroraOuterColor));
                
            }
            else
            {
                AuroraCoroutine = StartCoroutine(AuroraShaderFadeSequence(5 * TransitionSpeed, 0, CurrentWeatherType.AuroraInnerColor, CurrentWeatherType.AuroraOuterColor));
            }

       
           

            Particles.TransitionWeather();
            SoundManager.TransitionWeather();
        }

        //Calculates our moon phases. This is updated daily at exactly 12:00.

        float TimeOfDayFraction => Singleton.TryGetValue<Singleton_SunAndMoonRotator, float>(s => s.TimeOfDayFraction, defaultValue: 0.5f);

        //Continuously update our colors based on the time of day
        void UpdateColors()
        {
            m_SkyBoxMaterial.Set(_SkyTint, SkyColor.Evaluate(TimeOfDayFraction));
            m_SkyBoxMaterial.Set(_NightSkyTint, SkyTintColor.Evaluate(TimeOfDayFraction));

            m_CloudDomeMaterial.Set(_uCloudsAmbientColorTop, CloudLightColor.Evaluate(TimeOfDayFraction));
            m_CloudDomeMaterial.Set(_uCloudsAmbientColorBottom, CloudBaseColor.Evaluate(TimeOfDayFraction));
            m_CloudDomeMaterial.Set(_uSunColor, RenderSettings.sun.color); //SunColor.Evaluate(TimeOfDayFraction));

            m_CloudDomeMaterial.Set(_uAttenuation, SunAttenuationCurve.Evaluate(TimeOfDayFraction * 24));
            m_SkyBoxMaterial.Set(_AtmosphereThickness, AtmosphereThickness.Evaluate(TimeOfDayFraction * 24));

            RenderSettings.ambientIntensity = AmbientIntensityCurve.Evaluate(TimeOfDayFraction * 24);
            RenderSettings.ambientSkyColor = AmbientSkyLightColor.Evaluate(TimeOfDayFraction);
            RenderSettings.ambientEquatorColor = AmbientEquatorLightColor.Evaluate(TimeOfDayFraction);
            RenderSettings.ambientGroundColor = AmbientGroundLightColor.Evaluate(TimeOfDayFraction);
            RenderSettings.reflectionIntensity = EnvironmentReflections.Evaluate(TimeOfDayFraction * 24);

        }

        private readonly ShaderProperty.FloatValue _uAttenuation = new("_uAttenuation");
        private readonly ShaderProperty.FloatValue _AtmosphereThickness = new("_AtmosphereThickness");

        private readonly ShaderProperty.ColorFloat4Value _SkyTint = new("_SkyTint");
        private readonly ShaderProperty.ColorFloat4Value _NightSkyTint = new("_NightSkyTint");

        private readonly ShaderProperty.ColorFloat4Value _uCloudsAmbientColorTop = new("_uCloudsAmbientColorTop");
        private readonly ShaderProperty.ColorFloat4Value _uCloudsAmbientColorBottom = new("_uCloudsAmbientColorBottom");
        private readonly ShaderProperty.ColorFloat4Value _uSunColor = new("_uSunColor");


        void OnApplicationQuit()
        {
            if (Application.isPlaying == false)
                return;

            Shader.SetGlobalFloat("_LightIntensity", 0);

            m_CloudDomeMaterial.SetFloat("_uHorizonColorFadeStart", 0);
            m_CloudDomeMaterial.SetFloat("_uHorizonColorFadeEnd", 0);
            m_CloudDomeMaterial.SetFloat("_uHorizonFadeEnd", 0.18f);
            m_CloudDomeMaterial.SetFloat("_uSunFadeEnd", 0.045f);
            m_CloudDomeMaterial.SetFloat("_uCloudAlpha", 1);
            m_CloudDomeMaterial.SetFloat("_FogBlendHeight", 0.3f);
        }

        #region Encode & Decode

        public CfgEncoder Encode() => new CfgEncoder()
            .Add_String("weather type", CurrentWeatherTag);


        public void DecodeTag(string key, CfgData data)
        {
            switch (key)
            {
              
                case "weather type": CurrentWeatherTag = data.ToString(); break;
             
            }
        }

        #endregion
    }
}