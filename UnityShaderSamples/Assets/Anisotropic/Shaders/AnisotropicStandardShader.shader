Shader "Anisotropic/AnisotropicStandardShader" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_NormalMap("Normal", 2D) = "bump" {}
		_Glossiness("Smoothness", Range(0,1)) = 0.5
		_Anisotropy ("Anisotropy", Range(-1,1)) = 0
		_Metallic ("Metallic", Range(0,1)) = 0.0
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Standard fullforwardshadows vertex:vert

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0
			#include "UnityPBSLighting.cginc"

		sampler2D _MainTex;
		sampler2D _NormalMap;

		struct Input {
			float2 uv_MainTex;
			float2 uv_NormalMap;
			half3 tangent;
			float3 viewDir;
		};

		half _Anisotropy;
		half _Glossiness;
		half _Metallic;
		fixed4 _Color;

		// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
		// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
		// #pragma instancing_options assumeuniformscaling
		UNITY_INSTANCING_BUFFER_START(Props)
			// put more per-instance properties here
		UNITY_INSTANCING_BUFFER_END(Props)


		// 異方性を考慮した法線を算出する
		inline half3 AnisotropicNormal(half anisotropy, half3 viewDir, half3 normal, half3 tangent, half3 bitangent)
		{
			half3 anisotropicDirection = anisotropy >= 0.0 ? bitangent : tangent;
			half3 anisotropicTangent = cross(anisotropicDirection, viewDir);
			half3 anisotropicNormal = normalize(cross(anisotropicTangent, anisotropicDirection));
			return normalize(lerp(normal, anisotropicNormal, anisotropy));
		}

		// 頂点シェーダ
		void vert(inout appdata_full v, out Input o)
		{
			UNITY_INITIALIZE_OUTPUT(Input, o);
			o.tangent = v.tangent;
		}

		// サーフェイスシェーダ
		void surf (Input IN, inout SurfaceOutputStandard o) {
			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			
			half3 normal = UnpackNormal(tex2D(_NormalMap, IN.uv_NormalMap));
			half3 bitangent = normalize(cross(normal, IN.tangent));
			o.Normal = AnisotropicNormal(_Anisotropy, IN.viewDir, normal, IN.tangent, bitangent);
			
			// Metallic and smoothness come from slider variables
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
