using QuizCanners.Inspect;
using UnityEngine;


namespace QuizCanners.VolumeBakedRendering
{
    using static Utils.ShaderProperty;

    public class MatDrawer_RayGeometryStandardSpecular : PEGI_Inspector_Material
    {
        private readonly MaterialToggle SIMPLIFY_SHADER = new("simplifyShader", "_SIMPLIFY_SHADER");

        private readonly TextureValue SpecularMap = new("_SpecularMap");
        
        // AO
        private readonly KeywordEnum AO = new("_AO", new string[] {  "None", "MADS", "Separate" });
        private readonly MaterialToggle AMBIENT_IN_UV2 = new("ambInuv2", "_AMBIENT_IN_UV2");
        private readonly MaterialToggle COLOR_R_AMBIENT = new("colAIsAmbient", "_COLOR_R_AMBIENT");
        private readonly TextureValue OcclusionMap = new("_OcclusionMap");

        // Ray Tracing // 	[KeywordEnum(OFF, ON, INVERTEX, MIXED)] _PER_PIXEL_REFLECTIONS("Traced Reflections", Float) = 0
        private readonly KeywordEnum RTX = new("_PER_PIXEL_REFLECTIONS", new string[] { "OFF", "ON", "INVERTEX", "MIXED" });

        // Parallax      
        private readonly MaterialToggle PARALLAX = new("parallax", "_PARALLAX");
        private readonly FloatValue ParallaxForce = new ("_ParallaxForce");


        private readonly MaterialToggle OFFSET_BY_HEIGHT = new("heightOffset", "_OFFSET_BY_HEIGHT");
        private readonly FloatValue HeightOffset = new("_HeightOffset");

        private readonly MaterialToggle _DAMAGED = new("isDamaged", "_DAMAGED");
        private readonly TextureValue _Damage_Tex = new("_Damage_Tex");
        private readonly TextureValue _DamDiffuse = new("_DamDiffuse");
        private readonly TextureValue _BumpD = new("_BumpD");
        private readonly TextureValue _DamDiffuse2 = new("_DamDiffuse2");
        private readonly TextureValue _BumpD2 = new("_BumpD2");
        private readonly TextureValue _BloodPattern = new("_BloodPattern");


        public override bool Inspect(Material mat)
        {

            var tok = mat.PegiToken();

            var changed = pegi.ChangeTrackStart();
            
            pegi.Toggle_DefaultInspector(mat);

            pegi.Nl();

            tok.Toggle(SIMPLIFY_SHADER).Nl();

            tok.Edit(TextureValue.mainTexture).Nl();

            if (!SIMPLIFY_SHADER.Get(mat))
            {
                tok.Edit(TextureValue.bumpMap).Nl();
                tok.Edit(SpecularMap).Nl();
                //tok.Edit(ColorFloat4Value.tintColor).Nl();

                tok.Toggle(PARALLAX).Nl();
                if (mat.Get(PARALLAX)) 
                {
                    tok.Edit(ParallaxForce, 0.001f, 0.3f).Nl();
                }

                tok.Toggle(OFFSET_BY_HEIGHT).Nl();
                if (mat.Get(OFFSET_BY_HEIGHT)) 
                {
                    tok.Edit(HeightOffset, 0.01f, 0.3f).Nl();
                }


                tok.Toggle(_DAMAGED).Nl();

                if (mat.Get(_DAMAGED)) 
                {
                    tok.Edit(_Damage_Tex, "Damage Mask").Nl();
                    tok.Edit(_DamDiffuse, "Damage Color").Nl();
                    tok.Edit(_BumpD, "Damage Bump").Nl();
                    tok.Edit(_DamDiffuse2, "Deep Damage Col").Nl();
                    tok.Edit(_BumpD2, "Deep Damage Bump").Nl();
                    tok.Edit(_BloodPattern, "Blood Splatter Mask (R)").Nl();
                }
            }

            tok.Edit_Enum(AO).Nl();

            if (mat.Get(AO) == 2) 
            {
                tok.Edit(OcclusionMap).Nl();
                tok.Toggle(AMBIENT_IN_UV2).Nl();
            }

            tok.Toggle(COLOR_R_AMBIENT).Nl();

            tok.Edit_Enum(RTX).Nl();

            return changed;
        }


    }
}