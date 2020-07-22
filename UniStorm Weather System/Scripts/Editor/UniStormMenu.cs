/*
using UnityEngine;
using UnityEditor;

namespace UniStorm.Utility
{
    public class UniStormMenu : MonoBehaviour
    {
        [MenuItem("Window/UniStorm/Create UniStorm (Desktop)", false, 100)]
        static void InstantiateUniStorm()
        {
            Selection.activeObject = SceneView.currentDrawingSceneView;

            GameObject codeInstantiatedPrefab = Instantiate(Resources.Load("UniStorm System")) as GameObject;
            codeInstantiatedPrefab.name = "UniStorm System";
            codeInstantiatedPrefab.transform.position = new Vector3(0, 0, 0);
            Selection.activeGameObject = codeInstantiatedPrefab;
        }

        [MenuItem("Window/UniStorm/Create UniStorm (Mobile)", false, 100)]
        static void InstantiateUniStormMobile()
        {
            Selection.activeObject = SceneView.currentDrawingSceneView;

            GameObject codeInstantiatedPrefab = Instantiate(Resources.Load("UniStorm Mobile System")) as GameObject;
            codeInstantiatedPrefab.name = "UniStorm Mobile System";
            codeInstantiatedPrefab.transform.position = new Vector3(0, 0, 0);
            Selection.activeGameObject = codeInstantiatedPrefab;
        }

        [MenuItem("Window/UniStorm/Create UniStorm (VR)", false, 100)]
        static void InstantiateUniStormVR()
        {
            Selection.activeObject = SceneView.currentDrawingSceneView;

            GameObject codeInstantiatedPrefab = Instantiate(Resources.Load("UniStorm VR System")) as GameObject;
            codeInstantiatedPrefab.name = "UniStorm VR System";
            codeInstantiatedPrefab.transform.position = new Vector3(0, 0, 0);
            Selection.activeGameObject = codeInstantiatedPrefab;
        }



        [MenuItem("Window/UniStorm/Documentation and Tutorials", false, 200)]
        static void Documentation()
        {
            Application.OpenURL("https://github.com/Black-Horizon-Studios/UniStorm-Weather-System/wiki");
        }

        [MenuItem("Window/UniStorm/UniStorm API", false, 200)]
        static void UniStormAPI()
        {
            Application.OpenURL("https://github.com/Black-Horizon-Studios/UniStorm-Weather-System/wiki/UniStorm-API");
        }

        [MenuItem("Window/UniStorm/Contact", false, 200)]
        static void ReportABug()
        {
            Application.OpenURL("https://blackhorizonstudios.com/contact/");
        }
    }
}*/