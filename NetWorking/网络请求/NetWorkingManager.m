//
//  NetWorkingManager.m
//  MobileTYCJ
//
//  Created by Mac on 16/5/23.
//  Copyright © 2016年 ZXX. All rights reserved.
//

#import "NetWorkingManager.h"
#import "NSString+cache.h"
#import "ACMediaModel.h"


typedef NS_ENUM(NSInteger, NetworkRequestType) {
    NetworkRequestTypeGET,  // GET请求
    NetworkRequestTypePOST,  // POST请求
};

#define timeout 30
// 网络状态，初始值-1：未知网络状态
static NSInteger networkStatus = -1;

// 缓存路径
static inline NSString *cachePath() {
    return [NSString cachesPathString];
}

@interface NetWorkingManager ()

@property (nonatomic,strong) AFHTTPSessionManager *manager;

@end

@implementation NetWorkingManager


#pragma mark -- 单例 --
+ (NetWorkingManager *)sharedManager{
    
    static NetWorkingManager *sharedManagerInstance = nil;
    static dispatch_once_t predicate;
    
    dispatch_once(&predicate, ^{
        
        sharedManagerInstance = [[self alloc] init];
        
    });
    
    return sharedManagerInstance;
}

#pragma mark -- 网络判断 --
- (void)checkNetworkLinkStatus{

    //1.创建网络状态监测管理者
    AFNetworkReachabilityManager *reachability = [AFNetworkReachabilityManager sharedManager];
    //2.监听改变
    [reachability setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        /*
         AFNetworkReachabilityStatusUnknown          = -1,
         AFNetworkReachabilityStatusNotReachable     = 0,
         AFNetworkReachabilityStatusReachableViaWWAN = 1,
         AFNetworkReachabilityStatusReachableViaWiFi = 2,
         */
        networkStatus = status;
        switch (status) {
            case AFNetworkReachabilityStatusUnknown:
            NetworkLog(@"未知");
            break;
            case AFNetworkReachabilityStatusNotReachable:
            NetworkLog(@"没有网络");
            break;
            case AFNetworkReachabilityStatusReachableViaWWAN:
            NetworkLog(@"3G|4G");
            break;
            case AFNetworkReachabilityStatusReachableViaWiFi:
            NetworkLog(@"WiFi");
            break;
            default:
            break;
        }
    }];
    [reachability startMonitoring];
}



- (NSInteger)theNetworkStatus{
    // 调用完checkNetworkLinkStatus,才可以调用此方法
    return networkStatus;
}

#pragma mark -- GET请求 --
- (void)getNetworkRequestWithUrlString:(NSString *)urlString parameters:(id)parameters isCache:(BOOL)isCache succeed:(void(^)(id data))succeed fail:(void(^)(NSString *error))fail{
    
    [self requestType:NetworkRequestTypeGET url:urlString parameters:parameters isCache:isCache cacheTime:0.0 succeed:succeed fail:fail];
}

#pragma mark --返回JSON
- (void)getNetworkRequestWithUrlString:(NSString *)urlString parameters:(id)parameters isucceed:(void(^)(id data))succeed fail:(void(^)(NSString *error))fail{
    
    [self requestType:NetworkRequestTypeGET url:urlString parameters:parameters  succeed:succeed fail:fail];
}

#pragma mark -- GET请求 <含缓存时间> --
- (void)getCacheRequestWithUrlString:(NSString *)urlString parameters:(id)parameters cacheTime:(float)time succeed:(void(^)(id data))succeed fail:(void(^)(NSString *error))fail{
    
    [self requestType:NetworkRequestTypeGET url:urlString parameters:parameters isCache:YES cacheTime:time succeed:succeed fail:fail];
}


