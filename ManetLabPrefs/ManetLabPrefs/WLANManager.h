//
//  WLANManager.h
//  ManetLabPrefs
//
//  Created by Francois Vessaz on 10/25/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WLANManager : NSObject

-(NSString*)getName;
-(NSEnumerator*)getAllNames;
-(NSArray*)getAllChannels;

@end
