//
//  BDAlphaPlayerDelegate.h
//  BDAlphaPlayer
//
//  Created by ByteDance on 2020/7/5.
//

#import <UIKit/UIKit.h>

@protocol BDAlphaPlayerDelegate <NSObject>

- (void)metalView:(UIView *)metalView didFinishPlayingWithError:(NSError *)error;

@optional

/**
 @brief The method will be called for every frame during displaying duration.
 @prama duration The duration from start to current frame.
*/
- (void)frameCallBack:(NSTimeInterval)duration;

@end
