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
#import <limits.h>
#import <itpp/itcomm.h>
#import <itpp/base/math/elem_math.h>

@protocol RecorderDelegate <NSObject>

- (void) frequencyDetected:(CGFloat) frequency;
- (void) frequencyStringUpdated:(NSString*) frequencyString;
- (void) decodedStringFound:(NSString *) string;
- (void) startDecoding;
- (void) bufferUpdatedWithData:(void *)data size:(UInt32) size;

@end

typedef struct {
    __unsafe_unretained id mSelf;
    AudioStreamBasicDescription mDataFormat;
    AudioQueueRef mQueue;
    AudioQueueBufferRef mBuffers[kNumberBuffers];
    UInt32 bufferByteSize;
    UInt32 mCurrentPacket;
    itpp::vec mCodeReceived;
    int mCodeLength;
    bool mSignalFound;
    bool mIsRunning;
    double fq1,fq2,fq3;
    int framesCount;
    int codeIndex;
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

@property (nonatomic, assign) BOOL performDecode;
@property (nonatomic, assign) AQRecordState recordState;
@property (nonatomic, assign) CGFloat frequency;
@property (nonatomic, assign) id<RecorderDelegate> delegate;
@property (nonatomic, assign) BOOL isDecoding;

- (void)startRecording;
- (void)stopRecording;
- (void) decode;
- (void) displayBuffer:(AudioQueueBufferRef) audioQueueReference;
- (void) frequenciesUpdated:(NSArray *)frequencies;

@end
