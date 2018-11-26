Shader "Eye_HighLight"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)
		_BumpMap("Normal Map", 2D) = "bump" {}
		_Roughness("Roughness", Range(0.0, 1.0)) = 0.5

		_Power("Power", Range(0.0, 1.0)) = 0.5
		_Direction("HighLight Dir", Vector) = (0,0,1,0)
		_ObjectDirection("Object Dir", Vector) = (0,0,1,0)
		_Position("Position", Vector) = (0,0,1,0)
	}

		SubShader
		{
			Tags { "Queue" = "Transparent" "RenderType" = "Transparent" }
			LOD 100

			ZWrite Off
			Blend One One

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
					half3 localNormal : TEXCOORD5;
					//half3 worldPivotPos : TEXCOORD5;
				};

				sampler2D _MainTex;
				float4 _MainTex_ST;
				half4 _Color;
				sampler2D _BumpMap;
				float _Roughness;
				
				float4 _Direction;
				float4 _ObjectDirection;
				float4 _Position;
				float _Power;

	#define MEDIUMP_FLT_MAX 65504.0
	#define saturateMadiumup(x) min(x, MEDIUMP_FLT_MAX)

				float D_GGX(float linearRoughness, float NoH, const float3 n, const float3 h) {
					float3 NxH = cross(n, h);
					float a = NoH * linearRoughness;
					float k = linearRoughness / (dot(NxH, NxH) + a * a);
					float d = k * k * (1.0 / UNITY_PI);
					return saturateMadiumup(d);
				}

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

					o.localNormal = v.normal;
					//o.worldPivotPos = mul(unity_ObjectToWorld, float4(0,0,0,1)).xyz;

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
					n = normalize(n);

					// ライトの方向ベクトル
					float3 l = _WorldSpaceLightPos0.xyz;

					// 視線ベクトル
					float3 v = normalize(_WorldSpaceCameraPos - i.worldPos);
					//float3 v = normalize(_WorldSpaceCameraPos - _Position);

					// 位置補正ベクトル
					float3 dir = normalize(_Direction.xyz + _ObjectDirection.xyz);

					//float3 V = normalize(v + dir);
					//float NoV = max(0, dot(i.localNormal, dir));

					//float3 h = normalize(normalize(i.localNormal) + v);
					float3 h = normalize(dir);
					float NoH = max(0, dot(h, n));
					float D = min(1, D_GGX(_Roughness, NoH, n, h));
					return (albedo * D) + half4(0.5,0,0,0);
					






					
					//float3 ln = mul(unity_WorldToObject, n);
					//return half4((i.localNormal + float3(1, 1, 1)) * 0.5, 1);
					//return half4((i.localNormal + float3(1,1,1)) * 0.5, 1);
				}
				ENDCG
			}
		}
}
