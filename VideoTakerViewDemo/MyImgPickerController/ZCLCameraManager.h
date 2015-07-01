//
//  ZCLCameraManager.h
//  ZCLCameraManager
//
//  Created by lwj on 15/7/1.
//  Copyright (c) 2015年 ZCL. All rights reserved.
//

/*
 本类利用AVFoundation和AssetsLibrary框架封装了照相机的调用和设置
 目前尚未包含拍照功能，只有录像功能。
 用以下的初始化方法创建对象，将同时创建一个会话，包含捕获设备、输入对象、输出对象。
 调用setContainerViewLayerToView:focusCursor:方法可以设置预览层（屏幕上的相机取景框）
    具体方法是，再界面中创建一个预览用的UIView并添加到视图中，创建一个对焦框的UIImageView不需要添加到视图中，并分别作为参数调用该方法，即可把预览层的layer加到界面的预览用UIView中。
 调用changeDeviceProperty:方法设置设备属性，该方法会为我们lock和unlock设备，只需要在Block中修改相机属性
 闪光模式、对焦模式、曝光模式的修改方法均调用changeDeviceProperty:方法。
 不要忘记在调用相机的界面中调用startRuning和stopRunning开始结束会话
 协议ZCLCameraManagerDelegate中三个方法，在开始录制、结束录制、设计捕获区域改变时调用
 两个压缩视频的方法，在导出未结束时不能再调用，block中操作UI界面需要切换到主线程操作。
    ——朱灿乐
 */

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
@property (readonly,nonatomic,getter=isExporting) BOOL isExporting;
@property (strong,nonatomic) AVCaptureDevice *videoCaptureDevice;// 设备

// 初始化管理对象并创建一个会话
- (id)initSessionWithMediaType:(ZCLCameraMediaType)cameraType preset:(NSString *)preset position:(AVCaptureDevicePosition)position;
// 设置预览层和对焦光标
- (CALayer *)setContainerViewLayerToView:(UIView *)view focusCursor:(UIImageView *)focusCursor;
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
// 获取默认的单击手势对象（单击对焦）
- (UITapGestureRecognizer *)getSingleTapGestureRecognizer;

// 开始、结束会话
- (void)startRuning;
- (void)stopRunning;
// 开始录制视频
- (void)startVideoRunningWithOutputPath:(NSString *)path;
// 停止录制视频
- (void)stopVideoRunning;

// 压缩视频，可选择是否裁剪成正方形
- (void)compressVideoInputFilePath:(NSString *)inPath outputFilePath:(NSString *)outPath isSqure:(BOOL)squre finished:(void (^)(void))finished;
// 合并、裁剪成正方形、压缩视频到指定路径，bolck中操作ui界面要切换到主线程
- (void)mergeVideoWithFileURLS:(NSArray *)fileURLArray ToPath:(NSString *)path preset:(NSString *)preset type:(NSString *)type finished:(void (^)(void))finished;
// 获取视频输出的进度
- (float)getExportProgress;
// 判断是否在压缩视频文件
- (BOOL)isExporting;
@end

// 协议方法实现录像开始、录像结束、捕获区域改变时的操作
// mark：当协议方法中有参数为自身类时（类似UITableView的协议），可参考以下这种写法
// mark:当有可选方法时，要调用respondToSelector：方法来判断代理对象是否有实现相应的方法再执行该方法，否则会崩溃.
@protocol ZCLCameraManagerDelegate <NSObject>
@optional
- (void)didStartVideoRunningCameraManager:(ZCLCameraManager *)manager;
- (void)didStopVideoRunningCameraManager:(ZCLCameraManager *)manager;
- (void)didChangeAreaCameraManager:(ZCLCameraManager *)manager;
@end

@interface ZCLCameraManager ()
@property (strong, nonatomic) id<ZCLCameraManagerDelegate> delegate;
@end

