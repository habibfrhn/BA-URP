Shader "Custom/Watercolor"
{
    // Define shader properties that can be adjusted in the Unity Editor
    Properties
    {
        // Base texture and its properties
        _MainTex ("Main Texture", 2D) = "white" {} // The primary texture of the object
        _Color ("Albedo Color", Color) = (1, 1, 1, 1) // The base color applied to the main texture

        // Paper texture with enhanced properties
        _PaperTex ("Paper Texture", 2D) = "white" {} // Texture simulating paper surface
        _PaperStrength ("Paper Texture Strength", Range(0, 1)) = 0.7 // Strength of the paper texture effect
        _PaperColor ("Paper Color", Color) = (0.9, 0.9, 0.85, 1) // Color tint applied to the paper texture

        // Brush texture with advanced blending
        _BrushTex ("Brush Texture", 2D) = "white" {} // Texture simulating brush strokes
        _BrushColor ("Brush Color", Color) = (1, 1, 1, 1) // Color tint applied to the brush texture

        // Enhanced watercolor effects
        _WatercolorBleed ("Watercolor Bleed", Range(0, 1)) = 0.3 // Controls the bleeding effect of watercolor
        _EdgeSoftness ("Edge Softness", Range(0, 1)) = 0.2 // Softens the edges of the painted areas
        _NoiseIntensity ("Noise Intensity", Range(0, 0.2)) = 0.05 // Adds noise to simulate texture variation
        _BrushStrength ("Brush Strength", Range(0, 1)) = 0.5 // Controls the influence of the brush texture

        // Rendering properties
        [Toggle] _UseAlphaClip ("Use Alpha Clip", Float) = 0 // Enables or disables alpha clipping
        _AlphaClipThreshold ("Alpha Clip Threshold", Range(0, 1)) = 0.5 // Threshold for alpha clipping
    }

    SubShader
    {
        // Tags define rendering order and pipeline
        Tags 
        { 
            "RenderType"="Opaque" // Specifies the object is opaque
            "RenderPipeline"="UniversalPipeline" // Specifies the shader is for the Universal Render Pipeline
            "Queue"="Geometry" // Sets the rendering queue
        }
        LOD 200 // Level of Detail

        Pass
        {
            Name "ForwardLit" // Name of the rendering pass
            Tags { "LightMode"="UniversalForward" } // Tags indicating the lighting mode

            HLSLPROGRAM
            #pragma vertex vert // Specifies the vertex shader function
            #pragma fragment frag // Specifies the fragment shader function

            // Include necessary URP shader libraries
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // Declare shader textures and samplers
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_PaperTex);
            SAMPLER(sampler_PaperTex);
            TEXTURE2D(_BrushTex);
            SAMPLER(sampler_BrushTex);

            // Define a constant buffer to hold shader variables
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;    // Tiling and offset for _MainTex
                float4 _PaperTex_ST;   // Tiling and offset for _PaperTex
                float4 _BrushTex_ST;   // Tiling and offset for _BrushTex
                half4 _Color;          // Albedo color
                half4 _PaperColor;     // Paper texture color
                half4 _BrushColor;     // Brush texture color
                float _PaperStrength;  // Strength of paper texture effect
                float _WatercolorBleed; // Watercolor bleed intensity
                float _EdgeSoftness;    // Edge softness factor
                float _NoiseIntensity;  // Noise intensity
                float _BrushStrength;   // Brush texture strength
                float _UseAlphaClip;    // Toggle for alpha clipping
                float _AlphaClipThreshold; // Threshold for alpha clipping
            CBUFFER_END

            // Structure for vertex shader input
            struct Attributes
            {
                float4 positionOS : POSITION; // Object space position
                float2 uv : TEXCOORD0;        // UV coordinates
                half3 normalOS : NORMAL;      // Object space normal
            };

            // Structure for passing data from vertex to fragment shader
            struct V2F
            {
                float4 positionCS : SV_POSITION; // Clip space position
                float2 uv : TEXCOORD0;           // UV coordinates
                half3 normalWS : TEXCOORD1;      // World space normal
                float3 positionWS : TEXCOORD2;    // World space position
            };

            // Pseudo-random noise function based on UV coordinates
            float rand(float2 co)
            {
                return frac(sin(dot(co.xy, float2(12.9898, 78.233))) * 43758.5453);
            }

            // Function to apply watercolor bleeding effect
            half3 WatercolorBleed(half3 color, float2 uv)
            {
                float bleedOffset = _WatercolorBleed * 0.05; // Calculate offset based on bleed strength
                // Sample the main texture slightly offset to simulate bleeding
                half3 bleedColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(bleedOffset, bleedOffset)).rgb;
                // Blend the original color with the bleed color based on bleed strength
                return lerp(color, bleedColor, _WatercolorBleed);
            }

            // Vertex shader: Transforms object space positions to clip space and passes necessary data to fragment shader
            V2F vert(Attributes input)
            {
                V2F output;
                // Transform object space position to world space
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                // Transform world space position to clip space
                output.positionCS = TransformWorldToHClip(output.positionWS);

                // Pass UVs unchanged (tiling and offset will be applied in the fragment shader)
                output.uv = input.uv;
                // Transform object space normal to world space
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                return output;
            }

            // Fragment shader: Calculates the final pixel color with watercolor effects
            half4 frag(V2F input) : SV_Target
            {
                // Apply Unity's built-in tiling and offset for each texture
                float2 mainUV = input.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                float2 paperUV = input.uv * _PaperTex_ST.xy + _PaperTex_ST.zw;
                float2 brushUV = input.uv * _BrushTex_ST.xy + _BrushTex_ST.zw;

                // Sample textures with transformed UVs and apply respective colors
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainUV) * _Color;
                half4 paperTex = SAMPLE_TEXTURE2D(_PaperTex, sampler_PaperTex, paperUV) * _PaperColor;
                half4 brushTex = SAMPLE_TEXTURE2D(_BrushTex, sampler_BrushTex, brushUV) * _BrushColor;

                // Apply paper texture by blending it with the main texture based on paper strength
                mainTex.rgb = lerp(mainTex.rgb, mainTex.rgb * paperTex.rgb, _PaperStrength);

                // Apply brush texture by blending it with the main texture based on brush strength
                mainTex.rgb = lerp(mainTex.rgb, mainTex.rgb * brushTex.rgb, _BrushStrength);

                // Apply watercolor bleeding effect to simulate ink spreading
                mainTex.rgb = WatercolorBleed(mainTex.rgb, mainUV);

                // Add noise to simulate texture variation, making the effect more natural
                float noise = rand(mainUV * _Time.y) * _NoiseIntensity;
                mainTex.rgb += noise;

                // Soften edges to mimic watercolor's gradual transitions
                mainTex.rgb = saturate(mainTex.rgb * (1.0 - _EdgeSoftness));

                // Optionally discard pixels based on alpha value and threshold
                clip(_UseAlphaClip * (mainTex.a - _AlphaClipThreshold));

                // Perform basic Lambertian lighting calculation using the main light
                Light mainLight = GetMainLight(); // Retrieve the main directional light
                half3 lighting = LightingLambert(mainLight.color, mainLight.direction, input.normalWS);
                mainTex.rgb *= lighting; // Apply lighting to the color

                // Return the final color with full opacity
                return half4(mainTex.rgb, 1.0);
            }
            ENDHLSL
        }
    }
    // Fallback shader in case the custom shader cannot be used
    FallBack "Universal Render Pipeline/Lit"
}
