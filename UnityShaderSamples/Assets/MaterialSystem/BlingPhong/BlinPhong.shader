Shader "BlinnPhong"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)
		_BumpMap("Normal Map", 2D) = "bump" {}
		_Roughness("Roughness", Range(0.0, 1.0)) = 0.5
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
				float2 uv : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				half3 tspace0 : TEXCOORD2;
				half3 tspace1 : TEXCOORD3;
				half3 tspace2 : TEXCOORD4;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			half4 _Color;
			sampler2D _BumpMap;
			float _Roughness;
			float _Metallic;

			v2f vert(appdata v)
			{
				v2f o;

				// ローカル空間の頂点位置からクリップ空間の位置へ変換します
				o.vertex = UnityObjectToClipPos(v.vertex);

				// uv座標を算出します
				// TRANSFORM_TEXはインスペクター上で入力されたスケールとオフセット値から適切なuvを計算してくれるマクロです
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);

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
				half4 albedo = tex2D(_MainTex, i.uv) * _Color;

				// 法線
				// Tangent空間上の法線を取得します
				float3 tnormal = UnpackNormal(tex2D(_BumpMap, i.uv));

				// 法線をTangent空間からワールド空間へ変換します
				float3 n;
				n.x = dot(i.tspace0, tnormal);
				n.y = dot(i.tspace1, tnormal);
				n.z = dot(i.tspace2, tnormal);

				// ライトの方向ベクトル
				float3 l = _WorldSpaceLightPos0.xyz;

				// 視線ベクトル
				float3 v = _WorldSpaceCameraPos;


				// Phongシェーディングでのライティングを行います

				// 計算に使うパラメータを用意しておきます
				half3 h = normalize(l + v);
				half NoL = max(0, dot(n, l));

				// specular
				half specular = pow(max(0, dot(n, h)), 50);

				// diffuse
				// Lambert反射
				half diffuse = 1.0;

				// 最終的に表現される色を算出します
				half4 col = ((albedo * _LightColor0 * diffuse) + (specular * _LightColor0)) * NoL;
				return col;
			}
			ENDCG
		}
	}
}
