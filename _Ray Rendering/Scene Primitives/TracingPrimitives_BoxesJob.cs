using QuizCanners.Inspect;
using Unity.Burst;
using Unity.Collections;
using Unity.Jobs;
using Unity.Mathematics;
using QuizCanners.Utils;

namespace QuizCanners.VolumeBakedRendering
{
    public static partial class TracingPrimitives
    {
        internal const int MAX_BOUNDING_BOXES_COUNT = 8;

        struct Efficiency
        {
            public int Index_Bigger;
            public int Index_Smaller;
            public float Value;
        }

        public struct BoxJobMeta : IPEGI
        {
            public int LoopsCounter;
            public int RemainingToEncapsulate;
            public int DirectEncapslations;
            public int ByBestValue;
            public bool BreakOnFailedEncapsulation;
            public int MaxVoundingBoxesCount;

            public void Inspect()
            {
                "Loops Counter: {0}".F(LoopsCounter).PegiLabel().Nl();
                "Left Unencapsulated: {0}".F(RemainingToEncapsulate).PegiLabel().Nl();
                "Direct Incapsulation: {0}".F(DirectEncapslations).PegiLabel().Nl();
                "By Best Value: {0}".F(ByBestValue).PegiLabel().Nl();
                "Breaked by failed incapsulation: {0}".F(BreakOnFailedEncapsulation).PegiLabel().Nl();
            }
        }

        [BurstCompile(Debug = true,CompileSynchronously = true)]
        public struct BoxesJob : IJob
        {
            private NativeArray<BoxForJob> _boxes;
            private int _remaining;
            private NativeArray<BoxJobMeta> _meta;

            public void Execute()
            {
                var counter = 0;
                bool anyEncapsulated;
                var meta = _meta[0];

                while (_remaining > meta.MaxVoundingBoxesCount && counter < 1000)
                {
                    counter++;

                    Efficiency bestEfficiency = new();

                    anyEncapsulated = false;

                    for (int iSm = 0; iSm < _boxes.Length; iSm++)
                    {
                        var smaller = _boxes[iSm];

                        if (smaller.IsEncapsulaed)
                            continue;

                        if (TryEncapsulate(iSm, ref bestEfficiency))
                        {
                            meta.DirectEncapslations++;
                            anyEncapsulated = true;
                            _remaining--;
                            continue;
                        }
                    }

                    if (anyEncapsulated)
                        continue;

                    if (bestEfficiency.Value > 0)
                    {
                        meta.ByBestValue++;
                        Encapsulate(bigger: bestEfficiency.Index_Bigger, smaller: bestEfficiency.Index_Smaller);
                        _remaining--;
                    }
                    else
                    {
                        meta.BreakOnFailedEncapsulation = true;
                        break;
                    }
                }

             
                meta.LoopsCounter = counter;
                meta.RemainingToEncapsulate = _remaining;
                _meta[0] = meta;
            }

            bool TryEncapsulate(int iSm, ref Efficiency bestEfficiency)
            {
                for (int jBig = 0; jBig < iSm; jBig++)
                {
                    var bigger = _boxes[jBig];
                    if (bigger.IsEncapsulaed)
                        continue;

                    if (TryEncapsulate(biggerIndex: jBig, smallerIndex: iSm, out float efficiency))
                    {
                        return true;
                    }

                    if (efficiency > bestEfficiency.Value)
                    {
                        bestEfficiency.Value = efficiency;
                        bestEfficiency.Index_Bigger = jBig;
                        bestEfficiency.Index_Smaller = iSm;
                    }
                }

                return false;
            }

            bool TryEncapsulate(int biggerIndex, int smallerIndex, out float efficiency)
            {
                var bigger = _boxes[biggerIndex];
                var smaller = _boxes[smallerIndex];

                float coefficient = smaller.EncapsulatesCount + bigger.EncapsulatesCount;

                efficiency = bigger.GetEncapsulationEfficiency(smaller, coefficient: 1f / coefficient);

                if (efficiency >= 2)
                {
                    Encapsulate(bigger: biggerIndex, smaller: smallerIndex);
                    return true;
                }
                return false;
            }

            void Encapsulate(int bigger, int smaller)
            {
                var boxBigger = _boxes[bigger];
                var boxSmaller = _boxes[smaller];
                boxBigger.Encapsulate(ref boxSmaller);
                _boxes[smaller] = boxSmaller;
                _boxes[bigger] = boxBigger;
            }

            public BoxesJob(NativeArray<BoxForJob> boxes, NativeArray<BoxJobMeta> meta)  
            {
                _boxes = boxes;
                _remaining = boxes.Length;
                _meta = meta;
            }
        }

        public struct BoxForJob : IPEGI
        {
            public float3 Min;
            public float3 Max;
            public int EncapsulatedInto;
            public int EncapsulatesCount;
            public int Index;
            public int Iterations;

            public bool IsEncapsulaed => EncapsulatedInto != -1;

            public float3 Center
            {
                get => (Min + Max) * 0.5f;
                set
                {
                    var extents = Extents;
                    Min = value - extents;
                    Max = value + extents;
                }
            }

            public float3 Extents
            {
                get => Size * 0.5f;
            }

            public float3 Size
            {
                get => math.max(float3.zero, Max - Min);
                set
                {
                    var center = Center;
                    var extents = value * 0.5f;
                    Min = center - extents;
                    Max = center + extents;
                }
            }

            public float Volume
            {
                get
                {
                    var s = Size;
                    return s.x * s.y * s.z;
                }
            }

            public void Encapsulate(ref BoxForJob other) 
            {
                EncapsulatesCount += other.EncapsulatesCount;
                other.EncapsulatedInto = Index;
                Min = math.min(Min, other.Min);
                Max = math.max(Max, other.Max);
            }

            public float GetEncapsulationEfficiency(BoxForJob other, float coefficient)
            {
                var volume = Volume;
                var newMin = math.min(Min, other.Min);
                var newMax = math.max(Max, other.Max);
                var newSize = newMax - newMin;
                var newVolume = newSize.x * newSize.y * newSize.z;

                var deltaVolume = newVolume - volume;

                // if (Mathf.Approximately(deltaVolume, 0))
                //   return float.MaxValue;

                var otherVolume = other.Volume;

                var smaller = math.min(volume, otherVolume);
                var larger = math.max(volume, otherVolume);

                var sizeRelation = smaller / larger; //Mathf.Abs(other.Volume - volume) / volume;

                return sizeRelation * coefficient / (newVolume + deltaVolume * deltaVolume); // / (1 + deltaVolume / smaller); // (volume + deltaVolume * 10);
            }

            #region Inspect
            public void Inspect()
            {
                "{0} el. {1} m3".F(EncapsulatesCount, Volume).PegiLabel().Nl();

                //"Volume: {0}".F(Volume).PegiLabel().Nl();
                if (IsEncapsulaed)
                    "Encapsulated int {0}".F(EncapsulatedInto).PegiLabel().Nl();
                //"Encapsulates: {0}".F(EncapsulatesCount).PegiLabel().Nl();

            }

            #endregion

            public BoxForJob(float3 min, float3 max, int index) 
            {
                Min = min;
                Max = max;
                EncapsulatedInto = -1;
                EncapsulatesCount = 1;
                Index = index;
                Iterations = 0;
            }
        }
    }
}