//
//  NetworkViewController.m
//  Demo
//
//  Created by Mac mini on 15-7-8.
//  Copyright (c) 2015年 zcl. All rights reserved.
//

#import "NetworkViewController.h"
#import "UserCell.h"
#import "BodyCell.h"
#import "NetworkModel.h"

#import <Masonry.h>

#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height
#define SCREEN_RECT [UIScreen mainScreen].bounds

@interface NetworkViewController () <UITableViewDataSource,UITableViewDelegate>
{
    UITableView *_tableView;
    NSMutableArray *_dataArray;
}

@end

@implementation NetworkViewController

#pragma mark - VC Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    _dataArray = [[NSMutableArray alloc] init];
    
    [self configNavigationBar];
    [self createTableView];
    [self requestData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITableViewDataSource,UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _dataArray.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 2;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.row==0)
    {
        return 60;
    }
    else
    {
        NetworkModel *model = _dataArray[indexPath.section];
        CGSize bodyLabelSize = [model.commentBody boundingRectWithSize:CGSizeMake(SCREEN_WIDTH-20, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:15]} context:nil].size;
        NSLog(@"/////%ld  %f,%f",(long)indexPath.section,bodyLabelSize.height,bodyLabelSize.width);
        return bodyLabelSize.height+18;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NetworkModel *model = _dataArray[indexPath.section];
    if(indexPath.row==0)
    {
        UserCell *cell = [[[NSBundle mainBundle] loadNibNamed:@"UserCell" owner:self options:nil] firstObject];
        cell.iconImagerView.image = [UIImage imageNamed:model.iconName];
        cell.userNameLabel.text = model.userName;
        cell.userDescribeLabel.text = model.userDescribe;
        return cell;
    }
    else
    {
        //BodyCell *cell = [[[NSBundle mainBundle] loadNibNamed:@"BodyCell" owner:self options:nil] firstObject];
        static NSString *bodyCellIdentifier = @"bodyCell";
        BodyCell *cell = [_tableView dequeueReusableCellWithIdentifier:bodyCellIdentifier];
        if(cell==nil)
        {
            cell = [[BodyCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:bodyCellIdentifier];
        }
        CGSize bodyLabelSize = [model.commentBody boundingRectWithSize:CGSizeMake(SCREEN_WIDTH-20, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:15.0]} context:nil].size;
        NSLog(@"aaaaaa %f,%f",bodyLabelSize.width,bodyLabelSize.height);
        [cell.bodyLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.mas_equalTo(@0);
            make.leading.mas_equalTo(@10);
            make.trailing.mas_equalTo(@-10);
            make.height.mas_equalTo(bodyLabelSize.height+18);
        }];
        cell.bodyLabel.text = model.commentBody;
        return cell;
    }
}

#pragma mark - UI

- (void)configNavigationBar
{
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 180, 30)];
    titleLabel.text = @"人脉圈";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    self.navigationItem.titleView = titleLabel;
    
    UIButton *rightBarBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [rightBarBtn setImage:[UIImage imageNamed:@"index_btn_sign.png"] forState:UIControlStateNormal];
    rightBarBtn.frame = CGRectMake(0, 0, 40, 40);
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:rightBarBtn];

}

- (void)createTableView
{
    _tableView = [[UITableView alloc] initWithFrame:SCREEN_RECT style:UITableViewStylePlain];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [self.view addSubview:_tableView];
    
}

#pragma mark - Download and Analysis Data
- (void)requestData
{
    /// For Test.
    NSArray *userNameArray = @[@"吖Moon",@"赵大纯",@"快摇名片小助手"];
    NSArray *userDescribeArray = @[@"产品经理",@"iOS开发工程师",@"快摇名片官方人员"];
    NSArray *userIconArray = @[@"rBACE1QMtbeTotShAAAcpr2Zveg734_200x200_3.jpg",@"5019d66eef7ed_200x200_3.jpg",@"10-160540_880.jpg"];
    NSArray *comentBody = @[@"BESD：移动应用程序设计的演变",@"老外说汉语某日，一个对中文略知一二的老外去某工厂参观。半路当中，厂长说：“对不起，我去方便一下。”老外不懂这句中文，问翻译：“方便是什么意思。”翻译说，“就是去厕所。”老外：“哦……”参观结束，厂长热情地对老外说：“下次你方便的时候一起吃饭！”老外一脸不高兴，用生硬的中文说：“我在方便的时候从来不吃饭！”",@"定制版本已经开放预定，限量1000个名额。"];
    NSArray *commentPituresArray = @[@[@"342ac65c1038534374fb7e0b9113b07ecb8065380cd790d8.jpg"],@[@"2010081951611673.jpg",@"2010081951611673.jpg",@"342ac65c1038534374fb7e0b9113b07ecb8065380cd790d8.jpg"],@[@"u=1383080264,94368405&fm=21&gp=0.jpg"]];
    NSArray *dateArray = @[[NSDate dateWithTimeIntervalSince1970:3600*24*365*30],[NSDate dateWithTimeIntervalSince1970:3600*24*365*30],[NSDate dateWithTimeIntervalSince1970:3600*24*365*30]];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSArray *commentsArray = @[@[],@[],@[@"赞赞赞",@"怎么参加啊我也要！",@"me too！！"]];
    NSArray *thumbsArray = @[@[],@[@"海潮为"],@[@"海潮为",@"赵大纯",@"毕业没小学",@"123123",@"AABBCCDD"]];
    
    [_dataArray removeAllObjects];
    for(int i=0;i<3;i++)
    {
        NSDictionary *dictionary = @{@"userName":userNameArray[i],@"userDescribe":userDescribeArray[i],@"iconName":userIconArray[i],@"commentBody":comentBody[i],@"commentPics":commentPituresArray[i],@"date":dateArray[i],@"comments":commentsArray[i],@"thumbs":thumbsArray[i]};
        NetworkModel *model = [[NetworkModel alloc] init];
        [model setValuesForKeysWithDictionary:dictionary];
        [_dataArray addObject:model];
    }
    [_tableView reloadData];
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
