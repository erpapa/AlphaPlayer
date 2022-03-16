//
//  BDAlphaVideoMetalRenderer.h
//  BDAlphaPlayer
//
//  Created by ByteDance on 2020/4/23.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

@interface BDAlphaVideoMetalRenderer : NSObject

@property (nonatomic, strong, readonly) id<MTLDevice> device;

- (instancetype)initWithDevice:(id<MTLDevice>)device;

- (void)renderPixelBuffer:(CVPixelBufferRef)pixelBuffer toPixelBuffer:(CVPixelBufferRef)outputPixelBuffer;

- (void)flush;

@end

NS_ASSUME_NONNULL_END
