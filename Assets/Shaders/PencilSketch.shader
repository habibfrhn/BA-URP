// Define the shader and its name within the Universal Render Pipeline
Shader "Universal Render Pipeline/PencilSketch"
{
    // Properties block defines the inputs that can be adjusted in the Unity Editor
    Properties
    {
        // Base texture of the material
        _MainTex("Base Texture", 2D) = "white" {}
        // Tint color applied to the base texture
        _Color("Base Color Tint", Color) = (1,1,1,1)

        // First pencil texture used for sketching (black on white)
        _PencilTex1("Pencil Texture #1 (Black on White)", 2D) = "gray" {}
        // UV scale for the first pencil texture
        _SketchScale1("Sketch UV Scale #1", Float) = 1.0

        // Second pencil texture used for sketching (black on white)
        _PencilTex2("Pencil Texture #2 (Black on White)", 2D) = "gray" {}
        // UV scale for the second pencil texture
        _SketchScale2("Sketch UV Scale #2", Float) = 1.0

        // Controls the intensity of the pencil lines
        _LineIntensity("Overall Pencil Line Intensity", Range(0,1)) = 0.5
        // Adjusts the brightness of the sketch
        _SketchBrightness("Sketch Brightness", Range(0.5,2)) = 1.0
        // Adjusts the contrast of the sketch
        _SketchContrast("Sketch Contrast", Range(0.5,2)) = 1.0

        // Color of the outline around the object
        _OutlineColor("Outline Color", Color) = (0,0,0,1)
        // Thickness of the outline
        _OutlineThickness("Outline Thickness", Float) = 0.02
    }

    // SubShader contains the rendering passes and shader logic
    SubShader
    {
        // Tags define how the shader interacts with the rendering pipeline
        Tags 
        { 
            "RenderType"="Opaque" 
            "RenderPipeline"="UniversalPipeline"
            "Queue"="Geometry" 
        }
        // Level of Detail for the shader
        LOD 100

        // Begin HLSL (High-Level Shading Language) code inclusion
        HLSLINCLUDE
        // Include core shader functions from the Universal Render Pipeline
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        // Include lighting functions
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        // Define a constant buffer for material properties
        CBUFFER_START(UnityPerMaterial)
            // Transformation parameters for the main texture
            float4 _MainTex_ST;
            // Base color tint
            float4 _Color;
            // Transformation parameters for the first pencil texture
            float4 _PencilTex1_ST;
            // Transformation parameters for the second pencil texture
            float4 _PencilTex2_ST;
            // UV scale factors for pencil textures
            float _SketchScale1;
            float _SketchScale2;
            // Pencil line intensity
            float _LineIntensity;
            // Sketch brightness and contrast
            float _SketchBrightness;
            float _SketchContrast;
            // Outline color and thickness
            float4 _OutlineColor;
            float _OutlineThickness;
        CBUFFER_END

        // Declare texture and sampler for the main texture
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        // Declare textures and samplers for pencil textures
        TEXTURE2D(_PencilTex1);
        SAMPLER(sampler_PencilTex1);
        TEXTURE2D(_PencilTex2);
        SAMPLER(sampler_PencilTex2);
        // End HLSL inclusion
        ENDHLSL

        // First Pass: Pencil Sketch Shading
        Pass
        {
            // Name of the pass for identification
            Name "PencilShading"
            // Tags to specify when this pass should be used
            Tags { "LightMode"="UniversalForward" }

            // Begin HLSL program for this pass
            HLSLPROGRAM
            // Specify vertex and fragment shaders
            #pragma vertex vert
            #pragma fragment frag
            // Compile different shader variants based on lighting features
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS

            // Structure to hold input vertex attributes
            struct Attributes
            {
                float4 positionOS : POSITION; // Object-space position
                float3 normalOS : NORMAL;     // Object-space normal
                float2 uv : TEXCOORD0;        // Texture coordinates
            };

            // Structure to hold data passed to the fragment shader
            struct Varyings
            {
                float4 positionCS : SV_POSITION; // Clip-space position
                float3 normalWS : NORMAL;        // World-space normal
                float3 positionWS : TEXCOORD1;   // World-space position
                float2 uv : TEXCOORD2;           // Transformed texture coordinates
            };

            // Vertex shader: transforms vertex data to clip space and passes necessary data to fragment shader
            Varyings vert(Attributes input)
            {
                Varyings output;
                // Transform object-space position to clip-space
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                // Transform object-space normal to world-space normal
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                // Transform object-space position to world-space position
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                // Apply texture scaling and offset
                output.uv = input.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                return output;
            }

            // Fragment shader: calculates the final color of each pixel
            half4 frag(Varyings input) : SV_Target
            {
                // Lighting Calculation using Lambertian reflectance
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS));
                float3 lightDir = normalize(mainLight.direction);
                float lambert = saturate(dot(normalize(input.normalWS), lightDir));

                // Sample the base texture using the transformed UV coordinates
                half4 baseTexColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                // Apply the base color tint and lighting
                half4 baseColor = baseTexColor * _Color * lambert;

                // Calculate scaled UVs for both pencil textures
                float2 uv1 = input.uv * _SketchScale1 * _PencilTex1_ST.xy + _PencilTex1_ST.zw;
                float2 uv2 = input.uv * _SketchScale2 * _PencilTex2_ST.xy + _PencilTex2_ST.zw;

                // Sample both pencil textures
                half4 pencilSample1 = SAMPLE_TEXTURE2D(_PencilTex1, sampler_PencilTex1, uv1);
                half4 pencilSample2 = SAMPLE_TEXTURE2D(_PencilTex2, sampler_PencilTex2, uv2);

                // Blend the two pencil textures by inverting their red channels and averaging
                float blendedPencilLines = (1.0 - pencilSample1.r + 1.0 - pencilSample2.r) * 0.5;
                // Adjust the blended lines with brightness and contrast
                float adjustedLines = pow(blendedPencilLines * _SketchBrightness, _SketchContrast);
                // Apply the line intensity
                float lineFactor = adjustedLines * _LineIntensity;

                // Combine the base color with the pencil lines to create the sketch effect
                half3 finalColor = baseColor.rgb - (lineFactor * half3(1,1,1));

                // Return the final color with the original alpha
                return half4(finalColor, baseColor.a);
            }
            // End HLSL program for this pass
            ENDHLSL
        }

        // Second Pass: Outline Rendering
        Pass
        {
            // Name of the pass for identification
            Name "Outline"
            // Tags to specify when this pass should be used
            Tags { "LightMode" = "SRPDefaultUnlit" }

            // Render settings for the outline
            Cull Front               // Cull front faces to render the back (outline)
            ZWrite On                // Enable writing to the depth buffer
            ZTest LEqual             // Depth test function
            Blend SrcAlpha OneMinusSrcAlpha // Enable alpha blending

            // Begin HLSL program for the outline pass
            HLSLPROGRAM
            // Specify vertex and fragment shaders for the outline
            #pragma vertex vert_outline
            #pragma fragment frag_outline

            // Structure to hold input vertex attributes for the outline
            struct Attributes
            {
                float4 positionOS : POSITION; // Object-space position
                float3 normalOS : NORMAL;     // Object-space normal
            };

            // Structure to hold data passed to the fragment shader for the outline
            struct Varyings
            {
                float4 positionCS : SV_POSITION; // Clip-space position
            };

            // Vertex shader for the outline: expands the geometry along normals to create an outline
            Varyings vert_outline(Attributes input)
            {
                Varyings output;
                // Transform object-space normal to world-space normal
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                // Transform object-space position to world-space position
                float3 posWS = TransformObjectToWorld(input.positionOS.xyz);

                // Calculate a scaling factor based on the object's transformation matrix
                float scaleFactor = length(float3(UNITY_MATRIX_M[0][0], UNITY_MATRIX_M[1][0], UNITY_MATRIX_M[2][0]));
                // Offset the position along the normal by the outline thickness
                posWS += normalWS * (_OutlineThickness * scaleFactor);

                // Transform the offset position back to clip-space
                output.positionCS = TransformWorldToHClip(posWS);
                return output;
            }

            // Fragment shader for the outline: outputs the outline color
            half4 frag_outline(Varyings input) : SV_Target
            {
                return _OutlineColor;
            }
            // End HLSL program for the outline pass
            ENDHLSL
        }
    }

    // Fallback shader to use if the current render pipeline doesn't support this shader
    FallBack "Universal Render Pipeline/Unlit"
}
