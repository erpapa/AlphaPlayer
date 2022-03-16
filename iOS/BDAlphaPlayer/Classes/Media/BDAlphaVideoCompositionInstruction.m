//
//  BDAlphaVideoCompositionInstruction.m
//  testVideoFilter
//
//  Created by Lyman Li on 2020/3/8.
//  Copyright © 2020 Lyman Li. All rights reserved.
//

#import "BDAlphaVideoCompositionInstruction.h"
#import "BDAlphaVideoFilter.h"
#import "BDAlphaVideoMetalRenderer.h"

@interface BDAlphaVideoCompositionInstruction ()

@property (nonatomic, strong) CIContext *context;
@property (nonatomic, strong) BDAlphaVideoFilter *filter;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) BDAlphaVideoMetalRenderer *renderer;

@end

@implementation BDAlphaVideoCompositionInstruction

- (instancetype)initWithPassthroughTrackID:(CMPersistentTrackID)passthroughTrackID timeRange:(CMTimeRange)timeRange {
    self = [super init];
    if (self) {
        _passthroughTrackID = passthroughTrackID;
        _timeRange = timeRange;
        _requiredSourceTrackIDs = @[];
        _containsTweening = NO;
        _enablePostProcessing = NO;
//        _context = [CIContext contextWithOptions:@{kCIContextWorkingColorSpace:[NSNull null]}];
//        _filter = [[BDAlphaVideoFilter alloc] init];
        _device = MTLCreateSystemDefaultDevice();
        _renderer = [[BDAlphaVideoMetalRenderer alloc] initWithDevice:_device];
    }
    return self;
}

- (instancetype)initWithSourceTrackIDs:(NSArray<NSValue *> *)sourceTrackIDs timeRange:(CMTimeRange)timeRange {
    self = [super init];
    if (self) {
        _requiredSourceTrackIDs = sourceTrackIDs;
        _timeRange = timeRange;
        _passthroughTrackID = kCMPersistentTrackID_Invalid;
        _containsTweening = YES;
        _enablePostProcessing = NO;
//        _context = [CIContext contextWithOptions:@{kCIContextWorkingColorSpace:[NSNull null]}];
//        _filter = [[BDAlphaVideoFilter alloc] init];
        _device = MTLCreateSystemDefaultDevice();
        _renderer = [[BDAlphaVideoMetalRenderer alloc] initWithDevice:_device];
    }
    return self;
}

#pragma mark - Public

- (CVPixelBufferRef)applyPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    return [self applyPixelBuffer:pixelBuffer fromRequest:nil];
}
    
- (CVPixelBufferRef)applyPixelBuffer:(CVPixelBufferRef)pixelBuffer fromRequest:(AVAsynchronousVideoCompositionRequest *)request {
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    CGSize outputSize = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer) * 0.5, CVPixelBufferGetHeight(pixelBuffer));
    CVPixelBufferRef outputPixelBuffer = NULL;
    if (request && CGSizeEqualToSize(request.renderContext.size, outputSize)) {
        outputPixelBuffer = [request.renderContext newPixelBuffer];
    } else {
        outputPixelBuffer = [self createPixelBufferWithSize:outputSize];
    }
    if (self.context && self.filter) {
        self.filter.inputImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
        CIImage *outputImage = self.filter.outputImage;
        CIImage *scaleImage = [outputImage imageByApplyingTransform:CGAffineTransformMakeScale(0.5, 1.0)];
        [self.context render:scaleImage toCVPixelBuffer:outputPixelBuffer];
    } else {
        [self.renderer renderPixelBuffer:pixelBuffer toPixelBuffer:outputPixelBuffer];
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    return outputPixelBuffer;
}

- (CVPixelBufferRef)createPixelBufferWithSize:(CGSize)size {
    CVPixelBufferRef pixelBuffer = NULL;
    NSDictionary *attributes = nil;
    if (self.renderer) {
        attributes = @{(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}, (__bridge NSString *)kCVPixelBufferMetalCompatibilityKey: @(YES)};
    } else {
        attributes = @{(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}};
    }
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef _Nullable)(attributes), &pixelBuffer);
    if (status != kCVReturnSuccess) {
        NSLog(@"Can't create pixelbuffer");
    }
    return pixelBuffer;
}

@end
