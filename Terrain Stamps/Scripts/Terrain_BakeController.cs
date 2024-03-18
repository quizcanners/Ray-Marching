using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using UnityEngine;

namespace QuizCanners.StampTerrain
{
    /// <summary>
    /// Controls the baking process.
    /// </summary>
    [ExecuteAlways]
    public class Terrain_BakeController : MonoBehaviour, IPEGI
    {
        [SerializeField] private Camera _camera;
        public Camera BakeCamera => _camera;
      
        [SerializeField] private bool _anyResultPublished;
        [SerializeField] private float _terrainHeight01 = 0.5f;
        [SerializeField] private int _defaultTerrain;

        public void SetBakingArea(Vector3 center, Vector3 size) 
        {
            transform.position = new Vector3(center.x, 0, center.z);

            float maxSize = Mathf.Max(size.x, size.z);

            const float SAFETY_BORDER = 1.2f;

            _camera.orthographicSize = maxSize * 0.5f * SAFETY_BORDER;
        }

        [SerializeField] private int _renderTexturesSize = 1024;

        public float MinHeight = -10;
        public float MaxHeight = 10;

        [SerializeField] private GameObject _previousFrame;
        [SerializeField] private Shader _calculateNormalShader;

        private BakingStage _state = BakingStage.Dirty;
        protected int bakingVersion;
        protected int _debug_stampBatches;

        private readonly ShaderProperty.TextureValue TERRAIN_TEXTURE_PUBLISHED = new("Ct_Control");
        private readonly ShaderProperty.VectorValue TERRAIN_POSITION_PUBLISHED = new("Ct_Pos");
        private readonly ShaderProperty.VectorValue TERRAIN_SIZE_PUBLISHED = new("Ct_Size");
        private readonly ShaderProperty.TextureValue TERRANIN_NORMAL_PUBLISHED = new("_Ct_Normal");

        private readonly ShaderProperty.TextureValue TERRAIN_PREVIOUS_BUFFER = new("Ct_Control_Previous");
        private readonly ShaderProperty.VectorValue TERRAIN_POSITION_BAKE = new("Ct_Pos_Bake");
        private readonly ShaderProperty.VectorValue TERRAIN_SIZE_BAKE = new("Ct_Size_Bake");

        private readonly ShaderProperty.VectorValue BAKE_HEIGHT_RANGE = new("Ct_HeightRange");
        private readonly ShaderProperty.VectorValue DEFAULT_TERRAIN = new("Ct_TerrainDefault"); // Not needed

        private readonly BakeState _baking = new();
        [NonSerialized]public RenderTexture[] _bakingBufferTextures;
        [NonSerialized] private RenderTexture _baked_Normal;
        public Texture2D PublishedControlMap { get; private set; }
       

        private bool _activeIsZero;
        private int _version;
        public int BakedVersion { get; private set; } = -1;

        private float _timeWhenBakingFinished;

 
        private readonly Gate.Integer _pixelsVersion = new();
        Color[] _pixels;

        public Color[] GetControlMapPixels(out int resolution) 
        {
            if (!PublishedControlMap) 
            {
                Debug.LogError("No control map found");
                resolution = 0;
                return null;
            }

            resolution = PublishedControlMap.width;

            if (_pixelsVersion.TryChange(BakedVersion))
                _pixels = PublishedControlMap.GetPixels();

            return _pixels;
        }

        public bool IsBakingFinished => !IsDirty && (_state == BakingStage.Finished || _state == BakingStage.ClearingBakerTextures);

        public Vector3 BakedAreaCenterPosition => TERRAIN_POSITION_PUBLISHED.latestValue.XYZ();
        public Vector3 BakedAreaSize => (TERRAIN_SIZE_PUBLISHED.latestValue.x * Vector3.one).Y(MaxHeight-MinHeight);
        
        public float GetBake01FromPositionY(float positionY) 
        {
            return Mathf.Clamp01((positionY - MinHeight) / (MaxHeight - MinHeight));
        }
        
        private RenderTexture ActiveControlTexture
        {
            get => GetBakingBufferTextures()[_activeIsZero ? 0 : 1];
            set => GetBakingBufferTextures()[_activeIsZero ? 0 : 1] = value;
        }
        private RenderTexture PreviousControlTexture => GetBakingBufferTextures()[_activeIsZero ? 1 : 0];

        public void Flip()
        {
            _activeIsZero = !_activeIsZero;
            TERRAIN_PREVIOUS_BUFFER.SetGlobal(PreviousControlTexture);
        }

        private RenderTexture GetNormalTexture() 
        {
            if (!_baked_Normal) 
            {
                _baked_Normal = GetRenderTexture("Terrain's Normal");
            }

            return _baked_Normal;
        }

        public RenderTexture[] GetBakingBufferTextures()
        {
            if (_bakingBufferTextures.IsNullOrEmpty())
            {
                _bakingBufferTextures = new RenderTexture[2];

                _bakingBufferTextures[0] = GetRenderTexture("Terrain Bake data A");
                _bakingBufferTextures[1] = GetRenderTexture("Terrain Bake data B");
            }

            return _bakingBufferTextures;
        }

