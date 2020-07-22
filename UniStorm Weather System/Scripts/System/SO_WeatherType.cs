using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;

namespace UniStorm
{
    [CreateAssetMenu(fileName = "New Weather Type", menuName = QcUnity.SO_CREATE_MENU + "UniStorm/New Weather Type")]
    public class SO_WeatherType : ScriptableObject, IPEGI
    {
        UniStormSystem Mgmt => Singleton.Get<UniStormSystem>();

        public string WeatherTypeName = "New Weather Type";
        public CloudProfile CloudProfileComponent;

        public float SunIntensity = 1;
        public float CloudShadowIntensity = 1;
        public float MoonIntensity = 1;

        //Auroras
        public Yes_No UseAuroras = Yes_No.No;
        public float AuroraIntensity = 0.4f;
        public Color AuroraOuterColor = Color.cyan;
        public Color AuroraInnerColor = Color.green;

        //Wind
        public float WindSpeedLevel = 0.85f;
        public float WindBendingLevel = 0.2f;

        public ParticleSystem WeatherEffect;
        public int ParticleEffectAmount = 200;
        public Vector3 ParticleEffectVector = new Vector3(0, 28, 0);
        public ParticleSystem AdditionalWeatherEffect;
        public int AdditionalParticleEffectAmount = 200;
        public Vector3 AdditionalParticleEffectVector = new Vector3(0, 28, 0);

        //Audio
        public float WeatherVolume = 1;
        public AudioClip WeatherSound;

        //Particle Effect
        public Yes_No PrecipitationWeatherType = Yes_No.No;
        public Yes_No UseWeatherSound = Yes_No.No;
        public Yes_No UseWeatherEffect = Yes_No.No;
        public Yes_No UseAdditionalWeatherEffect = Yes_No.No;
        public Yes_No SpecialWeatherType = Yes_No.No;

        public SeasonEnum Season;
        public enum SeasonEnum
        {
            All = 0,
            Spring = 1,
            Summer = 2,
            Fall = 3,
            Winter = 4
        }

        public int CloudHeight = 1000;
        public CloudLevelEnum CloudLevel;
        public enum CloudLevelEnum
        {
            Clear = 0,
            MostlyClear = 1,
            PartyCloudy = 2,
            MostlyCloudy = 3,
            Cloudy = 4,
            DontChange = 5
        }

        public TemperatureTypeEnum TemperatureType = TemperatureTypeEnum.AboveFreezing;
        public enum TemperatureTypeEnum
        {
            BelowFreezing = 0,
            AboveFreezing = 1,
            Both = 2
        }

        public Yes_No OverrideCloudColor = Yes_No.No;
        public Gradient CloudColor;
        public Yes_No UseLightning = Yes_No.No;
        public Yes_No CustomizeWeatherIcon = Yes_No.No;
        public Yes_No WaitForCloudLevel = Yes_No.No;
        public Texture WeatherIcon;
        public enum Yes_No
        {
            Yes = 0,
            No = 1
        }

        

        public void CreateWeatherSound(Transform parent)
        {
            if (Mgmt.enabled)
            {
                GameObject Temp = new GameObject();
                Temp.AddComponent<AudioSource>();
                AudioSource _AS = Temp.GetComponent<AudioSource>();
                _AS.clip = WeatherSound;
                _AS.volume = 0;
                _AS.loop = true;
                UnityEngine.Audio.AudioMixer m_AudioMixer = Resources.Load("UniStorm Audio Mixer") as UnityEngine.Audio.AudioMixer;
                _AS.outputAudioMixerGroup = m_AudioMixer.FindMatchingGroups("Master/Weather")[0];
                Temp.name = WeatherTypeName + " (UniStorm)";
                Temp.transform.SetParent(parent);
                Temp.transform.position = new Vector3(Temp.transform.parent.position.x, Temp.transform.parent.position.y, Temp.transform.parent.position.z);
                Mgmt.SoundManager.WeatherSoundsList.Add(_AS);
            }
        }

        public void CreateWeatherEffect()
        {
            ParticleSystem Temp = Instantiate(WeatherEffect, Vector3.zero, Quaternion.AngleAxis(-90, Vector3.right));
            Temp.transform.SetParent(GameObject.Find("UniStorm Effects").transform);
            Temp.name = Temp.name.Replace("(Clone)", " (UniStorm)");
            ParticleSystem.EmissionModule CurrentEmission = Temp.emission;
            CurrentEmission.enabled = true;
            CurrentEmission.rateOverTime = new ParticleSystem.MinMaxCurve(0);
            CurrentEmission.SetBursts(new ParticleSystem.Burst[] { });
            Mgmt.Particles.WeatherEffectsList.Add(Temp);
        }

        public void CreateAdditionalWeatherEffect()
        {
            ParticleSystem Temp = Instantiate(AdditionalWeatherEffect, Vector3.zero, Quaternion.AngleAxis(-90, Vector3.right));
            Temp.transform.SetParent(GameObject.Find("UniStorm Effects").transform);
            Temp.name = Temp.name.Replace("(Clone)", " (UniStorm)");
            ParticleSystem.EmissionModule CurrentEmission = Temp.emission;
            CurrentEmission.enabled = true;
            CurrentEmission.rateOverTime = new ParticleSystem.MinMaxCurve(0);
            Mgmt.Particles.AdditionalWeatherEffectsList.Add(Temp);
        }

        private static readonly pegi.EnterExitContext _context = new();

        public void Inspect()
        {
            using (_context.StartContext())
            {
                CloudProfileComponent.Enter_Inspect().Nl();

                if ("Default Inspect".PegiLabel().IsEntered().Nl()) 
                    pegi.TryDefaultInspect(this);
            }
        }
    }
}