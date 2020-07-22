using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using System.Collections;
using System.Collections.Generic;
using UniStorm.Utility;
using UnityEngine;
using static UniStorm.UniStormSystem;
using Random = UnityEngine.Random;

namespace UniStorm
{
    public partial class UniStorm
    {
        static UniStormSystem MGMT => Singleton.Get<UniStormSystem>();
        static SO_WeatherType CurrentWeatherType => MGMT.CurrentWeatherType;
        static UniStormClouds UniStormClouds => Singleton.Get<UniStormClouds>();

        [Serializable]
        public class Sounds : IPEGI
        {

            //Audio Mixer Volumes
            [SerializeField] private float _weatherSoundsVolume = 1;
            [SerializeField] private float _ambienceVolume = 1;
            [SerializeField] private float _musicVolume = 1;

            public List<AudioClip> MorningSounds = new();
            public List<AudioClip> DaySounds = new();
            public List<AudioClip> EveningSounds = new();
            public List<AudioClip> NightSounds = new();
            public AudioSource TimeOfDayAudioSource;
            public List<AudioClip> MorningMusic = new();
            public List<AudioClip> DayMusic = new();
            public List<AudioClip> EveningMusic = new();
            public List<AudioClip> NightMusic = new();
            public List<AudioSource> WeatherSoundsList = new List<AudioSource>();
            public AudioSource TimeOfDayMusicAudioSource;
            public UnityEngine.Audio.AudioMixer UniStormAudioMixer;

            public int TimeOfDayMusicDelay = 1;
            float m_CurrentMusicClipLength = 0;
            float m_TimeOfDayMusicTimer = 0;
            public EnableFeature TimeOfDaySoundsDuringPrecipitationWeather = EnableFeature.Disabled;
            public EnableFeature TransitionMusicOnTimeOfDayChange = EnableFeature.Disabled;
            float m_CurrentClipLength = 0;
            public bool m_UpdateTimeOfDayMusic = false;
            public bool m_UpdateBiomeTimeOfDayMusic = false;
            public int MusicTransitionLength = 3;
            public float m_TimeOfDaySoundsTimer = 0;
            int m_TimeOfDaySoundsSeconds = 10;
            public int TimeOfDaySoundsSecondsMin = 10;
            public int TimeOfDaySoundsSecondsMax = 30;


            public Coroutine MusicVolumeCoroutine, SoundInCoroutine, SoundOutCoroutine;


            public GameObject m_SoundTransform;


            public enum CurrentTimeOfDayEnum 
            {
                Morning, Day, Evening, Night
            }
            public void PlayTimeOfDaySound(CurrentTimeOfDayEnum timeOfDay)
            {
                m_TimeOfDaySoundsTimer += Time.deltaTime;

                if (m_TimeOfDaySoundsTimer >= m_TimeOfDaySoundsSeconds + m_CurrentClipLength)
                {
                    var CurrentWeatherType = MGMT.CurrentWeatherType;

                    if (CurrentWeatherType != null && CurrentWeatherType.PrecipitationWeatherType == SO_WeatherType.Yes_No.Yes &&
                        TimeOfDaySoundsDuringPrecipitationWeather == UniStormSystem.EnableFeature.Enabled ||
                        CurrentWeatherType != null && CurrentWeatherType.PrecipitationWeatherType == SO_WeatherType.Yes_No.No &&
                        TimeOfDaySoundsDuringPrecipitationWeather == UniStormSystem.EnableFeature.Disabled)
                    {
                        
                        if (timeOfDay == CurrentTimeOfDayEnum.Morning)
                        {
                            //Morning Sounds
                            if (MorningSounds.Count != 0)
                            {
                                TimeOfDayAudioSource.clip = MorningSounds[Random.Range(0, MorningSounds.Count)];
                                if (TimeOfDayAudioSource.clip != null)
                                {
                                    TimeOfDayAudioSource.Play();
                                    m_CurrentClipLength = TimeOfDayAudioSource.clip.length;
                                }
                            }
                        }
                        else if (timeOfDay == CurrentTimeOfDayEnum.Day)
                        {
                            //Day Sounds
                            if (DaySounds.Count != 0)
                            {
                                TimeOfDayAudioSource.clip = DaySounds[Random.Range(0, DaySounds.Count)];
                                if (TimeOfDayAudioSource.clip != null)
                                {
                                    TimeOfDayAudioSource.Play();
                                    m_CurrentClipLength = TimeOfDayAudioSource.clip.length;
                                }
                            }
                        }
                        else if (timeOfDay == CurrentTimeOfDayEnum.Evening)
                        {
                            //Evening Sounds
                            if (EveningSounds.Count != 0)
                            {
                                TimeOfDayAudioSource.clip = EveningSounds[Random.Range(0, EveningSounds.Count)];
                                if (TimeOfDayAudioSource.clip != null)
                                {
                                    TimeOfDayAudioSource.Play();
                                    m_CurrentClipLength = TimeOfDayAudioSource.clip.length;
                                }
                            }
                        }
                        else if (timeOfDay == CurrentTimeOfDayEnum.Night)
                        {
                            //Night Sounds
                            if (NightSounds.Count != 0)
                            {
                                TimeOfDayAudioSource.clip = NightSounds[Random.Range(0, NightSounds.Count)];
                                if (TimeOfDayAudioSource.clip != null)
                                {
                                    TimeOfDayAudioSource.Play();
                                    m_CurrentClipLength = TimeOfDayAudioSource.clip.length;
                                }
                            }
                        }

                        m_TimeOfDaySoundsTimer = 0;
                    }
                }
            }


