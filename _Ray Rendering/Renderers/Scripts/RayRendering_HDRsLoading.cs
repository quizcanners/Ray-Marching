using System.Collections.Generic;
using UnityEngine;
using QuizCanners.Inspect;
using System;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;
using QuizCanners.Utils;

namespace QuizCanners.RayTracing
{

    [CreateAssetMenu(fileName = FILE_NAME, menuName = QcUnity.SO_CREATE_MENU + "Ray Renderer/" + FILE_NAME)]
    public class SO_HDRsLoading : ScriptableObject, IPEGI
    {
        public const string FILE_NAME = "HDR Boxes";

        [SerializeField] private List<HDRBox> _hdrs = new();

        private bool _loading;
        private string _targetHDR;

        private static readonly ShaderProperty.TextureValue QC_SKY_BOX = new("Qc_SkyBox");

        public static Texture SkyBox
        {
            get => QC_SKY_BOX.latestValue;
            set
            {
                QC_SKY_BOX.GlobalValue = value;
            }
        }

        public string CurrentHDR 
        {
            get => _targetHDR;
            set
            {
                _targetHDR = value;
                _loading = true;
            }
        }

        public void ManagedUpdate() 
        {
            if (!_loading)
                return;

            try
            {
             //   bool any = false;
                foreach (var h in _hdrs)
                {
                    if (h.name.Equals(_targetHDR))
                    {
                        h.TryGet(out _, out _);
                       // any = true;
                    }
                    else
                        h.Unload();
                }

                SkyBox = null;
            } catch (Exception ex) 
            {
                Debug.LogException(ex);
            }

            _loading = false;
        }

        public pegi.ChangesToken InspectSelect() 
        {
            var changes = pegi.ChangeTrackStart();
            Icon.Clear.Click(() => CurrentHDR = "");
            if (pegi.Select_iGotName(ref _targetHDR, _hdrs)) 
            {
                CurrentHDR = _targetHDR;
            }

            return changes;
        }

        private static SO_HDRsLoading inspected;
        public void Inspect()
        {
            inspected = this;

            InspectSelect().Nl();

            "HDRS".PegiLabel().Edit_List(_hdrs).Nl();
        }


        [Serializable]
        private class HDRBox : IPEGI_ListInspect, ISerializationCallbackReceiver, IGotName
        {
            public string name = "Unnamed";
            public AssetReference reference;
            private Texture _cachedAsset;
            [NonSerialized] private State _state;

            public string NameForInspector { get => name; set => name = value; }

            private enum State { Uninitialized, Loading, Loaded, FailedToLoad }

            public bool TryGet(out Texture tex, out bool failed)
            {
                tex = null;
                failed = false;

                switch (_state)
                {
                    case State.Loaded: tex = _cachedAsset; return true;
                    case State.FailedToLoad: failed = true; return false;
                    case State.Loading: return false;
                    case State.Uninitialized:
                        try
                        {
                            AsyncOperationHandle handle = reference.LoadAssetAsync<Texture>();
                            handle.Completed += Handle_Completed;
                            _state = State.Loading;
                            return false;
                        }
                        catch (Exception ex)
                        {
                            Debug.LogException(ex);
                            _state = State.FailedToLoad;
                            failed = true;
                            return false;
                        }
                    default: Debug.LogError("Unimpleented case: " + _state); return false;
                }
            }

            // Instantiate the loaded prefab on complete
            private void Handle_Completed(AsyncOperationHandle obj)
            {
                if (obj.Status == AsyncOperationStatus.Succeeded)
                {
                    _cachedAsset = reference.Asset as Texture;
                    if (_cachedAsset)
                    {
                        _state = State.Loaded;
                        SkyBox = _cachedAsset;
                    }
                    else
                    {
                        _state = State.FailedToLoad;
                    }
                }
                else
                {
                    Debug.LogError($"AssetReference {reference.RuntimeKey} failed to load.");
                    _state = State.FailedToLoad;
                }
            }

            // Release asset when parent object is destroyed
            public void Unload()
            {
                if (_state == State.Uninitialized)
                    return;

                _state = State.Uninitialized;
                if (reference != null)
                {
                    reference.ReleaseAsset();
                    _cachedAsset = null;
                }
               
            }

            #region Inspector
            public override string ToString() => name;

            public void InspectInList(ref int edited, int index)
            {
                if (_cachedAsset)
                    pegi.Edit(ref _cachedAsset);

                "Adressable".PegiLabel(60).Edit_Property(
                    () => reference,
                    nameof(_hdrs),
                    inspected);

                if (reference == null || reference.AssetGUID.IsNullOrEmpty())
                {
                    return;
                } else 
                {
                    Icon.Delete.ClickConfirm(confirmationTag: "Del").OnChanged(() => reference = null);
                }
                
                pegi.Edit(ref name);

                switch (_state)
                {
                    case State.Loaded:
                        if (Icon.Clear.Click())
                            Unload();
                        pegi.Nl();
                        pegi.Draw(_cachedAsset, Screen.width).Nl();
                      
                        break;
                    case State.Uninitialized: if (Icon.Download.Click()) TryGet(out _, out _); break;
                    case State.FailedToLoad: if (Icon.Refresh.Click()) _state = State.Uninitialized; break;
                    case State.Loading: Icon.Wait.Draw("Loading"); break;
                    default: break;
                }
            }

            public void OnBeforeSerialize()
            {
                Unload();
            }

            public void OnAfterDeserialize()
            {
                _state = State.Uninitialized;
            }

            #endregion
        }

    }

}
