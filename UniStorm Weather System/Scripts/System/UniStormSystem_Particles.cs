using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using System.Collections;
using System.Collections.Generic;
using UniStorm.Utility;
using UnityEngine;

namespace UniStorm
{
    public partial class UniStorm
    {
        [Serializable]
        public class Particles : IPEGI
        {
            public GameObject m_EffectsTransform;
            public List<ParticleSystem> ParticleSystemList = new List<ParticleSystem>();
            public List<ParticleSystem> WeatherEffectsList = new List<ParticleSystem>();
            public List<ParticleSystem> AdditionalParticleSystemList = new List<ParticleSystem>();
            public List<ParticleSystem> AdditionalWeatherEffectsList = new List<ParticleSystem>();


            public ParticleSystem CurrentParticleSystem;
            public float m_ParticleAmount = 0;
            public ParticleSystem AdditionalCurrentParticleSystem;


            Coroutine AdditionalParticleFadeCoroutine, ParticleFadeCoroutine, WeatherEffectCoroutine, AdditionalWeatherEffectCoroutine;


            public void Setup() 
            {
               


                m_EffectsTransform = new GameObject
                {
                    name = "UniStorm Effects"
                };
                m_EffectsTransform.transform.SetParent(MGMT.PlayerTransform);
                m_EffectsTransform.transform.localPosition = Vector3.zero;

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

                        //Add all of our weather effects to a list to be controlled when needed.
                        if (!ParticleSystemList.Contains(weather.WeatherEffect) && weather.WeatherEffect != null)
                        {
                            weather.CreateWeatherEffect();
                            ParticleSystemList.Add(weather.WeatherEffect);
                        }

                        //Add all of our additional weather effects to a list to be controlled when needed.
                        if (!AdditionalParticleSystemList.Contains(weather.AdditionalWeatherEffect))
                        {
                            if (weather.UseAdditionalWeatherEffect == SO_WeatherType.Yes_No.Yes)
                            {
                                weather.CreateAdditionalWeatherEffect();
                                AdditionalParticleSystemList.Add(weather.AdditionalWeatherEffect);
                            }
                        }

                        //Create a weather sound for each weather type that has one.
                  
                    }
                }


            }


            public void StopCoroutines() 
            {
                if (WeatherEffectCoroutine != null)  MGMT.StopCoroutine(WeatherEffectCoroutine); 
                if (AdditionalWeatherEffectCoroutine != null)  MGMT.StopCoroutine(AdditionalWeatherEffectCoroutine); 
                if (ParticleFadeCoroutine != null)  MGMT.StopCoroutine(ParticleFadeCoroutine); 
                if (AdditionalParticleFadeCoroutine != null)  MGMT.StopCoroutine(AdditionalParticleFadeCoroutine); 
            }

            public void SkipTransition() 
            {
              

                for (int i = 0; i < WeatherEffectsList.Count; i++)
                {
                    ParticleSystem.EmissionModule CurrentEmission = WeatherEffectsList[i].emission;
                    CurrentEmission.rateOverTime = new ParticleSystem.MinMaxCurve(0);
                }

                for (int i = 0; i < AdditionalWeatherEffectsList.Count; i++)
                {
                    ParticleSystem.EmissionModule CurrentEmission = AdditionalWeatherEffectsList[i].emission;
                    CurrentEmission.rateOverTime = new ParticleSystem.MinMaxCurve(0);
                }

                //Initialize our weather type's particle effetcs
                if (CurrentWeatherType.UseWeatherEffect == SO_WeatherType.Yes_No.Yes)
                {
                    for (int i = 0; i < WeatherEffectsList.Count; i++)
                    {
                        if (WeatherEffectsList[i].name == CurrentWeatherType.WeatherEffect.name + " (UniStorm)")
                        {
                            CurrentParticleSystem = WeatherEffectsList[i];
                            ParticleSystem.EmissionModule CurrentEmission = CurrentParticleSystem.emission;
                            CurrentEmission.rateOverTime = new ParticleSystem.MinMaxCurve((float)CurrentWeatherType.ParticleEffectAmount);
                        }
                    }

                    CurrentParticleSystem.transform.localPosition = CurrentWeatherType.ParticleEffectVector;
                }

                //Initialize our weather type's additional particle effetcs
                if (CurrentWeatherType.UseAdditionalWeatherEffect == SO_WeatherType.Yes_No.Yes)
                {
                    for (int i = 0; i < AdditionalWeatherEffectsList.Count; i++)
                    {
                        if (AdditionalWeatherEffectsList[i].name == CurrentWeatherType.AdditionalWeatherEffect.name + " (UniStorm)")
                        {
                            AdditionalCurrentParticleSystem = AdditionalWeatherEffectsList[i];
                            ParticleSystem.EmissionModule CurrentEmission = AdditionalCurrentParticleSystem.emission;
                            CurrentEmission.rateOverTime = new ParticleSystem.MinMaxCurve((float)CurrentWeatherType.AdditionalParticleEffectAmount);
                        }
                    }

                    AdditionalCurrentParticleSystem.transform.localPosition = CurrentWeatherType.AdditionalParticleEffectVector;
                }
            }

