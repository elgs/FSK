//
//  ViewController.m
//  FSK
//
//  Created by Elgs Chen on 12/9/13.
//  Copyright (c) 2013 Elgs Chen. All rights reserved.
//

#import "ViewController.h"
#import <AudioToolbox/AudioToolbox.h>

@interface ViewController ()

@end

@implementation ViewController

const double sampleRate = 44100;

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [[self view] endEditing:YES];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
	OSStatus result = AudioSessionInitialize(NULL, NULL, ToneInterruptionListener, (__bridge void *)(self));
	if (result == kAudioSessionNoError)
	{
		UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
		AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
	}
	AudioSessionSetActive(true);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    AudioSessionSetActive(false);
}

void populateCircle(double* buf, int freq, int steps, float amplitude, float phaseShiftInPi){
    double theta=0;
    for (int i=0; i<steps; ++i) {
        double theta_increment = 2.0 * M_PI * freq / sampleRate;
        buf[i] = sin(theta+phaseShiftInPi*M_PI) * amplitude;
        theta+=theta_increment;
        if (theta > 2.0 * M_PI)
        {
            theta -= 2.0 * M_PI;
        }
    }
}

- (IBAction)amplitudeChanged:(id)sender {
    float value =[(UISlider*)sender value];
    [[self amplitudeValue] setText:[NSString stringWithFormat:@"%.2f", value]];
}

- (IBAction)alertInfo:(id)sender {
    NSString* infoData = @"_ denotes a full cycle of low frequency signal. ^ denotes a full cycle of high frequency signal. Interval in milliseconds between which signals are generated. Only one signal is generated if the value is minus. Phase Shift being 1 π means the phase shifts half cycle to the left.";
    UIAlertView* alertHeading = [[UIAlertView alloc]initWithTitle:@"Info" message:infoData delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertHeading show];
}

int getBytes(const char* src, char* dst, int lowSteps, int highSteps) {
	int steps = 0;
    for(int i=0;i<strlen(src);++i){
		for(int j=0;j<8;++j){
            int v = (src[i]>>j)&1;
            dst[i*8+j] = v;
            if(v==0){
                steps+=lowSteps;
            }else{
                steps+=highSteps;
            }
		}
	}
    return steps;
}

- (IBAction)sendData:(id)sender {
    if (toneUnit){
		AudioOutputUnitStop(toneUnit);
		AudioUnitUninitialize(toneUnit);
		AudioComponentInstanceDispose(toneUnit);
		toneUnit = nil;
        if(dataQueue != NULL){
            free(dataQueue);
            dataQueue = NULL;
        }
		[sender setTitle:NSLocalizedString(@"Send", nil) forState:0];
	}else{
        qIndex = 0;
        float amplitude = [[self amplitude] value];
        float phaseShiftInPi = [[[self phaseShiftInPi] text] floatValue];
        NSString* bit0 = [[self bit0] text];
        int bit0Length = bit0.length;
        NSString* bit1 = [[self bit1] text];
        int bit1Length = bit1.length;
        NSString* heading = [[self heading] text];
        NSString* tailing = [[self tailing] text];
        //printf("heading.length:%d\n",heading.length);
        //printf("tailing.length:%d\n",tailing.length);
        
		int lowFreq = [[[self lowFreq] text] intValue];
        int lowSteps = sampleRate/lowFreq+1;
        int lowSize =lowSteps*sizeof(double);
        
        int highFreq = [[[self highFreq] text] intValue];
        int highSteps = sampleRate/highFreq+1;
        int highSize =highSteps*sizeof(double);
        
        double lowData[lowSteps];
        double highData[highSteps];
        populateCircle(lowData, lowFreq, lowSteps, amplitude, phaseShiftInPi);
        populateCircle(highData, highFreq, highSteps, amplitude, phaseShiftInPi);
        NSStringEncoding gbk = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
        const char* datac = [[[self data] text] cStringUsingEncoding:gbk];
        //const char* datac = [data UTF8String];
        
        unsigned long dataLengthc = strlen(datac)*8;
        printf("%lu\n", dataLengthc/8);
        char dataSignal[dataLengthc];
        int steps = getBytes(datac, dataSignal, lowSteps, highSteps);
        
        qSize = steps*dataLengthc;
        for (int i=0; i<heading.length; ++i) {
            NSString* h = [heading substringWithRange:NSMakeRange(i, 1)];
            if([h isEqualToString:@"_"]) {
                qSize+=lowSteps;
            } else if([h isEqualToString:@"^"]) {
                qSize+=highSteps;
            }
        }
        
        for (int i=0; i<tailing.length; ++i) {
            NSString* t = [tailing substringWithRange:NSMakeRange(i, 1)];
            if([t isEqualToString:@"_"]) {
                qSize+=lowSteps;
            } else if([t isEqualToString:@"^"]) {
                qSize+=highSteps;
            }
        }
        //printf("qSize:%d\n", qSize);
        dataQueue = (double*)malloc(sizeof(double)*qSize);
        opDq = dataQueue;
        
        for (int i=0; i<heading.length; ++i) {
            NSString* h = [heading substringWithRange:NSMakeRange(i, 1)];
            if([h isEqualToString:@"_"]) {
                memcpy(opDq, lowData, lowSize);
                opDq+=lowSteps;
            } else if([h isEqualToString:@"^"]) {
                memcpy(opDq, highData, highSize);
                opDq+=highSteps;
            }
        }
        
        for (int i=0; i<dataLengthc; ++i){
            int d = dataSignal[i];
            if(d==0){
                memcpy(opDq, highData, highSize);
                opDq+=highSteps;
                memcpy(opDq, lowData, lowSize);
                opDq+=lowSteps;
            }else{
                memcpy(opDq, lowData, lowSize);
                opDq+=lowSteps;
                memcpy(opDq, highData, highSize);
                opDq+=highSteps;
            }
        }
        
        for (int i=0; i<tailing.length; ++i) {
            NSString* t = [tailing substringWithRange:NSMakeRange(i, 1)];
            if([t isEqualToString:@"_"]) {
                memcpy(opDq, lowData, lowSize);
                opDq+=lowSteps;
            } else if([t isEqualToString:@"^"]) {
                memcpy(opDq, highData, highSize);
                opDq+=highSteps;
            }
        }
        opDq = dataQueue;
        
        //        printf("%d\n", qSize);
        //        for (int i=0; i<qSize; ++i) {
        //            printf("%d: %f\n", i,self->dataQueue[i]);
        //        }
        
        [self createToneUnit];
		
		// Stop changing parameters on the unit
		OSErr err = AudioUnitInitialize(toneUnit);
		NSAssert1(err == noErr, @"Error initializing unit: %d", err);
		
		// Start playback
		err = AudioOutputUnitStart(toneUnit);
		NSAssert1(err == noErr, @"Error starting unit: %d", err);
		
		[sender setTitle:NSLocalizedString(@"Stop", nil) forState:0];
	}
}

