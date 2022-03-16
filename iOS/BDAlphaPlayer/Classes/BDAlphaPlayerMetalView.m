//
//  BDAlphaPlayerMetalView.m
//  BDAlphaPlayer
//
//  Created by ByteDance on 2020/7/5.
//

#import "BDAlphaPlayerMetalView.h"

#import "BDAlphaPlayerAssetReaderOutput.h"
#import "BDAlphaPlayerMetalRenderer.h"
#import "BDAlphaPlayerMetalShaderType.h"

#import <MetalKit/MetalKit.h>
#import <pthread.h>

@interface BDAlphaPlayerMetalView ()

@property (nonatomic, strong, readwrite) BDAlphaPlayerResourceModel *model;
@property (nonatomic, assign, readwrite) BDAlphaPlayerPlayState state;

@property (nonatomic, weak, nullable) id<BDAlphaPlayerDelegate> delegate;

@property (nonatomic, assign) CGRect renderSuperViewFrame;
@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic, strong) BDAlphaPlayerMetalRenderer *metalRenderer;

@property (nonatomic, strong) BDAlphaPlayerAssetReaderOutput *output;

@property (atomic, assign) BOOL hasDestroyed;

@end

@implementation BDAlphaPlayerMetalView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.contentScaleFactor = [UIScreen mainScreen].scale;
        self.backgroundColor = [UIColor clearColor];
        [self setupMetal];
    }
    return self;
}

- (instancetype)initWithDelegate:(id<BDAlphaPlayerDelegate>)delegate
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.contentScaleFactor = [UIScreen mainScreen].scale;
        self.backgroundColor = [UIColor clearColor];
        
        self.delegate = delegate;
        [self setupMetal];
    }
    return self;
}

- (void)dealloc
{
    if (!self.hasDestroyed) {
        [self destroyMTKView];
    }
}

#pragma mark - Public Method

- (void)playWithMetalConfiguration:(BDAlphaPlayerMetalConfiguration *)configuration
{
    NSAssert(!CGRectIsEmpty(configuration.renderSuperViewFrame), @"You need to initialize renderSuperViewFrame before playing");
    NSError *error = nil;
    self.renderSuperViewFrame = configuration.renderSuperViewFrame;
    self.model = [BDAlphaPlayerResourceModel resourceModelFromDirectory:configuration.directory orientation:configuration.orientation error:&error];
    if (error) {
        [self didFinishPlayingWithError:error];
        return;
    }
    [self configRenderViewContentModeFromModel];
    [self play];
}

- (void)playWithFrame:(CGRect)frame model:(BDAlphaPlayerResourceModel *)model completion:(nullable BDAlphaPlayerRenderOutputCompletion)completion
{
    self.renderSuperViewFrame = frame;
    self.model = model;
    [self configRenderViewContentModeFromModel];
    [self playWithCompletion:completion];
}

- (NSTimeInterval)totalDurationOfPlayingEffect
{
    if (self.output) {
        return self.output.videoDuration;
    }
    return 0.0;
}

- (void)pause
{
    self.mtkView.paused = YES;
    [self.metalRenderer drainSampleBufferQueue];
}

- (void)stop
{
    [self destroyMTKView];
}

- (void)stopWithFinishPlayingCallback
{
    [self stop];
    [self renderCompletion];
}

#pragma mark - Private Method

- (void)configRenderViewContentModeFromModel
{
    if (self.model.currentOrientationResourceInfo) {
        BDAlphaPlayerContentMode mode = self.model.currentOrientationResourceInfo.contentMode;
        self.model.currentOrientationResourceInfo.contentMode = mode;
        self.model.currentContentMode = mode;
    }
}

#pragma mark Callback

- (void)didFinishPlayingWithError:(NSError *)error
{
    self.state = BDAlphaPlayerPlayStateStop;
    if (self.delegate && [self.delegate respondsToSelector:@selector(metalView:didFinishPlayingWithError:)]) {
        [self.delegate metalView:self didFinishPlayingWithError:error];
    }
}

#pragma mark Player

- (void)play
{
    [self playWithCompletion:NULL];
}

