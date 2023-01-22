using QuizCanners.Inspect;
using QuizCanners.Migration;
using QuizCanners.Utils;
using System;
using System.Collections.Generic;
using UniStorm.Effects;
using UnityEngine;
using static UniStorm.UniStormSystem;

namespace QuizCanners.RayTracing
{

    [ExecuteAlways]
    public class Singleton_SunAndMoonRotator : Singleton.BehaniourBase, IPEGI_Handles, ICfg
    {
        [Header("Sun")]
        [SerializeField] public Light SharedLight;
        [SerializeField] public GameObject SunObject;
        [SerializeField] public Transform m_SunTransform;
        [SerializeField] public Transform m_CelestialAxisTransform;

        public int SunAngle = 10;
        [NonSerialized] internal UniStormSunShafts m_SunShafts;

        [Header("Moon")]
        [SerializeField] public Transform Moon;
        public AnimationCurve MoonObjectFade = AnimationCurve.Linear(0, 1, 24, 1);
        public List<MoonPhaseClass> MoonPhaseList = new();
        public Color MoonPhaseColor = Color.white;
        public Material m_MoonPhaseMaterial;
        [SerializeField] Renderer m_MoonRenderer;
        [SerializeField] Transform m_MoonTransform;
        UniStormSunShafts m_MoonShafts;

        private float _timeOfDayFraction;

        [SerializeField] private float _intensity;

        public float Intensity 
        {
            get => _intensity;
            set 
            {
                _intensity = value;
                UpdateIntensity();
            }
        }
        private void UpdateIntensity() 
        {
            SharedLight.intensity = _intensity * QcMath.SmoothStep(0f, 0.3f, Mathf.Abs(m_CelestialAxisTransform.forward.y));
        }

        public bool LightIsSun => m_CelestialAxisTransform.forward.y < 0;

        public float TimeOfDayFraction 
        {
            get => _timeOfDayFraction;
            set 
            {
                _timeOfDayFraction = value;
                m_CelestialAxisTransform.eulerAngles = new Vector3(TimeOfDayFraction * 360 - 100, 180, 180);

                SharedLight.transform.rotation = LightIsSun ? m_CelestialAxisTransform.rotation : Quaternion.LookRotation(-m_CelestialAxisTransform.forward);

                m_MoonRenderer.gameObject.SetActive(m_CelestialAxisTransform.forward.y > -0.3f);
                SunObject.SetActive(m_CelestialAxisTransform.forward.y < 0.3f);

                SunObject.transform.localScale = Vector3.one * 50;//25 * SunSize.Evaluate(TimeOfDayFraction * 24) * Vector3.one;
                m_MoonTransform.localScale = Vector3.one * 40; //MoonSize.Evaluate(TimeOfDayFraction * 24) * m_MoonStartingSize;
                m_MoonPhaseMaterial.SetFloat("_MoonBrightness", MoonObjectFade.Evaluate(TimeOfDayFraction * 24));
                UpdateIntensity();
            }
        }

        private Camera PlayerCamera => Camera.main;

        protected override void OnAfterEnable()
        {
            base.OnAfterEnable();

            RenderSettings.sun = SharedLight;
        }

        void CreateSun() 
        {
           /* Sun = GameObject.Find("UniStorm Sun").GetComponent<Light>();
            Sun.transform.localEulerAngles = new Vector3(0, SunAngle, 0);
            m_CelestialAxisTransform = GameObject.Find("Celestial Axis").transform;
            RenderSettings.sun = Sun;*/

            SunObject = GameObject.Instantiate((GameObject)Resources.Load("UniStorm Sun Object"), transform.position, Quaternion.identity);
            SunObject.name = "Sun";
            m_SunTransform = SunObject.GetComponent<Renderer>().transform;
            m_SunTransform.parent = SharedLight.transform;

            m_SunTransform.localPosition = new Vector3(0, 0, -2000);
            m_SunTransform.localEulerAngles = new Vector3(270, 0, 0);
        }

        void CreateMoon()
        {
           // Moon = GameObject.Find("UniStorm Moon").transform; //.GetComponent<Light>();
           // Moon.localEulerAngles = new Vector3(-180, MoonAngle, 0);
            GameObject m_CreatedMoon = Instantiate((GameObject)Resources.Load("UniStorm Moon Object") as GameObject, transform.position, Quaternion.identity);
            m_CreatedMoon.name = "UniStorm Moon Object";
            m_MoonRenderer = GameObject.Find("UniStorm Moon Object").GetComponent<Renderer>();
            m_MoonTransform = m_MoonRenderer.transform;
            m_MoonPhaseMaterial = m_MoonRenderer.sharedMaterial;
            m_MoonPhaseMaterial.SetColor("_MoonColor", MoonPhaseColor);
            m_MoonTransform.parent = Moon;

        }

        void UpdateMoonTransform() 
        {
            if (PlayerCamera.farClipPlane < 2000)
            {
                m_MoonTransform.localPosition = new Vector3(0, 0, PlayerCamera.farClipPlane * -1);
                m_MoonTransform.localEulerAngles = new Vector3(270, 0, 0);
                m_MoonTransform.localScale = new Vector3(m_MoonTransform.localScale.x, m_MoonTransform.localScale.y, m_MoonTransform.localScale.z);
            }
            else
            {
                m_MoonTransform.localPosition = new Vector3(0, 0, -2000);
                m_MoonTransform.localEulerAngles = new Vector3(270, 0, 0);
                m_MoonTransform.localScale = new Vector3(m_MoonTransform.localScale.x, m_MoonTransform.localScale.y, m_MoonTransform.localScale.z);
            }
        }