#pragma mark -- POST请求 --
- (void)postNetworkRequestWithUrlString:(NSString *)urlString parameters:(id)parameters isCache:(BOOL)isCache succeed:(void(^)(id data))succeed fail:(void(^)(NSString *error))fail{
    
    [self requestType:NetworkRequestTypePOST url:urlString parameters:parameters isCache:isCache cacheTime:0.0 succeed:succeed fail:fail];
}

#pragma mark --返回JSON
- (void)postNetworkRequestWithUrlString:(NSString *)urlString parameters:(id)parameters isucceed:(void(^)(id data))succeed fail:(void(^)(NSString *error))fail{
    
    [self requestType:NetworkRequestTypePOST url:urlString parameters:parameters  succeed:succeed fail:fail];
}


#pragma mark -- POST请求 <含缓存时间> --
- (void)postCacheRequestWithUrlString:(NSString *)urlString parameters:(id)parameters cacheTime:(float)time succeed:(void(^)(id data))succeed fail:(void(^)(NSString *error))fail{
    
    [self requestType:NetworkRequestTypePOST url:urlString parameters:parameters isCache:YES cacheTime:time succeed:succeed fail:fail];
}

#pragma mark -- 取消请求
- (void)cancelRequest{
    
    [self.manager.tasks makeObjectsPerformSelector:@selector(cancel)];
    NetworkLog(@"cancel net request");

}

#pragma mark -- 网络请求 --
/**
 *  网络请求
 *
 *  @param type       请求类型，get请求/Post请求
 *  @param urlString  请求地址字符串
 *  @param parameters 请求参数
 *  @param isCache    是否缓存
 *  @param time       缓存时间
 *  @param succeed    请求成功回调
 *  @param fail       请求失败回调
 */
- (void)requestType:(NetworkRequestType)type url:(NSString *)urlString parameters:(id)parameters isCache:(BOOL)isCache cacheTime:(float)time succeed:(void(^)(id data))succeed fail:(void(^)(NSString *error))fail{

    NSString *key = [self cacheKey:urlString params:parameters];
    // 判断网址是否加载过，如果没有加载过 在执行网络请求成功时，将请求时间和网址存入UserDefaults，value为时间date、Key为网址
    if ([CacheDefaults objectForKey:key]) {
        // 如果UserDefaults存过网址，判断本地数据是否存在
        id cacheData = [self cahceResponseWithURL:urlString parameters:parameters];
        if (cacheData) {
            // 如果本地数据存在，读取本地数据，解析并返回给首页
            id dict = [NSJSONSerialization JSONObjectWithData:cacheData options:NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves error:nil];
            if (succeed) {
                succeed(dict);
            }
            // 判断存储时间，如果在规定直接之内，直接return，否则将继续执行网络请求
            if (time) {
                NSDate *oldDate = [CacheDefaults objectForKey:key];
                float cacheTime = [[NSString stringNowTimeDifferenceWith:[NSString stringWithDate:oldDate]] floatValue];
                if (cacheTime < time) {
                    return;
                }
            }
        }
    }else{
        // 判断是否开启缓存
        if (isCache) {
            id cacheData = [self cahceResponseWithURL:urlString parameters:parameters];
            if (cacheData) {
                id dict = [NSJSONSerialization JSONObjectWithData:cacheData options:NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves error:nil];
                if (succeed) {
                    succeed(dict);
                }
            }
        }
    }
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    // 不加上这句话，会报“Request failed: unacceptable content-type: text/plain”错误，因为要获取text/plain类型数据
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    // 二进制请求
//    manager.requestSerializer = [AFHTTPRequestSerializer serializer];
    manager.requestSerializer.timeoutInterval = timeout;
    self.manager = manager;
    
    if (type == NetworkRequestTypeGET) {
        // GET请求
        NetworkLog(@"startRequest--get--url:%@ --parameters:%@",urlString,parameters);
        
        
        
        [self.manager GET:urlString parameters:parameters progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            // 请求成功，加入缓存，解析数据
            
            if (isCache) {
                if (time > 0.0) {
                    [CacheDefaults setObject:[NSDate date] forKey:key];
                }
                [self cacheResponseObject:responseObject urlString:urlString parameters:parameters];
            }
            id dict = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves error:nil];
            
            [self logDic:dict];
            if (succeed) {
                succeed(dict);
            }
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            // 请求失败
            NSString *errorStr = [error localizedDescription];
            errorStr = ([self theNetworkStatus] == 0) ? ErrorNotReachable:errorStr;
            if (fail) {
                fail(errorStr);
            }
        }];
        
        
    }else{
        // POST请求
        NetworkLog(@"startRequest--post--url:%@ --parameters:%@",urlString,parameters);
        
        
       
        [self.manager POST:urlString parameters:parameters progress:^(NSProgress * _Nonnull uploadProgress) {
            // 请求的进度
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            // 请求成功，加入缓存，解析数据
            
            if (isCache) {
                if (time > 0.0) {
                    [CacheDefaults setObject:[NSDate date] forKey:key];
                }
                [self cacheResponseObject:responseObject urlString:urlString parameters:parameters];
            }
            NSString *aString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
            id dict = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves error:nil];
            [self logDic:dict];
//            NSString *str = [self dictionaryToJson:dict];
            if (succeed) {
                succeed(dict);
            }
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            // 请求失败
            
            NSString *errorStr = [error localizedDescription];
            errorStr = ([self theNetworkStatus] == 0) ? ErrorNotReachable:errorStr;
            if (fail) {
                fail(errorStr);
            }
        }];
    }
}

