//
//  ZCLCameraManager.m
//  ZCLCameraManager
//
//  Created by lwj on 15/7/1.
//  Copyright (c) 2015年 ZCL. All rights reserved.
//

#import "ZCLCameraManager.h"

@implementation ZCLCameraManager
{
    AVCaptureSession *_captureSession;// 会话，负责输入和输出设备之间的数据传递
    AVCaptureDeviceInput *_videoCaptureDeviceInput;// 负责从AVCaptureDevice获得输入数据
    AVCaptureDeviceInput *_audioCaptureDeviceInput;
    AVCaptureMovieFileOutput *_captureMovieFileOutput;// 音频输出流
    AVCaptureVideoPreviewLayer *_captureVideoPreviewLayer;// 相机拍摄预览图层
    AVAssetWriter *_writer;
    AVAssetWriterInput *_writerInput;
    AVAssetExportSession *_exporter;// 用于导出编辑过的视频
    
    UIButton *_recordBtn;
    UIProgressView *_filmProgress;
    NSTimer *_progressTimer;
    NSTimer *_focusTimer;
    NSTimer *_zoomTimer;
    UILabel *_releaseLabel;
    UILabel *zoomLabel;
    UIAlertView *_finishAlert;
    UIView *_darkView;
    UIView *_viewContainer;
    UIImageView *_focusCursor; //聚焦光标
    UITapGestureRecognizer *_singleTapGesture;
    BOOL _isCancel;// 取消录制标记（取消录制操作后不进行视频裁剪和压缩处理）
    BOOL _isProcessingData;
}

#pragma mark - API
- (id)initSessionWithMediaType:(ZCLCameraMediaType)cameraType preset:(NSString *)preset position:(AVCaptureDevicePosition)position
{
    self = [super init];
    if(self)
    {
        if(cameraType==ZCLCameraMediaTypeVideo)
        {
            [self createVideoSessionWithPreset:(NSString *)preset position:(AVCaptureDevicePosition)position];
        }
        else
        {
            // 创建照相会话
        }
    }
    return self;
}

- (float)getExportProgress
{
    return _exporter.progress;
}

// 改变设备属性的统一操作方法(调用时在block中修改设备属性)
- (void)changeDeviceProperty:(void (^)(AVCaptureDevice *captureDevice))propertyChange
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

- (void)setFocusMode:(AVCaptureFocusMode)focusMode
{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        captureDevice.focusMode = focusMode;
    }];
}

- (NSArray *)getFormats
{
    return _videoCaptureDevice.formats;
}

- (void)setActiveFormatsWithIndex:(NSInteger)index withMaxFrameDuration:(CMTime)max minFrameDuration:(CMTime)min
{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        [captureDevice setActiveFormat:[[captureDevice formats] objectAtIndex:index]];
        [captureDevice setActiveVideoMaxFrameDuration:max];
        [captureDevice setActiveVideoMinFrameDuration:min];
    }];
}

- (void)setFlashMode:(AVCaptureFlashMode )flashMode
{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFlashModeSupported:flashMode]) {
            [captureDevice setFlashMode:flashMode];
        }
    }];
}

-(void)setExposureMode:(AVCaptureExposureMode)exposureMode
{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:exposureMode];
        }
    }];
}

- (CALayer *)setContainerViewLayerToView:(UIView *)view focusCursor:(UIImageView *)focusCursor
{
    _viewContainer = view;
    // 对焦框
    _focusCursor = focusCursor;
    _focusCursor.frame = CGRectMake(0, 0, 60, 60);
    _focusCursor.center = CGPointMake(_viewContainer.frame.size.width/2, _viewContainer.frame.size.height/2);
    _focusCursor.alpha = 0;
    [_viewContainer addSubview:_focusCursor];

    // 创建视频预览层，实时展示摄像头状态
    _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    CALayer *layer = _viewContainer.layer;
    layer.masksToBounds = YES;
    _captureVideoPreviewLayer.frame = layer.bounds;
    _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;//填充模式
    
    // 预览层添加到界面中
    [layer insertSublayer:_captureVideoPreviewLayer below:_focusCursor.layer];
    
    // 单击手势，用于对焦（相机必备功能）
    _singleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapScreen:)];
    [_singleTapGesture setNumberOfTapsRequired:1];
    [self addGenstureRecognizer:_singleTapGesture];
    
    return _captureVideoPreviewLayer;
}

