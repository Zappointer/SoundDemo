//
//  ViewController.m
//  SoundHandShake
//
//  Created by Jason Chang on 6/25/14.
//  Copyright (c) 2014 Invisibi. All rights reserved.
//

#import "ViewController.h"
#import "RIOInterface.h"
#import "KeyHelper.h"
#import "Synth.h"
#import "MHAudioBufferPlayer.h"
#import "ToneGenerator.h"
#import "SoundPreference.h"

typedef struct {
    CGFloat frequency;
    NSTimeInterval timeStamp;
} soundPacket;

#define STARTSEQUENCE_MAX_DIFF 0.25
#define INDIVIDUAL_DIFF 0.1
// 60 c, 61 db,62 d,63 db,64 e,65 f,66 gb ,67 g,68 ab,69 a,70 bb, 71 b
#define STARTNOTE 60
#define ENDNOTE 60
#define STARTCHAR @"a"
#define ENDCHAR @"b"
#define TARGETLENGTH 12

NSString * letters = @"0123456789ab";

@interface ViewController () <ListernerDelegate>
{
    BOOL foundStart;
    BOOL foundSignal;
    BOOL foundA;
    NSTimeInterval foundATime;
    BOOL foundB;
    NSString *sequence;
    int sequenceLength;
    NSTimeInterval foundBTime;
    double minFrequencyValue;
    double maxFrequencyValue;
    double toneFrequencyValue;
    BOOL initalized;
    NSString *prevChar;
    int seemCount;
}

@property (nonatomic,weak) IBOutlet UILabel *frequencyLabel;
@property (nonatomic,weak) IBOutlet UILabel *statucLabel;
@property (nonatomic,weak) IBOutlet UILabel *codeLabel;
@property (nonatomic,weak) IBOutlet UITextField *minFrequency;
@property (nonatomic,weak) IBOutlet UITextField *maxFrequency;
@property (nonatomic,weak) IBOutlet UISlider *frequencySlider;
@property (nonatomic,weak) IBOutlet UILabel *toneFrequencyLabel;

@property (nonatomic,assign) CGFloat currentFrequency;
@property (nonatomic,strong) ToneGenerator *toneGenerator;
@property (nonatomic,strong) NSLock *synthLock;
@property (nonatomic,strong) Synth *synth;
@property (nonatomic,strong) MHAudioBufferPlayer *player;

@end

@implementation ViewController

- (ToneGenerator *) toneGenerator {
    if(!_toneGenerator) {
        _toneGenerator = [ToneGenerator new];
        _toneGenerator->sampleRate = APP_SAMPLERATE;
    }
    return _toneGenerator;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    minFrequencyValue = 200;
    maxFrequencyValue = 19500;
    self.minFrequency.text = [@(minFrequencyValue) stringValue];
    self.maxFrequency.text = [@(maxFrequencyValue) stringValue];
    toneFrequencyValue = self.frequencySlider.value * (maxFrequencyValue - minFrequencyValue) + minFrequencyValue;
    self.toneFrequencyLabel.text = [@(toneFrequencyValue) stringValue];
    self.toneGenerator->frequency = toneFrequencyValue;
    
    self.statucLabel.text = @"scanning...";
//    [self setUpAudioBufferPlayer];
}

- (IBAction) slideChanged:(UISlider *)slider {
    toneFrequencyValue = slider.value * (maxFrequencyValue - minFrequencyValue) + minFrequencyValue;
    self.toneFrequencyLabel.text = [@(toneFrequencyValue) stringValue];
    self.toneGenerator->frequency = toneFrequencyValue;
}

- (NSLock *) synthLock {
    if(!_synthLock) {
        _synthLock = [[NSLock alloc] init];
    }
    return _synthLock;
}

