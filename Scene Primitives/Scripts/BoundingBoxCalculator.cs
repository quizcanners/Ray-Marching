using QuizCanners.Inspect;
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