- (void)playWithCompletion:(BDAlphaPlayerRenderOutputCompletion)completion
{
    NSURL *url = self.model.currentResourceFileURL;
    if (!url) {
        url = [self.model.currentOrientationResourceInfo resourceFileURL];
    }
    NSError *error = nil;
    BDAlphaPlayerAssetReaderOutput *output = [[BDAlphaPlayerAssetReaderOutput alloc] initWithURL:url error:&error];
    CGRect rederFrame = [BDAlphaPlayerUtility frameFromVideoSize:output.videoSize renderSuperViewFrame:self.renderSuperViewFrame contentMode:self.model.currentContentMode];
    self.frame = rederFrame;
    
    if (error) {
        NSError *finishError = nil;
        switch (error.code) {
            case BDAlphaPlayerAssetReaderOutputErrorFileNotExists:
            case BDAlphaPlayerAssetReaderOutputErrorCannotReadFile:
                finishError = [NSError errorWithDomain:BDAlphaPlayerErrorDomain code:BDAlphaPlayerErrorCodeFile userInfo:error.userInfo];
                break;
            case BDAlphaPlayerAssetReaderOutputErrorVideoTrackNotExists:
                finishError = [NSError errorWithDomain:BDAlphaPlayerErrorDomain code:BDAlphaPlayerErrorCodePlay userInfo:@{NSLocalizedDescriptionKey:@"does not have video track"}];
                break;
            default:
                finishError = error;
                break;
        }
        [self didFinishPlayingWithError:finishError];
        return;
    }
    self.state = BDAlphaPlayerPlayStatePlay;
    BDAlphaPlayerRenderOutputCompletion outputCompletion = [completion copy];

    __weak typeof(self) weakSelf = self;
    [self renderOutput:output resourceModel:self.model completion:^{
        if (!weakSelf) {
            return;
        }
        [weakSelf renderCompletion];
        if (outputCompletion) {
            outputCompletion();
        }
    }];
}

- (void)renderCompletion
{
    [self didFinishPlayingWithError:nil];
}

- (void)renderOutput:(BDAlphaPlayerAssetReaderOutput *)output resourceModel:(BDAlphaPlayerResourceModel *)resourceModel completion:(BDAlphaPlayerRenderOutputCompletion)completion
{
    if (!self.mtkView) {
        [self setupMetal];
    }
    self.output = output;
    BDAlphaPlayerRenderOutputCompletion renderCompletion = [completion copy];
    
    __weak typeof(self) weakSelf = self;
    [self.metalRenderer renderOutput:output resourceModel:resourceModel completion:^{
        if (!weakSelf) {
            return;
        }
        [weakSelf pause];
        if (renderCompletion) {
            renderCompletion();
        }
    }];
}

- (void)destroyMTKView
{
    self.mtkView.paused = YES;
    [self.mtkView removeFromSuperview];
    [self.mtkView releaseDrawables];
    [self.metalRenderer drainSampleBufferQueue];
    self.mtkView = nil;
    self.hasDestroyed = YES;
}

#pragma mark SetupMetal

- (void)setupMetal
{
    // Init MTKView
    if (!self.mtkView) {
        self.mtkView = [[MTKView alloc] initWithFrame:CGRectZero];
        self.mtkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.mtkView.backgroundColor = [UIColor clearColor];
        self.mtkView.device = MTLCreateSystemDefaultDevice();
        self.mtkView.clearColor = MTLClearColorMake(0, 0, 0, 0);
        [self addSubview:self.mtkView];
        
        __weak typeof(self) weakSelf = self;
        self.metalRenderer = [[BDAlphaPlayerMetalRenderer alloc] initWithMetalKitView:self.mtkView];
        self.metalRenderer.framePlayDurationCallBack = ^(NSTimeInterval duration) {
            if (weakSelf && [weakSelf.delegate respondsToSelector:@selector(frameCallBack:)]) {
                [weakSelf.delegate frameCallBack:duration];
            }
        };
        
        self.mtkView.frame = self.bounds;
        self.hasDestroyed = NO;
    }
}

@end
