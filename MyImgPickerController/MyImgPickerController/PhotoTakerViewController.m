//
//  PhotoTakerViewController.m
//  MyImgPickerController
//
//  Created by lwj on 15/6/25.
//  Copyright (c) 2015年 root. All rights reserved.
//

#import "PhotoTakerViewController.h"

#import "UIView+ZCLQuickControl.h"

#import <Masonry.h>
#import <TGCameraViewController.h>

#define MAX_RECORD_TIME 15
#define PROGRESS_MOVE_PERTIME 0.0006667

@interface PhotoTakerViewController () <UIAlertViewDelegate>
{
    AVCaptureSession *_captureSession;//会话，负责输入和输出设备之间的数据传递
    AVCaptureDeviceInput *_videoCaptureDeviceInput;//负责从AVCaptureDevice获得输入数据
    AVCaptureDeviceInput *_audioCaptureDeviceInput;
    AVCaptureMovieFileOutput *_captureMovieFileOutput;//音频输出流
    AVCaptureVideoPreviewLayer *_captureVideoPreviewLayer;//相机拍摄预览图层
    
    UIButton *_recordBtn;
    UIProgressView *_filmProgress;
    NSTimer *_progressTimer;
    UILabel *_releaseLabel;
    UIAlertView *_finishAlert;
    NSString *_outputFielPath;// 原视频文件输出路径
    NSString *_outputFilePathLow;// 压缩后视频文件输出路径
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
    
    [self createUI];
    
    [self configCaptureSessionAndPreview];
}

- (void)viewWillAppear:(BOOL)animated
{
    [_captureSession startRunning];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [_captureSession stopRunning];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldAutorotate
{
    return self.enableRotation;
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
    
    // 录制按钮
    _recordBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_recordBtn setBackgroundImage:[UIImage imageNamed:@"08341911.png"] forState:UIControlStateNormal];
    [self.view addSubview:_recordBtn];
    //_record = [self.view addCustomButtonAtNormalStateWithFrame:CGRectMake(0, 0, 0, 0) imageName:@"green-button-for-web.jpg" title:nil titleColor:nil fontSize:15 fontName:nil aligmentType:NSTextAlignmentCenter];
    [_recordBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.mas_equalTo(@-110);
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.size.mas_equalTo(CGSizeMake(100, 100));
    }];
    [_recordBtn setBackgroundImage:[UIImage imageNamed:@"0834192.png"] forState:UIControlStateHighlighted];
    [_recordBtn addTarget:self action:@selector(holdRecord:) forControlEvents:UIControlEventTouchDown];
    [_recordBtn addTarget:self action:@selector(releaseRecord:) forControlEvents:UIControlEventTouchUpInside];
    [_recordBtn addTarget:self action:@selector(cancelRecord:) forControlEvents:UIControlEventTouchUpOutside];
    
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
    self.focusCursor = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"f096.png"]];
    self.focusCursor.frame = CGRectMake(0, 0, 60, 60);
    self.focusCursor.alpha = 0;
    [_viewContainer addSubview:self.focusCursor];

    // 取消提示
    _releaseLabel = [self.view addLabelWithFrame:CGRectMake(0, 0, 0, 0) text:@"👆上拉取消👆" textColor:[UIColor redColor] fontSize:16 fontName:nil aligmentType:NSTextAlignmentCenter];
    _releaseLabel.alpha = 0;
    [_releaseLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(_filmProgress.mas_bottom).with.offset(10);
        make.size.mas_equalTo(CGSizeMake(180, 23));
        make.centerX.mas_equalTo(self.view.mas_centerX);
    }];
}