        public bool IsDirty
        {
            get => BakedVersion != _version;
            private set
            {
                if (value)
                    _version++;
                else
                    BakedVersion = _version;
            }
        }

        private void PublishControlTexture()
        {
            RenderTexture.active = ActiveControlTexture;
            var teraget = GetPublishTexture();
            teraget.ReadPixels(new Rect(0, 0, ActiveControlTexture.width, ActiveControlTexture.height), 0, 0, false);
            teraget.Apply(false);

            TERRAIN_TEXTURE_PUBLISHED.GlobalValue = teraget;
            TERRAIN_POSITION_PUBLISHED.GlobalValue = _baking.adjustedBakePosition.Y(0);
            float size = _baking.ProjectionSize * 2f;
            TERRAIN_SIZE_PUBLISHED.GlobalValue = new Vector4(size, 1 / size, 0, 0);
        }

        private void Publish() 
        {
            _anyResultPublished = true;
            PublishControlTexture();
            TERRANIN_NORMAL_PUBLISHED.GlobalValue = _baked_Normal;
        }

        public float GetChunkSize() => _camera.orthographicSize * 2 / _renderTexturesSize;

        // Make sure our bake projection is modified by a whole number of pixels and not a fraction of.
        public Vector3 FloorPositionToChunkSize(Vector3 pos)
        {
            float size = GetChunkSize();
            pos.y = 0;
            pos.x = Mathf.Floor(pos.x / size) * size;
            pos.z = Mathf.Floor(pos.z / size) * size;

            return pos;
        }

        private Texture2D GetPublishTexture() 
        {
            if (PublishedControlMap)
                return PublishedControlMap;

            PublishedControlMap = new Texture2D(ActiveControlTexture.width, ActiveControlTexture.height, TextureFormat.RGBAHalf, false, true)
            {
                filterMode = FilterMode.Bilinear,
                wrapMode = TextureWrapMode.Clamp,
                name = "Published result"
            };

            return PublishedControlMap;
        }

        private RenderTexture GetRenderTexture(string textureName)
        {
            return new RenderTexture(_renderTexturesSize, _renderTexturesSize, 0, RenderTextureFormat.ARGBHalf)
            {
                wrapMode = TextureWrapMode.Clamp,
                autoGenerateMips = false,
                name = textureName
            };
        }

        void SetupBaking() 
        {
            IsDirty = false;
            bakingVersion++;
            _debug_stampBatches = 0;
            _baking.previousPosition = transform.position;
            _baking.adjustedBakePosition = FloorPositionToChunkSize(_baking.previousPosition).Y(50);
            TERRAIN_POSITION_BAKE.GlobalValue = _baking.adjustedBakePosition.Y(0);

            _baking.ProjectionSize = _camera.orthographicSize;
            float size = _baking.ProjectionSize * 2f;
            TERRAIN_SIZE_BAKE.GlobalValue = new Vector4(size, 1 / size, 0, 0);

            UpdateMainShaderParameters();
        }

        void OnDrawGizmos()
        {
#if UNITY_EDITOR
            // Request updates until baking is done
            if (!IsBakingFinished)
            {
                if (!Application.isPlaying)
                {
                    UnityEditor.EditorApplication.QueuePlayerLoopUpdate();
                    UnityEditor.SceneView.RepaintAll();
                }
            }
#endif
        }

        int blurIterations = 0;

        void LateUpdate() 
        {
            if (!_camera)
                return;

            switch (_state) 
            {
                case BakingStage.Dirty:

                    if (ActiveControlTexture && (ActiveControlTexture.width != _renderTexturesSize && Mathf.IsPowerOfTwo(_renderTexturesSize)))
                    {
                        Clear();
                    }

                    SetupBaking();
                    _previousFrame.SetActive(false);
                  
                    RenderFromCamera();
                    _state = BakingStage.BakingStamps;
                    if (!_anyResultPublished)
                    {
                        // We are publishing premature result here
                        PublishControlTexture();
                    }
                    
                    break;

                case BakingStage.BakingStamps:

                    if (TerrainBaking.Stamps.s_activeStamps.Count == 0) 
                    {
                        OnStampsBaked();
                        break;
                    }

                    Flip();
                    TerrainBaking.Stamps.SetStampsVisible(bakingVersion, out bool lastBatch);
                    _previousFrame.SetActive(true);
                    RenderFromCamera();
                    _debug_stampBatches++;

                    if (lastBatch)
                        OnStampsBaked();
                        
                    void OnStampsBaked()
                    {
                        TerrainBaking.Stamps.HideAllStamps();
                        _previousFrame.SetActive(false);
                        _state = BakingStage.BakingNormal;
                    }

                    break;


                case BakingStage.BakingNormal:

                    Graphics.Blit(ActiveControlTexture, GetNormalTexture(), _baking.GetPostprocessMaterial(_calculateNormalShader));
                    TERRANIN_NORMAL_PUBLISHED.GlobalValue = _baked_Normal;
                    AllBakingDone();
                    break;

                case BakingStage.ClearingBakerTextures:
                    CheckForChanges();
                    if (Time.unscaledTime - _timeWhenBakingFinished > 3) 
                    {
                        ClearBakerTextures();
                        _state = BakingStage.Finished;
                    }

                    break;
                
                case BakingStage.Finished:
                    CheckForChanges();
                    break;
            }

            return;

            void CheckForChanges()
            {
                if (!IsDirty)
                {
                    if (_camera.orthographicSize != _baking.ProjectionSize)
                    {
                        _version++;
                        return;
                    }
                    if (Vector3.Distance(_baking.previousPosition.XZ(), transform.position.XZ()) > 10)
                    {
                        _version++;
                        return;
                    }

                    if (ActiveControlTexture && (ActiveControlTexture.width != _renderTexturesSize && Mathf.IsPowerOfTwo(_renderTexturesSize)))
                    {
                        SetDirty();
                    }

                    TerrainBaking.Stamps.CheckForStampChanges();
                }

                if (IsDirty)
                    _state = BakingStage.Dirty;
                
            }

            /*
            void BlitBuffers(Shader shader)
            {
                Flip();
                Graphics.Blit(PreviousControlTexture, ActiveControlTexture, _baking.GetPostprocessMaterial(shader));
            }*/

            void AllBakingDone() 
            {
                Publish();
                _state = BakingStage.ClearingBakerTextures;
                _timeWhenBakingFinished = Time.unscaledTime;
            }

        }

