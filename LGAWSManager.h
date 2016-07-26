//
//  LGAWSManager.h
//
//  Created by 李振刚 on 16/7/25.
//  Copyright © 2016年 displayten. All rights reserved.
//

// source: AWS mobile SDK
// source sample: https://github.com/awslabs/aws-sdk-ios-samples/tree/developer-authenticated-identities-2-4/CognitoYourUserPools-Sample/Objective-C

// SDK source: https://github.com/aws/aws-sdk-ios

// Explain: I had changed some of the SDK, because original had many error and
//          it can't used in my project. It realizes the functions of
//      *** Sign up, Sign in, Sign out, Send email.

// It will have more in the future.
// Let's start!

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AWSCognitoIdentityProvider.h"



#pragma mark ********* Config area start ******************
// start here..

/**
 *  Tag of user pool
 */
#define UserPool @"Your_User_Pool"

/**
 *  Configure your registration information, do this first
 */
#define CognitoIdentityUserPoolId @"Your_Pool_ID"
#define CognitoIdentityUserPoolAppClientId @"Your_AppClientId"
#define CognitoIdentityUserPoolAppClientSecret @"Your_AppClientSecret"

#define IdentityPoolId @"Your_IdentityPoolId"
#define UnauthRoleArn @"Your_UnauthRoleArn"
#define AuthRoleArn @"Your_AuthRoleArn"

/**
 *  Config by yourself, this is attribute type when Create Attribute Type used(method 'createAttributeTypeWithName').
 */
#define AttributeTypePhone @"phone_number"
#define AttributeTypeEmail @"email"
// eg:
#define AttributeTypeFirst @"first"
#define AttributeTypeSecond @"second"
#define AttributeTypeThird @"third"

// end
#pragma mark ********* Config area end ******************

/**
 *  Key of email dictionary, do not change best.
 */
#define EmailFromEmail @"fromEmail" // string
#define EmailToEmail @"toEmail" // string
#define EmailSubject @"subject" // string
#define EmailContentText @"contentText" // string


@interface LGAWSManager : NSObject

/**
 *  initialize, call this first. Param is, who is the delegate
 *
 *  @param appDelegate who is the delegate, follow <AWSCognitoIdentityInteractiveAuthenticationDelegate> and required to achieve two protocol methods.  <AWSCognitoIdentityInteractiveAuthenticationDelegate> should return a viewController, this return controller required to achieve two protocol methods.
 */
+ (void)initializeWithAppDelegate:(id)appDelegate;

/**
 *  Single case , after method 'initializeWithAppDelegate'
 */
+ (instancetype)sharedManager;

/**
 *  get current user
 */
@property (strong, nonatomic, readonly) AWSCognitoIdentityUser *currentUser;

/**
 *  refresh and do something completed
 */
- (AWSCognitoIdentityUser *)refresh:(void(^)(AWSCognitoIdentityUserGetDetailsResponse *response))complete;

/**
 *  Sign in button click, complete calls the protocol method 'didCompletePasswordAuthenticationStepWithError', if error is be in existence, do something shows to user
 *
 *  @param name                                   user name
 *  @param password                               password
 *  @param passwordAuthenticationCompletionSource comes from method 'getPasswordAuthenticationDetails' passwordAuthenticationCompletionSource.
 */
- (void)signInWithUserName:(NSString *)name password:(NSString *)password passwordAuthenticationCompletionSource:(AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails *> *)passwordAuthenticationCompletionSource;

/**
 *  If you don't know how to build the 'AWSCognitoIdentityUserAttributeType', use this method
 *
 *  @param name  your custom name
 *  @param value The name from your own config whitch is required.
 *
 *  @return UserAttributeType, you can take it as a parameter of method 'signUpWithUserName'.
 */
- (AWSCognitoIdentityUserAttributeType *)createAttributeTypeWithName:(NSString *)name value:(NSString *)value;

/**
 *  Sign up and do something when complete.
 *
 *  @param name       user name
 *  @param password   user password
 *  @param attributes Can not contain the parameters upper.
 */
- (void)signUpWithUserName:(NSString *)name password:(NSString *)password attributes:(NSArray<AWSCognitoIdentityUserAttributeType *> *)attributes completed:(void(^)(NSError *error))completed;

/**
 *  Sign out and refresh in block.
 *
 *  @param refreshComplete end of refresh, do something
 */
- (void)signOutAndRefreshCompleted:(void(^)(AWSCognitoIdentityUserGetDetailsResponse *response))refreshCompleted;

/**
 *  Sing out and clear
 */
- (void)signOutAndClearLastKnowUserAndRefreshCompleted:(void(^)(AWSCognitoIdentityUserGetDetailsResponse *response))refreshCompleted;

/**
 *  async send email, charset is UTF-8
 *
 *  @param dict     key is Email... 
                    source address should have been verified
 *  @param complete if error is nil, mean success, do something
 */
- (void)sendEmail:(NSDictionary *)dict complete:(void(^)(NSError *error))complete;
@end
