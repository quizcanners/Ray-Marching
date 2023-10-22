
namespace QuizCanners.RayTracing
{

    using Inspect;
    using UnityEngine;
    using Utils;

    public class Singleton_ReflectionProbe : Singleton.BehaniourBase
    {
        [SerializeField] private ReflectionProbe _probe;

        #region Inspector

        public override void Inspect()
        {
            base.Inspect();

            "Probe".PegiLabel(60).Edit_IfNull(ref _probe, gameObject).Nl();

            

        }
        #endregion

    }

    [PEGI_Inspector_Override(typeof(Singleton_ReflectionProbe))]
    internal class Singleton_ReflectionProbeDrawer : PEGI_Inspector_Override { }
}