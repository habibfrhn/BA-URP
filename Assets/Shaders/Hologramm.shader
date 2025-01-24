Shader "Custom/AdvancedHolographicShader"
{
    Properties
    {
        [Header(Base Properties)]
        _MainTex ("Base Texture", 2D) = "white" {}
        _Color ("Base Color", Color) = (0.2, 0.8, 1, 0.5)
        
        [Header(Holographic Properties)]
        _HologramFrequency ("Scan Line Frequency", Range(1, 100)) = 20
        _ScanSpeed ("Scan Line Speed", Range(0, 10)) = 2
        _Noise ("Noise Intensity", Range(0, 1)) = 0.1
        _Distortion ("Edge Distortion", Range(0, 1)) = 0.2
        _EdgeHighlight ("Edge Highlight", Range(0, 1)) = 0.5
        
        [Header(Emission)]
        _EmissionColor ("Emission Color", Color) = (0.2, 0.8, 1, 1)
        _EmissionIntensity ("Emission Intensity", Range(0, 5)) = 1
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType"="Transparent" 
            "Queue"="Transparent" 
            "RenderPipeline"="UniversalPipeline"
        }
        
        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off
        
        Pass
        {
            Name "Holographic"
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 viewDirWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
            };

            // Shader Properties
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                half4 _Color;
                float _HologramFrequency;
                float _ScanSpeed;
                float _Noise;
                float _Distortion;
                float _EdgeHighlight;
                half4 _EmissionColor;
                float _EmissionIntensity;
            CBUFFER_END

            // Simple noise function
            float noise(float2 p) 
            {
                return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
            }

            Varyings vert(Attributes input)
            {
                Varyings output;
                
                // Vertex displacement with slight distortion
                float displacement = sin(_Time.y * _ScanSpeed + input.positionOS.y * _HologramFrequency) * _Distortion;
                input.positionOS.xyz += input.normalOS * displacement;
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);
                
                output.positionHCS = vertexInput.positionCS;
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);
                output.normalWS = normalInput.normalWS;
                
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // Base texture sampling
                half4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv) * _Color;
                
                // Fresnel effect for edge highlighting
                float3 normalWS = normalize(input.normalWS);
                float3 viewDirWS = normalize(input.viewDirWS);
                float fresnel = pow(1.0 - saturate(dot(normalWS, viewDirWS)), 5);
                
                // Scan line effect
                float scanLine = sin(_Time.y * _ScanSpeed + input.uv.y * _HologramFrequency);
                float noiseValue = noise(input.uv * 100) * _Noise;
                
                // Combine effects
                float edgeEffect = fresnel * _EdgeHighlight;
                float scanEffect = abs(scanLine) * (1 - noiseValue);
                
                // Final color calculation
                half3 finalColor = baseColor.rgb + 
                    (_EmissionColor.rgb * _EmissionIntensity * scanEffect) + 
                    (edgeEffect * _EmissionColor.rgb);
                
                float alpha = baseColor.a * (scanEffect + edgeEffect);
                
                return half4(finalColor, alpha);
            }
            ENDHLSL
        }
    }
    
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}