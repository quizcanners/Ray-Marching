/*

using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine.SceneManagement;

namespace UniStorm.Utility
{

    
    [CustomEditor(typeof(CloudProfile))]
    [System.Serializable]
    public class CloudProfileEditor : Editor
    {
        Texture CloudProfileIcon;
        Texture HelpIcon;

        private void OnEnable()
        {
            if (CloudProfileIcon == null) CloudProfileIcon = Resources.Load("CloudProfileIcon") as Texture;
            if (HelpIcon == null) HelpIcon = Resources.Load("HelpIcon") as Texture;
        }

        public override void OnInspectorGUI()
        {
            CloudProfile self = (CloudProfile)target;

            GUIStyle TitleStyle = new GUIStyle(EditorStyles.toolbarButton);
            TitleStyle.fontStyle = FontStyle.Bold;
            TitleStyle.fontSize = 14;
            TitleStyle.alignment = TextAnchor.UpperCenter;
            TitleStyle.normal.textColor = Color.white;

            var HelpStyle = new GUIStyle(EditorStyles.boldLabel) { alignment = TextAnchor.UpperRight };

            EditorGUILayout.BeginVertical("Box");
            EditorGUILayout.BeginHorizontal();
            GUILayout.FlexibleSpace();

            EditorGUILayout.BeginVertical(GUILayout.Width(90 * Screen.width / 100));
            var style = new GUIStyle(EditorStyles.boldLabel) { alignment = TextAnchor.MiddleCenter };

            if (GUILayout.Button(new GUIContent(HelpIcon), HelpStyle, GUILayout.ExpandWidth(true), GUILayout.Height(22.5f)))
            {
                Application.OpenURL("https://github.com/Black-Horizon-Studios/UniStorm-Weather-System/wiki/Creating-a-Custom-Cloud-Profile#creating-a-custom-cloud-profile");
            }

            GUI.backgroundColor = new Color(0.25f, 0.25f, 0.25f, 0.5f);
            EditorGUILayout.LabelField("Cloud Profile", TitleStyle);
            GUI.backgroundColor = Color.white;
            GUI.backgroundColor = new Color(0.1f, 0.1f, 0.1f, 0.19f);
            EditorGUILayout.LabelField("Cloud Profiles allow you to customize the appearance of the clouds. These can be used for each Weather Type to create multiple " +
                "variants and make each Weather Type unique. Cloud Profiles can only be used with volumetric clouds.", EditorStyles.helpBox);
            GUI.backgroundColor = Color.white;
            EditorGUILayout.Space();
            GUILayout.Space(2);
            EditorGUILayout.LabelField(new GUIContent(CloudProfileIcon), style, GUILayout.ExpandWidth(true), GUILayout.Height(64));

            GUILayout.Space(4);
            EditorGUILayout.EndVertical();
            GUILayout.FlexibleSpace();
            EditorGUILayout.EndHorizontal();
            EditorGUILayout.EndVertical();

            EditorGUILayout.BeginVertical("Box");

            GUI.backgroundColor = new Color(0.25f, 0.25f, 0.25f, 0.5f);
            EditorGUILayout.LabelField("Settings", TitleStyle);
            GUI.backgroundColor = Color.white;
            EditorGUILayout.Space();

            self.EdgeSoftness = EditorGUILayout.Slider("Edge Softness", self.EdgeSoftness, 0.001f, 0.5f);
            GUI.backgroundColor = new Color(0.1f, 0.1f, 0.1f, 0.19f);
            EditorGUILayout.LabelField("Controls the edge softness of UniStorm's clouds for this profile.", EditorStyles.helpBox);
            GUI.backgroundColor = Color.white;
            EditorGUILayout.Space();

            self.BaseSoftness = EditorGUILayout.Slider("Base Softness", self.BaseSoftness, 0.02f, 2);
            GUI.backgroundColor = new Color(0.1f, 0.1f, 0.1f, 0.19f);
            EditorGUILayout.LabelField("Controls the base/bottom softness of UniStorm's clouds for this profile.", EditorStyles.helpBox);
            GUI.backgroundColor = Color.white;
            EditorGUILayout.Space();

            self.DetailStrength = EditorGUILayout.Slider("Detail Strength", self.DetailStrength, 0.02f, 0.2f);
            GUI.backgroundColor = new Color(0.1f, 0.1f, 0.1f, 0.19f);
            EditorGUILayout.LabelField("Controls the detail strength of UniStorm's clouds for this profile.", EditorStyles.helpBox);
            GUI.backgroundColor = Color.white;
            EditorGUILayout.Space();

            self.Density = EditorGUILayout.Slider("Density", self.Density, 0.1f, 1);
            GUI.backgroundColor = new Color(0.1f, 0.1f, 0.1f, 0.19f);
            EditorGUILayout.LabelField("Controls the density of UniStorm's clouds for this profile.", EditorStyles.helpBox);
            GUI.backgroundColor = Color.white;
            EditorGUILayout.Space();

            self.CoverageBias = EditorGUILayout.Slider("Coverage Bias", self.CoverageBias, -0.05f, 0.1f);
            GUI.backgroundColor = new Color(0.1f, 0.1f, 0.1f, 0.19f);
            EditorGUILayout.LabelField("Controls the Coverage Bias of UniStorm's clouds for this profile. This is useful if the cloud clover is too full or not enough.", EditorStyles.helpBox);
            GUI.backgroundColor = Color.white;
            EditorGUILayout.Space();

            EditorGUILayout.EndVertical();

#if UNITY_EDITOR
            if (!Application.isPlaying)
            {
                Undo.RecordObject(self, "Undo");

                if (GUI.changed)
                {
                    EditorUtility.SetDirty(target);
                    EditorSceneManager.MarkSceneDirty(SceneManager.GetActiveScene());
                }
            }
#endif
        }
    }
}*/