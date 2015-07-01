//
//  PhotoTakerViewController.h
//  MyImgPickerController
//
//  Created by lwj on 15/6/25.
//  Copyright (c) 2015年 root. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

@interface PhotoTakerViewController : UIViewController
@property (assign,nonatomic) BOOL enableRotation;//是否允许旋转（注意在视频录制过程中禁止屏幕旋转）
@property (assign,nonatomic) CGRect *lastBounds;//旋转的前大小
@property (assign,nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;//后台任务标识
@property (strong, nonatomic)  UIView *viewContainer;
@property (strong, nonatomic)  UIButton *takeButton;//拍照按钮
@property (strong, nonatomic)  UIImageView *focusCursor; //聚焦光标


@end