- (void)requestType:(NetworkRequestType)type url:(NSString *)urlString parameters:(id)parameters  succeed:(void(^)(id data))succeed fail:(void(^)(NSString *error))fail{
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    // 不加上这句话，会报“Request failed: unacceptable content-type: text/plain”错误，因为要获取text/plain类型数据
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    manager.requestSerializer.timeoutInterval = timeout;
    self.manager = manager;
    if (type == NetworkRequestTypeGET) {
        // GET请求
        NetworkLog(@"startRequest--get--url:%@ --parameters:%@",urlString,parameters);
        
        [self.manager GET:urlString parameters:parameters progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            // 请求成功，解析数据
//            NSString *aString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
            id dict = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves error:nil];
            
            [self logDic:dict];
            if (succeed) {
                succeed(responseObject);
            }
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            // 请求失败
            NSString *errorStr = [error localizedDescription];
            errorStr = ([self theNetworkStatus] == 0) ? ErrorNotReachable:errorStr;
            if (fail) {
                fail(errorStr);
            }
        }];
        
        
    }else{
        // POST请求
        NetworkLog(@"startRequest--post--url:%@ --parameters:%@",urlString,parameters);
        
        [self.manager POST:urlString parameters:parameters progress:^(NSProgress * _Nonnull uploadProgress) {
            // 请求的进度
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            // 解析数据
            NSString *aString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
            id dict = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves error:nil];
            [self logDic:dict];
            if (succeed) {
                succeed(aString);
            }
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            // 请求失败
            NSString *errorStr = [error localizedDescription];
            errorStr = ([self theNetworkStatus] == 0) ? ErrorNotReachable:errorStr;
            if (fail) {
                fail(errorStr);
            }
        }];
    }
}

#pragma mark -- 调用极光短信接口 --
- (void)postNetworkSendMessageWithUrlString:(NSString *)urlString authorization:(NSString *)authorization parameters:(id)parameters isucceed:(void(^)(id data))succeed fail:(void(^)(NSString *error))fail{
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    // 不加上这句话，会报“Request failed: unacceptable content-type: text/plain”错误，因为要获取text/plain类型数据
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setValue:authorization forHTTPHeaderField:@"Authorization"];
    self.manager = manager;
    
    // POST请求
    NetworkLog(@"startRequest--post--url:%@ --parameters:%@",urlString,parameters);
    
    [self.manager POST:urlString parameters:parameters progress:^(NSProgress * _Nonnull uploadProgress) {
        // 请求的进度
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        // 解析数据
        id dict = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves error:nil];
        [self logDic:dict];

        if (succeed) {
            succeed(dict);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        // 请求失败
        NSString *errorStr = [error localizedDescription];
        errorStr = ([self theNetworkStatus] == 0) ? ErrorNotReachable:errorStr;
        if (fail) {
            fail(errorStr);
        }
    }];
}

