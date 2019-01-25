using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace PostProcessing
{
    [RequireComponent(typeof(Camera))]
    [ExecuteInEditMode]
    public class SimpleMultiply : MonoBehaviour
    {
        [Header("PostProcessingをかけるシェーダー")]
        public Shader shader;

        [Header("カラー")]
        public Color color = new Color(1,1,1,1);

        private Material _material;
        private Material material
        {
            get
            {
                if (_material == null)
                {
                    _material = new Material(shader);
                    // スクリプトから生成したマテリアルは保存しないようにする
                    _material.hideFlags = HideFlags.HideAndDontSave;
                }
                return _material;
            }
        }

        /// <summary>
        /// Materialの設定を行う
        /// </summary>
        private void SetMaterial()
        {
            //TODO マテリアルの設定を行う
            material.SetColor("_Color", color);
        }

        // Start is called before the first frame update
        void Start()
        {
            if (!SystemInfo.supportsImageEffects || shader == null || !shader.isSupported)
            {
                enabled = false;
                return;
            }

            SetMaterial();
        }

        private void OnRenderImage(RenderTexture source, RenderTexture destination)
        {
#if UNITY_EDITOR
            // エディターではインスペクタからの変更を反映させるためにここでmaterialを再設定する
            SetMaterial();
#endif

            Graphics.Blit(source, destination, material);
        }

        private void OnDestroy()
        {
            if (_material) { Destroy(_material); }
        }
    }
}