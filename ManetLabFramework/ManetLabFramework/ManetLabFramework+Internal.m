//
//  ManetLabFramework+Internal.m
//  ManetLabFramework
//
//  Created by Francois Vessaz on 11/29/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <SystemConfiguration/SystemConfiguration.h>

#import "ManetLabFramework+Internal.h"
#import "MLController.h"
#import "MLAgent.h"
#import "MLWLANController.h"
//#import "ML_SL_WLANController.h"
#import "MLUNIXSocketServer.h"
#import "MLLowestLayer.h"

#define EXEC_NAME "ManetLabFramework"
#define EXEC_ID "ch.unil.doplab.manetlabframework"
#define CONTROLLER_SERVICE @"_manetlab._tcp"
#define APP_ID "ch.unil.doplab.manetlab"
#define MONITOR_AIRPORT "ch.unil.doplab.wlan"
#define MAX_RESTART_ATTEMPTS 3



@interface ManetLabFramework() <NSNetServiceBrowserDelegate, MLUNIXSocketServerDelegate> {
    
    MLController* controller;               // Local ML network controller if host isController
    MLAgent* controllerProxy;               // Selected ML control interface
    MLWLANController* wlan;                 // SL or Lion WLAN controller
    MLState state;                          // current state of WLAN
    aslclient logclient;                    // log client
    aslmsg logmsg;                          // log msg
    NSDictionary* currentPrefs;             // values of preferences
    NSNetServiceBrowser* serviceBrowser;    // Browser for ML network controllers
    NSMutableArray* services;               // List of published services
    BOOL waitOnBonjour;                     // flag YES if need to connect bonjour controller
    SCDynamicStoreRef store;                // System configuration store used to monitor wlan changes
    int restartAttempt;                     // number of ateempt to restart after being in kMLError state
    MLUNIXSocketServer* prefSocketServer;   // UNIX socket server for prefs updates
    MLLowestLayer* lowestLayer;              // Lowest adhoc layer on WLAN interface
    
}

-(NSDictionary*)initPrefs;
-(void)start;
-(void)connectBonjourController;
-(void)startWLAN;
-(void)started;
-(void)checkWLANchanges:(NSArray*)keys;
-(void)stop;
-(void)initPrefSocket;
-(void)errorMode:(id)arg;

void airportStateCallback(SCDynamicStoreRef store, CFArrayRef changedKeys, void* info);

@end

/*
 * Framework singleton. Main entry point.
 */
static ManetLabFramework* singleton = nil;  // singleton instance

@implementation ManetLabFramework

/*
 * Get singleton instance
 */
+(ManetLabFramework*)sharedInstance {
    if (singleton == nil) {
        singleton = [[[ManetLabFramework alloc] init] autorelease];
    }
    return singleton;
}

/*
 * Allocate memory for singleton. Can be called only once.
 */
+(id)alloc {
    if (singleton == nil) {
        singleton = [super alloc];
        return singleton;
    } else {
        [singleton logWithLevel:ASL_LEVEL_ERR andMsg:@"Attempt to create a second instance of framework singleton."];
    }
    return nil;
}

/*
 * Basic init from singleton: logging, ivars, wlan controller and bonjour discovery.
 */
-(id)init {
    self = [super init];
    if (self) {
        // Init logging
        logclient = asl_open(EXEC_NAME, EXEC_ID,0);
        logmsg = asl_new(ASL_TYPE_MSG);
        if (logclient == NULL || logmsg == NULL){
            return nil;
        }
        asl_set(logmsg, ASL_KEY_FACILITY, EXEC_ID);
        asl_set(logmsg, ASL_KEY_SENDER, EXEC_NAME);
        asl_log(logclient, logmsg, ASL_LEVEL_NOTICE, "%s (%s) started", EXEC_NAME, EXEC_ID);
        
        restartAttempt = 0;
        self.state = kMLStopped;
        currentPrefs = nil;
        controller = nil;
        controllerProxy = nil;
        lowestLayer = nil;
        
        // init controller instance for SL or Lion
        //if (kCFCoreFoundationVersionNumber < 635.0) {
        //    wlan = [[ML_SL_WLANController alloc] init];
        //} else {
            wlan = [[MLWLANController alloc] init];
        //}
        if (wlan == nil) {
            asl_log(logclient, logmsg, ASL_LEVEL_ERR, "Unable to instantiate WLAN controller");
            return nil;
        }
        
        // Init Bonjour discovery
        services = [[NSMutableArray array] retain];
        serviceBrowser = [[NSNetServiceBrowser alloc] init];
        [serviceBrowser setDelegate:self];
        [serviceBrowser searchForServicesOfType:CONTROLLER_SERVICE inDomain:@""];
        waitOnBonjour = NO;
        
        // Init pref UNIX socket
        [self initPrefSocket];
    }
    return self;
}

