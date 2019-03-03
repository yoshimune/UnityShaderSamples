Shader "ProcedualTexture/bubble"
{
    Properties
    {
		[HDR]_Color("Color", Color)=(1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 100
		Blend One One
		ZWrite Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
				float2 uv : TEXCOORD0; // テクスチャ座標
				half4 color : COLOR0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				half4 color : COLOR0;
            };

            half4 _Color;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = (v.uv * 2.0) - float2(1.0, 1.0);
				o.color = v.color;
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
				float sqr_distance = (i.uv.x * i.uv.x) + (i.uv.y * i.uv.y);
				float cutout = (1.0 - sqr_distance);
				cutout = clamp(cutout * 50, 0, 1);
				float alpha = clamp(pow(sqr_distance, 5), 0, 1);
				return _Color * _Color.a * (cutout * alpha) * i.color;
            }
            ENDCG
        }
    }
}
