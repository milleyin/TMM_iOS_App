//
//  PolyLineModel.h
//  TianMM
//
//  Created by cocoa on 15/11/10.
//  Copyright © 2015年 cocoa. All rights reserved.
//

#import <Foundation/Foundation.h>

#define LineStyleBus        2000
#define LineStyleMetro      2001  // 地铁
#define LineStyleWalk       2002  // 步行

@interface PolyLineModel : NSObject
@property (nonatomic, strong)  NSString *polyline;
@property (nonatomic)  int lineType;
@property (nonatomic)  NSInteger distance;

-(id)initLine:(NSString *)line LineType:(int )n_LineType Distance:(NSInteger)distance;

@end
