using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;

namespace UniStorm
{

    [CreateAssetMenu(fileName = FILE_NAME, menuName = QcUnity.SO_CREATE_MENU + nameof(UniStorm) + "/" + FILE_NAME)]
    public class SO_WetherConfiguration : ScriptableObject, IPEGI
    {
        public const string FILE_NAME = "Uni Storm Config";

        public bool CustomizeQuality;


        public void Inspect()
        {
            "Customize Quality".PegiLabel().ToggleIcon(ref CustomizeQuality).Nl();
        }
    }

    [PEGI_Inspector_Override(typeof(SO_WetherConfiguration))] internal class SO_WetherConfigurationDrawer : PEGI_Inspector_Override { }
}