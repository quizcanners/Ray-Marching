
using UnityEngine;

namespace QuizCanners.StampTerrain
{
    public class BakedTerrainBiomeData
    {
        public Color[] pixels;
        public Vector3 startPos;
        public Vector3 size;
        public Vector2 minMaxHeight;
        public int resolution;


        public bool TryGetPixel (Vector3 pos, out Color col) 
        {
            col = Color.clear;

            Vector3 localPosition = pos - startPos;

            Vector2 localNormalized = new(localPosition.x / size.x, localPosition.z / size.z); //.Scale(1f/size);

            if (localNormalized.x<0 || localNormalized.y<0 || localNormalized.x>=1 || localNormalized.y >= 1)
                return false;

            col = pixels[Mathf.FloorToInt(localNormalized.y * resolution) * resolution + Mathf.FloorToInt(localNormalized.x * resolution)];

            return true;
        }
    }
}