using PlayerAndEditorGUI;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace NodeNotes.RayTracing
{
    [CreateAssetMenu(fileName = "Ray Tracing Prefab Object", menuName = "Node Nodes/RayTracedPrefabObject", order = 0)]
    public class RayTracingPrefabObject : ScriptableObject, IPEGI
    {
        public GameObject prefab;
        public Vector3 primitiveObjectSize = Vector3.one;

        public enum PrimitiveObjectType
        {
            Box,
            Sphere,
            Pyramid
        }

        public PrimitiveObjectType primitiveType;

        public bool Inspect()
        {
            var changed = false;

            

            return changed;
        }
    }
}