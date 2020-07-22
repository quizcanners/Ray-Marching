using UnityEngine;

namespace QuizCanners.RayTracing
{
    [DisallowMultipleComponent]
    public class C_RotationLock : MonoBehaviour
    {
        [SerializeField] private Vector3 _goalValue;

        private Quaternion rotationQ;

        void Start()
        {
            rotationQ = Quaternion.Euler(_goalValue);
        }

      
        void Update()
        {
            transform.rotation = rotationQ;
        }
    }
}
