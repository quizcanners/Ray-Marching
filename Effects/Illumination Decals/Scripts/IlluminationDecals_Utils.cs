using QuizCanners.Inspect;
using QuizCanners.Utils;
using System.Collections.Generic;

namespace QuizCanners.SpecialEffects
{
    public static class IlluminationDecals
    {

        public static Singleton_IlluminationDecals MGMT => Singleton.Get<Singleton_IlluminationDecals>();

        public enum AoMode
        {
            Center, Side, Edge, Corner
        }

        public enum ShadowMode
        {
            Capsule,
            Box,
            Sphere,
            Sdf,
        }

        //

        public static bool AnyDynamics => s_dynamicAoDecalTargets.Count>0 || s_dynamicShadowDecalTargets.Count > 0;
        public static bool AnyStatics => s_staticShadowDecalTargets.Count > 0 || s_staticAoDecalTargets.Count > 0;
        public static bool AnyTargets => AnyDynamics || AnyStatics;

        public static readonly List<C_ShadowDecalTarget> s_staticShadowDecalTargets = new();
        public static readonly List<C_ShadowDecalTarget> s_dynamicShadowDecalTargets = new();

        public static readonly List<C_AODecalTarget> s_staticAoDecalTargets = new();
        public static readonly List<C_AODecalTarget> s_dynamicAoDecalTargets = new();
        public static int StaticDecalsVersion;
        internal static int DynamicDecalsVersion;

        public static void Inspect() 
        {
            
            "AO".PegiLabel(pegi.Styles.HeaderText).Nl();
            "Static Decals".PegiLabel().Edit_List_UObj(s_staticAoDecalTargets).Nl();
            "Dynamic Decals".PegiLabel().Edit_List_UObj(s_dynamicAoDecalTargets).Nl();

            pegi.Space();

            "SHadows".PegiLabel(pegi.Styles.HeaderText).Nl();
            "Static Shadows".PegiLabel().Edit_List_UObj(s_staticShadowDecalTargets).Nl();
            "Dynamic Shadows".PegiLabel().Edit_List_UObj(s_dynamicShadowDecalTargets).Nl();
        }
    }
}