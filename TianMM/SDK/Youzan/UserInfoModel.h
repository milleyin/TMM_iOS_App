//
//  UserInfoModel.h
//  YouzaniOSDemo
//
//  Created by youzan on 15/11/6.
//  Copyright (c) 2015年 youzan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UserInfoModel : NSObject

@property (copy, nonatomic  ) NSString *userId;
@property (copy, nonatomic  ) NSString *gender;
@property (copy, nonatomic  ) NSString *bid;
@property (copy, nonatomic  ) NSString *name;
@property (copy, nonatomic  ) NSString *telephone;
@property (copy, nonatomic  ) NSString *avatar;
@property (copy, nonatomic  ) NSString *ipAddress;
@property (assign, nonatomic) BOOL     isLogined;

+ (instancetype)sharedManage;

@end
