using System.Collections.Generic;
using UnityEngine;
using QuizCanners.Inspect;
using System;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;
using QuizCanners.Utils;

namespace QuizCanners.VolumeBakedRendering
{

    [CreateAssetMenu(fileName = FILE_NAME, menuName = QcUnity.SO_CREATE_MENU + "Ray Renderer/" + FILE_NAME)]
    public class SO_HDRsLoading : ScriptableObject, IPEGI
    {
        public const string FILE_NAME = "HDR Boxes";

        [SerializeField] private List<HDRBox> _hdrs = new();


        private static readonly ShaderProperty.TextureValue QC_SKY_BOX = new("Qc_SkyBox");

        public static Texture SkyBox
        {
            get => QC_SKY_BOX.latestValue;
            set
            {
                QC_SKY_BOX.GlobalValue = value;
            }
        }

        public string CurrentHDR;

        private State _state;
        private enum State { Undefined, LoadngNew, Loaded, Error }
        private readonly Gate.String _hdrVersion = new();
        private HDRBox currentlyLoading;


        public void ManagedUpdate() 
        {
            switch (_state) 
            {
                case State.Error:
                case State.Loaded:
                case State.Undefined: 
                    if (_hdrVersion.TryChange(CurrentHDR)) 
                    {
                        if (CurrentHDR.IsNullOrEmpty()) 
                        {
                            foreach (HDRBox h in _hdrs)
                                h.Unload();
                        }

                        foreach (HDRBox h in _hdrs)
                        {
                            if (h.name.Equals(CurrentHDR))
                            {
                                currentlyLoading = h;
                                currentlyLoading.TryGet(out _, out var error);
                                if (!error) 
                                    _state = State.LoadngNew;

                                break;
                            }
                        }
                    }
                    break;
                case State.LoadngNew:
                    try
                    {
                        if (currentlyLoading.TryGet(out var tex, out var error))
                        {
                            _state = State.Loaded;
                            SkyBox = tex;
                            foreach (var h in _hdrs)
                                if (h != currentlyLoading)
                                    h.Unload();
                        }

                        if (error)
                            _state = State.Error;
                    }
                    catch (Exception ex)
                    {
                        Debug.LogException(ex);
                        _state = State.Error;
                    }
                    break;
            }
        }

        #region Inspector

        public pegi.ChangesToken InspectSelect() 
        {
            var changes = pegi.ChangeTrackStart();
            Icon.Clear.Click(() => CurrentHDR = "");
            pegi.Select_iGotName(ref CurrentHDR, _hdrs);
            
            return changes;
        }

        private static SO_HDRsLoading inspected;
        void IPEGI.Inspect()
        {
            inspected = this;
            InspectSelect().Nl();
            "HDRS".PegiLabel().Edit_List(_hdrs).Nl();
        }

        #endregion

        internal void ManagedOnDisable()
        {
            foreach (var h in _hdrs)
                h.Unload();
        }

        [Serializable]
        private class HDRBox : IPEGI_ListInspect, IGotName
        {
            public string name = "Unnamed";
            public AssetReference reference;
            [NonSerialized] private State _state;

           // AsyncOperationHandle<Texture> _handle;

            public string NameForInspector { get => name; set => name = value; }

            private enum State { Uninitialized, Loading, Loaded, FailedToLoad }

            public bool TryGet(out Texture tex, out bool failed)
            {
                tex = null;
                failed = false;

                switch (_state)
                {
                    case State.Loaded: tex = reference.OperationHandle.Result as Texture; return true;
                    case State.FailedToLoad: failed = true; return false;
                    case State.Loading: 
                        
                        if (reference.OperationHandle.IsDone) 
                        {
                            if (reference.OperationHandle.Status == AsyncOperationStatus.Succeeded) 
                            {
                                _state = State.Loaded;
                                tex = reference.OperationHandle.Result as Texture;
                                
                                return true;
                            } else 
                            {
                                Debug.LogError("HDR loading failed");
                                _state = State.FailedToLoad;
                            }
                        }
                        
                        return false;
                    case State.Uninitialized:
                        try
                        {
                            reference.LoadAssetAsync<Texture>();
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


            // Release asset when parent object is destroyed
            public void Unload()
            {
                try
                {
                    switch (_state)
                    {
                        case State.Uninitialized:
                            return;
                        case State.Loading:
                            _state = State.Uninitialized;
                            Addressables.Release(reference.OperationHandle);
                            return;
                        case State.Loaded:
                            Addressables.Release(reference.OperationHandle);
                            _state = State.Uninitialized;
                            return;
                    }
                } catch(Exception ex) 
                {
                    Debug.LogException(ex);
                }
                     
            }

            #region Inspector
            public override string ToString() => name;

            public void InspectInList(ref int edited, int index)
            {
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

                _state.ToString().PegiLabel().Write();

                switch (_state)
                {
                    case State.Loaded:
                        if (Icon.Clear.Click())
                            Unload();
                        pegi.Nl();
                        pegi.Draw(reference.OperationHandle.Result as Texture, Screen.width).Nl();

                        break;
                    case State.Uninitialized: if (Icon.Download.Click()) TryGet(out _, out _); break;
                    case State.FailedToLoad: if (Icon.Refresh.Click()) _state = State.Uninitialized; break;
                    case State.Loading: Icon.Wait.Draw("Loading"); break;
                    default: break;
                }
            }

            #endregion
        }
    }
}
