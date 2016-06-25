//
//  AppDelegate.m
//  TianMM
//
//  Created by cocoa on 15/9/4.
//  Copyright (c) 2015年 cocoa. All rights reserved.
//
#import "AppDelegate.h"
#import "TMMWebVC.h"
#import <ShareSDK/ShareSDK.h>
#import <ShareSDKConnector/ShareSDKConnector.h>
#import <TencentOpenAPI/TencentOAuth.h>
#import <TencentOpenAPI/QQApiInterface.h>
#import "WXApi.h"
#import <MOBFoundation/MOBFoundation.h>

const static NSString *AMapAPIKey = @"e1f16265e862ed69ac6fbacef159b1e6";

//#define kGtAppId           @"BhuYRjPu4OAGD8D2xDN9I"
//#define kGtAppKey          @"HPfrPF0f1a7aOfrveyYe22"
//#define kGtAppSecret       @"s8XhAJpaMmAPqpE9GQnl2A"

NSString * const DefaultStoredVersionCheckDate = @"App_Version_Check";
NSString * const DefaultSkippedVersion = @"DefaultSkippedVersion";

//static NSString *YZuserAgent = @"tianmimi";

@interface AppDelegate ()<WXApiDelegate>
@property (assign ,nonatomic) TMMWebVC *webVC;
@property (assign, nonatomic) NSURLCache *sharedCache;
@property (nonatomic, assign) NSDate *lastAppVersionCheckOnDate;
@end

@implementation AppDelegate

- (void)CheckAppVersion{
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        _lastAppVersionCheckOnDate = [[NSUserDefaults standardUserDefaults] objectForKey:DefaultStoredVersionCheckDate];
        if (![self lastAppVersionCheckOnDate]) {
            self.lastAppVersionCheckOnDate = [NSDate date];
        }else{
            NSCalendar *currentCalendar = [NSCalendar currentCalendar];
            NSDateComponents *components = [currentCalendar components:NSCalendarUnitDay
                                                              fromDate:[self lastAppVersionCheckOnDate]
                                                                toDate:[NSDate date]
                                                               options:0];
            if ([components day] < 3) {
                return;
            }
        }
        
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        [configuration setRequestCachePolicy:NSURLRequestReloadIgnoringCacheData];
        NSURLSessionDataTask *task = [[NSURLSession sessionWithConfiguration:configuration] dataTaskWithURL:[NSURL URLWithString:APPSTORE_UPDATE_URL]
                                                                                          completionHandler:^(NSData *  data, NSURLResponse *  response, NSError *  error)
                                      {
                                          if ([(NSHTTPURLResponse*)response statusCode] == 200 && error == nil) {
                                              NSDictionary *resultJSON = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
                                              if ([resultJSON count] > 0) {
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                      
                                                      if ([[resultJSON objectForKey:@"resultCount"] integerValue] == 1) {
                                                          NSArray *verArr = [resultJSON objectForKey:@"results"];
                                                          NSDictionary *verDic = [verArr objectAtIndex:0];
                                                          NSString *currentAppStoreVersion = [verDic objectForKey:@"version"];
                                                          
                                                          if (![[[NSUserDefaults standardUserDefaults] objectForKey:DefaultSkippedVersion] isEqualToString:currentAppStoreVersion]) {
                                                              NSArray *oldVersionComponents = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"] componentsSeparatedByString:@"."];

                                                              NSArray *newVersionComponents = [currentAppStoreVersion componentsSeparatedByString: @"."];
                                                              
                                                              if ([oldVersionComponents count] == 3 && [newVersionComponents count] == 3) {
                                                                  if ([newVersionComponents[0] integerValue] > [oldVersionComponents[0] integerValue] ||
                                                                      ([newVersionComponents[0] integerValue] == [oldVersionComponents[0] integerValue] &&
                                                                       [newVersionComponents[1] integerValue] > [oldVersionComponents[1] integerValue]) ||
                                                                      ([newVersionComponents[0] integerValue] == [oldVersionComponents[0] integerValue] &&
                                                                       [newVersionComponents[1] integerValue] == [oldVersionComponents[1] integerValue] &&
                                                                       [newVersionComponents[2] integerValue] > [oldVersionComponents[2] integerValue]))
                                                                  {
                                                                      self.lastAppVersionCheckOnDate = [NSDate date];
                                                                      [[NSUserDefaults standardUserDefaults] setObject:[self lastAppVersionCheckOnDate] forKey:DefaultStoredVersionCheckDate];
                                                                      [[NSUserDefaults standardUserDefaults] synchronize];
                                                                      
                                                                      
                                                                      UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"田觅觅" message:[NSString stringWithFormat:@"检测到新的 %@ 版本，是否更新？",currentAppStoreVersion] delegate:nil cancelButtonTitle:@"跳过此版本"otherButtonTitles:@"去更新", nil];
                                                                      [[alertView rac_buttonClickedSignal] subscribeNext:^(NSNumber *indexNumber) {
                                                                          if ([indexNumber intValue] == 0) {
                                                                              [[NSUserDefaults standardUserDefaults] setObject:currentAppStoreVersion forKey:DefaultSkippedVersion];
                                                                              [[NSUserDefaults standardUserDefaults] synchronize];
                                                                          } else {
                                                                              [[UIApplication sharedApplication] openURL:[NSURL URLWithString:APPSTORE_URL]];
                                                                          }
                                                                      }];
                                                                      [alertView show];
                                                                      [alertView release];
                                                                  }
                                                              }
                                                          }
                                                      }
                                                  });
                                              }
                                          }
                                      }];
        [task resume];
    });
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]]; 
    
    
    [AMapNaviServices sharedServices].apiKey = (NSString *)AMapAPIKey;
    [MAMapServices sharedServices].apiKey = (NSString *)AMapAPIKey;
    [self configIFlySpeech];
    [AMapSearchServices sharedServices].apiKey = (NSString *)AMapAPIKey;
    [AMapLocationServices sharedServices].apiKey = (NSString *)AMapAPIKey;
    [MobClick startWithAppkey:@"55a5cc4f266c1be10a000959" reportPolicy:BATCH  channelId:nil];

    _sharedCache = [[NSURLCache alloc] initWithMemoryCapacity: 4*1024*1024 diskCapacity:32*1024*1024 diskPath:@"nsurlcache"];
    [NSURLCache setSharedURLCache:_sharedCache];
    
    self.webVC = [[TMMWebVC alloc]init];
    self.window.rootViewController = self.webVC;
    [self.window makeKeyAndVisible];
    
    [ShareSDK registerApp:@"c3539f8e63c0"
          activePlatforms:@[
                            @(SSDKPlatformTypeSinaWeibo),
                            @(SSDKPlatformTypeMail),
                            @(SSDKPlatformTypeSMS),
                            @(SSDKPlatformTypeCopy),
                            @(SSDKPlatformSubTypeWechatSession),
                            @(SSDKPlatformSubTypeWechatTimeline),
                            @(SSDKPlatformTypeQQ)
                            ]
                 onImport:^(SSDKPlatformType platformType) {
                     
                     switch (platformType)
                     {
                         case SSDKPlatformTypeWechat:
                             [ShareSDKConnector connectWeChat:[WXApi class] delegate:self];
                             break;
                         case SSDKPlatformTypeQQ:
                             [ShareSDKConnector connectQQ:[QQApiInterface class]
                                        tencentOAuthClass:[TencentOAuth class]];
                             break;
                         default:
                             break;
                     }
                 }
          onConfiguration:^(SSDKPlatformType platformType, NSMutableDictionary *appInfo) {
              switch (platformType)
              {
                  case SSDKPlatformTypeSinaWeibo:
                      [appInfo SSDKSetupSinaWeiboByAppKey:@"2913799679"
                                                appSecret:@"fe1c8e30d8b4c63e06a2b0360b1cc068"
                                              redirectUri:@"http://www.365tmm.com"
                                                 authType:SSDKAuthTypeBoth];
                      break;
                  case SSDKPlatformTypeWechat:
                      [appInfo SSDKSetupWeChatByAppId:@"wxeeabb8e9c700ca7f"
                                            appSecret:@"d4624c36b6795d1d99dcf0547af5443d"];
                      break;
                  case SSDKPlatformTypeQQ:
                      [appInfo SSDKSetupQQByAppId:@"1104880734"
                                           appKey:@"ATAq4o2l6RbVrf7w"
                                         authType:SSDKAuthTypeBoth];
                      break;
                  default:
                      break;
              }
          }];
    
    [WXApi registerApp:@"wxeeabb8e9c700ca7f" withDescription:@"WxPay"];
    
    [self CheckAppVersion];
    return YES;
}

