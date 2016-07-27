//
//  ViewController.m
//  LGAWSManager
//
//  Created by 李振刚 on 16/7/27.
//  Copyright © 2016年 李振刚. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *nameTextField;
@property (weak, nonatomic) IBOutlet UITextField *passwordTextField;

@property (strong, nonatomic) NSMutableArray *objs;

@end

@implementation ViewController {
    AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails *> *_passwordAuthenticationCompletionSource;
}

// sign in button
- (IBAction)signInBtnClick:(id)sender {
    
    // password required 8 length
    if (self.nameTextField.text.length > 0 && self.passwordTextField.text.length >= 8) {
        
        [[LGAWSManager sharedManager] signInWithUserName:self.nameTextField.text password:self.passwordTextField.text passwordAuthenticationCompletionSource:_passwordAuthenticationCompletionSource];
    }
}

// lazy loaded
- (NSMutableArray *)objs {
    
    if (!_objs) {
        // This place for save user info
        _objs = [NSMutableArray array];
    }
    return _objs;
}

#pragma mark AWSCognitoIdentityPasswordAuthentication
// There is password authentication complete, show your UI
- (void)getPasswordAuthenticationDetails:(AWSCognitoIdentityPasswordAuthenticationInput *)authenticationInput passwordAuthenticationCompletionSource:(AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails *> *)passwordAuthenticationCompletionSource {
    
    // save this variable and it will used when sign in
    _passwordAuthenticationCompletionSource = passwordAuthenticationCompletionSource;
    
    // show last name, reload your UI
    NSString *lastName = authenticationInput.lastKnownUsername;
    __weak typeof(self)weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        weakSelf.nameTextField.text = lastName;
    });
}

// login complete
- (void)didCompletePasswordAuthenticationStepWithError:(NSError *)error {
    
    if (!error) {
        
        __weak typeof(self)weakSelf = self;
        [[LGAWSManager sharedManager] refresh:^(AWSCognitoIdentityUserGetDetailsResponse *response) {
            
            // get user info
            NSArray *array = response.userAttributes;
            for (AWSCognitoIdentityProviderAttributeType *attribute in array) {
                
                if ([attribute.name isEqualToString:@"email"]) {
                    
                    NSString *str = attribute.value;
                    [weakSelf.objs addObject:str];
                }
                else if ([attribute.name isEqualToString:@"An attribute of you had setted"]) {
                    
                    NSString *str = attribute.value;
                    [weakSelf.objs addObject:str];
                }
                else if ([attribute.name isEqualToString:@"An attribute of you had setted"]) {
                    
                    NSString *str = attribute.value;
                    [weakSelf.objs addObject:str];
                }
                else continue;
            }
        }];
    }
}

#pragma mark AWSCognitoIdentityMultiFactorAuthentication
- (void)getMultiFactorAuthenticationCode:(AWSCognitoIdentityMultifactorAuthenticationInput *)authenticationInput mfaCodeCompletionSource:(AWSTaskCompletionSource<NSString *> *)mfaCodeCompletionSource {
    
}
- (void)didCompleteMultifactorAuthenticationStepWithError:(NSError *)error {
    
}

@end
