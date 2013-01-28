//
//  MLAppDelegate.m
//  mlcontroller
//
//  Created by Francois Vessaz on 12/12/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#include <sys/socket.h>
#include <sys/un.h>

#import "MLAppDelegate.h"
#import "MainViewController.h"
#import "SetLayersWindowController.h"
#import "SendWindowController.h"
#import "LogWindowController.h"

#define PREF_PATH @"/Library/PreferencePanes/ManetLabPrefs.prefPane"
#define SOCKET_PATH "/var/tmp/ch.unil.doplab.manetlab/guisocket"

@interface MLAppDelegate() {
    
    MainViewController* mainViewController;
    BOOL errorOnInit;
    NSArray* agentsList;
    NSDictionary* lastTaskDetails;
    BOOL displayLastActionView;
    SetLayersWindowController* setLayersController;
    NSMutableDictionary* logWindows;
    MLStreamsUtility* streams;
    
}

@end

@implementation MLAppDelegate

@synthesize mainView = _mainView;
@synthesize window = _window;
@synthesize agentsList;
@synthesize lastTaskDetails;

- (id)init
{
    self = [super init];
    if (self) {
        errorOnInit = NO;
        agentsList = nil;
        lastTaskDetails = nil;
        displayLastActionView = NO;
        logWindows = [[NSMutableDictionary dictionary] retain];
        
        // Init socket with ML framework
        int sockFD = -1;
        sockFD = socket(AF_UNIX, SOCK_STREAM, 0);
        if (sockFD < 0) {
            errorOnInit = YES;
            NSLog(@"socket error (%i)",errno);
        }
        struct sockaddr_un connReq;
        connReq.sun_len    = sizeof(connReq);
        connReq.sun_family = AF_UNIX;
        strcpy(connReq.sun_path,SOCKET_PATH);
        int i = connect(sockFD, (struct sockaddr *) &connReq, (socklen_t)SUN_LEN(&connReq));
        if (i < 0) {
            errorOnInit = YES;
            NSLog(@"connection error (%i)",errno);
        }
        
        // init streams
        NSInputStream* streamIn = nil;
        NSOutputStream* streamOut = nil;
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, sockFD, (CFReadStreamRef*)&streamIn, (CFWriteStreamRef*)&streamOut);
        if (streamIn && streamOut) {
            CFReadStreamSetProperty((CFReadStreamRef)streamIn, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            CFWriteStreamSetProperty((CFWriteStreamRef)streamOut, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            streams = [[MLStreamsUtility alloc] initWithInputStream:streamIn andOutputStream:streamOut delegate:self];
        } else {
            errorOnInit = YES;
            NSLog(@"Unable to get streams to framework");
        }
    }
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    if (errorOnInit) {
        NSAlert* alert = [NSAlert alertWithMessageText:@"ManetLab error" defaultButton:@"Quit" alternateButton:nil otherButton:nil informativeTextWithFormat:@"ManetLab was not able to connect local controller."];
        [alert runModal];
        exit(1);
    } else {
        [self sendData:[NSDictionary dictionaryWithObject:@"checkin" forKey:@"action"]];
        
        mainViewController = [[MainViewController alloc] initWithNibName:@"MainViewController" bundle:nil];
        [_mainView addSubview:mainViewController.view];
    }
}

-(BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem {
    if ([[toolbarItem itemIdentifier] isEqualToString:@"prefs"]){
        return YES;
    } else if ([[toolbarItem itemIdentifier] isEqualToString:@"log"]) {
        return (mainViewController._sidebar.selectedRow > 3);
    } else {
        return [mainViewController hasSelectedAgents];
    }
}

- (IBAction)openPrefs:(id)sender {
    [[NSWorkspace sharedWorkspace] openFile:PREF_PATH];
}

- (IBAction)addPlugin:(id)sender {
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    [openDlg setDelegate:self];
    [openDlg setCanChooseFiles:YES];
    [openDlg setAllowsMultipleSelection:NO];
    [openDlg setCanChooseDirectories:NO];
    [openDlg setAllowedFileTypes:[NSArray arrayWithObject:@"plugin"]];
    [openDlg setMessage:@"Choose a ManetLab plugin to upload it to selected agents:"];
    [openDlg setPrompt:@"Upload plugin"];
    [openDlg beginSheetModalForWindow:_window completionHandler:NULL];
}

- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError **)outError {NSError* err = nil;
    NSFileWrapper* plugin = [[NSFileWrapper alloc] initWithURL:[url fileReferenceURL] options:NSFileWrapperReadingImmediate error:&err];
    if (err != nil) {
        NSLog(@"ERROR: %@",[err localizedDescription]);
        [plugin release];
        return NO;
    }
    NSData* pluginData = [plugin serializedRepresentation];
    NSDictionary* addPluginDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                   @"newTask",@"action",
                                   [mainViewController selectedAgents],@"toAgents",
                                   @"addPlugin",@"task",
                                   pluginData,@"pluginData",
                                   [url lastPathComponent],@"pluginName",
                                   nil];
    [plugin release];
    displayLastActionView = YES;
    if ([self sendData:addPluginDict]){
        NSLog(@"Plugin %@ successfully uploaded to controller.",[url absoluteString]);
        return YES;
    }
    return NO;
}

