//
//  ManetLabPrefs.m
//  ManetLabPrefs
//
//  Created by François Vessaz on 9/13/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#include <arpa/inet.h>
#include <ifaddrs.h>
#include <sys/socket.h>
#include <sys/un.h>
#import <SystemConfiguration/SystemConfiguration.h>

#import "ManetLabPrefs.h"
#import "mondoSwitch/MondoSwitch.h"

// Could be removed if we retrieved available wlan interfaces from mllauncherd via UNIX socket
#import "WLANManager.h"

#define APP_NAME "ManetLabPref"
#define APP_ID "ch.unil.doplab.manetlab"
#define SOCKET_PATH "/var/tmp/ch.unil.doplab.manetlab/prefsocket"

@implementation ManetLabPrefs
@synthesize mainSwitch, onLabel, adhocInterfaceSelector, controlInterfaceSelector, roleSelector, controllerSelector,wlanNameSelector,passwordSelector,channelSelector;

// Init logging and UNIX socket with mllauncherd daemon
- (id)initWithBundle:(NSBundle *)bundle {
    self = [super initWithBundle:bundle];
    if (self) {
        // Init logging
        logclient = asl_open(APP_NAME, APP_ID, 0);
        logmsg = asl_new(ASL_TYPE_MSG);
        asl_set(logmsg, ASL_KEY_SENDER, APP_NAME);
        asl_set(logmsg, ASL_KEY_FACILITY, APP_ID);
        asl_log(logclient, logmsg, ASL_LEVEL_NOTICE,"%s (%s) started", APP_NAME, APP_ID);
        
        // Init wlan names
        wlan = [[WLANManager alloc] init];
        
        // Init socket with mllauncherd
        errorOnInit = NO;
        int sockFD = -1;
        sockFD = socket(AF_UNIX, SOCK_STREAM, 0);
        if (sockFD < 0) {
            asl_log(logclient, logmsg, ASL_LEVEL_ERR, "mllauncherd socket error (%i)",errno);
            errorOnInit = YES;
        }
        struct sockaddr_un connReq;
        connReq.sun_len    = sizeof(connReq);
        connReq.sun_family = AF_UNIX;
        strcpy(connReq.sun_path,SOCKET_PATH);
        int i = connect(sockFD, (struct sockaddr *) &connReq, (socklen_t)SUN_LEN(&connReq));
        if (i < 0) {
            asl_log(logclient, logmsg, ASL_LEVEL_ERR, "mllauncherd connection error (%i)",errno);
            errorOnInit = YES;
        }
        sockCF = CFSocketCreateWithNative(NULL,(CFSocketNativeHandle)sockFD,kCFSocketNoCallBack,NULL,NULL);
        if (sockCF == NULL) {
            asl_log(logclient, logmsg, ASL_LEVEL_ERR, "mllauncherd CFSocketRef error");
            errorOnInit = YES;
        }
        
        prefs = nil;
        prefs = [(NSDictionary*)CFPreferencesCopyMultiple(CFPreferencesCopyKeyList(CFSTR(APP_ID), kCFPreferencesAnyUser, kCFPreferencesCurrentHost), CFSTR(APP_ID), kCFPreferencesAnyUser, kCFPreferencesCurrentHost) mutableCopy];
        
        if ([prefs count] == 0) {
            asl_log(logclient, logmsg, ASL_LEVEL_ERR, "Error on pref init, unable to retrieve preferences from plist");
            errorOnInit = YES;
        } else {
            _on = [[prefs valueForKey:@"startMLAgent"] boolValue];
        }
        
        browser = [[NSNetServiceBrowser alloc] init];
        [browser setDelegate:self];
        [browser searchForServicesOfType:@"_manetlab._tcp" inDomain:@""];
    }
    return self;
}

// Set the initial value
- (void)mainViewDidLoad
{
    // Bind main switch value to pref. cache
    mainSwitch.on = _on;
    [self bind:@"on" toObject:mainSwitch withKeyPath:@"on" options:nil];
    
    // Get interfaces list
    NSMutableArray* availableInterfaces = [NSMutableArray array];
    struct ifaddrs* interfaces = NULL;
    struct ifaddrs* cur_addr = NULL;
    getifaddrs(&interfaces);
    cur_addr = interfaces;
    while(cur_addr != NULL){
        [availableInterfaces addObject:[NSString stringWithUTF8String:cur_addr->ifa_name]];
        cur_addr = cur_addr->ifa_next;
    }
    freeifaddrs(interfaces);
    // Could be removed if we retrieved available wlan interfaces from mllauncherd via UNIX socket
    NSEnumerator* interfacesEnumerator = [wlan getAllNames];
    NSString* interfaceName;
    while ((interfaceName = [interfacesEnumerator nextObject])){
        [adhocInterfaceSelector addItemWithTitle:interfaceName];
        if ([availableInterfaces containsObject:interfaceName]) {
            [availableInterfaces removeObject:interfaceName];
        }
    }
    [controlInterfaceSelector addItemsWithTitles:availableInterfaces];
    
    [channelSelector addItemsWithTitles:[wlan getAllChannels]];
    
    [controllerSelector addItemWithObjectValue:@"default"];
    
    // Update display
    [self updateDisplay];
    
    // Display Error on init dialog
    if (errorOnInit) {
        asl_log(logclient, logmsg, ASL_LEVEL_ERR, "Display error on init modal dialog");
        NSAlert* alert = [NSAlert alertWithMessageText:@"ManetLab error" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"ManetLab was not able to load correctly.\nYour preferences may be not applied."];
        [alert runModal];
    }
}

