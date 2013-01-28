//
//  MLControllerStream.m
//  ManetLabFramework
//
//  Created by Francois Vessaz on 11/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MLStreamsUtility.h"

#define ML_BUFFER_SIZE 32768

/*
 * Private methods
 */
@interface MLStreamsUtility (hidden)

-(void)parseData;
-(void)sendData;
-(void)error;

@end

@implementation MLStreamsUtility

/*
 * Init with streams and delegate. SSL settings should be applied before (due to client/server differences)
 */
- (id)initWithInputStream:(NSInputStream*)ins andOutputStream:(NSOutputStream*)outs delegate:(id<MLStreamsUtilityDelegate>)del {
    self = [super init];
    if (self) {
        delegate = del;
        bufferIn = [[NSMutableData data] retain];
        bufferOut = [[NSMutableData data] retain];
        streamIn = [ins retain];
        streamOut = [outs retain];
        [streamIn setDelegate:self];
        [streamOut setDelegate:self];
        [streamIn scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [streamOut scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [streamIn open];
        [streamOut open];
    }
    return self;
}

/*
 * Send a new dictionnary
 */
-(void)sendData:(NSDictionary*)dictToSend {
    NSData* dataToSend = [NSPropertyListSerialization dataWithPropertyList:dictToSend format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
    NSUInteger dataLength = [dataToSend length];
    [bufferOut appendBytes:&dataLength length:sizeof(dataLength)];
    [bufferOut appendData:dataToSend];
    [self sendData];
}

/*
 * Check if incoming dictionnary is complete and release it if necessary
 */
-(void)parseData {
    NSUInteger length = 0;
    NSUInteger headerSize = sizeof(length);
    
    if ([bufferIn length] >= headerSize) {
        [bufferIn getBytes:&length length:headerSize];
        if ([bufferIn length] >= (length + headerSize)) {
            NSData* newData = [bufferIn subdataWithRange:NSMakeRange(headerSize, length)];
            NSDictionary* newDict = [NSPropertyListSerialization propertyListFromData:newData mutabilityOption:0 format:NULL errorDescription:nil];
            [delegate onData:newDict];
            [bufferIn replaceBytesInRange:NSMakeRange(0, (length+headerSize)) withBytes:NULL length:0];
            
            // recursive call if there is more than one object
            [self parseData];
        }
    }
}

/*
 * Send data from OUT buffer if data are available
 */
-(void)sendData {
    @synchronized(self){
        if ([streamOut hasSpaceAvailable] && [bufferOut length] > 0){
            NSUInteger toSendLength = [bufferOut length];
            
            if (toSendLength > ML_BUFFER_SIZE) {
                toSendLength = ML_BUFFER_SIZE;
            }
            NSUInteger sendedLength = [streamOut write:[bufferOut bytes] maxLength:toSendLength];
            [bufferOut replaceBytesInRange:NSMakeRange(0, sendedLength) withBytes:NULL length:0];
        }
    }
}

/*
 * Notify delegate from error and cleanup
 */
-(void)error {
    [delegate onError];
}

/*
 * NSStream callbacks
 */
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)streamEvent {
    switch(streamEvent) {
        case NSStreamEventHasBytesAvailable:
            if (aStream == streamIn) {
                uint8_t buf[ML_BUFFER_SIZE];
                NSInteger len = 0;
                len = [streamIn read:buf maxLength:ML_BUFFER_SIZE];
                if(len > 0) {
                    [bufferIn appendBytes:(const void *)buf length:len];
                    [self parseData];
                } else if (len == 0) {
                    [delegate onClose];
                } else {
                    NSLog(@"MLController stream error: code %ld",len);
                    [self error];
                }
            }
            break;
        case NSStreamEventEndEncountered:
            [delegate onClose];
            break;
        case NSStreamEventHasSpaceAvailable:
            if (aStream == streamOut){
                [self sendData];
            }
            break;
        case NSStreamEventErrorOccurred:
            NSLog(@"MLController stream error: %@",[[aStream streamError] description]);
            [self error];
            break;
        default:
            break;
    }
}

/*
 * Close streams
 */
-(void)close {
    [streamIn close];
    [streamOut close];
    [streamIn removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [streamOut removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [streamIn setDelegate:nil];
    [streamOut setDelegate:nil];
    [streamOut release];
    [streamIn release];
    streamIn = nil;
    streamOut = nil;
}

/*
 * Cleanup
 */
- (void)dealloc {
    if (streamIn != nil || streamOut != nil) {
        [self close];
    }
    [bufferIn release];
    [bufferOut release];
    [super dealloc];
}

@end
