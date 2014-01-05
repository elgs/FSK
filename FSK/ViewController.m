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

void getBytes(const char* src, char* dst) {
    for(int i=0;i<strlen(src);++i){
        for(int j=0;j<8;++j){
            dst[i*8+j] = (src[i]>>j)&1;
        }
    }
}

void getBitData(const char* bit, double* data, const double* lowData,int lowSteps, const double* highData, int highSteps){
    for(int i=0;i<strlen(bit);++i){
        char c = bit[i];
        if(c == '_'){
            memcpy(data, lowData, lowSteps*sizeof(double));
            data+=lowSteps;
        }else if(c == '^'){
            memcpy(data, highData, highSteps*sizeof(double));
            data+=highSteps;
        }
    }
}

unsigned long calcQSteps(const char* dst,unsigned long dstSize, unsigned long bit0Steps, unsigned long bit1Steps){
    unsigned long ret = 0;
    for(int i=0;i<dstSize;++i){
        if(dst[i] == 0){
            ret += bit0Steps;
        }else if(dst[i] == 1){
            ret += bit1Steps;
        }
    }
    return ret;
}

unsigned long calcBitSteps(const char* bit, int lowSteps, int highSteps){
    unsigned long ret = 0;
    for(int i=0;i<strlen(bit);++i){
        char c = bit[i];
        if(c == '_'){
            ret+=lowSteps;
        }else if(c == '^'){
            ret+=highSteps;
        }
    }
    return ret;
}

- (IBAction)sendData:(id)sender {
    if (toneUnit){
		status = 0;
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
        status = 1;
        qIndex = 0;
        float amplitude = [[self amplitude] value];
        float phaseShiftInPi = [[[self phaseShiftInPi] text] floatValue];
        const char* bit0 = [[[self bit0] text] UTF8String];
        const char* bit1 = [[[self bit1] text] UTF8String];
        NSString* heading = [[self heading] text];
        NSString* tailing = [[self tailing] text];
        //printf("heading.length:%d\n",heading.length);
        //printf("tailing.length:%d\n",tailing.length);
        
		int lowFreq = [[[self lowFreq] text] intValue];
        int lowSteps = round(sampleRate/lowFreq);
        int lowSize =lowSteps*sizeof(double);
        
        int highFreq = [[[self highFreq] text] intValue];
        int highSteps = round(sampleRate/highFreq);
        int highSize =highSteps*sizeof(double);
        
        unsigned long bit0Steps = calcBitSteps(bit0, lowSteps, highSteps);
        unsigned long bit1Steps = calcBitSteps(bit1, lowSteps, highSteps);
        //printf("bit0Steps: %lu\n",bit0Steps);
        //printf("bit1Steps: %lu\n",bit1Steps);
        
        double lowData[lowSteps];
        double highData[highSteps];
        populateCircle(lowData, lowFreq, lowSteps, amplitude, phaseShiftInPi);
        populateCircle(highData, highFreq, highSteps, amplitude, phaseShiftInPi);
        
        double bit0Data[bit0Steps];
        double bit1Data[bit1Steps];
        getBitData(bit0, bit0Data, lowData, lowSteps, highData, highSteps);
        getBitData(bit1, bit1Data, lowData, lowSteps, highData, highSteps);
        
        NSStringEncoding gbk = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
        const char* datac = [[[self data] text] cStringUsingEncoding:gbk];
        //const char* datac = [data UTF8String];
        
        unsigned long dataLengthc = strlen(datac)*8;
        char dataSignal[dataLengthc];
        getBytes(datac, dataSignal);
        qSteps = calcQSteps(dataSignal,dataLengthc, bit0Steps, bit1Steps);
        //printf("qSteps: %lu\n",qSteps);
        for (int i=0; i<heading.length; ++i) {
            NSString* h = [heading substringWithRange:NSMakeRange(i, 1)];
            if([h isEqualToString:@"_"]) {
                qSteps+=lowSteps;
            } else if([h isEqualToString:@"^"]) {
                qSteps+=highSteps;
            }
        }
        
        for (int i=0; i<tailing.length; ++i) {
            NSString* t = [tailing substringWithRange:NSMakeRange(i, 1)];
            if([t isEqualToString:@"_"]) {
                qSteps+=lowSteps;
            } else if([t isEqualToString:@"^"]) {
                qSteps+=highSteps;
            }
        }
        //printf("qSteps: %lu\n",qSteps);
        dataQueue = (double*)malloc(sizeof(double)*qSteps);
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
                memcpy(opDq, bit0Data, bit0Steps*sizeof(double));
                opDq+=bit0Steps;
            }else{
                memcpy(opDq, bit1Data, bit1Steps*sizeof(double));
                opDq+=bit1Steps;
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
        if(viewController->status){
            buffer[frame] = *(viewController->opDq);
            //printf("qIndex:%lu, frame:%d, value:%f\n", viewController->qIndex, (unsigned int)frame, *(viewController->opDq));
            ++viewController->opDq;
            if(++viewController->qIndex >= viewController->qSteps){
                //printf("qIndex end:%lu qSteps:%lu\n", viewController->qIndex, viewController->qSteps);
                [viewController performSelectorOnMainThread:@selector(stop) withObject:nil waitUntilDone:NO];
                viewController->status = 0;
                break;
            }
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