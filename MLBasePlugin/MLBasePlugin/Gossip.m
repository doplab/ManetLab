//
//  Gossip.m
//  MLBasePlugin
//
//  Created by Francois Vessaz on 8/13/12.
//  Modified by Arielle Moro on 16.11.12.
//  Copyright (c) 2012 UNIL - HEC - ISI - DopLab. All rights reserved.
//

#import "Gossip.h"
#import <net/ethernet.h>

#define GOSSIP_ALGO_ID 0x00             // 1 byte to identify gossip algo
#define GOSSIP_ALGO_NAME @"GOSSIP"
#define ARC4RANDOM_MAX 0x100000000

typedef struct {
    
    Byte algo;                          // 1 byte
    struct ether_addr sender;           // 6 bytes
    unsigned int serial;                // 4 bytes
    
} GossipHeader;                         // => 11 bytes header

static unsigned int serialCounter = 0;  // msg counter, allow us to build unique ID with host's MAC address

@interface Gossip () {
    
    NSMutableSet* _handledMsgs;         // received messages
    double _prob;                       // [%]
    Byte _algo_id;                      // algorithm id used
    NSString* _algo_name;               // algorithm name (for log)
    
}

@end

@implementation Gossip

/*
 * Standard initialisation
 */
-(id)init{
    self = [super init];
    if (self) {
        NSBundle* bundle = [NSBundle bundleWithIdentifier:@"ch.unil.doplab.MLBasePlugin"];
        NSString* settingsPath = [bundle pathForResource:@"PluginSettings" ofType:@"plist"];
        NSDictionary* settings = [NSDictionary dictionaryWithContentsOfFile:settingsPath];
        _handledMsgs = [NSMutableSet set];
        _prob = [[settings valueForKey:@"p"] doubleValue];
        _algo_id = GOSSIP_ALGO_ID;
        _algo_name = GOSSIP_ALGO_NAME;
    }
    return self;
}

/*
 * Subclass SP initialisation
 */
-(id)initWithProb:(double)p name:(NSString*)name andAlgoId:(Byte)algoId {
    self = [super init];
    if (self) {
        _handledMsgs = [NSMutableSet set];
        _prob = p;
        _algo_id = algoId;
        _algo_name = name;
    }
    return self;
}

// Method created to generate one float randomly
-(float) randomizeFloatBetween:(float)lowerLimit and:(float)highLimit{
    float diff = highLimit - lowerLimit;
    return (((float) arc4random() / ARC4RANDOM_MAX) * diff) + lowerLimit;
}

// Method created to determine if the data must be sent
-(BOOL) shouldForward{
    return (((double) arc4random() / ARC4RANDOM_MAX) <= _prob);
}

/*
 * Gossip SEND
 */
-(MLSendResult)send:(MLMessage*)msg {
    //Header creation process
    GossipHeader hdr;
    hdr.algo = _algo_id;
    memcpy(&hdr.sender, ether_aton([[self hostAddress] UTF8String]), ETHER_ADDR_LEN); // copy MAC address of host in sender field of header
    hdr.serial = serialCounter++;
    NSData* msgID = [NSData dataWithBytes:&hdr.sender length:10];
    [self logFor:msg event:@"%@ SEND %@ %u",_algo_name,[self hostAddress],hdr.serial];
    [_handledMsgs addObject:msgID];
    
    //Sending "further" process
    [msg addHeader:&hdr length:sizeof(GossipHeader)];
    return [self sendFurther:msg];
}

/*
 * Gossip DELIVER
 */
-(void)deliver:(MLMessage*)msg {
    //Header reading process
    GossipHeader hdr;
    [msg readHeader:&hdr length:sizeof(GossipHeader)];
    //Delivering "further" process
    if (hdr.algo == _algo_id) {
        NSData* msgID = [NSData dataWithBytes:&hdr.sender length:10];
        char* author = ether_ntoa(&hdr.sender);
        if (![_handledMsgs containsObject:msgID]){
            [_handledMsgs addObject:msgID];
            if ([self shouldForward]) {
                [self logFor:msg event:@"%@ FORWARD %s %u %@",_algo_name,author,hdr.serial,[msg description]];
                [self sendFurther:msg];
            } else {
                [self logFor:msg event:@"%@ DISCARD %s %u %@",_algo_name,author,hdr.serial,[msg description]];
            }
            [msg removeHeaderOflength:sizeof(GossipHeader)];
            [self deliverFurther:msg];
        } else {
            [self logFor:msg event:@"%@ DOUBLE %s %u %@",_algo_name,author,hdr.serial,[msg description]];
        }
    } else {
        [self logFor:msg event:@"%@ Not a message for me",_algo_name];
    }
}

@end
