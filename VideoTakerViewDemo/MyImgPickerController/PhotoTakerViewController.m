//
//  PhotoTakerViewController.m
//  MyImgPickerController
//
//  Created by lwj on 15/6/25.
//  Copyright (c) 2015年 root. All rights reserved.
//  AVFoundation定制相机界面，裁剪视频规格，压缩视频，单双击手势的冲突解决。

#import "PhotoTakerViewController.h"

#import "UIView+ZCLQuickControl.h"
#import "ZCLCameraManager.h"

#import <Masonry.h>
#import <SVProgressHUD.h>

#define MAX_RECORD_TIME 15
#define PROGRESS_MOVE_PERTIME 0.0006666667

@interface PhotoTakerViewController () <UIAlertViewDelegate,ZCLCameraManagerDelegate>
{
    ZCLCameraManager *_cameraManager;
    
    UIButton *_recordBtn;
    UIProgressView *_filmProgress;
    NSTimer *_progressTimer;
    NSTimer *_focusTimer;
    NSTimer *_zoomTimer;
    UILabel *_releaseLabel;
    UILabel *zoomLabel;
    UIAlertView *_finishAlert;
    UIView *_darkView;
    NSString *_outputFielPath;// 原视频文件输出路径
    NSString *_outputFilePathLow;// 压缩后视频文件输出路径
    BOOL _isCancel;// 取消录制标记（取消录制操作后不进行视频裁剪和压缩处理）
}

@end

@implementation PhotoTakerViewController

// 会话、设备、输入对象、输出对象、预览层

#pragma mark - VC生命周期
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _outputFielPath = [NSTemporaryDirectory() stringByAppendingString:@"myMovie.mov"];
    _outputFilePathLow = [NSTemporaryDirectory() stringByAppendingString:@"myMovieLow.mov"];
    
    _isCancel = NO;
    
    [self createUI];
    
    [self configCaptureSessionAndPreview];
}

- (void)viewWillAppear:(BOOL)animated
{
    [_cameraManager startRuning];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [_cameraManager stopRunning];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - 创建视图
- (void)createUI
{
    self.view.backgroundColor = [UIColor blackColor];
    
    // 取景框
    _viewContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 20, self.view.frame.size.width, self.view.frame.size.width*1)];
    //_viewContainer.backgroundColor = [UIColor redColor];
    _viewContainer.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_viewContainer];
    
    // 录制进度
    _filmProgress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    [self.view addSubview:_filmProgress];
    [_filmProgress mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.with.equalTo(_viewContainer.mas_bottom).with.offset(0);
        make.width.mas_equalTo(self.view.mas_width);
        make.height.mas_equalTo(@3);
        make.centerX.mas_equalTo(self.view.mas_centerX);
    }];
    _filmProgress.progressTintColor = [UIColor redColor];
    _filmProgress.progress = 0;
    
    // 对焦框
    self.focusCursor = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"1352205788135321393.png"]];
