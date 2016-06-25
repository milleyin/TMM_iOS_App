//
//  PolyLineModel.m
//  TianMM
//
//  Created by cocoa on 15/11/10.
//  Copyright © 2015年 cocoa. All rights reserved.
//

#import "PolyLineModel.h"

@implementation PolyLineModel

-(id)initLine:(NSString *)line LineType:(int )n_LineType Distance:(NSInteger)distance
{
    self = [super init];
    if (self) {
        self.polyline  = [[NSString alloc]initWithString:line];
        self.lineType = n_LineType;
        self.distance = distance;
    }
    return self;
}
@end
