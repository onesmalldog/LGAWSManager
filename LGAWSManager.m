//
//  LGAWSManager.m
//
//  Created by 李振刚 on 16/7/25.
//  Copyright © 2016年 displayten. All rights reserved.
//


// Documents are in 'LGAWSManager.h' , back to read it.

#import "LGAWSManager.h"
#import "AWSSES.h"

@interface LGAWSManager()

@property (strong, nonatomic) AWSCognitoIdentityUserPool *pool;

@end

@implementation LGAWSManager
@synthesize currentUser = _currentUser;

+ (instancetype)sharedManager {
    
    static LGAWSManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        manager = [[LGAWSManager alloc]init];
    });
    return manager;
}
- (AWSCognitoIdentityUserPool *)pool {
    if (!_pool) {
        _pool = [AWSCognitoIdentityUserPool CognitoIdentityUserPoolForKey:UserPool];
    }
    return _pool;
}
- (AWSCognitoIdentityUser *)currentUser {
    if (!_currentUser) {
        _currentUser = self.pool.currentUser;
    }
    return _currentUser;
}

+ (void)initializeWithAppDelegate:(id)appDelegate {
    
    [AWSLogger defaultLogger].logLevel = AWSLogLevelVerbose;
    
    AWSServiceConfiguration *serviceConfiguration = [[AWSServiceConfiguration alloc] initWithRegion:AWSRegionUSEast1 credentialsProvider:nil];
    
    AWSCognitoIdentityUserPoolConfiguration *configuration = [[AWSCognitoIdentityUserPoolConfiguration alloc] initWithClientId:CognitoIdentityUserPoolAppClientId  clientSecret:CognitoIdentityUserPoolAppClientSecret poolId:CognitoIdentityUserPoolId];
    
    [AWSCognitoIdentityUserPool registerCognitoIdentityUserPoolWithConfiguration:serviceConfiguration userPoolConfiguration:configuration forKey:UserPool];
    
    AWSCognitoIdentityUserPool *pool = [AWSCognitoIdentityUserPool CognitoIdentityUserPoolForKey:UserPool];
    
    AWSCognitoCredentialsProvider *credentialsProvider = [[AWSCognitoCredentialsProvider alloc]initWithRegionType:AWSRegionUSEast1 identityPoolId:IdentityPoolId unauthRoleArn:UnauthRoleArn authRoleArn:AuthRoleArn identityProviderManager:pool];
    
    AWSServiceConfiguration *defaultServiceConfiguration = [[AWSServiceConfiguration alloc] initWithRegion:AWSRegionUSEast1 credentialsProvider:credentialsProvider];
    
    AWSServiceManager.defaultServiceManager.defaultServiceConfiguration = defaultServiceConfiguration;
    
    pool.delegate = appDelegate;
}

- (AWSCognitoIdentityUser *)refresh:(void (^)(AWSCognitoIdentityUserGetDetailsResponse *))complete {
    
    [[self.currentUser getDetails] continueWithSuccessBlock:^id _Nullable(AWSTask<AWSCognitoIdentityUserGetDetailsResponse *> * _Nonnull task) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            complete(task.result);
        });
        return nil;
    }];
    return self.currentUser;
}
- (void)signInWithUserName:(NSString *)name password:(NSString *)password passwordAuthenticationCompletionSource:(AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails *> *)passwordAuthenticationCompletionSource {
    
    passwordAuthenticationCompletionSource.result = [[AWSCognitoIdentityPasswordAuthenticationDetails alloc]initWithUsername:name password:password];
}
- (AWSCognitoIdentityUserAttributeType *)createAttributeTypeWithName:(NSString *)name value:(NSString *)value {
    
    AWSCognitoIdentityUserAttributeType * type = [AWSCognitoIdentityUserAttributeType new];
    type.name = name;
    type.value = value;
    
    return type;
}
- (void)signUpWithUserName:(NSString *)name password:(NSString *)password attributes:(NSArray<AWSCognitoIdentityUserAttributeType *> *)attributes completed:(void (^)(NSError *))completed {
    
    [[self.pool signUp:name password:password userAttributes:attributes validationData:nil] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityUserPoolSignUpResponse *> * _Nonnull task) {
        
        completed(task.error);
        
        return nil;
    }];
}

- (void)sendEmail:(NSDictionary *)dict complete:(void (^)(NSError *))complete {
    
    NSString *fromEmail = dict[EmailFromEmail];
    NSString *toEmail = dict[EmailToEmail];
    NSString *subjectText = dict[EmailSubject];
    NSString *contentText = dict[EmailContentText];
    
    AWSSES *ses = [AWSSES defaultSES];
    
    AWSSESSendEmailRequest *sendEmailRequest = [AWSSESSendEmailRequest new];
    //    AWSSESSendRawEmailRequest *sendEmailRequest = [AWSSESSendRawEmailRequest new];
    sendEmailRequest.source = fromEmail;//@"zgli@mail.DTEN.com";
    
    AWSSESDestination *destination = [AWSSESDestination new];
    destination.toAddresses = @[toEmail];//@[@"ios@displayten.com.cn"];
    
    sendEmailRequest.destination = destination;
    
    AWSSESMessage *message = [AWSSESMessage new];
    AWSSESContent *subject = [AWSSESContent new];
    subject.data = subjectText;
    subject.charset = @"UTF-8";
    message.subject = subject;
    
    AWSSESContent *content = [AWSSESContent new];
    content.data = contentText;
    content.charset = @"UTF-8";
    
    AWSSESBody *body = [AWSSESBody new];
    body.text = content;
    message.body = body;
    sendEmailRequest.message = message;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // send email in global queue
        [[[ses sendEmail:sendEmailRequest] continueWithBlock:^id(AWSTask *task) {
            
            // do something in main queue
            dispatch_async(dispatch_get_main_queue(), ^{
                
                complete(task.error);
            });
            return nil;
            
        }] waitUntilFinished];
    });
}

- (void)signOutAndRefreshCompleted:(void (^)(AWSCognitoIdentityUserGetDetailsResponse *response))refreshCompleted {
    
    [self.currentUser signOut];
    [self refresh:^(AWSCognitoIdentityUserGetDetailsResponse *response) {
        
        refreshCompleted(response);
    }];
}

- (void)signOutAndClearLastKnowUserAndRefreshCompleted:(void (^)(AWSCognitoIdentityUserGetDetailsResponse *))refreshCompleted {
    
    [self.currentUser signOutAndClearLastKnownUser];
    [self refresh:^(AWSCognitoIdentityUserGetDetailsResponse *response) {
        
        refreshCompleted(response);
    }];
}
@end
