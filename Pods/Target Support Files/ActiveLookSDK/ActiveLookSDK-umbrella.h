#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "heatshrink-Bridging-Header.h"
#import "heatshrink_common.h"
#import "heatshrink_config.h"
#import "heatshrink_decoder.h"
#import "heatshrink_encoder.h"
#import "RNHeatshrinkDecoder.h"
#import "RNHeatshrinkEncoder.h"

FOUNDATION_EXPORT double ActiveLookSDKVersionNumber;
FOUNDATION_EXPORT const unsigned char ActiveLookSDKVersionString[];

