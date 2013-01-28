//
//  Fragmentation.h
//  MLBasePlugin
//
//  Created by Francois Vessaz on 9/6/12.
//  Copyright (c) 2012 UNIL - HEC - ISI - DopLab. All rights reserved.
//

#import <ManetLabFramework/MLStackLayer.h>
#include <net/ethernet.h>

typedef enum : Byte {
    
    kFragMsgTypeData = 0xF0,    // fragment of a message
    kFragMsgTypeNAK = 0xF1      // requires to re-send fragments (NSArray of NSNumber of fragments)
    
} FragMsgType;

typedef struct {
    
    FragMsgType msgType;        // 1 byte
    struct ether_addr sender;   // 6 bytes
    unsigned int session;       // 4 bytes
    unsigned int fragment;      // 4 bytes
    unsigned int total;         // 4 bytes
    
} FragHeader;                   // 19 bytes header

@interface Fragmentation : MLStackLayer

-(void)cleanupSession:(NSData*)sessionID; // cleanup a session (after timeout or message delivred)

@end
