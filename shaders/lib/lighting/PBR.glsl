// Derivatives
vec2 dcdx = dFdx(texCoord);
vec2 dcdy = dFdy(texCoord);

uniform sampler2D texture;

#ifdef AUTO_GEN_NORM
#endif

#if (defined TERRAIN || defined WATER || defined BLOCK) && defined ENVIRO_MAT
    uniform float isWarm;
    uniform float isSnowy;
    uniform float isPeaks;
    uniform float wetness;

    void enviroPBR(inout matPBR material, in vec3 worldPos){
        float rainMatFact = sqrt(max(0.0, TBN[2].y)) * smoothstep(0.8, 0.9, material.light.y) * wetness * (1.0 - isWarm) * (1.0 - isSnowy) * (1.0 - isPeaks);

        if(rainMatFact != 0){
            vec3 noiseData = texPix2DCubic(noisetex, worldPos.xz / 512.0, vec2(noiseTextureResolution)).xyz;
            rainMatFact *= smoothstep(0.4, 0.8, (mix(noiseData.y, noiseData.x, noiseData.z) + noiseData.y) * 0.5);
            
            material.normal = mix(material.normal, TBN[2], rainMatFact);
            material.metallic = max(0.02 * rainMatFact, material.metallic);
            material.smoothness = mix(material.smoothness, 0.96, rainMatFact);
            material.albedo.rgb *= 1.0 - sqrt(rainMatFact) * 0.25;
        }
    }
#endif

