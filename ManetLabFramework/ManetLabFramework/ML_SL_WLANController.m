//
//  WLANController.m
//  ManetLab
//
//  Created by François Vessaz on 8/17/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ML_SL_WLANController.h"

@interface ML_SL_WLANController() {
@private

}
-(BOOL)checkForExistingNetworkAndConnect:(NSString*)ssid withPassword:(NSString*)password;
@end

@implementation ML_SL_WLANController

-(NSArray*)getAvailableInterfaces{
    return [CWInterface supportedInterfaces];
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
    return selectedInteface.name;
}

-(void)selectDefaultChannel:(int)channel {
    selectedChannel = channel;
}

-(BOOL)checkIfParamsAreEqualTo:(NSString*)ssidName andInterface:(NSString*)interfaceName andChannel:(int)channelNb {
    BOOL res = YES;
    res = res && [selectedInteface.ssid isEqualToString:ssidName];
    res = res && [selectedInteface.name isEqualToString:interfaceName];
    res = res && ([selectedInteface.channel intValue] == channelNb);
    res = res && selectedInteface.power;
    return res;
}

-(BOOL)startAdHocSession:(NSString*)sessionName {
    if ([self checkSelectedInterfaceForIBSS]){
        if ([self checkForExistingNetworkAndConnect:sessionName withPassword:nil]) {
            return YES;
        }
        NSError* error;
        NSMutableDictionary* params = [NSMutableDictionary dictionary];
        [params setValue:sessionName forKey:kCWIBSSKeySSID];
        [params setValue:[NSNumber numberWithInt:selectedChannel] forKey:kCWIBSSKeyChannel];
        BOOL res = [selectedInteface enableIBSSWithParameters:params error:&error];
        if (res) {
            return [self waitForIpaddress];
        }
    }
    return NO;
}

-(BOOL)startAdHocSecureSession:(NSString*)sessionName withPassword:(NSString*)password {
    if ([self checkSelectedInterfaceForIBSS]){
        if ([self checkForExistingNetworkAndConnect:sessionName withPassword:password]) {
            return YES;
        }
        NSError* error;
        NSMutableDictionary* params = [NSMutableDictionary dictionary];
        [params setValue:sessionName forKey:kCWIBSSKeySSID];
        [params setValue:[NSNumber numberWithInt:selectedChannel] forKey:kCWIBSSKeyChannel];
        [params setValue:password forKey:kCWIBSSKeyPassphrase];
        BOOL res = [selectedInteface enableIBSSWithParameters:params error:&error];
        if (res) {
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
    if (selectedInteface.configuration.requireAdminForNetworkChange){
        return NO;
    }
    if (selectedInteface.configuration.requireAdminForIBSSCreation){
        return NO;
    }
    return YES;
}

-(BOOL)checkForExistingNetworkAndConnect:(NSString*)ssid withPassword:(NSString*)password {
    NSError* error;
    NSArray* nets = [selectedInteface scanForNetworksWithParameters:nil error:&error];
    for (CWNetwork* net in nets) {
        if ([net.ssid isEqualToString:ssid]) {
            NSMutableDictionary* params = [NSMutableDictionary dictionary];
            [params setValue:password forKey:kCWAssocKeyPassphrase];
            BOOL res = [selectedInteface associateToNetwork:net parameters:params error:&error];
            if (res) {
                return [self waitForIpaddress];
            }
        }
    }
    return NO;
}

@end