//    self.focusCursor.frame = CGRectMake(0, 0, 60, 60);
//    self.focusCursor.center = CGPointMake(_viewContainer.frame.size.width/2, _viewContainer.frame.size.height/2);
//    self.focusCursor.alpha = 0;
//    [_viewContainer addSubview:self.focusCursor];

    // 取消提示
    _releaseLabel = [self.view addLabelWithFrame:CGRectMake(0, 0, 0, 0) text:@"👆上拉取消👆" textColor:[UIColor redColor] fontSize:16 fontName:nil aligmentType:NSTextAlignmentCenter];
    _releaseLabel.alpha = 0;
    [_releaseLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(_filmProgress.mas_bottom).with.offset(10);
        make.size.mas_equalTo(CGSizeMake(180, 23));
        make.centerX.mas_equalTo(self.view.mas_centerX);
    }];
    
    // 录制按钮
    _recordBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_recordBtn setBackgroundImage:[UIImage imageNamed:@"08341911.png"] forState:UIControlStateNormal];
    [self.view addSubview:_recordBtn];
    //_record = [self.view addCustomButtonAtNormalStateWithFrame:CGRectMake(0, 0, 0, 0) imageName:@"green-button-for-web.jpg" title:nil titleColor:nil fontSize:15 fontName:nil aligmentType:NSTextAlignmentCenter];
    [_recordBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        if([UIScreen mainScreen].bounds.size.height==480)
        {
            make.top.mas_equalTo(_releaseLabel.mas_bottom).with.offset(0);
            make.centerX.mas_equalTo(self.view.mas_centerX);
            make.size.mas_equalTo(CGSizeMake(70, 70));
        }
        else
        {
            make.top.mas_equalTo(_releaseLabel.mas_bottom).with.offset(15);
            make.centerX.mas_equalTo(self.view.mas_centerX);
            make.size.mas_equalTo(CGSizeMake(100, 100));
        }
    }];

    [_recordBtn setBackgroundImage:[UIImage imageNamed:@"0834192.png"] forState:UIControlStateHighlighted];
    [_recordBtn addTarget:self action:@selector(holdRecord:) forControlEvents:UIControlEventTouchDown];
    [_recordBtn addTarget:self action:@selector(releaseRecord:) forControlEvents:UIControlEventTouchUpInside];
    [_recordBtn addTarget:self action:@selector(cancelRecord:) forControlEvents:UIControlEventTouchUpOutside];
    
    // 放大提示
    zoomLabel = [self.view addLabelWithFrame:CGRectMake(0, 0, 0, 0) text:@"-双击放大/缩小-" textColor:[UIColor greenColor] fontSize:15 fontName:nil aligmentType:NSTextAlignmentCenter];
    [zoomLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(_filmProgress.mas_bottom).with.offset(-38);
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.size.mas_equalTo(CGSizeMake(180, 23));
    }];
}

- (BOOL)shouldAutorotate
{
    return self.enableRotation;
}

#pragma mark - 拍摄功能
- (void)configCaptureSessionAndPreview
{
    // 初始化管理对象
    _cameraManager = [[ZCLCameraManager alloc] initSessionWithMediaType:ZCLCameraMediaTypeVideo preset:AVCaptureSessionPresetHigh position:AVCaptureDevicePositionBack];
    _cameraManager.delegate = self;
    
    // 创建视频预览层，实时展示摄像头状态
//    [_cameraManager setContainerViewLayerToView:_viewContainer focusCursor:_focusCursor];
    // 创建视频预览层，实时展示摄像头状态
    
    // 预览层添加到界面中
    [_cameraManager setContainerViewLayerToView:_viewContainer focusCursor:_focusCursor];
    
    // 设置是否可旋转（外部调用设置的话注释掉），添加手势、通知；
    // 双击手势，调整视野（微信小视频功能）
    UITapGestureRecognizer *doubleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapScreen:)];
    [doubleTapGesture setNumberOfTapsRequired:2];
    [_cameraManager addGenstureRecognizer:doubleTapGesture];
    // 单击手势需要双击手势不存在或失败时才能激活（防止冲突）
    UITapGestureRecognizer *singleTapGesture = [_cameraManager getSingleTapGestureRecognizer];
    [singleTapGesture requireGestureRecognizerToFail:doubleTapGesture];
}

#pragma mark - ZCLCameraManagerDelegate
// 录制操作结束后的操作
- (void)didStopVideoRunningCameraManager:(ZCLCameraManager *)manager
{
    // 取消操作造成的停止录制讲不进行后面的操作
    if(_isCancel==YES)
    {
        return;
    }
    
    // 数据处理中的UI界面效果
    [SVProgressHUD showProgress:0.0 status:@"处理中"];
    _darkView = [[UIView alloc] init];
    [self.view addSubview:_darkView];
    [_darkView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.view.mas_top);
        make.left.mas_equalTo(self.view.mas_left);
        make.right.mas_equalTo(self.view.mas_right);
        make.bottom.mas_equalTo(self.view.mas_bottom);
    }];
    _darkView.backgroundColor = [UIColor blackColor];
    _darkView.alpha = 0.7;
    
    // 裁剪及压缩视频
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    if([fileManager fileExistsAtPath:_outputFielPath])
    {
        NSLog(@"愿文件存在");
        [_cameraManager compressVideoInputFilePath:_outputFielPath outputFilePath:_outputFilePathLow preset:AVAssetExportPresetMediumQuality isSqure:YES finished:^{
            // 结束后切换到主线程操作UI
            dispatch_async(dispatch_get_main_queue(), ^{
                // 获取文件大小
                NSFileManager *fileManager = [[NSFileManager alloc] init];
                unsigned long long fileSizeB = [[fileManager attributesOfItemAtPath:_outputFilePathLow error:nil] fileSize];
                double fileSizeKB = fileSizeB/1024.0;
                // UI操作
                _finishAlert = [[UIAlertView alloc] initWithTitle:nil message:[NSString stringWithFormat:@"视频录制完成，文件大小%.2fKB",fileSizeKB] delegate:self cancelButtonTitle:@"重新录制" otherButtonTitles:@"退出",nil];
                [_finishAlert show];
                [SVProgressHUD dismiss];
            });
        }];
        
        // 在子线程中获取压缩的进度
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            while ([_cameraManager getExportProgress]<0.99)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD showProgress:[_cameraManager getExportProgress] status:@"处理中"];
                });
            }
        });
    }

}

