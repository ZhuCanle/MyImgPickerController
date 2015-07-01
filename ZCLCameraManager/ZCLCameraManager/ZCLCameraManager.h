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
@property (copy,nonatomic) NSString *outputFielPath;// 原文件输出路径
@property (readonly,nonatomic,getter=isExporting) BOOL isExporting;
@property (strong,nonatomic) AVCaptureDevice *videoCaptureDevice;// 设备

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
// 向取景框（预览层）添加手势
- (void)addGenstureRecognizer:(UIGestureRecognizer *)gestureRecognizer;
// 前后摄像头切换,录制中不可操作.
- (void)changeDevicePosition;

- (void)startRuning;
- (void)stopRunning;
// 开始录制视频
- (void)startVideoRunningWithOutputPath:(NSString *)path;
// 停止录制视频
- (void)stopVideoRunning;

// 压缩视频，可选择是否裁剪成正方形
- (void)compressVideoFilePath:(NSString *)path isSqure:(BOOL)squre finished:(void (^)(void))finished;
// 合并、裁剪成正方形、压缩视频到指定路径，bolck中操作ui界面要切换到主线程
- (void)mergeVideoWithFileURLS:(NSArray *)fileURLArray ToPath:(NSString *)path preset:(NSString *)preset type:(NSString *)type finished:(void (^)(void))finished;
// 获取视频输出的进度
- (float)getExportProgress;
// 判断是否在压缩视频文件
- (BOOL)isExporting;
@end

// 协议方法实现录像开始、录像结束、捕获区域改变时的操作
// mark：当协议方法中有参数为自身类时（类似UITableView的协议），可参考以下这种写法
@protocol ZCLCameraManagerDelegate <NSObject>
@optional
- (void)didStartVideoRunningCameraManager:(ZCLCameraManager *)manager;
- (void)didStopVideoRunningCameraManager:(ZCLCameraManager *)manager;
- (void)didChangeAreaCameraManager:(ZCLCameraManager *)manager;
@end

@interface ZCLCameraManager ()
@property (strong, nonatomic) id<ZCLCameraManagerDelegate> delegate;
@end

