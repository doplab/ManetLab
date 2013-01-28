//
//  UDP6Server.m
//  ManetLab
//
//  Created by François Vessaz on 8/17/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MLLowestLayer.h"
#import "ManetLabFramework+Internal.h"
#import "MLMessage+Internal.h"

#import <CoreWLAN/CoreWLAN.h>

#include <sys/socket.h>
#include <ifaddrs.h>
#include <net/if_dl.h>
#include <net/ethernet.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <net/ndrv.h>
#include <sys/select.h>
#include <fcntl.h>

#define ML_ETHERTYPE 0x88b5                     // Custom Ethertype
#define ML_TX_TARGET_RATE 0.8                   // ratio of the Tx (output in MBits) that we target
#define ML_MIN_TX 6.0                           // Min TX (before applying ratio)

@interface MLLowestLayer() {
    
@private
    
    NSString* interfaceBSDname;                 // WLAN inteface BSD name
    NSString* macAddress;                       // WLAN interface MAC address
    NSMutableArray* sendQueue;                  // OUT queue
    NSLock* sendQueueLock;                      // Lock on OUT queue
    int MTU;                                    // WLAN interface Maximum Transmission Unit
    CFSocketNativeHandle socketIN;              // file descriptor for IN socket
    CFSocketNativeHandle socketOUT;             // file descriptor for OUT socket
    NSThread* sendThread;                       // dedicated sending thread, nil when sendQueue empty
    CWInterface* interface;                     // CoreWLAN interface (to get current Tx)
    NSThread* receiveThread;                    // dedicated recieved thread
    
}

-(CFSocketNativeHandle)getSocketOUT;
-(CFSocketNativeHandle)getSocketIN;
-(int)getMTU;
-(void)sendLoop;
-(void)receiveLoop;
-(void)dispatchNewData:(NSData*)newData;

@end

@implementation MLLowestLayer

/*
 * Init lowest layer on selected interface (WLAN)
 */
- (id)initOnInterface:(NSString*)anInterface
{
    self = [super init];
    if (self) {
        interfaceBSDname = [anInterface retain];
        sendQueue = [[NSMutableArray array] retain];
        sendQueueLock = [[NSLock alloc] init];
        sendThread = nil;
        interface = [[CWInterface interfaceWithName:interfaceBSDname] retain];
        socketIN = -1;
        socketOUT = -1;
        
        macAddress = [[MLLowestLayer getMACOfInterface:interfaceBSDname] retain];
        socketOUT = [self getSocketOUT];
        MTU = [self getMTU];
        socketIN = [self getSocketIN];
        
        receiveThread = [[NSThread alloc] initWithTarget:self selector:@selector(receiveLoop) object:nil];
        [receiveThread start];
    }
    return self;
}

/*
 * Interface MAC address
 */
+(NSString*)getMACOfInterface:(NSString*)interface {
    //macAddress = nil;
    struct ifaddrs * addrs;
    int success = getifaddrs(&addrs);
    if (success < 0) {
        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to get MAC address of interface %@",interface];
        return nil;
    }
    struct ifaddrs * cursor;
    struct ether_addr macAddr;
    cursor = addrs;
    while (cursor != 0) {
        struct sockaddr_dl * dlAddr;
        if ((cursor->ifa_addr->sa_family == AF_LINK) && (strcmp([interface UTF8String], cursor->ifa_name)==0)) {
            dlAddr = (struct sockaddr_dl *) cursor->ifa_addr;
            memcpy(&macAddr, &dlAddr->sdl_data[dlAddr->sdl_nlen], dlAddr->sdl_alen);
            return [NSString stringWithCString:ether_ntoa(&macAddr) encoding:NSUTF8StringEncoding];
        }
        cursor = cursor->ifa_next;
    }
    freeifaddrs(addrs);
    [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to get MAC address of interface %@",interface];
    return nil;
}

/*
 * Open RAW socket on WLAN interface for output
 */
-(CFSocketNativeHandle)getSocketOUT {
    // get FD
    CFSocketNativeHandle fd = socket(AF_NDRV, SOCK_RAW, 0);
    if (fd < 0) {
        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"WLAN socket ERROR %i: %s",errno,strerror(errno)];
    }
    
    // set interface BSD name
    struct sockaddr address;
    memset(&address, 0, sizeof(address));
    address.sa_len = sizeof(address);
    const char* ifName = [interfaceBSDname UTF8String];
    memcpy(address.sa_data, ifName, sizeof(&ifName));
    address.sa_family = AF_NDRV;
    
    // bind socket to bsd name
    int res = bind(fd, &address, sizeof(address));
    if (res < 0) {
        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"WLAN bind ERROR %i: %s",errno,strerror(errno)];
    }

    // connect, so we do not have to pass addresse on each send
    res = connect(fd, &address, sizeof(address));
    if (res < 0) {
        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"WLAN connect ERROR %i: %s",errno,strerror(errno)];
    }
    return fd;
}

