// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FLTImagePickerPhotoAssetUtil.h"
#import "FLTImagePickerImageUtil.h"
#import "FLTImagePickerMetaDataUtil.h"

#import <MobileCoreServices/MobileCoreServices.h>

@implementation FLTImagePickerPhotoAssetUtil

+ (PHAsset *)getAssetFromImagePickerInfo:(NSDictionary *)info {
  if (@available(iOS 11, *)) {
    return [info objectForKey:UIImagePickerControllerPHAsset];
  }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  NSURL *referenceURL = [info objectForKey:UIImagePickerControllerReferenceURL];
  if (!referenceURL) {
    return nil;
  }
  PHFetchResult<PHAsset *> *result = [PHAsset fetchAssetsWithALAssetURLs:@[ referenceURL ]
                                                                 options:nil];
  return result.firstObject;
#pragma clang diagnostic pop
}

+ (PHAsset *)getAssetFromPHPickerResult:(PHPickerResult *)result API_AVAILABLE(ios(14)) {
  PHFetchResult *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[ result.assetIdentifier ]
                                                                options:nil];
  return fetchResult.firstObject;
}

+ (NSString *)saveImageWithOriginalImageData:(NSData *)originalImageData
                                       image:(UIImage *)image
                                    maxWidth:(nullable NSNumber *)maxWidth
                                   maxHeight:(nullable NSNumber *)maxHeight
                                imageQuality:(nullable NSNumber *)imageQuality {
  return [self saveImageWithOriginalImageData:originalImageData image:image maxWidth:maxWidth maxHeight:maxHeight imageQuality:imageQuality originalFileName:nil];
}

+ (NSString *)saveImageWithOriginalImageData:(NSData *)originalImageData
                                       image:(UIImage *)image
                                    maxWidth:(NSNumber *)maxWidth
                                   maxHeight:(NSNumber *)maxHeight
                                imageQuality:(NSNumber *)imageQuality
                            originalFileName:(NSString *)originalFileName {
  NSString *suffix = kFLTImagePickerDefaultSuffix;
  FLTImagePickerMIMEType type = kFLTImagePickerMIMETypeDefault;
  NSDictionary *metaData;
  
  // Getting the image type from the original image data if necessary.
  if (originalImageData) {
    type = [FLTImagePickerMetaDataUtil getImageMIMETypeFromImageData:originalImageData];
    suffix =
        [FLTImagePickerMetaDataUtil imageTypeSuffixFromType:type] ?: kFLTImagePickerDefaultSuffix;
    metaData = [FLTImagePickerMetaDataUtil getMetaDataFromImageData:originalImageData];
  }
  
  if (type == FLTImagePickerMIMETypeGIF) {
    GIFInfo *gifInfo = [FLTImagePickerImageUtil scaledGIFImage:originalImageData
                                                      maxWidth:maxWidth
                                                     maxHeight:maxHeight];

    return [self saveImageWithMetaData:metaData
                               gifInfo:gifInfo
                                prefix:originalFileName
                                suffix:suffix];
  } else {
    return [self saveImageWithMetaData:metaData
                                 image:image
                                prefix:originalFileName
                                suffix:suffix
                                  type:type
                          imageQuality:imageQuality];
  }
}

+ (NSString *)saveImageWithPickerInfo:(nullable NSDictionary *)info
                                image:(UIImage *)image
                         imageQuality:(NSNumber *)imageQuality {
  NSDictionary *metaData = info[UIImagePickerControllerMediaMetadata];
  return [self saveImageWithMetaData:metaData
                               image:image
                              prefix:nil
                              suffix:kFLTImagePickerDefaultSuffix
                                type:kFLTImagePickerMIMETypeDefault
                        imageQuality:imageQuality];
}

+ (NSString *)saveImageWithMetaData:(NSDictionary *)metaData
                            gifInfo:(GIFInfo *)gifInfo
                             prefix:(NSString *)prefix
                             suffix:(NSString *)suffix {
  NSString *path = [self temporaryFilePath:prefix suffix:suffix];
  return [self saveImageWithMetaData:metaData gifInfo:gifInfo path:path];
}

+ (NSString *)saveImageWithMetaData:(NSDictionary *)metaData
                              image:(UIImage *)image
                             prefix:(NSString *)prefix
                             suffix:(NSString *)suffix
                               type:(FLTImagePickerMIMEType)type
                       imageQuality:(NSNumber *)imageQuality {
  NSData *data = [FLTImagePickerMetaDataUtil convertImage:image
                                                usingType:type
                                                  quality:imageQuality];
  if (metaData) {
    NSData *updatedData = [FLTImagePickerMetaDataUtil imageFromImage:data withMetaData:metaData];
    // If updating the metadata fails, just save the original.
    if (updatedData) {
      data = updatedData;
    }
  }

  return [self createFile:data prefix:prefix suffix:suffix];
}

+ (NSString *)saveImageWithMetaData:(NSDictionary *)metaData
                            gifInfo:(GIFInfo *)gifInfo
                               path:(NSString *)path {
  CGImageDestinationRef destination = CGImageDestinationCreateWithURL(
      (CFURLRef)[NSURL fileURLWithPath:path], kUTTypeGIF, gifInfo.images.count, NULL);

  NSDictionary *frameProperties = @{
    (__bridge NSString *)kCGImagePropertyGIFDictionary : @{
      (__bridge NSString *)kCGImagePropertyGIFDelayTime : @(gifInfo.interval),
    },
  };

  NSMutableDictionary *gifMetaProperties = [NSMutableDictionary dictionaryWithDictionary:metaData];
  NSMutableDictionary *gifProperties =
      (NSMutableDictionary *)gifMetaProperties[(NSString *)kCGImagePropertyGIFDictionary];
  if (gifMetaProperties == nil) {
    gifProperties = [NSMutableDictionary dictionary];
  }

  gifProperties[(__bridge NSString *)kCGImagePropertyGIFLoopCount] = @0;

  CGImageDestinationSetProperties(destination, (CFDictionaryRef)gifMetaProperties);

  for (NSInteger index = 0; index < gifInfo.images.count; index++) {
    UIImage *image = (UIImage *)[gifInfo.images objectAtIndex:index];
    CGImageDestinationAddImage(destination, image.CGImage, (CFDictionaryRef)frameProperties);
  }

  CGImageDestinationFinalize(destination);
  CFRelease(destination);

  return path;
}

+ (NSString *)temporaryFilePath: (NSString*) prefix suffix:(NSString *)suffix {
  NSString *fileExtension = [@"image_picker_%@" stringByAppendingString:suffix];
  if(prefix) {
    fileExtension = [NSString stringWithFormat:@"%@_%@", prefix, fileExtension];
  }
  NSString *guid = [[NSProcessInfo processInfo] globallyUniqueString];
  NSString *tmpFile = [NSString stringWithFormat:fileExtension, guid];
  NSString *tmpDirectory = NSTemporaryDirectory();
  NSString *tmpPath = [tmpDirectory stringByAppendingPathComponent:tmpFile];
  return tmpPath;
}

+ (NSString *)createFile:(NSData *)data prefix: (NSString *) prefix suffix:(NSString *)suffix {
  NSString *tmpPath = [self temporaryFilePath:prefix suffix:suffix];
  if ([[NSFileManager defaultManager] createFileAtPath:tmpPath contents:data attributes:nil]) {
    return tmpPath;
  } else {
    nil;
  }
  return tmpPath;
}

@end
