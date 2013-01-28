//
//  FragSession.m
//  MLBasePlugin
//
//  Created by Francois Vessaz on 11/5/12.
//  Copyright (c) 2012 UNIL - HEC - ISI - DopLab. All rights reserved.
//

#import "FragSession.h"
#import "Fragmentation.h"

#define CLEANUP 10.0 // cleanup after [s]

@interface FragSession () {
    
    // For both:
    __weak Fragmentation* layer;        // Fragmentation layer of this session
    NSTimer* timer;                     // timer for cleanup (outgoing) or reassemble (incoming)
    NSData* sessionID;                  // session ID (host's MAC + session number)
    
    // outgoing only:
    NSMutableArray* outFragments;       // fragements out (MLMessage)
    
    // incoming only:
    NSMutableDictionary* inFragments;   // fragments in {NSNumber(identifiant) : MLMessage}
    double tiSum;                       // sum of time interval between fragments arrival
    double lastTimestamp;               // timestamp of last incomed fragment
    
}

-(void)reassemble;                      // try to reassemble message, deliver it if possible or request missing messages
-(void)cleanup;                         // cleanup the session form layer sessions list

@end

@implementation FragSession

- (id)initIncoming:(Fragmentation*)aFragLayer andID:(NSData*)aSessionID
{
    self = [super init];
    if (self) {
        inFragments = [@{} mutableCopy];
        layer = aFragLayer;
        lastTimestamp = -1;
        tiSum = 0;
        timer = nil;
        sessionID = aSessionID;
    }
    return self;
}

- (id)initOutgoing:(Fragmentation*)aFragLayer andID:(NSData*)aSessionID
{
    self = [super init];
    if (self) {
        outFragments = [@[] mutableCopy];
        layer = aFragLayer;
        timer = [NSTimer scheduledTimerWithTimeInterval:CLEANUP target:self selector:@selector(cleanup) userInfo:nil repeats:NO];
        sessionID = aSessionID;
    }
    return self;
}

-(void)newOutgoingFragment:(MLMessage*)frag {
    [outFragments addObject:frag];
}

-(void)newIncomingFragment:(MLMessage*)frag {
    NSTimeInterval time = [[NSDate date] timeIntervalSince1970];
    FragHeader hdr;
    [frag readHeader:&hdr length:sizeof(FragHeader)];
    [inFragments setObject:frag forKey:@(hdr.fragment)];
    if (lastTimestamp > 0) {
        tiSum += (time - lastTimestamp);
    }
    if (hdr.total == hdr.fragment+1 || [inFragments count] == hdr.total) {
        // message may be complete
        [self reassemble];
    } else if (lastTimestamp > 0) {
        // evaluate when msg will be complete
        double avgTi = tiSum / ([inFragments count]-1);
        int fragsToEnd = hdr.total - hdr.fragment;
        double waitFor = (avgTi * fragsToEnd);
        if (timer == nil) {
            timer = [NSTimer scheduledTimerWithTimeInterval:waitFor target:self selector:@selector(reassemble) userInfo:nil repeats:NO];
        } else {
            [timer setFireDate:[NSDate dateWithTimeIntervalSinceNow:waitFor]];
        }
    }
    lastTimestamp = time;
}

-(NSArray*)outFragments {
    [timer setFireDate:[NSDate dateWithTimeIntervalSinceNow:CLEANUP]];
    return outFragments;
}

- (void)reassemble {
    [timer invalidate];
    timer = nil;
    
    MLMessage* msg = [[inFragments allValues] objectAtIndex:0];
    FragHeader hdr;
    [msg readHeader:&hdr length:sizeof(FragHeader)];
    NSMutableArray* missingFrags = [@[] mutableCopy];
    for (unsigned int i = 0; i<hdr.total; i++) {
        if ([inFragments objectForKey:@(i)] == nil) {
            [missingFrags addObject:@(i)];
        }
    }
    if ([missingFrags count] > 0) {
        FragHeader nakHdr;
        nakHdr.msgType = kFragMsgTypeNAK;
        nakHdr.sender = hdr.sender;
        nakHdr.session = hdr.session;
        nakHdr.fragment = 0;
        MLMessage* nakMessage = [[MLMessage alloc] initWithData:[NSKeyedArchiver archivedDataWithRootObject:missingFrags] from:msg.from to:msg.to andTask:[@(msg.taskId) stringValue]];
        [nakMessage addHeader:&nakHdr length:sizeof(FragHeader)];
        [layer logFor:nakMessage event:@"FRAG SEND_NAK for %i messages",[missingFrags count]];
        [layer sendFurther:nakMessage];
    } else {
        NSMutableData* msgData = [NSMutableData data];
        for (unsigned int i = 0; i<hdr.total; i++) {
            MLMessage* frag = [inFragments objectForKey:@(i)];
            [frag removeHeaderOflength:sizeof(FragHeader)];
            [msgData appendData:frag.msgData];
        }
        MLMessage* reassembledMsg = [[MLMessage alloc] initWithData:msgData from:msg.from to:msg.to andTask:[@(msg.taskId) stringValue]];
        [layer logFor:reassembledMsg event:@"FRAG DELIVER %@",[reassembledMsg description]];
        [layer deliverFurther:reassembledMsg];
        [self cleanup];
    }
}

-(void)cleanup {
    [layer cleanupSession:sessionID];
}

@end
