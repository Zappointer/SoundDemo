//
//  KeyHelper.h
//  SafeSound
//
//  Created by Demetri Miller on 10/22/2010
//  Copyright 2010 Demetri Miller. All rights reserved.
//

/*
 *	This class is a singleton providing globally accessible methods 
 *	and properties that may be needed by multiple classes wanting to map frequency
 *	values to pitches (e.g. A, Bb, C, F#, etc).
 */


#import <Foundation/Foundation.h>

@interface KeyHelper : NSObject {
	NSMutableDictionary *keyMapping;
	NSMutableDictionary *frequencyMapping;
}

@property(nonatomic, retain) NSMutableDictionary *keyMapping;
@property(nonatomic, retain) NSMutableDictionary *frequencyMapping;
@property (nonatomic,strong) NSDictionary *noteMapping;
@property (nonatomic,assign) CGFloat lowPassFrequency;
@property (nonatomic,assign) CGFloat highPassFrequency;

#pragma mark Key Generation
- (void)buildKeyMapping;
- (NSString *)closestCharForFrequency:(float)frequency;
- (NSString *) noteStringFromMapping:(int)note;

#pragma mark Singleton Methods
+ (KeyHelper *)sharedInstance;


@end