            public void TransitionWeather() 
            {
                if (CurrentWeatherType.UseWeatherEffect == SO_WeatherType.Yes_No.Yes)
                {
                    ParticleSystem m_PreviousWeatherEffect = CurrentParticleSystem;

                    for (int i = 0; i < WeatherEffectsList.Count; i++)
                    {
                        if (WeatherEffectsList[i].name == CurrentWeatherType.WeatherEffect.name + " (UniStorm)")
                        {
                            CurrentParticleSystem = WeatherEffectsList[i];
                            CurrentParticleSystem.transform.localPosition = CurrentWeatherType.ParticleEffectVector;
                        }
                    }

                    if (CurrentParticleSystem.emission.rateOverTime.constant < CurrentWeatherType.ParticleEffectAmount)
                    {
                        WeatherEffectCoroutine = MGMT.StartCoroutine(ParticleFadeSequence(10 * MGMT.TransitionSpeed, CurrentWeatherType.ParticleEffectAmount, null, false));
                    }
                    else
                    {
                        if (m_PreviousWeatherEffect != CurrentParticleSystem)
                        {
                            ParticleFadeCoroutine = MGMT.StartCoroutine(ParticleFadeSequence(5 * MGMT.TransitionSpeed, 0, CurrentParticleSystem, true));
                        }
                        else
                        {
                            ParticleFadeCoroutine = MGMT.StartCoroutine(ParticleFadeSequence(5 * MGMT.TransitionSpeed, CurrentWeatherType.ParticleEffectAmount, CurrentParticleSystem, true));
                        }
                    }
                }

                if (CurrentWeatherType.UseAdditionalWeatherEffect == SO_WeatherType.Yes_No.Yes)
                {
                    for (int i = 0; i < AdditionalWeatherEffectsList.Count; i++)
                    {
                        if (AdditionalWeatherEffectsList[i].name == CurrentWeatherType.AdditionalWeatherEffect.name + " (UniStorm)")
                        {
                            AdditionalCurrentParticleSystem = AdditionalWeatherEffectsList[i];
                            AdditionalCurrentParticleSystem.transform.localPosition = CurrentWeatherType.AdditionalParticleEffectVector;
                        }
                    }

                    if (AdditionalCurrentParticleSystem.emission.rateOverTime.constant < CurrentWeatherType.AdditionalParticleEffectAmount)
                    {
                        AdditionalWeatherEffectCoroutine = MGMT.StartCoroutine(AdditionalParticleFadeSequence(10 * MGMT.TransitionSpeed, CurrentWeatherType.AdditionalParticleEffectAmount, null, false));
                    }
                    else
                    {
                        AdditionalParticleFadeCoroutine = MGMT.StartCoroutine(AdditionalParticleFadeSequence(5 * MGMT.TransitionSpeed, 0, AdditionalCurrentParticleSystem, true));
                    }
                }

                if (CurrentWeatherType.UseWeatherEffect == SO_WeatherType.Yes_No.No)
                {
                    CurrentParticleSystem = null;

                    if (CurrentWeatherType.UseAdditionalWeatherEffect == SO_WeatherType.Yes_No.No)
                    {
                        AdditionalCurrentParticleSystem = null;
                    }
                }

                foreach (ParticleSystem P in WeatherEffectsList)
                {
                    if (P != CurrentParticleSystem && P.emission.rateOverTime.constant > 0 ||
                        CurrentWeatherType.UseWeatherEffect == SO_WeatherType.Yes_No.No && P.emission.rateOverTime.constant > 0)
                    {
                        ParticleFadeCoroutine = MGMT.StartCoroutine(ParticleFadeSequence(5 * MGMT.TransitionSpeed, 0, P, true));
                    }
                }

                foreach (ParticleSystem P in AdditionalWeatherEffectsList)
                {
                    if (P != AdditionalCurrentParticleSystem && P.emission.rateOverTime.constant > 0 ||
                        CurrentWeatherType.UseAdditionalWeatherEffect == SO_WeatherType.Yes_No.No && P.emission.rateOverTime.constant > 0)
                    {
                        AdditionalParticleFadeCoroutine = MGMT.StartCoroutine(AdditionalParticleFadeSequence(5 * MGMT.TransitionSpeed, 0, P, true));
                    }
                }
            }

            internal readonly ShaderProperty.FloatValue _uCloudsCoverage = new("_uCloudsCoverage");

