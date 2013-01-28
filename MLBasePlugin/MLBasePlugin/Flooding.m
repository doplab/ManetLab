//
//  MLPTestLayer.m
//  MLBasePlugin
//
//  Created by Francois Vessaz on 8/13/12.
//  Copyright (c) 2012 UNIL - HEC - ISI - DopLab. All rights reserved.
//

#import "Flooding.h"

@interface Flooding () {
    
    NSMutableSet* _handledMsgs;
    
}

@end

@implementation Flooding

- (id)init
{
    self = [super init];
    if (self) {
        _handledMsgs = [NSMutableSet set];
    }
    return self;
}

-(MLSendResult)sendData:(MLMessage*)dataToSend to:(NSString*)host {
    [dataToSend setHeader:@"flooding" forKey:@"mlAlgo"];
    [_handledMsgs addObject:dataToSend.msg_UID];
    return [_lowerLayer sendData:dataToSend to:host];
}

-(void)onData:(MLMessage*)receivedData from:(NSString*)sender {
    if ([[receivedData headerForKey:@"mlAlgo"] isEqualToString:@"flooding"]) {
        if (![_handledMsgs member:receivedData.msg_UID]) {
            [_handledMsgs addObject:receivedData.msg_UID];
            [_upperLayer onData:receivedData from:sender];
            [_lowerLayer sendData:receivedData to:@"all"];
        }
    }
}

@end
