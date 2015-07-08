//
//  NetworkModel.h
//  Demo
//
//  Created by Mac mini on 15-7-8.
//  Copyright (c) 2015年 zcl. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NetworkModel : NSObject
@property (nonatomic,copy) NSString *userName;
@property (nonatomic,copy) NSString *userDescribe;
@property (nonatomic,copy) NSString *iconName;
@property (nonatomic,copy) NSString *commentBody;
@property (nonatomic,strong) NSArray *commentPics;
@property (nonatomic,strong) NSDate *date;
@property (nonatomic,strong) NSArray *comments;
@property (nonatomic,strong) NSArray *thumbs;
@end