// Triggered on other changes
-(IBAction)onChange:(id)sender {
    BOOL isController = ([roleSelector selectedSegment]==1);
    
    // set the new values
    [prefs setValue:[adhocInterfaceSelector titleOfSelectedItem] forKey:@"adhocInterface"];
    [prefs setValue:[controlInterfaceSelector titleOfSelectedItem] forKey:@"controlInterface"];
    [prefs setValue:[NSNumber numberWithBool:isController] forKey:@"isController"];
    [prefs setValue:[wlanNameSelector stringValue] forKey:@"wlanName"];
    [prefs setValue:[passwordSelector stringValue] forKey:@"wlanPassword"];
    [prefs setValue:[NSNumber numberWithInt:[[channelSelector titleOfSelectedItem] intValue]] forKey:@"wlanChannel"];
    if (isController) {
        SCDynamicStoreRef store = SCDynamicStoreCreate(NULL, CFSTR(APP_NAME), NULL, NULL);
        NSString* pattern = [NSString stringWithFormat:@"State:/Network/Interface/%@/IPv4",[controlInterfaceSelector titleOfSelectedItem]];
        NSDictionary* ipDict = nil;
        ipDict = SCDynamicStoreCopyValue(store, (CFStringRef)pattern);
        NSString* ipAddress = nil;
        if (ipDict){
            NSArray* ipArray = [ipDict valueForKey:@"Addresses"];
            if ([ipArray count] > 0) {
                ipAddress = [ipArray objectAtIndex:0];
            }
        }
        if (ipAddress) {
            [prefs setValue:ipAddress forKey:@"controller"];
        }
        [ipDict release];
    } else {
        [prefs setValue:[controllerSelector stringValue] forKey:@"controller"];
    }
    
    [self updateDisplay];
    
    // Send updates to pref socket
    [self sendPrefs];
}

// set the current value
-(void)updateDisplay {
    [adhocInterfaceSelector selectItemWithTitle:[prefs valueForKey:@"adhocInterface"]];
    [controlInterfaceSelector selectItemWithTitle:[prefs valueForKey:@"controlInterface"]];
    [wlanNameSelector setStringValue:[prefs valueForKey:@"wlanName"]];
    [passwordSelector setStringValue:[prefs valueForKey:@"wlanPassword"]];
    [channelSelector selectItemWithTitle:[[prefs valueForKey:@"wlanChannel"] stringValue]];
    if ([(NSNumber*)[prefs valueForKey:@"isController"] boolValue]){
        [roleSelector setSelectedSegment:1];
        [controllerSelector setEnabled:NO];
        [wlanNameSelector setEnabled:YES];
        [passwordSelector setEnabled:YES];
        [channelSelector setEnabled:YES];
    } else {
        [roleSelector setSelectedSegment:0];
        [controllerSelector setEnabled:YES];
        [wlanNameSelector setEnabled:NO];
        [passwordSelector setEnabled:NO];
        [channelSelector setEnabled:NO];
    }
    [controllerSelector setStringValue:[prefs valueForKey:@"controller"]];
    NSNumber* tmp = [prefs valueForKey:@"startMLAgent"];
    if ([tmp boolValue]) {
        [onLabel setTextColor:[NSColor alternateSelectedControlColor]];
    } else {
        [onLabel setTextColor:[NSColor disabledControlTextColor]];
    }
    BOOL enabled = ![tmp boolValue];
    [adhocInterfaceSelector setEnabled:enabled];
    [controlInterfaceSelector setEnabled:enabled];
    [controllerSelector setEnabled:(enabled && [roleSelector selectedSegment]==0)];
    [wlanNameSelector setEnabled:(enabled && [roleSelector selectedSegment]==1)];
    [passwordSelector setEnabled:(enabled && [roleSelector selectedSegment]==1)];
    [channelSelector setEnabled:(enabled && [roleSelector selectedSegment]==1)];
    [roleSelector setEnabled:(enabled)];
    
}

-(BOOL)isOn {
    return _on;
}

-(void)setOn:(BOOL)newValue {
    if (newValue != _on) {
        _on = newValue;
        [prefs setValue:[NSNumber numberWithBool:newValue] forKey:@"startMLAgent"];
        [self onChange:self];
    }
}

// send prefs to framework
-(void)sendPrefs {
    NSData* dictToSend = [NSPropertyListSerialization dataWithPropertyList:prefs format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
    NSUInteger dictLength = [dictToSend length];
    NSMutableData* dataToSend = [NSMutableData data];
    [dataToSend appendBytes:&dictLength length:sizeof(dictToSend)];
    [dataToSend appendData:dictToSend];
    CFSocketError res = CFSocketSendData(sockCF, NULL, (CFDataRef)dataToSend, 0);
    if (res != kCFSocketSuccess) {
        asl_log(logclient, logmsg, ASL_LEVEL_ERR, "Could not contact mllauncherd to update prefs");
    }
}

// NSNetService callback
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    [controllerSelector addItemWithObjectValue:[aNetService name]];
}

// NSNetService callback
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    [controllerSelector removeItemWithObjectValue:[aNetService name]];
}

-(void)dealloc {
    [browser stop];
    [browser release];
    CFSocketInvalidate(sockCF);
    CFRelease(sockCF);
    [prefs release];
    [controllerSelector release];
    [wlanNameSelector release];
    [passwordSelector release];
    [channelSelector release];
    [roleSelector release];
    [controlInterfaceSelector release];
    [adhocInterfaceSelector release];
    [mainSwitch release];
    [onLabel release];
    [wlan release];
    [super dealloc];
}

@end