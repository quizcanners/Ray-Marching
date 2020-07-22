using QuizCanners.Lerp;
using QuizCanners.Utils;
using System.Collections;
using UnityEngine;

namespace UniStorm
{
    public partial class UniStormSystem 
    {

        IEnumerator CloudFadeSequence(float TransitionTime, float MaxValue)
        {
            float CurrentValue = m_CloudDomeMaterial.Get(CloudProfile.COVERAGE);
            // float LerpValue = CurrentValue;
            // float t = 0;

            LerpUtils.DurationLerp.FloatUnscaled lerpState = new(speed: 1 / TransitionTime);

            while (lerpState.IsDone == false)  //(LerpValue > MaxValue && FadeOut) || (LerpValue < MaxValue && !FadeOut))
            {
                // t += Time.deltaTime;
                CurrentValue = Mathf.Lerp(CurrentValue, MaxValue, lerpState.GetLerpDelta()); // t / TransitionTime);
                m_CloudDomeMaterial.Set(CloudProfile.COVERAGE, CurrentValue);

                yield return null;
            }
        }

        internal static ShaderProperty.FloatValue _uCloudAlpha = new("_uCloudAlpha");


        IEnumerator CloudHeightSequence(float TransitionTime, float TargetValue)
        {
            float StartingValue = m_CloudDomeMaterial.GetFloat("_uCloudsBottom");

            LerpUtils.DurationLerp.FloatUnscaled lerpState = new(speed: 1 / TransitionTime);

            while (lerpState.IsDone == false)
            {
                m_CurrentCloudHeight = Mathf.Lerp(StartingValue, TargetValue, lerpState.GetLerpTotal());
                m_CloudDomeMaterial.Set(CloudProfile.BOTTOM, m_CurrentCloudHeight);

                yield return null;
            }
        }


        /*
        IEnumerator CloudTallnessSequence(float TransitionTime, float EndValue)
        {
            if (UniStormInitialized && ForceLowClouds == EnableFeature.Disabled)
            {
                float StartValue = m_CloudDomeMaterial.Get(_uCloudsHeight);

                LerpUtils.DurationLerp.FloatUnscaled lerpState = new(speed: 1 / TransitionTime);

                while (lerpState.IsDone == false)
                {
                    m_CloudDomeMaterial.Set(_uCloudsHeight, Mathf.Lerp(StartValue, EndValue, lerpState.GetLerpTotal()));
                    yield return null;
                }
            }
        }*/

 
 
   /*
        IEnumerator RainShaderFadeSequence(float TransitionTime, float target, bool FadeOut)
        {
            if (!FadeOut)
            {
                if (QualitySettings.activeColorSpace == ColorSpace.Gamma)
                    yield return new WaitUntil(() => m_CloudDomeMaterial.Get(_uCloudsCoverage) >= 0.59f);
                else
                    yield return new WaitUntil(() => m_CloudDomeMaterial.Get(_uCloudsCoverage) >= m_ReceivedCloudValue);
            }
            else
            {
                yield return new WaitUntil(() => m_CloudDomeMaterial.Get(_uCloudsCoverage) <= m_ReceivedCloudValue + 0.01f);
            }

            float StartingValue = _WetnessStrength.GlobalValue;//Shader.GetGlobalFloat(_WetnessStrength);

            LerpUtils.DurationLerp.FloatUnscaled lerpState = new(speed: 1 / TransitionTime);

            while (lerpState.IsDone == false)
            {
                _WetnessStrength.GlobalValue = Mathf.Lerp(StartingValue, target, lerpState.GetLerpTotal());

                yield return null;
            }
        }*/

      //  internal readonly ShaderProperty.FloatValue _WetnessStrength = new("_WetnessStrength");
      /*
        IEnumerator SnowShaderFadeSequence(float TransitionTime, float target, bool FadeOut)
        {
            if (!FadeOut)
            {
                if (QualitySettings.activeColorSpace == ColorSpace.Gamma)
                    yield return new WaitUntil(() => m_CloudDomeMaterial.Get(_uCloudsCoverage) >= 0.59f);
                else
                    yield return new WaitUntil(() => m_CloudDomeMaterial.Get(_uCloudsCoverage) >= m_ReceivedCloudValue);

                TransitionTime *= 2;
            }

            float CurrentValue = _SnowStrength.GlobalValue;

            LerpUtils.DurationLerp.FloatUnscaled lerpState = new(speed: 1 / TransitionTime);

            while (lerpState.IsDone == false) //(LerpValue > target && FadeOut) || (LerpValue < target && !FadeOut))
            {
                //t += Time.deltaTime;
                CurrentValue = Mathf.Lerp(CurrentValue, target, lerpState.GetLerpDelta());// (t / TransitionTime));
               _SnowStrength.GlobalValue = CurrentValue;
                yield return null;
            }
        }
      */
      //  internal readonly ShaderProperty.FloatValue _SnowStrength = new("_SnowStrength");

