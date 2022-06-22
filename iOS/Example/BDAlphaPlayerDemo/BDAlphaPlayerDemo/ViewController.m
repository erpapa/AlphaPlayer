//
//  ViewController.m
//  BDAlphaPlayerDemo
//
//  Created by ByteDance on 2020/12/21.
//

#import "ViewController.h"
#import <BDAlphaPlayer/BDAlphaPlayer.h>

@interface ViewController () <BDAlphaPlayerDelegate>

@property (nonatomic, strong) BDAlphaPlayerMetalView *metalView;
@property (nonatomic, strong) BDAlphaPlayerVideoView *videoView;
@property (nonatomic, strong) UIButton *startBtn;
@property (nonatomic, strong) UIButton *stopBtn;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor lightGrayColor];
    self.startBtn = [[UIButton alloc] initWithFrame:CGRectMake(100, 88, 60, 60)];
    self.startBtn.backgroundColor = [UIColor orangeColor];
    [self.startBtn setTitle:@"start" forState:UIControlStateNormal];
    [self.startBtn addTarget:self action:@selector(startBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.startBtn];
    
    self.stopBtn = [[UIButton alloc] initWithFrame:CGRectMake(200, 88, 60, 60)];
    self.stopBtn.backgroundColor = [UIColor orangeColor];
    [self.stopBtn setTitle:@"stop" forState:UIControlStateNormal];
    [self.stopBtn addTarget:self action:@selector(stopBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.stopBtn];
}

- (void)startBtnClicked:(UIButton *)sender
{
//    if (!self.metalView) {
//        self.metalView = [[BDAlphaPlayerMetalView alloc] initWithDelegate:self];
//        [self.view insertSubview:self.metalView atIndex:0];
//    }
//    self.startBtn.hidden = YES;
//    self.stopBtn.alpha = 0.3;
//
//    BDAlphaPlayerMetalConfiguration *configuration = [BDAlphaPlayerMetalConfiguration defaultConfiguration];
//    NSString *testResourcePath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"TestResource"];
//    NSString *directory = [testResourcePath stringByAppendingPathComponent:@"heartbeats"];
//    configuration.directory = directory;
//    configuration.renderSuperViewFrame = self.view.frame;
//    configuration.orientation = BDAlphaPlayerOrientationPortrait;
//
//    [self.metalView playWithMetalConfiguration:configuration];

    if (!self.videoView) {
        self.videoView = [[BDAlphaPlayerVideoView alloc] initWithDelegate:self];
        [self.view insertSubview:self.videoView atIndex:0];
    }
    self.startBtn.hidden = YES;
    self.stopBtn.alpha = 0.3;

    BDAlphaPlayerResourceModel *model = [[BDAlphaPlayerResourceModel alloc] init];
    model.currentContentMode = BDAlphaPlayerContentModeScaleAspectFit;
    model.currentResourceFileURL = [NSURL URLWithString:@"https://video.ivwen.com/users/47951008/73c07c63b599bcc0d4ac53802d6ebd79.mp4"];
    [self.videoView playWithFrame:self.view.frame model:model completion:^{
        NSLog(@"videoView play completion");
    }];
}

- (void)stopBtnClicked:(UIButton *)sender
{
//    [self.metalView stopWithFinishPlayingCallback];
//    [self.metalView removeFromSuperview];
//    self.metalView = nil;

    [self.videoView stopWithFinishPlayingCallback];
    [self.videoView removeFromSuperview];
    self.videoView = nil;
}

- (void)metalView:(UIView *)metalView didFinishPlayingWithError:(NSError *)error
{
    if (error) {
        NSLog(@"%@", error.localizedDescription);
    }
    self.startBtn.hidden = NO;
    self.stopBtn.alpha = 1;
}

@end
