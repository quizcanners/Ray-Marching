using QuizCanners.Utils;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace UniStorm.Utility
{
    public class LightningSystem : MonoBehaviour
    {
        [HideInInspector]        public int LightningGenerationDistance = 100;
        [HideInInspector]        public LineRenderer LightningBolt;
        [HideInInspector]        List<Vector3> LightningPoints = new List<Vector3>();
        [HideInInspector]        public bool AnimateLight;
        [HideInInspector]        public float LightningLightIntensityMin = 1;
        [HideInInspector]        public float LightningLightIntensityMax = 1;
        [HideInInspector]        public float LightningLightIntensity;
       // [HideInInspector]        public Light LightningLightSource;
        [HideInInspector]        public float LightningCurveMultipler = 1.45f;
        [HideInInspector]        public AnimationCurve LightningCurve = AnimationCurve.EaseInOut(0, 0, 1, 1);
        [HideInInspector]        public float m_FlashSeconds = 0.5f;
        [HideInInspector]        public Transform StartingPoint;
        [HideInInspector]        public Transform EndingPoint;
        [HideInInspector]        public int m_Segments = 45;
        [HideInInspector]        public float Speed = 0.032f;
        [HideInInspector]        public float Scale = 2;
        [HideInInspector]        public Transform PlayerTransform;
        [HideInInspector]        public List<AudioClip> ThunderSounds = new List<AudioClip>();
        [HideInInspector]        public int BoltIntensity = 10;
        [HideInInspector]        public float LightningSpeed = 0.1f;
        [HideInInspector]        public float StaticIntensity = 0.05f;

        AudioSource AS;
        Coroutine LightningCoroutine;
        float m_FlashTimer;
        float m_GenerateTimer;
        float m_WidthTimer;
        public Material m_LightningMaterial;
        Color m_LightningColor;
        float PointIndex;
        Vector3 m_LightningCurve;
        bool Generated = false;
        float LightningTime;
        Perlin noise;
        float CurrentIndex = 0;
        Vector3 Final;

        UniStormSystem Mgmt => Singleton.Get<UniStormSystem>();

        void Start()
        {
            if (!LightningBolt)
            {
                GameObject TempBolt = Resources.Load("Lightning Renderer") as GameObject;
                LightningBolt = Instantiate(TempBolt, Vector3.zero, Quaternion.identity).GetComponent<LineRenderer>();
                LightningBolt.transform.SetParent(Mgmt.transform);
                LightningBolt.name = "Lightning Renderer";
            }
            if (!EndingPoint)
            {
                GameObject TempEndPoint = Resources.Load("Lightning End Point") as GameObject;
                EndingPoint = Instantiate(TempEndPoint, Vector3.zero, Quaternion.identity).transform;
                EndingPoint.transform.SetParent(Mgmt.transform);
                EndingPoint.name = "Lightning End Point";
            }

            if (!StartingPoint)
            {
                StartingPoint = new GameObject().transform;
                StartingPoint.transform.position = Vector3.zero;
                StartingPoint.SetParent(Mgmt.transform);
                StartingPoint.name = "Lightning Start Point";
            }

            m_Segments = 20;

            LightningBolt.positionCount = m_Segments;
            PointIndex = 1f / (float)m_Segments;

            for (int i = 0; i < LightningBolt.positionCount; i++)
            {
                LightningPoints.Add(transform.position);
            }

            if (!AS)
            {
                AS = gameObject.AddComponent<AudioSource>();
                AS.outputAudioMixerGroup = Mgmt.SoundManager.UniStormAudioMixer.FindMatchingGroups("Master/Weather")[0];
                LightningBolt.enabled = false;
                m_LightningMaterial = LightningBolt.material;
                m_LightningMaterial.SetColor("_TintColor", Mgmt.LightningColor);
                m_LightningColor = Mgmt.LightningColor;
            }

            Vector3 GeneratedPosition = new Vector3(PlayerTransform.position.x, PlayerTransform.position.y, PlayerTransform.position.z) + new Vector3(Random.insideUnitSphere.x, 0, Random.insideUnitSphere.z) * LightningGenerationDistance;
            StartingPoint.position = GeneratedPosition + new Vector3(0, 80, 0);
            EndingPoint.position = GeneratedPosition;

           // LightningLightSource.transform.rotation = Quaternion.Euler(UnityEngine.Random.Range(35, 85), UnityEngine.Random.Range(0, 360), 0);
            LightningLightIntensity = Random.Range(LightningLightIntensityMin, LightningLightIntensityMax);

            if (Mgmt.LightningStrikes == UniStormSystem.EnableFeature.Disabled)
            {
                EndingPoint.gameObject.SetActive(false);
            }
        }

        void SetupLightningLight()
        {
            //LightningLightSource.transform.rotation = Quaternion.Euler(UnityEngine.Random.Range(10, 40), UnityEngine.Random.Range(0, 360), 0);
        }

        void GeneratePoints()
        {
            m_GenerateTimer += Time.deltaTime;

            if (noise == null)
            {
                noise = new Perlin();
            }

            float offset = Time.time * -0.01f;
            m_LightningMaterial.SetTextureOffset("_MainTex", new Vector2(offset, 0));

            float timex = Time.time * 1;
            float timey = Time.time * 1;
            float timez = Time.time * 1;

            if (m_GenerateTimer <= 1)
            {
                for (int i = 0; i < LightningBolt.positionCount; i++)
                {
                    Vector3 position = Vector3.Lerp(StartingPoint.position, EndingPoint.position, (float)i * PointIndex);
                    Vector3 position2 = Vector3.Lerp(StartingPoint.position, EndingPoint.position, (float)i * PointIndex);
                    Vector3 offsety = new Vector3(noise.Noise(timex + position.x, timex + position.y, timex + position.z),
                noise.Noise(timey + position.x, timey + position.y, timey + position.z),
                noise.Noise(timez + position.x, timez + position.y, timez + position.z));

                    int Strength = 8;
                    position += (offsety * Strength);

                    if (CurrentIndex % 5 == 0)
                    {
                        m_LightningCurve = new Vector3(Random.Range(-4.0f, 4.0f), 0, Random.Range(-4.0f, 4.0f)) + m_LightningCurve;
                    }

                    if (i <= 1)
                    {
                        Final = Vector3.Lerp(position + m_LightningCurve * i, position2, (float)i * PointIndex);
                    }
                    else
                    {
                        Final = Vector3.Lerp(position + m_LightningCurve * i, position2, (float)i * PointIndex);
                    }

                    LightningPoints[i] = Vector3.Lerp(Final, EndingPoint.position, (float)i * PointIndex);

                    if (i == LightningBolt.positionCount - 1)
                    {
                        m_GenerateTimer = 2;
                    }

                    LightningBolt.SetPosition(i, LightningPoints[i]);
                    CurrentIndex++;
                }
            }
        }

        void Update()
        {
            if (AnimateLight)
            {
                LightningTime += Time.deltaTime * LightningCurveMultipler;
                var LightIntensity = LightningCurve.Evaluate(LightningTime);
                Mgmt.LightingStrikes.intensity = LightIntensity * LightningLightIntensity;

                Shader.SetGlobalFloat("_uLightning", Mgmt.LightingStrikes.intensity * 0.3f);

                if (LightningTime >= 1)
                {
                    LightningTime = 0;
                    AnimateLight = false;
                    //LightningLightSource.transform.rotation = Quaternion.Euler(UnityEngine.Random.Range(35, 85), UnityEngine.Random.Range(0, 360), 0);
                }
            }
        }

        public void GenerateLightning()
        {
            Generated = true;
            Speed = LightningSpeed;
            Scale = BoltIntensity;
            Mgmt.LightningStruckObject = null;

            LightningLightIntensity = Random.Range(LightningLightIntensityMin, LightningLightIntensityMax);
            if (LightningCoroutine != null)
            {
                StopCoroutine(LightningCoroutine);
            }
            LightningCoroutine = StartCoroutine(DrawLightning());
        }

        IEnumerator DrawLightning()
        {
            AnimateLight = true;
            LightningBolt.enabled = true;
            StartCoroutine(ThunderSoundDelay());
            LightningBolt.widthMultiplier = 0;

            if (Mgmt.LightningStrikes == UniStormSystem.EnableFeature.Enabled)
            {
                var End = EndingPoint.GetComponent<LightningStrike>();

                End.CreateLightningStrike();
                if (End.HitPosition != Vector3.zero)
                {
                    Vector3 OffSet = new Vector3(Random.Range(-70, 70), 100, Random.Range(-70, 70));
                    EndingPoint.position = End.HitPosition;
                    StartingPoint.position = new Vector3(EndingPoint.position.x, StartingPoint.position.y, EndingPoint.position.z) + OffSet;
                }

                if (End.EmeraldAIAgentDetected)
                {
                    if (End.HitAgent != null)
                    {
                        EndingPoint.position = End.HitAgent.transform.position;
                    }
                }

                CurrentIndex = 0;
                m_GenerateTimer = 0.2f;
                m_LightningCurve = new Vector3(Random.Range(-10,10), 0, Random.Range(-10,10));

                while (Generated)
                {
                    m_FlashTimer += Time.deltaTime;

                    GeneratePoints();

                    LightningBolt.widthMultiplier = 7;
               
                    if (m_FlashTimer >= m_FlashSeconds)
                    {
                        m_WidthTimer += Time.deltaTime * 2;
                        Color TempColor = m_LightningColor;
                        TempColor.a = Mathf.Lerp(1, 0, m_WidthTimer);
                        m_LightningMaterial.SetColor("_TintColor", TempColor);

                        if (m_WidthTimer > 1)
                        {
                            LightningBolt.widthMultiplier = 0;
                            Generated = false;
                            m_WidthTimer = 0;
                        }
                    } else 
                    {
                        Color TempColor2 = m_LightningColor;
                        TempColor2.a = Mathf.Lerp(1, Mgmt.LightingStrikes.intensity / 1.75f, m_FlashTimer);
                        m_LightningMaterial.SetColor("_TintColor", TempColor2);
                    }


                    yield return null;
                }
            }

            m_FlashTimer = 0;
            LightningBolt.widthMultiplier = 0;
            LightningBolt.enabled = false;

            EndingPoint.GetComponent<LightningStrike>().HitPosition = Vector3.zero;
            Vector3 GeneratedPosition = new Vector3(PlayerTransform.position.x, PlayerTransform.position.y, PlayerTransform.position.z) + new Vector3(Random.insideUnitSphere.x, 0, Random.insideUnitSphere.z) * LightningGenerationDistance;
            Vector3 RandomOffSet = new Vector3(0, Random.Range(0, 40), 0);
            Vector3 StartOffSet = new Vector3(Random.Range(-200, 200), 0, Random.Range(-200, 200));
            StartingPoint.position = GeneratedPosition + new Vector3(0, 200, 0) + StartOffSet;
            EndingPoint.position = GeneratedPosition + RandomOffSet;

            Color C = m_LightningColor;
            C.a = Mathf.Lerp(1, 0, m_WidthTimer);
            m_LightningMaterial.SetColor("_TintColor", C);
        }

        //When a lightning strike is generated, get the distance between the player and the lightning position.
        //Create a delay based on the distance to simulate the sound having to travel.
        IEnumerator ThunderSoundDelay()
        {
            float DistanceDelay = Vector3.Distance(EndingPoint.position, PlayerTransform.position) / 50;
            yield return new WaitForSeconds(DistanceDelay);
            AS.pitch = Random.Range(0.7f, 1.3f);
            if (ThunderSounds.Count > 0)
            {
                AudioClip m_ThunderSound = ThunderSounds[Random.Range(0, ThunderSounds.Count)];
                if (m_ThunderSound != null)
                {
                    AS.PlayOneShot(m_ThunderSound);
                }
            }
        }
    }
}