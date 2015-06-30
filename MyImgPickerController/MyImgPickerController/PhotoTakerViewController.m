//
//  PhotoTakerViewController.m
//  MyImgPickerController
//
//  Created by lwj on 15/6/25.
//  Copyright (c) 2015年 root. All rights reserved.
//  AVFoundation定制相机界面，裁剪视频规格，压缩视频，单双击手势的冲突解决。

#import "PhotoTakerViewController.h"

#import "UIView+ZCLQuickControl.h"

#import <Masonry.h>
#import <SVProgressHUD.h>

#define MAX_RECORD_TIME 15
#define PROGRESS_MOVE_PERTIME 0.0006666667

@interface PhotoTakerViewController () <UIAlertViewDelegate,AVCaptureFileOutputRecordingDelegate>
{
    AVCaptureSession *_captureSession;// 会话，负责输入和输出设备之间的数据传递
    AVCaptureDeviceInput *_videoCaptureDeviceInput;// 负责从AVCaptureDevice获得输入数据
    AVCaptureDeviceInput *_audioCaptureDeviceInput;
    AVCaptureMovieFileOutput *_captureMovieFileOutput;// 音频输出流
    AVCaptureVideoPreviewLayer *_captureVideoPreviewLayer;// 相机拍摄预览图层
    AVAssetWriter *_writer;
    AVAssetWriterInput *_writerInput;
    
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
    BOOL _isProcessingData;
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
    self.focusCursor = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"1352205788135321393.png"]];
    self.focusCursor.frame = CGRectMake(0, 0, 60, 60);
    self.focusCursor.center = CGPointMake(_viewContainer.frame.size.width/2, _viewContainer.frame.size.height/2);
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
    // 初始化会话
    _captureSession = [[AVCaptureSession alloc] init];
    if([_captureSession canSetSessionPreset:AVCaptureSessionPresetHigh])
    {
        _captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    }
    // 获得输入设备
    // 视频输入设备
    AVCaptureDevice *videoCaptureDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];//获取后置摄像头
    if(!videoCaptureDevice)
    {
        NSLog(@"无法获取后置摄像头");
    }
    
    // 修改设备的activeFormat时参考以下注释
//    [videoCaptureDevice lockForConfiguration:nil];
//    AVCaptureDeviceFormat *format = [[videoCaptureDevice formats] firstObject];
//    for(AVCaptureDeviceFormat *format in [videoCaptureDevice formats])
//    {
//        NSLog(@"%@",format.formatDescription);
//    }
//    videoCaptureDevice.activeFormat = videoCaptureDevice.formats[4];
//    NSLog(@"%@",videoCaptureDevice.activeFormat.formatDescription);
//    CMTime max = ((AVFrameRateRange *)[videoCaptureDevice.activeFormat.videoSupportedFrameRateRanges firstObject]).maxFrameDuration;
//    CMTime min = ((AVFrameRateRange *)[videoCaptureDevice.activeFormat.videoSupportedFrameRateRanges firstObject]).minFrameDuration;
//    NSLog(@"%u,%d,%lld",max.flags,max.timescale,max.value);
    
//    [videoCaptureDevice setActiveVideoMaxFrameDuration:min];
//    [videoCaptureDevice setActiveVideoMinFrameDuration:min];
//    [videoCaptureDevice unlockForConfiguration];
    
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
        // 设置防抖模式
        if([captureConnection isVideoStabilizationSupported])
        {
            captureConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeCinematic;
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
    
    // 添加通知
    [self addNotificationForDevice:videoCaptureDevice];

}

-(void)addGenstureRecognizer
{
    // 单击手势，用于对焦（相机必备功能）
    UITapGestureRecognizer *singleTapGesture=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapScreen:)];
    [singleTapGesture setNumberOfTapsRequired:1];
    [self.viewContainer addGestureRecognizer:singleTapGesture];
    
    // 双击手势，调整视野（微信小视频功能）
    UITapGestureRecognizer *doubleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapScreen:)];
    [doubleTapGesture setNumberOfTapsRequired:2];
    [self.viewContainer addGestureRecognizer:doubleTapGesture];
    
    // 单击手势需要双击手势不存在或失败时才能激活（防止冲突）
    [singleTapGesture requireGestureRecognizerToFail:doubleTapGesture];
    
}