            public void PlayTimeOfDayMusic(CurrentTimeOfDayEnum time)
            {
                m_TimeOfDayMusicTimer += Time.deltaTime;

                if (m_TimeOfDayMusicTimer >= m_CurrentMusicClipLength + TimeOfDayMusicDelay || m_UpdateTimeOfDayMusic && TransitionMusicOnTimeOfDayChange == EnableFeature.Enabled || m_UpdateBiomeTimeOfDayMusic)
                {
                    if (time == CurrentTimeOfDayEnum.Morning)
                    {
                        //Morning Music
                        if (MorningMusic.Count != 0)
                        {
                            if (MusicVolumeCoroutine != null) { MGMT.StopCoroutine(MusicVolumeCoroutine); }
                            AudioClip RandomMorningSound = MorningMusic[Random.Range(0, MorningMusic.Count)];
                            if (RandomMorningSound != null)
                            {
                                MusicVolumeCoroutine = MGMT.StartCoroutine(MusicFadeSequence(MusicTransitionLength, RandomMorningSound));
                                m_CurrentMusicClipLength = RandomMorningSound.length;
                            }
                        }
                    }
                    else if (time == CurrentTimeOfDayEnum.Day)
                    {
                        //Day Music
                        if (DayMusic.Count != 0)
                        {
                            if (MusicVolumeCoroutine != null) { MGMT.StopCoroutine(MusicVolumeCoroutine); }
                            AudioClip RandomDaySound = DayMusic[Random.Range(0, DayMusic.Count)];
                            if (RandomDaySound != null)
                            {
                                MusicVolumeCoroutine = MGMT.StartCoroutine(MusicFadeSequence(MusicTransitionLength, RandomDaySound));
                                m_CurrentMusicClipLength = RandomDaySound.length;
                            }
                        }
                    }
                    else if (time == CurrentTimeOfDayEnum.Evening)
                    {
                        //Evening Music
                        if (EveningMusic.Count != 0)
                        {
                            if (MusicVolumeCoroutine != null) { MGMT.StopCoroutine(MusicVolumeCoroutine); }
                            AudioClip RandomEveningSound = EveningMusic[Random.Range(0, EveningMusic.Count)];
                            if (RandomEveningSound != null)
                            {
                                MusicVolumeCoroutine = MGMT.StartCoroutine(MusicFadeSequence(MusicTransitionLength, RandomEveningSound));
                                m_CurrentMusicClipLength = RandomEveningSound.length;
                            }
                        }
                    }
                    else if (time == CurrentTimeOfDayEnum.Night)
                    {
                        //Night Music
                        if (NightMusic.Count != 0)
                        {
                            if (MusicVolumeCoroutine != null) { MGMT.StopCoroutine(MusicVolumeCoroutine); }
                            AudioClip RandomNightSound = NightMusic[Random.Range(0, NightMusic.Count)];
                            if (RandomNightSound != null)
                            {
                                MusicVolumeCoroutine = MGMT.StartCoroutine(MusicFadeSequence(MusicTransitionLength, RandomNightSound));
                                m_CurrentMusicClipLength = RandomNightSound.length;
                            }
                        }
                    }

                    m_TimeOfDayMusicTimer = 0;
                    m_UpdateTimeOfDayMusic = false;
                    m_UpdateBiomeTimeOfDayMusic = false;
                }
            }

    
            public void TransitionWeather()
            {
                if (CurrentWeatherType.UseWeatherSound == SO_WeatherType.Yes_No.Yes)
                {
                    foreach (AudioSource A in WeatherSoundsList)
                    {
                        if (A.gameObject.name == CurrentWeatherType.WeatherTypeName + " (UniStorm)")
                        {
                            A.Play();
                            SoundInCoroutine = MGMT.StartCoroutine(SoundFadeSequence(10 * MGMT.TransitionSpeed, CurrentWeatherType.WeatherVolume, A, false));
                        }
                    }
                }



                foreach (AudioSource A in WeatherSoundsList)
                {
                    if (A.gameObject.name != CurrentWeatherType.WeatherTypeName + " (UniStorm)" && A.volume > 0 || CurrentWeatherType.UseWeatherSound == SO_WeatherType.Yes_No.No && A.volume > 0)
                    {
                        SoundOutCoroutine = MGMT.StartCoroutine(SoundFadeSequence(5 * MGMT.TransitionSpeed, 0, A, true));
                    }
                }
            }

