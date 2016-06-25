//
//  TMMWebVC.m
//  TianMM
//
//  Created by cocoa on 15/9/4.
//  Copyright (c) 2015年 cocoa. All rights reserved.
//
#import "TMMWebVC.h"
#import "TMMYzView.h"
#import "NavViewController.h"
#import <ShareSDK/ShareSDK.h>
#import <CommonCrypto/CommonDigest.h>
#import <ShareSDKExtension/SSEShareHelper.h>
#import <ShareSDKUI/ShareSDK+SSUI.h>
#import <ShareSDKUI/SSUIShareActionSheetStyle.h>
#import <ShareSDKUI/SSUIShareActionSheetCustomItem.h>
#import <ShareSDK/ShareSDK+Base.h>
#import <SDWebImage/UIImageView+WebCache.h>
#import "M13ProgressViewSegmentedBar.h"

@interface TMMWebVC ()< UIWebViewDelegate,AMapLocationManagerDelegate>

@property (assign,nonatomic) UIWebView *webView;
@property (assign,nonatomic) WebViewJavascriptBridge* bridge;
@property (assign,nonatomic) TMMYzView *youzanView;
@property (assign,nonatomic) TMMYzView *youzanView2;
@property (nonatomic,strong) AMapLocationManager *locationManager;

@end

@implementation TMMWebVC

-(id)init{
    self = [super init];
    if (self) {
        self.webView = nil;
        
        [[[[NSNotificationCenter defaultCenter] rac_addObserverForName:UIApplicationDidBecomeActiveNotification object:nil]
            takeUntil:[self rac_willDeallocSignal]]
            subscribeNext:^(id x) {
                //
            }];
        
        [[[[NSNotificationCenter defaultCenter] rac_addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil]
          takeUntil:[self rac_willDeallocSignal]]
          subscribeNext:^(id x) {
//             [self.webView stopLoading];
         }];
    }
    return self;
}

- (void)WxPayResult:(NSNotification*)notification{
    BOOL status = [[notification object] boolValue];
    if (status) {
        [_bridge callHandler:@"PayCallback" data:@"1"];
    }else{
        [_bridge callHandler:@"PayCallback" data:@"0"];
    }
    DDLogDebug(@"PAY %d",status);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSHTTPCookieStorage *cook = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    [cook setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    
    [self.view setBackgroundColor:[UIColor whiteColor]];
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(WxPayResult:) name:WEIXIN_PAY_RESULT object:nil];

    
    M13ProgressViewSegmentedBar *progressBar = [[M13ProgressViewSegmentedBar alloc]initWithFrame:CGRectMake(0, 0,100, 10)];
    [self.view addSubview:progressBar];
    [progressBar setIndeterminate:YES];
    progressBar.progressDirection = M13ProgressViewSegmentedBarProgressDirectionLeftToRight;
    [progressBar setSegmentShape:M13ProgressViewSegmentedBarSegmentShapeRoundedRect];
    [progressBar release];
    
    UILabel *locLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 0,60, 30)];
    [self.view addSubview:locLabel];
    [locLabel setText:@"定位中..."];
    [locLabel setTextColor:[UIColor colorWithRed:40/255.0f green:166/255.0f blue:23/255.0f alpha:1]];
    [locLabel setFont:[UIFont systemFontOfSize:14]];
    [locLabel release];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [progressBar removeFromSuperview];
            [locLabel removeFromSuperview];
        });
    });
    
    self.locationManager = [[AMapLocationManager alloc] init];
    [self.locationManager setDesiredAccuracy:kCLLocationAccuracyHundredMeters];
    [self.locationManager requestLocationWithReGeocode:YES completionBlock:^(CLLocation *location, AMapLocationReGeocode *regeocode, NSError *error)
     {
         dispatch_semaphore_signal(semaphore);
         DDLogDebug(@"location:%f,%f", location.coordinate.latitude,location.coordinate.longitude);
         if (error)
         {
             DDLogDebug(@"locError:{%ld - %@};", (long)error.code, error.localizedDescription);
             if (error.code == AMapLocationErrorLocateFailed)
             {
                 [self initWebView:CLLocationCoordinate2DMake(0, 0) city:@""];
                 if([CLLocationManager locationServicesEnabled] == YES && [CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied) {
                     UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"" message:@"您禁止了田觅觅获取当前位置" delegate:nil cancelButtonTitle:@"取消" otherButtonTitles:@"设置", nil];
                     [[alertView rac_buttonClickedSignal] subscribeNext:^(NSNumber *indexNumber) {
                         if ([indexNumber intValue] == 1) {
                             if([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]]) {
                                 [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                             }
                        }
                     }];
                     [alertView show];
                     [alertView release];
                 }
             }else{
                 [self initWebView:location.coordinate city:@""];
             }
         }else{
             if (regeocode)
             {
                 DDLogDebug(@"reGeocode:%@--%@", regeocode,regeocode.city);
                 [self initWebView:location.coordinate city:regeocode.city];
             }else{
                 [self initWebView:location.coordinate city:@""];
             }
         }
    }];
    
    [progressBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(self.view.mas_centerX);
        make.centerY.mas_equalTo(self.view.mas_centerY).offset(-20);
        make.size.mas_equalTo(CGSizeMake(100, 10));

    }];
    [locLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(progressBar.mas_centerX);
        make.top.mas_equalTo(progressBar.mas_bottom).offset(5);
        make.size.mas_equalTo(CGSizeMake(60, 30));
        
    }];
}

