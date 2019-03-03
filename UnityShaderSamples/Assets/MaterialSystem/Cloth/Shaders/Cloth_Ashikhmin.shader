Shader "Cloth/Ashikhmin"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)
		_SheenColor("_SheenColor", Color) = (1,1,1,1)
		_Roughness("Roughness", Range(0.0, 1.0)) = 0.5
		_RoughnessTex("Roughness", 2D) = "white" {}
		_RoughnessScale("Roughness Scale", Range(0.0, 2.0)) = 1.0
		_BumpMap("Normal Map", 2D) = "bump" {}
		_BumpScale("BumpScale", Range(-1.0, 1.0)) = 1.0
		_OcclusionTex("Occlusion", 2D) = "white" {}
		_OcclusionScale("Occlusion Scale", Range(0.0, 2.0)) = 1.0
		_Metallic("Metallic", Range(0.0, 1.0)) = 0.0
	}

	SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 100

		Pass
		{
			// LightModeをForwardBaseにしないと_WorldSpaceLightPos0で取得されるライトの向きが逆になります
			// これは位置情報をもたない directional light とそれ以外のライトの違いかと思われます
			Tags {"LightMode" = "ForwardBase"}
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "UnityLightingCommon.cginc"
			#include "UnityStandardUtils.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv1 : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				half3 tspace0 : TEXCOORD2;
				half3 tspace1 : TEXCOORD3;
				half3 tspace2 : TEXCOORD4;
				float2 uv2 : TEXCOORD5;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _RoughnessTex;
			half4 _Color;
			half4 _SheenColor;
			sampler2D _BumpMap;
			float4 _BumpMap_ST;
			float _BumpScale;
			sampler2D _OcclusionTex;
			float _OcclusionScale;
			float _Roughness;
			float _RoughnessScale;
			float _Metallic;

			//  Ashikmin NDF
			// https://google.github.io/filament/Filament.md.html#materialsystem/clothmodel
			float D_Ashikmin(float linearRoughness, float NoH) {
				// Ashikhmin 2007, "Distribution-based BRDFs"
				float a2 = linearRoughness * linearRoughness;
				float cos2h = NoH * NoH;
				float sin2h = max(1.0 - cos2h, 0.0078125); // 2^(-14/2), so sin2h^2 > 0 in fp16
				float sin4h = sin2h * sin2h;
				float cot2 = -cos2h / (a2 * sin2h);
				return 1.0 / (UNITY_PI * (4.0 * a2 + 1.0) * sin4h) * (4.0 * exp(cot2) + sin4h);
			}

			// Fresnel(Shilick)
			// https://google.github.io/filament/Filament.md.html#materialsystem/specularbrdf/fresnel(specularf)
			float3 F_Schlick(float VoH, float3 f0) {
				return f0 + (float3(1.0, 1.0, 1.0) - f0) * pow(1.0 - VoH, 5.0);
			}

			// V_Neubelt
			float V_Neubelt(float NoV, float NoL) {
				return saturate(1 / (4 * ((NoL + NoV) - (NoL * NoV))));
			}

			float3 BRDF(float D, float3 F, float NoL, float NoV)
			{
				return F * (D / 4*(NoL + NoV - (NoL * NoV)));
			}

			v2f vert(appdata v)
			{
				v2f o;

				// ローカル空間の頂点位置からクリップ空間の位置へ変換します
				o.vertex = UnityObjectToClipPos(v.vertex);

				// uv座標を算出します
				// TRANSFORM_TEXはインスペクター上で入力されたスケールとオフセット値から適切なuvを計算してくれるマクロです
				o.uv1 = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv2 = TRANSFORM_TEX(v.uv, _BumpMap);

				// ローカル空間の頂点位置からワールド空間の頂点位置へ変換します
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

				// ローカル空間法線をワールド空間に変換します
				half3 wNormal = UnityObjectToWorldNormal(v.normal);

				// ローカル空間接線をワールド空間に接線します
				half3 wTangent = UnityObjectToWorldDir(v.tangent.xyz);

				// ワールド空間での接線の向きを算出します
				// tangent.w には接線の向きを表す値です
				// 右手系・左手系座標の差異を吸収するため「unity_WorldTransformParams.w」（1.0 or -1.0）を乗算します
				half tangentSign = v.tangent.w * unity_WorldTransformParams.w;

				// 従接線を算出します
				// 従接線は、法線と接線の両方と直行するベクトルです
				// よって法線と接線の外積で求められます
				half3 wBitangent = cross(wNormal, wTangent) * tangentSign;

				// 接線マトリクスを作成します
				// この接線マトリクスはフラグメントシェーダーで法線マップと合わせて法線算出に使用されます
				o.tspace0 = half3(wTangent.x, wBitangent.x, wNormal.x);
				o.tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
				o.tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);

				return o;
			}

			half4 frag(v2f i) : SV_Target
			{
				// アルベドカラーを算出します
				half4 albedo = tex2D(_MainTex, i.uv1) * _Color;

				// ラフネス値を取得します
				float roughness = pow(tex2D(_RoughnessTex, i.uv2).r, _RoughnessScale) * _Roughness;

				// オクルージョン値を取得します
				float occlsion = pow(tex2D(_OcclusionTex, i.uv2).r, _OcclusionScale);

				// 法線
				// Tangent空間上の法線を取得します
				//float3 tnormal = UnpackNormal(tex2D(_BumpMap, i.uv));
				//float3 tnormal = UnpackScaleNormal(tex2D(_BumpMap, i.uv), _BumpScale);
				float4 tnormal = tex2D(_BumpMap, i.uv2);
				tnormal.x *= tnormal.w;
				half3 normal;
				normal.xy = (tnormal.xy * 2 - 1);
				normal.xy *= _BumpScale;
				normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));

				// 法線をTangent空間からワールド空間へ変換します
				float3 n;
				n.x = dot(i.tspace0, normal);
				n.y = dot(i.tspace1, normal);
				n.z = dot(i.tspace2, normal);

				// ライトの方向ベクトル
				float3 l = normalize(_WorldSpaceLightPos0.xyz);

				// 視線ベクトル
				float3 v = normalize(_WorldSpaceCameraPos);

				// ハーフベクトル
				float3 h = normalize(l + v);

				// 最終的に表現される色を算出します

				float NoH = saturate(dot(n, h));
				float NoL = saturate(dot(n, l));
				float NoV = saturate(dot(n, v));
				float VoH = saturate(dot(v, h));

				// NDF
				float D = D_Ashikmin(roughness, NoH);

				// V
				float V = V_Neubelt(NoV, NoL);

				// Fresnel
				float3 F0 = lerp(lerp(unity_ColorSpaceDielectricSpec.rgb, albedo, _Metallic), _SheenColor.rgb, _SheenColor.a);
				float3 F = F_Schlick(max(0, VoH), F0);

				// Specular
				//half3 specularColor = half3(BRDF(D, F, NoL, NoV));
				half3 specularColor = half3(D * V * F);

				// Diffuse
				half oneMinusDielectricSpec = unity_ColorSpaceDielectricSpec.a;
				half diffuseTerm = oneMinusDielectricSpec - _Metallic * oneMinusDielectricSpec;
				half3 diffuseColor = (diffuseTerm * albedo.rgb) / UNITY_PI;

				// ライト成分
				half3 light = _LightColor0.rgb * occlsion;

				// 反射光成分
				half3 col = (specularColor + diffuseColor) * UNITY_PI * NoL;
				col *= light;

				// 環境光
				// デフォルトのリフレクションキューブマップをサンプリングしてリフレクションベクトルを使用する
				half4 skyData = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, n);

				// キューブマップデータを実際のカラーにデコードする
				//half3 skyColor = DecodeHDR(skyData, unity_SpecCube0_HDR);
				//half3 skyColor = 0;

				half3 ambientColor = ShadeSH9(half4(n, 1)) * albedo.rgb;

				half3 color = ambientColor + col;
				
				return half4(color, albedo.a);
			}
			ENDCG
		}
	}
}
