//
//  AppDelegate.m
//  LGAWSManager
//
//  Created by 李振刚 on 16/7/27.
//  Copyright © 2016年 李振刚. All rights reserved.
//

#import "AppDelegate.h"
#import "LGAWSManager/LGAWSManager.h"
#import "ViewController.h"

@interface AppDelegate () <AWSCognitoIdentityInteractiveAuthenticationDelegate>

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    
    [LGAWSManager initializeWithAppDelegate:self];
    
    return YES;
}

// login and .. view controller
- (id<AWSCognitoIdentityPasswordAuthentication>)startPasswordAuthentication {
    
    ViewController *vc = (ViewController *)[UIApplication sharedApplication].keyWindow.rootViewController;
    return vc;
}

// MFA view controller
- (id<AWSCognitoIdentityMultiFactorAuthentication>)startMultiFactorAuthentication {
    
    ViewController *vc = (ViewController *)[UIApplication sharedApplication].keyWindow.rootViewController;
    return vc;
}

@end
