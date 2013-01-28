//
//  SimpleFlooding.m
//  MLBasePlugin
//
//  Created by Arielle Moro on 16.11.12.
//  Copyright (c) 2012 UNIL - HEC - ISI - DopLab. All rights reserved.
//

#import "SimpleFlooding.h"

#define FLOODING_ALGO_ID 0x01     // 1 byte to identify simple flooding algo
#define FLOODING_ALGO_NAME @"FLOODING"

@implementation SimpleFlooding

/*
 * Standard initialisation
 */
-(id)init
{
    self = [super initWithProb:1.0 name:FLOODING_ALGO_NAME andAlgoId:FLOODING_ALGO_ID];
    return self;
}

/*
 * SimpleFlooding SEND
 */
-(MLSendResult)send:(MLMessage*)msg {
    return [super send:msg];
}

/*
 * SimpleFlooding DELIVER
 */
-(void)deliver:(MLMessage*)msg {
    [super deliver:msg];
}

@end