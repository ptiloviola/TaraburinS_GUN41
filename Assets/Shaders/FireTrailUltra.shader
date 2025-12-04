Shader "Custom/FireTrailUltra"
{
    Properties
    {
        _MainTex     ("Flame Texture", 2D) = "white" {}
        _NoiseTex    ("Noise Texture", 2D) = "gray" {}
        _ColorHot    ("Hot Color", Color)  = (1,0.95,0.8,1)
        _ColorWarm   ("Warm Color", Color) = (1,0.6,0.1,1)
        _ColorCool   ("Cool Color", Color) = (0.6,0.05,0,1)
        _ScrollSpeed ("Scroll Speed", Float)        = 4.0
        _DistortSpeed("Distort Speed", Float)       = 1.5
        _DistortStrength("Distort Strength", Float) = 0.18
        _NoiseScale  ("Noise Scale", Float)  = 2.5
        _NoiseScale2 ("Noise Scale 2", Float)= 6.0
        _EdgeSoftness("Edge Softness", Float)= 2.5
        _Intensity   ("Intensity", Float)   = 2.0
        _FlickerSpeed ("Flicker Speed", Float) = 8.0
        _FlickerAmount("Flicker Amount", Float) = 0.35
    }

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        LOD 100

        Blend One One       // аддитивное свечение
        ZWrite Off
        Cull Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4    _MainTex_ST;

            sampler2D _NoiseTex;
            float4    _NoiseTex_ST;

            float4 _ColorHot;
            float4 _ColorWarm;
            float4 _ColorCool;
            float  _ScrollSpeed;
            float  _DistortSpeed;
            float  _DistortStrength;
            float  _NoiseScale;
            float  _NoiseScale2;
            float  _EdgeSoftness;
            float  _Intensity;
            float  _FlickerSpeed;
            float  _FlickerAmount;

            struct appdata_t
            {
                float4 vertex : POSITION;
                float2 uv     : TEXCOORD0; // x — ширина, y — длина трейла
                float4 color  : COLOR;     // градиент TrailRenderer
            };

            struct v2f
            {
                float4 pos       : SV_POSITION;
                float2 uvMain    : TEXCOORD0;
                float2 uvNoise1  : TEXCOORD1;
                float2 uvNoise2  : TEXCOORD2;
                float  widthCoord: TEXCOORD3;
                float4 color     : COLOR;
            };

            v2f vert (appdata_t v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);

                // UV вдоль трейла + скролл
                float2 uv = TRANSFORM_TEX(v.uv, _MainTex);
                uv.y += _Time.y * _ScrollSpeed;
                o.uvMain = uv;

                // крупный шум
                float2 noiseUV1 = v.uv * _NoiseScale;
                noiseUV1.y += _Time.y * _DistortSpeed;
                noiseUV1 = TRANSFORM_TEX(noiseUV1, _NoiseTex);
                o.uvNoise1 = noiseUV1;

                // мелкий шум
                float2 noiseUV2 = v.uv * _NoiseScale2;
                noiseUV2.y -= _Time.y * (_DistortSpeed * 0.7);
                noiseUV2 = TRANSFORM_TEX(noiseUV2, _NoiseTex);
                o.uvNoise2 = noiseUV2;

                o.widthCoord = v.uv.x;
                o.color = v.color;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // два шума
                fixed n1 = tex2D(_NoiseTex, i.uvNoise1).r;
                fixed n2 = tex2D(_NoiseTex, i.uvNoise2).r;

                // комбинированный шум [-1,1]
                fixed nComb = ((n1 + n2) * 0.5 - 0.5) * 2.0;

                // центр трейла ярче
                fixed centerMask = 1.0 - abs(i.widthCoord - 0.5) * 2.0;
                centerMask = saturate(pow(centerMask, _EdgeSoftness));

                // искажение сильнее в центре
                fixed distort = nComb * _DistortStrength * centerMask;

                float2 uv = i.uvMain;
                uv.x += distort;
                uv.y += distort * 0.4;

                // базовая текстура огня
                fixed4 baseTex = tex2D(_MainTex, uv);

                // маска пламени
                fixed flameMask = baseTex.a * centerMask * i.color.a;
                flameMask = saturate(flameMask);
                if (flameMask <= 0.001)
                    discard;

                // "температура" по маске
                fixed tHot  = saturate(flameMask * 2.0);
                fixed tWarm = saturate(flameMask);
                fixed tCool = saturate(1.0 - flameMask);

                fixed4 warmMix = lerp(_ColorCool, _ColorWarm, tWarm);
                fixed4 hotMix  = lerp(warmMix,  _ColorHot,  tHot);

                // мерцание
                fixed flicker = 1.0 + _FlickerAmount *
                    (sin(_Time.y * _FlickerSpeed + i.uvMain.y * 10.0) * 0.5);

                fixed4 col = hotMix * flameMask * i.color * baseTex.r;
                col.rgb *= (_Intensity * flicker);

                return col;
            }
            ENDCG
        }
    }
}