- (void)startVideoRunningWithOutputPath:(NSString *)path
{
    // 根据设备输出获得连接
    AVCaptureConnection *captureConnection = [_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    self.enableRotation=NO;
    // 如果支持多任务则开始多任务
    if ([[UIDevice currentDevice] isMultitaskingSupported])
    {
        self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
    }
    // 预览图层和视频方向保持一致
    captureConnection.videoOrientation = [_captureVideoPreviewLayer connection].videoOrientation;
    // 视频保存到沙盒中
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    if([fileManager fileExistsAtPath:path])
    {
        NSLog(@"exist");
        [fileManager removeItemAtPath:path error:nil];
    }
    NSURL *fileUrl=[NSURL fileURLWithPath:path];
    [_captureMovieFileOutput startRecordingToOutputFileURL:fileUrl recordingDelegate:self];
}

- (void)stopVideoRunning
{
    [_captureMovieFileOutput stopRecording];//停止录制
}

- (void)mergeVideoWithFileURLS:(NSArray *)fileURLArray ToPath:(NSString *)path preset:(NSString *)preset type:(NSString *)type finished:(void (^)(void))finished;
{
    if(_isProcessingData)
    {
        return;
    }
    
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

    AVAssetTrack *videoTrack = [assetTrackArray firstObject];
    mainCompositionInst.renderSize = videoTrack.naturalSize;
    
    // 导出视频
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    if([fileManager fileExistsAtPath:path])
    {
        [fileManager removeItemAtPath:path error:nil];
    }
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetMediumQuality];
    exporter.videoComposition = mainCompositionInst;
    exporter.outputURL = [NSURL fileURLWithPath:path];
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        // 该方法为异步操作，因此如果要在此Block中操作UI应切换到主线程操作
        finished();
    }];

}

- (void)compressVideoInputFilePath:(NSString *)inPath outputFilePath:(NSString *)outPath isSqure:(BOOL)squre finished:(void (^)(void))finished
{
    if(_isProcessingData)
    {
        return;
    }
    
    AVMutableComposition *composition = [[AVMutableComposition alloc] init];//初始化剪辑对象
    CMTime totalDuration = kCMTimeZero;//视频长度，预设为0；
    AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:inPath]];//用原视频初始化一个asset对象
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
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    if([fileManager fileExistsAtPath:outPath])
    {
        [fileManager removeItemAtPath:outPath error:nil];
    }
    _exporter = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetMediumQuality];
    _exporter.videoComposition = mainComposition;
    _exporter.outputURL = [NSURL fileURLWithPath:outPath];
    _exporter.outputFileType = AVFileTypeQuickTimeMovie;
    //exporter.shouldOptimizeForNetworkUse = YES;
    [_exporter exportAsynchronouslyWithCompletionHandler:^{
        // 该方法为异步操作，因此如果要在此Block中操作UI应切换到主线程操作
        finished();
    }];
}

- (BOOL)isExporting
{
    return _isProcessingData;
}

- (void)changeDevicePosition
{
    if(_videoCaptureDevice.position==AVCaptureDevicePositionBack)
    {
        _videoCaptureDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionFront];
    }
    else
    {
        _videoCaptureDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];
    }
}

- (void)startRuning
{
    [_captureSession startRunning];
}

- (void)stopRunning
{
    [_captureSession stopRunning];
}

- (void)addGenstureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    [_viewContainer addGestureRecognizer:gestureRecognizer];
}

- (UITapGestureRecognizer *)getSingleTapGestureRecognizer
{
    return _singleTapGesture;
}

