//
//  BDAlphaVideoFilter.h
//  BDAlphaPlayer
//
//  Created by Lyman Li on 2020/3/8.
//  Copyright © 2020 Lyman Li. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>

NS_ASSUME_NONNULL_BEGIN

/*
 Using class with name `filterName` to construct a filter object.
 */
@interface BDAlphaVideoFilterConstructor : NSObject <CIFilterConstructor>

+ (instancetype)constructor;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface BDAlphaVideoFilter : CIFilter

@property (nonatomic, strong) CIImage *inputImage;

+ (void)registerFilter;

@end

NS_ASSUME_NONNULL_END
