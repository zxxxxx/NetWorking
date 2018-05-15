//
//  ACMediaModel.h
//  ACMediaFrame
//
//  Created by caoyq on 16/12/25.
//  Copyright © 2016年 ArthurCao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>

@interface ACMediaModel : NSObject

/** 媒体名字 */
@property (nonatomic, copy) NSString *name;

/** 媒体上传格式 图片是NSData，视频主要是路径名，也有NSData */
@property (nonatomic, strong) id uploadType;

//兼容 MWPhotoBrowser 的附加属性

/** 媒体照片 */
@property (nonatomic, strong) UIImage *image;

@property (nonatomic, copy) NSString  *imageUrl;

/** iOS8 之后的媒体属性 */
@property (nonatomic, strong) PHAsset *asset;

/** 是否属于可播放的视频类型 */
@property (nonatomic, assign) BOOL isVideo;

/** 视频的URL */
@property (nonatomic, strong) NSURL *mediaURL;

@property (nonatomic, copy) NSString *sandBoxFilePath;

@property (nonatomic, copy) NSString *videoFileName;

@property (nonatomic, copy) NSString * cover; //封面

@property (nonatomic, copy) NSString * mp4_url; //远程播放链接

@property (nonatomic, copy) NSString * mp3_url; //远程音频链接

@end