            IEnumerator AdditionalParticleFadeSequence(float TransitionTime, float MaxValue, ParticleSystem AdditionalEffectToFade, bool FadeOut)
            {
                var skyMat = UniStormClouds.skyMaterial;

                if (CurrentWeatherType.PrecipitationWeatherType == SO_WeatherType.Yes_No.Yes)
                {
                    if (QualitySettings.activeColorSpace == ColorSpace.Gamma)
                        yield return new WaitUntil(() => skyMat.Get(_uCloudsCoverage) >= 0.59f);
                    else
                        yield return new WaitUntil(() => skyMat.Get(_uCloudsCoverage) >= MGMT.m_ReceivedCloudValue);
                }
                else if (CurrentWeatherType.WaitForCloudLevel == SO_WeatherType.Yes_No.Yes)
                {
                    yield return new WaitUntil(() => skyMat.Get(_uCloudsCoverage) >= (MGMT.m_ReceivedCloudValue - 0.01f));
                }

                if (AdditionalEffectToFade == null)
                {
                    float CurrentValue = AdditionalCurrentParticleSystem.emission.rateOverTime.constant;
                    float LerpValue = CurrentValue;
                    float t = 0;

                    while ((LerpValue > MaxValue && FadeOut) || (LerpValue < MaxValue && !FadeOut))
                    {
                        t += Time.deltaTime;
                        LerpValue = Mathf.Lerp(CurrentValue, MaxValue, t / TransitionTime);
                        ParticleSystem.EmissionModule CurrentEmission = AdditionalCurrentParticleSystem.emission;
                        CurrentEmission.rateOverTime = new ParticleSystem.MinMaxCurve(LerpValue);

                        yield return null;
                    }
                }
                else
                {
                    float CurrentValue = AdditionalEffectToFade.emission.rateOverTime.constant;
                    float LerpValue = CurrentValue;
                    float t = 0;

                    while ((LerpValue > MaxValue && FadeOut) || (LerpValue < MaxValue && !FadeOut))
                    {
                        t += Time.deltaTime;
                        LerpValue = Mathf.Lerp(CurrentValue, MaxValue, t / TransitionTime);
                        ParticleSystem.EmissionModule CurrentEmission = AdditionalEffectToFade.emission;
                        CurrentEmission.rateOverTime = new ParticleSystem.MinMaxCurve(LerpValue);

                        yield return null;
                    }
                }
            }

            IEnumerator ParticleFadeSequence(float TransitionTime, float MaxValue, ParticleSystem EffectToFade, bool FadeOut)
            {
                var skyMat = UniStormClouds.skyMaterial;

                if (CurrentWeatherType.PrecipitationWeatherType == SO_WeatherType.Yes_No.Yes)
                {
                    if (QualitySettings.activeColorSpace == ColorSpace.Gamma)
                        yield return new WaitUntil(() => skyMat.Get(_uCloudsCoverage) >= 0.59f);
                    else
                        yield return new WaitUntil(() => skyMat.Get(_uCloudsCoverage) >= MGMT.m_ReceivedCloudValue);
                }
                else if (CurrentWeatherType.WaitForCloudLevel == SO_WeatherType.Yes_No.Yes)
                {
                    yield return new WaitUntil(() => skyMat.Get(_uCloudsCoverage) >= (MGMT.m_ReceivedCloudValue - 0.01f));
                }

                if (EffectToFade == null)
                {
                    float CurrentValue = CurrentParticleSystem.emission.rateOverTime.constant;
                    float LerpValue = CurrentValue;
                    float t = 0;

                    while ((LerpValue > MaxValue && FadeOut) || (LerpValue < MaxValue && !FadeOut))
                    {
                        t += Time.deltaTime;
                        LerpValue = Mathf.Lerp(CurrentValue, MaxValue, t / TransitionTime);
                        ParticleSystem.EmissionModule CurrentEmission = CurrentParticleSystem.emission;
                        CurrentEmission.rateOverTime = new ParticleSystem.MinMaxCurve(LerpValue);

                        yield return null;
                    }
                }
                else
                {
                    float CurrentValue = EffectToFade.emission.rateOverTime.constant;
                    float LerpValue = CurrentValue;
                    float t = 0;

                    while ((LerpValue > MaxValue && FadeOut) || (LerpValue < MaxValue && !FadeOut))
                    {
                        t += Time.deltaTime;
                        LerpValue = Mathf.Lerp(CurrentValue, MaxValue, t / TransitionTime);
                        ParticleSystem.EmissionModule CurrentEmission = EffectToFade.emission;
                        CurrentEmission.rateOverTime = new ParticleSystem.MinMaxCurve(LerpValue);
                        m_ParticleAmount = LerpValue;

                        yield return null;
                    }
                }
            }

            public void Inspect()
            {

            }
        }
    }
}