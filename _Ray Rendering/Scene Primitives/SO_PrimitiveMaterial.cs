using QuizCanners.Inspect;
using QuizCanners.Utils;
using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace QuizCanners.VolumeBakedRendering
{
    [CreateAssetMenu(fileName = FILE_NAME, menuName = QcUnity.SO_CREATE_MENU + "Ray Renderer/" + FILE_NAME)]
    public class SO_PrimitiveMaterial :  ScriptableObject, IPEGI
    {
        [SerializeField] private PrimitiveMaterial defaultMaterial = new();
        [SerializeField] internal List<MaterialPrimitiveLink> allLinks;

        public const string FILE_NAME = "Primitive Materials";

        public bool TryGetMaterial(Material material, out PrimitiveMaterial primitive) 
        {
            primitive = this[material];
            return primitive != defaultMaterial;
        }

        public PrimitiveMaterial this[Material material] 
        {
            get 
            {
                if (!material || allLinks.IsNullOrEmpty())
                    return defaultMaterial;

                var el = allLinks.FirstOrDefault(l => l.Material == material);
                
                return el!= null ? el.Primitive : defaultMaterial;
            }
        }

        public PrimitiveMaterial CreateFor(Material material) 
        {
            var newMat = new MaterialPrimitiveLink() { Material = material };
            allLinks.Add(newMat);
            this.SetToDirty();
            return newMat.Primitive;
        }

        [Serializable]
        internal class MaterialPrimitiveLink : IPEGI, IPEGI_ListInspect
        {
            public Material Material;
            public PrimitiveMaterial Primitive = new();

            void IPEGI.Inspect()
            {
                "Material".PegiLabel().Edit(ref Material).Nl();
            }

            public void InspectInList(ref int edited, int index)
            {
                pegi.Edit(ref Material);
                Primitive.InspectInList(ref edited, index);
            }
        }

        #region Inspector

        [SerializeField] private pegi.CollectionInspectorMeta _linksMeta = new pegi.CollectionInspectorMeta("Primitive Materials");

        void IPEGI.Inspect()
        {
            _linksMeta.Edit_List(allLinks).Nl();

            if (_linksMeta.IsAnyEntered == false)
            {
                "Default:".PegiLabel().Nl();
                defaultMaterial.Nested_Inspect().Nl();
            }

        }
        #endregion
    }

    [PEGI_Inspector_Override(typeof(SO_PrimitiveMaterial))] internal class SO_PrimitiveMaterialDrawer : PEGI_Inspector_Override { }
}