            public void SkipTransition() 
            {
                foreach (AudioSource A in WeatherSoundsList)
                {
                    A.volume = 0;
                }

                if (CurrentWeatherType.UseWeatherSound == SO_WeatherType.Yes_No.Yes)
                {
                    foreach (AudioSource A in WeatherSoundsList)
                    {
                        if (A.gameObject.name == CurrentWeatherType.WeatherTypeName + " (UniStorm)")
                        {
                            A.Play();
                            A.volume = CurrentWeatherType.WeatherVolume;
                        }
                    }
                }
            }

            public void Setup()
            {
                if (_musicVolume <= 0)
                    _musicVolume = 0.001f;

                if (_ambienceVolume <= 0)
                    _ambienceVolume = 0.001f;

                if (_weatherSoundsVolume <= 0)
                    _weatherSoundsVolume = 0.001f;

                if (!UniStormAudioMixer)
                {
                    UniStormAudioMixer = Resources.Load("UniStorm Audio Mixer") as UnityEngine.Audio.AudioMixer;
                    UpdateVolume();
                }

                //Setup our sound holder
                if (!m_SoundTransform)
                {
                    m_SoundTransform = new GameObject
                    {
                        name = "UniStorm Sounds"
                    };

                    m_SoundTransform.transform.SetParent(MGMT.PlayerTransform);
                    m_SoundTransform.transform.localPosition = Vector3.zero;

                 

                    for (int i = 0; i < MGMT.AllWeatherTypes.Count; i++)
                    {
                        var weather = MGMT.AllWeatherTypes[i];

                        if (weather)
                        {
                            //If our weather types have certain features enabled, but there are none detected, disable the feature.
                            if (weather.UseWeatherSound == SO_WeatherType.Yes_No.Yes && weather.WeatherSound == null)
                            {
                                weather.UseWeatherSound = SO_WeatherType.Yes_No.No;
                            }

                            if (weather.UseWeatherEffect == SO_WeatherType.Yes_No.Yes && weather.WeatherEffect == null)
                            {
                                weather.UseWeatherEffect = SO_WeatherType.Yes_No.No;
                            }

                            if (weather.UseAdditionalWeatherEffect == SO_WeatherType.Yes_No.Yes && weather.AdditionalWeatherEffect == null)
                            {
                                weather.UseAdditionalWeatherEffect = SO_WeatherType.Yes_No.No;
                            }

                            //Create a weather sound for each weather type that has one.
                            if (weather.UseWeatherSound == SO_WeatherType.Yes_No.Yes && weather.WeatherSound)
                            {
                                weather.CreateWeatherSound(m_SoundTransform.transform);
                            }
                        }
                    }
                }


                //Intialize the other components and set the proper settings from within the editor
                if (!TimeOfDayAudioSource)
                {
                    GameObject TempAudioSource = new GameObject("UniStorm Time of Day Sounds");
                    TempAudioSource.transform.SetParent(MGMT.transform);
                    TempAudioSource.transform.localPosition = Vector3.zero;
                    TimeOfDayAudioSource = TempAudioSource.AddComponent<AudioSource>();
                    TimeOfDayAudioSource.outputAudioMixerGroup = UniStormAudioMixer.FindMatchingGroups("Master/Ambience")[0];
                }
                m_TimeOfDaySoundsSeconds = Random.Range(TimeOfDaySoundsSecondsMin, TimeOfDaySoundsSecondsMax + 1);

                if (!TimeOfDayMusicAudioSource)
                {
                    GameObject TempAudioSourceMusic = new GameObject("UniStorm Time of Day Music");
                    TempAudioSourceMusic.transform.SetParent(MGMT.transform);
                    TempAudioSourceMusic.transform.localPosition = Vector3.zero;
                    TimeOfDayMusicAudioSource = TempAudioSourceMusic.AddComponent<AudioSource>();
                    TimeOfDayMusicAudioSource.outputAudioMixerGroup = UniStormAudioMixer.FindMatchingGroups("Master/Music")[0];
                }


            }

