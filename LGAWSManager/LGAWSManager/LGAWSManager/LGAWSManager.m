//
//  LGAWSManager.m
//
//  Created by 李振刚 on 16/7/25.
//  Copyright © 2016年 displayten. All rights reserved.
//


// Documents are in 'LGAWSManager.h' , back to read it.

#import "LGAWSManager.h"
#import "AWSSES.h"
#import "DTGetFile.h"

@interface LGAWSManager()

@property (strong, nonatomic) AWSCognitoIdentityUserPool *pool;
@property (strong, nonatomic) dispatch_queue_t queue;

@end

@implementation LGAWSManager {
    AWSCognitoIdentityUser *_user;
    id _uploadObject;
    id _downloadObject;
}
@synthesize currentUser = _currentUser;

- (dispatch_queue_t)queue {
    if (!_queue) {
        
        _queue = dispatch_queue_create("AWS_Send_Email",DISPATCH_QUEUE_CONCURRENT);
    }
    return _queue;
}
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

- (AWSCognitoIdentityUser *)refresh {
    
    __weak typeof(self)weakSelf = self;
    [[self.currentUser getDetails] continueWithSuccessBlock:^id _Nullable(AWSTask<AWSCognitoIdentityUserGetDetailsResponse *> * task) {
        
        if ([weakSelf.delegate respondsToSelector:@selector(awsManagerDoRefresh:)]) {
            
            [weakSelf.delegate awsManagerDoRefresh:task.result];
        }
        return nil;
    }];
    
    return self.currentUser;
}
- (void)signInWithUserName:(NSString *)name password:(NSString *)password passwordAuthenticationCompletionSource:(AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails *> * _Nonnull)passwordAuthenticationCompletionSource {
    
    passwordAuthenticationCompletionSource.result = [[AWSCognitoIdentityPasswordAuthenticationDetails alloc]initWithUsername:name password:password];
}
- (AWSCognitoIdentityUserAttributeType *)createAttributeTypeWithName:(NSString *)name value:(NSString *)value {
    
    AWSCognitoIdentityUserAttributeType * type = [AWSCognitoIdentityUserAttributeType new];
    type.name = name;
    type.value = value;
    
    return type;
}
- (void)signUpWithUserName:(NSString *)name password:(NSString *)password attributes:(NSArray<AWSCognitoIdentityUserAttributeType *> *)attributes completed:(void (^)(NSError *))completed {
    _user = [self.pool getUser:name];
    [[self.pool signUp:name password:password userAttributes:attributes validationData:nil] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityUserPoolSignUpResponse *> * _Nonnull task) {
        
        completed(task.error);
        
        return nil;
    }];
}
- (void)confirmSignUpWithVerifiedCode:(NSString *_Nullable)code complete:(void(^_Nullable)(NSError *_Nullable error))complete {
    
    [[_user confirmSignUp:code] continueWithBlock: ^id _Nullable(AWSTask<AWSCognitoIdentityUserConfirmSignUpResponse *> * _Nonnull task) {
        
        complete(task.error);
        
        return nil;
    }];
}
- (void)sendRawEmail:(NSDictionary *)dict attachmentFilePath:(NSString *)path complete:(void (^)(NSError *error))complete {
    
    NSString *fromEmail = dict[EmailFromEmail];
    NSArray *toEmail = dict[EmailToEmail];
    NSString *subjectText = dict[EmailSubject];
    NSString *contentText = dict[EmailContentText];
    
    NSString *fileName = [path lastPathComponent];
    NSData *attachmentData = [NSData dataWithContentsOfFile:path];
    NSString *tmp = [attachmentData base64EncodedStringWithOptions:NSDataBase64Encoding76CharacterLineLength];
    
    NSString *type = [self MIMEJudgeType:[fileName pathExtension]];
    
    NSString *rawMessageString = [NSString stringWithFormat:@"MIME-Version: 1.0\nContent-Transfer-Encoding: 7bit\nContent-Type: multipart/mixed; boundary=\"__MY_BOUNDARY__\"\nSubject: %@\nTo: %@\n\nThis is a multi-part message in MIME format.\n\n--__MY_BOUNDARY__\nMIME-Version: 1.0\nContent-Transfer-Encoding: 7bit\nContent-Type: text/plain; charset=\"UTF-8\"\n\n%@\n\n--__MY_BOUNDARY__\nMIME-Version: 1.0\nContent-Disposition: attachment; filename=\"%@\"\nContent-Transfer-Encoding: base64\nContent-Type: %@; name=\"%@\"\n\n%@--__MY_BOUNDARY__", subjectText,fromEmail, contentText,fileName, type,fileName, tmp];
    
    NSData *data = [rawMessageString dataUsingEncoding:NSUTF8StringEncoding];
    
    AWSSES *ses = [AWSSES defaultSES];
    AWSSESSendRawEmailRequest *sendEmailRequest = [AWSSESSendRawEmailRequest new];
    sendEmailRequest.source = fromEmail;
    sendEmailRequest.destinations = toEmail;
    
    AWSSESRawMessage *message = [AWSSESRawMessage new];
    message.data = data;
    sendEmailRequest.rawMessage = message;
    
    dispatch_async(self.queue, ^{
        
        [[ses sendRawEmail:sendEmailRequest] continueWithBlock:^id(AWSTask *task) {
            
            complete(task.error);
            return nil;
        }];
    });
}

- (void)sendEmail:(NSDictionary *)dict complete:(void (^)(NSError *error))complete {
    
    NSString *fromEmail = dict[EmailFromEmail];
    NSArray *toEmail = dict[EmailToEmail];
    NSString *subjectText = dict[EmailSubject];
    NSString *contentText = dict[EmailContentText];
    
    AWSSES *ses = [AWSSES defaultSES];
    
    AWSSESSendEmailRequest *sendEmailRequest = [AWSSESSendEmailRequest new];

    sendEmailRequest.source = fromEmail;
    
    AWSSESDestination *destination = [AWSSESDestination new];
    destination.toAddresses = toEmail;
    
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
    
    dispatch_async(self.queue, ^{
        
        // send email in global queue
        [[[ses sendEmail:sendEmailRequest] continueWithBlock:^id(AWSTask *task) {
            
            complete(task.error);
            
            return nil;
            
        }] waitUntilFinished];
    });
}

- (void)signOutAndRefresh {
    
    [self.currentUser signOut];
    [self refresh];
}

- (void)signOutAndClearLastKnowUserAndRefresh {
    
    [self.currentUser signOutAndClearLastKnownUser];
    [self refresh];
}
- (void)forgotPasswordWithUserName:(NSString *_Nonnull)userName complete:(void(^_Nullable)(NSError *_Nullable error))complete {
    
    _user = [self.pool getUser:userName];
    [[_user forgotPassword] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityUserForgotPasswordResponse *> * _Nonnull task) {
        
        complete(task.error);
        return nil;
    }];
}
- (void)confirmForgotPassword:(NSString *)code newPassword:(NSString *)newPassword complete:(void (^)(NSError * _Nullable))complete {
    
    [[_user confirmForgotPassword:code password:newPassword] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityUserConfirmForgotPasswordResponse *> * _Nonnull task) {
        
        complete(task.error);
        
        return nil;
    }];
}

