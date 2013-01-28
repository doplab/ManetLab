//
//  MLPTestLayer.m
//  MLBasePlugin
//
//  Created by Francois Vessaz on 8/13/12.
//  Copyright (c) 2012 UNIL - HEC - ISI - DopLab. All rights reserved.
//

#import "MLPTestLayer.h"

@implementation MLPTestLayer

-(MLSendResult)sendData:(MLMessage*)dataToSend to:(NSString*)host {
    [self logToTask:[dataToSend headerForKey:@"mlTaskId"] event:@"POPOPOP send"];
    return kMLSendSuccess;
}

-(void)onData:(MLMessage*)receivedData from:(NSString*)sender {
    [self logToTask:[receivedData headerForKey:@"mlTaskId"] event:@"POPOPOP onData"];
}

@end
