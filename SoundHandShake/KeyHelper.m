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
    self.lowPassFrequency = 250;
    self.highPassFrequency = 500;
	self.keyMapping = [[NSMutableDictionary alloc] initWithCapacity:9];
    [keyMapping setObject: @(258.39) forKey: @"c"];
    [keyMapping setObject: @(301.46) forKey: @"d"];
    [keyMapping setObject: @(322.99) forKey: @"e"];
    [keyMapping setObject: @(344.53) forKey: @"f"];
    [keyMapping setObject: @(387.59) forKey: @"g"];
    [keyMapping setObject: @(430.66) forKey: @"a"];
    [keyMapping setObject: @(495.26) forKey: @"b"];
	
	self.frequencyMapping = [[NSMutableDictionary alloc] initWithCapacity:9];
    [frequencyMapping setObject: @"c" forKey: @(258.39)];
    [frequencyMapping setObject: @"d" forKey: @(301.46)];
    [frequencyMapping setObject: @"e" forKey: @(322.99)];
    [frequencyMapping setObject: @"f" forKey: @(344.53)];
    [frequencyMapping setObject: @"g" forKey: @(387.59)];
    [frequencyMapping setObject: @"a" forKey: @(430.66)];
    [frequencyMapping setObject: @"b" forKey: @(495.26)];
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