- (void)upLoadImage:(NSString *_Nullable)filePath uploading:(void(^_Nullable)(float progress))uploading complete:(void(^_Nullable)(NSError *_Nullable error, UIImage *_Nullable image))complete {
    
    __weak typeof(self)weakSelf = self;
    NSString *fileName = [filePath lastPathComponent];
    
    AWSS3TransferManager *transferManager = [AWSS3TransferManager defaultS3TransferManager];
    
    AWSS3TransferManagerUploadRequest *uploadRequest = [AWSS3TransferManagerUploadRequest new];
    NSURL *url =[NSURL fileURLWithPath:filePath];
    
    uploadRequest.body = url;
    uploadRequest.key = fileName;
    uploadRequest.bucket = BucketName;
    
    [[transferManager upload:uploadRequest] continueWithBlock:^id(AWSTask *task) {
        
        if (task.result) {
            
            _uploadObject = uploadRequest.body;
            [weakSelf whileUpLoadImageWhenUploading:^(float progress){
                
                uploading(progress);
                
            } complete:^(UIImage *image){
                
                complete(task.error, image);
            }];
        }
        
        return nil;
    }];
    
    _uploadObject = uploadRequest;
    
    [weakSelf whileUpLoadImageWhenUploading:^(float progress){
        
        uploading(progress);
        
    } complete:^(UIImage *image){
        
        complete(nil, image);
    }];
}

- (void)whileUpLoadImageWhenUploading:(void(^_Nullable)(float progress))uploading complete:(void(^_Nullable)(UIImage *_Nullable image))complete {
    
    if ([_uploadObject isKindOfClass:[AWSS3TransferManagerUploadRequest class]]) {
        AWSS3TransferManagerUploadRequest *uploadRequest = _uploadObject;
        
        uploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (totalBytesExpectedToSend > 0) {
                    float a = (float)((double) totalBytesSent / totalBytesExpectedToSend);
                    uploading(a);
                }
            });
        };
    } else if ([_uploadObject isKindOfClass:[NSURL class]]) {
        NSURL *downloadFileURL = _uploadObject;
        UIImage *image = [UIImage imageWithContentsOfFile:downloadFileURL.path];
        complete(image);
    }
}
- (void)downLoadFileWithFilePath:(NSString *_Nullable)path progress:(void(^_Nullable)(float progress, NSString *_Nullable name))progress complete:(void(^_Nullable)(NSError *_Nullable error, NSString *_Nullable path))complete {
    
    NSArray *array;
    if ([path hasPrefix:@"https"]) {
        
        array = [path componentsSeparatedByString:@"/"];
    }
    NSString *fileFloder;
    if (array.count > 1) {
        
        fileFloder = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"file"] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", array[array.count-2]]];
    }
    else fileFloder = [NSTemporaryDirectory() stringByAppendingPathComponent:@"file"];
    
    
    AWSS3 *s3 = [AWSS3 defaultS3];
    
    AWSS3ListObjectsRequest *listObjectsRequest = [AWSS3ListObjectsRequest new];
    listObjectsRequest.bucket = BucketName;
    
    [[s3 listObjects:listObjectsRequest] continueWithBlock:^id(AWSTask *task) {
        
        if (task.error) {
            
            complete(task.error, nil);
        } else {
            
            AWSS3ListObjectsOutput *listObjectsOutput = task.result;
            for (AWSS3Object *s3Object in listObjectsOutput.contents) {
                
//                NSLog(@"%@", s3Object.key);
                if ([path hasSuffix:s3Object.key]) {
                    
                    NSString *fileName = [s3Object.key lastPathComponent];
                    NSString *downloadingFilePath = [fileFloder stringByAppendingPathComponent:fileName];
                    NSURL *downloadingFileURL = [NSURL fileURLWithPath:downloadingFilePath];
                    
                    if ([[NSFileManager defaultManager] fileExistsAtPath:downloadingFilePath]) {
                        
                        _downloadObject = downloadingFileURL;
                        if ([_downloadObject isKindOfClass:[NSURL class]]) {
                            NSURL *downloadFileURL = _downloadObject;
                            complete(task.error, downloadFileURL.path);
                        }
                        
                    } else {
                        AWSS3TransferManagerDownloadRequest *downloadRequest = [AWSS3TransferManagerDownloadRequest new];
                        downloadRequest.bucket = BucketName;
                        downloadRequest.key = s3Object.key;
                        downloadRequest.downloadingFileURL = downloadingFileURL;
                        _downloadObject = downloadRequest;
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            AWSS3TransferManager *transferManager = [AWSS3TransferManager defaultS3TransferManager];
                            [[transferManager download:downloadRequest] continueWithBlock:^id(AWSTask *task) {
                                
                                if (task.error) {
                                    
                                    complete(task.error, nil);
                                }else {
                                    
                                    _downloadObject = downloadRequest.downloadingFileURL;
                                    
                                    if ([_downloadObject isKindOfClass:[NSURL class]]) {
                                        
                                        NSURL *downloadFileURL = _downloadObject;
                                        complete(task.error, downloadFileURL.path);
                                    }
                                }
                                return nil;
                            }];
                        });
                    }
                    
                    if ([_downloadObject isKindOfClass:[AWSS3TransferManagerDownloadRequest class]]) {
                        AWSS3TransferManagerDownloadRequest *downloadRequest = _downloadObject;
                        downloadRequest.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                if (totalBytesExpectedToWrite > 0) {
                                    float a = (float)((double) totalBytesWritten / totalBytesExpectedToWrite);
                                    
                                    progress(a, fileName);
                                    
                                }
                            });
                        };
                    }
                }
            }
        }
        return nil;
    }];
    
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:fileFloder
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
}
- (void)downLoadHeaderImageWithUserName:(NSString *)userName complete:(void(^_Nullable)(NSError *_Nullable error, UIImage *_Nullable image))complete {
    
    __weak typeof(self)weakSelf = self;
    
    AWSS3 *s3 = [AWSS3 defaultS3];
    
    AWSS3ListObjectsRequest *listObjectsRequest = [AWSS3ListObjectsRequest new];
    listObjectsRequest.bucket = BucketName;
    [[s3 listObjects:listObjectsRequest] continueWithBlock:^id(AWSTask *task) {
        
        if (task.error) {
            
            complete(task.error, nil);
        } else {
            
            AWSS3ListObjectsOutput *listObjectsOutput = task.result;
            for (AWSS3Object *s3Object in listObjectsOutput.contents) {
                
//                NSLog(@"%@", s3Object.key);
                if ([s3Object.key hasPrefix:userName]) {
                    
                    NSString *downloadingFilePath = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"download"] stringByAppendingPathComponent:s3Object.key];
                    NSURL *downloadingFileURL = [NSURL fileURLWithPath:downloadingFilePath];
                    
                    if ([[NSFileManager defaultManager] fileExistsAtPath:downloadingFilePath]) {
                        
                        _downloadObject = downloadingFileURL;
                        [weakSelf whileDownloadImageWhenDownloading:^(float progress){
                            
//                            downloading(progress);
                        } complete:^(UIImage *image){
                            
                            complete(task.error, image);
                        }];
                    } else {
                        AWSS3TransferManagerDownloadRequest *downloadRequest = [AWSS3TransferManagerDownloadRequest new];
                        downloadRequest.bucket = BucketName;
                        downloadRequest.key = s3Object.key;
                        downloadRequest.downloadingFileURL = downloadingFileURL;
                        _downloadObject = downloadRequest;
                        
// 下面的语句应该放到if判断完，并且加上一个判断
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            AWSS3TransferManager *transferManager = [AWSS3TransferManager defaultS3TransferManager];
                            [[transferManager download:downloadRequest] continueWithBlock:^id(AWSTask *task) {
                                
                                if (task.error) {
                                    
                                    complete(task.error, nil);
                                }else {
                                    
                                    _downloadObject = downloadRequest.downloadingFileURL;
                                    
                                    [weakSelf whileDownloadImageWhenDownloading:^(float progress){
                                        
//                                        downloading(progress);
                                    } complete:^(UIImage *image){
                                        
                                        complete(task.error, image);
                                    }];
                                }
                                
                                return nil;
                            }];
                        });
                    }
                } else continue;
            }
        }
        return nil;
    }];
    
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"download"]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
}

