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
//      *** Sign up, Sign in, Send email.

// It will have more in the future.
// Let's start!

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AWSCognitoIdentityProvider.h"
#import "AWSS3.h"


#pragma mark ********* Config area start *********
// start here..

/**
 *  Tag of user pool
 */
#define UserPool @"dten_user"

/**
 *  Configure your registration information, do this first
 */
#define CognitoIdentityUserPoolId @"us-east-1_bDfyuBfz3"
#define CognitoIdentityUserPoolAppClientId @"7na2u2oenq7usjc5qemli8h4os"
#define CognitoIdentityUserPoolAppClientSecret @"qet0fdtc5sdf990bqmlh34olcfuoih6ivft8fa49r63tr7o7uc5"

#define IdentityPoolId @"us-east-1:cdc0bac2-5588-4982-b5d4-296d8cc3ac80"
#define UnauthRoleArn @"arn:aws:iam::919886360521:role/Cognito_dten_appUnauth_Role"
#define AuthRoleArn @"arn:aws:iam::919886360521:role/Cognito_dten_appAuth_Role"

/**
 *  Config by yourself, this is attribute type when Create Attribute Type used(method 'createAttributeTypeWithName').
 */
#define AttributeTypePhone @"phone_number"
#define AttributeTypeEmail @"email"
#define AttributeTypeDTenID @"custom:dten_mail"
#define AttributeTypeFirstName @"custom:first_name"
#define AttributeTypeLastName @"custom:last_name"
#define AttributeTypeSync @"custom:sync_data"

/**
 *  This config is for S3, config this first and use 'upLoadImage:' method
 */
#define BucketName @"profile.dten.com"

// end
#pragma mark ********* Config area end *********

#define RegisterSESKey @"USWest2SES"
/**
 *  Key of email dictionary, do not change best.
 */
#define EmailFromEmail @"fromEmail" // string
#define EmailToEmail @"toEmail" // array
#define EmailSubject @"subject" // string
#define EmailContentText @"contentText" // string

@protocol LGAWSManagerDelegate <NSObject>

- (void)awsManagerDoRefresh:(AWSCognitoIdentityUserGetDetailsResponse *_Nullable)response;

@end

@interface LGAWSManager : NSObject

/**
 *  initialize, call this first. Param is, who is the delegate
 *
 *  @param appDelegate who is the delegate, follow <AWSCognitoIdentityInteractiveAuthenticationDelegate> and required to achieve two protocol methods.  <AWSCognitoIdentityInteractiveAuthenticationDelegate> should return a viewController, this return controller required to achieve two protocol methods.
 */
+ (void)initializeWithAppDelegate:(id _Nonnull)appDelegate;

/**
 *  Single case , after method 'initializeWithAppDelegate'
 */
+ (instancetype _Nonnull)sharedManager;

/**
 *  get current user
 */
@property (strong, nonatomic, readonly) AWSCognitoIdentityUser *_Nonnull currentUser;

/**
 *  Refresh
 */
- (AWSCognitoIdentityUser *_Nullable)refresh;

/**
 *  Delegate
 */
@property (weak, nonatomic) id <LGAWSManagerDelegate>_Nullable delegate;

/**
 *  Sign in button click, complete calls the protocol method 'didCompletePasswordAuthenticationStepWithError', if error is be in existence, do something shows to user
 *
 *  @param name                                   user name
 *  @param password                               password
 *  @param passwordAuthenticationCompletionSource comes from method 'getPasswordAuthenticationDetails' passwordAuthenticationCompletionSource.
 */
- (void)signInWithUserName:(NSString *_Nonnull)name password:(NSString *_Nonnull)password passwordAuthenticationCompletionSource:(AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails *> * _Nonnull)passwordAuthenticationCompletionSource;

/**
 *  If you don't know how to build the 'AWSCognitoIdentityUserAttributeType', use this method
 *
 *  @param name  your custom name
 *  @param value The name from your own config whitch is required.
 *
 *  @return UserAttributeType, you can take it as a parameter of method 'signUpWithUserName'.
 */