#pragma mark -- 上传图片 --
- (void)uploadWithURLString:(NSString *)URLString
                 parameters:(id)parameters
                      model:(CLImageModel *)model
                   progress:(void (^)(float writeKB, float totalKB)) progress
                    succeed:(void (^)(id data))succeed
                       fail:(void (^)(NSString *error))fail{
    
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    
    NetworkLog(@"startRequest--get--url:%@ --parameters:%@",URLString,parameters);
    [manager POST:URLString parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        // 拼接data到请求体，这个block的参数是遵守AFMultipartFormData协议的。
        NSData *imageData = UIImageJPEGRepresentation(model.image, 1);
        NSString *imageFileName = model.imageName;
        if (imageFileName == nil || ![imageFileName isKindOfClass:[NSString class]] || imageFileName.length == 0) {
            // 如果文件名为空，以时间命名文件名
            imageFileName = [NSString imageFileName];
        }
        [formData appendPartWithFileData:imageData name:model.field fileName:imageFileName mimeType:[NSString imageFieldType]];
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        float uploadKB = uploadProgress.completedUnitCount/1024.0;
        float grossKB = uploadProgress.totalUnitCount/1024.0;
        if (progress) {
            progress(uploadKB, grossKB);
        }
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        id dict = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves error:nil];
        [self logDic:dict];
        if (succeed) {
            succeed(dict);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        // 请求失败
       
        NSString *errorStr = [error localizedDescription];
        errorStr = ([self theNetworkStatus] == 0) ? ErrorNotReachable:errorStr;
        if (fail) {
            fail(errorStr);
        }
    }];
}


#pragma mark -- 上传多张图片 --
- (void)uploadWithURLString:(NSString *)URLString
                 parameters:(id)parameters
                 imageArray:(NSArray <ACMediaModel *>*)modelArray
                   progress:(void (^)(float writeKB, float totalKB)) progress
                    succeed:(void (^)(id data))succeed
                       fail:(void (^)(NSString *error))fail{
    
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    
    NetworkLog(@"startRequest--get--url:%@ --parameters:%@",URLString,parameters);
    [manager POST:URLString parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        // 拼接data到请求体，这个block的参数是遵守AFMultipartFormData协议的。
        for (ACMediaModel *model in modelArray) {
            NSData *imageData = UIImageJPEGRepresentation(model.image, 0.7);
            NSString *imageFileName = @"";
            if (imageFileName == nil || ![imageFileName isKindOfClass:[NSString class]] || imageFileName.length == 0) {
                // 如果文件名为空，以时间命名文件名
                imageFileName = [NSString imageFileName];
            }
            [formData appendPartWithFileData:imageData name:@"" fileName:imageFileName mimeType:[NSString imageFieldType]];
        }

    } progress:^(NSProgress * _Nonnull uploadProgress) {
        float uploadKB = uploadProgress.completedUnitCount/1024.0;
        float grossKB = uploadProgress.totalUnitCount/1024.0;
        if (progress) {
            progress(uploadKB, grossKB);
        }
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
       
        id dict = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves error:nil];
        [self logDic:dict];
        if (succeed) {
            succeed(dict);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        // 请求失败
        
        NSString *errorStr = [error localizedDescription];
        errorStr = ([self theNetworkStatus] == 0) ? ErrorNotReachable:errorStr;
        if (fail) {
            fail(errorStr);
        }
    }];
}