#if DEFAULT_MAT == 2
    uniform sampler2D normals;
    uniform sampler2D specular;

    // This is for Optifine to detect the option...
    #ifdef PARALLAX_OCCLUSION
    #endif

    #ifdef PARALLAX_SHADOWS
    #endif

    #if (defined TERRAIN || defined WATER || defined BLOCK || defined ENTITIES || defined HAND || defined ENTITIES_GLOWING || defined HAND_WATER) && defined PARALLAX_OCCLUSION
        vec2 getParallaxOffset(vec3 dirT){
            return normalize(dirT.xy) * (sqrt(lengthSquared(dirT) - squared(dirT.z)) * PARALLAX_DEPTH / dirT.z);
        }

        vec2 parallaxUv(vec2 startUv, vec2 endUv, out vec3 currPos){
            float stepSize = 1.0 / PARALLAX_STEPS;
            endUv *= stepSize * PARALLAX_DEPTH;

            float texDepth = texture2DGradARB(normals, fract(startUv) * vTexCoordScale + vTexCoordPos, dcdx, dcdy).a;
            float traceDepth = 1.0;

            for(int i = 0; i < PARALLAX_STEPS; i++){
                if(texDepth >= traceDepth) break;
                startUv += endUv;
                traceDepth -= stepSize;
                texDepth = texture2DGradARB(normals, fract(startUv) * vTexCoordScale + vTexCoordPos, dcdx, dcdy).a;
            }

            currPos = vec3(startUv - endUv, traceDepth + stepSize);
            return startUv;
        }

        #if defined PARALLAX_SHADOWS && defined WORLD_LIGHT
            float parallaxShadow(vec3 currPos, vec2 lightDir) {
                float stepSize = 1.0 / PARALLAX_SHD_STEPS;
                vec2 stepOffset = stepSize * lightDir;
                
                float traceDepth = currPos.z;
                vec2 traceUv = currPos.xy;

                for(int i = int(traceDepth * PARALLAX_SHD_STEPS); i < PARALLAX_SHD_STEPS; i++){
                    if(texture2DGradARB(normals, fract(traceUv) * vTexCoordScale + vTexCoordPos, dcdx, dcdy).a >= traceDepth) return pow(i * stepSize, 16.0);
                    // if(texture2DGradARB(normals, fract(traceUv) * vTexCoordScale + vTexCoordPos, dcdx, dcdy).a >= traceDepth) return 0.0;
                    traceUv += stepOffset;
                    traceDepth += stepSize;
                }

                return 1.0;
            }
        #endif

        #ifdef SLOPE_NORMALS
            vec2 getSlopeNormals(vec3 viewT, vec2 texUv, float traceDepth){
                vec2 texRes = textureSize(normals, 0);
                vec2 texPixSize = 1.0 / texRes;

                vec2 texSnapped = floor(texUv * texRes) * texPixSize;
                vec2 texOffset = texUv - texSnapped - 0.5 * texPixSize;
                vec2 stepSign = sign(-viewT.xy);

                vec2 texX = texSnapped + vec2(texPixSize.x * stepSign.x, 0);
                float heightX = texture2DGradARB(normals, texX, dcdx, dcdy).a;
                bool hasX = traceDepth > heightX && sign(texOffset.x) == stepSign.x;

                vec2 texY = texSnapped + vec2(0, texPixSize.y * stepSign.y);
                float heightY = texture2DGradARB(normals, texY, dcdx, dcdy).a;
                bool hasY = traceDepth > heightY && sign(texOffset.y) == stepSign.y;

                if(abs(texOffset.x) < abs(texOffset.y)){
                    if(hasY) return vec2(0, stepSign.y);
                    if(hasX) return vec2(stepSign.x, 0);
                } else {
                    if(hasX) return vec2(stepSign.x, 0);
                    if(hasY) return vec2(0, stepSign.y);
                }

                float s = step(abs(viewT.y), abs(viewT.x));
                return vec2(1.0 - s, s) * stepSign;
            }
        #endif
    #endif

    void getPBR(inout matPBR material, in positionVectors posVector, in int id){
        // Assign default normal map
        material.normal = TBN[2];

        vec2 texUv = texCoord;

        #if (defined TERRAIN || defined WATER || defined BLOCK || defined ENTITIES || defined HAND || defined ENTITIES_GLOWING || defined HAND_WATER) && defined PARALLAX_OCCLUSION
            vec3 viewDir = -posVector.eyePlayerPos * TBN;

            vec3 currPos;
            
            // Exclude signs, due to a missing text bug
            if(id != 10019) texUv = fract(parallaxUv(vTexCoord, viewDir.xy / -viewDir.z, currPos)) * vTexCoordScale + vTexCoordPos;
        #endif

        // Assign albedo
        material.albedo = texture2DGradARB(texture, texUv, dcdx, dcdy);

        // Alpha test, discard immediately
        if(material.albedo.a <= ALPHA_THRESHOLD) discard;

        // Get raw textures
        vec4 normalAOH = texture2DGradARB(normals, texUv, dcdx, dcdy);

        vec4 SRPSSE = texture2DGradARB(specular, texUv, dcdx, dcdy);

        // Decode and extract the materials
        // Extract normals
        vec3 normalMap = vec3(normalAOH.xy * 2.0 - 1.0, 0);
        normalMap.z = sqrt(1.0 - dot(normalMap.xy, normalMap.xy));

        // Assign SS
        material.ss = saturate((SRPSSE.b * 255.0 - 64.0) / (255.0 - 64.0));

        // Assign smoothness
        material.smoothness = SRPSSE.r;

        // Assign reflectance
        material.metallic = SRPSSE.g;

        // Assign emissive
        material.emissive = SRPSSE.a * float(SRPSSE.a != 1);

        // Assign ambient
        #ifdef TERRAIN
            // Apply vanilla AO with it in terrain
            material.ambient = glcolor.a * normalAOH.b;
        #else
            // For others, don't use vanilla AO
            material.ambient = normalAOH.b;
        #endif

        #if defined TERRAIN || defined BLOCK
            // If lava and fire
            if(id == 10002 || id == 10003) material.emissive = 1.0;

            // Foliage and corals
            else if((id >= 10004 && id <= 10016) || id == 10036 || id == 10037) material.ss = 1.0;
        #endif

        // Get parallax shadows
        material.parallaxShd = 1.0;

        #if (defined TERRAIN || defined WATER || defined BLOCK || defined ENTITIES || defined HAND || defined ENTITIES_GLOWING || defined HAND_WATER) && defined PARALLAX_OCCLUSION
            if(id != 10019){
                #ifdef SLOPE_NORMALS
                    if(texture2DGradARB(normals, texUv, dcdx, dcdy).a > currPos.z) normalMap = vec3(getSlopeNormals(-viewDir, texUv, currPos.z), 0);
                #endif

                #if defined PARALLAX_SHADOWS && defined WORLD_LIGHT
                    if(dot(material.normal, vec3(shadowModelView[0].z, shadowModelView[1].z, shadowModelView[2].z)) > 0.000001)
                        material.parallaxShd = parallaxShadow(currPos, getParallaxOffset(vec3(shadowModelView[0].z, shadowModelView[1].z, shadowModelView[2].z) * TBN));
                    else material.parallaxShd = material.ss;
                #endif
            }
        #endif

        // Assign normal
        material.normal = normalize(TBN * normalMap);

        #if defined WATER || defined BLOCK
            // If water
            if(id == 10001){
                material.smoothness = 0.96;
                material.metallic = 0.02;
            }

            // End portal
            else if(id == 10017){
                vec3 d0 = texture2DGradARB(texture, (posVector.screenPos.yx + vec2(0, frameTimeCounter * 0.02)) * 0.5, dcdx, dcdy).rgb;
                vec3 d1 = texture2DGradARB(texture, (posVector.screenPos.yx + vec2(0, frameTimeCounter * 0.01)), dcdx, dcdy).rgb;
                material.albedo = vec4(d0 + d1 + 0.05, 1);
                material.normal = TBN[2];
                material.smoothness = 0.96;
                material.metallic = 0.04;
                material.emissive = 1.0;
            }
            
            // Nether portal
            else if(id == 10018){
                material.smoothness = 0.96;
                material.metallic = 0.04;
                material.emissive = maxC(material.albedo.rgb);
            }
        #endif

        #if WHITE_MODE == 0
            material.albedo.rgb *= glcolor.rgb;
        #elif WHITE_MODE == 1
            material.albedo.rgb = vec3(1);
        #elif WHITE_MODE == 2
            material.albedo.rgb = vec3(0);
        #elif WHITE_MODE == 3
            material.albedo.rgb = glcolor.rgb;
        #endif

        material.smoothness = min(material.smoothness, 0.96);

        // Ambient occlusion fix
        #if defined HAND || defined HAND_WATER
            if(id == 0) material.ambient = 1.0;
        #endif
    }