/*
 * Open RAW socket for input on WLAN
 */
-(CFSocketNativeHandle)getSocketIN {
    // get fd
    CFSocketNativeHandle fd = socket(AF_NDRV, SOCK_RAW, 0);
    if (fd < 0) {
        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"WLAN socket ERROR %i: %s",errno,strerror(errno)];
    }
    
    // set BSD name address
    struct sockaddr address;
    memset(&address, 0, sizeof(address));
    address.sa_len = sizeof(address);
    const char* ifName = [interfaceBSDname UTF8String];
    memcpy(address.sa_data, ifName, sizeof(&ifName));
    address.sa_family = AF_NDRV;
    
    // bind socket to interface
    int res = bind(fd, &address, sizeof(address));
    if (res < 0) {
        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"WLAN bind ERROR %i: %s",errno,strerror(errno)];
    }
    
    // set demultiplexing: we are only interested on our ethertype
    struct ndrv_protocol_desc desc;
    struct ndrv_demux_desc	demux_desc[1];
    bzero(&desc, sizeof(desc));
    bzero(&demux_desc, sizeof(demux_desc));
    
    desc.version = NDRV_PROTOCOL_DESC_VERS;
    desc.protocol_family = NDRV_DEMUXTYPE_ETHERTYPE;
    desc.demux_count = (u_int32_t)1;
    desc.demux_list = (struct ndrv_demux_desc*)&demux_desc;
    
    demux_desc[0].type = NDRV_DEMUXTYPE_ETHERTYPE;
    demux_desc[0].data.ether_type = htons(ML_ETHERTYPE);
    demux_desc[0].length = sizeof(unsigned short);
    
    res = setsockopt(fd, SOL_NDRVPROTO, NDRV_SETDMXSPEC, (caddr_t)&desc, sizeof(desc));
    if (res < 0) {
        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"WLAN setsockopt ERROR %i: %s",errno,strerror(errno)];
    }
    
    // set socket non blocking, because we use a select call
    int opts;
    opts = fcntl(fd,F_GETFL);
	if (opts < 0) {
        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"WLAN get FD option ERROR %i: %s",errno,strerror(errno)];
	}
	opts = (opts | O_NONBLOCK);
	if (fcntl(fd,F_SETFL,opts) < 0) {
        [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"WLAN set FD option ERROR %i: %s",errno,strerror(errno)];
	}
    return fd;
}

/*
 * get WLAN interface MTU (in MBits)
 */
-(int)getMTU {
    struct ifreq req;
    memset(&req, 0, sizeof(req));
    req.ifr_addr.sa_family = AF_NDRV;
    strcpy(req.ifr_name,[interfaceBSDname UTF8String]);
    if (ioctl(socketOUT, SIOCGIFMTU, &req) == 0){
        return req.ifr_mtu;
    }
    [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"Unable to get MTU of interface %@",interfaceBSDname];
    return -1;
}

/*
 * This is the lowest layer. This action is impossible and will make manetlab crash.
 */
-(void)setLowerLayer:(MLStackLayer*)lowerLayer {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"ERROR not allowed to set a lower layer to the lowest adhoc layer!"] userInfo:nil];
}

/*
 * Send data on WLAN.
 */
