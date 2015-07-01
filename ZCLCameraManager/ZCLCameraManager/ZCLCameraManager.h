//
//  ZCLCameraManager.h
//  ZCLCameraManager
//
//  Created by lwj on 15/7/1.
//  Copyright (c) 2015年 ZCL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <UIKit/UIKit.h>

typedef enum{
    ZCLCameraMediaTypePhoto,
    ZCLCameraMediaTypeVideo
}ZCLCameraMediaType;

@interface ZCLCameraManager : NSObject <AVCaptureFileOutputRecordingDelegate>

@property (assign,nonatomic) BOOL enableRotation;//是否允许旋转（注意在视频录制过程中禁止屏幕旋转）
@property (assign,nonatomic) CGRect *lastBounds;//旋转的前大小
@property (assign,nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;//后台任务标识
@property (strong, nonatomic)  UIView *viewContainer;
@property (strong, nonatomic)  UIButton *takeButton;//拍照按钮
@property (strong, nonatomic)  UIImageView *focusCursor; //聚焦光标

// 初始化管理对象并创建一个会话
- (id)initSessionWithMediaType:(ZCLCameraMediaType)cameraType preset:(NSString *)preset position:(AVCaptureDevicePosition)position;
// 设置预览层和对焦光标
- (void)setContainerViewLayerToView:(UIView *)view focusCursor:(UIImageView *)focusCursor;
// 使用Block设置设备属性
- (void)changeDeviceProperty:(void (^)(AVCaptureDevice *captureDevice))propertyChange;
// 设置对焦模式
- (void)setFocusMode:(AVCaptureFocusMode)focusMode;
// 获取当前设备支持的格式(activeFormat)
- (NSArray *)getFormats;
// 设置设备格式支持列表中的格式(activeFormat)
- (void)setActiveFormatsWithIndex:(NSInteger)index withMaxFrameDuration:(CMTime)max minFrameDuration:(CMTime)min;
// 设置闪光模式
- (void)setFlashMode:(AVCaptureFlashMode )flashMode;
// 设置曝光模式
- (void)setExposureMode:(AVCaptureExposureMode)exposureMode;

// 开始录制视频
- (void)startVideoRunningWithOutputPath:(NSString *)path;
// 停止录制视频
- (void)stopVideoRunning;

// 合并、压缩视频到指定路径，可选择是否裁剪成正方形
- (void)mergeVideoWithFileURLS:(NSArray *)fileURLArray ToPath:(NSString *)path preset:(NSString *)preset type:(NSString *)type cutToSqure:(BOOL)squre WithFinished:(void (^)(void))finished;

@end
