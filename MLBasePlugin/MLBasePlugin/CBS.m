//
//  CBS.m
//  MLBasePlugin
//
//  Created by Arielle Moro on 16.11.12.
//  Copyright (c) 2012 UNIL - HEC - ISI - DopLab. All rights reserved.
//

#import "CBS.h"
#import <net/ethernet.h>

#define CBS_ALGO_ID 0x02            // 1 byte to identify CBS algo
#define ARC4RANDOM_MAX  0x100000000 // random constant

typedef struct {
    
    Byte algo;                      // 1 byte
    struct ether_addr sender;       // 6 bytes
    unsigned int serial;            // 4 bytes
    
} CBSHeader;                        // => 11 bytes header

static unsigned int serialCounter = 0;  // msg counter, allow us to build unique ID with host's MAC address

@interface CBS () {
    
    NSMutableDictionary* _handledMsgs;  // received messages and their counter
    int _threshold;                     // threshold of CBS (number of max hops)
    double _lowerLimitR;                // random waiting time lower limit
    double _upperLimitR;                // random waiting time upper limit
    
}

@end

@implementation CBS

/*
 * Standard initialisation
 */
-(id)init{
    self = [super init];
    if (self) {
        NSBundle* bundle = [NSBundle bundleWithIdentifier:@"ch.unil.doplab.MLBasePlugin"];
        NSString* settingsPath = [bundle pathForResource:@"PluginSettings" ofType:@"plist"];
        NSDictionary* settings = [NSDictionary dictionaryWithContentsOfFile:settingsPath];
        _handledMsgs = [[NSMutableDictionary alloc] init];
        _lowerLimitR = [[settings valueForKey:@"waitMin"] doubleValue];
        _upperLimitR = [[settings valueForKey:@"waitMax"] doubleValue];
        _threshold = [[settings valueForKey:@"k"] intValue];
    }
    return self;
}

//Function created to generate one float randomly
-(double)randomizeBetween:(double)lowerLimit and:(double)highLimit{
    double diff = highLimit - lowerLimit;
    return (((double) arc4random() / ARC4RANDOM_MAX) * diff) + lowerLimit;
}

//Void created to determine if the data must be sent
-(void) shouldForward:(NSTimer*)theTimer{
    MLMessage* msg = [theTimer userInfo];
    CBSHeader hdr;
    [msg readHeader:&hdr length:sizeof(CBSHeader)];
    NSData* msgID = [NSData dataWithBytes:&hdr.sender length:10];
    int counter = [[_handledMsgs objectForKey:msgID] intValue];
    char* author = ether_ntoa(&hdr.sender);
    //Send further process
    if(counter < _threshold){
        [self logFor:msg event:@"CBS FORWARD %s %u %@",author,hdr.serial,[msg description]];
        [self sendFurther:msg];
    }else{
        [self logFor:msg event:@"CBS DISCARD %s %u %@",author,hdr.serial,[msg description]];
    }
}

/*
 * CBS SEND
 */
-(MLSendResult)send:(MLMessage*)msg {
    //Header creation process
    CBSHeader hdr;
    hdr.algo = CBS_ALGO_ID;
    memcpy(&hdr.sender, ether_aton([[self hostAddress] UTF8String]), ETHER_ADDR_LEN); // copy MAC address of host in sender field of header
    hdr.serial = serialCounter++;
    [msg addHeader:&hdr length:sizeof(CBSHeader)];
    
    NSData* msgID = [NSData dataWithBytes:&hdr.sender length:10];
    [_handledMsgs setObject:[NSNumber numberWithInt:0] forKey:msgID];
    
    //Sending "further" process
    [self logFor:msg event:@"CBS SEND %@ %u %@",[self hostAddress],hdr.serial,[msg description]];
    return [self sendFurther:msg];
}

/*
 * CBS DELIVER
 */
-(void)deliver:(MLMessage*)msg {
    //Header reading process
    CBSHeader hdr;
    [msg readHeader:&hdr length:sizeof(CBSHeader)];
    if (hdr.algo == CBS_ALGO_ID) {
        NSData* msgID = [NSData dataWithBytes:&hdr.sender length:10];
        char* author = ether_ntoa(&hdr.sender);
        if (![[_handledMsgs allKeys] containsObject:msgID]){
            
            [_handledMsgs setObject:@(0) forKey:msgID];
            
            //Wait
            double rand =  [self randomizeBetween:_lowerLimitR and:_upperLimitR];
            [self logFor:msg event:@"CBS WAIT %s %u %f %@",author,hdr.serial,rand,[msg description]];
            [NSTimer scheduledTimerWithTimeInterval:rand target:self selector:@selector(shouldForward:) userInfo:msg repeats:NO];
            
            //Deliver further
            MLMessage* msgCopy = [msg copy];
            [msgCopy removeHeaderOflength:sizeof(CBSHeader)];
            [self deliverFurther:msgCopy];
        } else {
            
            int counter = [[_handledMsgs objectForKey:msgID] intValue] + 1;
            [self logFor:msg event:@"CBS INCREMENT %s %u %d %@",author,hdr.serial,counter,[msg description]];
            [_handledMsgs setObject:@(counter) forKey:msgID];
        }
    } else {
        [self logFor:msg event:@"CBS Not a message for me"];
    }
}

@end
