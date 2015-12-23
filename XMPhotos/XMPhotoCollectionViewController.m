//
//  XMPhotoCollectionViewController.m
//  XMPhotos
//
//  Created by mifit on 15/11/14.
//  Copyright © 2015年 mifit. All rights reserved.
//

#import "XMPhotoCollectionViewController.h"
#import "XMPhotosCollectionViewCell.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>

@implementation UICollectionView (Convenience)
- (NSArray *)aapl_indexPathsForElementsInRect:(CGRect)rect {
    NSArray *allLayoutAttributes = [self.collectionViewLayout layoutAttributesForElementsInRect:rect];
    if (allLayoutAttributes.count == 0) { return nil; }
    NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:allLayoutAttributes.count];
    for (UICollectionViewLayoutAttributes *layoutAttributes in allLayoutAttributes) {
        NSIndexPath *indexPath = layoutAttributes.indexPath;
        [indexPaths addObject:indexPath];
    }
    return indexPaths;
}
@end

@interface XMPhotoCollectionViewController ()<PHPhotoLibraryChangeObserver>{
    ALAssetsLibrary *_assetsLibrary;
    
    PHAssetCollection *_assetCollection;
    PHFetchResult *_albums;
    PHCachingImageManager *_imageManager;
}
/// ios9前使用略缩图
@property (nonatomic,strong) NSMutableArray *arrThumbnail;
/// ios9前使用原图
@property (nonatomic,strong) NSMutableArray *arrOrg;
/// 多选时候的图片引所
@property (nonatomic,strong) NSMutableArray *selImages;
@property (nonatomic,strong) NSMutableArray *selIndex;

@property (nonatomic,copy) PhotoSelectedBlock blockPhoto;
@property (nonatomic,copy) PhotoesSelectedBlock blockPhotoes;
/// 是否多选
@property (nonatomic,assign) BOOL isMutableSelected;
@property CGRect previousPreheatRect;

@property (nonatomic,strong) UIButton *sureBtn;
@property (nonatomic,strong) UIButton *cancelBtn;
@end

@implementation XMPhotoCollectionViewController
static CGSize AssetGridThumbnailSize;
static NSString * const reuseIdentifier = @"XMPhotosCollectionViewCell";

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    _arrThumbnail = [NSMutableArray array];
    _arrOrg = [NSMutableArray array];
    if (_selectCount <=0 ) {
        _selectCount = -1;
    }
    if (_numPerLine <= 0) {
        _numPerLine = 3;
    }
    if (_proportion <= 0) {
        _proportion = 1.0f;
    }
    [self initBtn];
    [self imageFromAssert];
}

