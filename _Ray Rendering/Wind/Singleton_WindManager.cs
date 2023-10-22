using QuizCanners.Inspect;
using QuizCanners.Utils;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace QuizCanners.SavageTurret
{
    public class Singleton_WindManager : Singleton.BehaniourBase
    {
        private readonly ShaderProperty.VectorValue EXPLOSION_POSITION = new("_qc_WindPush_Position");
        private readonly ShaderProperty.VectorValue EXPLOSION_DYNAMICS = new("_qc_WindPush_Dynamics");

        public Vector3 Position 
        {
            get => EXPLOSION_POSITION.latestValue;
            set => EXPLOSION_POSITION.GlobalValue = value;
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

        public void PlayExplosion(Vector3 center, float force) 
        {

        }


        #region Inspector

        public override void Inspect()
        {
            base.Inspect();
        }
        #endregion
    }

    [PEGI_Inspector_Override(typeof(Singleton_WindManager))]
    internal class Singleton_WindManagerDrawer : PEGI_Inspector_Override { }
}
