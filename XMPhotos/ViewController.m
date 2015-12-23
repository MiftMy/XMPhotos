//
//  ViewController.m
//  XMPhotos
//
//  Created by mifit on 15/11/14.
//  Copyright © 2015年 mifit. All rights reserved.
//

#import "ViewController.h"
#import "XMPhotoCollectionViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *IV;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    //延迟执行·
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)show:(id)sender {
    XMPhotoCollectionViewController *pushVC = [[UIStoryboard storyboardWithName:@"XMPhotos" bundle:nil]instantiateViewControllerWithIdentifier:@"XMPhotoCollectionViewController"];
    pushVC.numPerLine = 4;
    pushVC.selectCount = 5;
    [pushVC setSelectedPhotoesBlock:^(NSArray *images) {
        for (UIImage *i in images) {
            NSLog(@"%@",i);
        }
    }];
    [self.navigationController pushViewController:pushVC animated:YES];
//    [pushVC setSelectedPhotoBlock:^(UIImage *image, NSInteger index) {
//        NSLog(@"%ld",(long)index);
//        self.IV.image = image;
//    }];
}

@end