- (void)viewWillAppear:(BOOL)animated{
    if ([[UIDevice currentDevice].systemVersion floatValue] > 8.6) {
        CGFloat scale = [UIScreen mainScreen].scale;
        CGSize cellSize = ((UICollectionViewFlowLayout *)self.collectionViewLayout).itemSize;
        AssetGridThumbnailSize = CGSizeMake(cellSize.width * scale, cellSize.height * scale);
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([[UIDevice currentDevice].systemVersion floatValue] > 8.6) {
        [self updateCachedAssets];
    }
}

- (void)dealloc {
    if ([[UIDevice currentDevice].systemVersion floatValue] > 8.6) {
        [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
    }
    _arrOrg = nil;
    _arrThumbnail = nil;
    _selIndex = nil;
    _selImages = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)initBtn{
    if (self.isMutableSelected) {
        _selImages = [NSMutableArray array];
        _selIndex = [NSMutableArray array];
        CGFloat btnH = 40;
        CGFloat space = 10;
        CGRect rect = self.view.frame;
        UIButton *btn1 = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn1 setTitle:@"确定" forState:UIControlStateNormal];
        [btn1 setTitleColor:[UIColor colorWithRed:41/255.0 green:134/255.0 blue:229/255.0 alpha:1] forState:UIControlStateNormal];
        [btn1 setBackgroundImage:[UIImage imageNamed:@"xm_photoBtnBG"] forState:UIControlStateNormal];
        [btn1 setImage:[UIImage imageNamed:@"xm_sureIconN"] forState:UIControlStateNormal];
        [btn1 addTarget:self action:@selector(sureBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
        rect.origin.y = rect.size.height - btnH - space;
        rect.origin.x = space;
        rect.size.height = btnH;rect.size.width = 96;
        btn1.frame = rect;
        [self.view addSubview:btn1];
        _sureBtn = btn1;
        
        UIButton *btn2 = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn2 setTitle:@"取消" forState:UIControlStateNormal];
        [btn2 setTitleColor:[UIColor colorWithRed:41/255.0 green:134/255.0 blue:229/255.0 alpha:1] forState:UIControlStateNormal];
        [btn2 setBackgroundImage:[UIImage imageNamed:@"xm_photoBtnBG"] forState:UIControlStateNormal];
        [btn2 setImage:[UIImage imageNamed:@"xm_cancelIconN"] forState:UIControlStateNormal];
        [btn2 addTarget:self action:@selector(cancelBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
        rect.origin.x = self.view.frame.size.width - rect.size.width - space;
        btn2.frame = rect;
        [self.view addSubview:btn2];
        _cancelBtn = btn2;
    }
}

- (void)sureBtnClicked:(id)sender{
    if (self.blockPhotoes) {
        for (NSNumber *index in self.selIndex) {
            if ([[UIDevice currentDevice].systemVersion floatValue] < 8.6) {
                [self selectedImage:[index intValue]];
            }
            if ([[UIDevice currentDevice].systemVersion floatValue] > 8.6) {
                [self PHImage:[index intValue]];
            }
        }
    }
}

- (void)cancelBtnClicked:(id)sender{
    [self.selImages removeAllObjects];
    [self.selIndex removeAllObjects];
    [self.collectionView reloadData];
}

- (void)setSelectedPhotoBlock:(PhotoSelectedBlock)block{
    self.blockPhoto = block;
    self.isMutableSelected = NO;
    self.blockPhotoes = nil;
}

- (void)setSelectedPhotoesBlock:(PhotoesSelectedBlock)block{
    self.blockPhotoes = block;
    self.isMutableSelected = YES;
    self.blockPhoto = nil;
}

- (void)delayDismiss:(NSInteger)delay{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.navigationController popViewControllerAnimated:YES];
    });
}

- (void)imageFromAssert{
    if ([[UIDevice currentDevice].systemVersion floatValue] < 8.6) {
        _assetsLibrary = [[ALAssetsLibrary alloc] init];
        [_assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
            if (group) {
                [group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                    if (result) {
                        UIImage *image = [UIImage imageWithCGImage:[result aspectRatioThumbnail]];
                        NSString *url = [NSString stringWithFormat:@"%@", [[result defaultRepresentation] url]];
                        [self.arrThumbnail addObject:image];
                        [self.arrOrg addObject:url];
                        [self.collectionView reloadData];
                    }
                }];
            }
        } failureBlock:^(NSError *error) {
            NSLog(@"---Group not found!\n");
        }];
    }
    
    //ios9以上
    if ([[UIDevice currentDevice].systemVersion floatValue] > 8.6) {
        PHFetchOptions *options = [[PHFetchOptions alloc] init];
        /// 按创建日期排序
        options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];
        _albums = [PHAsset fetchAssetsWithOptions:options];
        NSLog(@"images count:%ld",(long)_albums.count);
        [[PHPhotoLibrary sharedPhotoLibrary]registerChangeObserver:self];
        _imageManager = [[PHCachingImageManager alloc] init];
        [_imageManager stopCachingImagesForAllAssets];
    }
}

