//
//  ZongheShowViewController.h
//  officialDemoNavi
//
//  Created by LiuX on 14-9-1.
//  Copyright (c) 2014年 AutoNavi. All rights reserved.
//

#import "BaseNaviViewController.h"

@interface NavViewController : BaseNaviViewController
- (id)initLocParam:(NSDictionary*)locDic;

@property(strong,nonatomic) NSString *in_Address;
@property(strong,nonatomic) NSString *in_city;
@property(nonatomic) double  in_longitude;
@property(nonatomic) double  in_latitude;

@end
