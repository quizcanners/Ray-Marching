using QuizCanners.Utils;
using UnityEngine;
using static QuizCanners.StampTerrain.TerrainBaking;

namespace QuizCanners.StampTerrain
{
    [SelectionBase]
    [ExecuteAlways]
    /// <summary>
    /// A component that should be attached to all the stamp GameObjects in the scene.
    /// </summary>
    public class TerrainStampComponent : MonoBehaviour
    {
        [SerializeField] private MeshRenderer _renderer;
        public Stamps.VisiblePriority Priority;
        public Stamps.BakingMode BakingMode;

        public int bakedForVersion;
        public int batchIndex;


        // public string _pushedUpReason;

        private readonly Gate.Vector3Value _positionGate = new();
        private readonly Gate.Vector3Value _sizeGate = new();
        private readonly Gate.QuaternionValue _rotationGate = new();
        private readonly Gate.Integer _syblingIndex = new();

        public BoundsTopDown GetBounds() => new(_renderer.bounds, priority: Priority, siblingIndex: transform.GetSiblingIndex());

       
        /// <summary>
        /// We only hide the stamp from rendering, as the stamp should remain registered.
        /// </summary>
        public bool IsVisible 
        {
            get => _renderer.enabled;
            set => _renderer.enabled = value;
        }

        /// <summary>
        /// 
        /// </summary>
        private void Reset()
        {
            _renderer = GetComponent<MeshRenderer>();   
        }

        /// <summary>
        /// 
        /// </summary>
        void OnEnable() 
        {
            Stamps.s_activeStamps.Add(this);
            Stamps.SetDirty(); 
        }

        /// <summary>
        /// 
        /// </summary>
        void OnDisable() 
        {
            var list = Stamps.s_activeStamps;
            list.Remove(this);

            Stamps.SetDirty();

#if UNITY_EDITOR
            if (Application.isPlaying)
                return;

            for (int i= list.Count-1; i>=0; i--) 
            {
                if (list[i])
                    continue;

                Debug.LogWarning("One Layer was not cleared");

                list.RemoveAt(i);
            }
#endif
        }

        public void OnBaked() 
        {
            _positionGate.TryChange(transform.position);
            _rotationGate.TryChange(transform.rotation);
            _sizeGate.TryChange(transform.lossyScale);
            _syblingIndex.TryChange(transform.GetSiblingIndex());
        }
        
        public void ManagedCheck() 
        {
            if (_positionGate.TryChange(transform.position))
                TerrainBaking.Stamps.SetDirty();

            if (_rotationGate.TryChange(transform.rotation))
                TerrainBaking.Stamps.SetDirty();

            if (_sizeGate.TryChange(transform.lossyScale))
                TerrainBaking.Stamps.SetDirty();

            if (_syblingIndex.TryChange(transform.GetSiblingIndex()))
                TerrainBaking.Stamps.SetDirty();
        }
    }
}