- (void)updateCachedAssets {
    BOOL isViewVisible = [self isViewLoaded] && [[self view] window] != nil;
    if (!isViewVisible) { return; }
    
    // The preheat window is twice the height of the visible rect
    CGRect preheatRect = self.collectionView.bounds;
    preheatRect = CGRectInset(preheatRect, 0.0f, -0.5f * CGRectGetHeight(preheatRect));
    
    // If scrolled by a "reasonable" amount...
    CGFloat delta = ABS(CGRectGetMidY(preheatRect) - CGRectGetMidY(self.previousPreheatRect));
    if (delta > CGRectGetHeight(self.collectionView.bounds) / 3.0f) {
        
        // Compute the assets to start caching and to stop caching.
        NSMutableArray *addedIndexPaths = [NSMutableArray array];
        NSMutableArray *removedIndexPaths = [NSMutableArray array];
        
        [self computeDifferenceBetweenRect:self.previousPreheatRect andRect:preheatRect removedHandler:^(CGRect removedRect) {
            NSArray *indexPaths = [self.collectionView aapl_indexPathsForElementsInRect:removedRect];
            [removedIndexPaths addObjectsFromArray:indexPaths];
        } addedHandler:^(CGRect addedRect) {
            NSArray *indexPaths = [self.collectionView aapl_indexPathsForElementsInRect:addedRect];
            [addedIndexPaths addObjectsFromArray:indexPaths];
        }];
        
        NSArray *assetsToStartCaching = [self assetsAtIndexPaths:addedIndexPaths];
        NSArray *assetsToStopCaching = [self assetsAtIndexPaths:removedIndexPaths];
        
        [_imageManager startCachingImagesForAssets:assetsToStartCaching
                                        targetSize:AssetGridThumbnailSize
                                       contentMode:PHImageContentModeAspectFill
                                           options:nil];
        [_imageManager stopCachingImagesForAssets:assetsToStopCaching
                                       targetSize:AssetGridThumbnailSize
                                      contentMode:PHImageContentModeAspectFill
                                          options:nil];
        
        self.previousPreheatRect = preheatRect;
    }
}

- (void)computeDifferenceBetweenRect:(CGRect)oldRect andRect:(CGRect)newRect removedHandler:(void (^)(CGRect removedRect))removedHandler addedHandler:(void (^)(CGRect addedRect))addedHandler
{
    if (CGRectIntersectsRect(newRect, oldRect)) {
        CGFloat oldMaxY = CGRectGetMaxY(oldRect);
        CGFloat oldMinY = CGRectGetMinY(oldRect);
        CGFloat newMaxY = CGRectGetMaxY(newRect);
        CGFloat newMinY = CGRectGetMinY(newRect);
        if (newMaxY > oldMaxY) {
            CGRect rectToAdd = CGRectMake(newRect.origin.x, oldMaxY, newRect.size.width, (newMaxY - oldMaxY));
            addedHandler(rectToAdd);
        }
        if (oldMinY > newMinY) {
            CGRect rectToAdd = CGRectMake(newRect.origin.x, newMinY, newRect.size.width, (oldMinY - newMinY));
            addedHandler(rectToAdd);
        }
        if (newMaxY < oldMaxY) {
            CGRect rectToRemove = CGRectMake(newRect.origin.x, newMaxY, newRect.size.width, (oldMaxY - newMaxY));
            removedHandler(rectToRemove);
        }
        if (oldMinY < newMinY) {
            CGRect rectToRemove = CGRectMake(newRect.origin.x, oldMinY, newRect.size.width, (newMinY - oldMinY));
            removedHandler(rectToRemove);
        }
    } else {
        addedHandler(newRect);
        removedHandler(oldRect);
    }
}

- (NSArray *)assetsAtIndexPaths:(NSArray *)indexPaths {
    if (indexPaths.count == 0) { return nil; }
    
    NSMutableArray *assets = [NSMutableArray arrayWithCapacity:indexPaths.count];
    for (NSIndexPath *indexPath in indexPaths) {
        PHAsset *asset = _albums[indexPath.item];
        [assets addObject:asset];
    }
    return assets;
}

- (void)selectedImage:(NSInteger)index{
    ALAssetsLibrary *assetLibrary = [[ALAssetsLibrary alloc] init];
    NSURL *url = [NSURL URLWithString:[self.arrOrg objectAtIndex:index]];
    [assetLibrary assetForURL:url resultBlock:^(ALAsset *asset)  {
        if ([[asset valueForProperty:ALAssetPropertyType] isEqualToString:ALAssetTypePhoto]) {
            CGImageRef ref = [[asset defaultRepresentation] fullScreenImage];
            UIImage *image = [[UIImage alloc] initWithCGImage:ref];
            if (self.isMutableSelected) {
                [self.selImages addObject:image];
                if (self.selIndex.count == self.selImages.count) {
                    [self delayDismiss:0.5];
                    self.blockPhotoes(self.selImages);
                }
            }
            if (self.blockPhoto) {
                [self delayDismiss:0.5];
                self.blockPhoto(image,index);
            }
        }
    }failureBlock:^(NSError *error) {
        NSLog(@"error=%@",error);
    }];
}

