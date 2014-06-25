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

typedef struct {
    CGFloat frequency;
    NSTimeInterval timeStamp;
} soundPacket;

#define STARTSEQUENCE_MAX_DIFF 0.5
#define STARTCHAR @"f"
#define ENDCHAR @"b"

@interface ViewController () <ListernerDelegate>
{
    BOOL foundStart;
    BOOL foundSignal;
    BOOL foundA;
    NSTimeInterval foundATime;
    BOOL foundB;
    NSString *sequence;
    NSTimeInterval foundBTime;
}

@property (nonatomic,assign) CGFloat currentFrequency;
@property (nonatomic,weak) IBOutlet UILabel *frequencyLabel;
@property (nonatomic,weak) IBOutlet UILabel *statucLabel;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    RIOInterface *rioRef = [RIOInterface sharedInstance];
	[rioRef setSampleRate:44100];
	[rioRef setFrequency:294];
	[rioRef initializeAudioSession];
    self.statucLabel.text = @"scanning...";
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    [[RIOInterface sharedInstance] startListening: self];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear: animated];
    [[RIOInterface sharedInstance] stopListening];
}

- (void) frequencyChangedWithValue:(float)newFrequency {
    self.currentFrequency = newFrequency;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        KeyHelper *helper = [KeyHelper sharedInstance];
        NSString *closestChar = [helper closestCharForFrequency:newFrequency];
        if(closestChar.length == 1) {
            strongSelf.frequencyLabel.text = closestChar;
            [strongSelf detectStart: newFrequency withChar: closestChar];
            [strongSelf recordSequence: closestChar];
        }
    });
}

- (void) recordSequence:(NSString *)closestChar {
    if(foundStart && !foundSignal) {
        foundATime = [[NSDate date] timeIntervalSince1970];
        if(foundATime - foundBTime > STARTSEQUENCE_MAX_DIFF) {
            sequence = [NSString stringWithFormat: @"%@%@",sequence,closestChar];
            self.statucLabel.text = [NSString stringWithFormat:@"start sequence founded: %@",sequence];
            foundBTime = foundATime;
            if(sequence.length >= 4) {
                foundSignal = YES;
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
                    self.statucLabel.text = @"start sequence founded";
                } else {
                    foundA = NO;
                }
            }
        }
    }
}

- (IBAction) restart:(id)sender {
    self.statucLabel.text = @"scanning...";
    sequence = @"";
    foundStart = NO;
    foundB = NO;
    foundA = NO;
    foundSignal = NO;
}

@end
