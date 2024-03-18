using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using UnityEngine;

namespace QuizCanners.StampTerrain
{

    [CreateAssetMenu(fileName = FILE_NAME, menuName = QcUnity.SO_CREATE_MENU + "Terrain/" + FILE_NAME)]
    public class TerrainLayersConfig_ScriptableObject : ScriptableObject, IPEGI
    {
        const string FILE_NAME = "Terrain Layers";

        [SerializeField] private TerrainLayerScriptableObject FieldGrassSO;
        [SerializeField] private TerrainLayerScriptableObject ForestGrassSO;
        [SerializeField] private TerrainLayerScriptableObject StonesSO;
        [SerializeField] private TerrainLayerScriptableObject SandSO;

        [SerializeField] public TerrainLayerScriptableObject CliffSO;


        [Header("Shared Settings:")]
        public Configurations Settings;

        public TerrainBaking.LayerTextureSet this[int index] 
        {
            get 
            {
                switch (index) 
                {
                    case 0: return FieldGrassSO.TextureSet;
                    case 1: return ForestGrassSO.TextureSet; 
                    case 2: return StonesSO.TextureSet;
                    case 3: return SandSO.TextureSet;
                    default: return null;
                }
            }
        }

        public bool GotTerrainLayers() => FieldGrassSO && ForestGrassSO && StonesSO && SandSO;

        #region Inspector

        private readonly pegi.EnterExitContext _context = new();
        public void Inspect()
        {
            using (_context.StartContext()) 
            {
                "Grass".PegiLabel().Edit_Enter_Inspect(ref FieldGrassSO).Nl();
                "Forest".PegiLabel().Edit_Enter_Inspect(ref ForestGrassSO).Nl();
                "Stones".PegiLabel().Edit_Enter_Inspect(ref StonesSO).Nl();
                "Sand".PegiLabel().Edit_Enter_Inspect(ref SandSO).Nl();

                if (!_context.IsAnyEntered)
                    pegi.Space();

                "Cliff".PegiLabel().Edit_Enter_Inspect(ref CliffSO).Nl();
            }
        }

        #endregion

        [Serializable]
        public class Configurations 
        {
            public Texture2D Caustics;
            public float Sharpness = 0.1f;
        }
    }
}