/*
 * Main entry point from framework. Check APP_ID prefererences (/Library/Preferences/ch.unil.doplab.manetlab.plist)
 */
-(void)checkPrefsUpdates {
    // Load prefs or init them
    if (currentPrefs != nil) {
        [currentPrefs release];
    }
    CFArrayRef prefKeys = CFPreferencesCopyKeyList(CFSTR(APP_ID), kCFPreferencesAnyUser, kCFPreferencesCurrentHost);
    if (prefKeys != NULL) {
        currentPrefs = (NSDictionary*)CFPreferencesCopyMultiple(prefKeys, CFSTR(APP_ID), kCFPreferencesAnyUser, kCFPreferencesCurrentHost);
        CFRelease(prefKeys);
    } else {
        currentPrefs = [[self initPrefs] retain];
    }
    if (currentPrefs == nil){
        [self logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to get required preferences for ML framework."];
        return;
    }
    
    // Start / Stop ML framework corresponding to prefs value
    BOOL isStarted = [(NSNumber*)[currentPrefs valueForKey:@"startMLAgent"] boolValue];
    if (isStarted && (self.state == kMLStopped || self.state == kMLError)) {
        [self logWithLevel:ASL_LEVEL_NOTICE andMsg:@"Initiating start."];
        [self start];
    } else if (!isStarted && (self.state == kMLStarted || self.state == kMLWaitingController || self.state == kMLWaitingWLAN)) {
        [self logWithLevel:ASL_LEVEL_NOTICE andMsg:@"Initiating stop."];
        [self stop];
    }
}

/*
 * Cleanup
 */
-(void)dealloc {
    if (self.state == kMLStarted) {
        [self stop];
    }
    
    [currentPrefs release];
    [serviceBrowser stop];
    [serviceBrowser release];
    [services release];
    [wlan release];
    [prefSocketServer release];
    
    asl_log(logclient, logmsg, ASL_LEVEL_NOTICE, "Framework singleton instance destroyed.");
    asl_close(logclient);
    
    [super dealloc];
}


/*
 * Default preferences used on first launch of framework to create pref .plist file
 */
-(NSDictionary*)initPrefs {
    CFMutableDictionaryRef initPrefs = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionaryAddValue(initPrefs, CFSTR("startMLAgent"), kCFBooleanFalse);
    CFDictionaryAddValue(initPrefs, CFSTR("controlInterface"), CFSTR("en0"));
    CFDictionaryAddValue(initPrefs, CFSTR("adhocInterface"), [wlan selectedInterface]);
    CFDictionaryAddValue(initPrefs, CFSTR("controller"), CFSTR("default"));
    CFDictionaryAddValue(initPrefs, CFSTR("isController"), kCFBooleanFalse);
    CFDictionaryAddValue(initPrefs, CFSTR("wlanName"), CFSTR("manet"));
    CFDictionaryAddValue(initPrefs, CFSTR("wlanPassword"), CFSTR("1234567890123"));
    int defaultChannel = 11;
    CFNumberRef channel = CFNumberCreate(NULL, kCFNumberIntType, &defaultChannel);
    CFDictionaryAddValue(initPrefs, CFSTR("wlanChannel"), channel);
    CFRelease(channel);
    CFPreferencesSetMultiple(initPrefs, NULL, CFSTR(APP_ID), kCFPreferencesAnyUser, kCFPreferencesCurrentHost);
    if (!CFPreferencesSynchronize(CFSTR(APP_ID), kCFPreferencesAnyUser, kCFPreferencesCurrentHost)){
        asl_log(logclient, logmsg, ASL_LEVEL_ERR, "Unable to set initial preferences.");
        return nil;
    }
    NSDictionary* res = (NSDictionary*)initPrefs;
    [res autorelease];
    asl_log(logclient, logmsg, ASL_LEVEL_NOTICE, "No prefs found. Preferences initialized.");
    return res;
}

/*
 * Init UNIX socket server for pref updates
 */
-(void)initPrefSocket {
    prefSocketServer = [[MLUNIXSocketServer alloc] initWithPath:@"/var/tmp/ch.unil.doplab.manetlab/prefsocket" andDelegate:self];
}

/*
 * Request manetlab network to start. Create controller if needed.
 */
-(void)start {
    self.state = kMLWaitingController;
    if ([(NSNumber*)[currentPrefs valueForKey:@"isController"] boolValue]) {
        controller = [[MLController alloc] initWithInterface:[currentPrefs valueForKey:@"controlInterface"]];
        if (controller == nil) {
            [self goIntoErrorMode];
        }
    } else {
        [self connectController];
    }
}

/*
 * Connect controller of ML network available via Bonjour and checkin to get adhoc network parameters
 */
-(void)connectBonjourController {
    if (waitOnBonjour && [services count] > 0) {
        waitOnBonjour= NO;
        controllerProxy = [[MLAgent alloc] initWithService:[services objectAtIndex:0]];
        if (controllerProxy != nil){
            [controllerProxy checkinWithAdhocInterface:[currentPrefs valueForKey:@"adhocInterface"]];
        } else {
            [[ManetLabFramework sharedInstance] goIntoErrorMode];
        }
    }
}

/*
 * Create 802.11 network in IBSS mode
 */
-(void)startWLAN {
    self.state = kMLWaitingWLAN;
    [wlan disconnect];
    [wlan selectInterface:[currentPrefs objectForKey:@"adhocInterface"]];
    [wlan selectDefaultChannel:[(NSNumber*)[controllerProxy.wlanSettings objectForKey:@"channel"] intValue]];
    [wlan startAdHocSecureSession:[controllerProxy.wlanSettings objectForKey:@"ssid"] withPassword:[controllerProxy.wlanSettings objectForKey:@"password"]];
}

/*
 * System config callback. Check if airport state is right. Restart WLAN if needed. Notify singleton from successful start of ML network.
 */
-(void)checkWLANchanges:(NSArray*)keys {
    NSString* pattern = [NSString stringWithFormat:@"State:/Network/Interface/%@/AirPort",[currentPrefs objectForKey:@"adhocInterface"]];
    if ([keys containsObject:pattern]) {
        NSDictionary* curWLANsettings = SCDynamicStoreCopyValue(store, (CFStringRef)pattern);
        NSString* curWLANname = [curWLANsettings valueForKey:@"SSID_STR"];
        if ([[controllerProxy.wlanSettings valueForKey:@"ssid"] isEqualToString:curWLANname] && self.state == kMLWaitingWLAN) {
            [self started];
        } else if (![[controllerProxy.wlanSettings valueForKey:@"ssid"] isEqualToString:curWLANname]) {
            [self logWithLevel:ASL_LEVEL_NOTICE andMsg:@"Restarting adhoc connection due to external WLAN change."];
            [self startWLAN];
        }
        [curWLANsettings release];
    }
}

/*
 * Network (control and adhoc links) up and running
 */
-(void)started {
    if (lowestLayer != nil) {
        [lowestLayer stop];
        [lowestLayer release];
        lowestLayer = nil;
    }
    lowestLayer = [[MLLowestLayer alloc] initOnInterface:[currentPrefs valueForKey:@"adhocInterface"]];
    if (lowestLayer != nil) {
        [controllerProxy reconnectStack];
        self.state = kMLStarted;
    } else {
        [self goIntoErrorMode];
    }
}

/*
 * Request framework stop. Disconnect from adhoc network, ML controller, and stop controller if needed.
 */
-(void)stop {
    self.state = kMLStopping;
    
    waitOnBonjour = NO;
    if (lowestLayer != nil){
        [lowestLayer stop];
        [lowestLayer release];
        lowestLayer = nil;
    }
    
    if (store != NULL) {
        SCDynamicStoreSetNotificationKeys(store,NULL,NULL);
        CFRelease(store);
        store = NULL;
    }
    [wlan disconnect];
    if (controllerProxy != nil){
        [controllerProxy disconnect];
        [controllerProxy release];
        controllerProxy = nil;
    }
    if (controller != nil) {
        [controller stopServer];
        [controller release];
        controller = nil;
    }
    
    self.state = kMLStopped;
}

/*
 * Pref socket callback
 */
-(void)onData:(NSDictionary*)newData {
    // Check if new prefs are valid
    NSArray* keys = [newData allKeys];
    if ([keys containsObject:@"controlInterface"] && 
        [keys containsObject:@"adhocInterface"] &&
        [keys containsObject:@"startMLAgent"] &&
        [keys containsObject:@"isController"] &&
        [keys containsObject:@"wlanName"] &&
        [keys containsObject:@"wlanPassword"] &&
        [keys containsObject:@"wlanChannel"] &&
        [keys containsObject:@"controller"]) {
        
        // Write new preferences
        CFPreferencesSetMultiple((CFDictionaryRef)newData, NULL, CFSTR(APP_ID), kCFPreferencesAnyUser, kCFPreferencesCurrentHost);
        bool res = CFPreferencesSynchronize(CFSTR(APP_ID), kCFPreferencesAnyUser, kCFPreferencesCurrentHost);
        if (res){
            [self logWithLevel:ASL_LEVEL_NOTICE andMsg:@"Preferences updated"];
            [self checkPrefsUpdates];
        } else {
            [self logWithLevel:ASL_LEVEL_ERR andMsg:@"Could not synchronize new preferences"];
        }
    } else {
        [self logWithLevel:ASL_LEVEL_ERR andMsg:@"New preferences have invalid/missing keys"];
    }
}

/*
 * Pref socket callback
 */
-(void)onClose {
    // nothing
}



/*
 * Bonjour callback
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    [services addObject:aNetService];
    if (!moreComing) {
        [self connectBonjourController];
    }
}

/*
 * Bonjour callback
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    if ([[services objectAtIndex:0] isEqualTo:aNetService] && self.state == kMLStarted) {
        [self logWithLevel:ASL_LEVEL_ERR andMsg:@"Current Bonjour controller disconnected. No more controller."];
        [self goIntoErrorMode];
    }
    [services removeObject:aNetService];
}

-(void)errorMode:(id)arg {
    self.state = kMLError;
    restartAttempt++;
    [self logWithLevel:ASL_LEVEL_CRIT andMsg:@"An error occured: ML framework stop all its services."];
    
    waitOnBonjour = [[currentPrefs valueForKey:@"controller"] isEqualToString:@"default"];
    if (lowestLayer != nil){
        [lowestLayer stop];
        [lowestLayer release];
        lowestLayer = nil;
    }
    
    if (store != NULL) {
        SCDynamicStoreSetNotificationKeys(store,NULL,NULL);
        CFRelease(store);
        store = NULL;
    }
    [wlan disconnect];
    if (controllerProxy != nil){
        [controllerProxy disconnect];
        [controllerProxy release];
        controllerProxy = nil;
    }
    if (controller != nil) {
        [controller stopServer];
        [controller release];
        controller = nil;
    }
    
    if (restartAttempt <= MAX_RESTART_ATTEMPTS) {
        [self logWithLevel:ASL_LEVEL_NOTICE andMsg:@"Attempting to restart framework in %i seconds.",restartAttempt];
        sleep(restartAttempt);
        [self start];
    } else if (restartAttempt > MAX_RESTART_ATTEMPTS){
        [self logWithLevel:ASL_LEVEL_ALERT andMsg:@"ALERT: Not able to start ML framework. Stopping."];
        self.state = kMLStopped;
    }
}

/*
 * System config callback
 */
void airportStateCallback(SCDynamicStoreRef store, CFArrayRef changedKeys, void* info) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    [[ManetLabFramework sharedInstance] checkWLANchanges:(NSArray*)changedKeys];
    [pool release];
}