-(MLSendResult)send:(MLMessage*)msg {
    NSData* data = [msg getSerializedMessage:macAddress];
    if ([data length] > MTU+ETHER_HDR_LEN) {
        return kMLSendTooBig;
    }
    [sendQueueLock lock];
    [sendQueue addObject:data];
    if (sendThread == nil) {
        sendThread = [[NSThread alloc] initWithTarget:self selector:@selector(sendLoop) object:nil];
        [sendThread start];
    }
    [sendQueueLock unlock];
    return kMLSendSuccess;
}

/*
 * SendLoop for send thread. Only active when broadcastQueue not empty.
 */
-(void)sendLoop {
    while ([sendQueue count] > 0) {
        @autoreleasepool {
            [sendQueueLock lock];
            NSData* data = [[sendQueue objectAtIndex:0] retain];
            [sendQueue removeObjectAtIndex:0];
            [sendQueueLock unlock];
            
            ssize_t sendded = send(socketOUT, [data bytes], [data length], 0);
            if (sendded < 0) {
                [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"ERROR while sending on WLAN (send errno %i)",errno];
            }
            
            // If no TX returned from interface, assume that TX is min TX.
            double transmitRate = interface.transmitRate;
            if (transmitRate <= 0) {
                transmitRate = ML_MIN_TX;
            }
            double targetTx = ML_TX_TARGET_RATE * transmitRate;
            double paquetPerSecond = targetTx * 125000 / [data length];
            double waitFor = 1.0 / paquetPerSecond;
            
            [data release];
            
            [NSThread sleepForTimeInterval:waitFor];
            if ([sendThread isCancelled]) {
                break;
            }
        }
    }
    [sendQueueLock lock];
    [sendThread release];
    sendThread = nil;
    [sendQueueLock unlock];
}

/*
 * Receive loop for receive thread. Active until stop method is called.
 */
-(void)receiveLoop {
    struct timeval timeout;
    memset(&timeout, 0, sizeof(timeout));
    timeout.tv_sec = 1;
    unsigned char buffer[MTU+ETHER_HDR_LEN];
    while (YES) {
        @autoreleasepool {
            fd_set readSet;
            FD_ZERO(&readSet);
            FD_SET(socketIN, &readSet);
            int selRes = select(socketIN+1, &readSet, 0, 0, &timeout);
            if (selRes < 0) {
                [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"ERROR while receiving on WLAN (select errno %i)",errno];
                break;
            } else if (selRes > 0){
                ssize_t length = recv(socketIN, &buffer, sizeof(buffer), 0);
                if (length < 0) {
                    [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"ERROR while receiving on WLAN (recv errno %i)",errno];
                } else {
                    NSData *newData = [NSData dataWithBytes:&buffer length:length];
                    [self performSelectorOnMainThread:@selector(dispatchNewData:) withObject:newData waitUntilDone:NO];
                }
            }
            if ([receiveThread isCancelled]) {
                break;
            }
        }
    }
    [receiveThread release];
    receiveThread = nil;
}

/*
 * Pass incoming data from receive loop thread to run loop as a message object.
 */
-(void)dispatchNewData:(NSData*)newData {
    MLMessage* msg = [[MLMessage alloc] initWithBytes:[newData bytes] length:[newData length]];
    [self deliverFurther:msg];
    [msg release];
}

/*
 * Returns MAC address
 */
-(NSString*)hostAddress {
    return macAddress;
}

/*
 * Stop the send and receive threads.
 */
-(void)stop {
    [sendThread cancel];
    [receiveThread cancel];
}

-(void)dealloc {
    if (socketIN > 0) {
        if (close(socketIN) <0){
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"WLAN socket IN close ERROR %i",errno];
        }
    }
    if (socketOUT > 0) {
        if (close(socketOUT) <0){
            [[ManetLabFramework sharedInstance] logWithLevel:ASL_LEVEL_ERR andMsg:@"WLAN socket OUT close ERROR %i",errno];
        }
    }
    [interface release];
    [sendQueue release];
    [sendQueueLock release];
    [interfaceBSDname release];
    [macAddress release];
    [super dealloc];
}

@end
