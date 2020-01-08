using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace RayMarching
{



    
    public class RayMarchRotator : MonoBehaviour
    {

        public float speed;

        // Update is called once per frame
        void Update()
        {
            transform.Rotate(Vector3.up, speed*Time.deltaTime);
        }
    }
}