#pragma mark - 事件响应
- (void)holdRecord:(UIButton *)button
{
    _progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(timerRunning) userInfo:nil repeats:YES];
    
    [UIView animateWithDuration:0.2 animations:^{
        _releaseLabel.alpha = 1;
    }];
    
    if(_filmProgress.progress<1.0)
    {
        // 开始录制
        [_cameraManager startVideoRunningWithOutputPath:_outputFielPath];
    }
}

- (void)releaseRecord:(UIButton *)button
{
    [UIView animateWithDuration:0.2 animations:^{
        _releaseLabel.alpha = 0;
    }];
    
    _isCancel = NO;
    [_cameraManager stopVideoRunning];//停止录制
}

- (void)cancelRecord:(UIButton *)button
{
    [UIView animateWithDuration:0.2 animations:^{
        _releaseLabel.alpha = 0;
    }];
    _filmProgress.progress = 0;
    
    _isCancel = YES;
    [_cameraManager stopVideoRunning];// 停止录制
}

- (void)timerRunning
{
    if(_recordBtn.highlighted==YES && _filmProgress.progress!=1)
    {
        _filmProgress.progress += PROGRESS_MOVE_PERTIME;
    }
    else
    {
        [_progressTimer invalidate];
        _filmProgress.tintColor = [UIColor greenColor];
    }
    
    if(_filmProgress.progress==1)
    {
        [_progressTimer invalidate];
        _isCancel = NO;
        [_cameraManager stopVideoRunning];
        [UIView animateWithDuration:0.2 animations:^{
            _releaseLabel.alpha = 0;
        }];
    }
}

- (void)doubleTapScreen:(UITapGestureRecognizer *)tapGesture
{
    if([_zoomTimer isValid])
    {
        return;
    }
    AVCaptureDevice *device = _cameraManager.videoCaptureDevice;
    if(device.videoZoomFactor<1.7)
    {
        _zoomTimer = [NSTimer scheduledTimerWithTimeInterval:0.03 target:self selector:@selector(zoomTimerAdd:) userInfo:nil repeats:YES];
    }
    else
    {
       _zoomTimer = [NSTimer scheduledTimerWithTimeInterval:0.03 target:self selector:@selector(zoomTimerReduce:) userInfo:nil repeats:YES];
    }
}

- (void)zoomTimerAdd:(NSTimer *)timer
{
    [_cameraManager changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        captureDevice.videoZoomFactor += 0.07;
        if(captureDevice.videoZoomFactor>=1.7)
        {
            captureDevice.videoZoomFactor = 1.7;
            [_zoomTimer invalidate];
        }
    }];
}

- (void)zoomTimerReduce:(NSTimer *)timer
{
    [_cameraManager changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if(captureDevice.videoZoomFactor>1.07)
        {
            captureDevice.videoZoomFactor -= 0.07;
        }
        else
        {
            captureDevice.videoZoomFactor = 1.0;
            [_zoomTimer invalidate];
        }
    }];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(alertView==_finishAlert)
    {
        switch (buttonIndex)
        {
            case 0:
            {
                [_darkView removeFromSuperview];
                _filmProgress.progress = 0;
                break;
            }
            case 1:
            {
                [_darkView removeFromSuperview];
                [self dismissViewControllerAnimated:YES completion:nil];
                break;
            }
        }
    }
}

- (void)didChangeAreaCameraManager:(ZCLCameraManager *)manager
{

}




/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