#else
    void getPBR(inout matPBR material, in positionVectors posVector, in int id){
        // Assign default normal map
        material.normal = TBN[2];

        vec2 texUv = texCoord;

        // Assign albedo
        material.albedo = texture2DGradARB(texture, texUv, dcdx, dcdy);

        // Alpha test, discard immediately
        if(material.albedo.a <= ALPHA_THRESHOLD) discard;

        // Generate bumped normals
        #if (defined TERRAIN || defined WATER || defined BLOCK) && defined AUTO_GEN_NORM
            float d = length(material.albedo.rgb);
            float dx = d - length(texture2DGradARB(texture, fract(vTexCoord + vec2(0.0125, 0)) * vTexCoordScale + vTexCoordPos, dcdx, dcdy).rgb);
            float dy = d - length(texture2DGradARB(texture, fract(vTexCoord + vec2(0, 0.0125)) * vTexCoordScale + vTexCoordPos, dcdx, dcdy).rgb);

            material.normal = normalize(TBN * normalize(vec3(dx, dy, 0.125)));
        #endif

        // Default material if not specified
        material.metallic = 0.04; material.emissive = 0.0;
        material.smoothness = 0.0; material.ss = 0.0;
        material.ambient = glcolor.a; material.parallaxShd = 1.0;

        #if (defined TERRAIN || defined WATER || defined BLOCK) && DEFAULT_MAT == 1
            vec3 hsv = saturate(rgb2hsv(material.albedo));
            float sumCol = saturate(material.albedo.r + material.albedo.g + material.albedo.b);
        #endif

        #if defined TERRAIN || defined BLOCK
            // If lava and fire
            if(id == 10002 || id == 10003) material.emissive = 1.0;

            // Foliage and corals
            else if((id >= 10004 && id <= 10016) || id == 10036 || id == 10037) material.ss = 1.0;
        #endif

        #if defined WATER || defined BLOCK
            // If water
            if(id == 10001){
                material.smoothness = 0.96;
                material.metallic = 0.02;
            }

            // End portal
            else if(id == 10017){
                vec3 d0 = texture2DGradARB(texture, (posVector.screenPos.yx + vec2(0, frameTimeCounter * 0.02)) * 0.5, dcdx, dcdy).rgb;
                vec3 d1 = texture2DGradARB(texture, (posVector.screenPos.yx + vec2(0, frameTimeCounter * 0.01)), dcdx, dcdy).rgb;
                material.albedo = vec4(d0 + d1 + 0.05, 1);
                material.normal = TBN[2];
                material.smoothness = 0.96;
                material.metallic = 0.04;
                material.emissive = 1.0;
            }
            
            // Nether portal
            else if(id == 10018){
                material.smoothness = 0.96;
                material.metallic = 0.04;
                material.emissive = maxC(material.albedo.rgb);
            }
        #endif

        #if WHITE_MODE == 0
            material.albedo.rgb *= glcolor.rgb;
        #elif WHITE_MODE == 1
            material.albedo.rgb = vec3(1);
        #elif WHITE_MODE == 2
            material.albedo.rgb = vec3(0);
        #elif WHITE_MODE == 3
            material.albedo.rgb = glcolor.rgb;
        #endif
        
        #if DEFAULT_MAT == 1
            #if defined TERRAIN || defined BLOCK
                // Glow berries
                if(id == 10033) material.emissive = max2(material.albedo.rg) > 0.8 ? 0.72 : material.emissive;

                // Stems
                else if(id == 10034) material.emissive = material.albedo.r < 0.1 ? hsv.z * 0.72 : material.emissive;
                else if(id == 10035) material.emissive = material.albedo.b < 0.16 && material.albedo.r > 0.4 ? hsv.z * 0.72 : material.emissive;

                // Fungus
                else if(id == 10036) material.emissive = max2(material.albedo.rg) > 0.8 ? 0.72 : material.emissive;

                // Emissives
                else if(id == 10038) material.emissive = smoothstep(0.6, 0.8, hsv.z);

                // Redstone
                else if(id == 10039 || id == 10068){
                    material.emissive = cubed(material.albedo.r) * hsv.y;
                    material.smoothness = material.emissive;
                    material.metallic = step(0.8, material.emissive);
                }

                // Gem ores
                else if(id == 10048){
                    material.smoothness = hsv.y > 0.128 ? 0.93 : material.smoothness;
                    material.metallic = hsv.y > 0.128 ? 0.17 : material.metallic;
                }

                // Gem blocks
                else if(id == 10050){
                    material.smoothness = 0.96;
                    material.metallic = 0.17;
                }

                // Netherack gem ores
                else if(id == 10049){
                    material.smoothness = hsv.y < 0.256 ? 0.93 : material.smoothness;
                    material.metallic = hsv.y < 0.256 ? 0.16 : material.metallic;
                }

                // Metal ores
                else if(id == 10064){
                    material.smoothness = hsv.y > 0.128 ? 0.93 : material.smoothness;
                    material.metallic = hsv.y > 0.128 ? 1.0 : material.metallic;
                }

                // Netherack metal ores
                else if(id == 10065){
                    material.smoothness = max2(material.albedo.rg) > 0.6 ? 0.93 : material.smoothness;
                    material.metallic = max2(material.albedo.rg) > 0.6 ? 1.0 : material.metallic;
                }

                // Metal blocks
                else if(id == 10066){
                    material.smoothness = hsv.z * hsv.z;
                    material.metallic = 1.0;
                }

                // Dark metals
                else if(id == 10067){
                    material.smoothness = sumCol;
                    material.metallic = 1.0;
                }

                // Rails
                else if(id == 10068){
                    material.smoothness = hsv.y < 0.128 ? 0.96 : material.smoothness;
                    material.metallic = hsv.y < 0.128 ? 1.0 : material.metallic;
                }

                // Polished blocks
                else if(id == 10080) material.smoothness = sumCol;
            #endif

            #if defined WATER || defined BLOCK
                // Glass and ice
                if(id == 10041 || id == 10042) material.smoothness = 0.96;

                // Gelatin
                else if(id == 10043) material.smoothness = 0.96;
            #endif
        #endif

        material.smoothness = min(material.smoothness, 0.96);
    }
#endif