OSStatus RenderTone(
                    void *inRefCon,
                    AudioUnitRenderActionFlags 	*ioActionFlags,
                    const AudioTimeStamp 		*inTimeStamp,
                    UInt32 						inBusNumber,
                    UInt32 						inNumberFrames,
                    AudioBufferList 			*ioData)

{
	// Get the tone parameters out of the view controller
	ViewController *viewController = (__bridge ViewController *)inRefCon;
    
	// This is a mono tone generator so we only need the first buffer
	const int channel = 0;
	Float32 *buffer = (Float32 *)ioData->mBuffers[channel].mData;
	
    //printf("Start package.\n");
	// Generate the samples
	for (UInt32 frame = 0; frame < inNumberFrames; frame++)
	{
		buffer[frame] = *(viewController->opDq);
        //printf("qIndex:%d, frame:%d, value:%f\n", viewController->qIndex, (unsigned int)frame, *(viewController->opDq));
        ++viewController->opDq;
        if(++viewController->qIndex >= viewController->qSize){
            //printf("qIndex end:%d\n", viewController->qIndex);
            [viewController performSelectorOnMainThread:@selector(stop) withObject:nil waitUntilDone:NO];
            break;
        }
	}
    
	return noErr;
}

- (void)stop
{
	if (toneUnit)
	{
		[self sendData:[self sendButton]];
        float interval = [[[self interval] text] floatValue];
        if (interval>0) {
            [NSThread sleepForTimeInterval:interval/1000];
            [self sendData:[self sendButton]];
        }
    
	}
}

void ToneInterruptionListener(void *inClientData, UInt32 inInterruptionState)
{
	ViewController *viewController = (__bridge ViewController *)inClientData;
	[viewController stop];
}

- (void)createToneUnit
{
	// Configure the search parameters to find the default playback output unit
	// (called the kAudioUnitSubType_RemoteIO on iOS but
	// kAudioUnitSubType_DefaultOutput on Mac OS X)
	AudioComponentDescription defaultOutputDescription;
	defaultOutputDescription.componentType = kAudioUnitType_Output;
	defaultOutputDescription.componentSubType = kAudioUnitSubType_RemoteIO;
	defaultOutputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
	defaultOutputDescription.componentFlags = 0;
	defaultOutputDescription.componentFlagsMask = 0;
	
	// Get the default playback output unit
	AudioComponent defaultOutput = AudioComponentFindNext(NULL, &defaultOutputDescription);
	NSAssert(defaultOutput, @"Can't find default output");
	
	// Create a new unit based on this that we'll use for output
	OSErr err = AudioComponentInstanceNew(defaultOutput, &toneUnit);
	NSAssert1(toneUnit, @"Error creating unit: %d", err);
	
	// Set our tone rendering function on the unit
	AURenderCallbackStruct input;
	input.inputProc = RenderTone;
	input.inputProcRefCon = (__bridge void *)(self);
	err = AudioUnitSetProperty(toneUnit,
                               kAudioUnitProperty_SetRenderCallback,
                               kAudioUnitScope_Input,
                               0,
                               &input,
                               sizeof(input));
	NSAssert1(err == noErr, @"Error setting callback: %d", err);
	
	// Set the format to 32 bit, single channel, floating point, linear PCM
	const int four_bytes_per_float = 4;
	const int eight_bits_per_byte = 8;
	AudioStreamBasicDescription streamFormat;
	streamFormat.mSampleRate = sampleRate;
	streamFormat.mFormatID = kAudioFormatLinearPCM;
	streamFormat.mFormatFlags =
    kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
	streamFormat.mBytesPerPacket = four_bytes_per_float;
	streamFormat.mFramesPerPacket = 1;
	streamFormat.mBytesPerFrame = four_bytes_per_float;
	streamFormat.mChannelsPerFrame = 1;
	streamFormat.mBitsPerChannel = four_bytes_per_float * eight_bits_per_byte;
	err = AudioUnitSetProperty (toneUnit,
                                kAudioUnitProperty_StreamFormat,
                                kAudioUnitScope_Input,
                                0,
                                &streamFormat,
                                sizeof(AudioStreamBasicDescription));
	NSAssert1(err == noErr, @"Error setting stream format: %d", err);
}

@end