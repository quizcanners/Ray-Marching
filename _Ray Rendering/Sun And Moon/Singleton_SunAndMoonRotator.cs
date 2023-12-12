using QuizCanners.Inspect;
using QuizCanners.Lerp;
using QuizCanners.Migration;
using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.RayTracing
{

    [ExecuteAlways]
    [AddComponentMenu(QcUtils.QUIZCANNERS + "/Quiz ñ'Anners/Sun And Moon")]
    public class Singleton_SunAndMoonRotator : Singleton.BehaniourBase, IPEGI_Handles, ICfg, ILinkedLerping
    {

        [Header("Sun")]
        public Light SharedLight;

        public int SunAngle = 10;


        private readonly LinkedLerp.QuaternionValue _sunRotation = new("ROtation", Quaternion.identity, 50f);

        private bool IsAnimating = true;

        private float _intensityFallback = 1f;

        public float SunIntensity 
        {
            get => Singleton.GetValue<Singleton_RayRendering, float>(s => s.lightsManager.SunIntensity, _intensityFallback); //_intensityAnimation.targetValue;

            set 
            {
                _intensityFallback = value;
               // Singleton.Try<Singleton_RayRendering>(s => s.lightsManager.SunIntensity = _intensityFallback);
                UpdateIntensity();
            }
        }

    //    private float SunAttenuation => Singleton.GetValue<Singleton_RayRendering, float>(s => s.lightsManager.SunAttenuation, defaultValue: 1, logOnServiceMissing: false);

        private void UpdateIntensity() 
        {
            SharedLight.intensity = SunIntensity * QcMath.SmoothStep(0f, 0.3f, Mathf.Abs(SharedLight.transform.forward.y));
        }

        public Quaternion GetSunRotation() => _sunRotation.CurrentValue;

        public void SetSunRotation(Quaternion rotation) 
        {
            _sunRotation.TargetAndCurrentValue = rotation;
            OnTimeOfDayChanged();
        }

        private bool LightIsSun => SharedLight.transform.forward.y < 0;

        void OnTimeOfDayChanged()
        {
            SharedLight.transform.rotation = _sunRotation.CurrentValue; 
            UpdateIntensity();
        }

        public void SetLightSourcePositionAndColor(Vector3 position, Color color) 
        {
            Singleton.Try<Singleton_CameraOperatorGodMode>(c => 
            {
                var diff = position - c.Position;
                SetSunRotation(Quaternion.LookRotation(-diff, Vector3.up));
                SharedLight.color = color;
            });
        }


        protected override void OnAfterEnable()
        {
            base.OnAfterEnable();

            RenderSettings.sun = SharedLight;
            IsAnimating = true;
        }

        #region Linked Lerp

        private readonly LerpData _lerpData = new(unscaledTime: false);

        public void Portion(LerpData ld)
        {
            _sunRotation.Portion(ld);
            ///_timeOfDayAnimation.Portion(ld);
        }

        public void Lerp(LerpData ld, bool canSkipLerp)
        {
            _sunRotation.Lerp(ld, canSkipLerp);
           // _timeOfDayAnimation.Lerp(ld, canSkipLerp);

            OnTimeOfDayChanged();
        }

        #endregion

        public void Update()
        {
            if (!IsAnimating)
                return;

            _lerpData.Update(this, canSkipLerp: false);
            OnTimeOfDayChanged();

            if (_lerpData.IsDone)
                IsAnimating = false;
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
                   
                    /*var t = TimeOfDayFraction_Target;
                    if ("Time Fraction".PegiLabel().Edit_01(ref t).Nl())
                        TimeOfDayFraction_Target = t;*/

                }
            }
        }

        public void OnSceneDraw()
        {
            var sun = SharedLight.transform;
            pegi.Handle.Line(sun.position, sun.position + 10 * SharedLight.intensity * sun.forward, Color.red);
        }

        #endregion

        #region Encode & Decode
        public CfgEncoder Encode() => new CfgEncoder()
           .Add("rot", SharedLight.transform.rotation)
           //.Add("t", TimeOfDayFraction_Target)
            ;

        public void DecodeTag(string key, CfgData data)
        {
           switch (key) 
           {
               // case "t": TimeOfDayFraction_Target = data.ToFloat(); break;
                case "rot": _sunRotation.TargetValue = data.ToQuaternion();

                    IsAnimating = true;
                    break;   
           }
        }



        #endregion
    }

    [PEGI_Inspector_Override(typeof(Singleton_SunAndMoonRotator))] internal class Singleton_SunAndMoonRotatorDrawer : PEGI_Inspector_Override { }
}