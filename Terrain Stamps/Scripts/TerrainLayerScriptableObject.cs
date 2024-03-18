using UnityEngine;

namespace QuizCanners.StampTerrain
{
    [CreateAssetMenu(fileName = FILE_NAME, menuName = Utils.QcUnity.SO_CREATE_MENU + "Terrain/" + FILE_NAME)]
    public class TerrainLayerScriptableObject : ScriptableObject
    {
        const string FILE_NAME = "Single Layer";

        public TerrainBaking.LayerTextureSet TextureSet;
    }
}
