//
//  XMPhotoCollectionViewController.h
//  XMPhotos
//
//  Created by mifit on 15/11/14.
//  Copyright © 2015年 mifit. All rights reserved.
//

#import <UIKit/UIKit.h>
/// 相册cell点击响应block
typedef void (^PhotoSelectedBlock)(UIImage *image,NSInteger index);
typedef void (^PhotoesSelectedBlock)(NSArray *images);


/**
 *  图片选择类
 *               
 */
@interface XMPhotoCollectionViewController : UICollectionViewController
@property (nonatomic,assign) NSInteger selectCount;//允许选择的个数,默认-1，不限
@property (nonatomic,assign) NSInteger numPerLine;// 每行cell的个数，默认3个
@property (nonatomic,assign) CGFloat proportion;// cell的宽高比,默认1：1

/// 单选回调,与多选同时只能有一个。
- (void)setSelectedPhotoBlock:(PhotoSelectedBlock)block;

/// 多选回调,与单选同时只能有一个。
- (void)setSelectedPhotoesBlock:(PhotoesSelectedBlock)block;
@end
