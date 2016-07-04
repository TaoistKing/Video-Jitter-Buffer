//
//  ViewController.m
//  JitterBufferTest
//
//  Created by WangRui on 16/6/15.
//  Copyright © 2016年 WangRui. All rights reserved.
//

#import "ViewController.h"
#import "webrtc/modules/video_coding/main/source/receiver.h"
#import "webrtc/modules/video_coding/main/source/encoded_frame.h"

#import "webrtc/system_wrappers/interface/clock.h"

@interface ViewController ()
{
    webrtc::VCMReceiver *_receiver;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self startTest];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)startTest{
    [self createReceiver];
    
    NSThread *inputThread = [[NSThread alloc] initWithTarget:self selector:@selector(Run:) object:nil];
    [inputThread start];
    NSThread *outputThread = [[NSThread alloc] initWithTarget:self selector:@selector(Run:) object:nil];
    [outputThread start];
    
    [self performSelector:@selector(startInput) onThread:inputThread withObject:nil waitUntilDone:NO];
    [self performSelector:@selector(startoutput) onThread:outputThread withObject:nil waitUntilDone:NO];
}

- (void)Run: (id)obj{
    @autoreleasepool {
        [[NSRunLoop currentRunLoop] addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        while ([[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
        NSLog(@"leave thread");
    }
}

- (void)startInput{
    NSTimer *inputTimer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(insertPacket) userInfo:nil repeats:YES];
    [inputTimer fire];
}

- (void)startoutput{
    NSTimer *outputTimer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(getPacket) userInfo:nil repeats:YES];
    [outputTimer fire];
}


- (void)createReceiver{
    webrtc::Clock *clock = webrtc::Clock::GetRealTimeClock();
    webrtc::VCMTiming *timing = new webrtc::VCMTiming(clock);
    webrtc::EventFactory *factory = new webrtc::EventFactoryImpl;
    
    _receiver = new webrtc::VCMReceiver(timing, clock, factory);
    _receiver->Reset();
    _receiver->UpdateRtt(300);
    
    
}

- (void)insertPacket{
    unsigned char buffer[100] = {0};
    size_t length = 100;
    static uint16_t sn = 0;
    static UInt32 ts = 0;
    bool marker = false;
    
    if (sn % 3 == 2) {
        marker = true;
    }else if (sn % 3 == 0){
        ts += 3000;
    }
    webrtc::WebRtcRTPHeader header;
    header.frameType = webrtc::kVideoFrameKey;
    header.type.Video.codec = webrtc::kRtpVideoH264;
    
    if (sn % 3 == 2) {
        marker = true;
    }else if (sn % 3 == 0){
        ts += 3000;
        header.type.Video.isFirstPacket = true;
    }
    header.header.markerBit = marker;
    header.header.sequenceNumber = sn;
    header.header.timestamp = ts;

    webrtc::VCMPacket packet(buffer, length, header);
    NSLog(@"insert packet with sn:%d, ts:%d", sn, ts);
    
    int32_t rt = _receiver->InsertPacket(packet, 640, 480);
    if (rt != 0) {
        NSLog(@"InsertPacket error : %d", rt);
    }
    sn++;
}

- (void)getPacket{
    int64_t render_time;
    webrtc::VCMEncodedFrame *frame = _receiver->FrameForDecoding(100, render_time);
    
    if (frame != nullptr) {
        NSLog(@"got frame with ts: %d", frame->TimeStamp());
    }
    _receiver->ReleaseFrame(frame);

}

@end