#pragma mark -- 上传音频 --
- (void)uploadMp3WithURLString:(NSString *)URLString
                    parameters:(id)parameters
                         model:(CLImageModel *)model
                      progress:(void (^)(float writeKB, float totalKB)) progress
                       succeed:(void (^)(id data))succeed
                          fail:(void (^)(NSString *error))fail
{
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    
    NetworkLog(@"startRequest--get--url:%@ --parameters:%@",URLString,parameters);
    [manager POST:URLString parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        NSString *imageFileName = model.imageName;
        if (imageFileName == nil || ![imageFileName isKindOfClass:[NSString class]] || imageFileName.length == 0) {
            // 如果文件名为空，以时间命名文件名
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"yyyyMMddHHmmss";
            NSString *str = [formatter stringFromDate:[NSDate date]];
            imageFileName = [NSString stringWithFormat:@"%@.mp3", str];;
        }
        [formData appendPartWithFileURL:model.url name:@"" fileName:imageFileName mimeType:@"application/octet-stream" error:nil];;
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        float uploadKB = uploadProgress.completedUnitCount/1024.0;
        float grossKB = uploadProgress.totalUnitCount/1024.0;
        if (progress) {
            progress(uploadKB, grossKB);
        }
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
       
        id dict = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves error:nil];
        [self logDic:dict];
        if (succeed) {
            succeed(dict);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        // 请求失败
        
        NSString *errorStr = [error localizedDescription];
        errorStr = ([self theNetworkStatus] == 0) ? ErrorNotReachable:errorStr;
        if (fail) {
            fail(errorStr);
        }
    }];
}

#pragma mark -- 上传视频 --
- (void)uploadVideoWithURLString:(NSString *)URLString
                      parameters:(id)parameters
                           model:(ACMediaModel *)model
                        progress:(void (^)(float writeKB, float totalKB)) progress
                         succeed:(void (^)(id data))succeed
                            fail:(void (^)(NSString *error))fail{
    
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    
    NetworkLog(@"startRequest--get--url:%@ --parameters:%@",URLString,parameters);
    [manager POST:URLString parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        NSString *imageFileName = model.videoFileName;
        if (imageFileName == nil || ![imageFileName isKindOfClass:[NSString class]] || imageFileName.length == 0) {
            // 如果文件名为空，以时间命名文件名
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"yyyyMMddHHmmss";
            NSString *str = [formatter stringFromDate:[NSDate date]];
            imageFileName = [NSString stringWithFormat:@"%@.mp4", str];;
        }
        NSData *videoData = [NSData dataWithContentsOfFile:model.sandBoxFilePath];

         [formData appendPartWithFileData:videoData name:@"" fileName:model.videoFileName mimeType:@"application/octet-stream"];
        
        NSData *imageData = UIImageJPEGRepresentation(model.image, 0.4);
        NSString *coverFileName = @"";
        if (coverFileName == nil || ![coverFileName isKindOfClass:[NSString class]] || coverFileName.length == 0) {
            // 如果文件名为空，以时间命名文件名
            coverFileName = [NSString imageFileName];
        }
        [formData appendPartWithFileData:imageData name:@"" fileName:coverFileName mimeType:[NSString imageFieldType]];
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        float uploadKB = uploadProgress.completedUnitCount/1024.0;
        float grossKB = uploadProgress.totalUnitCount/1024.0;
        if (progress) {
            progress(uploadKB, grossKB);
        }
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
       
        id dict = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves error:nil];
        [self logDic:dict];
        if (succeed) {
            succeed(dict);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        // 请求失败
       
        NSString *errorStr = [error localizedDescription];
        errorStr = ([self theNetworkStatus] == 0) ? ErrorNotReachable:errorStr;
        if (fail) {
            fail(errorStr);
        }
    }];
}



