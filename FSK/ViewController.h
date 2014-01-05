//
//  ViewController.h
//  FSK
//
//  Created by Elgs Chen on 12/9/13.
//  Copyright (c) 2013 Elgs Chen. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AudioUnit/AudioUnit.h>

@interface ViewController : UIViewController{
    AudioComponentInstance toneUnit;
    double* dataQueue;
    double* opDq;
    unsigned long qSteps;
    unsigned long qIndex;
    int status;
}

@property (strong, nonatomic) IBOutlet UITextField* lowFreq;
@property (strong, nonatomic) IBOutlet UITextField* highFreq;
@property (strong, nonatomic) IBOutlet UITextField* data;
@property (strong, nonatomic) IBOutlet UIButton *sendButton;
@property (strong, nonatomic) IBOutlet UISlider *amplitude;
@property (strong, nonatomic) IBOutlet UITextField *bit0;
@property (strong, nonatomic) IBOutlet UITextField *bit1;
@property (strong, nonatomic) IBOutlet UITextField *heading;
@property (strong, nonatomic) IBOutlet UITextField *tailing;
@property (strong, nonatomic) IBOutlet UILabel *amplitudeValue;
@property (strong, nonatomic) IBOutlet UITextField *interval;
@property (strong, nonatomic) IBOutlet UITextField *phaseShiftInPi;

- (IBAction)sendData:(id)sender;
- (IBAction)amplitudeChanged:(id)sender;
- (IBAction)alertInfo:(id)sender;

@end
