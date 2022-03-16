//
//  shaders.metal
//  BDAlphaPlayer
//
//  Created by ByteDance on 2018/6/21.
//  Copyright © 2018年 ByteDance. All rights reserved.
//

#include <metal_stdlib>
#include "BDAlphaPlayerMetalShaderType.h"

using namespace metal;

typedef struct {
    float4 clipSpacePosition [[position]];
    float2 textureCoordinate;
} RasterizerData;

vertex RasterizerData vertexShader(uint vertexID [[ vertex_id ]],
             constant BDAlphaPlayerVertex *vertexArray [[ buffer(BDAlphaPlayerVertexInputIndexVertices) ]]) {
    RasterizerData out;
    out.clipSpacePosition = vertexArray[vertexID].position;
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
    return out;
}

fragment float4 samplingShader(RasterizerData input [[stage_in]],
               texture2d<float> textureY [[ texture(BDAlphaPlayerFragmentTextureIndexTextureY) ]],
               texture2d<float> textureUV [[ texture(BDAlphaPlayerFragmentTextureIndexTextureUV) ]],
               constant BDAlphaPlayerConvertMatrix *convertMatrix [[ buffer(BDAlphaPlayerFragmentInputIndexMatrix) ]])
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    
    float videoR = textureY.sample(textureSampler, float2(input.textureCoordinate.x * 0.5, input.textureCoordinate.y)).r;
    float2 videoRG = textureUV.sample(textureSampler, float2(input.textureCoordinate.x * 0.5, input.textureCoordinate.y)).rg;
    float3 videoRGB = convertMatrix->matrix * (float3(videoR, videoRG) + convertMatrix->offset);
    
    float alphaR = textureY.sample(textureSampler, float2(input.textureCoordinate.x * 0.5 + 0.5, input.textureCoordinate.y)).r;
    float2 alphaRG = textureUV.sample(textureSampler, float2(input.textureCoordinate.x * 0.5 + 0.5, input.textureCoordinate.y)).rg;
    float3 alphaRGB = convertMatrix->matrix * (float3(alphaR, alphaRG) + convertMatrix->offset);
    
    return float4(videoRGB, alphaRGB.r);
}


