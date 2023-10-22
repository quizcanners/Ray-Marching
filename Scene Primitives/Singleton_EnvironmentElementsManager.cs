using PainterTool;
using System;
using System.Collections.Generic;
using UnityEngine;

namespace QuizCanners.RayTracing
{
    using Inspect;
    using Utils;
    using static TracingPrimitives;

    [ExecuteAlways]
    [AddComponentMenu("Quiz ñ'Anners/Ray Rendering/Environment Elements")]
    public partial class Singleton_EnvironmentElementsManager : Singleton.BehaniourBase, IPEGI, IGotCount
    {
        private readonly List<CfgAndInstance> Instances = new();
        private readonly Dictionary<Shape, List<int>> _sortedRotated = new();
        private readonly Dictionary<Shape, List<int>> _sortedUnRotated = new();
        private readonly Gate.Integer _sortedInstancesVersion = new();
        private readonly Gate.Integer _volumeVersion = new();

        [NonSerialized] public int ArrangementVersion = -1;
        public void OnArrangementChanged() => ArrangementVersion++;

        public void Register(C_RayT_PrimShape_EnvironmentElement el)
        {
            Instances.Add(new CfgAndInstance(el));
            OnArrangementChanged();
        }

        public void UnRegister(C_RayT_PrimShape_EnvironmentElement el) 
        {
            OnArrangementChanged();
        }

        public C_RayT_PrimShape_EnvironmentElement GetInstanceForShape(Shape shape, bool rotated, int index)
        {
            List<int> l = GetSortedForVolume(rotated).GetOrCreate(shape);
            if (l.Count > index)
            {
                var inst = Instances.TryGet(l[index]);
                return inst?.EnvironmentElement;
            }

            return null;
        }

     
        private bool GetSorted_Internal(Shape shape, bool isRotated, out List<int> list) 
        {
            var dic = isRotated ? _sortedRotated : _sortedUnRotated;
            return dic.TryGetValue(shape, out list);
        }

        public List<CfgAndInstance> GetSortedForBox(Vector3 pos, Vector3 size, Shape shape, bool rotated) 
        {
            List<CfgAndInstance> lst = new();

            if (!GetSorted_Internal(shape, rotated, out List<int> byShapeIndexes)) //dic.TryGetValue(shape, out List<int> byShapeIndexes))
            {
                Debug.LogWarning("Sorted not found");
                return lst;
            }

            List<Pair> pairs = new();

            foreach (var ind in byShapeIndexes) 
            {
                var el = Instances[ind];

                if (!el.EnvironmentElement)
                    continue;

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

        private Dictionary<Shape, List<int>> GetSortedForVolume(bool rotated) 
        {
            var ltst = C_VolumeTexture.LatestInstance;

            bool volumeChanged = ltst && _volumeVersion.TryChange(ltst.LocationVersion);

            if (_sortedInstancesVersion.TryChange(ArrangementVersion) | volumeChanged)
            {
                UpdateLists();

                // Sort
                foreach (KeyValuePair<Shape, List<int>> pair in _sortedRotated)
                    SortList(pair.Value);

                foreach (KeyValuePair<Shape, List<int>> pair in _sortedUnRotated)
                    SortList(pair.Value);

                void SortList(List<int> sortedIndexes) 
                {
                    if (sortedIndexes.Count < 2)
                        return;

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

            return rotated ? _sortedRotated : _sortedUnRotated;


            void UpdateLists()
            {
                for (int i = Instances.Count - 1; i >= 0; i--)
                {
                    if (!Instances[i].IsValid)
                        Instances.RemoveAt(i);
                }

                // Indexes to sort
                HashSet<int> rotatedDistributionList = new();
                HashSet<int> unRotatedDistributionList = new();
                for (int i = 0; i < Instances.Count; i++)
                {
                    if (Instances[i].EnvironmentElement.Unrotated)
                        unRotatedDistributionList.Add(i);
                    else
                        rotatedDistributionList.Add(i);
                }

                Process(_sortedRotated, rotatedDistributionList, unRotated: false);

                Process(_sortedUnRotated, unRotatedDistributionList, unRotated: true);

                void Process(Dictionary<Shape, List<int>> sorted, HashSet<int> listToClear, bool unRotated)
                {
                    // Remove invalid 
                    foreach (KeyValuePair<Shape, List<int>> pair in sorted)
                        RemoveInvalidFromList(pair, listToClear);

                    foreach (int el in listToClear)
                    {
                        CfgAndInstance ins = Instances[el];
                        if (ins.IsValid)
                            sorted.GetOrCreate(ins.EnvironmentElement.Shape).Add(el);
                    }

                    void RemoveInvalidFromList(KeyValuePair<Shape, List<int>> pair, HashSet<int> listToClear)
                    {
                        List<int> list = pair.Value;

                        for (int i = list.Count - 1; i >= 0; i--)
                        {
                            int indexOfInstance = list[i];
                            CfgAndInstance el = Instances.TryGet(indexOfInstance);
                            if (el == null || !el.IsValid || el.EnvironmentElement.Shape != pair.Key || el.Unroated != unRotated)
                                list.RemoveAt(i);
                            else
                                listToClear.Remove(indexOfInstance); // to leave only ones we haven't assigned yet
                        }
                    }
                }

            }

        }


        public void Clear()
        {
            _sortedRotated.Clear();
            _sortedUnRotated.Clear();
            _sortedInstancesVersion.ValueIsDefined = false;
        }



        #region Inspector

        private Shape _debugShape = Shape.Cube;

        private readonly pegi.EnterExitContext _context = new();

        private readonly pegi.CollectionInspectorMeta _inspectedInstance = new("Instances");
        public override void Inspect()
        {
            pegi.Nl();
            using (_context.StartContext())
            {
                _inspectedInstance.Enter_List(Instances).Nl();

                if ("Sorted".PegiLabel().IsEntered().Nl()) 
                {
                    "Shape".PegiLabel().Edit_Enum(ref _debugShape).Nl();

                    List<int> rotL = GetSortedForVolume(rotated: true).GetOrCreate(_debugShape);

                    "Rotated".PegiLabel().Edit_List(rotL).Nl();

                    List<int> unRotL = GetSortedForVolume(rotated: false).GetOrCreate(_debugShape);
                    "Un Rotated".PegiLabel().Edit_List(unRotL).Nl();

                }

                /*
                if (_context.IsCurrentEntered && Instances.Count > 0 && "Clear All".PegiLabel().Click().Nl())
                {
                    Clear();
                }*/
            }
        }

        public int GetCount() => Instances.Count;


        #endregion
    }

    [PEGI_Inspector_Override(typeof(Singleton_EnvironmentElementsManager))] internal class Singleton_EnvironmentElementsManagerDrawer : PEGI_Inspector_Override { }
}