#pragma mark - 拍摄功能
- (void)configCaptureSessionAndPreview
{
    // 初始化会话
    _captureSession = [[AVCaptureSession alloc] init];
    if([_captureSession canSetSessionPreset:AVCaptureSessionPresetMedium])
    {
        _captureSession.sessionPreset = AVCaptureSessionPreset352x288;
    }
    // 获得输入设备
    // 视频输入设备
    AVCaptureDevice *videoCaptureDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];//获取后置摄像头
    if(!videoCaptureDevice)
    {
        NSLog(@"无法获取后置摄像头");
    }
    //[videoCaptureDevice unlockForConfiguration];
    [videoCaptureDevice lockForConfiguration:nil];
    //NSLog(@"",videoCaptureDevice.fr)
    [videoCaptureDevice setActiveVideoMaxFrameDuration:CMTimeMake(1, 10)];
    [videoCaptureDevice setActiveVideoMaxFrameDuration:CMTimeMake(1, 10)];
    [videoCaptureDevice unlockForConfiguration];
    // 音频输入设备
    AVCaptureDevice *audioCaptureDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    
    // 初始化设备输入对象，用于获取输入数据
    NSError *error = nil;
    _videoCaptureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:videoCaptureDevice error:&error];
    if(error)
    {
        NSLog(@"获取输入对象，%@",error.localizedDescription);
        return;
    }
    _audioCaptureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioCaptureDevice error:&error];
    if(error)
    {
        NSLog(@"获取输入对象，%@",error.localizedDescription);
        return;
    }
    
    // 初始化设备输出对象，获取输出数据
    _captureMovieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    
    // 将输入对象加入会话
    if([_captureSession canAddInput:_videoCaptureDeviceInput]&&[_captureSession canAddInput:_audioCaptureDeviceInput])
    {
        [_captureSession addInput:_videoCaptureDeviceInput];
        [_captureSession addInput:_audioCaptureDeviceInput];
//        NSDictionary *dic = [[NSDictionary alloc] initWithObjects:@[[NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA],[NSNumber numberWithInt:240],[NSNumber numberWithInt:320]] forKeys:@[(NSString *)kCVPixelBufferPixelFormatTypeKey,(NSString *)kCVPixelBufferWidthKey,(NSString *)kCVPixelBufferHeightKey]];
//        _captureMovieFileOutput.videoSettings = dic;
        AVCaptureConnection *captureConnection = [_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        captureConnection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
        [captureConnection setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
        NSLog(@"%d",captureConnection.isVideoOrientationSupported);
        if([captureConnection isVideoStabilizationSupported])
        {
            captureConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
        }
    }
    
    // 将输出设备加入会话
    if([_captureSession canAddOutput:_captureMovieFileOutput])
    {
        [_captureSession addOutput:_captureMovieFileOutput];
    }
    
    // 创建视频预览层，实时展示摄像头状态
    _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    CALayer *layer = _viewContainer.layer;
    layer.masksToBounds = YES;
    _captureVideoPreviewLayer.frame = layer.bounds;
    _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;//填充模式
    
    // 预览层添加到界面中
    [layer insertSublayer:_captureVideoPreviewLayer below:self.focusCursor.layer];
    
    // 设置是否可旋转（外部调用设置的话注释掉），添加对焦手势；
    _enableRotation = NO;
    [self addGenstureRecognizer];
}

-(void)addGenstureRecognizer{
    UITapGestureRecognizer *tapGesture=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapScreen:)];
    [self.viewContainer addGestureRecognizer:tapGesture];
}

-(void)setFocusCursorWithPoint:(CGPoint)point{
    self.focusCursor.center=point;
    self.focusCursor.transform=CGAffineTransformMakeScale(1.5, 1.5);
    self.focusCursor.alpha=1.0;
    [UIView animateWithDuration:1.0 animations:^{
        self.focusCursor.transform=CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        self.focusCursor.alpha=0;
        
    }];
}

-(void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        // 判断当前的对焦模式、对焦模式是否支持，并根据手势设置新的对焦及曝光参数。
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        if ([captureDevice isFocusPointOfInterestSupported]) {
            [captureDevice setFocusPointOfInterest:point];
        }
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        if ([captureDevice isExposurePointOfInterestSupported]) {
            [captureDevice setExposurePointOfInterest:point];
        }
    }];
}

// 录制按钮中调用此方法来开始、结束录制；
- (void)takeButtonClick
{
    // 根据设备输出获得连接
    AVCaptureConnection *captureConnection=[_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    // 根据连接取得设备输出的数据
    if (![_captureMovieFileOutput isRecording]) {
        self.enableRotation=NO;
        // 如果支持多任务则开始多任务
        if ([[UIDevice currentDevice] isMultitaskingSupported]) {
            self.backgroundTaskIdentifier=[[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
        }
        // 预览图层和视频方向保持一致
        captureConnection.videoOrientation=[_captureVideoPreviewLayer connection].videoOrientation;
        // 视频保存到沙盒中
        NSString *outputFielPath=[NSTemporaryDirectory() stringByAppendingString:@"myMovie.mov"];
        NSURL *fileUrl=[NSURL fileURLWithPath:outputFielPath];
        [_captureMovieFileOutput startRecordingToOutputFileURL:fileUrl recordingDelegate:self];
    }
    else{
        [_captureMovieFileOutput stopRecording];//停止录制
    }
}

// 代理方法
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    // 结束录制后的操作
    NSLog(@"录制结束/暂停");
}

/**
 *  改变设备属性的统一操作方法
 *
 *  @param propertyChange 属性改变操作
 */
-(void)changeDeviceProperty:(void (^)(AVCaptureDevice *captureDevice))propertyChange
{
    AVCaptureDevice *captureDevice= [_videoCaptureDeviceInput device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }else{
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}

-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position]==position) {
            return camera;
        }
    }
    return nil;
}

