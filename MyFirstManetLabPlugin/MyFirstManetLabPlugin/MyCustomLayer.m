//
//  MyCustomLayer.m
//  MyFirstManetLabPlugin
//
//  Created by Francois Vessaz on 11/5/12.
//  Copyright (c) 2012 UNIL - HEC - ISI - DopLab. All rights reserved.
//

#import "MyCustomLayer.h"

/*
 * The MyCustomLayer class implements a simple flooding algorithm to demonstrate how the ManetLab API works.
 */

static int myCounter = 0;           // message sequence number generator for this host

/*
 * CustomHeader is a C structure containing the header of this layer. It should be added before sending further and removed before delivering further.
 */
typedef struct {
    
    Byte algoType;                  // 1 byte containing an algorithm identifier
    char senderMACaddress[17];      // 17 chars representing the MAC address of the sender (e.g: 12:34:56:78:90:AB)
    int seqNumber;                  // an int representing the unique sequence number
    
} CustomHeader;

@interface MyCustomLayer () {
    
    NSMutableSet* handledMessages;  // set of message IDs that have been handled by this layer.
    
}

@end

@implementation MyCustomLayer

/* 
 * init method
 */
- (id)init
{
    self = [super init];
    if (self) {
        handledMessages = [NSMutableSet set];                       // create an empty set
    }
    return self;
}

/*
 * Override this method from MLStackLayer to send a message.
 */
-(MLSendResult)send:(MLMessage*)msg {
    CustomHeader header;                                            // create a new header:
    
    header.algoType = 0xFF;                                         // set the algo type to 11111111 (arbitrary)
    NSString* myMACaddress = [self hostAddress];                    // return the MAC address of current host
    strcpy(header.senderMACaddress,[myMACaddress UTF8String]);      // set the MAC address
    header.seqNumber = myCounter++;                                 // set and increment the message sequence number using myCounter
    
    [msg addHeader:&header length:sizeof(CustomHeader)];            // add the header to the message. Every added header in a layer, should be removed by the same layer!!!
    
    NSString* msgID = [NSString stringWithFormat:@"%s:%i",header.senderMACaddress,header.seqNumber]; // unique message identifier composed by sender MAC address and unique sequence number.
    [handledMessages addObject:msgID];                              // add messageID to handled messages set to avoid re-sending it.
    
    [self logFor:msg event:@"I will send this message: %@",[msg description]];// log operations related to a message.
    
    return [self sendFurther:msg];                                  // send this message further: pass it to the underlying layer. If there is no underlying custom layer,
                                                                    // the message is sent via my wireless network interface.
}

/*
 * Override this method from MLStackLayer to handle received message.
 */
-(void)deliver:(MLMessage*)msg {
    [self logFor:msg event:@"A new message delivred from %@!",msg.from]; // log
    
    CustomHeader msgHeader;                                         // create empty header
    [msg readHeader:&msgHeader length:sizeof(CustomHeader)];        // read header of message
    
    if (msgHeader.algoType == 0xFF) {                               // if this is a message coming from a MyCustomLayer
        [self logFor:msg event:@"Message %i sent initially by %s",msgHeader.seqNumber,msgHeader.senderMACaddress]; // log
        
        NSString* msgID = [NSString stringWithFormat:@"%s:%i",msgHeader.senderMACaddress,msgHeader.seqNumber]; // unique message identifier built as a concatenation of the
                                                                    // sender's MAC address and the message's unique sequence number.
        if (![handledMessages containsObject:msgID]) {              // if messageID is not in set of previously handled messages...
            [handledMessages addObject:msgID];                      // ... add it!
            [self logFor:msg event:@"I will forward a message..."]; // log
            [self sendFurther:msg];                                 // send the message further
            
            [msg removeHeaderOflength:sizeof(CustomHeader)];        // remove the header
            [self deliverFurther:msg];                              // deliver the message to the upper layer.
        } else {
            [self logFor:msg event:@"I have already received this message..."]; // log
        }
    } else {
        [self logFor:msg event:@"Not a MyCustomLayer message..."];  // log
    }
}

@end