- (AWSCognitoIdentityUserAttributeType * _Nullable)createAttributeTypeWithName:(NSString * _Nonnull)name value:(NSString *_Nonnull)value;

/**
 *  Sign up and do something when complete.
 *
 *  @param name       user name
 *  @param password   user password
 *  @param attributes Can not contain the parameters upper.
 */
- (void)signUpWithUserName:(NSString *_Nonnull)name password:(NSString *_Nonnull)password attributes:(NSArray<AWSCognitoIdentityUserAttributeType *> *_Nullable)attributes completed:(void(^_Nullable)(NSError *_Nullable error))completed;

/**
 *  After sign up, user will recive a verified code, use this
 */
- (void)confirmSignUpWithVerifiedCode:(NSString *_Nullable)code complete:(void(^_Nullable)(NSError *_Nullable error))complete;

/**
 *  Sign out and refresh in block.
 *
 *  @param refreshComplete end of refresh, do something
 */
- (void)signOutAndRefresh;

/**
 *  Sing out and clear
 */
- (void)signOutAndClearLastKnowUserAndRefresh;

/**
 *  Async send email, charset is UTF-8
 *
 *  @param dict     key is Email... 
                    source address should have been verified
 *  @param complete if error is nil, mean success, do something
 */
- (void)sendEmail:(NSDictionary<NSString *, NSArray<NSString *> *> *_Nullable)dict complete:(void(^_Nullable)(NSError *_Nullable error))complete;

/**
 *  Async send a email with attachment, charset is UTF-8
 *
 *  @param dict     Key is Email...
 *  @param path     File path
 *  @param complete if error is nil, mean success
 */
- (void)sendRawEmail:(NSDictionary<NSString *, NSArray<NSString *> *> *_Nullable)dict attachmentFilePath:(NSString *_Nullable)path complete:(void (^_Nullable)(NSError *_Nullable error))complete;

/**
 *  Forgot password calls
 *
 *  @param userName enter user name first
 *  @param complete error.userInfo[@"__type"]
                and error.userInfo[@"message"]
 */
- (void)forgotPasswordWithUserName:(NSString *_Nonnull)userName complete:(void(^_Nullable)(NSError *_Nullable error))complete;

/**
 *  Confirm password, input your recived code
 *
 *  @param code     recived verification code from mailbox
 *  @param complete complete doing
 */
- (void)confirmForgotPassword:(NSString *_Nullable)code newPassword:(NSString *_Nullable)newPassword complete:(void(^_Nullable)(NSError *_Nullable error))complete;

/**
 *  Change password.
 */
- (void)changePasswordOldPassword:(NSString *_Nonnull)oldPwd newPassword:(NSString *_Nonnull)newPwd complete:(void(^_Nullable)(NSError *_Nullable error, AWSCognitoIdentityUserChangePasswordResponse *_Nullable response))complete;

/**
 *  Upload image use S3
 *
 *  @param filePath     file path, prefer not in album.
 *  @param uploading    use progress to show to UI.
 *  @param complete     complete, and you can get the image.
 */
- (void)upLoadImage:(NSString *_Nullable)filePath uploading:(void(^_Nullable)(float progress))uploading complete:(void(^_Nullable)(NSError *_Nullable error, UIImage *_Nullable image))complete;

/**
 *  Download image use S3
 *
 *  @param complete    complete, get this image without error.
 */
- (void)downLoadHeaderImageWithUserName:(NSString *_Nullable)userName complete:(void(^_Nullable)(NSError *_Nullable error, UIImage *_Nullable image))complete;

/**
 *  Download file and do something
 *
 *  @param path     path of file in AWS background
 */
- (void)downLoadFileWithFilePath:(NSString *_Nullable)path progress:(void(^_Nullable)(float progress, NSString *_Nullable name))progress complete:(void(^_Nullable)(NSError *_Nullable error, NSString *_Nullable path))complete;

/**
 *  Update user attributes
 */
- (void)updateAttributes:(NSArray<AWSCognitoIdentityUserAttributeType *> *_Nullable)attributes complete:(void(^_Nullable)(NSError *_Nullable error, AWSCognitoIdentityUserUpdateAttributesResponse *_Nullable response))complete;
@end
