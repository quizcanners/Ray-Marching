﻿using UnityEngine;

namespace QuizCanners.RayTracing
{



    
    public class RayMarchRotator : MonoBehaviour
    {

        public float speed;

        // Update is called once per frame
        private void Update()
        {
            transform.Rotate(Vector3.up, speed*Time.deltaTime);
        }
    }
}