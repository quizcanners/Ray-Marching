using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.StampTerrain
{
    [ExecuteAlways]
    public abstract class TerrainManagerBase : Singleton.BehaniourBase, IPEGI
    {
        [SerializeField] public Terrain_BakeController _baker;
        [SerializeField] protected Terrain_ToUnityController _toUnityTerrain = new();

        public float GetTerrainHeight(Vector3 position) => _toUnityTerrain.GetHeight(position);

        public Vector3 GetNormal(Vector3 position) => _toUnityTerrain.GetNormal(position);

        public bool TerrainGenerationCompleted => !IsDirty && _baker.IsBakingFinished && !IsTerrainDirty;

        private readonly Gate.Integer _stampsVersionGate = new();
        private readonly Gate.Integer _bakeVersionGate = new();

        protected bool IsTerrainDirty 
        {
            get => _bakeVersionGate.IsDirty(_baker.BakedVersion);
            set 
            {
                if (value)
                    _bakeVersionGate.ValueIsDefined = false;
                else
                    _bakeVersionGate.TryChange(_baker.BakedVersion);
            }
        }

        protected bool IsDirty
        {
            get => _stampsVersionGate.IsDirty(TerrainBaking.Stamps.StampArrangementVersion);
            set
            {
                if (value)
                    _stampsVersionGate.ValueIsDefined = false;
                else
                    _stampsVersionGate.TryChange(TerrainBaking.Stamps.StampArrangementVersion);
            }
        }


        public void GetPixelsAndMappingData(out BakedTerrainBiomeData data)
        {
            data = new();
            data.pixels = _baker.GetControlMapPixels(out data.resolution);
            data.size = _baker.BakedAreaSize;
            data.startPos = _baker.BakedAreaCenterPosition - new Vector3(data.size.x * 0.5f, 0, data.size.z * 0.5f);
            data.minMaxHeight = new Vector2(_baker.MinHeight, _baker.MaxHeight);
        }


        internal void ToUnityTerrain()
        {
            GetPixelsAndMappingData(out BakedTerrainBiomeData data);
            _toUnityTerrain.CreateFromAlpha(data.pixels, resolution: data.resolution, position: data.startPos, size: data.size, minHeight: data.minMaxHeight.x, maxHeight: data.minMaxHeight.y);
        }

        protected virtual void Update() 
        {
            if (IsDirty)
                return;
            
            if (IsTerrainDirty && _baker.IsBakingFinished)
            {
                IsTerrainDirty = false;
                ToUnityTerrain();
            }
        }


        protected void RestartBake()
        {
            _baker.SetDirty();
            IsDirty = false;
            IsTerrainDirty = true;
        }


        protected override void OnRegisterServiceInterfaces()
        {
            base.OnRegisterServiceInterfaces();
            RegisterServiceAs<TerrainManagerBase>();
        }

        protected override void OnAfterEnable()
        {
            base.OnAfterEnable();
        }

        protected override void OnBeforeOnDisableOrEnterPlayMode(bool afterEnableCalled)
        {
            _toUnityTerrain.OnDisable();
        }


        public override void Inspect()
        {
            base.Inspect();

            if (Icon.Refresh.Click())
                IsDirty = true;

            pegi.Nl();

        }

    }
}