- (void)whileDownloadImageWhenDownloading:(void(^_Nullable)(float progress))downloading complete:(void(^_Nullable)(UIImage *_Nullable image))complete {
    /*
    if ([_downloadObject isKindOfClass:[AWSS3TransferManagerDownloadRequest class]]) {
        AWSS3TransferManagerDownloadRequest *downloadRequest = _downloadObject;
        downloadRequest.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (totalBytesExpectedToWrite > 0) {
                    float a = (float)((double) totalBytesWritten / totalBytesExpectedToWrite);
                    downloading(a);
                }
            });
        };
    }
    else*/ if ([_downloadObject isKindOfClass:[NSURL class]]) {
        NSURL *downloadFileURL = _downloadObject;
        
        UIImage *image = [UIImage imageWithContentsOfFile:downloadFileURL.path];
        complete(image);
    }
}
- (void)updateAttributes:(NSArray<AWSCognitoIdentityUserAttributeType *> *)attributes complete:(void(^_Nullable)(NSError *_Nullable error, AWSCognitoIdentityUserUpdateAttributesResponse *_Nullable response))complete {
    
    [[[LGAWSManager sharedManager].currentUser updateAttributes:attributes]  continueWithBlock:^id(AWSTask *task) {
        
        complete(task.error, task.result);
        
        return nil;
    }];
}

- (void)changePasswordOldPassword:(NSString *_Nonnull)oldPwd newPassword:(NSString *_Nonnull)newPwd complete:(void(^_Nullable)(NSError *_Nullable error, AWSCognitoIdentityUserChangePasswordResponse *_Nullable response))complete {
    
    [[self.currentUser changePassword:oldPwd proposedPassword:newPwd] continueWithBlock:^id(AWSTask *task) {
        
        complete(task.error, task.result);
        return nil;
    }];
}