-(void)setFocusCursorWithPoint:(CGPoint)point{
    self.focusCursor.center=point;
    if(_focusTimer!=nil)
    {
        [_focusTimer invalidate];
    }
    self.focusCursor.alpha = 1.0;
    _focusTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(focusTimer:) userInfo:nil repeats:NO];
}

- (void)focusTimer:(NSTimer *)timer
{
    self.focusCursor.alpha = 0.0;
    [_focusTimer invalidate];
}

-(void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point
{
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
    if (![_captureMovieFileOutput isRecording])
    {
        self.enableRotation=NO;
        // 如果支持多任务则开始多任务
        if ([[UIDevice currentDevice] isMultitaskingSupported])
        {
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


// 改变设备属性的统一操作方法(调用时在block中修改设备属性)
-(void)changeDeviceProperty:(void (^)(AVCaptureDevice *captureDevice))propertyChange
{
    AVCaptureDevice *captureDevice= [_videoCaptureDeviceInput device];
    NSError *error;
    // 注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error])
    {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }
    else
    {
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

// 添加通知，为相机的区域改变、对焦、曝光改变等做出相应的操作
- (void)addNotificationForDevice:(AVCaptureDevice *)device
{
    //注意添加区域改变捕获通知必须首先设置设备允许捕获
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        captureDevice.subjectAreaChangeMonitoringEnabled=YES;
    }];
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    //捕获区域发生改变
    [notificationCenter addObserver:self selector:@selector(areaChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:device];
}

#pragma mark - 视频合并、裁剪、压缩
// 把视频裁剪成正方形并压缩
- (void)mergeVideoWithFinished:(void (^)(void))finished
{
    //
    AVMutableComposition *composition = [[AVMutableComposition alloc] init];//初始化剪辑对象
    CMTime totalDuration = kCMTimeZero;//视频长度，预设为0；
    AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:_outputFielPath]];//用原视频初始化一个asset对象
    AVAssetTrack *videoAssetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];//取其视频轨
    
    AVMutableCompositionTrack *audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];//初始化一个音轨剪辑对象
    [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:[[asset tracksWithMediaType:AVMediaTypeAudio] firstObject] atTime:kCMTimeZero error:nil];//把原视频asset的音插入音轨剪辑对象，范围是视频起始到最后一秒，插入位置为0秒。
    AVMutableCompositionTrack *videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];//初始化一个视频剪辑对象
    [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:videoAssetTrack atTime:kCMTimeZero error:nil];//把原视频asset的视频轨插入视频剪辑对象，范围是视频起始到最后一秒，插入位置为0秒。

    AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];//用视频剪辑对象创建一个layerInstruction，该对象用于裁剪视频、模糊化等操作；
    totalDuration = CMTimeAdd(totalDuration, asset.duration);//视频总长
    
    // 获取剪辑区域
    CGSize renderSize = CGSizeMake(0, 0);
    renderSize.width = MAX(renderSize.width, videoAssetTrack.naturalSize.height);
    renderSize.height = MAX(renderSize.height, videoAssetTrack.naturalSize.width);
    CGFloat renderW = MIN(renderSize.width, renderSize.height);
    CGFloat rate;
    rate = renderW / MIN(videoAssetTrack.naturalSize.width, videoAssetTrack.naturalSize.height);
    CGAffineTransform layerTransform = CGAffineTransformMake(videoAssetTrack.preferredTransform.a, videoAssetTrack.preferredTransform.b, videoAssetTrack.preferredTransform.c, videoAssetTrack.preferredTransform.d, videoAssetTrack.preferredTransform.tx * rate, videoAssetTrack.preferredTransform.ty * rate);
    layerTransform = CGAffineTransformConcat(layerTransform, CGAffineTransformMake(1, 0, 0, 1, 0, -(videoAssetTrack.naturalSize.width - videoAssetTrack.naturalSize.height) / 2.0));//向上移动取中部影响
    layerTransform = CGAffineTransformScale(layerTransform, rate, rate);//放缩，解决前后摄像结果大小不对称
    // 把该区域设定为layerInstruction的剪辑区域
    [layerInstruction setTransform:layerTransform atTime:kCMTimeZero];
    [layerInstruction setOpacity:0.0 atTime:totalDuration];
    
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];//创建一个剪辑指令
    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, totalDuration);//时间为从视频起始到结束
    instruction.layerInstructions = @[layerInstruction];//设定剪辑区域为上面的layerInstruction对象，放在数组中。
    AVMutableVideoComposition *mainComposition = [AVMutableVideoComposition videoComposition];//创建一个视频剪辑对象
    mainComposition.instructions = @[instruction];//设定剪辑指令为上面常见的剪辑指令，放在数组中
    mainComposition.frameDuration = CMTimeMake(1, 30);//设定帧速率
    mainComposition.renderSize = CGSizeMake(renderW, renderW);//设定渲染区域大小，高宽均为原视频的宽。
    
    // 导出视频
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetMediumQuality];
    exporter.videoComposition = mainComposition;
    exporter.outputURL = [NSURL fileURLWithPath:_outputFilePathLow];
    exporter.outputFileType = AVFileTypeQuickTimeMovie;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        // 如果要在此处操作UI应切换到主线程操作
        finished();
    }];
    
}
// 合并和裁剪视频(包含上一个方法的功能)
- (void)mergeAndExportVideosAtFileURLs:(NSArray *)fileURLArray
{
    NSError *error = nil;
    
    CGSize renderSize = CGSizeMake(0, 0);
    
    NSMutableArray *layerInstructionArray = [[NSMutableArray alloc] init];
    
    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
    
    CMTime totalDuration = kCMTimeZero;
    
    //先去assetTrack 也为了取renderSize
    NSMutableArray *assetTrackArray = [[NSMutableArray alloc] init];
    NSMutableArray *assetArray = [[NSMutableArray alloc] init];
    for (NSURL *fileURL in fileURLArray) {
        AVAsset *asset = [AVAsset assetWithURL:fileURL];
        
        if (!asset) {
            continue;
        }
        
        [assetArray addObject:asset];
        
        AVAssetTrack *assetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        [assetTrackArray addObject:assetTrack];
        
        renderSize.width = MAX(renderSize.width, assetTrack.naturalSize.height);
        renderSize.height = MAX(renderSize.height, assetTrack.naturalSize.width);
    }
    
    CGFloat renderW = MIN(renderSize.width, renderSize.height);
    
    for (int i = 0; i < [assetArray count] && i < [assetTrackArray count]; i++) {
        
        AVAsset *asset = [assetArray objectAtIndex:i];
        AVAssetTrack *assetTrack = [assetTrackArray objectAtIndex:i];
        
        AVMutableCompositionTrack *audioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                            ofTrack:[[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0]
                             atTime:totalDuration
                              error:nil];
        
        AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        
        [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                            ofTrack:assetTrack
                             atTime:totalDuration
                              error:&error];
        
        //fix orientationissue
        AVMutableVideoCompositionLayerInstruction *layerInstruciton = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
        
        totalDuration = CMTimeAdd(totalDuration, asset.duration);
        
        CGFloat rate;
        rate = renderW / MIN(assetTrack.naturalSize.width, assetTrack.naturalSize.height);
        
        CGAffineTransform layerTransform = CGAffineTransformMake(assetTrack.preferredTransform.a, assetTrack.preferredTransform.b, assetTrack.preferredTransform.c, assetTrack.preferredTransform.d, assetTrack.preferredTransform.tx * rate, assetTrack.preferredTransform.ty * rate);
        layerTransform = CGAffineTransformConcat(layerTransform, CGAffineTransformMake(1, 0, 0, 1, 0, -(assetTrack.naturalSize.width - assetTrack.naturalSize.height) / 2.0));//向上移动取中部影响
        layerTransform = CGAffineTransformScale(layerTransform, rate, rate);//放缩，解决前后摄像结果大小不对称
        
        [layerInstruciton setTransform:layerTransform atTime:kCMTimeZero];
        [layerInstruciton setOpacity:0.0 atTime:totalDuration];
        
        //data
        [layerInstructionArray addObject:layerInstruciton];
    }
    
    //export
    AVMutableVideoCompositionInstruction *mainInstruciton = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruciton.timeRange = CMTimeRangeMake(kCMTimeZero, totalDuration);
    mainInstruciton.layerInstructions = layerInstructionArray;
    AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];
    mainCompositionInst.instructions = @[mainInstruciton];
    mainCompositionInst.frameDuration = CMTimeMake(1, 30);
    mainCompositionInst.renderSize = CGSizeMake(renderW, renderW);
    
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetMediumQuality];
    exporter.videoComposition = mainCompositionInst;
    exporter.outputURL = [NSURL fileURLWithPath:_outputFilePathLow];
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
    }];
}

