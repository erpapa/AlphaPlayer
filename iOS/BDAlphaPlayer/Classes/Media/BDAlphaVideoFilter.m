//
//  BDAlphaVideoFilter.m
//  BDAlphaPlayer
//
//  Created by Lyman Li on 2020/3/8.
//  Copyright © 2020 Lyman Li. All rights reserved.
//

#import "BDAlphaVideoFilter.h"

NSString *const kBDAlphaVideoFilterShaderString = @"\
kernel vec4 _alphaVideoFilter(sampler inputImage)\
{\
    vec2 texCoord = samplerCoord(inputImage);\
    vec4 texColor = sample(inputImage, vec2(texCoord.x * 0.5, texCoord.y));\
    vec4 texColorMap = sample(inputImage, vec2(texCoord.x * 0.5 + 0.5, texCoord.y));\
    return vec4(texColor.r, texColor.g, texColor.b, texColorMap.r);\
}";

@implementation BDAlphaVideoFilterConstructor

+ (instancetype)constructor
{
    static BDAlphaVideoFilterConstructor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BDAlphaVideoFilterConstructor alloc] initForSharedConstructor];
    });
    return instance;
}

- (instancetype)initForSharedConstructor
{
    self = [super init];
    return self;
}

- (CIFilter *)filterWithName:(NSString *)name
{
    return [[NSClassFromString(name) alloc] init];
}

@end

@implementation BDAlphaVideoFilter

+ (void)registerFilter
{
    NSString *filterName = NSStringFromClass(self);
    NSString *displayName = [NSStringFromClass(self) stringByReplacingOccurrencesOfString:@"BD" withString:@""];
    
    NSArray *filterCategories = @[kCICategoryColorAdjustment, kCICategoryColorEffect,kCICategoryStillImage,kCICategoryVideo, kCICategoryInterlaced];
    NSDictionary *attributes = @{
                                 kCIAttributeFilterDisplayName : displayName,
                                 kCIAttributeFilterCategories : filterCategories };
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
    [CIFilter registerFilterName:filterName constructor:[BDAlphaVideoFilterConstructor constructor] classAttributes:attributes];
#else
    if (@available(iOS 9.0, *)) {
        [CIFilter registerFilterName:filterName constructor:[BDAlphaVideoFilterConstructor constructor] classAttributes:attributes];
    }
#endif
}

- (CIImage *)outputImage
{
    NSArray *arguments = [self arguments];
    CIKernel *kernel = [self kernel];
    
    if ([kernel isKindOfClass:[CIColorKernel class]]) {
        CIImage *texture = [arguments firstObject];
        CIColorKernel *colorKernel = (CIColorKernel *)kernel;
        return [colorKernel applyWithExtent:texture.extent arguments:arguments];
    }
    
    CIImage *texture = [arguments firstObject];
    return [kernel applyWithExtent:texture.extent roiCallback:^CGRect(int index, CGRect destRect) {
        if (index == 0) {
            return destRect;
        } else if (index < arguments.count) {
            CIImage *otherTexture = [arguments objectAtIndex:index];
            return otherTexture.extent;
        }
        return destRect;
    } arguments:arguments];
}

- (CIKernel *)kernel
{
    static CIKernel *kAlphaVideoFilterKernel = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kAlphaVideoFilterKernel = [CIKernel kernelWithString:kBDAlphaVideoFilterShaderString];
    });
    return kAlphaVideoFilterKernel;
}

- (NSArray *)arguments
{
    NSArray *arguments = nil;
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
    CISampler *texture = [CISampler samplerWithImage:self.inputImage options:[self samplerOptions]];
    arguments = [NSArray arrayWithObjects:texture, nil];
#else
    arguments = [NSArray arrayWithObjects:self.inputImage, nil];
#endif
    return arguments;
}

- (nullable NSDictionary *)samplerOptions
{
    // 必须要指定颜色空间，否则会自动启用颜色校正(Color Correction)
    NSDictionary *options = nil;
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    options = [NSDictionary dictionaryWithObjectsAndKeys:(__bridge id)colorSpace, kCISamplerColorSpace, nil];
    CGColorSpaceRelease(colorSpace);
#else
    if (@available(iOS 9.0, *)) {
        CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        options = [NSDictionary dictionaryWithObjectsAndKeys:(__bridge id)colorSpace, kCISamplerColorSpace, nil];
        CGColorSpaceRelease(colorSpace);
    }
#endif
    return options;
}

@end