        IEnumerator AuroraShaderFadeSequence(float TransitionTime, float MaxValue, Color InnerColor, Color OuterColor)
        {
            float CurrentLightIntensity = Shader.GetGlobalFloat("_LightIntensity");
            float LerpLightIntensity = CurrentLightIntensity;

            Color CurrentInnerColor = Shader.GetGlobalColor("_InnerColor");
            Color LerpInnerColor;

            Color CurrentOuterColor = Shader.GetGlobalColor("_OuterColor");
            Color LerpOuterColor;

            float t = 0;

            if (CurrentLightIntensity <= 0 && CurrentWeatherType.UseAuroras == SO_WeatherType.Yes_No.Yes)
            {
                m_AuroraParent.SetActive(true);
            }

            while ((t / TransitionTime) < 1)
            {
                t += Time.deltaTime;
                LerpLightIntensity = Mathf.Lerp(CurrentLightIntensity, MaxValue, t / TransitionTime);
                Shader.SetGlobalFloat("_LightIntensity", LerpLightIntensity);

                if (CurrentWeatherType.UseAuroras == SO_WeatherType.Yes_No.Yes)
                {
                    LerpInnerColor = Color.Lerp(CurrentInnerColor, InnerColor, t / TransitionTime);
                    Shader.SetGlobalColor("_InnerColor", LerpInnerColor);

                    LerpOuterColor = Color.Lerp(CurrentOuterColor, OuterColor, t / TransitionTime);
                    Shader.SetGlobalColor("_OuterColor", LerpOuterColor);
                }

                yield return null;
            }

            if (LerpLightIntensity <= 0)
            {
                m_AuroraParent.SetActive(false);
            }
        }




        IEnumerator CloudProfileSequence(float TransitionTime, float MaxBaseSoftness,  float MaxDensity, float MaxCoverageBias)
        {
          //  float EdgeSoftnessValue = m_CloudDomeMaterial.Get(_uCloudsBaseEdgeSoftness);
            float BaseSoftnessValue = m_CloudDomeMaterial.Get(CloudProfile.BOTTOM_SOFTNESS);
           // float DetailStrengthValue = m_CloudDomeMaterial.Get(_uCloudsDetailStrength);
            float StartingDensityValue = m_CloudDomeMaterial.Get(CloudProfile.DENSIY);
            float StartingCoverageBiasValue = m_CloudDomeMaterial.Get(CloudProfile.COVERAGE_BIAS);

            LerpUtils.DurationLerp.FloatUnscaled lerpState = new(speed: 1 / TransitionTime);

            while (lerpState.IsDone == false) 
            {
                float total = lerpState.GetLerpTotal();

              //  m_CloudDomeMaterial.Set(_uCloudsBaseEdgeSoftness, Mathf.Lerp(EdgeSoftnessValue, MaxEdgeSoftness, total));
                m_CloudDomeMaterial.Set(CloudProfile.BOTTOM_SOFTNESS, Mathf.Lerp(BaseSoftnessValue, MaxBaseSoftness, total));
              //  m_CloudDomeMaterial.Set(_uCloudsDetailStrength, Mathf.Lerp(DetailStrengthValue, MaxDetailStrength, total));
                m_CloudDomeMaterial.Set(CloudProfile.DENSIY, Mathf.Lerp(StartingDensityValue, MaxDensity, total));
                m_CloudDomeMaterial.Set(CloudProfile.COVERAGE_BIAS, Mathf.Lerp(StartingCoverageBiasValue, MaxCoverageBias, total));

                yield return null;
            }
        }

        internal readonly ShaderProperty.FloatValue _FogBlendHeight = new("_FogBlendHeight");
        internal readonly ShaderProperty.FloatValue _OpaqueY = new("_OpaqueY");
        internal readonly ShaderProperty.FloatValue _TransparentY = new("_TransparentY");

    }
}