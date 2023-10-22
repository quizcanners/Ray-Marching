using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.SavageTurret
{
    public class Singleton_PointLightTraced : Singleton.BehaniourBase
    {
        private readonly ShaderProperty.VectorValue POSITION = new("_qc_PointLight_Position");
        private readonly ShaderProperty.ColorValue COLOR = new("_qc_PointLight_Color", Color.clear);

        private bool _isAnimating;
        private float _currentFramePriority;
        private int _framesLeft;
        private int _totalFrames;
        private Color targetColor;

        private readonly Gate.Frame _frameDuration = new();

        [SerializeField] private Transform _testPoint;
        private readonly Gate.Vector3Value _testPosition = new();

        private bool Visible 
        {
            get
            {
                CheckIsVisible();
                return COLOR.GlobalValue.a > 0;
            }
            set => COLOR.GlobalValue = COLOR.GlobalValue.Alpha(value ? 1 : 0);
        }

        private void CheckIsVisible() 
        {
            if (!_isAnimating)
                return;

            if (!_frameDuration.TryEnter())
                return;
                
            _framesLeft--;

            if (_framesLeft < 1)
            {
                _isAnimating = false;
                _currentFramePriority = 0;
                Visible = false;
                return;
            }
          
            COLOR.GlobalValue = targetColor * ((float)_framesLeft)/(_totalFrames + 1);
        }

        public bool TryPlay(Vector3 position, Color color, float brightness = 1, float priority = 1, int frames = 1 ) 
        {
            CheckIsVisible();

            if (_currentFramePriority > priority)
                return false;

            if (_currentFramePriority == priority && frames == _framesLeft)
                return false;

            _totalFrames = frames;
            _framesLeft = frames;
            POSITION.GlobalValue = position; //.Y(Mathf.Max(0.1f, position.y));

            targetColor = color * brightness;
            COLOR.GlobalValue = targetColor;
            _isAnimating = true;
            _frameDuration.TryEnter();

            return true;
        }

        private void Update()
        {
            CheckIsVisible();

            if (!_testPoint)
                return;

            if (_testPosition.TryChange(_testPoint.position))
            {
                POSITION.GlobalValue = _testPoint.position;
            }
        }

        #region Inspector
        public override void Inspect()
        {
            base.Inspect();

            var isVisible = Visible;

            "Visible".PegiLabel().ToggleIcon(ref isVisible).Nl(() => Visible = isVisible);

            "Test".PegiLabel().Edit(ref _testPoint).Nl();

            var changed = pegi.ChangeTrackStart();

            COLOR.Nested_Inspect();

            if (changed) 
            {
                COLOR.SetGlobal();
            }
        }

        #endregion
    }

    [PEGI_Inspector_Override(typeof(Singleton_PointLightTraced))]
    internal class Singleton_PointLightTracedDrawer : PEGI_Inspector_Override { }
}
