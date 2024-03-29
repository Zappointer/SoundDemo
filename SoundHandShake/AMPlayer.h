//
//  AMPlayer.h
//  AudioModem
//
//  Created by Tarek Belkahia on 11/01/13.
//
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <itpp/itcomm.h>
#import <itpp/base/math/elem_math.h>

#define kNumberBuffers 3
using namespace itpp;

typedef struct {
    AudioStreamBasicDescription mDataFormat;
    AudioQueueRef mQueue;
    AudioQueueBufferRef mBuffers[kNumberBuffers];
    SInt64 mCurrentPacket;
    UInt32 mNumPacketsToRead;
    UInt32 bufferByteSize;
    bool mIsRunning;
    const char * mMessage;
    int mMessageIndex;
    UInt32 mMessageLength;
    UInt32 mMessageIndexFrameCount;
    UInt32 mMessageSentCounter;
    double fq1,fq2,fq3;
    float mTheta;
    __unsafe_unretained id mSelf;

} AQPlayState;

@interface AMPlayer : NSObject
@property (nonatomic, assign) AQPlayState playState;
//@property (retain, nonatomic) IBOutlet UIButton *recordButton;
//@property (retain, nonatomic) IBOutlet UIButton *playButton;
//@property (retain, nonatomic) IBOutlet UITextView *messageTextView;
//- (IBAction)playMessage:(id)sender;
- (void)play:(NSString *)message;
- (void) stop;
@end