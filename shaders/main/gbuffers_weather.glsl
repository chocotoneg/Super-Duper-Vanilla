/*
================================ /// Super Duper Vanilla v1.3.3 /// ================================

    Developed by Eldeston, presented by FlameRender (TM) Studios.

    Copyright (C) 2020 Eldeston | FlameRender (TM) Studios License


    By downloading this content you have agreed to the license and its terms of use.

================================ /// Super Duper Vanilla v1.3.3 /// ================================
*/

/// Buffer features: TAA jittering, and direct shading

/// -------------------------------- /// Vertex Shader /// -------------------------------- ///

#ifdef VERTEX
    #ifdef FORCE_DISABLE_WEATHER
        void main(){
            gl_Position = vec4(-10);
        }
    #else
        out float lmCoordX;

        out vec2 texCoord;

        #if ANTI_ALIASING == 2
            uniform float viewWidth;
            uniform float viewHeight;

            #include "/lib/utility/taaJitter.glsl"
        #endif

        #ifdef WEATHER_ANIMATION
            uniform mat4 gbufferModelView;
            uniform mat4 gbufferModelViewInverse;

            uniform vec3 cameraPosition;

            uniform float rainStrength;

            #if TIMELAPSE_MODE == 2
                uniform float animationFrameTime;

                float newFrameTimeCounter = animationFrameTime;
            #else
                uniform float frameTimeCounter;

                float newFrameTimeCounter = frameTimeCounter;
            #endif

            #include "/lib/vertex/weatherWave.glsl"
        #endif

        void main(){
            // Lightmap fix for mods
            lmCoordX = saturate(gl_MultiTexCoord1.x * 0.00416667);
            // Get buffer texture coordinates
            texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

            #ifdef WEATHER_ANIMATION
                if(rainStrength > 0.005){
                    // Get vertex position (feet player pos)
                    vec4 vertexPos = gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex);

                    // Apply weather wave animation
                    vertexPos.xz = getWeatherWave(vertexPos.xyz, vertexPos.xz + cameraPosition.xz);

                    // Convert to clip pos and output as position
                    gl_Position = gl_ProjectionMatrix * (gbufferModelView * vertexPos);
                }
                else gl_Position = ftransform();
            #else
                gl_Position = ftransform();
            #endif

            #if ANTI_ALIASING == 2
                gl_Position.xy += jitterPos(gl_Position.w);
            #endif
        }
    #endif
#endif

/// -------------------------------- /// Fragment Shader /// -------------------------------- ///

#ifdef FRAGMENT
    #ifdef FORCE_DISABLE_WEATHER
        void main(){
            discard;
        }
    #else
        in float lmCoordX;

        in vec2 texCoord;

        uniform float nightVision;

        uniform sampler2D tex;

        #ifndef FORCE_DISABLE_DAY_CYCLE
            uniform float dayCycle;
        #endif

        #ifdef WORLD_VANILLA_FOG_COLOR
            uniform vec3 fogColor;
        #endif
        
        void main(){
            // Get albedo color
            vec4 albedo = textureLod(tex, texCoord, 0);

            // Alpha test, discard immediately
            if(albedo.a <= ALPHA_THRESHOLD) discard;

            // Convert to linear space
            albedo.rgb = toLinear(albedo.rgb);

        /* DRAWBUFFERS:0 */
            gl_FragData[0] = vec4(albedo.rgb * (toLinear(SKY_COL_DATA_BLOCK) + toLinear((lmCoordX * BLOCKLIGHT_I * 0.00392156863) * vec3(BLOCKLIGHT_R, BLOCKLIGHT_G, BLOCKLIGHT_B)) + toLinear(AMBIENT_LIGHTING + nightVision * 0.5)), albedo.a); // gcolor
        }
    #endif
#endif