- (void)setUpAudioBufferPlayer
{
	// We need a lock because we update the Synth's state from the main thread
	// whenever the user presses a button, but we also read its state from an
	// audio thread in the MHAudioBufferPlayer callback. Doing both at the same
	// time is a bad idea and the lock prevents that.
    if(!_synthLock) {
        _synthLock = [[NSLock alloc] init];
    }
    
	// The Synth and the MHAudioBufferPlayer must use the same sample rate.
	// Note that the iPhone is a lot slower than a desktop computer, so choose
	// a sample rate that is not too high and a buffer size that is not too low.
	// For example, a buffer size of 800 packets and a sample rate of 16000 Hz
	// means you need to fill up the buffer in less than 0.05 seconds. If it
	// takes longer, the sound will crack up.
	float sampleRate = 16000.0f;
    
	_synth = [[Synth alloc] initWithSampleRate:sampleRate];
    
	_player = [[MHAudioBufferPlayer alloc] initWithSampleRate:sampleRate
													 channels:1
											   bitsPerChannel:16
											 packetsPerBuffer:1024];
	_player.gain = 0.9f;
    
	__weak typeof(self) weakSelf = self;
	_player.block = ^(AudioQueueBufferRef buffer, AudioStreamBasicDescription audioFormat)
	{
		__strong typeof(weakSelf) blockSelf = weakSelf;
		if (blockSelf != nil)
		{
			// Lock access to the synth. This callback runs on an internal
			// Audio Queue thread and we don't want to allow any other thread
			// to change the Synth's state while we're still filling up the
			// audio buffer.
			[blockSelf->_synthLock lock];
            
			// Calculate how many packets fit into this buffer. Remember that a
			// packet equals one frame because we are dealing with uncompressed
			// audio; a frame is a set of left+right samples for stereo sound,
			// or a single sample for mono sound. Each sample consists of one
			// or more bytes. So for 16-bit mono sound, each packet is 2 bytes.
			// For stereo it would be 4 bytes.
			int packetsPerBuffer = buffer->mAudioDataBytesCapacity / audioFormat.mBytesPerPacket;
            
			// Let the Synth write into the buffer. The Synth just knows how to
			// fill up buffers in a particular format and does not care where
			// they come from.
			int packetsWritten = [blockSelf->_synth fillBuffer:buffer->mAudioData frames:packetsPerBuffer];
            
			// We have to tell the buffer how many bytes we wrote into it.
			buffer->mAudioDataByteSize = packetsWritten * audioFormat.mBytesPerPacket;
            
			[blockSelf->_synthLock unlock];
		}
	};
    
	[_player start];
}


- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
//    [[RIOInterface sharedInstance] startListening: self];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear: animated];
//    [[RIOInterface sharedInstance] stopListening];
}

- (void) frequencyChangedWithValue:(float)newFrequency {
    self.currentFrequency = newFrequency;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.frequencyLabel.text = [@(newFrequency) stringValue];
        int letterIndex = [strongSelf indexFromFrequeucy: newFrequency];

        if(letterIndex >= 0) {
            NSString *closestChar = [letters substringWithRange: NSMakeRange(letterIndex,1)];
            NSLog(@"%@",closestChar);
            strongSelf.frequencyLabel.text = [@(newFrequency) stringValue];
            [strongSelf detectStart: newFrequency withChar: closestChar];
            [strongSelf recordSequence: closestChar];
        }
    });
}

- (int) indexFromFrequeucy:(float) frequency {
    if(frequency < (18500 - 50) || frequency > (18500 + (letters.length-1) * 50 + 50)) {
        return -1;
    }
    frequency -= 18500;
    if(frequency <= 25) {
        return 0;
    }
    NSUInteger index = frequency / 50;
    float mod = fmodf(frequency,50);
    if(mod > 25) {
        index++;
    }
    if(index >= letters.length) {
        index = letters.length-1;
    }
    return (int)index;
}

- (void) recordSequence:(NSString *)closestChar {
    if(foundStart && !foundSignal) {
        foundATime = [[NSDate date] timeIntervalSince1970];
        if([closestChar isEqualToString: ENDCHAR]) {
            return;
        }
        if(prevChar == nil) {
            seemCount = 1;
            prevChar = closestChar;
            sequence = [NSString stringWithFormat: @"%@%@",sequence,closestChar];
            self.statucLabel.text = [NSString stringWithFormat:@"founded: %@",sequence];
            sequenceLength++;
            if(sequenceLength >= TARGETLENGTH) {
                foundSignal = YES;
                [[RIOInterface sharedInstance] stopListening];
            }
        } else {
            if([prevChar isEqualToString: closestChar]) {
                seemCount++;
                if(seemCount == 4) {
                    seemCount = 2;
                    sequence = [NSString stringWithFormat: @"%@%@",sequence,closestChar];
                    self.statucLabel.text = [NSString stringWithFormat:@"founded: %@",sequence];
                    sequenceLength++;
                    if(sequenceLength >= TARGETLENGTH) {
                        foundSignal = YES;
                        [[RIOInterface sharedInstance] stopListening];
                    }
                }
            } else {
                prevChar = closestChar;
                seemCount = 1;
                sequence = [NSString stringWithFormat: @"%@%@",sequence,closestChar];
                self.statucLabel.text = [NSString stringWithFormat:@"founded: %@",sequence];
                sequenceLength++;
                if(sequenceLength >= TARGETLENGTH) {
                    foundSignal = YES;
                    [[RIOInterface sharedInstance] stopListening];
                }
            }
        }
    }
}

