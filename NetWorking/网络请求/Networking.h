//
//  Networking.h
//  MobileTYCJ
//
//  Created by Mac on 16/5/23.
//  Copyright © 2016年 ZXX. All rights reserved.
//

#ifndef Networking_h
#define Networking_h

//对AFNetworking3.0进行封装

#import "AFNetworking.h"
#import "NetworkingManager.h"
#import "CLImageModel.h"
#import "NSString+tools.h"

//重写NSLog,Debug模式下打印日志和当前行数
#ifdef DEBUG
#define NetworkLog(s, ... ) NSLog( @"[%@ line:%d]=> %@", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )
#else
#define NetworkLog(s, ... )
#endif

// 网络缓存NSUserDefaults
#define CacheDefaults [NSUserDefaults standardUserDefaults]

// 网络缓存文件夹名
#define NetworkCache @"NetworkCache"

#define ErrorNotReachable @"网络不给力"

#endif /* Networking_h */
