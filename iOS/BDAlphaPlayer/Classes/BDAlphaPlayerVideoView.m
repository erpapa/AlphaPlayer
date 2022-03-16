//
//  BDAlphaPlayerVideoView.m
//  BDAlphaPlayer
//
//  Created by ByteDance on 2020/7/5.
//

#import "BDAlphaPlayerVideoView.h"
#import "BDAlphaVideoCompositing.h"
#import "BDAlphaVideoCompositionInstruction.h"
#import "BDAlphaPlayerUtility.h"

@interface BDAlphaPlayerVideoView ()

@property (nonatomic, strong, readwrite) BDAlphaPlayerResourceModel *model;
@property (nonatomic, assign, readwrite) BDAlphaPlayerPlayState state;

@property (nonatomic, weak, nullable) id<BDAlphaPlayerDelegate> delegate;
@property (nonatomic, copy) BDAlphaPlayerRenderOutputCompletion outputCompletion;

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVURLAsset *asset;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) AVAssetExportSession *exportSession;
@property (nonatomic, strong) AVMutableVideoComposition *videoComposition;
@property (nonatomic, strong) id timeObserve;

@property (nonatomic, assign) CGRect renderSuperViewFrame;
@property (atomic, assign) BOOL hasDestroyed;

@end

@implementation BDAlphaPlayerVideoView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.contentScaleFactor = [UIScreen mainScreen].scale;
        self.backgroundColor = [UIColor clearColor];
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
    }
    return self;
}

- (void)dealloc
{
    if (!self.hasDestroyed) {
        [self destroyPlayer];
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
    if (self.playerItem) {
        return CMTimeGetSeconds(self.playerItem.duration);
    }
    return 0.0;
}

- (void)pause
{
    [self.player pause];
}

- (void)stop
{
    [self destroyPlayer];
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
    self.asset = [AVURLAsset assetWithURL:url];
    if (!self.player || ![self.asset.URL isEqual:url]) {
        [self setupPlayer];
    }
    [self.asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
        CGSize videoSize = CGSizeZero;
        NSArray *array = self.asset.tracks;
        for (AVAssetTrack *track in array) {
            if ([track.mediaType isEqualToString:AVMediaTypeVideo]) {
                videoSize = track.naturalSize;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            CGRect rederFrame = [BDAlphaPlayerUtility frameFromVideoSize:videoSize renderSuperViewFrame:self.renderSuperViewFrame contentMode:self.model.currentContentMode];
            self.frame = rederFrame;
            self.playerLayer.frame = self.bounds;
        });
    }];

    self.state = BDAlphaPlayerPlayStatePlay;
    self.outputCompletion = completion;
    [self.player seekToTime:CMTimeMake(0, 60)];
    [self.player play];
}

- (void)renderCompletion
{
    [self didFinishPlayingWithError:nil];
}

- (void)setupPlayer
{
    [self destroyPlayer];
    // videoComposition
    self.videoComposition = [self createVideoCompositionWithAsset:self.asset];
    self.videoComposition.customVideoCompositorClass = [BDAlphaVideoCompositing class];
    
    // playerItem
    self.playerItem = [[AVPlayerItem alloc] initWithAsset:self.asset];
    self.playerItem.videoComposition = self.videoComposition;
    
    // player
    self.player = [[AVPlayer alloc] initWithPlayerItem:self.playerItem];
    
    // playerLayer
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.videoGravity = AVLayerVideoGravityResize;
    [self.layer addSublayer:self.playerLayer];
    
    __weak typeof(self) weakSelf = self;
    self.timeObserve = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1, 1) queue:nil usingBlock:^(CMTime time){
        AVPlayerItem *currentItem = weakSelf.playerItem;
        NSArray *loadedRanges = currentItem.seekableTimeRanges;
        if (loadedRanges.count > 0 && currentItem.duration.timescale != 0) {
            CGFloat duration = (CGFloat)CMTimeGetSeconds(currentItem.duration);
            if (weakSelf && [weakSelf.delegate respondsToSelector:@selector(frameCallBack:)]) {
                [weakSelf.delegate frameCallBack:duration];
            }
        }
    }];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayDidEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerItem];
    self.hasDestroyed = NO;
}

- (void)destroyPlayer
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.timeObserve) {
        [self.player removeTimeObserver:self.timeObserve];
        self.timeObserve = nil;
    }
    if (self.outputCompletion) {
        self.outputCompletion();
        self.outputCompletion = NULL;
    }
    [self.player pause];
    self.player = nil;
    self.videoComposition = nil;
    self.playerItem = nil;
    [self.playerLayer removeFromSuperlayer];
    self.playerLayer = nil;
    self.hasDestroyed = YES;
}

- (AVMutableVideoComposition *)createVideoCompositionWithAsset:(AVAsset *)asset
{
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:asset];
    // videoComposition.renderSize = CGSizeMake(videoComposition.renderSize.width * 0.5, videoComposition.renderSize.height);
    NSArray *instructions = videoComposition.instructions;
    NSMutableArray *newInstructions = [NSMutableArray array];
    for (AVVideoCompositionInstruction *instruction in instructions) {
        NSArray *layerInstructions = instruction.layerInstructions;
        // TrackIDs
        NSMutableArray *trackIDs = [NSMutableArray array];
        for (AVVideoCompositionLayerInstruction *layerInstruction in layerInstructions) {
            [trackIDs addObject:@(layerInstruction.trackID)];
        }
        BDAlphaVideoCompositionInstruction *newInstruction = [[BDAlphaVideoCompositionInstruction alloc] initWithSourceTrackIDs:trackIDs timeRange:instruction.timeRange];
        newInstruction.layerInstructions = instruction.layerInstructions;
        [newInstructions addObject:newInstruction];
    }
    videoComposition.instructions = newInstructions;
    return videoComposition;
}

- (void)moviePlayDidEnd:(NSNotification *)notification
{
    [self renderCompletion];
    if (self.outputCompletion) {
        self.outputCompletion();
    }
}

@end