- (void) detectStart:(float)newFrequency withChar:(NSString*) closestChar {
    if(!foundStart) {
        if([closestChar isEqualToString: STARTCHAR]) {
            if(!foundB && !foundA) {
                foundA = YES;
                foundATime = [[NSDate date] timeIntervalSince1970];
                NSLog(@"foundStart Note with time: %f", foundATime);
            }
        }
        if([closestChar isEqualToString: ENDCHAR]) {
            if(foundA && !foundB) {
                foundBTime = [[NSDate date] timeIntervalSince1970];
                NSLog(@"foundEnd Note with time: %f", foundBTime);
                NSLog(@"diff %f", foundBTime - foundATime);
                if(foundBTime - foundATime < STARTSEQUENCE_MAX_DIFF) {
                    foundB = YES;
                    foundStart = YES;
                    sequence = @"";
                    sequenceLength = 0;
                    prevChar = nil;
                    self.statucLabel.text = @"start sequence founded";
                } else {
                    foundA = NO;
                }
            }
        }
    }
}

- (void) startListener {
    if(!initalized) {
        RIOInterface *rioRef = [RIOInterface sharedInstance];
        [rioRef setSampleRate:APP_SAMPLERATE];
        [rioRef setFrequency:15000];
        [rioRef initializeAudioSession];
        initalized = YES;
    }
    [[RIOInterface sharedInstance] stopListening];
    [[RIOInterface sharedInstance] startListening: self];
}

- (IBAction) restart:(id)sender {
    [self startListener];
    [self reset];
}

- (void) reset {
    self.statucLabel.text = @"scanning...";
    sequence = @"";
    foundStart = NO;
    foundB = NO;
    foundA = NO;
    foundSignal = NO;
    sequenceLength = 0;
}

- (IBAction) createRandomCode:(id)sender {
//    [self restart: nil];
    // random code
    int note[TARGETLENGTH];
    NSMutableString *output = [NSMutableString new];
    for(int i = 0; i < TARGETLENGTH; i++) {
        note[i] = arc4random() %(letters.length-2);
        [output appendString: [letters substringWithRange: NSMakeRange(note[i], 1)]];
    }
    
    self.codeLabel.text = [NSString stringWithFormat: @"%@", output];
    
    // start code
    CGFloat delay = 0;
    self.toneGenerator->frequency = [self frequecyFromLetterIndex: letters.length - 2];
    [self.toneGenerator play];
    delay += 0.1;
    [self performSelector: @selector(playFrequencyAtIndex:)  withObject: @(letters.length-1) afterDelay: delay];
    for(int i = 0; i < TARGETLENGTH; i++) {
        delay += INDIVIDUAL_DIFF;
        [self performSelector: @selector(playFrequencyAtIndex:)  withObject: @(note[i]) afterDelay: delay];
    }
    
    delay += INDIVIDUAL_DIFF;
    [self performSelector: @selector(stopFrequeucy)  withObject: nil afterDelay: delay];
}

- (double) frequecyFromLetterIndex:(NSUInteger) index {
    return 18500 + 50 * index;
}

- (void) playFrequencyAtIndex:(NSNumber *)index {
    self.toneGenerator->frequency = [self frequecyFromLetterIndex: [index integerValue]];
}

- (void) stopFrequeucy {
    [self.toneGenerator stop];
}

- (void) playNote:(NSNumber *)note {
//    [self.synthLock lock];
//	[self.synth playNote:[note integerValue]];
//	[self.synthLock unlock];
}

- (void) releaeNote:(NSNumber *)note {
//    [self.synthLock lock];
//    [self.synth releaseNote:[note integerValue]];
//    [self.synthLock unlock];
}

- (IBAction) playTone:(id)sender {
    [self.toneGenerator stop];
    self.toneGenerator->frequency = toneFrequencyValue;
    [self.toneGenerator play];
    
}

- (IBAction) stopTone:(id)sender {
    [self.toneGenerator stop];
}

@end
