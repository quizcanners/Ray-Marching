using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;


namespace QuizCanners.RayTracing
{
    public class BoundingBoxCalculator : IPEGI_Handles, IPEGI
    {
        public Vector3 Min = Vector3.positiveInfinity;
        public Vector3 Max = Vector3.negativeInfinity;

        public Vector3 Center
        {
            get => (Min + Max) * 0.5f;
            set 
            {
                var extents = Extents;
                Min = value - extents;
                Max = value + extents;
            }
        }

        public Vector3 Extents 
        {
            get => Size * 0.5f;
        }

        public Vector3 Size
        {
            get => Vector3.Max(Vector3.zero, (Max - Min));
            set 
            {
                var center = Center;
                var extents = value * 0.5f;
                Min = center - extents;
                Max = center + extents;
            }
        }

        public Bounds ToBounds() => new(center: Center, size: Size);

        public float Volume 
        {
            get 
            {
                var s = Size;
                return s.x * s.y * s.z;
            }
        }

        public void Reset() 
        {
            Min = Vector3.positiveInfinity;
            Max = Vector3.negativeInfinity;
        }

      
        public void Add(Vector3 center, Vector3 size) 
        {
            var extents = size * 0.5f;
            Min = Vector3.Min(Min, center - extents);
            Max = Vector3.Max(Max, center + extents);
        }

        public float GetEncapsulationEfficiency(BoundingBoxCalculator other, float coefficient) 
        {
            var volume = Volume;
            var newMin = Vector3.Min(Min, other.Min);
            var newMax = Vector3.Max(Max, other.Max);
            var newSize = newMax - newMin;
            var newVolume = newSize.x * newSize.y * newSize.z;

            var deltaVolume = newVolume - volume;

            // if (Mathf.Approximately(deltaVolume, 0))
            //   return float.MaxValue;

            var otherVolume = other.Volume;

            var smaller = Mathf.Min(volume, otherVolume);
            var larger = Mathf.Max(volume, otherVolume);

            var sizeRelation = smaller / larger; //Mathf.Abs(other.Volume - volume) / volume;

            return sizeRelation * coefficient / (newVolume + deltaVolume* deltaVolume); // / (1 + deltaVolume / smaller); // (volume + deltaVolume * 10);
        }

        public void Add(Bounds bounds) 
        {
            Min = Vector3.Min(Min, bounds.min);
            Max = Vector3.Max(Max, bounds.max);
        }

        public void Add(BoundingBoxCalculator box)
        {
            Min = Vector3.Min(Min, box.Min);
            Max = Vector3.Max(Max, box.Max);
        }

        #region Inspector
        public void OnSceneDraw()
        {
            pegi.Handle.DrawWireCube(Center, Size);
        }

        public override string ToString() => "From {0} to {1} - {2} m3".F(Min, Max, Volume);

        public void Inspect()
        {
            var center = Center;
            if ("Center".PegiLabel().Edit(ref center))
                Center = center;

            var size = Size;
            if ("Size".PegiLabel().Edit(ref size))
                Size = size;
        }
        #endregion
    }
}