// 录制结束后的操作
- (void)finishRecord
{
    [_captureMovieFileOutput stopRecording];//停止录制
    _filmProgress.progress = 0;
//    // 压缩视频
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    if([fileManager fileExistsAtPath:_outputFilePathLow])
    {
        //[fileManager removeItemAtPath:_outputFilePathLow error:nil];
    }
    if([fileManager fileExistsAtPath:_outputFielPath])
    {
        NSLog(@"愿文件存在");
    }
    [self lowQuailtyWithInputURL:[NSURL fileURLWithPath:_outputFielPath] outputURL:[NSURL fileURLWithPath:_outputFilePathLow] blockHandler:^(AVAssetExportSession *session) {
        // 压缩后删除原视频
        if([fileManager fileExistsAtPath:_outputFielPath])
        {
            //[fileManager removeItemAtPath:_outputFielPath error:nil];
        }
        if(![fileManager fileExistsAtPath:_outputFilePathLow])
        {
            NSLog(@"不存在");
        }
    }];
    
    // 获取文件大小
    long fileSizeKB = [[fileManager attributesOfItemAtPath:_outputFielPath error:nil] fileSize];
    double fileSizeMB = fileSizeKB/1024.0;
    NSNumber *fileSize = [NSNumber numberWithDouble:fileSizeMB];
    
    _finishAlert = [[UIAlertView alloc] initWithTitle:nil message:[NSString stringWithFormat:@"文件录制完成，视频大小%@MB",fileSize] delegate:self cancelButtonTitle:@"重新录制" otherButtonTitles:@"退出",nil];
    [_finishAlert show];
}

// 调用此方法压缩视频
- (void) lowQuailtyWithInputURL:(NSURL*)inputURL
                      outputURL:(NSURL*)outputURL
                   blockHandler:(void (^)(AVAssetExportSession*))handler
{
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:inputURL options:nil];
    AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetMediumQuality];
    session.outputURL = outputURL;
    session.outputFileType = AVFileTypeMPEG4;
    [session exportAsynchronouslyWithCompletionHandler:^(void)
     {
         handler(session);
     }];
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
        // 根据设备输出获得连接
        AVCaptureConnection *captureConnection=[_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        // 根据连接取得设备输出的数据
        self.enableRotation=NO;
        // 如果支持多任务则开始多任务
        if ([[UIDevice currentDevice] isMultitaskingSupported]) {
        self.backgroundTaskIdentifier=[[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
        }
        // 预览图层和视频方向保持一致
        captureConnection.videoOrientation=[_captureVideoPreviewLayer connection].videoOrientation;
        // 视频保存到沙盒中
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        if([fileManager fileExistsAtPath:_outputFielPath])
        {
            NSLog(@"exist");
            [fileManager removeItemAtPath:_outputFielPath error:nil];
        }
        NSLog(@"save path is :%@",_outputFielPath);
        NSURL *fileUrl=[NSURL fileURLWithPath:_outputFielPath];
        [_captureMovieFileOutput startRecordingToOutputFileURL:fileUrl recordingDelegate:self];
    }
}

- (void)releaseRecord:(UIButton *)button
{
    [UIView animateWithDuration:0.2 animations:^{
        _releaseLabel.alpha = 0;
    }];
    
    [self finishRecord];
}

- (void)cancelRecord:(UIButton *)button
{
    [UIView animateWithDuration:0.2 animations:^{
        _releaseLabel.alpha = 0;
    }];
    _filmProgress.progress = 0;
    
    [_captureMovieFileOutput stopRecording];//停止录制
    NSLog(@"ccc");
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
        [self finishRecord];
    }
}

-(void)tapScreen:(UITapGestureRecognizer *)tapGesture{
    CGPoint point= [tapGesture locationInView:self.viewContainer];
    // 将UI坐标转化为摄像头坐标
    CGPoint cameraPoint= [_captureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [self setFocusCursorWithPoint:point];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(alertView==_finishAlert)
    {
        switch (buttonIndex)
        {
            case 0:
            {
                break;
            }
            case 1:
            {
                NSLog(@"111111");
                [self dismissViewControllerAnimated:YES completion:nil];
                break;
            }
        }
    }
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
