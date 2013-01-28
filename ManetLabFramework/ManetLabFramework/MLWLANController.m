//
//  WLANController.m
//  ManetLab
//
//  Created by François Vessaz on 8/17/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#include <arpa/inet.h>
#include <ifaddrs.h>

#import "MLWLANController.h"

@implementation MLWLANController

- (id)init
{
    self = [super init];
    if (self) {
        if ([CWInterface interface] != nil){
            selectedInteface = [[CWInterface interface] retain];
            selectedChannel = 11;
        } else {
            return nil;
        }
    }
    
    return self;
}

-(NSArray*)getAvailableInterfaces{
    NSEnumerator* interfacesEnumerator = [[CWInterface interfaceNames] objectEnumerator];
    NSString* interfaceName;
    NSMutableArray* result = [NSMutableArray array];
    while ((interfaceName = [interfacesEnumerator nextObject])){
        [result addObject:interfaceName];
    }
    return result;
}

-(BOOL)selectInterface:(NSString*)interfaceName {
    CWInterface* newInterface = [CWInterface interfaceWithName:interfaceName];
    if (newInterface != nil){
        [selectedInteface release];
        selectedInteface = [newInterface retain];
        return YES;
    }
    return NO;
}

-(NSString*)selectedInterface {
    return selectedInteface.interfaceName;
}

-(void)selectDefaultChannel:(int)channel {
    selectedChannel = channel;
}

-(BOOL)checkIfParamsAreEqualTo:(NSString*)ssidName andInterface:(NSString*)interfaceName andChannel:(int)channelNb {
    BOOL res = YES;
    res = res && [selectedInteface.ssid isEqualToString:ssidName];
    res = res && [selectedInteface.interfaceName isEqualToString:interfaceName];
    res = res && (selectedInteface.wlanChannel.channelNumber == channelNb);
    res = res && (selectedInteface.interfaceMode == kCWInterfaceModeIBSS);
    res = res && selectedInteface.powerOn;
    return res;
}

-(BOOL)startAdHocSession:(NSString*)sessionName {
    if ([self checkSelectedInterfaceForIBSS]){
        NSError* error;
        BOOL success = [selectedInteface startIBSSModeWithSSID:[[NSString stringWithString:sessionName] dataUsingEncoding:NSUTF8StringEncoding] security:kCWIBSSModeSecurityNone channel:selectedChannel password:nil error:&error];
        if (success) {
            return [self waitForIpaddress];
        }
    }
    return NO;
}

-(BOOL)startAdHocSecureSession:(NSString*)sessionName withPassword:(NSString*)password {
    if ([self checkSelectedInterfaceForIBSS]){
        NSError* error;
        BOOL success = [selectedInteface startIBSSModeWithSSID:[[NSString stringWithString:sessionName] dataUsingEncoding:NSUTF8StringEncoding] security:kCWIBSSModeSecurityWEP104 channel:selectedChannel password:password error:&error];
        if (success) {
            return [self waitForIpaddress];
        }
    }
    return NO;
}

-(void)disconnect {
    [selectedInteface disassociate];
}

-(BOOL)checkSelectedInterfaceForIBSS {
    if (selectedInteface == nil){
        return NO;
    }
    if ([selectedInteface.configuration requireAdministratorForAssociation]){
        return NO;
    }
    if ([selectedInteface.configuration requireAdministratorForIBSSMode]){
        return NO;
    }
    return YES;
}

-(BOOL)waitForIpaddress {
    for (int i=0;i<20;i++) {
        struct ifaddrs* interfaces = NULL;
        struct ifaddrs* cur_addr = NULL;
        int res = getifaddrs(&interfaces);
        if (res == 0){
            cur_addr = interfaces;
            while(cur_addr != NULL){
                if (strcmp(cur_addr->ifa_name,[[self selectedInterface] UTF8String])==0) {
                    if (cur_addr->ifa_addr->sa_family == PF_INET6){
                        sleep(1);
                        return YES;
                    } else {
                        sleep(1);
                    }
                }
                cur_addr = cur_addr->ifa_next;
            }
        }
        freeifaddrs(interfaces);
    }
    return NO;
}

-(void)dealloc {
    [selectedInteface release];
    [super dealloc];
}

@end