//
//  BDAlphaPlayerDelegate.h
//  BDAlphaPlayer
//
//  Created by ByteDance on 2020/7/5.
//

#import <Foundation/Foundation.h>
#import "BDAlphaPlayerDelegate.h"
#import "BDAlphaPlayerMetalConfiguration.h"
#import "BDAlphaPlayerResourceModel.h"

typedef NS_ENUM(NSUInteger, BDAlphaPlayerPlayState) {
    BDAlphaPlayerPlayStateStop = 0,
    BDAlphaPlayerPlayStatePlay,
};

NS_ASSUME_NONNULL_BEGIN

@protocol BDAlphaPlayerProtocol <NSObject>

- (instancetype)initWithDelegate:(nullable id<BDAlphaPlayerDelegate>)delegate;

/**
 @brief Resource model for MP4.
*/
@property (nonatomic, strong, readonly) BDAlphaPlayerResourceModel *model;

/**
 @brief Current state for player.
*/
@property (nonatomic, assign, readonly) BDAlphaPlayerPlayState state;

/**
 @brief Core method for player.Only this method can start to play MP4.
 
 @prama configuration Params player needs.
*/
- (void)playWithMetalConfiguration:(BDAlphaPlayerMetalConfiguration *)configuration;

/**
 @brief Core method for player.Only this method can start to play MP4.
 
 @prama model Params player needs.
*/
- (void)playWithFrame:(CGRect)frame model:(BDAlphaPlayerResourceModel *)model completion:(nullable BDAlphaPlayerRenderOutputCompletion)completion;

/**
 @brief Get total duration of currently displaying MP4.Duration is only available after [BDAlphaPlayerMetalView playWithMetalConfiguration:] method called.

 @seealso [BDAlphaPlayerMetalView playWithMetalConfiguration:]
 @return Total Duration of MP4.
*/
- (NSTimeInterval)totalDurationOfPlayingEffect;

/**
 @brief clear cache.
*/
- (void)pause;

/**
 @brief Stop displaying without calling didFinishPlayingWithError method.

 @seealso [BDAlphaPlayerMetalView stopWithFinishPlayingCallback:]
*/
- (void)stop;

/**
 @brief Stop displaying with calling didFinishPlayingWithError method.

 @seealso [BDAlphaPlayerMetalView stop:]
*/
- (void)stopWithFinishPlayingCallback;

@end

NS_ASSUME_NONNULL_END