- (void)soapData:(NSString *)url soapBody:(NSString *)soapBody success:(void (^)(id responseObject))success failure:(void(^)(NSError *error))failure{
    
    NSString *soapStr = [NSString stringWithFormat:
                         @"<?xml version=\"1.0\" encoding=\"utf-8\"?>\
                         <soap:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"\
                         xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">\
                         <soap:Header>\
                         </soap:Header>\
                         <soap:Body>%@</soap:Body>\
                         </soap:Envelope>",soapBody];
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFXMLParserResponseSerializer serializer];
    
    // 设置请求超时时间
    manager.requestSerializer.timeoutInterval = 30;
    
    // 返回NSData
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    
    // 设置请求头，也可以不设置
    [manager.requestSerializer setValue:@"application/soap+xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [manager.requestSerializer setValue:[NSString stringWithFormat:@"%zd", soapStr.length] forHTTPHeaderField:@"Content-Length"];
    
    // 设置HTTPBody
    [manager.requestSerializer setQueryStringSerializationWithBlock:^NSString *(NSURLRequest *request, NSDictionary *parameters, NSError *__autoreleasing *error) {
        return soapStr;
    }];
    
    [manager POST:url parameters:soapStr success:^(NSURLSessionDataTask * _Nonnull task, id  _Nonnull responseObject) {
        // 把返回的二进制数据转为字符串
        NSString *result = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        
        // 利用正则表达式取出<return></return>之间的字符串
        NSRegularExpression *regular = [[NSRegularExpression alloc] initWithPattern:@"(?<=return\\>).*(?=</return)" options:NSRegularExpressionCaseInsensitive error:nil];
        
        NSDictionary *dict = [NSDictionary dictionary];
        for (NSTextCheckingResult *checkingResult in [regular matchesInString:result options:0 range:NSMakeRange(0, result.length)]) {
            
            // 得到字典
            dict = [NSJSONSerialization JSONObjectWithData:[[result substringWithRange:checkingResult.range] dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableLeaves error:nil];
        }
        // 请求成功并且结果有值把结果传出去
        if (success && dict) {
            success(dict);
        }
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if (failure) {
            failure(error);
        }
    }];
}

#pragma mark 获取指定URL的MIMEType类型
- (NSString *)mimeType:(NSURL *)url
{
    //1NSURLRequest
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLResponse *response = nil;
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
    return response.MIMEType;
}


#pragma mark -- 缓存处理 --
/**
 *  缓存文件夹下某地址的文件名，及UserDefaulets中的key值
 *
 *  @param urlString 请求地址
 *  @param params    请求参数
 *
 *  @return 返回一个MD5加密后的字符串
 */
- (NSString *)cacheKey:(NSString *)urlString params:(id)params{
    NSString *absoluteURL = [NSString generateGETAbsoluteURL:urlString params:params];
    NSString *key = [NSString networkingUrlString_md5:absoluteURL];
    return key;
}

/**
 *  读取缓存
 *
 *  @param url    请求地址
 *  @param params 拼接的参数
 *
 *  @return 数据data
 */
- (id)cahceResponseWithURL:(NSString *)url parameters:(id)params {
    id cacheData = nil;
    if (url) {
        // 读取本地缓存
        NSString *key = [self cacheKey:url params:params];
        NSString *path = [cachePath() stringByAppendingPathComponent:key];
        NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
        if (data) {
            cacheData = data;
        }
    }
    return cacheData;
}

/**
 *  添加缓存
 *
 *  @param responseObject 请求成功数据
 *  @param urlString      请求地址
 *  @param params         拼接的参数
 */
- (void)cacheResponseObject:(id)responseObject urlString:(NSString *)urlString parameters:(id)params {
    NSString *key = [self cacheKey:urlString params:params];
    NSString *path = [cachePath() stringByAppendingPathComponent:key];
    [self deleteFileWithPath:path];
    BOOL isOk = [[NSFileManager defaultManager] createFileAtPath:path contents:responseObject attributes:nil];
    if (isOk) {
        NetworkLog(@"cache file success: %@\n", path);
    } else {
        NetworkLog(@"cache file error: %@\n", path);
    }
}

- (NSString *)cacheUrlString:(NSString *)urlString parameters:(id)params {
    NSString *key = [self cacheKey:urlString params:params];
    NSString *path = [cachePath() stringByAppendingPathComponent:key];
    [self deleteFileWithPath:path];
    BOOL isOk = [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
    if (isOk) {
        NetworkLog(@"cache file success: %@\n", path);
        
    } else {
        NetworkLog(@"cache file error: %@\n", path);
    }
    return path;
}

// 清空缓存
- (void)clearCaches {
    // 删除CacheDefaults中的存放时间和地址的键值对，并删除cache文件夹
    NSString *directoryPath = cachePath();
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:directoryPath]){
        NSEnumerator *childFilesEnumerator = [[manager subpathsAtPath:directoryPath] objectEnumerator];
        NSString *key;
        while ((key = [childFilesEnumerator nextObject]) != nil){
            NetworkLog(@"remove_key ==%@",key);
            [CacheDefaults removeObjectForKey:key];
        }
    }
    if ([manager fileExistsAtPath:directoryPath isDirectory:nil]) {
        NSError *error = nil;
        [manager removeItemAtPath:directoryPath error:&error];
        if (error) {
            NetworkLog(@"clear caches error: %@", error);
        } else {
            NetworkLog(@"clear caches success");
        }
    }
}

