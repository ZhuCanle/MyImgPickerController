//
//  MyImgPickerController.m
//  MyImgPickerController
//
//  Created by lwj on 15/6/25.
//  Copyright (c) 2015年 root. All rights reserved.
//

#import "MyImgPickerController.h"

#import "UIView+ZCLQuickControl.h"

#import <Masonry.h>

@implementation MyImgPickerController

- (void)viewDidLoad
{

    self.allowsEditing = YES;
    self.cameraViewTransform = CGAffineTransformMakeScale(1, 0.5);

    UIView *upper = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 180)];
    upper.backgroundColor = [UIColor blackColor];
    [self.view addSubview:upper];
    UIView *lower = [[UIView alloc] initWithFrame:CGRectMake(0, 400, self.view.frame.size.width, 400)];
    lower.backgroundColor = [UIColor blackColor];
    [self.view addSubview:lower];
    self.videoQuality = UIImagePickerControllerQualityTypeMedium;
    self.cameraCaptureMode = UIImagePickerControllerCameraCaptureModeVideo;
}


@end
