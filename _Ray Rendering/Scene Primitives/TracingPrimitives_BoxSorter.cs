using System.Collections.Generic;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    public static partial class TracingPrimitives
    {
        public class PrimitivesForBoxSorter
        {
            private readonly List<CfgAndInstance> _sortedUnRotated;
            private readonly List<CfgAndInstance> _sortedRotated; 
            private int _currentUnRotated = 0;
            private int _currentRotated = 0;
            private bool _prioratizeHigherElements;

            public bool TryGetElement(out C_RayT_PrimShape el) 
            {
                if (_currentRotated < _sortedRotated.Count)
                {
                    CfgAndInstance rot = _sortedRotated[_currentRotated];

                    if (_currentUnRotated < _sortedUnRotated.Count)
                    {
                        var unRot = _sortedUnRotated[_currentUnRotated];

                        if (rot.LatestOverlapCheck > unRot.LatestOverlapCheck)
                        {
                            el = rot.EnvironmentElement;
                            _currentRotated++;
                            return true;
                        }
                      
                        el = unRot.EnvironmentElement;
                        _currentUnRotated++;
                        return true;
                    }

                    el = rot.EnvironmentElement;
                    _currentRotated++;
                    return true;
                }

                if (_currentUnRotated < _sortedUnRotated.Count)
                {
                    el = _sortedUnRotated[_currentUnRotated].EnvironmentElement;
                    _currentUnRotated++;
                    return true;
                }

                el = null;
                return false;
            }

            public PrimitivesForBoxSorter(Vector3 center, Vector3 size, bool prioratizeHigherElements) 
            {
                _prioratizeHigherElements = prioratizeHigherElements;
                var mgmt = s_EnvironmentElements;
                _sortedUnRotated = mgmt.GetSortedForBox(center, size, Shape.Cube, rotated: false, prioratizeHigher: _prioratizeHigherElements);
                _sortedRotated = mgmt.GetSortedForBox(center, size, Shape.Cube, rotated: true, prioratizeHigher: _prioratizeHigherElements);
            }
        }
    }
}
