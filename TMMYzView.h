//
//  TMMYzView.h
//  TianMM
//
//  Created by cocoa on 15/10/26.
//  Copyright © 2015年 cocoa. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^ShareBlock)(NSDictionary *shareJSON);


@interface TMMYzView : UIView

@property (nonatomic,assign) BOOL bTabTypeBn;
@property (nonatomic,assign) ShareBlock shareBlock;

- (void)SetShareBlock:(ShareBlock)block;

- (instancetype)initWithUrl:(NSString *)szurl frame:(CGRect)viewframe bTabViewType:(BOOL)bTabViewType title:(NSString *)title;
@end