#pragma mark - AVCaptureFileOutputRecordingDelegate
// 录制操作结束后的操作
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    // 数据写入中标记
    _isProcessingData = NO;
    
    // 取消操作造成的停止录制讲不进行后面的操作
    if(_isCancel==YES)
    {
        return;
    }
    
    // 数据处理中的UI界面效果
    [SVProgressHUD showWithStatus:@"处理中"];
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
    if([fileManager fileExistsAtPath:_outputFilePathLow])
    {
        [fileManager removeItemAtPath:_outputFilePathLow error:nil];
    }
    if([fileManager fileExistsAtPath:_outputFielPath])
    {
        NSLog(@"愿文件存在");
        [self mergeVideoWithFinished:^{
            // 结束后切换到主线程操作UI
            dispatch_async(dispatch_get_main_queue(), ^{
                // 获取文件大小
                NSFileManager *fileManager = [[NSFileManager alloc] init];
                long fileSizeB = [[fileManager attributesOfItemAtPath:_outputFilePathLow error:nil] fileSize];
                double fileSizeKB = fileSizeB/1024.0;
                // UI操作
                _finishAlert = [[UIAlertView alloc] initWithTitle:nil message:[NSString stringWithFormat:@"视频录制完成，文件大小%.2fKB",fileSizeKB] delegate:self cancelButtonTitle:@"重新录制" otherButtonTitles:@"退出",nil];
                [_finishAlert show];
                [SVProgressHUD dismiss];
            });
        }];
    }

}

