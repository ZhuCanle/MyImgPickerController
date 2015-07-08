//
//  UserCell.h
//  Demo
//
//  Created by Mac mini on 15-7-8.
//  Copyright (c) 2015年 zcl. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UserCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *iconImagerView;
@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *userDescribeLabel;

@end
