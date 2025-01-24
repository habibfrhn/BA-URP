Shader "Universal Render Pipeline/Custom/ToonShader"
{
    // Define the properties that can be set in the Unity Editor
    Properties
    {
        // Albedo Color: Base color of the object
        _Color ("Albedo Color", Color) = (1, 1, 1, 1)
        
        // Shades: Number of discrete shading levels for toon effect
        _Shades ("Shades", Range(1, 20)) = 3
        
        // Outline Color: Color of the object's outline
        _OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
        
        // Outline Thickness: Thickness of the outline
        _OutlineThickness ("Outline Thickness", Float) = 0.02
        
        // Shade Shadow Color: Color used for shadowed areas in toon shading
        _ShadeShadowColor ("Shade Shadow Color", Color) = (0, 0, 0, 1)
        
        // Shadow Threshold: Determines at which angle shadows appear
        _ShadowThreshold ("Shadow Threshold", Range(0, 1)) = 0.5
    }

    // Define the rendering behavior of the shader
    SubShader
    {
        // Tags define rendering characteristics
        Tags 
        { 
            "RenderType"="Opaque" // Indicates that the shader is opaque
            "RenderPipeline"="UniversalPipeline" // Specifies the shader is for URP
        }
        
        // Level of Detail for shader; lower numbers are less detailed
        LOD 100

        // First Pass: Toon Shading
        Pass
        {
            Name "Toon" // Name of the pass
            Tags { "LightMode" = "UniversalForward" } // Specifies the lighting mode

            // Begin HLSL program block
            HLSLPROGRAM
            // Specify the vertex and fragment shaders
            #pragma vertex Vertex
            #pragma fragment Fragment

            // Include essential shader libraries from URP
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // Define material properties accessible in the shader
            CBUFFER_START(UnityPerMaterial)
                half4 _Color; // Base color
                float _Shades; // Number of shading levels
                half4 _ShadeShadowColor; // Shadow color for shading
                float _ShadowThreshold; // Threshold for shadow application
            CBUFFER_END

            // Structure for input vertex attributes
            struct Attributes
            {
                float4 positionOS : POSITION; // Object-space position
                float3 normalOS : NORMAL; // Object-space normal
            };

            // Structure for passing data from vertex to fragment shader
            struct Varyings
            {
                float4 positionCS : SV_POSITION; // Clip-space position
                float3 normalWS : TEXCOORD0; // World-space normal
                float3 positionWS : TEXCOORD1; // World-space position
            };

            // Vertex shader: Transforms vertices and passes data to fragment shader
            Varyings Vertex(Attributes input)
            {
                Varyings output;

                // Get transformed position and normal
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);

                // Assign transformed values to output structure
                output.positionCS = vertexInput.positionCS;
                output.normalWS = normalInput.normalWS;
                output.positionWS = vertexInput.positionWS;

                return output;
            }

            // Fragment shader: Calculates the final color with toon shading
            half4 Fragment(Varyings input) : SV_Target
            {
                // Get main directional light information
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS));
                
                // Calculate normalized light direction
                float3 lightDir = normalize(mainLight.direction);
                
                // Compute the cosine of the angle between normal and light direction
                float cosineAngle = max(dot(normalize(input.normalWS), lightDir), 0.0);
                
                // Determine if the current fragment is in shadow based on threshold
                float shadowMask = step(_ShadowThreshold, 1.0 - cosineAngle);
                
                // Quantize the lighting to create discrete shading levels
                float quantized = floor(cosineAngle * _Shades) / _Shades;

                // Base color of the material
                half4 baseColor = _Color;
                
                // Blend between base color and shadow color where shadowMask is true
                half4 finalColor = lerp(baseColor, _ShadeShadowColor, shadowMask);
                
                // Apply quantized shading to create toon effect
                finalColor = lerp(finalColor, baseColor, quantized);

                // Apply lighting color and shadow attenuation
                return finalColor * half4(mainLight.color, 1.0) * mainLight.shadowAttenuation;
            }
            // End of HLSL program block
            ENDHLSL
        }

        // Second Pass: Outline Rendering
        Pass
        {
            Name "Outline" // Name of the pass
            Tags { "LightMode" = "SRPDefaultUnlit" } // Uses unlit lighting mode

            // Cull front-facing polygons to render back-facing outlines
            Cull Front
            
            // Enable writing to the depth buffer
            ZWrite On
            
            // Depth test function
            ZTest LEqual

            // Begin HLSL program block
            HLSLPROGRAM
            // Specify the vertex and fragment shaders
            #pragma vertex Vertex
            #pragma fragment Fragment

            // Include core shader library from URP
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // Define material properties for the outline
            CBUFFER_START(UnityPerMaterial)
                half4 _OutlineColor; // Color of the outline
                float _OutlineThickness; // Thickness of the outline
            CBUFFER_END

            // Structure for input vertex attributes
            struct Attributes
            {
                float4 positionOS : POSITION; // Object-space position
                float3 normalOS : NORMAL; // Object-space normal
            };

            // Structure for passing data to fragment shader
            struct Varyings
            {
                float4 positionCS : SV_POSITION; // Clip-space position
            };

            // Vertex shader: Expands the object along normals to create outline effect
            Varyings Vertex(Attributes input)
            {
                Varyings output;

                // Get transformed vertex position
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                
                // Transform normal to world space
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

                // Calculate scaled normal based on outline thickness and object scale
                float3 scaledNormal = normalWS * _OutlineThickness * length(GetWorldToObjectMatrix()._m00_m11_m22);
                
                // Expand the vertex position along the normal
                vertexInput.positionWS.xyz += scaledNormal;

                // Transform the expanded position to clip space
                output.positionCS = TransformWorldToHClip(vertexInput.positionWS);
                return output;
            }

            // Fragment shader: Outputs the outline color
            half4 Fragment(Varyings input) : SV_Target
            {
                return _OutlineColor; // Set the fragment color to the outline color
            }
            // End of HLSL program block
            ENDHLSL
        }
    }
    
    // Fallback shader in case URP is not available; uses unlit shader
    FallBack "Universal Render Pipeline/Unlit"
}
