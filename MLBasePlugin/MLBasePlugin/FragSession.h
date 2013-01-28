//
//  FragSession.h
//  MLBasePlugin
//
//  Created by Francois Vessaz on 11/5/12.
//  Copyright (c) 2012 UNIL - HEC - ISI - DopLab. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MLMessage;
@class Fragmentation;

@interface FragSession : NSObject

@property (readonly) NSArray* outFragments;     // fragments sent in the session

-(id)initIncoming:(Fragmentation*)aFragLayer andID:(NSData*)aSessionID;     // new incoming session
-(id)initOutgoing:(Fragmentation*)aFragLayer andID:(NSData*)aSessionID;     // new outgoing session

-(void)newIncomingFragment:(MLMessage*)frag;    // new fragment for session
-(void)newOutgoingFragment:(MLMessage*)frag;    // new fragment for session

@end
