//
//  AMRecorder.h
//  AudioModem
//
//  Created by Tarek Belkahia on 11/01/13.
//
//

#import <Foundation/Foundation.h>
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#include <limits.h>
#import <itpp/itcomm.h>
#import <itpp/base/math/elem_math.h>

@protocol RecorderDelegate <NSObject>

- (void) frequencyDetected:(CGFloat) frequency;
- (void) decodedStringFound:(NSString *) string;

@end

typedef struct {
    __unsafe_unretained id mSelf;
    AudioStreamBasicDescription mDataFormat;
    AudioQueueRef mQueue;
    AudioQueueBufferRef mBuffers[kNumberBuffers];
    UInt32 bufferByteSize;
    SInt64 mCurrentPacket;
    itpp::vec mCodeReceived;
    int mCodeLength;
    bool mSignalFound;
    bool mIsRunning;
} AQRecordState;

@interface AMRecorder : NSObject
{
    @public
    FFTSetup fftSetup;
    COMPLEX_SPLIT A;
    int log2n, n, nOver2;
    
    void *dataBuffer;
    float *outputBuffer;
    size_t bufferCapacity;	// In samples
    size_t index;	// In samples
}

@property (nonatomic, assign) AQRecordState recordState;
@property (nonatomic, assign) CGFloat frequency;
@property (nonatomic, assign) id<RecorderDelegate> delegate;
//@property (retain, nonatomic) IBOutlet UIButton *playButton;
//@property (retain, nonatomic) IBOutlet UIButton *recordButton;
//@property (retain, nonatomic) IBOutlet UITextView *receiverTextView;
//- (IBAction)recordMessage:(id)sender;
- (void)startRecording;
- (void)stopRecording;
- (void)updateTextView;
- (void) decode;

@end
