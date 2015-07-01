//
//  ViewController.m
//  MyImgPickerController
//
//  Created by lwj on 15/6/25.
//  Copyright (c) 2015年 root. All rights reserved.
//

#import "ViewController.h"
#import "PhotoTakerViewController.h"
#import "MyImgPickerController.h"

#import "UIView+ZCLQuickControl.h"

#import <MediaPlayer/MediaPlayer.h>

#import <Masonry.h>

@interface ViewController () <UIImagePickerControllerDelegate,UINavigationControllerDelegate>
{
    UIButton *_btn;
    UIButton *_test;
    UIButton *_player;
    UIButton *_library;
    MPMoviePlayerViewController *_mpVC;
    
    NSString *_outputFielPathLow;
    NSString *_outputFilePath;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _outputFielPathLow = [NSTemporaryDirectory() stringByAppendingString:@"myMovieLow.mov"];
    _outputFilePath =[NSTemporaryDirectory() stringByAppendingString:@"myMovie.mov"];
    
    _btn = [self.view addSystemButtonAtNormalStateWithFrame:CGRectMake(0, 0, 0, 0) title:@"拍照" titleColor:[UIColor blackColor] fontSize:15 fontName:nil aligmentType:NSTextAlignmentCenter];
    [_btn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.centerY.mas_equalTo(self.view.mas_centerY);
        make.size.mas_equalTo(CGSizeMake(30, 50));
    }];
    [_btn addTarget:self action:@selector(photoClick:) forControlEvents:UIControlEventTouchUpInside];
    
    _test = [self.view addSystemButtonAtNormalStateWithFrame:CGRectMake(0, 0, 0, 0) title:@"test" titleColor:[UIColor blackColor] fontSize:15 fontName:nil aligmentType:NSTextAlignmentCenter];
    [_test mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(_btn.mas_bottom).with.offset(0);
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.size.mas_equalTo(CGSizeMake(30, 50));
    }];
    [_test addTarget:self action:@selector(testClick:) forControlEvents:UIControlEventTouchUpInside];
    
    _player = [self.view addSystemButtonAtNormalStateWithFrame:CGRectMake(0, 0, 0, 0) title:@"播放" titleColor:[UIColor blackColor] fontSize:15 fontName:nil aligmentType:NSTextAlignmentCenter];
    [_player mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(_test.mas_bottom).with.offset(0);
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.size.mas_equalTo(CGSizeMake(30, 50));
    }];
    [_player addTarget:self action:@selector(playClick:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)photoClick:(UIButton *)btn
{
    PhotoTakerViewController *photoVC = [[PhotoTakerViewController alloc] init];
    [self presentViewController:photoVC animated:YES completion:nil];
}

- (void)testClick:(UIButton *)btn
{
    MyImgPickerController *myPC = [[MyImgPickerController alloc] init];
//    [self presentViewController:myPC animated:YES completion:nil];
    
    // 判断设备是否可用
    if(![MyImgPickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"不可用" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
    }
    else
    {
        // 设置要素
        myPC.sourceType = UIImagePickerControllerSourceTypeCamera;
        myPC.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:myPC.sourceType];
        myPC.delegate = self;
        //   切换到拍摄界面
        [self presentViewController:myPC animated:YES completion:nil];
    }
}

- (void)playClick:(UIButton *)button
{
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    if([fileManager fileExistsAtPath:_outputFielPathLow])
    {
        _mpVC = [[MPMoviePlayerViewController alloc] initWithContentURL:[NSURL fileURLWithPath:_outputFielPathLow]];
        _mpVC.moviePlayer.controlStyle = MPMovieControlStyleDefault;
        _mpVC.moviePlayer.scalingMode = MPMovieScalingModeNone;
        UIButton *exitBtn = [_mpVC.view addSystemButtonAtNormalStateWithFrame:CGRectMake(10, 30, 50, 23) title:@"back" titleColor:[UIColor whiteColor] fontSize:15 fontName:nil aligmentType:NSTextAlignmentCenter];
        [exitBtn addTarget:self action:@selector(backClick:) forControlEvents:UIControlEventTouchUpInside];
        // 开始播放视频
        [[[UIApplication sharedApplication] keyWindow] addSubview:_mpVC.view];
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"文件不存在" delegate:self cancelButtonTitle:@"知道了" otherButtonTitles:nil];
        [alert show];
    }
}

- (void)backClick:(UIButton *)btn
{
    [_mpVC.view removeFromSuperview];
}

@end
