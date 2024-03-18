using System;
using UnityEngine;

namespace QuizCanners.StampTerrain
{
    [Serializable]
    /// <summary>
    /// Composition class that is used by Terrain Manager to generate Unity Terrain using data created from Stamp baking process.
    /// </summary>
    public class Terrain_ToUnityController
    {
        [SerializeField] private UnityEngine.Terrain _instance;
        [SerializeField] private TerrainCollider _terrainCollider;
        [SerializeField] private Material _material;
        [SerializeField] private uint _renderingLayer;


        public float GetHeight(Vector3 position) => _instance.SampleHeight(position) + _instance.GetPosition().y;
        public Vector3 GetNormal(Vector3 position)
        {
            position -= _instance.transform.position; // To Terrain space
            Vector3 terrainSize = _instance.terrainData.size;
            float x = position.x / terrainSize.x;
            float z = position.z / terrainSize.z;
            return _instance.terrainData.GetInterpolatedNormal(x,z); //.Nor(position) + _instance.GetPosition().y;
        }
        public void CreateFromAlpha(Color[] pixels, int resolution, Vector3 position, Vector3 size, float minHeight, float maxHeight) 
        {
            if (!_instance && !_material)
            {
                Debug.Log("No material. Not creating Unity Terrain");
                return;
            }

            TerrainData terrainData = null; 

            if (_instance) 
            {
                terrainData = _instance.terrainData;
            } 
            
            if (terrainData == null)
            {
                terrainData = new TerrainData()
                {
                    
                };
            }

            terrainData.heightmapResolution = resolution;
            terrainData.size = new Vector3(size.x, maxHeight - minHeight, size.z);

            float[,] height = new float[resolution,resolution];

            for (int z = 0; z < resolution; z++)
            {
               // float zUv = ((float)z) / (float)resolution;
                for (int x = 0; x < resolution; x++)
                {
                   // float xUv = ((float)x) / (float)resolution;
                    height[z, x] = pixels[z * resolution + x].a;// * GetAlphaToHideForUvBorders(xUv, zUv); // * to01;
                }
            }

            /*
            float GetAlphaToHideForUvBorders(float frac, float zfrac)
            {
                frac -= 0.5f;
                zfrac -= 0.5f;
                frac *= frac;
                zfrac *= zfrac;
               
                float len = frac * frac + zfrac * zfrac;
                return Mathf.SmoothStep(0.0625f, 0.04f, len);
            }
            */

            terrainData.SetHeights(0, 0, height);

            if (!_instance)
            {
                _instance = UnityEngine.Terrain.CreateTerrainGameObject(terrainData).GetComponent<UnityEngine.Terrain>();
                _instance.renderingLayerMask = _renderingLayer;
                _instance.materialTemplate = _material;
            } else
            {
                _instance.terrainData = terrainData;
            }

            if (!_terrainCollider)
                _terrainCollider = _instance.GetComponent<UnityEngine.TerrainCollider>();

            if (_terrainCollider)
                _terrainCollider.terrainData = terrainData;


            position.y = minHeight;
            _instance.transform.position = position;

        }


        public void OnDisable() 
        {

        }
    }
}