- (NSString *)MIMEJudgeType:(NSString *)type {
    
    type = [type lowercaseString];
    
    if ([type isEqualToString:@"3gp"]) {
        
        return @"video/3gpp";
    }
    else if ([type isEqualToString:@"3gpp"]) {
        
        return @"video/3gpp";
    }
    
    else if ([type isEqualToString:@"3gpp"]) {
        
        return @"video/3gpp";
    }
    else if ([type isEqualToString:@"aac"]) {
        
        return @"audio/x-mpeg";
    }
    else if ([type isEqualToString:@"amr"]) {
        
        return @"audio/x-mpeg";
    }
    else if ([type isEqualToString:@"apk"]) {
        
        return @"application/vnd.android.package-archive";
    }
    else if ([type isEqualToString:@"avi"]) {
        
        return @"video/x-msvideo";
    }
    else if ([type isEqualToString:@"aab"]) {
        
        return @"application/x-authoware-bin";
    }
    else if ([type isEqualToString:@"aam"]) {
        
        return @"application/x-authoware-map";
    }
    else if ([type isEqualToString:@"aas"]) {
        
        return @"application/x-authoware-seg";
    }
    else if ([type isEqualToString:@"ai"]) {
        
        return @"application/postscript";
    }
    else if ([type isEqualToString:@"aif"]) {
        
        return @"audio/x-aiff";
    }
    else if ([type isEqualToString:@"aifc"]) {
        
        return @"audio/x-aiff";
    }
    else if ([type isEqualToString:@"aiff"]) {
        
        return @"audio/x-aiff";
    }
    else if ([type isEqualToString:@"als"]) {
        
        return @"audio/x-alpha5";
    }
    else if ([type isEqualToString:@"amc"]) {
        
        return @"application/x-mpeg";
    }
    else if ([type isEqualToString:@"ani"]) {
        
        return @"application/octet-stream";
    }
    else if ([type isEqualToString:@"asc"]) {
        
        return @"text/plain";
    }
    else if ([type isEqualToString:@"asd"]) {
        
        return @"application/astound";
    }
    else if ([type isEqualToString:@"asf"]) {
        
        return @"video/x-ms-asf";
    }
    else if ([type isEqualToString:@"asn"]) {
        
        return @"application/astound";
    }
    else if ([type isEqualToString:@"asp"]) {
        
        return @"application/x-asap";
    }
    else if ([type isEqualToString:@"asx"]) {
        
        return @" video/x-ms-asf";
    }
    else if ([type isEqualToString:@"au"]) {
        
        return @"audio/basic";
    }
    else if ([type isEqualToString:@"avb"]) {
        
        return @"application/octet-stream";
    }
    else if ([type isEqualToString:@"awb"]) {
        
        return @"audio/amr-wb";
    }
    else if ([type isEqualToString:@"bcpio"]) {
        
        return @"application/x-bcpio";
    }
    else if ([type isEqualToString:@"bld"]) {
        
        return @"application/bld";
    }
    else if ([type isEqualToString:@"bld2"]) {
        
        return @"application/bld2";
    }
    else if ([type isEqualToString:@"bpk"]) {
        
        return @"application/octet-stream";
    }
    else if ([type isEqualToString:@"bz2"]) {
        
        return @"application/x-bzip2";
    }
    else if ([type isEqualToString:@"bin"]) {
        
        return @"application/octet-stream";
    }
    else if ([type isEqualToString:@"bmp"]) {
        
        return @"image/bmp";
    }
    else if ([type isEqualToString:@"c"]) {
        
        return @"text/plain";
    }
    else if ([type isEqualToString:@"class"]) {
        
        return @"application/octet-stream";
    }
    else if ([type isEqualToString:@"conf"]) {
        
        return @"text/plain";
    }
    else if ([type isEqualToString:@"cpp"]) {
        
        return @"text/plain";
    }
    else if ([type isEqualToString:@"cal"]) {
        
        return @"image/x-cals";
    }
    else if ([type isEqualToString:@"ccn"]) {
        
        return @"application/x-cnc";
    }
    else if ([type isEqualToString:@"cco"]) {
        
        return @"application/x-cocoa";
    }
    else if ([type isEqualToString:@"cdf"]) {
        
        return @"application/x-netcdf";
    }
    else if ([type isEqualToString:@"cgi"]) {
        
        return @"magnus-internal/cgi";
    }
    else if ([type isEqualToString:@"chat"]) {
        
        return @"application/x-chat";
    }
    else if ([type isEqualToString:@"clp"]) {
        
        return @"application/x-msclip";
    }
    else if ([type isEqualToString:@"cmx"]) {
        
        return @"application/x-cmx";
    }
    else if ([type isEqualToString:@"co"]) {
        
        return @"application/x-cult3d-object";
    }
    else if ([type isEqualToString:@"cod"]) {
        
        return @"image/cis-cod";
    }
    else if ([type isEqualToString:@"cpio"]) {
        
        return @"application/x-cpio";
    }
    else if ([type isEqualToString:@"cpt"]) {
        
        return @"application/mac-compactpro";
    }
    else if ([type isEqualToString:@"crd"]) {
        
        return @"application/x-mscardfile";
    }
    else if ([type isEqualToString:@"csh"]) {
        
        return @"application/x-csh";
    }
    else if ([type isEqualToString:@"csm"]) {
        
        return @"chemical/x-csml";
    }
    else if ([type isEqualToString:@"csml"]) {
        
        return @"chemical/x-csml";
    }
    else if ([type isEqualToString:@"css"]) {
        
        return @"text/css";
    }
    else if ([type isEqualToString:@"cur"]) {
        
        return @"application/octet-stream";
    }
    else if ([type isEqualToString:@"doc"]) {
        
        return @"application/msword";
    }
    else if ([type isEqualToString:@"docx"]) {
        
        return @"application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    }
    else if ([type isEqualToString:@"dcm"]) {
        
        return @"x-lml/x-evm";
    }
    else if ([type isEqualToString:@"dcr"]) {
        
        return @"application/x-director";
    }
    else if ([type isEqualToString:@"dcx"]) {
        
        return @"image/x-dcx";
    }
    else if ([type isEqualToString:@"dhtml"]) {
        
        return @"text/html";
    }
    else if ([type isEqualToString:@"dir"]) {
        
        return @"application/x-director";
    }
    else if ([type isEqualToString:@"dll"]) {
        
        return @"application/octet-stream";
    }
    else if ([type isEqualToString:@"dmg"]) {
        
        return @"application/octet-stream";
    }
    else if ([type isEqualToString:@"dms"]) {
        
        return @"application/octet-stream";
    }
    else if ([type isEqualToString:@"dot"]) {
        
        return @"application/x-dot";
    }
    else if ([type isEqualToString:@"dvi"]) {
        
        return @"application/x-dvi";
    }
    else if ([type isEqualToString:@"dwf"]) {
        
        return @"drawing/x-dwf";
    }
    else if ([type isEqualToString:@"dwg"]) {
        
        return @"application/x-autocad";
    }
    else if ([type isEqualToString:@"dxf"]) {
        
        return @"application/x-autocad";
    }
    else if ([type isEqualToString:@"dxr"]) {
        
        return @"application/x-director";
    }
    else if ([type isEqualToString:@"ebk"]) {
        
        return @"application/x-expandedbook";
    }
    else if ([type isEqualToString:@"emb"]) {
        
        return @"chemical/x-embl-dl-nucleotide";
    }
    else if ([type isEqualToString:@"embl"]) {
        
        return @"chemical/x-embl-dl-nucleotide";
    }
    else if ([type isEqualToString:@"eps"]) {
        
        return @"application/postscript";
    }
    else if ([type isEqualToString:@"epub"]) {
        
        return @"application/epub+zip";
    }
    else if ([type isEqualToString:@"eri"]) {
        
        return @"image/x-eri";
    }
    else if ([type isEqualToString:@"es"]) {
        
        return @"audio/echospeech";
    }
    else if ([type isEqualToString:@"esl"]) {
        
        return @"audio/echospeech";
    }
    else if ([type isEqualToString:@"etc"]) {
        
        return @"application/x-earthtime";
    }
    else if ([type isEqualToString:@"etx"]) {
        
        return @"text/x-setext";
    }
    else if ([type isEqualToString:@"evm"]) {
        
        return @"x-lml/x-evm";
    }
    else if ([type isEqualToString:@"evy"]) {
        
        return @"application/x-envoy";
    }
    else if ([type isEqualToString:@"exe"]) {
        
        return @"application/octet-stream";
    }
    else if ([type isEqualToString:@"fh4"]) {
        
        return @"image/x-freehand";
    }
    else if ([type isEqualToString:@"fh5"]) {
        
        return @"image/x-freehand";
    }
    else if ([type isEqualToString:@"fhc"]) {
        
        return @"image/x-freehand";
    }
    else if ([type isEqualToString:@"fif"]) {
        
        return @"image/fif";
    }
    else if ([type isEqualToString:@"fm"]) {
        
        return @"application/x-maker";
    }
    else if ([type isEqualToString:@"fpx"]) {
        
        return @"image/x-fpx";
    }
    else if ([type isEqualToString:@"fvi"]) {
        
        return @"video/isivideo";
    }
    else if ([type isEqualToString:@"flv"]) {
        
        return @"video/x-msvideo";
    }
    else if ([type isEqualToString:@"gau"]) {
        
        return @"chemical/x-gaussian-input";
    }
    else if ([type isEqualToString:@"gca"]) {
        
        return @"application/x-gca-compressed";
    }
    else if ([type isEqualToString:@"gdb"]) {
        
        return @"x-lml/x-gdb";
    }
    else if ([type isEqualToString:@"gif"]) {
        
        return @"image/gif";
    }
    else if ([type isEqualToString:@"gps"]) {
        
        return @"application/x-gps";
    }
    else if ([type isEqualToString:@"gtar"]) {
        
        return @"application/x-gtar";
    }
    else if ([type isEqualToString:@"gz"]) {
        
        return @"application/x-gzip";
    }
    else if ([type isEqualToString:@"gif"]) {
        
        return @"image/gif";
    }
    else if ([type isEqualToString:@"gtar"]) {
        
        return @"application/x-gtar";
    }
    else if ([type isEqualToString:@"gz"]) {
        
        return @"application/x-gzip";
    }
    else if ([type isEqualToString:@"h"]) {
        
        return @"text/plain";
    }
    else if ([type isEqualToString:@"hdf"]) {
        
        return @"application/x-hdf";
    }
    else if ([type isEqualToString:@"hdm"]) {
        
        return @"text/x-hdml";
    }
    else if ([type isEqualToString:@"hdml"]) {
        
        return @"text/x-hdml";
    }
    else if ([type isEqualToString:@"htm"]) {
        
        return @"text/html";
    }
    else if ([type isEqualToString:@"html"]) {
        
        return @"text/html";
    }
    else if ([type isEqualToString:@"hlp"]) {
        
        return @"application/winhlp";
    }
    else if ([type isEqualToString:@"hqx"]) {
        
        return @"application/mac-binhex40";
    }
    else if ([type isEqualToString:@"hts"]) {
        
        return @"text/html";
    }
    else if ([type isEqualToString:@"ice"]) {
        
        return @"x-conference/x-cooltalk";
    }
    else if ([type isEqualToString:@"ico"]) {
        
        return @"application/octet-stream";
    }
    else if ([type isEqualToString:@"ief"]) {
        
        return @"image/ief";
    }
    else if ([type isEqualToString:@"ifm"]) {
        
        return @"image/gif";
    }
    else if ([type isEqualToString:@"ifs"]) {
        
        return @"image/ifs";
    }
    else if ([type isEqualToString:@"imy"]) {
        
        return @"audio/melody";
    }
    else if ([type isEqualToString:@"ins"]) {
        
        return @"application/x-net-install";
    }
    else if ([type isEqualToString:@"ips"]) {
        
        return @"application/x-ipscript";
    }
    else if ([type isEqualToString:@"ipx"]) {
        
        return @"application/x-ipix";
    }
    else if ([type isEqualToString:@"it"]) {
        
        return @"audio/x-mod";
    }
    else if ([type isEqualToString:@"itz"]) {
        
        return @"audio/x-mod";
    }
    else if ([type isEqualToString:@"ivr"]) {
        
        return @"i-world/i-vrml";
    }
    else if ([type isEqualToString:@"j2k"]) {
        
        return @"image/j2k";
    }
    else if ([type isEqualToString:@"jad"]) {
        
        return @"text/vnd.sun.j2me.app-descriptor";
    }
    else if ([type isEqualToString:@"jam"]) {
        
        return @"application/x-jam";
    }
    else if ([type isEqualToString:@"jnlp"]) {
        
        return @"application/x-java-jnlp-file";
    }
    else if ([type isEqualToString:@"jpe"]) {
        
        return @"image/jpeg";
    }
    else if ([type isEqualToString:@"jpz"]) {
        
        return @"image/jpeg";
    }
    else if ([type isEqualToString:@"jwc"]) {
        
        return @"application/jwc";
    }
    else if ([type isEqualToString:@"jar"]) {
        
        return @"application/java-archive";
    }
    else if ([type isEqualToString:@"java"]) {
        
        return @"text/plain";
    }
    else if ([type isEqualToString:@"jpeg"]) {
        
        return @"image/jpeg";
    }
    else if ([type isEqualToString:@"jpg"]) {
        
        return @"image/jpeg";
    }
    else if ([type isEqualToString:@"js"]) {
        
        return @"application/x-javascript";
    }
    else if ([type isEqualToString:@"kjx"]) {
        
        return @"application/x-kjx";
    }
    else if ([type isEqualToString:@"lak"]) {
        
        return @"x-lml/x-lak";
    }
    else if ([type isEqualToString:@"latex"]) {
        
        return @"application/x-latex";
    }
    else if ([type isEqualToString:@"lcc"]) {
        
        return @"application/fastman";
    }
    else if ([type isEqualToString:@"lcl"]) {
        
        return @"application/x-digitalloca";
    }
    else if ([type isEqualToString:@"lcr"]) {
        
        return @"application/x-digitalloca";
    }
    else if ([type isEqualToString:@"lgh"]) {
        
        return @"application/lgh";
    }
    else if ([type isEqualToString:@"lha"]) {
        
        return @"application/octet-stream";
    }
    else if ([type isEqualToString:@"lml"]) {
        
        return @"x-lml/x-lml";
    }
    else if ([type isEqualToString:@"lmlpack"]) {
        
        return @"x-lml/x-lmlpack";
    }
    else if ([type isEqualToString:@"log"]) {
        
        return @"text/plain";
    }
    else if ([type isEqualToString:@"lsf"]) {
        
        return @"video/x-ms-asf";
    }
    else if ([type isEqualToString:@"lsx"]) {
        
        return @"video/x-ms-asf";
    }
    else if ([type isEqualToString:@"lzh"]) {
        
        return @"application/x-lzh ";
    }
    else if ([type isEqualToString:@"m13"]) {
        
        return @"application/x-msmediaview";
    }
    else if ([type isEqualToString:@"m14"]) {
        
        return @"application/x-msmediaview";
    }
    else if ([type isEqualToString:@"m15"]) {
        
        return @"audio/x-mod";
    }
    else if ([type isEqualToString:@"m3u"]) {
        
        return @"audio/x-mpegurl";
    }
    else if ([type isEqualToString:@"m3url"]) {
        
        return @"audio/x-mpegurl";
    }
    else if ([type isEqualToString:@"ma1"]) {
        
        return @"audio/ma1";
    }
    else if ([type isEqualToString:@"ma2"]) {
        
        return @"audio/ma2";
    }
    else if ([type isEqualToString:@"ma3"]) {
        
        return @"audio/ma3";
    }
    else if ([type isEqualToString:@"ma5"]) {
        
        return @"audio/ma5";
    }
    else if ([type isEqualToString:@"man"]) {
        
        return @"application/x-troff-man";
    }
    else if ([type isEqualToString:@"map"]) {
        
        return @"magnus-internal/imagemap";
    }
    else if ([type isEqualToString:@"mbd"]) {
        
        return @"application/mbedlet";
    }
    else if ([type isEqualToString:@"mct"]) {
        
        return @"application/x-mascot";
    }
    else if ([type isEqualToString:@"mdb"]) {
        
        return @"application/x-msaccess";
    }
    else if ([type isEqualToString:@"mdz"]) {
        
        return @"audio/x-mod";
    }
    else if ([type isEqualToString:@"me"]) {
        
        return @"application/x-troff-me";
    }
    else if ([type isEqualToString:@"mel"]) {
        
        return @"text/x-vmel";
    }
    else if ([type isEqualToString:@"mi"]) {
        
        return @"application/x-mif";
    }
    else if ([type isEqualToString:@"mid"]) {
        
        return @"audio/midi";
    }
    else if ([type isEqualToString:@"midi"]) {
        
        return @"audio/midi";
    }
    else if ([type isEqualToString:@"m4a"]) {
        
        return @"audio/mp4a-latm";
    }
    else if ([type isEqualToString:@"m4b"]) {
        
        return @"audio/mp4a-latm";
    }
    else if ([type isEqualToString:@"m4p"]) {
        
        return @"audio/mp4a-latm";
    }
    else if ([type isEqualToString:@"m4u"]) {
        
        return @"video/vnd.mpegurl";
    }
    else if ([type isEqualToString:@"m4v"]) {
        
        return @"video/x-m4v";
    }
    else if ([type isEqualToString:@"mov"]) {
        
        return @"video/quicktime";
    }
    else if ([type isEqualToString:@"mp2"]) {
        
        return @"audio/x-mpeg";
    }
    else if ([type isEqualToString:@"mp3"]) {
        
        return @"audio/x-mpeg";
    }
    else if ([type isEqualToString:@"mp4"]) {
        
        return @"video/mp4";
    }
    else if ([type isEqualToString:@"mpc"]) {
        
        return @"application/vnd.mpohun.certificate";
    }
    else if ([type isEqualToString:@"mpe"]) {
        
        return @"video/mpeg";
    }
    else if ([type isEqualToString:@"mpeg"]) {
        
        return @"video/mpeg";
    }
    else if ([type isEqualToString:@"mpg"]) {
        
        return @"video/mpeg";
    }
    else if ([type isEqualToString:@"mpg4"]) {
        
        return @"video/mp4";
    }
    else if ([type isEqualToString:@"mpga"]) {
        
        return @"audio/mpeg";
    }
    else if ([type isEqualToString:@"msg"]) {
        
        return @"application/vnd.ms-outlook";
    }
    else if ([type isEqualToString:@"mif"]) {
        
        return @"application/x-mif";
    }
    else if ([type isEqualToString:@"mil"]) {
        
        return @"image/x-cals";
    }
    else if ([type isEqualToString:@"mio"]) {
        
        return @"audio/x-mio";
    }
    else if ([type isEqualToString:@"mmf"]) {
        
        return @"application/x-skt-lbs";
    }
    else if ([type isEqualToString:@"mng"]) {
        
        return @"video/x-mng";
    }
    else if ([type isEqualToString:@"mny"]) {
        
        return @"application/x-msmoney";
    }
    else if ([type isEqualToString:@"moc"]) {
        
        return @"application/x-mocha";
    }
    else if ([type isEqualToString:@"mocha"]) {
        
        return @"application/x-mocha";
    }
    else if ([type isEqualToString:@"mod"]) {
        
        return @"audio/x-mod";
    }
    else if ([type isEqualToString:@"mof"]) {
        
        return @"application/x-yumekara";
    }
    else if ([type isEqualToString:@"mol"]) {
        
        return @"chemical/x-mdl-molfile";
    }
    else if ([type isEqualToString:@"mop"]) {
        
        return @"chemical/x-mopac-input";
    }
    else if ([type isEqualToString:@"movie"]) {
        
        return @"video/x-sgi-movie";
    }
    else if ([type isEqualToString:@"mpn"]) {
        
        return @"application/vnd.mophun.application";
    }
    else if ([type isEqualToString:@"mpp"]) {
        
        return @"application/vnd.ms-project";
    }
    else if ([type isEqualToString:@"mps"]) {
        
        return @"application/x-mapserver";
    }
    else if ([type isEqualToString:@"mrl"]) {
        
        return @"text/x-mrml";
    }
    else if ([type isEqualToString:@"mrm"]) {
        
        return @"application/x-mrm";
    }
    else if ([type isEqualToString:@"ms"]) {
        
        return @"application/x-troff-ms";
    }
    else if ([type isEqualToString:@"mts"]) {
        
        return @"application/metastream";
    }
    else if ([type isEqualToString:@"mtx"]) {
        
        return @"application/metastream";
    }
    else if ([type isEqualToString:@"mtz"]) {
        
        return @"application/metastream";
    }
    else if ([type isEqualToString:@"mzv"]) {
        
        return @"application/metastream";
    }
    else if ([type isEqualToString:@"nar"]) {
        
        return @"application/zip";
    }
    else if ([type isEqualToString:@"nbmp"]) {
        
        return @"image/nbmp";
    }
    else if ([type isEqualToString:@"nc"]) {
        
        return @"application/x-netcdf";
    }
    else if ([type isEqualToString:@"ndb"]) {
        
        return @"x-lml/x-ndb";
    }
    else if ([type isEqualToString:@"ndwn"]) {
        
        return @"application/ndwn";
    }
    else if ([type isEqualToString:@"nif"]) {
        
        return @"application/x-nif";
    }
    else if ([type isEqualToString:@"nmz"]) {
        
        return @"application/x-scream";
    }
    else if ([type isEqualToString:@"nokia-op-logo"]) {
        
        return @"image/vnd.nok-oplogo-color";
    }
    else if ([type isEqualToString:@"npx"]) {
        
        return @"application/x-netfpx";
    }
    else if ([type isEqualToString:@"nsnd"]) {
        
        return @"audio/nsnd";
    }
    else if ([type isEqualToString:@"nva"]) {
        
        return @"application/x-neva1";
    }
    else if ([type isEqualToString:@"oda"]) {
        
        return @"application/oda";
    }
    else if ([type isEqualToString:@"oom"]) {
        
        return @"application/x-atlasMate-plugin";
    }
    else if ([type isEqualToString:@"ogg"]) {
        
        return @"audio/ogg";
    }
    else if ([type isEqualToString:@"pac"]) {
        
        return @"audio/x-pac";
    }
    else if ([type isEqualToString:@"pae"]) {
        
        return @"audio/x-epac";
    }
    else if ([type isEqualToString:@"pan"]) {
        
        return @"application/x-pan";
    }
    else if ([type isEqualToString:@"pbm"]) {
        
        return @"image/x-portable-bitmap";
    }
    else if ([type isEqualToString:@"pcx"]) {
        
        return @"image/x-pcx";
    }
    else if ([type isEqualToString:@"pda"]) {
        
        return @"image/x-pda";
    }
    else if ([type isEqualToString:@"pdb"]) {
        
        return @"chemical/x-pdb";
    }
    else if ([type isEqualToString:@"pdf"]) {
        
        return @"application/pdf";
    }
    else if ([type isEqualToString:@"pfr"]) {
        
        return @"application/font-tdpfr";
    }
    else if ([type isEqualToString:@"pgm"]) {
        
        return @"image/x-portable-graymap";
    }
    else if ([type isEqualToString:@"pict"]) {
        
        return @"image/x-pict";
    }
    else if ([type isEqualToString:@"pm"]) {
        
        return @"application/x-perl";
    }
    else if ([type isEqualToString:@"pmd"]) {
        
        return @"application/x-pmd";
    }
    else if ([type isEqualToString:@"png"]) {
        
        return @"image/png";
    }
    else if ([type isEqualToString:@"pnm"]) {
        
        return @"image/x-portable-anymap";
    }
    else if ([type isEqualToString:@"pnz"]) {
        
        return @"image/png";
    }
    else if ([type isEqualToString:@"pot"]) {
        
        return @"application/vnd.ms-powerpoint";
    }
    else if ([type isEqualToString:@"ppm"]) {
        
        return @"image/x-portable-pixmap";
    }
    else if ([type isEqualToString:@"pps"]) {
        
        return @"application/vnd.ms-powerpoint";
    }
    else if ([type isEqualToString:@"ppt"]) {
        
        return @"application/vnd.ms-powerpoint";
    }
    else if ([type isEqualToString:@"pptx"]) {
        
        return @"application/vnd.openxmlformats-officedocument.presentationml.presentation";
    }
    else if ([type isEqualToString:@"pqf"]) {
        
        return @"application/x-cprplayer";
    }
    else if ([type isEqualToString:@"pqi"]) {
        
        return @"application/cprplayer";
    }
    else if ([type isEqualToString:@"prc"]) {
        
        return @"application/x-prc";
    }
    else if ([type isEqualToString:@"proxy"]) {
        
        return @"application/x-ns-proxy-autoconfig";
    }
    else if ([type isEqualToString:@"prop"]) {
        
        return @"text/plain";
    }
    else if ([type isEqualToString:@"ps"]) {
        
        return @"application/postscript";
    }
    else if ([type isEqualToString:@"ptlk"]) {
        
        return @"application/listenup";
    }
    else if ([type isEqualToString:@"pub"]) {
        
        return @"application/x-mspublisher";
    }
    else if ([type isEqualToString:@"pvx"]) {
        
        return @"video/x-pv-pvx";
    }
    else if ([type isEqualToString:@"qcp"]) {
        
        return @"audio/vnd.qcelp";
    }
    else if ([type isEqualToString:@"qt"]) {
        
        return @"video/quicktime";
    }
    else if ([type isEqualToString:@"qti"]) {
        
        return @"image/x-quicktime";
    }
    else if ([type isEqualToString:@"qtif"]) {
        
        return @"image/x-quicktime";
    }
    else if ([type isEqualToString:@"r3t"]) {
        
        return @"text/vnd.rn-realtext3d";
    }
    else if ([type isEqualToString:@"ra"]) {
        
        return @"audio/x-pn-realaudio";
    }
    else if ([type isEqualToString:@"ram"]) {
        
        return @"audio/x-pn-realaudio";
    }
    else if ([type isEqualToString:@"ras"]) {
        
        return @"image/x-cmu-raster";
    }
    else if ([type isEqualToString:@"rdf"]) {
        
        return @"application/rdf+xml";
    }
    else if ([type isEqualToString:@"rf"]) {
        
        return @"image/vnd.rn-realflash";
    }
    else if ([type isEqualToString:@"rgb"]) {
        
        return @"image/x-rgb";
    }
    else if ([type isEqualToString:@"rlf"]) {
        
        return @"application/x-richlink";
    }
    else if ([type isEqualToString:@"rm"]) {
        
        return @"audio/x-pn-realaudio";
    }
    else if ([type isEqualToString:@"rmf"]) {
        
        return @"audio/x-rmf";
    }
    else if ([type isEqualToString:@"rmm"]) {
        
        return @"audio/x-pn-realaudio";
    }
    else if ([type isEqualToString:@"rnx"]) {
        
        return @"application/vnd.rn-realplayer";
    }
    else if ([type isEqualToString:@"roff"]) {
        
        return @"application/x-troff";
    }
    else if ([type isEqualToString:@"rp"]) {
        
        return @"image/vnd.rn-realpix";
    }
    else if ([type isEqualToString:@"rpm"]) {
        
        return @"audio/x-pn-realaudio-plugin";
    }
    else if ([type isEqualToString:@"rt"]) {
        
        return @"text/vnd.rn-realtext";
    }
    else if ([type isEqualToString:@"rte"]) {
        
        return @"x-lml/x-gps";
    }
    else if ([type isEqualToString:@"rtf"]) {
        
        return @"application/rtf";
    }
    else if ([type isEqualToString:@"rtg"]) {
        
        return @"application/metastream";
    }
    else if ([type isEqualToString:@"rtx"]) {
        
        return @"text/richtext";
    }
    else if ([type isEqualToString:@"rv"]) {
        
        return @"video/vnd.rn-realvideo";
    }
    else if ([type isEqualToString:@"rwc"]) {
        
        return @"application/x-rogerwilco";
    }
    else if ([type isEqualToString:@"rar"]) {
        
        return @"application/x-rar-compressed";
    }
    else if ([type isEqualToString:@"rc"]) {
        
        return @"text/plain";
    }
    else if ([type isEqualToString:@"rmvb"]) {
        
        return @"audio/x-pn-realaudio";
    }
    else if ([type isEqualToString:@"s3m"]) {
        
        return @"audio/x-mod";
    }
    else if ([type isEqualToString:@"s3z"]) {
        
        return @"audio/x-mod";
    }
    else if ([type isEqualToString:@"sca"]) {
        
        return @"application/x-supercard";
    }
    else if ([type isEqualToString:@"scd"]) {
        
        return @"application/x-msschedule";
    }
    else if ([type isEqualToString:@"sdf"]) {
        
        return @"application/e-score";
    }
    else if ([type isEqualToString:@"sea"]) {
        
        return @"application/x-stuffit";
    }
    else if ([type isEqualToString:@"sgm"]) {
        
        return @"text/x-sgml";
    }
    else if ([type isEqualToString:@"sgml"]) {
        
        return @"text/x-sgml";
    }
    else if ([type isEqualToString:@"shar"]) {
        
        return @"application/x-shar";
    }
    else if ([type isEqualToString:@"shtml"]) {
        
        return @"magnus-internal/parsed-html";
    }
    else if ([type isEqualToString:@"shw"]) {
        
        return @"application/presentations";
    }
    else if ([type isEqualToString:@"si6"]) {
        
        return @"image/si6";
    }
    else if ([type isEqualToString:@"si7"]) {
        
        return @"image/vnd.stiwap.sis";
    }
    else if ([type isEqualToString:@"si9"]) {
        
        return @"image/vnd.lgtwap.sis";
    }
    else if ([type isEqualToString:@"sis"]) {
        
        return @"application/vnd.symbian.install";
    }
    else if ([type isEqualToString:@"sit"]) {
        
        return @"application/x-stuffit";
    }
    else if ([type isEqualToString:@"skd"]) {
        
        return @"application/x-koan";
    }
    else if ([type isEqualToString:@"skm"]) {
        
        return @"application/x-koan";
    }
    else if ([type isEqualToString:@"skp"]) {
        
        return @"application/x-koan";
    }
    else if ([type isEqualToString:@"skt"]) {
        
        return @"application/x-koan";
    }
    else if ([type isEqualToString:@"slc"]) {
        
        return @"application/x-salsa";
    }
    else if ([type isEqualToString:@"smd"]) {
        
        return @"audio/x-smd";
    }
    else if ([type isEqualToString:@"smi"]) {
        
        return @"application/smil";
    }
    else if ([type isEqualToString:@"smil"]) {
        
        return @"application/smil";
    }
    else if ([type isEqualToString:@"smp"]) {
        
        return @"application/studiom";
    }
    else if ([type isEqualToString:@"smz"]) {
        
        return @"audio/x-smd";
    }
    else if ([type isEqualToString:@"sh"]) {
        
        return @"application/x-sh";
    }
    else if ([type isEqualToString:@"snd"]) {
        
        return @"audio/basic";
    }
    else if ([type isEqualToString:@"spc"]) {
        
        return @"text/x-speech";
    }
    else if ([type isEqualToString:@"spl"]) {
        
        return @"application/futuresplash";
    }
    else if ([type isEqualToString:@"spr"]) {
        
        return @"application/x-sprite";
    }
    else if ([type isEqualToString:@"sprite"]) {
        
        return @"application/x-sprite";
    }
    else if ([type isEqualToString:@"sdp"]) {
        
        return @"application/sdp";
    }
    else if ([type isEqualToString:@"spt"]) {
        
        return @"application/x-spt";
    }
    else if ([type isEqualToString:@"src"]) {
        
        return @"application/x-wais-source";
    }
    else if ([type isEqualToString:@"stk"]) {
        
        return @"application/hyperstudio";
    }
    else if ([type isEqualToString:@"stm"]) {
        
        return @"audio/x-mod";
    }
    else if ([type isEqualToString:@"sv4cpio"]) {
        
        return @"application/x-sv4cpio";
    }
    else if ([type isEqualToString:@"sv4crc"]) {
        
        return @"application/x-sv4crc";
    }
    else if ([type isEqualToString:@"svf"]) {
        
        return @"image/vnd";
    }
    else if ([type isEqualToString:@"svg"]) {
        
        return @"image/svg-xml";
    }
    else if ([type isEqualToString:@"svh"]) {
        
        return @"image/svh";
    }
    else if ([type isEqualToString:@"svr"]) {
        
        return @"x-world/x-svr";
    }
    else if ([type isEqualToString:@"swf"]) {
        
        return @"application/x-shockwave-flash";
    }
    else if ([type isEqualToString:@"swfl"]) {
        
        return @"application/x-shockwave-flash";
    }
    else if ([type isEqualToString:@"t"]) {
        
        return @"application/x-troff";
    }
    else if ([type isEqualToString:@"tad"]) {
        
        return @"application/octet-stream";
    }
    else if ([type isEqualToString:@"talk"]) {
        
        return @"text/x-speech";
    }
    else if ([type isEqualToString:@"tar"]) {
        
        return @"application/x-tar";
    }
    else if ([type isEqualToString:@"taz"]) {
        
        return @"application/x-tar";
    }
    else if ([type isEqualToString:@"tbp"]) {
        
        return @"application/x-timbuktu";
    }
    else if ([type isEqualToString:@"tbt"]) {
        
        return @"application/x-timbuktu";
    }
    else if ([type isEqualToString:@"tcl"]) {
        
        return @"application/x-tcl";
    }
    else if ([type isEqualToString:@"tex"]) {
        
        return @"application/x-tex";
    }
    else if ([type isEqualToString:@"texi"]) {
        
        return @"application/x-texinfo";
    }
    else if ([type isEqualToString:@"texinfo"]) {
        
        return @"application/x-texinfo";
    }
    else if ([type isEqualToString:@"tgz"]) {
        
        return @"application/x-tar";
    }
    else if ([type isEqualToString:@"thm"]) {
        
        return @"application/vnd.eri.thm";
    }
    else if ([type isEqualToString:@"tif"]) {
        
        return @"image/tiff";
    }
    else if ([type isEqualToString:@"tiff"]) {
        
        return @"image/tiff";
    }
    else if ([type isEqualToString:@"tki"]) {
        
        return @"application/x-tkined";
    }
    else if ([type isEqualToString:@"tkined"]) {
        
        return @"application/x-tkined";
    }
    else if ([type isEqualToString:@"toc"]) {
        
        return @"application/toc";
    }
    else if ([type isEqualToString:@"toy"]) {
        
        return @"image/toy";
    }
    else if ([type isEqualToString:@"tr"]) {
        
        return @"application/x-troff";
    }
    else if ([type isEqualToString:@"trk"]) {
        
        return @"x-lml/x-gps";
    }
    else if ([type isEqualToString:@"trm"]) {
        
        return @"application/x-msterminal";
    }
    else if ([type isEqualToString:@"tsi"]) {
        
        return @"audio/tsplayer";
    }
    else if ([type isEqualToString:@"tsp"]) {
        
        return @"application/dsptype";
    }
    else if ([type isEqualToString:@"tsv"]) {
        
        return @"text/tab-separated-values";
    }
    else if ([type isEqualToString:@"ttf"]) {
        
        return @"application/octet-stream";
    }
    else if ([type isEqualToString:@"ttz"]) {
        
        return @"application/t-time";
    }
    else if ([type isEqualToString:@"txt"]) {
        
        return @"text/plain";
    }
    else if ([type isEqualToString:@"ult"]) {
        
        return @"audio/x-mod";
    }
    else if ([type isEqualToString:@"ustar"]) {
        
        return @"application/x-ustar";
    }
    else if ([type isEqualToString:@"uu"]) {
        
        return @"application/x-uuencode";
    }
    else if ([type isEqualToString:@"uue"]) {
        
        return @"application/x-uuencode";
    }
    else if ([type isEqualToString:@"vcd"]) {
        
        return @"application/x-cdlink";
    }
    else if ([type isEqualToString:@"vcf"]) {
        
        return @"text/x-vcard";
    }
    else if ([type isEqualToString:@"vdo"]) {
        
        return @"video/vdo";
    }
    else if ([type isEqualToString:@"vib"]) {
        
        return @"audio/vib";
    }
    else if ([type isEqualToString:@"viv"]) {
        
        return @"video/vivo";
    }
    else if ([type isEqualToString:@"vivo"]) {
        
        return @"video/vivo";
    }
    else if ([type isEqualToString:@"vmd"]) {
        
        return @"application/vocaltec-media-desc";
    }
    else if ([type isEqualToString:@"vmf"]) {
        
        return @"application/vocaltec-media-file";
    }
    else if ([type isEqualToString:@"vmi"]) {
        
        return @"application/x-dreamcast-vms-info";
    }
    else if ([type isEqualToString:@"vms"]) {
        
        return @"application/x-dreamcast-vms";
    }
    else if ([type isEqualToString:@"vox"]) {
        
        return @"audio/voxware";
    }
    else if ([type isEqualToString:@"vqe"]) {
        
        return @"audio/x-twinvq-plugin";
    }
    else if ([type isEqualToString:@"vqf"]) {
        
        return @"audio/x-twinvq";
    }
    else if ([type isEqualToString:@"vql"]) {
        
        return @"audio/x-twinvq";
    }
    else if ([type isEqualToString:@"vre"]) {
        
        return @"x-world/x-vream";
    }
    else if ([type isEqualToString:@"vrml"]) {
        
        return @"x-world/x-vrml";
    }
    else if ([type isEqualToString:@"vrt"]) {
        
        return @"x-world/x-vrt";
    }
    else if ([type isEqualToString:@"vrw"]) {
        
        return @"x-world/x-vream";
    }
    else if ([type isEqualToString:@"vts"]) {
        
        return @"workbook/formulaone";
    }
    else if ([type isEqualToString:@"wax"]) {
        
        return @"audio/x-ms-wax";
    }
    else if ([type isEqualToString:@"wbmp"]) {
        
        return @"image/vnd.wap.wbmp";
    }
    else if ([type isEqualToString:@"web"]) {
        
        return @"application/vnd.xara";
    }
    else if ([type isEqualToString:@"wav"]) {
        
        return @"audio/x-wav";
    }
    else if ([type isEqualToString:@"wma"]) {
        
        return @"audio/x-ms-wma";
    }
    else if ([type isEqualToString:@"wmv"]) {
        
        return @"audio/x-ms-wmv";
    }
    else if ([type isEqualToString:@"wi"]) {
        
        return @"image/wavelet";
    }
    else if ([type isEqualToString:@"wis"]) {
        
        return @"application/x-InstallShield";
    }
    else if ([type isEqualToString:@"wm"]) {
        
        return @"video/x-ms-wm";
    }
    else if ([type isEqualToString:@"wmd"]) {
        
        return @"application/x-ms-wmd";
    }
    else if ([type isEqualToString:@"wmf"]) {
        
        return @"application/x-msmetafile";
    }
    else if ([type isEqualToString:@"wml"]) {
        
        return @"text/vnd.wap.wml";
    }
    else if ([type isEqualToString:@"wmlc"]) {
        
        return @"application/vnd.wap.wmlc";
    }
    else if ([type isEqualToString:@"wmls"]) {
        
        return @"text/vnd.wap.wmlscript";
    }
    else if ([type isEqualToString:@"wmlsc"]) {
        
        return @"application/vnd.wap.wmlscriptc";
    }
    else if ([type isEqualToString:@"wmlscript"]) {
        
        return @"text/vnd.wap.wmlscript";
    }
    else if ([type isEqualToString:@"wmv"]) {
        
        return @"video/x-ms-wmv";
    }
    else if ([type isEqualToString:@"wmx"]) {
        
        return @"video/x-ms-wmx";
    }
    else if ([type isEqualToString:@"wmz"]) {
        
        return @"application/x-ms-wmz";
    }
    else if ([type isEqualToString:@"wpng"]) {
        
        return @"image/x-up-wpng";
    }
    else if ([type isEqualToString:@"wps"]) {
        
        return @"application/vnd.ms-works";
    }
    else if ([type isEqualToString:@"wpt"]) {
        
        return @"x-lml/x-gps";
    }
    else if ([type isEqualToString:@"wri"]) {
        
        return @"application/x-mswrite";
    }
    else if ([type isEqualToString:@"wrl"]) {
        
        return @"x-world/x-vrml";
    }
    else if ([type isEqualToString:@"wrz"]) {
        
        return @"x-world/x-vrml";
    }
    else if ([type isEqualToString:@"ws"]) {
        
        return @"text/vnd.wap.wmlscript";
    }
    else if ([type isEqualToString:@"wsc"]) {
        
        return @"application/vnd.wap.wmlscriptc";
    }
    else if ([type isEqualToString:@"wv"]) {
        
        return @"video/wavelet";
    }
    else if ([type isEqualToString:@"wvx"]) {
        
        return @"video/x-ms-wvx";
    }
    else if ([type isEqualToString:@"wxl"]) {
        
        return @"application/x-wxl";
    }
    else if ([type isEqualToString:@"x-gzip"]) {
        
        return @"application/x-gzip";
    }
    else if ([type isEqualToString:@"xar"]) {
        
        return @"application/vnd.xara";
    }
    else if ([type isEqualToString:@"xbm"]) {
        
        return @"image/x-xbitmap";
    }
    else if ([type isEqualToString:@"xdm"]) {
        
        return @"application/x-xdma";
    }
    else if ([type isEqualToString:@"xdma"]) {
        
        return @"application/x-xdma";
    }
    else if ([type isEqualToString:@"xdw"]) {
        
        return @"application/vnd.fujixerox.docuworks";
    }
    else if ([type isEqualToString:@"xht"]) {
        
        return @"application/xhtml+xml";
    }
    else if ([type isEqualToString:@"xhtm"]) {
        
        return @"application/xhtml+xml";
    }
    else if ([type isEqualToString:@"xhtml"]) {
        
        return @"application/xhtml+xml";
    }
    else if ([type isEqualToString:@"xla"]) {
        
        return @"application/vnd.ms-excel";
    }
    else if ([type isEqualToString:@"xlc"]) {
        
        return @"application/vnd.ms-excel";
    }
    else if ([type isEqualToString:@"xll"]) {
        
        return @"application/x-excel";
    }
    else if ([type isEqualToString:@"xlm"]) {
        
        return @"application/vnd.ms-excel";
    }
    else if ([type isEqualToString:@"xls"]) {
        
        return @"application/vnd.ms-excel";
    }
    else if ([type isEqualToString:@"xlsx"]) {
        
        return @"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    }
    else if ([type isEqualToString:@"xlt"]) {
        
        return @"application/vnd.ms-excel";
    }
    else if ([type isEqualToString:@"xlw"]) {
        
        return @"application/vnd.ms-excel";
    }
    else if ([type isEqualToString:@"xm"]) {
        
        return @"audio/x-mod";
    }
    else if ([type isEqualToString:@"xml"]) {
        
        return @"text/xml";
    }
    else if ([type isEqualToString:@"xmz"]) {
        
        return @"audio/x-mod";
    }
    else if ([type isEqualToString:@"xpi"]) {
        
        return @"application/x-xpinstall";
    }
    else if ([type isEqualToString:@"xpm"]) {
        
        return @"image/x-xpixmap";
    }
    else if ([type isEqualToString:@"xsit"]) {
        
        return @"text/xml";
    }
    else if ([type isEqualToString:@"xsl"]) {
        
        return @"text/xml";
    }
    else if ([type isEqualToString:@"xul"]) {
        
        return @"text/xul";
    }
    else if ([type isEqualToString:@"xwd"]) {
        
        return @"image/x-xwindowdump";
    }
    else if ([type isEqualToString:@"xyz"]) {
        
        return @"chemical/x-pdb";
    }
    else if ([type isEqualToString:@"yz1"]) {
        
        return @"application/x-yz1";
    }
    else if ([type isEqualToString:@"z"]) {
        
        return @"application/x-compress";
    }
    else if ([type isEqualToString:@"zac"]) {
        
        return @"application/x-zaurus-zac";
    }
    else if ([type isEqualToString:@"zip"]) {
        
        return @"application/zip";
    }
    else {
        
        return @"*/*";
    }
}

@end

// ********************  Spare *********************
/*
 *  AWSCognitoCredentialsProvider *credentialsProvider = [[AWSCognitoCredentialsProvider alloc]initWithRegionType:AWSRegionUSEast1 identityPoolId:@"us-east-1:cdc0bac2-5588-4982-b5d4-296d8cc3ac80" unauthRoleArn:@"arn:aws:iam::919886360521:role/Cognito_dten_appUnauth_Role" authRoleArn:@"arn:aws:iam::919886360521:role/Cognito_dten_appAuth_Role" identityProviderManager:pool];//[[AWSCognitoCredentialsProvider alloc] initWithRegionType:AWSRegionUSEast1 identityPoolId:@"us-east-1:cdc0bac2-5588-4982-b5d4-296d8cc3ac80" identityProviderManager:pool];
*/
