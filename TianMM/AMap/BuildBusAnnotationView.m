//
//  BuildBusAnnotationView.m
//  TianMM
//
//  Created by cocoa on 15/11/11.
//  Copyright © 2015年 cocoa. All rights reserved.
//

#import "BuildBusAnnotationView.h"

@interface BuildBusAnnotationView ()

@property (nonatomic, strong, readwrite) BusAnnotationView *calloutView;

@end

@implementation BuildBusAnnotationView

- (void)setShowTip
{
    if (self.annotation.subtitle) {

        if (self.calloutView == nil)
        {
            self.calloutView = [[BusAnnotationView alloc] initWithFrame:CGRectMake(0, 0, 200, 30)];
            self.calloutView.center = CGPointMake(CGRectGetWidth(self.bounds) / 2.f + self.calloutOffset.x,
                                                  -CGRectGetHeight(self.calloutView.bounds) / 2.f + self.calloutOffset.y);
        }
        
        NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:self.annotation.subtitle];
        NSRange allRange = [self.annotation.subtitle rangeOfString:self.annotation.subtitle];
        [attrStr addAttribute:NSFontAttributeName
                        value:[UIFont systemFontOfSize:12.0]
                        range:allRange];
        
        
        NSStringDrawingOptions options =  NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading;
        CGRect rect = [attrStr boundingRectWithSize:CGSizeMake(kScreen_Width, CGFLOAT_MAX)
                                            options:options
                                            context:nil];
        
        CGRect m_rect = CGRectMake(rect.origin.x-(rect.size.width)/2+3, rect.origin.y-(rect.size.height+10)-2, rect.size.width+4, rect.size.height+10);
        
        [self.calloutView setFrame:m_rect];
        self.calloutView.titleLabel.text = self.annotation.subtitle;
        [self.calloutView.titleLabel setFrame:CGRectMake(2, 4, rect.size.width, rect.size.height)];
        
        [self addSubview:self.calloutView];
    }
}
@end
