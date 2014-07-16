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
#import "LDPCGenerator.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [LDPCGenerator sharedGenerator].signal0Frequency = 17000.0;
    [LDPCGenerator sharedGenerator].signal1Frequency = 19000.0;
    [LDPCGenerator sharedGenerator].startSignalFrequency = 18000.0;
    [LDPCGenerator sharedGenerator].characterLength = 14;
    [[LDPCGenerator sharedGenerator] setup];
    return YES;
}
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
//        // only need 112 bit for 14 ascii character
//        LDPC_Parity_Irregular H;
//        H.generate(224,
//                   "0 0.27684 0.28342 0 0 0 0 0 0.43974",
//                   "0 0 0 0 0 0.01568 0.85244 0.13188",
//                   "rand",   // random unstructured matrix
//                   "500 8"); // optimize girth
//        LDPC_Generator_Systematic G(&H);
//        LDPC_Code C(&H, &G);
//        C.set_exit_conditions(2500);
////        C.set_llrcalc(LLR_calc_unit(12,0,7));
//        NSLog(@"code generated completed\n");
//        {
//            bvec InData = zeros_b(112);
//            NSLog(@"%i",InData.length());
//    //        NSString *input = @"ab123456789012";
//            char input[] = "ab123987564912";
//            for(int i = 0; i < 14; i++) {
//                char c = input[i];
//                for(int bitIndex = 0; bitIndex < 8; bitIndex++) {
//                    InData.set(i*8+bitIndex, bin((c >> abs(bitIndex-7)) & 1));
//                }
//            }
//            bvec outData = C.encode(InData);
//    //        G.encode(InData,outData);
////            cout << InData << endl;
////            cout << outData << endl;
//            
//            BPSK Mod;
//            vec s = Mod.modulate_bits(outData);
//            // create noise
//            vec EbN0db = "0.6:0.2:5";
//            QLLRvec llr;
//            for(int n = 0; n < length(EbN0db); n++) {
//                double N0 = pow(10.0, -EbN0db(1) / 10.0) / C.get_rate();
//                NSLog(@"error rate %f",N0);
//                AWGN_Channel chan(N0 / 2);
//                vec x = chan(s);
//                vec softbits = Mod.demodulate_soft_bits(x, N0);
//                // Decode the received bits
////                llr = C.get_llrcalc().to_qllr(softbits);
//                int it = C.bp_decode(C.get_llrcalc().to_qllr(softbits), llr);
//                if(it >= 0) {
//                    NSLog(@"used %i iteration on %i",it,n);
//                    break;
//                } else {
//                    llr.clear();
//                }
//                NSLog(@"used %i iteration on %i",it,n);
//            }
//            
//            cout << llr.length() << endl;
//            bvec answer = llr.get(0, 111) < 0;
//            cout << answer << endl;
//            char *final = (char*)calloc(14,sizeof(char));
//            for(int i = 0; i < 14; i++) {
//                for(int bitIndex = 0; bitIndex < 8; bitIndex++) {
//                    bin b = answer.get(i*8+bitIndex);
//                    if(b == 1) {
//                        final[i] |= 1 << abs(bitIndex-7);
//                    }
//                }
//            }
//            cout << final << endl;
//        }
    
        
        
//        int64_t Nbits = 5000LL; // maximum number of bits simulated
//        // for each SNR point
//        int Nbers = 2500;            // target number of bit errors per SNR point
//        double BERmin = 1e-6;        // BER at which to terminate simulation
//        vec EbN0db = "0.6:0.2:5";
////        LDPC_Generator_Systematic G; // for codes created with ldpc_gen_codes since generator exists
//        bool single_snr_mode = false;
//        
//        // High performance: 2500 iterations, high resolution LLR algebra
//        C.set_exit_conditions(2500);
//        // Alternate high speed settings: 50 iterations, logmax approximation
//        // C.set_llrcalc(LLR_calc_unit(12,0,7));
//        cout << C << endl;
//        int N = C.get_nvar();             // number of bits per codeword
//        BPSK Mod;
//        bvec bitsin = zeros_b(N);
//        vec s = Mod.modulate_bits(bitsin);
//        RNG_randomize();
//        for (int j = 0; j < length(EbN0db); j++) {
//            // Noise variance is N0/2 per dimension
//            double N0 = pow(10.0, -EbN0db(j) / 10.0) / C.get_rate();
//            AWGN_Channel chan(N0 / 2);
//            BERC berc;  // Counters for coded and uncoded BER
//            BLERC ferc; // Counter for coded FER
//            ferc.set_blocksize(C.get_nvar() - C.get_ncheck());
//            for (int64_t i = 0; i < Nbits; i += C.get_nvar()) {
//                // Received data
//                vec x = chan(s);
//                // Demodulate
//                vec softbits = Mod.demodulate_soft_bits(x, N0);
//                // Decode the received bits
//                QLLRvec llr;
//                C.bp_decode(C.get_llrcalc().to_qllr(softbits), llr);
//                bvec bitsout = llr < 0;
//                //      bvec bitsout = C.decode(softbits); // (only systematic bits)
//                // Count the number of errors
//                berc.count(bitsin, bitsout);
//                ferc.count(bitsin, bitsout);
//                if (single_snr_mode) {
//                    cout << "Eb/N0 = " << EbN0db(j) << "  Simulated "
//                    << ferc.get_total_blocks() << " frames and "
//                    << berc.get_total_bits() << " bits. "
//                    << "Obtained " << berc.get_errors() << " bit errors. "
//                    << " BER: " << berc.get_errorrate()
//                    << " FER: " << ferc.get_errorrate() << endl << flush;
//                }
//                else {
//                    if (berc.get_errors() > Nbers)
//                        break;
//                }
//            }
//            cout << "Eb/N0 = " << EbN0db(j) << "  Simulated "
//            << ferc.get_total_blocks() << " frames and "
//            << berc.get_total_bits() << " bits. "
//            << "Obtained " << berc.get_errors() << " bit errors. "
//            << " BER: " << berc.get_errorrate()
//            << " FER: " << ferc.get_errorrate() << endl << flush;
//            if (berc.get_errorrate() < BERmin)
//                break;
//        }
        
        
//    });
    
    
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
//    return YES;
//}

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
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&err];
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
