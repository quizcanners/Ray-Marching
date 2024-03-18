using QuizCanners.Utils;
using System.Collections.Generic;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    public static class VolumeTracing
    {
        public static int ActiveConfigVersion;
        public static int Version = 0;

        public enum MotionMode { Static, DiscreteSteps, DynaimicRoot  }

        public static void OnVolumeConfigStackChanged()
        {
            ActiveConfigVersion++;
        }

        public static List<Inst_RtxVolumeSettings> Stack = new();

        public static void OnDisable(Inst_RtxVolumeSettings cfg) 
        {
            if (Stack.IndexOf(cfg) == Stack.Count - 1)
                OnVolumeConfigStackChanged();

            Stack.Remove(cfg);
        }

        public static void OnEnable(Inst_RtxVolumeSettings cfg) 
        {
            if (Stack.Count == 0)
            {
                AddAsCurrent();
                return;
            }

            var cam = Camera.main;

            if (!cam)
            {
                AddAsCurrent();
                return;
            }

            if (GotActiveVolume()) 
            {
                Stack.Insert(0, cfg);
                return;
            }

            var camPos = cam.transform.position;

            var toCam = Vector3.Distance(cfg.transform.position, camPos);

            for (int i = Stack.Count - 1; i >= 0; i--)
            {
                var other = Stack[i];

                if (Vector3.Distance(other.transform.position, camPos) > toCam)
                {
                    if (i == Stack.Count - 1)
                    {

                        AddAsCurrent();
                        return;
                    }

                    Stack.Insert(i + 1, cfg);
                    return;
                }
            }

            Stack.Insert(0, cfg);

            return;

            void AddAsCurrent()
            {
                Stack.Add(cfg);
                OnVolumeConfigStackChanged();
            }
        }

        private static Vector3 previousPosition;


        public static bool GotActiveVolume()
        {
            if (Stack.Count == 0)
                return false;

            Inst_RtxVolumeSettings active = Stack[^1];

            return active.IsInsideBounds(previousPosition);
        }

        public static void OnCameraPositionChanged(Vector3 newPosition) 
        {
            if (Vector3.Distance(previousPosition, newPosition) < 0.5f)
                return;

            previousPosition = newPosition;

            if (Stack.Count < 2)
                return;

            Inst_RtxVolumeSettings active = Stack[^1];

            /* if (active.IsInsideHalfBounds(newPosition))
                 return;*/

            if (active.IsInsideBounds(newPosition))
                return;

            /*
            if (active.IsInsideBounds(newPosition)) 
            {
                for (int i = Stack.Count - 2; i >= 0; i--)
                {
                    var volume = Stack[i];

                    if (!volume.IsInsideHalfBounds(newPosition))
                        continue;

                    Stack.Move(i, Stack.Count - 1);
                    SetDirty();
                    return;
                }

                return;
            }*/

            for (int i = Stack.Count - 2; i >= 0; i--)
            {
                var volume = Stack[i];

                if (!volume.IsInsideBounds(newPosition))
                    continue;
                
                Stack.Move(i, Stack.Count-1);
                OnVolumeConfigStackChanged();
                return;
            }
        }


        public static void OnVolumePositionChanged(Inst_RtxVolumeSettings cfg) 
        {
            if (Stack.Count != 0 && Stack[^1] == cfg)
                OnVolumeConfigStackChanged();
        }
    }
}