//微信支付回调
-(void)onResp:(BaseResp *)resp
{
    if([resp isKindOfClass:[PayResp class]]){
        switch (resp.errCode) {
            case WXSuccess:
                [[NSNotificationCenter defaultCenter] postNotificationName:WEIXIN_PAY_RESULT object:[NSNumber numberWithBool:YES] userInfo:nil];
                break;
            default:
                [[NSNotificationCenter defaultCenter] postNotificationName:WEIXIN_PAY_RESULT object:[NSNumber numberWithBool:NO] userInfo:nil];
                break;
        }
    }
}

- (void)configIFlySpeech
{
    [IFlySpeechUtility createUtility:[NSString stringWithFormat:@"appid=%@,timeout=%@",@"563c5170",@"20000"]];
    [IFlySetting setLogFile:LVL_NONE];
    [IFlySetting showLogcat:NO];
    // 设置语音合成的参数
    [[IFlySpeechSynthesizer sharedInstance] setParameter:@"50" forKey:[IFlySpeechConstant SPEED]];//合成的语速,取值范围 0~100
    [[IFlySpeechSynthesizer sharedInstance] setParameter:@"50" forKey:[IFlySpeechConstant VOLUME]];//合成的音量;取值范围 0~100
    // 发音人,默认为”xiaoyan”;可以设置的参数列表可参考个 性化发音人列表;
    [[IFlySpeechSynthesizer sharedInstance] setParameter:@"xiaoyan" forKey:[IFlySpeechConstant VOICE_NAME]];
    // 音频采样率,目前支持的采样率有 16000 和 8000;
    [[IFlySpeechSynthesizer sharedInstance] setParameter:@"8000" forKey:[IFlySpeechConstant SAMPLE_RATE]];
    // 当你再不需要保存音频时，请在必要的地方加上这行。
    [[IFlySpeechSynthesizer sharedInstance] setParameter:nil forKey:[IFlySpeechConstant TTS_AUDIO_PATH]];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}


- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    return  [WXApi handleOpenURL:url delegate:self];
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary*)options
{
    if ([url.host isEqualToString:@"pay"]) { //微信支付
        return [WXApi handleOpenURL:url delegate:self];
    }
    return TRUE;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    //跳转支付宝钱包进行支付，处理支付结果
    if ([url.host isEqualToString:@"safepay"]) {
        [[AlipaySDK defaultService] processOrderWithPaymentResult:url
                                                  standbyCallback:^(NSDictionary *resultDic) {
                                                      DDLogDebug(@"result = %@",resultDic);
                                                  }];
    }
    return true;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void) dealloc{
    [super dealloc];
    [self.webVC release];
    
    [_sharedCache release];
}

@end
