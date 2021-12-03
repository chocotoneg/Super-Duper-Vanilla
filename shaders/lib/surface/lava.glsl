float getCellNoise2(vec2 st){
    float animateTime = ANIMATION_SPEED * frameTimeCounter;
    float d0 = texture2D(noisetex, st + animateTime * 0.032).z;
    float d1 = texPix2DBilinear(noisetex, st / 64.0 - animateTime * 0.001, vec2(noiseTextureResolution)).y;

    return 1.0 - (d0 + d1) * 0.5;
}