- (void)initWebView:(CLLocationCoordinate2D)coord city:(NSString *)city
{
    self.webView = [[UIWebView alloc]initWithFrame:self.view.frame];
    self.webView.scrollView.bounces = NO;
    self.webView.delegate = self;
    [self.view addSubview:self.webView];
    
    [self.webView.scrollView setShowsHorizontalScrollIndicator:NO];
    [self.webView release];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:APP_URL] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:0] ;
   [self.webView loadRequest:request];

    _bridge = [WebViewJavascriptBridge bridgeForWebView:self.webView webViewDelegate:self handler:^(id data, WVJBResponseCallback responseCallback) {
        DDLogDebug(@"%@ OK", data);
//        responseCallback(data);
    }];
    
    [_bridge callHandler:@"JSCallback" data:@{@"longitude":[NSString stringWithFormat:@"%f",coord.longitude],@"latitude":[NSString stringWithFormat:@"%f",coord.latitude],@"city":city}];
    DDLogDebug(@"%@",@{@"longitude":[NSString stringWithFormat:@"%f",coord.longitude],@"latitude":[NSString stringWithFormat:@"%f",coord.latitude],@"city":city});
    
    [_bridge registerHandler:@"ObjcCallback" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSDictionary *dic = [NSDictionary dictionaryWithDictionary:data];
        NSArray *keyArr = [dic allKeys];

        if ([dic count] == 1)
        {
            NSString *szJSValue = [keyArr objectAtIndex:0];
            if ([szJSValue isEqualToString:@"phone"]) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"tel://%@",[dic valueForKey:@"phone"]]]];
            }
            else if([szJSValue isEqualToString:@"PayCode"])
            {
                [[AlipaySDK defaultService] payOrder:[dic valueForKey:@"PayCode"] fromScheme:@"tmmAlipay" callback:^(NSDictionary *resultDic) {
                    DDLogDebug(@"reslut = %@,%@",resultDic,[resultDic valueForKey:@"resultStatus"]);
                    if ([[resultDic valueForKey:@"resultStatus"] isEqualToString:@"9000"]) {
                        NSString *decodedString  = ( NSString *)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL, (__bridge CFStringRef)[resultDic valueForKey:@"result"], CFSTR(""),
                                                                                                                                         CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
                        NSString *parten = @"(success=)(\\S){1}(true\")";
                        NSError* error = NULL;
                        NSRegularExpression *reg = [NSRegularExpression regularExpressionWithPattern:parten options:0 error:&error];
                        NSArray* match = [reg matchesInString:decodedString options:NSMatchingReportCompletion range:NSMakeRange(0, [decodedString length])];
                        if (match.count != 0)
                        {
                            [_bridge callHandler:@"PayCallback" data:@"1"];
                            DDLogDebug(@"支付成功");
                        }else{
                            [_bridge callHandler:@"PayCallback" data:@"0"];
                        }
                    }
                }];
            }
            else if([szJSValue isEqualToString:@"WxPay"])
            {
                DDLogDebug(@"%@",[dic valueForKey:@"WxPay"]);
                NSDictionary *dict = [[NSDictionary alloc] initWithDictionary:[dic valueForKey:@"WxPay"]];
                if(dict != nil){
                    NSMutableString *stamp  = [dict objectForKey:@"timestamp"];
                    
                    PayReq* req             = [[PayReq alloc] init];
                    req.partnerId           = [NSString stringWithString:[dict objectForKey:@"partnerid"]];
                    req.prepayId            = [NSString stringWithString:[dict objectForKey:@"prepayid"]];
                    req.nonceStr            = [NSString stringWithString:[dict objectForKey:@"noncestr"]];
                    req.timeStamp           = stamp.intValue;
                    req.package             = [NSString stringWithString:[dict objectForKey:@"package"]];
                    req.sign                = [NSString stringWithString:[dict objectForKey:@"sign"]];
                    [WXApi sendReq:req];
                }
            }
            else if([szJSValue isEqualToString:@"Tips"])
            {
                MBProgressHUD *HUD = [[MBProgressHUD alloc] initWithView:self.view];
                [self.view addSubview:HUD];
                HUD.labelText = [dic valueForKey:@"Tips"];
                HUD.mode = MBProgressHUDModeText;
                
                [HUD showAnimated:YES whileExecutingBlock:^{
                    [NSThread sleepForTimeInterval:1];
                } completionBlock:^{
                    [HUD removeFromSuperview];
                    [HUD release];
                }];
            }
            else if ([szJSValue isEqualToString:@"youzan_1"])
            {
                if (_youzanView) {
                    [_youzanView setHidden:NO];

                }else{
                    _youzanView = [[TMMYzView alloc]initWithUrl:[dic valueForKey:@"youzan_1"] frame:CGRectMake(0, 20, kScreen_Width, kScreen_Height-20-50) bTabViewType:YES title:@""];
                    [_youzanView SetShareBlock:^(NSDictionary *shareDic) {
                        NSString *title = [shareDic valueForKey:@"name"];
                        NSString *description = [shareDic valueForKey:@"info"];
                        NSString *thumb_url = [shareDic valueForKey:@"image"];
                        NSString *webpageUrl = [shareDic valueForKey:@"link"];
                        
                        [self showShareActionSheet:title desc:description thumbUrl:thumb_url webpageUrl:webpageUrl];
                    }];
                    
                    [self.view addSubview:_youzanView];
                    [_youzanView release];
                }
            }
            else if ([szJSValue isEqualToString:@"youzan_3"])
            {
                NSDictionary * detailDic = [dic valueForKey:@"youzan_3"];
                _youzanView2 = [[TMMYzView alloc]initWithUrl: [detailDic valueForKey:@"webpageUrl"] frame:CGRectMake(0, 0, kScreen_Width, kScreen_Height-20) bTabViewType:NO title:[detailDic valueForKey:@"title"]];
                [_youzanView2 SetShareBlock:^(NSDictionary *shareDic) {
                    NSString *title = [shareDic valueForKey:@"name"];
                    NSString *description = [shareDic valueForKey:@"info"];
                    NSString *thumb_url = [shareDic valueForKey:@"image"];
                    NSString *webpageUrl = [shareDic valueForKey:@"link"];
                    
                    [self showShareActionSheet:title desc:description thumbUrl:thumb_url webpageUrl:webpageUrl];
                }];
                
                [self.view addSubview:_youzanView2];
                [_youzanView2 release];
                DDLogInfo(@"%@",[dic valueForKey:@"youzan_3"]);
            }
            else if ([szJSValue isEqualToString:@"youzan_exit"])
            {
                if (_youzanView) {
                    [_youzanView setHidden:YES];
                }
            }
            else if([szJSValue isEqualToString:@"appLoginName"])
            {
                [[NSUserDefaults standardUserDefaults] setObject:[dic valueForKey:@"appLoginName"] forKey:APP_LOGIN_NAME];
                [NSUserDefaults standardUserDefaults];
            }
            else if ([szJSValue isEqualToString:@"wx_share"]){
                NSDictionary *shareDic =[dic valueForKey:@"wx_share"];
                NSString *title = [shareDic valueForKey:@"title"];
                NSString *description = [shareDic valueForKey:@"description"];
                NSString *thumb_url = [shareDic valueForKey:@"thumb_url"];
                NSString *webpageUrl = [shareDic valueForKey:@"webpageUrl"];
                
                [self showShareActionSheet:title desc:description thumbUrl:thumb_url webpageUrl:webpageUrl];
            }
            else if ([szJSValue isEqualToString:@"navi_loc"])
            {
                NSDictionary *LocDic =[dic valueForKey:@"navi_loc"];
                BaseNaviViewController *navController = [[NSClassFromString(@"NavViewController") alloc] initLocParam:LocDic];

                [self presentViewController:navController animated:YES completion:nil];
            }
            else if ([szJSValue isEqualToString:@"getLoc"])
            {
                if([CLLocationManager locationServicesEnabled] == NO){
                    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"" message:@"您禁止了系统定位服务" delegate:nil cancelButtonTitle:@"取消" otherButtonTitles:@"设置", nil];
                    [[alertView rac_buttonClickedSignal] subscribeNext:^(NSNumber *indexNumber) {
                        if ([indexNumber intValue] == 1) {
                            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"prefs:root=LOCATION_SERVICES"]];
                        }
                    }];
                    [alertView show];
                    [alertView release];
                }else if( [CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied) {
                    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"" message:@"您禁止了田觅觅获取当前位置" delegate:nil cancelButtonTitle:@"取消" otherButtonTitles:@"设置", nil];
                    [[alertView rac_buttonClickedSignal] subscribeNext:^(NSNumber *indexNumber) {
                        if ([indexNumber intValue] == 1) {
                            if([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]]) {
                                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                            }
                        }
                    }];
                    [alertView show];
                    [alertView release];
                }
                [self.locationManager requestLocationWithReGeocode:YES completionBlock:^(CLLocation *location, AMapLocationReGeocode *regeocode, NSError *error)
                 {
                     DDLogDebug(@"location:%f,%f", location.coordinate.latitude,location.coordinate.longitude);
                     if (error)
                     {
                         DDLogDebug(@"locError:{%ld - %@};", (long)error.code, error.localizedDescription);
                         if (error.code == AMapLocationErrorLocateFailed)
                         {
                             responseCallback(@"false");
                         }
                     }else{
                         if (regeocode)
                         {
                             DDLogDebug(@"reGeocode:%@--%@", regeocode,regeocode.city);
                             responseCallback(@{@"longitude":[NSString stringWithFormat:@"%f",location.coordinate.longitude],@"latitude":[NSString stringWithFormat:@"%f",location.coordinate.latitude],@"city":regeocode.city});
                         }else{
                             responseCallback(@{@"longitude":[NSString stringWithFormat:@"%f",location.coordinate.longitude],@"latitude":[NSString stringWithFormat:@"%f",location.coordinate.latitude],@"city":@""});
                         }
                     }
                 }];
            }
        }
    }];
}

