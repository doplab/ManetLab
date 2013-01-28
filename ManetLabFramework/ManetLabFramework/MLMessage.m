//
//  MLMessage.m
//  MLStackAPI
//
//  Created by Francois Vessaz on 4/18/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MLMessage+Internal.h"
#import "ManetLabFramework+Internal.h"
#import "MLStackLayer.h"
#include <net/ethernet.h>

#define ML_ETHER_TYPE 0x88b5

@interface MLMessage (){
    
    NSString* from;         // sender MAC
    NSString* to;           // receiver MAC
    unsigned int taskId;    // msg task id for logging
    NSMutableData* msgData; // msg data (data & header)
    
}

@end

@implementation MLMessage

@synthesize from, to, taskId, msgData;

-(id)initWithData:(NSData*)data from:(NSString*)aSender to:(NSString*)aDestination andTask:(NSString*)aTaskId {
    self = [super init];
    if (self) {
        msgData = [data mutableCopy];
        taskId = [aTaskId intValue];
        to = [aDestination retain];
        from = [aSender retain];
    }
    return self;
}

-(void)addHeader:(const void *)header length:(NSUInteger)length{
    [msgData replaceBytesInRange:NSMakeRange(0, 0) withBytes:header length:length];
}

-(void)readHeader:(void *)header length:(NSUInteger)length {
    memcpy(header, [msgData mutableBytes], length);
}

-(void)readAndRemoveHeader:(void *)header length:(NSUInteger)length {
    [self readHeader:header length:length];
    [self removeHeaderOflength:length];
}

-(void)removeHeaderOflength:(NSUInteger)length {
    [msgData replaceBytesInRange:NSMakeRange(0, length) withBytes:NULL length:0];
}

-(NSString*)description {
    return [NSString stringWithFormat:@"[task %i: %li bytes from %@ to %@]",taskId,[msgData length],from,to];
}

- (id)copyWithZone:(NSZone *)zone {
    return [[[self class] allocWithZone:zone] initWithData:msgData from:from to:to andTask:[NSString stringWithFormat:@"%u",taskId]];
}

- (void)dealloc
{
    [from release];
    [to release];
    [msgData release];
    [super dealloc];
}

@end

@implementation MLMessage (Internal)

-(id)initWithBytes:(const void *)bytes length:(NSUInteger)length {
    self = [super init];
    if (self) {
        struct ether_header header;
        memcpy(&header, bytes, ETHER_HDR_LEN);
        if (header.ether_type == htons(ML_ETHER_TYPE)) {
            msgData = [[NSMutableData alloc] initWithBytes:(bytes+ETHER_HDR_LEN+sizeof(taskId)) length:(length-ETHER_HDR_LEN-sizeof(taskId))];
            from = [[NSString stringWithCString:ether_ntoa((struct ether_addr*)header.ether_shost) encoding:NSUTF8StringEncoding] retain];
            to = [[NSString stringWithCString:ether_ntoa((struct ether_addr*)header.ether_dhost) encoding:NSUTF8StringEncoding] retain];
            memcpy(&taskId, bytes+ETHER_HDR_LEN, sizeof(taskId));
        } else {
            return nil;
        }
    }
    return self;
}

-(NSData*)getSerializedMessage:(NSString*)localMAC {
    NSMutableData* serializedData = [NSMutableData dataWithData:msgData];
    [serializedData replaceBytesInRange:NSMakeRange(0,0) withBytes:&taskId length:sizeof(taskId)];
    struct ether_header header;
    memcpy(header.ether_shost, ether_aton([localMAC UTF8String]), ETHER_ADDR_LEN);
    memcpy(header.ether_dhost, ether_aton([to UTF8String]), ETHER_ADDR_LEN);
    header.ether_type = htons(ML_ETHER_TYPE);
    [serializedData replaceBytesInRange:NSMakeRange(0,0) withBytes:&header length:ETHER_HDR_LEN];
    return serializedData;
}

@end
