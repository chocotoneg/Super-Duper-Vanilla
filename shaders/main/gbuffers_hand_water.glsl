/// ------------------------------------- /// Vertex Shader /// ------------------------------------- ///

#ifdef VERTEX
    #ifdef WORLD_LIGHT
        flat out vec3 shdLightView;

        #ifdef SHD_ENABLE
            out vec3 shdPos;

            out float distortFactor;
        #endif
    #endif

    flat out mat3 TBN;

    flat out vec3 vertexColor;

    out vec2 lmCoord;
    out vec2 texCoord;

    #ifdef PARALLAX_OCCLUSION
        flat out vec2 vTexCoordScale;
        flat out vec2 vTexCoordPos;
        out vec2 vTexCoord;
    #endif

    out vec4 vertexPos;

    // View matrix uniforms
    uniform mat4 gbufferModelView;
    uniform mat4 gbufferModelViewInverse;

    #ifdef WORLD_LIGHT
        // Shadow view matrix uniforms
        uniform mat4 shadowModelView;

        #ifdef SHD_ENABLE
            // Shadow projection matrix uniforms
            uniform mat4 shadowProjection;

            #include "/lib/lighting/shdDistort.glsl"
        #endif
    #endif

    #if ANTI_ALIASING == 2
        /* Screen resolutions */
        uniform float viewWidth;
        uniform float viewHeight;

        #include "/lib/utility/taaJitter.glsl"
    #endif

    attribute vec4 at_tangent;

    #ifdef PARALLAX_OCCLUSION
        attribute vec4 mc_midTexCoord;
    #endif

    void main(){
        // Get texture coordinates
        texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        // Get vertex color
        vertexColor = gl_Color.rgb;

        // Get vertex tangent
        vec3 vertexTangent = normalize(at_tangent.xyz);
        // Get vertex normal
        vec3 vertexNormal = normalize(gl_Normal);

        // Get vertex position (view player pos)
        vertexPos = gl_ModelViewMatrix * gl_Vertex;
        // Get feet player pos
        vec4 feetPlayerPos = gbufferModelViewInverse * vertexPos;

        // Calculate TBN matrix
	    TBN = gl_NormalMatrix * mat3(vertexTangent, cross(vertexTangent, vertexNormal), vertexNormal);

        #ifdef WORLD_LIGHT
            // Shadow light view matrix
            shdLightView = mat3(gbufferModelView) * vec3(shadowModelView[0].z, shadowModelView[1].z, shadowModelView[2].z);

            #ifdef SHD_ENABLE
                // Get shadow clip space pos
                shdPos = mat3(shadowProjection) * (mat3(shadowModelView) * feetPlayerPos.xyz + shadowModelView[3].xyz) + shadowProjection[3].xyz;
                // Get distortion factor
                distortFactor = getDistortFactor(shdPos.xy);

                // Bias mutilplier, adjusts according to the current shadow distance and resolution
				float biasAdjustMult = log2(max(4.0, shadowDistance - shadowMapResolution * 0.125)) * 0.25;

                // Apply shadow bias
                shdPos += (mat3(shadowProjection) * (mat3(shadowModelView) * (mat3(gbufferModelViewInverse) * TBN[2]))) * distortFactor * biasAdjustMult;
            #endif
        #endif

        // Lightmap fix for mods
        #ifdef WORLD_SKYLIGHT
            lmCoord = vec2(saturate(((gl_TextureMatrix[1] * gl_MultiTexCoord1).x - 0.03125) * 1.06667), WORLD_SKYLIGHT);
        #else
            lmCoord = saturate(((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy - 0.03125) * 1.06667);
        #endif

        #ifdef PARALLAX_OCCLUSION
            vec2 midCoord = (gl_TextureMatrix[0] * mc_midTexCoord).xy;
            vec2 texMinMidCoord = texCoord - midCoord;

            vTexCoordScale = abs(texMinMidCoord) * 2.0;
            vTexCoordPos = min(texCoord, midCoord - texMinMidCoord);
            vTexCoord = sign(texMinMidCoord) * 0.5 + 0.5;
        #endif

        gl_Position = ftransform();

        #if ANTI_ALIASING == 2
            gl_Position.xy += jitterPos(gl_Position.w);
        #endif
    }
#endif

/// ------------------------------------- /// Fragment Shader /// ------------------------------------- ///

#ifdef FRAGMENT
    #ifdef WORLD_LIGHT
        flat in vec3 shdLightView;

        #ifdef SHD_ENABLE
            in vec3 shdPos;

            in float distortFactor;
        #endif
    #endif

    flat in mat3 TBN;

    flat in vec3 vertexColor;

    in vec2 lmCoord;
    in vec2 texCoord;

    #ifdef PARALLAX_OCCLUSION
        flat in vec2 vTexCoordScale;
        flat in vec2 vTexCoordPos;
        in vec2 vTexCoord;
    #endif

    in vec4 vertexPos;

    // Get albedo texture
    uniform sampler2D texture;

    // Get entity id
    uniform int entityId;

    // Get is eye in water
    uniform int isEyeInWater;

    // Get night vision
    uniform float nightVision;

    #if ANTI_ALIASING >= 2
        // Get frame time
        uniform float frameTimeCounter;
    #endif

    // Get entity color
    uniform vec4 entityColor;

    // Texture coordinate derivatives
    vec2 dcdx = dFdx(texCoord);
    vec2 dcdy = dFdy(texCoord);

    #include "/lib/universalVars.glsl"

    #include "/lib/utility/noiseFunctions.glsl"

    #include "/lib/lighting/shdDistort.glsl"
    #include "/lib/lighting/shdMapping.glsl"
    #include "/lib/lighting/GGX.glsl"

    #include "/lib/PBR/structPBR.glsl"

    #if PBR_MODE <= 1
        #include "/lib/PBR/defaultPBR.glsl"
    #else
        #include "/lib/PBR/labPBR.glsl"
    #endif

    #include "/lib/lighting/complexShadingForward.glsl"
    
    void main(){
        // Declare materials
	    structPBR material;
        getPBR(material, entityId);

        material.albedo.rgb = mix(material.albedo.rgb, entityColor.rgb, entityColor.a);

        material.albedo.rgb = toLinear(material.albedo.rgb);

        vec4 sceneCol = complexShadingGbuffers(material);

    /* DRAWBUFFERS:0123 */
        gl_FragData[0] = sceneCol; // gcolor
        gl_FragData[1] = vec4(material.normal, 1); // colortex1
        gl_FragData[2] = vec4(material.albedo.rgb, 1); // colortex2
        gl_FragData[3] = vec4(material.metallic, material.smoothness, 0, 1); // colortex3
    }
#endif