- (void)webViewHideBackgroundAndScrollBar:(UIWebView*)theView {
    theView.opaque = NO;
    theView.backgroundColor = [UIColor clearColor];
    
    for(UIView *view in theView.subviews) {
        if ([view isKindOfClass:[UIImageView class]]) {
            // to transparent
            [view removeFromSuperview];
        }
        
        if ([view isKindOfClass:[UIScrollView class]]) {
            UIScrollView *sView = (UIScrollView *)view;
            //to hide Scroller bar
            sView.showsVerticalScrollIndicator = NO;
            sView.showsHorizontalScrollIndicator = NO;
            
            for (UIView* shadowView in [sView subviews]){
                //to remove shadow
                if ([shadowView isKindOfClass:[UIImageView class]]) {
                    [shadowView setHidden:TRUE];
                }
            }
        }
    }
}

#pragma mark - UIWebViewDelegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [MBProgressHUD showHUDAddedTo:self.webView animated:YES];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [MBProgressHUD hideHUDForView:self.webView animated:YES];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [MBProgressHUD hideHUDForView:self.webView animated:YES];
}

- (void)showShareActionSheet:(NSString*)title desc:(NSString*)desc thumbUrl:(NSString *)thumb_url webpageUrl:(NSString*)webpageUrl
{
    SDWebImageManager *manager = [SDWebImageManager sharedManager];
    [manager downloadImageWithURL:[NSURL URLWithString:thumb_url]
                          options:0
                         progress:^(NSInteger receivedSize, NSInteger expectedSize) {
                         }
                        completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
                            if (image) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    NSMutableDictionary *shareParams = [NSMutableDictionary dictionary];
                                    NSArray* imageArray = @[image];
                                    [shareParams SSDKSetupShareParamsByText:desc
                                                                     images:imageArray
                                                                        url:[NSURL URLWithString:webpageUrl]
                                                                      title:title
                                                                       type:SSDKContentTypeAuto];
                                    [shareParams SSDKSetupWeChatParamsByText:title title:desc url:[NSURL URLWithString:webpageUrl] thumbImage:image image:nil musicFileURL:nil extInfo:nil fileData:nil emoticonData:nil type:SSDKContentTypeAuto forPlatformSubType:SSDKPlatformSubTypeWechatTimeline];
                                    
                                    [shareParams SSDKSetupSinaWeiboShareParamsByText:[NSString stringWithFormat:@"%@ %@",desc,webpageUrl] title:title image:image url:[NSURL URLWithString:webpageUrl] latitude:0 longitude:0 objectID:nil type:SSDKContentTypeAuto];
                                    
                                    [shareParams SSDKSetupSMSParamsByText:[NSString stringWithFormat:@"%@ %@",desc,webpageUrl] title:title images:imageArray attachments:nil recipients:nil type:SSDKContentTypeAuto];
                                    
                                    [shareParams SSDKSetupMailParamsByText:[NSString stringWithFormat:@"%@ %@",desc,webpageUrl] title:title images:imageArray attachments:nil recipients:nil ccRecipients:nil bccRecipients:nil type:SSDKContentTypeAuto];
                                    
                                    [shareParams SSDKSetupCopyParamsByText:[NSString stringWithFormat:@"%@ %@",desc,webpageUrl] images:imageArray url:[NSURL URLWithString:webpageUrl] type:SSDKContentTypeAuto];
                                    
                                    SSUIShareActionSheetController *sheet = [ShareSDK showShareActionSheet:self.webView
                                                                                                     items:@[@(SSDKPlatformTypeWechat),
                                                                                                             @(SSDKPlatformTypeQQ),
                                                                                                             @(SSDKPlatformTypeSinaWeibo),
                                                                                                             @(SSDKPlatformTypeMail),
                                                                                                             @(SSDKPlatformTypeSMS),
                                                                                                             @(SSDKPlatformTypeCopy)]
                                                                                               shareParams:shareParams
                                                                                       onShareStateChanged:^(SSDKResponseState state, SSDKPlatformType platformType, NSDictionary *userData, SSDKContentEntity *contentEntity, NSError *error, BOOL end) {
                                                                                           switch (state) {
                                                                                                   
                                                                                               case SSDKResponseStateBegin:
                                                                                               {
                                                                                                   break;
                                                                                               }
                                                                                               case SSDKResponseStateSuccess:
                                                                                               {
                                                                                                   [JDStatusBarNotification showWithStatus:@"分享成功" dismissAfter:3 styleName:@"JDStatusBarStyleSuccess"];
                                                                                                   break;
                                                                                               }
                                                                                               case SSDKResponseStateFail:
                                                                                               {
                                                                                                   if (platformType == SSDKPlatformTypeSMS && [error code] == 201)
                                                                                                   {
                                                                                                       [JDStatusBarNotification showWithStatus:@"分享失败" dismissAfter:3 styleName:@"JDStatusBarStyleError"];
                                                                                                       break;
                                                                                                   }
                                                                                                   else if(platformType == SSDKPlatformTypeMail && [error code] == 201)
                                                                                                   {
                                                                                                       [JDStatusBarNotification showWithStatus:@"分享失败" dismissAfter:3 styleName:@"JDStatusBarStyleError"];
                                                                                                       break;
                                                                                                   }
                                                                                                   else
                                                                                                   {
                                                                                                       DDLogDebug(@"%@",[error description]);
                                                                                                       [JDStatusBarNotification showWithStatus:@"分享失败" dismissAfter:3 styleName:@"JDStatusBarStyleError"];
                                                                                                       break;
                                                                                                   }
                                                                                                   break;
                                                                                               }
                                                                                               case SSDKResponseStateCancel:
                                                                                               {
                                                                                                   break;
                                                                                               }
                                                                                               default:
                                                                                                   break;
                                                                                           }
                                                                                       }];
                                    
                                    [sheet.directSharePlatforms addObject:@(SSDKPlatformTypeSinaWeibo)];

                                });
                            }
                        }];

}

#pragma mark --签名算法，获取签名
- (NSString *)getSignWithPartnerId:(NSString *)partnerId
                      withPrepayId:(NSString *)prepayId
                      withNonceStr:(NSString *)nonceStr
                     withTimeStamp:(UInt32)timeStamp
                       withPackage:(NSString *)package
{
    NSString *stringA = [NSString stringWithFormat:@"appid=%@&noncestr=%@&package=%@&partnerid=%@&prepayid=%@&timestamp=%d",@"", nonceStr, package, partnerId, prepayId, timeStamp];
    //拼接API秘钥
    NSString *stringSignTemp = [NSString stringWithFormat:@"%@&key=%@", stringA,@""];
    NSString *sign = [self md5:stringSignTemp];
    sign = [sign uppercaseString];
    return sign;
}
#pragma mark --MD5签名算法

- (NSString *)md5:(NSString *) str
{
    const char *cStr = [str UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cStr, strlen(cStr), result);
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

-(void) dealloc{
    [super dealloc];
    if (self.webView) {
        [self.webView release];
    }
}

@end
