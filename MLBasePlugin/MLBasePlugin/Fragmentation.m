//
//  Fragmentation.m
//  MLBasePlugin
//
//  Created by Francois Vessaz on 9/6/12.
//  Copyright (c) 2012 UNIL - HEC - ISI - DopLab. All rights reserved.
//

#import "Fragmentation.h"
#import "FragSession.h"

#define MAX_SIZE 1400 // fragments max size [bytes]

static unsigned int sessionCounter = 0; // session ID generator

@interface Fragmentation (){
    
    NSMutableDictionary* sessions; // active sessions
    
}

@end

@implementation Fragmentation

-(id)init
{
    self = [super init];
    if (self) {
        sessions = [@{} mutableCopy];
    }
    return self;
}

/*
 * Send a message directly or fragment it if too big.
 */
-(MLSendResult)send:(MLMessage*)msg {
    // try to send directly the message...
    MLSendResult res = [self sendFurther:msg];
    
    // fragment it if too big...
    if (res == kMLSendTooBig) {
        unsigned int nbOfFragment = (unsigned int)msg.msgData.length / MAX_SIZE;
        if (msg.msgData.length % MAX_SIZE > 0) {
            nbOfFragment++;
        }
        [self logFor:msg event:@"FRAG SEND %@ in %u fragments",[msg description],nbOfFragment];
        
        FragHeader hdr;
        hdr.session = sessionCounter++;
        hdr.total = nbOfFragment;
        hdr.msgType = kFragMsgTypeData;
        memcpy(&hdr.sender, ether_aton([[self hostAddress] UTF8String]), ETHER_ADDR_LEN);
        
        NSData* sessionID = [NSData dataWithBytes:&hdr.sender length:10];
        FragSession* session = [[FragSession alloc] initOutgoing:self andID:sessionID];
        
        for (unsigned int i=0; i<nbOfFragment; i++) {
            hdr.fragment = i;
            unsigned int start = i * MAX_SIZE;
            unsigned int length = MAX_SIZE;
            if (i == nbOfFragment-1) {
                length = (unsigned int)msg.msgData.length - (i*MAX_SIZE);
            }
            MLMessage* fragment = [[MLMessage alloc] initWithData:[msg.msgData subdataWithRange:NSMakeRange(start, length)] from:msg.from to:msg.to andTask:[@(msg.taskId) stringValue]];
            [fragment addHeader:&hdr length:sizeof(FragHeader)];
            [session newOutgoingFragment:fragment];
        }
        [sessions setObject:session forKey:sessionID];
        [self logFor:msg event:@"FRAG Will send %i fragments",nbOfFragment];
        for (MLMessage *toSend in session.outFragments) {
            res = [self sendFurther:toSend];
            if (res != kMLSendSuccess){
                return res;
            }
        }
    }
    return res;
}

/*
 * Deliver a message. Process only frag messages.
 */
-(void)deliver:(MLMessage*)msg {
    FragHeader hdr;
    [msg readHeader:&hdr length:sizeof(FragHeader)];
    if (hdr.msgType == kFragMsgTypeData) {
        NSData* msgID = [NSData dataWithBytes:&hdr.sender length:10];
        FragSession* session = nil;
        if ([sessions objectForKey:msgID] == nil) {
            // first reception
            session = [[FragSession alloc] initIncoming:self andID:msgID];
            [sessions setObject:session forKey:msgID];
        } else {
            // then
            session = [sessions objectForKey:msgID];
        }
        [session newIncomingFragment:msg];
    } else if (hdr.msgType == kFragMsgTypeNAK) {
        if (bcmp(&hdr.sender, ether_aton([[self hostAddress] UTF8String]), sizeof(ETHER_ADDR_LEN)) == 0) {
            [self logFor:msg event:@"FRAG RESEND"];
            // NAK message is for this host (origin), could maybe allow everyone to complete???
            NSData* msgID = [NSData dataWithBytes:&hdr.sender length:10];
            FragSession* session = [sessions objectForKey:msgID];
            [msg removeHeaderOflength:sizeof(FragHeader)];
            NSArray* missingFragments = [NSKeyedUnarchiver unarchiveObjectWithData:msg.msgData];
            for (NSNumber* frag in missingFragments) {
                MLMessage* msgToResend = [session.outFragments objectAtIndex:[frag unsignedIntegerValue]];
                [self sendFurther:msgToResend];
            }
        }
    } else {
        [self deliverFurther:msg];
    }
}

-(void)cleanupSession:(NSData*)sessionID {
    [sessions removeObjectForKey:sessionID];
}

@end
