using PainterTool;
using QuizCanners.Inspect;
using QuizCanners.Migration;
using QuizCanners.Utils;
using System;
using System.Collections.Generic;
using UnityEngine;
using static QuizCanners.RayTracing.QcRTX;

namespace QuizCanners.RayTracing
{
    [ExecuteAlways]
    public partial class Singleton_EnvironmentElementsManager : Singleton.BehaniourBase, IPEGI, IGotCount
    {
        private List<CfgAndInstance> Instances = new();
        private readonly Dictionary<Shape, List<int>> _sorted = new();
        private readonly Gate.Integer _sortedInstancesVersion = new();
        private readonly Gate.Integer _volumeVersion = new();

        [NonSerialized] public int ArrangementVersion = -1;
        public void OnArrangementChanged() => ArrangementVersion++;


        public void Register(C_RayT_PrimShape_EnvironmentElement el)
        {
            Instances.Add(new CfgAndInstance(el));
            OnArrangementChanged();
        }

        public C_RayT_PrimShape_EnvironmentElement GetInstanceForShape(Shape shape, int index)
        {
            List<int> l = GetSortedForVolume().GetOrCreate(shape);
            if (l.Count > index)
            {
                var inst = Instances.TryGet(l[index]);
                return inst == null ? null : inst.EnvironmentElement;
            }

            return null;
        }

     
        public List<CfgAndInstance> GetSortedForBox(Vector3 pos, Vector3 size, Shape shape) 
        {
            List<CfgAndInstance> lst = new List<CfgAndInstance>();

            List<int> byShapeIndexes = _sorted[shape];

            List<Pair> pairs = new List<Pair>();

            foreach (var ind in byShapeIndexes) 
            {
                var el = Instances[ind];
                var overlap = el.GetOverlap(pos, size);
                if (overlap > 0) 
                {
                    pairs.Add(new Pair() { cfg = el, overlap = overlap });
                }
            }

            pairs.Sort((a, b) => Mathf.FloorToInt((b.overlap - a.overlap)*100));

            foreach (var p in pairs)
                lst.Add(p.cfg);

            return lst;
        }

        struct Pair
        {   
            public CfgAndInstance cfg;
            public float overlap;
        }

        private Dictionary<Shape, List<int>> GetSortedForVolume() 
        {
            var ltst = C_VolumeTexture.LatestInstance;

            if (_sortedInstancesVersion.TryChange(ArrangementVersion) | (ltst &&_volumeVersion.TryChange(ltst.LocationVersion)))
            {
                CheckCollection();

                // Sort
                foreach (var pair in _sorted)
                {
                    List<int> sortedIndexes = pair.Value;
                    if (sortedIndexes.Count < 2)
                        continue;

                    bool dirty = true;

                    while (dirty)
                    {
                        dirty = false;

                        for (int i = 0; i < sortedIndexes.Count - 1; i++)
                        {
                            var sortedIndexA = sortedIndexes[i];
                            var sortedIndexB = sortedIndexes[i + 1];

                            if (Instances[sortedIndexB].VolumeWeight > Instances[sortedIndexA].VolumeWeight)
                            {
                                dirty = true;
                                sortedIndexes[i] = sortedIndexB;
                                sortedIndexes[i + 1] = sortedIndexA;
                            }
                        }
                    }
                }
            }

            return _sorted;
        }

        private void CheckCollection()
        {
            // Indexes to sort
            HashSet<int> distributionList = new();
            for (int i = 0; i < Instances.Count; i++)
                distributionList.Add(i);

            // Remove invalid 
            foreach (var pair in _sorted)
            {
                var list = pair.Value;

                for (int i = list.Count - 1; i >= 0; i--)
                {
                    var indexOfInstance = list[i];
                    CfgAndInstance el = Instances.TryGet(indexOfInstance);
                    if (el == null || !el.UsePrimitive || el.EnvironmentElement.Shape != pair.Key)
                        list.RemoveAt(i);
                    else
                        distributionList.Remove(indexOfInstance); // to leave only ones we haven't assigned yet
                }
            }

            // Add Unsorted
            foreach (var el in distributionList)
            {
                CfgAndInstance ins = Instances[el];
                if (ins.UsePrimitive)
                    _sorted.GetOrCreate(ins.EnvironmentElement.Shape).Add(el);
            }
        }

        public void Clear()
        {
            foreach (var el in Instances)
                el.Destroy();

            Instances.Clear();
            _sorted.Clear();
            _sortedInstancesVersion.ValueIsDefined = false;
        }



        #region Inspector

        private readonly pegi.EnterExitContext _context = new();

        private readonly pegi.CollectionInspectorMeta _inspectedInstance = new("Instances");
        public override void Inspect()
        {
            pegi.Nl();
            using (_context.StartContext())
            {
                _inspectedInstance.Enter_List(Instances).Nl();

                if (_context.IsCurrentEntered && Instances.Count > 0 && "Clear All".PegiLabel().Click().Nl())
                {
                    Clear();
                }
            }
        }

        public int GetCount() => Instances.Count;


        #endregion
    }

    [PEGI_Inspector_Override(typeof(Singleton_EnvironmentElementsManager))] internal class Singleton_EnvironmentElementsManagerDrawer : PEGI_Inspector_Override { }
}
