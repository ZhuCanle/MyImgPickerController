//
//  BodyCell.m
//  Demo
//
//  Created by Mac mini on 15-7-8.
//  Copyright (c) 2015年 zcl. All rights reserved.
//

#import "BodyCell.h"

@implementation BodyCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if(self)
    {
        self.bodyLabel = [[UILabel alloc] init];
        self.bodyLabel.numberOfLines = 0;
        self.bodyLabel.font = [UIFont systemFontOfSize:15];
        [self.contentView addSubview:self.bodyLabel];
    }
    return self;
}

- (void)awakeFromNib {
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
