//
//  AppDelegate.m
//  SoundHandShake
//
//  Created by Jason Chang on 6/25/14.
//  Copyright (c) 2014 Invisibi. All rights reserved.
//

#import "AppDelegate.h"
#import <AVFoundation/AVFoundation.h>
#import "SoundPreference.h"
#import <itpp/itcomm.h>

using namespace itpp;

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    
    LDPC_Parity_Irregular H;
    H.generate(10000,
               "0 0.21991 0.23328 0.02058 0 0.08543 0.06540 0.04767 0.01912 "
               "0 0 0 0 0 0 0 0 0 0.08064 0.22798",
               "0 0 0 0 0 0 0 0.64854 0.34747 0.00399",
               "rand",  // random unstructured matrix
               "150 8"); // optimize
    LDPC_Code C(&H);
    
    
//    //Scalars and vectors:
//    int m, t, n, k, q, NumBits, NumCodeWords;
//    double p;
//    bvec uncoded_bits, coded_bits, received_bits, decoded_bits;
//    //Set parameters:
//    NumCodeWords = 1000;  //Number of Reed-Solomon code-words to simulate
//    p = 0.5;             //BSC Error probability
//    m = 3;                //Reed-Solomon parameter m
//    t = 2;                //Reed-Solomon parameter t
//
//    //Classes:
//    Reed_Solomon reed_solomon(m, t);
//    BSC bsc(p);
//    BERC berc;
//    RNG_randomize();
//    //Calculate parameters for the Reed-Solomon Code:
//    n = round_i(pow(2.0, m) - 1);
//    k = round_i(pow(2.0, m)) - 1 - 2 * t;
//    q = round_i(pow(2.0, m));
//
//    NumBits = m * k * NumCodeWords;
//    uncoded_bits = randb(NumBits);
//    coded_bits = reed_solomon.encode(uncoded_bits);
//    NSLog(@"code length %i",coded_bits.length());
//    received_bits = bsc(coded_bits);
//    decoded_bits = reed_solomon.decode(received_bits);
//    NSLog(@"code length %i",decoded_bits.length());
//    berc.count(uncoded_bits, decoded_bits);
//    NSLog(@"The bit error probability after decoding is %f correct: %f total: %f", berc.get_errorrate(), berc.get_corrects(), berc.get_total_bits());
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setActive:NO error:nil];
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    NSError	*err = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setPreferredSampleRate: APP_SAMPLERATE error: &err];
    [session setCategory:AVAudioSessionCategoryPlayback error:&err];
    [session setActive:YES error:&err];
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