//单个文件的大小
- (long long)fileSizeAtPath:(NSString*)filePath{
    NSFileManager* manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:filePath]){
        return [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
    }
    return 0;
}

//遍历文件夹获得文件夹大小，返回多少KB
- (float)getCacheFileSize{
    NSString *folderPath = cachePath();
    NSFileManager* manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:folderPath]) return 0;
    NSEnumerator *childFilesEnumerator = [[manager subpathsAtPath:folderPath] objectEnumerator];
    NSString* fileName;
    long long folderSize = 0;
    while ((fileName = [childFilesEnumerator nextObject]) != nil){
        NSString* fileAbsolutePath = [folderPath stringByAppendingPathComponent:fileName];
        folderSize += [self fileSizeAtPath:fileAbsolutePath];
    }
    return folderSize/1024.0;
}

/**
 *  判断文件是否已经存在，若存在删除
 *
 *  @param path 文件路径
 */
- (void)deleteFileWithPath:(NSString *)path
{
    NSURL *url = [NSURL fileURLWithPath:path];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL exist = [fm fileExistsAtPath:url.path];
    NSError *err;
    if (exist) {
        [fm removeItemAtURL:url error:&err];
        NetworkLog(@"file deleted success");
        if (err) {
            NetworkLog(@"file remove error, %@", err.localizedDescription );
        }
    } else {
        NetworkLog(@"no file by that name");
    }
}


#pragma mark -- 打印相关
- (void)logDic:(id)data
{
    if (data == nil || [data isKindOfClass:[NSNull class]]) {
        NSLog(@"dic:%@",data);
    }else{
        NSDictionary *dic = (NSDictionary *)data;
        NSString *tempStr1 = [[dic description] stringByReplacingOccurrencesOfString:@"\\u" withString:@"\\U"];
        NSString *tempStr2 = [tempStr1 stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        NSString *tempStr3 = [[@"\"" stringByAppendingString:tempStr2] stringByAppendingString:@"\""];
        NSData *tempData = [tempStr3 dataUsingEncoding:NSUTF8StringEncoding];
        
        NSString * str = [NSPropertyListSerialization propertyListWithData:tempData options:NSPropertyListImmutable format:NULL error:NULL];
        NSLog(@"dic:%@",str);
    }
}

//字典转为Json字符串
-(NSString *)dictionaryToJson:(NSDictionary *)dic
{
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&error];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

@end
