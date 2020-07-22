/*
using UnityEditor;

namespace UniStorm.Utility
{
    [InitializeOnLoad]
    public class UniStormDefines
    {
        const string UniStormDefinesString = "UNISTORM_PRESENT";

        static UniStormDefines()
        {
            InitializeUniStormDefines();
        }

        static void InitializeUniStormDefines()
        {
            var BTG = EditorUserBuildSettings.selectedBuildTargetGroup;
            string UniStormDef = PlayerSettings.GetScriptingDefineSymbolsForGroup(BTG);

            if (!UniStormDef.Contains(UniStormDefinesString))
            {
                if (string.IsNullOrEmpty(UniStormDef))
                {
                    PlayerSettings.SetScriptingDefineSymbolsForGroup(BTG, UniStormDefinesString);
                }
                else
                {
                    if (UniStormDef[UniStormDef.Length - 1] != ';')
                    {
                        UniStormDef += ';';
                    }

                    UniStormDef += UniStormDefinesString;
                    PlayerSettings.SetScriptingDefineSymbolsForGroup(BTG, UniStormDef);
                }
            }
        }
    }
}
*/