            public void StopCoroutines() 
            {
                if (SoundInCoroutine != null) { MGMT.StopCoroutine(SoundInCoroutine); }
                if (SoundOutCoroutine != null) { MGMT.StopCoroutine(SoundOutCoroutine); }
            }

            void UpdateVolume()
            {
                UniStormAudioMixer.SetFloat("MusicVolume", Mathf.Log(_musicVolume) * 20);
                UniStormAudioMixer.SetFloat("AmbienceVolume", Mathf.Log(_ambienceVolume) * 20);
                UniStormAudioMixer.SetFloat("WeatherVolume", Mathf.Log(_weatherSoundsVolume) * 20);
            }

            IEnumerator MusicFadeSequence(float TransitionTime, AudioClip NewMusicClip)
            {
                if (MGMT.UniStormInitialized)
                {
                    float CurrentValue = TimeOfDayMusicAudioSource.volume;
                    float LerpValue = CurrentValue;
                    float t = 0;

                    //Fade out for transition, only if the AudioSource has a clip
                    if (TimeOfDayMusicAudioSource.clip != null)
                    {
                        while ((t / TransitionTime) < 1)
                        {
                            t += Time.deltaTime;
                            LerpValue = Mathf.Lerp(CurrentValue, 0, t / TransitionTime);
                            TimeOfDayMusicAudioSource.volume = LerpValue;

                            yield return null;
                        }
                    }
                    else
                    {
                        TimeOfDayMusicAudioSource.volume = 0;
                    }

                    //Assign new music clip
                    TimeOfDayMusicAudioSource.clip = NewMusicClip;
                    TimeOfDayMusicAudioSource.Play();

                    //Reset values to fade in from 0
                    CurrentValue = TimeOfDayMusicAudioSource.volume;
                    LerpValue = CurrentValue;
                    t = 0;

                    //Fade back in with new clip
                    while ((t / TransitionTime) < 1)
                    {
                        t += Time.deltaTime;
                        LerpValue = Mathf.Lerp(CurrentValue, _musicVolume, t / TransitionTime);
                        TimeOfDayMusicAudioSource.volume = LerpValue;

                        yield return null;
                    }

                    m_TimeOfDayMusicTimer = 0;
                }
            }

            IEnumerator SoundFadeSequence(float TransitionTime, float target, AudioSource SourceToFade, bool FadeOut)
            {
                var skyMat = UniStormClouds.skyMaterial;

                if (CurrentWeatherType.PrecipitationWeatherType == SO_WeatherType.Yes_No.Yes)
                {
                    if (QualitySettings.activeColorSpace == ColorSpace.Gamma)
                        yield return new WaitUntil(() => skyMat.GetFloat("_uCloudsCoverage") >= 0.59f);
                    else
                        yield return new WaitUntil(() => skyMat.GetFloat("_uCloudsCoverage") >= MGMT.m_ReceivedCloudValue);
                }
                else if (CurrentWeatherType.WaitForCloudLevel == SO_WeatherType.Yes_No.Yes)
                {
                    yield return new WaitUntil(() => skyMat.GetFloat("_uCloudsCoverage") >= (MGMT.m_ReceivedCloudValue - 0.01f));
                }

                float CurrentValue = SourceToFade.volume;
                float LerpValue = CurrentValue;
                float t = 0;

                while ((LerpValue > target && FadeOut) || (LerpValue < target && !FadeOut))
                {
                    t += Time.deltaTime;
                    LerpValue = Mathf.Lerp(CurrentValue, target, t / TransitionTime);
                    SourceToFade.volume = LerpValue;

                    yield return null;
                }
            }

            public void Inspect()
            {

            }
        }
    }
}