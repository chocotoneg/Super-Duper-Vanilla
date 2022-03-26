float getAmbientOcclusion(vec3 viewPos, vec3 normal, vec3 dither){
    float occlusion = 0.0;

    for(int i = 0; i < 8; i++){
        // Calculate the offsets
        vec3 sampleDir = normal + fract(dither + i * 0.125) - 0.5;
        // Add offsets to origin
        vec3 samplePos = viewPos + normalize(sampleDir) * 0.5;
        // Get the sample new depth and linearize
        float sampleDepth = toView(texture2D(depthtex0, toScreen(samplePos).xy).x);

        // Check if the offset points are inside geometry or if the point is occluded
        occlusion += sampleDepth > samplePos.z ? smoothen(0.5 / abs(viewPos.z - sampleDepth)) : 0.0;
    }
    
    // Invert results and 
    return 1.0 - occlusion * 0.125;
}