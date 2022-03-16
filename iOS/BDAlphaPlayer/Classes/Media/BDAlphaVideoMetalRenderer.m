//
//  BDAlphaPlayerMetalRenderer.m
//  BDAlphaPlayer
//
//  Created by ByteDance on 2020/4/23.
//

#import "BDAlphaVideoMetalRenderer.h"
#import "BDAlphaPlayerMetalShaderType.h"

#import <CoreVideo/CVMetalTexture.h>
#import <CoreVideo/CVMetalTextureCache.h>
#import <CoreVideo/CoreVideo.h>

@interface BDAlphaVideoMetalRenderer ()

@property (nonatomic, assign) CVMetalTextureCacheRef textureCache;
@property (nonatomic, assign) NSUInteger numVertices;

@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLTexture> texture;
@property (nonatomic, strong) id<MTLBuffer> vertices;
@property (nonatomic, strong) id<MTLBuffer> convertMatrix;

@end

@implementation BDAlphaVideoMetalRenderer

- (void)dealloc
{
    if (_textureCache) {
        CFRelease(_textureCache);
        _textureCache = NULL;
    }
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if (self = [super init]) {
        _device = device;
        [self setup];
    }
    return self;
}

- (void)setup
{
    [self setupCache];
    [self setupMatrix];
    [self setupVertex];
    [self setupPipeline];
}

- (void)setupCache
{
    if (!_textureCache) {
        CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL, self.device, NULL, &_textureCache);
    }
}

- (void)setupMatrix
{
    // Coding Matrices https://www.mir.com/DMG/ycbcr.html
    matrix_float3x3 kColorConversion601FullRangeMatrix = (matrix_float3x3){
        (simd_float3){1.0, 1.0, 1.0},
        (simd_float3){0.0, -0.344136, 1.772},
        (simd_float3){1.402, -0.714136, 0.0},
    };
    
    vector_float3 kColorConversion601FullRangeOffset = (vector_float3){ 0, -0.5, -0.5};
    
    BDAlphaPlayerConvertMatrix matrix;
    matrix.matrix = kColorConversion601FullRangeMatrix;
    matrix.offset = kColorConversion601FullRangeOffset;
    
    self.convertMatrix = [self.device newBufferWithBytes:&matrix
                                                  length:sizeof(BDAlphaPlayerConvertMatrix)
                                                 options:MTLResourceStorageModeShared];
}

- (void)setupVertex
{
    static const BDAlphaPlayerVertex quadVertices[] =
    {   // 顶点坐标，分别是x、y、z、w；    纹理坐标，x、y；
        { {  1.0, -1.0, 0.0, 1.0 },  { 1.f, 1.f } },
        { { -1.0, -1.0, 0.0, 1.0 },  { 0.f, 1.f } },
        { { -1.0,  1.0, 0.0, 1.0 },  { 0.f, 0.f } },
        
        { {  1.0, -1.0, 0.0, 1.0 },  { 1.f, 1.f } },
        { { -1.0,  1.0, 0.0, 1.0 },  { 0.f, 0.f } },
        { {  1.0,  1.0, 0.0, 1.0 },  { 1.f, 0.f } },
    };
    self.vertices = [self.device newBufferWithBytes:quadVertices
                                             length:sizeof(quadVertices)
                                            options:MTLResourceStorageModeShared];
    self.numVertices = sizeof(quadVertices) / sizeof(BDAlphaPlayerVertex);
}

- (void)setupPipeline
{
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"BDAlphaPlayer.bundle/default" ofType:@"metallib"];
    NSError *error = nil;
    id<MTLLibrary> defaultLibrary = [self.device newLibraryWithFile:filePath error:&error];
    id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
    id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"samplingShader"];
    
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.vertexFunction = vertexFunction;
    pipelineStateDescriptor.fragmentFunction = fragmentFunction;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineStateDescriptor.colorAttachments[0].blendingEnabled = NO; // 由于clearColor是(0,0,0,0)，可以不启用blend
    pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
    pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    self.pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:NULL];
    self.commandQueue = [self.device newCommandQueue];
}

- (void)renderPixelBuffer:(CVPixelBufferRef)pixelBuffer toPixelBuffer:(CVPixelBufferRef)outputPixelBuffer
{
    CVMetalTextureRef renderTextureRef = NULL;
    NSDictionary *textureAttributes = nil;
    if (@available(iOS 11.0, *)) {
        textureAttributes = @{
            (id)kCVMetalTextureUsage: @(MTLTextureUsageRenderTarget),
        };
    }
    if (@available(iOS 13.0, macOS 10.15, *)) {
        textureAttributes = @{
            (id)kCVMetalTextureUsage: @(MTLTextureUsageRenderTarget),
            (id)kCVMetalTextureStorageMode: @(MTLStorageModeShared)
        };
    }
    size_t textureWidth = CVPixelBufferGetWidth(outputPixelBuffer);
    size_t textureHeight = CVPixelBufferGetHeight(outputPixelBuffer);
    CVReturn status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _textureCache, outputPixelBuffer, (__bridge CFDictionaryRef)textureAttributes, MTLPixelFormatBGRA8Unorm, textureWidth, textureHeight, 0, &renderTextureRef);
    if (status != kCVReturnSuccess || renderTextureRef == NULL) {
        return;
    }
    
    MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    renderPassDescriptor.colorAttachments[0].texture = CVMetalTextureGetTexture(renderTextureRef);
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    CFRelease(renderTextureRef);
    
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [renderEncoder setViewport:(MTLViewport){0.0, 0.0, textureWidth, textureHeight, -1.0, 1.0 }];
    [renderEncoder setRenderPipelineState:self.pipelineState];
    [renderEncoder setVertexBuffer:self.vertices
                            offset:0
                           atIndex:BDAlphaPlayerVertexInputIndexVertices];
    id<MTLTexture> textureY = nil;
    id<MTLTexture> textureUV = nil;
    // textureY
    {
        size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        MTLPixelFormat pixelFormat = MTLPixelFormatR8Unorm;
        
        CVMetalTextureRef texture = NULL;
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, self.textureCache, pixelBuffer, NULL, pixelFormat, width, height, 0, &texture);
        if (status == kCVReturnSuccess) {
            textureY = CVMetalTextureGetTexture(texture);
            CFRelease(texture);
        }
    }
    // textureUV
    {
        size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
        MTLPixelFormat pixelFormat = MTLPixelFormatRG8Unorm;
        
        CVMetalTextureRef texture = NULL;
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, self.textureCache, pixelBuffer, NULL, pixelFormat, width, height, 1, &texture);
        if (status == kCVReturnSuccess) {
            textureUV = CVMetalTextureGetTexture(texture);
            CFRelease(texture);
        }
    }
    
    if (textureY != nil && textureUV != nil) {
        [renderEncoder setFragmentTexture:textureY
                                  atIndex:BDAlphaPlayerFragmentTextureIndexTextureY];
        [renderEncoder setFragmentTexture:textureUV
                                  atIndex:BDAlphaPlayerFragmentTextureIndexTextureUV];
    }
    [renderEncoder setFragmentBuffer:self.convertMatrix
                              offset:0
                             atIndex:BDAlphaPlayerFragmentInputIndexMatrix];
    
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                      vertexStart:0
                      vertexCount:self.numVertices];
    
    [renderEncoder endEncoding];
    [commandBuffer commit];
    [commandBuffer waitUntilScheduled];
}

- (void)flush
{
    if (_textureCache) {
        CVMetalTextureCacheFlush(_textureCache, 0);
    }
}

@end
