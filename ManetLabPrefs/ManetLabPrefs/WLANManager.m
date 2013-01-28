//
//  WLANManager.m
//  ManetLabPrefs
//
//  Created by Francois Vessaz on 10/25/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "WLANManager.h"
#import <CoreWLAN/CoreWLAN.h>

@implementation WLANManager

-(NSString*)getName {
    if (kCFCoreFoundationVersionNumber < 635.0) {
        return [CWInterface interface].name;
    } else {
        return [CWInterface interface].interfaceName;
    }
}

-(NSEnumerator*)getAllNames {
    if (kCFCoreFoundationVersionNumber < 635.0) {
        return [[CWInterface supportedInterfaces] objectEnumerator];
    } else {
        return [[CWInterface interfaceNames] objectEnumerator];
    }
}

-(NSArray*)getAllChannels {
    NSMutableArray* channelsName = [NSMutableArray array];
    if (kCFCoreFoundationVersionNumber < 635.0) {
        for (NSNumber* channelNb in [CWInterface interface].supportedChannels) {
            [channelsName addObject:[NSString stringWithFormat:@"%i",[channelNb intValue]]];
        }
    } else {
        for (CWChannel* channel in [CWInterface interface].supportedWLANChannels) {
            [channelsName addObject:[NSString stringWithFormat:@"%li",[channel channelNumber]]];
        }
    }
    return channelsName;
}

@end