- (IBAction)configureStack:(id)sender {
    setLayersController = [[SetLayersWindowController alloc] initWithWindowNibName:@"SetLayersWindowController" andAgents:[mainViewController selectedAgents]];
    [NSApp beginSheet:[setLayersController window] modalForWindow:_window modalDelegate:setLayersController didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
    displayLastActionView = YES;
}

- (IBAction)send:(id)sender {
    SendWindowController* viewController = [[SendWindowController alloc] initWithWindowNibName:@"SendWindowController" andAgents:[mainViewController selectedAgents]];
    [NSApp beginSheet:[viewController window] modalForWindow:_window modalDelegate:viewController didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
    displayLastActionView = YES;
}

- (IBAction)showLogs:(id)sender {
    NSString* taskId = [mainViewController selectedTaskId];
    LogWindowController* logController;
    if ([logWindows valueForKey:taskId] == nil) {
        logController = [[LogWindowController alloc] initWithWindowNibName:@"LogWindowController" andTask:taskId];
        [logWindows setValue:logController forKey:taskId];
    } else {
        logController = [logWindows valueForKey:taskId];
    }
    [logController refresh:self];
    [[logController window] makeKeyAndOrderFront:self];
}

-(void)closeLogWindow:(NSString*)aTaskId {
    [logWindows removeObjectForKey:aTaskId];
}

-(BOOL)sendData:(NSDictionary*)newData {
    if (streams != nil) {
        [streams sendData:newData];
        return YES;
    }
    NSLog(@"Unable to send data on UNIX connection");
    return NO;
}

-(void)onData:(NSDictionary*)newData {
    NSString* action = [newData valueForKey:@"action"];
    if ([action isEqualToString:@"agents"]) {
        if (agentsList != nil) {
            [agentsList release];
        }
        agentsList = [[newData valueForKey:@"agentsList"] retain];
        [mainViewController refreshDisplay];
    } else if ([action isEqualToString:@"tasksList"]) {
        [mainViewController refreshTasksList:[newData valueForKey:@"tasksList"] switchView:displayLastActionView];
    } else if ([action isEqualToString:@"taskDetails"]) {
        if (lastTaskDetails != nil){
            [lastTaskDetails release];
        }
        lastTaskDetails = [newData retain];
        [mainViewController refreshDisplay];
    } else if ([action isEqualToString:@"taskLog"]) {
        if ([logWindows valueForKey:[newData valueForKey:@"taskId"]] != nil) {
            LogWindowController* logController = [logWindows valueForKey:[newData valueForKey:@"taskId"]];
            [logController updateLog:[newData valueForKey:@"log"]];
        }
    } else if ([action isEqualToString:@"commonLayersList"]) {
        [setLayersController setAvailableLayers:[newData valueForKey:@"layersList"]];
    }
}

-(void)onClose {
    NSAlert* alert = [NSAlert alertWithMessageText:@"ManetLab error" defaultButton:@"Quit" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Local controller has quit unexpectedly."];
    [alert runModal];
    exit(1);
}

-(void)onError {
    NSAlert* alert = [NSAlert alertWithMessageText:@"ManetLab error" defaultButton:@"Quit" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Local controller has quit unexpectedly."];
    [alert runModal];
    exit(1);
}

- (void)dealloc {
    [logWindows release];
    if (lastTaskDetails != nil){
        [lastTaskDetails release];
    }
    if (agentsList != nil) {
        [agentsList release];
    }
    [mainViewController release];
    [super dealloc];
}

@end