- (void)PHImage:(NSInteger)index{
    PHAsset *asset = _albums[index];
    [_imageManager requestImageForAsset:asset
                             targetSize:AssetGridThumbnailSize
                            contentMode:PHImageContentModeAspectFill
                                options:nil
                          resultHandler:^(UIImage *result, NSDictionary *info) {
                              [self.selImages addObject:result];
                              if (self.selIndex.count == self.selImages.count) {
                                  [self delayDismiss:0.5];
                                  self.blockPhotoes(self.selImages);
                              }
                          }];
}

- (void)photoLibraryDidChange:(PHChange *)changeInstance{
    
}
#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if ([[UIDevice currentDevice].systemVersion floatValue] > 8.6) {
        [self updateCachedAssets];
    }
}

#pragma mark <UICollectionViewDataSource>

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if ([[UIDevice currentDevice].systemVersion floatValue] > 8.6) {
        return _albums.count;
    }
    return self.arrThumbnail.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    XMPhotosCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"XMPhotosCollectionViewCell" forIndexPath:indexPath];
    if ([[UIDevice currentDevice].systemVersion floatValue] > 8.6) {
        NSInteger currentTag = cell.tag + 1;
        cell.tag = currentTag;
        PHAsset *asset = _albums[indexPath.item];
        [_imageManager requestImageForAsset:asset
                                 targetSize:AssetGridThumbnailSize
                                contentMode:PHImageContentModeAspectFill
                                    options:nil
                              resultHandler:^(UIImage *result, NSDictionary *info) {
                                  // Only update the thumbnail if the cell tag hasn't changed. Otherwise, the cell has been re-used.
                                  if (cell.tag == currentTag) {
                                      cell.imageView.image = result;
                                  }
                              }];
    }
    if ([[UIDevice currentDevice].systemVersion floatValue] < 8.6) {
        cell.imageView.image = [self.arrThumbnail objectAtIndex:indexPath.row];
    }
    if ([self.selIndex containsObject:@(indexPath.row)]) {
        cell.selBtn.selected = YES;
        NSLog(@"++");
    } else {
        cell.selBtn.selected = NO;
        NSLog(@"--");
    }
    //cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
    return cell;
}

#pragma mark <UICollectionViewDelegate>
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath{
    CGSize size = collectionView.frame.size;
    size.width = (size.width - 4) / self.numPerLine;
    size.height = size.width / self.proportion;
    return size;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    if ([[UIDevice currentDevice].systemVersion floatValue] < 8.6) {
        if (self.isMutableSelected) {
            XMPhotosCollectionViewCell *cell = (XMPhotosCollectionViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
            if (self.selectCount < 0 || (self.selectCount > self.selIndex.count)) {
                cell.selBtn.selected = !cell.selBtn.selected;
                if (cell.selBtn.selected == YES) {
                    [self.selIndex addObject:@(indexPath.row)];
                } else {
                    [self.selIndex removeObject:@(indexPath.row)];
                }
            } else {
                if (cell.selBtn.selected == YES) {
                    cell.selBtn.selected = !cell.selBtn.selected;
                    [self.selIndex removeObject:@(indexPath.row)];
                }
            }
        }
        if (self.blockPhoto) {
            [self selectedImage:indexPath.row];
        }
    }
    if ([[UIDevice currentDevice].systemVersion floatValue] > 8.6) {
        XMPhotosCollectionViewCell *cell = (XMPhotosCollectionViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
        if (self.isMutableSelected) {
            if (self.selectCount < 0 || (self.selectCount > self.selIndex.count)) {
                cell.selBtn.selected = !cell.selBtn.selected;
                if (cell.selBtn.selected == YES) {
                    [self.selIndex addObject:@(indexPath.row)];
                } else {
                    [self.selIndex removeObject:@(indexPath.row)];
                }
            } else {
                if (cell.selBtn.selected == YES) {
                    cell.selBtn.selected = !cell.selBtn.selected;
                    [self.selIndex removeObject:@(indexPath.row)];
                }
            }
        }
        if (self.blockPhoto) {
            [self delayDismiss:0.5];
            self.blockPhoto(cell.imageView.image,indexPath.row);
        }
    }
}
@end