@end

/*
 * ManetLabFramework singleton internal implementation
 */
@implementation ManetLabFramework (Internal)

/*
 * Set framework state
 */
-(void)setState:(MLState)newState {
    state = newState;
    switch (newState) {
        case kMLStopped:
            [self logWithLevel:ASL_LEVEL_NOTICE andMsg:@"ML framework state: STOPPED"];
            break;
        case kMLWaitingController:
            [self logWithLevel:ASL_LEVEL_NOTICE andMsg:@"ML framework state: WAITING CONTROLLER"];
            break;
        case kMLWaitingWLAN:
            [self logWithLevel:ASL_LEVEL_NOTICE andMsg:@"ML framework state: WAITING WLAN"];
            break;
        case kMLStarted:
            restartAttempt = 0;
            [self logWithLevel:ASL_LEVEL_NOTICE andMsg:@"ML framework state: STARTED"];
            break;
        case kMLStopping:
            [self logWithLevel:ASL_LEVEL_NOTICE andMsg:@"ML framework state: STOPPING"];
            break;
        case kMLError:
            [self logWithLevel:ASL_LEVEL_ERR andMsg:@"ML framework state: ERROR"];
            break;
        default:
            break;
    }
}

/*
 * Get framework state
 */
-(MLState)state {
    return state;
}

