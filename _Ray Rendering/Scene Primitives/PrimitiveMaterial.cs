using QuizCanners.Inspect;
using QuizCanners.Migration;
using QuizCanners.Utils;
using System;
using UnityEngine;
using static QuizCanners.VolumeBakedRendering.TracingPrimitives;

namespace QuizCanners.VolumeBakedRendering
{

    [Serializable]
    public class PrimitiveMaterial : ICfg, IPEGI, IPEGI_ListInspect
    {
        [NonSerialized] public int Version;

        [SerializeField] public PrimitiveMaterialType MatType = PrimitiveMaterialType.lambertian;
      
        public Color Color = Color.gray;
        public float Roughtness = 0.5f;

        public bool Equals(PrimitiveMaterial obj)
        {
            return MatType == obj.MatType && Color == obj.Color && Roughtness == obj.Roughtness;

        }

        public void CopyFrom(PrimitiveMaterial other) 
        {
            MatType = other.MatType;
            Color = other.Color;
            Roughtness = other.Roughtness;
            Version++;
        }
      
        #region Encode & Decode
        public CfgEncoder Encode() => new CfgEncoder()
           .Add("t", (int)MatType)
          
           .Add("col", Color)
           .Add("gl", Roughtness);

        public void DecodeTag(string key, CfgData data)
        {
            switch (key)
            {
                case "t": MatType = (PrimitiveMaterialType)data.ToInt(); break;
              
                case "col": Color = data.ToColor(); break;
                case "gl": Roughtness = data.ToFloat(); break;
            }
        }

        #endregion

        #region Inspector
        void IPEGI.Inspect()
        {
            var changes = pegi.ChangeTrackStart();

            "Color".PegiLabel(60).Edit(ref Color, hdr: true).Nl();

            if (MatType != PrimitiveMaterialType.emissive && Color.Alpha(1).Equals(Color.white))
                "White Color will look weird as it has perfect reflectivity".PegiLabel().Write_Hint();

            "Roughness".PegiLabel(90).Edit(ref Roughtness, 0, 1).Nl();

            "Material".PegiLabel(90).Edit_Enum(ref MatType).Nl();

            if (changes)
                Version++;
        }

        public void InspectInList(ref int edited, int index)
        {
            pegi.Edit(ref Color);

            if (Icon.Enter.Click())
                edited = index;
        }
        #endregion
    }
}