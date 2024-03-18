using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{

    [DisallowMultipleComponent]
    [ExecuteInEditMode]
    [AddComponentMenu(QcUtils.QUIZCANNERS + "/PrimitiveTracing/Scene Prefab/Dynamic Primitive Root")]
    public class C_RayT_PrimitiveRoot : MonoBehaviour, IPEGI
    {
        [NonSerialized] private C_RayT_PrimShape[] _primShapes;
       
        private readonly Gate.Vector3Value _positionGate = new();
        private readonly Gate.QuaternionValue _rotationGate = new();
        
        private int _version;

        public int Version 
        {
            get 
            {
                if (_positionGate.TryChange(transform.position) || _rotationGate.TryChange(transform.rotation))
                    _version++;

                return _version;
            }
        }


        #region Inspector
        public void Inspect()
        {
            "Version: {0}".F(Version).PegiLabel().Nl();

            if ("Set on all children".PegiLabel().Click().Nl()) 
            {
                _primShapes = GetComponentsInChildren<C_RayT_PrimShape>();

                foreach (var s in _primShapes) 
                {
                    s.RootParent = this;
                }
            }

            if (_primShapes!= null)
                "List".PegiLabel().Edit_Array(ref _primShapes).Nl();
        }
        #endregion
    }

    [PEGI_Inspector_Override(typeof(C_RayT_PrimitiveRoot))] internal class C_RayT_PrimitiveRootDrawer : PEGI_Inspector_Override { }

}