/*
 * Get lowest layer (MLUDP6Server) connected to WLAN
 */
-(MLLowestLayer*)getLowestLayer {
    return lowestLayer;
}

/*
 * Framework log utility.
 */
-(void)logWithLevel:(int)level andMsg:(NSString*)format, ... {
    va_list args;
    va_start(args, format);
    NSString* res = [[NSString alloc] initWithFormat:format arguments:args];
    asl_log(logclient, logmsg, level, "%s",[res UTF8String]);
    [res release];
    va_end(args);
}

/*
 * Switch to error state and do some cleanup. Try to restart after a delay.
 */
-(void)goIntoErrorMode {
    // start proceeding error in a new thread
    [self performSelectorOnMainThread:@selector(errorMode:) withObject:nil waitUntilDone:NO];
    // kill and restart runloop???
}

/*
 * Register for airport changes
 */
-(void)connectWLAN {
    store = SCDynamicStoreCreate(NULL, CFSTR(MONITOR_AIRPORT), airportStateCallback, NULL);
    NSString* pattern = [NSString stringWithFormat:@"State:/Network/Interface/%@/AirPort",[currentPrefs objectForKey:@"adhocInterface"]];
    if (SCDynamicStoreSetNotificationKeys(store, NULL, (CFArrayRef)[NSArray arrayWithObject:pattern])){
        CFRunLoopSourceRef rls = SCDynamicStoreCreateRunLoopSource(NULL, store, 0);
        if (rls == NULL) {
            asl_log(logclient, logmsg, ASL_LEVEL_ERR, "Unable to create runloop source for Dynamic Store keys to monitor");
        } else {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
            CFRelease(rls);
        }
    }
    [self startWLAN];
}