#pragma mark - 自用方法
- (void)createVideoSessionWithPreset:(NSString *)preset position:(AVCaptureDevicePosition)position
{
    // 初始化会话
    _captureSession = [[AVCaptureSession alloc] init];
    if([_captureSession canSetSessionPreset:preset])
    {
        _captureSession.sessionPreset = preset;
    }
    // 获得输入设备
    // 视频输入设备
    _videoCaptureDevice = [self getCameraDeviceWithPosition:position];//获取后置摄像头
    if(!_videoCaptureDevice)
    {
        NSLog(@"无法获取后置摄像头");
    }
    // 对焦模式
    [_videoCaptureDevice lockForConfiguration:nil];
    _videoCaptureDevice.focusMode = AVCaptureFocusModeContinuousAutoFocus;
    // 修改设备的activeFormat时参考以下注释
    //    for(AVCaptureDeviceFormat *format in [videoCaptureDevice formats])
    //    {
    //        NSLog(@"%@",format.formatDescription);
    //    }
    //    videoCaptureDevice.activeFormat = videoCaptureDevice.formats[11];
    //    NSLog(@"%@",videoCaptureDevice.activeFormat.formatDescription);
    //    CMTime max = ((AVFrameRateRange *)[videoCaptureDevice.activeFormat.videoSupportedFrameRateRanges firstObject]).maxFrameDuration;
    //    CMTime min = ((AVFrameRateRange *)[videoCaptureDevice.activeFormat.videoSupportedFrameRateRanges firstObject]).minFrameDuration;
    //    NSLog(@"%u,%d,%lld",max.flags,max.timescale,max.value);
    //    [videoCaptureDevice setActiveVideoMaxFrameDuration:CMTimeMake(1, 30)];
    //    [videoCaptureDevice setActiveVideoMinFrameDuration:CMTimeMake(1, 30)];
    [_videoCaptureDevice unlockForConfiguration];
    
    // 音频输入设备
    AVCaptureDevice *audioCaptureDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    
    // 初始化设备输入对象，用于获取输入数据
    NSError *error = nil;
    _videoCaptureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:_videoCaptureDevice error:&error];
    if(error || !_videoCaptureDevice)
    {
        NSLog(@"获取输入对象，%@",error.localizedDescription);
        return;
    }
    _audioCaptureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioCaptureDevice error:&error];
    if(error || !_audioCaptureDeviceInput)
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
    
    // 设置是否可旋转（外部调用设置的话注释掉），添加手势、通知；
    _enableRotation = NO;
    // 添加通知
    [self addNotificationForDevice:_videoCaptureDevice];
}

- (AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position
{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position]==position) {
            return camera;
        }
    }
    return nil;
}

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

- (void)tapScreen:(UITapGestureRecognizer *)tapGesture
{
    CGPoint point= [tapGesture locationInView:_viewContainer];
    // 将UI坐标转化为摄像头坐标
    CGPoint cameraPoint= [_captureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [self setFocusCursorWithPoint:point];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
}

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point
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

- (void)setFocusCursorWithPoint:(CGPoint)point
{
    _focusCursor.center=point;
    if(_focusTimer!=nil)
    {
        [_focusTimer invalidate];
    }
    _focusCursor.alpha = 1.0;
    _focusTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(focusTimer:) userInfo:nil repeats:NO];
}

- (void)focusTimer:(NSTimer *)timer
{
    _focusCursor.alpha = 0.0;
    [_focusTimer invalidate];
}

- (void)areaChange:(NSNotification *)notification
{
    if([self.delegate respondsToSelector:@selector(didChangeAreaCameraManager:)] )
    {
        [self.delegate didChangeAreaCameraManager:self];
    }
}

#pragma mark - AVCaptureFileOutputRecordingDelegate
// 录制操作结束后的操作
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    _isProcessingData = NO;
    if([self.delegate respondsToSelector:@selector(didStopVideoRunningCameraManager:)])
    {
        [self.delegate didStopVideoRunningCameraManager:self];
    }
}

// 录制开始时的操作
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    _isProcessingData = YES;
    if([self.delegate respondsToSelector:@selector(didStartVideoRunningCameraManager:)])
    {
        [self.delegate didStartVideoRunningCameraManager:self];
    }
}

@end
