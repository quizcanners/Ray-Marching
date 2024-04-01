using PainterTool;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    using Inspect;
    using Utils;

    [ExecuteAlways]
    [DisallowMultipleComponent]
    public class Inst_RtxVolumeSettings : MonoBehaviour, IPEGI, IPEGI_Handles
    {
        private readonly Gate.Vector3Value _position = new();

        public float Size = 1;
        public int hSlices = 4;
        public bool IsDynamicRoot;
        //  public bool staticPosition;

        static int GetDisplaySize()
        {
            var current = C_VolumeTexture.LatestInstance; // 1024;
            if (!current)
                return 1024;

            return current.TextureWidth;
        }
        public int Height => hSlices * hSlices;

        public int Width => GetDisplaySize() / hSlices;

        public bool IsInsideHalfBounds(Vector3 point)
        {
            var diff = (GetVolumePosition() - point).Abs();

            var w = Width;
            var size = 0.25f * Size * new Vector3(w, Height, w);

            return diff.x < size.x && diff.y < size.y && diff.z < size.z;
        }

        public bool IsInsideBounds(Vector3 point)
        {
            var diff = (GetVolumePosition() - point).Abs();

            var w = Width;
            var size = 0.5f * Size * new Vector3(w, Height, w);

            return diff.x < size.x && diff.y < size.y && diff.z < size.z;
        }

        Vector3 GetVolumePosition()
        {
           // if (staticPosition)
                return DesiredCenter;

          //  return VolumeTexture.GetDiscretePosition(transform.position, Size, out _, 32);
        }

        Vector3 DesiredCenter
        {
            get
            {
                var pos = transform.position;
                pos.y += Height * 0.5f * Size;
                return pos;
            }
            set
            {
                value.y -= Height * 0.5f * Size;
                transform.position = value;
            }
        }

        private void OnEnable()
        {
            VolumeTracing.OnEnable(this);
        }

        private void OnDisable()
        {
            VolumeTracing.OnDisable(this);
        }


        private void Update()
        {
            if (!IsDynamicRoot && _position.TryChange(transform.position)) 
            {
                VolumeTracing.OnVolumePositionChanged(this);
            }
        }

        #region Inspector

        public override string ToString() => gameObject.name;

        void IPEGI.Inspect()
        {
            var changes = pegi.ChangeTrackStart();

            Icon.Refresh.Click();

            pegi.Nl();

            //  "Static Position".PegiLabel().ToggleIcon(ref staticPosition).Nl();

            "Dynamic Root".PegiLabel().ToggleIcon(ref IsDynamicRoot).Nl();

            "Size".PegiLabel(50).Edit(ref Size, 0.01f, 2).Nl();

            "H Slices".PegiLabel(60).Edit(ref hSlices, 2, 10).Nl();

            if (!Mathf.IsPowerOfTwo(hSlices)) 
            {
                "Non Power of two slices can introduce vertical wavy patterns on flat surfaces".PegiLabel().WriteWarning().Nl();
            }

            "Will result in X:{0} Z:{0} Y:{1} volume".F(Width, Height).PegiLabel().Nl();

            "Stack".PegiLabel().Edit_List(VolumeTracing.Stack).Nl();

            if (changes)
                VolumeTracing.OnVolumeConfigStackChanged();
        }

        #endregion

      

        public void OnSceneDraw()
        {

            //Vector3 GetDiscretePosition(Vector3 position, float size, out float scaledChunks, int segmentSize = 32) 

            var w = Width;
            var center = DesiredCenter; //transform.position;
         //   var hOff = Height * 0.5f * Size;
           // center.y += hOff;
            var size = new Vector3(w, Height, w) * Size;

            pegi.Gizmo.DrawCube(center, size, Color.blue);

            if (pegi.Handle.BoxBoundsHandle(ref center, ref size, Color.green)) 
            {
                DesiredCenter = center;
                //center.y -= hOff;
                //transform.position = center;
            }

            /*
            if (!staticPosition)
            {
                var discreteCenter = VolumeTexture.GetDiscretePosition(transform.position, Size, out _, 32);
                discreteCenter.y += Height * 0.5f * Size;
                pegi.Handle.DrawWireCube(discreteCenter, size);
            }*/
        }
    }

    [PEGI_Inspector_Override(typeof(Inst_RtxVolumeSettings))]
    internal class Inst_RtxVolumeSettingsDrawer : PEGI_Inspector_Override { }
}