/*
 * Return current preferences
 */
-(NSDictionary*)getPrefs {
    return currentPrefs;
}

/*
 * Connect controller of ML network and checkin to get adhoc network parameters
 */
-(void)connectController {
    NSString* controllerName = [currentPrefs valueForKey:@"controller"];
    if ([controllerName isEqualToString:@"default"]) {
        waitOnBonjour = YES;
        [self connectBonjourController];
    } else {
        NSHost* host = nil;
        host = [NSHost hostWithName:controllerName];
        if ([[host addresses] count] > 0) {
            controllerProxy = [[MLAgent alloc] initWithHost:host];
        } else {
            NSNetService* service = [[[NSNetService alloc] initWithDomain:@"local." type:CONTROLLER_SERVICE name:controllerName] autorelease];
            controllerProxy = [[MLAgent alloc] initWithService:service];
        }
        if (controllerProxy != nil){
            [controllerProxy checkinWithAdhocInterface:[currentPrefs valueForKey:@"adhocInterface"]];
        } else {
            [[ManetLabFramework sharedInstance] goIntoErrorMode];
        }
    }
}

@end

/*
 * Framework constructor
 *
 __attribute__((constructor))
 static void initializer(int argc, char** argv, char** envp)
 {
 }
 */

/*
 * Framework cleanup function
 *
 __attribute__((destructor))
 static void finalizer()
 {
 }
 */