// 录制开始时的操作
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    // 数据写入标记
    _isProcessingData = YES;
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
    
    _isCancel = NO;
    [_captureMovieFileOutput stopRecording];
}

- (void)cancelRecord:(UIButton *)button
{
    [UIView animateWithDuration:0.2 animations:^{
        _releaseLabel.alpha = 0;
    }];
    _filmProgress.progress = 0;
    
    _isCancel = YES;
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
        [_progressTimer invalidate];
        _isCancel = NO;
        [_captureMovieFileOutput stopRecording];
        [UIView animateWithDuration:0.2 animations:^{
            _releaseLabel.alpha = 0;
        }];
    }
}

-(void)tapScreen:(UITapGestureRecognizer *)tapGesture
{
    CGPoint point= [tapGesture locationInView:self.viewContainer];
    // 将UI坐标转化为摄像头坐标
    CGPoint cameraPoint= [_captureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [self setFocusCursorWithPoint:point];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
}

- (void)doubleTapScreen:(UITapGestureRecognizer *)tapGesture
{
    if([_zoomTimer isValid])
    {
        return;
    }
    AVCaptureDevice *device = [_videoCaptureDeviceInput device];
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
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
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
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
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

// 设备捕获区域改变
-(void)areaChange:(NSNotification *)notification
{
//     [self setFocusCursorWithPoint:];
//     NSLog(@"捕获区域改变...");
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




/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