        void CreateMoonShafts()
        {
            if (m_MoonShafts)
                return;

            m_MoonShafts = PlayerCamera.gameObject.AddComponent<UniStormSunShafts>();
            m_MoonShafts.sunShaftsShader = Shader.Find("Hidden/UniStormSunShafts");
            m_MoonShafts.simpleClearShader = Shader.Find("Hidden/UniStormSimpleClear");
            m_MoonShafts.useDepthTexture = true;
            m_MoonShafts.maxRadius = 0.3f;
            m_MoonShafts.sunShaftBlurRadius = 3.32f;
            m_MoonShafts.radialBlurIterations = 3;
            m_MoonShafts.sunShaftIntensity = 1;
            GameObject MoonTransform = new GameObject("Moon Transform");
            MoonTransform.transform.SetParent(Moon);
            MoonTransform.transform.localPosition = new Vector3(0, 0, -20000);
            m_MoonShafts.sunTransform = MoonTransform.transform;
            ColorUtility.TryParseHtmlString("#515252FF", out Color SunColor);
            m_MoonShafts.sunColor = SunColor;
            ColorUtility.TryParseHtmlString("#222222FF", out Color ThresholdColor);
            m_MoonShafts.sunThreshold = ThresholdColor;
        }

        void SetMoonPhase(int index)
        {
            if (MoonPhaseList.Count > 0)
            {
                var phase = MoonPhaseList[index];
                m_MoonPhaseMaterial.SetTexture("_MainTex", phase.MoonPhaseTexture);
                m_MoonRenderer.material = m_MoonPhaseMaterial;
                m_MoonPhaseMaterial.SetColor("_MoonColor", MoonPhaseColor);
            }
        }



        public void Update()
        {
            /*
            if (SunShaftsEffect == EnableFeature.Enabled && Light.Sun.intensity > 0)
            {
                m_SunShafts.sunShaftIntensity = SunLightShaftIntensity.Evaluate(TimeOfDayFraction * 24);
                m_SunShafts.radialBlurIterations = SunLightShaftsBlurIterations;
                m_SunShafts.sunShaftBlurRadius = SunLightShaftsBlurSize;
                m_SunShafts.sunColor = SunLightShaftsColor.Evaluate(TimeOfDayFraction);
            }
            else if (MoonShaftsEffect == EnableFeature.Enabled) // && Light.Moon.intensity > 0)
            {
                m_MoonShafts.sunShaftIntensity = MoonLightShaftIntensity.Evaluate(TimeOfDayFraction * 24);
                m_MoonShafts.radialBlurIterations = MoonLightShaftsBlurIterations;
                m_MoonShafts.sunShaftBlurRadius = MoonLightShaftsBlurSize;
                m_MoonShafts.sunColor = MoonLightShaftsColor.Evaluate(TimeOfDayFraction);
            }*/
        }


        #region Inspector

        private readonly pegi.EnterExitContext _context = new();

        public override void Inspect()
        {
            pegi.Nl();
            using (_context.StartContext())
            {
                if (_context.IsAnyEntered == false)
                {
                    base.Inspect();
                    "Light is {0}".F(LightIsSun ? "Sun" : "Moon").PegiLabel().Nl();
                    if ("Time Fraction".PegiLabel().Edit_01(ref _timeOfDayFraction).Nl())
                        TimeOfDayFraction = _timeOfDayFraction;
                }

                if ("Debug".PegiLabel().IsEntered().Nl())
                {
                    pegi.ClickConfirm(CreateSun).Nl();
                    pegi.ClickConfirm(CreateMoon).Nl();
                    pegi.ClickConfirm(UpdateMoonTransform).Nl();

                    if (!m_SunShafts && "Add Sun Shafts".PegiLabel().Click().Nl())
                        m_SunShafts = Camera.main.gameObject.AddComponent<UniStormSunShafts>();
                }
            }
        }

        public void OnSceneDraw()
        {
            var axs = m_CelestialAxisTransform.transform;
            pegi.Handle.Line(axs.position, axs.position + axs.forward * 10, Color.blue);

            var sun = SharedLight.transform;
            pegi.Handle.Line(sun.position, sun.position + 10 * SharedLight.intensity * sun.forward, Color.red);
        }

        #endregion

        #region Encode & Decode
        public CfgEncoder Encode() => new CfgEncoder()
            .Add("t", TimeOfDayFraction)
            .Add("i", Intensity)
            ;

        public void DecodeTag(string key, CfgData data)
        {
           switch (key) 
           {
                case "t": TimeOfDayFraction = data.ToFloat(); break;
                case "i": Intensity = data.ToFloat(); break;
           }
        }

        #endregion
    }

    [PEGI_Inspector_Override(typeof(Singleton_SunAndMoonRotator))] internal class Singleton_SunAndMoonRotatorDrawer : PEGI_Inspector_Override { }
}