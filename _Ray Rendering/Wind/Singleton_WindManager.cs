using QuizCanners.Inspect;
using QuizCanners.Utils;
using UnityEngine;

namespace QuizCanners.SavageTurret
{
    public class Singleton_WindManager : Singleton.BehaniourBase
    {
        private readonly ShaderProperty.VectorValue WIND_DIRECTION = new("qc_WindDirection");
        private readonly ShaderProperty.VectorValue WIND_PARAMETERS = new("qc_WindParameters");
        private readonly ShaderProperty.VectorValue WIND_PUSH_POSITION = new("_qc_WindPush_Position");
        private readonly ShaderProperty.VectorValue EXPLOSION_DYNAMICS = new("_qc_WindPush_Dynamics");

        public Vector3 Position 
        {
            get => WIND_PUSH_POSITION.latestValue;
            set => WIND_PUSH_POSITION.GlobalValue = value;
        }

        public float Force
        {
            get => EXPLOSION_DYNAMICS.latestValue.x;
            set => EXPLOSION_DYNAMICS.GlobalValue = EXPLOSION_DYNAMICS.latestValue.X(value);
        }

        public float Radius
        {
            get => EXPLOSION_DYNAMICS.latestValue.y;
            set => EXPLOSION_DYNAMICS.GlobalValue = EXPLOSION_DYNAMICS.latestValue.Y(value);
        }

        public Vector3 Direction
        {
            get => WIND_DIRECTION.latestValue;
            set => WIND_DIRECTION.SetGlobal(value.ToVector4(WIND_DIRECTION.latestValue.w));
        }

        public float WindFrequency 
        {
            get => WIND_PARAMETERS.latestValue.x;
            set => WIND_PARAMETERS.GlobalValue = WIND_PARAMETERS.latestValue.X(value);
        }

        public void PlayExplosion(Vector3 center, float force) 
        {

        }

        protected override void OnAfterEnable()
        {
            base.OnAfterEnable();

            Direction = Vector3.forward;
            WindFrequency = 30f;
        }

        #region Inspector

        public override void Inspect()
        {
            var dir = Direction;
            "Direction".PegiLabel().Edit(ref dir).Nl(()=> Direction = dir );

            float frq = WindFrequency;
            "Frequancy".PegiLabel().Edit(ref frq).Nl(() => WindFrequency = frq );

        }
        #endregion
    }

    [PEGI_Inspector_Override(typeof(Singleton_WindManager))]
    internal class Singleton_WindManagerDrawer : PEGI_Inspector_Override { }
}
