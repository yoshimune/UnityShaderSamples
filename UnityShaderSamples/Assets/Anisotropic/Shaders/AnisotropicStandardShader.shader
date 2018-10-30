// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

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
		#pragma surface surf GGX fullforwardshadows vertex:vert

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0
			#include "UnityPBSLighting.cginc"
#define PI 3.14159265359

		sampler2D _MainTex;
		sampler2D _NormalMap;

		struct Input {
			float2 uv_MainTex;
			half3 tangent;
		};

		struct SurfaceOutputAnisoStandard
		{
			fixed3 Albedo;      // ベース (ディフューズかスペキュラー) カラー
			fixed3 Normal;      // 書き込まれる場合は、接線空間法線
			fixed3 Tangent;		// 説空間
			half3 Emission;
			half Metallic;      // 0=非メタル, 1=メタル
			half Smoothness;    // 0=粗い, 1=滑らか
			half Occlusion;     // オクルージョン (デフォルト 1)
			fixed Alpha;        // 透明度のアルファ
		};

		half _Glossiness;
		half _Anisotropy;
		half _Metallic;
		fixed4 _Color;

		// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
		// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
		// #pragma instancing_options assumeuniformscaling
		UNITY_INSTANCING_BUFFER_START(Props)
			// put more per-instance properties here
		UNITY_INSTANCING_BUFFER_END(Props)


		inline float D_GGX_Anisotropic(float NoH, half3 h, half3 t, half3 b, float at, float ab)
		{
			half ToH = dot(t, h);
			half BoH = dot(b, h);
			float a2 = at * ab;
			float3 v = float3(ab * ToH, at * BoH, a2 * NoH);
			float v2 = dot(v, v);
			float w2 = a2 / v2;
			return a2 * w2 * w2 * (1.0 / PI);
		}

		half4 LightingGGX(SurfaceOutputAnisoStandard s, half3 lightDir, half3 viewDir, half atten)
		{
			// ハーフベクトル
			half3 h = normalize(lightDir + viewDir);

			// Bitangent
			half3 b = normalize(cross(s.Normal, s.Tangent));

			// 異方性NDFを求める
			float ndf = D_GGX_Anisotropic(normalize(dot(s.Normal, h)), h, s.Tangent, b, 
				max(s.Smoothness * (1.0 + _Anisotropy), 0.001),
				max(s.Smoothness * (1.0 - _Anisotropy), 0.001)
			);

			// 拡散反射(Lambert)
			half diffuse = max(0, dot(s.Normal, lightDir));

			half3 c = ((diffuse * s.Albedo * _LightColor0.rgb) + (ndf * _LightColor0.rgb)) * atten;

			return half4(c, 1);
		}

		void vert(inout appdata_full v, out Input o)
		{
			UNITY_INITIALIZE_OUTPUT(Input, o);
			o.tangent = v.tangent;
			//o.bitangent = normalize(cross(v.normal, v.tangent));
		}

		void surf (Input IN, inout SurfaceOutputAnisoStandard o) {
			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			// Metallic and smoothness come from slider variables
			o.Normal = UnpackNormal(tex2D(_NormalMap, IN.uv_MainTex));
			o.Tangent = IN.tangent;
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
