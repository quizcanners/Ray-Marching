using QuizCanners.Inspect;
using System.Collections.Generic;
using UnityEngine;

namespace QuizCanners.StampTerrain
{
    [ExecuteAlways]
    public class Terrain_LayerProvider : MonoBehaviour, IPEGI
    {
        [SerializeField]
        private TerrainLayersConfig_ScriptableObject layers;

        private static readonly List<Terrain_LayerProvider> s_activeLayerProviders = new();

        protected void OnDisable()
        {
            s_activeLayerProviders.Remove(this);

            if (s_activeLayerProviders.Count > 0)
                TerrainBaking.Layers.Set(s_activeLayerProviders[^1].layers);
            else
                TerrainBaking.Layers.Clear();
        }

        protected void OnEnable()
        {
            s_activeLayerProviders.Add(this);
            TerrainBaking.Layers.Set(layers);
        }

        void Update() 
        {
            TerrainBaking.Layers.ManagedUpdate();

        }

        #region Inspector
        public void Inspect()
        {
            var changes = pegi.ChangeTrackStart();
            "Layers".PegiLabel().Edit_Inspect(ref layers).Nl();

            if (Icon.Refresh.Click() | changes)
                TerrainBaking.Layers.Set(layers, dirty: true);
        }
        #endregion
    }

    [PEGI_Inspector_Override(typeof(Terrain_LayerProvider))]
    internal class Terrain_LayerProviderDrawer : PEGI_Inspector_Override { }
}
