//
//  KeyHelper.m
//  SafeSound
//
//  Created by Demetri Miller on 10/22/2010.
//  Copyright 2010 Demetri Miller. All rights reserved.
//

#import "KeyHelper.h"

@implementation KeyHelper

@synthesize keyMapping;
@synthesize frequencyMapping;

- (void)buildKeyMapping {
    self.lowPassFrequency = 2000;
    self.highPassFrequency = 4000;
	self.keyMapping = [[NSMutableDictionary alloc] initWithCapacity:9];
    [keyMapping setObject: @(2088.71) forKey: @"C"];
//    [keyMapping setObject: @(279.93) forKey: @"Db"];
//    [keyMapping setObject: @(301.46) forKey: @"D"];
//    [keyMapping setObject: @(211.00) forKey: @"Eb"];
//    [keyMapping setObject: @(322.99) forKey: @"E"];
//    [keyMapping setObject: @(344.53) forKey: @"F"];
//    [keyMapping setObject: @(366.06) forKey: @"Gb"];
//    [keyMapping setObject: @(387.59) forKey: @"G"];
//    [keyMapping setObject: @(409.13) forKey: @"Ab"];
//    [keyMapping setObject: @(430.66) forKey: @"A"];
//    [keyMapping setObject: @(473.73) forKey: @"Bb"];
//    [keyMapping setObject: @(495.26) forKey: @"B"];
	
	self.frequencyMapping = [[NSMutableDictionary alloc] initWithCapacity:9];
    [frequencyMapping setObject: @"C" forKey: @(2088.71)];
//    [frequencyMapping setObject: @"Db" forKey: @(279.93)];
//    [frequencyMapping setObject: @"D" forKey: @(301.46)];
//    [frequencyMapping setObject: @"Eb" forKey: @(311.00)];
//    [frequencyMapping setObject: @"E" forKey: @(322.99)];
//    [frequencyMapping setObject: @"F" forKey: @(344.53)];
//    [frequencyMapping setObject: @"Gb" forKey: @(366.06)];
//    [frequencyMapping setObject: @"G" forKey: @(387.59)];
//    [frequencyMapping setObject: @"Ab" forKey: @(409.13)];
//    [frequencyMapping setObject: @"A" forKey: @(430.66)];
//    [frequencyMapping setObject: @"Bb" forKey: @(473.73)];
//    [frequencyMapping setObject: @"B" forKey: @(495.26)];
    
    // 60 c, 61 db,62 d,63 db,64 e,65 f,66 gb ,67 g,68 ab,69 a,70 bb, 71 b
    self.noteMapping = @{
                         @(60):@"B",
                         @(61):@"Db",
                         @(62):@"D",
                         @(63):@"Eb",
                         @(64):@"E",
                         @(65):@"F",
                         @(66):@"Gb",
                         @(67):@"G",
                         @(68):@"Ab",
                         @(69):@"A",
                         @(70):@"Bb",
                         @(71):@"B",
                         };
}

// Gets the character closest to the frequency passed in. 
- (NSString *)closestCharForFrequency:(float)frequency {
	NSString *closestKey = nil;
	float closestFloat = 2;	// Init to largest float value so all ranges closer.
    if(frequency <= self.lowPassFrequency || frequency >= self.highPassFrequency) {
        return closestKey;
    }
    
	// Check each values distance to the actual frequency.
	for(NSNumber *num in [keyMapping allValues]) {
		float mappedFreq = [num floatValue];
		float tempVal = fabsf(mappedFreq-frequency);
		if (tempVal < closestFloat) {
			closestFloat = tempVal;
			closestKey = [frequencyMapping objectForKey:num];
		}
	}
	
	return closestKey;
}

- (instancetype) init {
    self = [super init];
    if(self) {
        [self buildKeyMapping];
    }
    return self;
}

- (NSString *) noteStringFromMapping:(int)note {
    return self.noteMapping[@(note)];
}

+ (KeyHelper *)sharedInstance
{
    static KeyHelper *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

@end