        protected void OnEnable()
        {
            UpdateMainShaderParameters();

            _camera.allowHDR = false;
            _camera.allowMSAA = false;
            _camera.enabled = false;

            bakingVersion = 0;
        }

        void UpdateMainShaderParameters() 
        {
            float range = MaxHeight - MinHeight;
            BAKE_HEIGHT_RANGE.GlobalValue = new Vector4(MinHeight, MaxHeight, range, 1f / range);
        }

        protected void OnDisable()
        {
            Clear();
        }

        public void Clear() 
        {
            ClearBakerTextures();

            if (PublishedControlMap)
            {
                PublishedControlMap.DestroyWhatever();
                PublishedControlMap = null;
            }

            if (_baked_Normal) 
            {
                _baked_Normal.DestroyWhatever();
                _baked_Normal = null;
            }
        }

        void ClearBakerTextures() 
        {
            if (!_bakingBufferTextures.IsNullOrEmpty())
            {
                _camera.targetTexture = null;
                _bakingBufferTextures[0].DestroyWhatever();
                _bakingBufferTextures[1].DestroyWhatever();
                _bakingBufferTextures = null;
            }
        }

        public void RenderFromCamera() 
        {
            Color terrainColor = GetFallbackColor();

            _camera.backgroundColor = terrainColor;
            _camera.transform.position = _baking.adjustedBakePosition;
            _camera.targetTexture = ActiveControlTexture;
            DEFAULT_TERRAIN.GlobalValue = terrainColor;

            _camera.enabled = true;
            _camera.Render();
            _camera.enabled = false;

            return;

            Color GetFallbackColor() 
            {
                var col = new Color(0, 0, 0, _terrainHeight01);
                if (_defaultTerrain > 0)
                    col[_defaultTerrain - 1] = 1;

                return col;
            } 
        }

        public void SetDirty() 
        {
            _version++;
        }

        #region Inspector
        public void Inspect()
        {
            "State: {0}; Bakes: {1}; Stamp Batch Count: {2}".F(_state, bakingVersion, _debug_stampBatches).PegiLabel().Nl();
            "Height".PegiLabel().Edit_Range(ref MinHeight, ref MaxHeight).Nl();
            "Render Texture Size".PegiLabel().Edit_Delayed(ref _renderTexturesSize).Nl(()=> 
            {
                if (_renderTexturesSize <= 8)
                {
                    _renderTexturesSize = 8;
                    return;
                }

                if (!Mathf.IsPowerOfTwo(_renderTexturesSize)) 
                {
                    _renderTexturesSize = Mathf.ClosestPowerOfTwo(_renderTexturesSize);
                }
            });


            float size = _camera.orthographicSize;

            if ("Area Size".PegiLabel().Edit_Delayed(ref size).Nl()) 
            {
                _camera.orthographicSize = size;
            }

            if (PublishedControlMap)
                pegi.Draw(PublishedControlMap).Nl();

        }
        #endregion

        private enum BakingStage
        {
            Dirty,
            BakingStamps,
            BakingNormal,
            ClearingBakerTextures,
            Finished,
        }

        /// <summary>
        /// Work in progress. Break up baker functionality using composition.
        /// </summary>
        private class BakeState
        {
            public Vector3 adjustedBakePosition;
            public Material _postprocessMaterial;
            public float ProjectionSize;
            public Vector3 previousPosition;

            public Material GetPostprocessMaterial(Shader shader)
            {
                if (_postprocessMaterial)
                {
                    _postprocessMaterial.shader = shader;
                    return _postprocessMaterial;
                }

                _postprocessMaterial = new Material(shader);

                return _postprocessMaterial;
            }
        }

    }

    [PEGI_Inspector_Override(typeof(Terrain_BakeController))]
    internal class Terrain_BakeControllerDrawer : PEGI_Inspector_Override { }
}