
@import AVFoundation;
@import Photos;
@class AppDelegate;

#import <UIKit/UIKit.h>
#import "IPhoneCameraViewController.h"
#import "AAPLPreviewView.h"
#import "CA7CH-Swift.h"
#import "VCSimpleSession.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <AVFoundation/AVAsset.h>
#import <CoreMedia/CoreMedia.h>
#import <QuartzCore/QuartzCore.h>
#import "ALAssetsLibrary+CustomPhotoAlbum.h"

static void * CapturingStillImageContext = &CapturingStillImageContext;
static void * SessionRunningContext = &SessionRunningContext;

NSString* selectedFlashOption = @"selectedFlashOption";
int thumbnailSize = 50;
int deleteCount = 0;
int flashFlag = 0;
int timeSec = 0;

typedef NS_ENUM( NSInteger, AVCamSetupResult ) {
    AVCamSetupResultSuccess,
    AVCamSetupResultCameraNotAuthorized,
    AVCamSetupResultSessionConfigurationFailed
};

@interface IPhoneCameraViewController ()<AVCaptureFileOutputRecordingDelegate,VCSessionDelegate, NSURLSessionDelegate,NSURLSessionTaskDelegate,NSURLSessionDataDelegate, StreamingProtocol>

{
    SnapCamSelectionMode _snapCamMode;
}

//For CA7CH specific album in phone
@property (strong,nonatomic) ALAssetsLibrary *assetsLibrary;

//Video Core Session
@property (nonatomic, retain) VCSimpleSession* liveSteamSession;

// For use in the storyboards.
@property (nonatomic) IBOutlet AAPLPreviewView *previewView;
@property (nonatomic, weak) IBOutlet UIButton *cameraButton;
@property (nonatomic, weak) IBOutlet UIButton *startCameraActionButton;
@property (weak, nonatomic) IBOutlet UIImageView *thumbnailImageView;
@property (weak, nonatomic) IBOutlet UIButton *flashButton;

// Session management.
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;
@property (strong, nonatomic) IBOutlet UIView *topView;

// Utilities.
@property (nonatomic) AVCamSetupResult setupResult;
@property (nonatomic, getter=isSessionRunning) BOOL sessionRunning;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;
@property (strong, nonatomic) IBOutlet UIView *bottomView;

//Flash settings
@property (nonatomic) AVCaptureFlashMode currentFlashMode;
@property (strong, nonatomic) IBOutlet UIImageView *activityImageView;
@property (strong, nonatomic) IBOutlet UILabel *noDataFound;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *_activityIndicatorView;
@property (strong, nonatomic) IBOutlet UIView *activitView;
@property (strong, nonatomic) IBOutlet UIButton *iphoneCameraButton;
@property (strong, nonatomic) IBOutlet UIButton *firstButton;
@property (strong, nonatomic) IBOutlet UIButton *secondButton;
@property (strong, nonatomic) IBOutlet UIButton *thirdButton;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewAnimate;

@end

int orientationFlag = 0;

UIView *snapshot;

@implementation IPhoneCameraViewController

IPhoneLiveStreaming * liveStreaming;
LiveStreamingHelpers *helper;
FileManagerViewController *fileManager;
int cameraChangeFlag = 0;
NSInteger shutterActionMode;
bool takePictureFlag = false;
bool loadingCameraFlag = false;
bool backgroundEnterFlag = false;
NSTimer *timer;
int timerCount = 0;

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = true;
    [self.topView setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:0.4]];
    [self deleteIphoneCameraSnapShots];
    [self addApplicationObserversInIphone];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
         addObserver:self selector:@selector(orientationChanged2:)
         name:UIDeviceOrientationDidChangeNotification
         object:[UIDevice currentDevice]];
        [self setButtonCornerRadius];
        [self setGUIBasedOnMode];
    });
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    self.assetsLibrary = nil;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"refreshLogin" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"stopInitialising" object:nil];
    
    if([self isStreamStarted]){
        [liveStreaming stopStreamingClicked];
        [_liveSteamSession endRtmpSession];
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"shutterActionMode"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"StartedStreaming"];
    }
    
    if(self.sessionQueue != nil){
        dispatch_async( self.sessionQueue, ^{
            if ( self.setupResult == AVCamSetupResultSuccess ) {
                [self.session stopRunning];
                [self removeObservers:@"remove" completion:^{
                    
                }];
            }
        });
    }
    else{
        if ( self.setupResult == AVCamSetupResultSuccess ) {
            [self.session stopRunning];
            [self removeObservers:@"remove" completion:^{
                
            }];
        }
    }
    
    if (self.videoDeviceInput.device.torchMode == AVCaptureTorchModeOff) {
    }else {
        [self.videoDeviceInput.device lockForConfiguration:nil];
        [self.videoDeviceInput.device setTorchMode:AVCaptureTorchModeOff];
        [self.videoDeviceInput.device unlockForConfiguration];
    }
    
    takePictureFlag = false;
    [self stopTimer];
}

-(void)addApplicationObserversInIphone
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackgrounds:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidActives:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopInitialisation:) name:@"stopInitialising" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkCountForLabel) name:@"PushNotificationIphone" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadInitialView) name:@"refreshLogin" object:nil];
    
}

- (void) orientationChanged2:(NSNotification *)note
{
    UIViewController *viewContr = self.navigationController.visibleViewController;
    if([viewContr.restorationIdentifier  isEqual: @"IPhoneCameraViewController"])
    {
        UIDevice *device = note.object;
        switch(device.orientation)
        {
            case UIDeviceOrientationPortrait:
                orientationFlag = 1;
                break;
                
            case UIDeviceOrientationPortraitUpsideDown:
                orientationFlag = 2;
                break;
                
            case UIDeviceOrientationLandscapeLeft:
                orientationFlag = 3;
                break;
                
            case UIDeviceOrientationLandscapeRight:
                orientationFlag = 4;
                break;
                
            default:
                orientationFlag = 0;
                break;
        }
    }
}

-(void)applicationDidEnterBackgrounds: (NSNotification *)notification
{
    backgroundEnterFlag = true;
    [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"Background"];
    UIViewController *viewContr = self.navigationController.visibleViewController;
    if([viewContr.restorationIdentifier  isEqual: @"IPhoneCameraViewController"])
    {
        if (shutterActionMode == SnapCamSelectionModeVideo)
        {
            dispatch_async( dispatch_get_main_queue(), ^{
                if ([self.videoDeviceInput.device hasFlash]&&[self.videoDeviceInput.device hasTorch]) {
                    if (self.videoDeviceInput.device.torchMode == AVCaptureTorchModeOff) {
                    }else {
                        [self.videoDeviceInput.device lockForConfiguration:nil];
                        [self.videoDeviceInput.device setTorchMode:AVCaptureTorchModeOff];
                        [self.videoDeviceInput.device unlockForConfiguration];
                    }
                }
                [_startCameraActionButton setImage:[UIImage imageNamed:@"Camera_Button_OFF"] forState:UIControlStateNormal];
            });
            [self.movieFileOutput stopRecording];
        }
        else if(shutterActionMode == SnapCamSelectionModeLiveStream){
            [liveStreaming stopStreamingClicked];
            [_liveSteamSession endRtmpSession];
            [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"shutterActionMode"];
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"StartedStreaming"];
            dispatch_async( dispatch_get_main_queue(), ^{
                _liveSteamSession.previewView.backgroundColor = [UIColor clearColor];
                _liveSteamSession.previewView.hidden = false;
                [_iphoneCameraButton setImage:[UIImage imageNamed:@"iphone"] forState:UIControlStateNormal];
                _activityImageView.hidden = true;
                [__activityIndicatorView stopAnimating];
                __activityIndicatorView.hidden = true;
                _noDataFound.hidden = true;
                self.activitView.hidden = true;
                [self.bottomView setUserInteractionEnabled:YES];
            });
        }
    }
}

-(void)applicationDidActives: (NSNotification *)notification
{
    UIViewController *viewContr = self.navigationController.visibleViewController;
    if([viewContr.restorationIdentifier  isEqual: @"IPhoneCameraViewController"])
    {
        dispatch_async( dispatch_get_main_queue(), ^{
            if (shutterActionMode == SnapCamSelectionModeLiveStream)
            {
            }
            else{
                if (shutterActionMode == SnapCamSelectionModeVideo)
                {
                    dispatch_async( dispatch_get_main_queue(), ^{
                        if ([self.videoDeviceInput.device hasFlash]&&[self.videoDeviceInput.device hasTorch]) {
                            if (self.videoDeviceInput.device.torchMode == AVCaptureTorchModeOff) {
                            }else {
                                [self.videoDeviceInput.device lockForConfiguration:nil];
                                [self.videoDeviceInput.device setTorchMode:AVCaptureTorchModeOff];
                                [self.videoDeviceInput.device unlockForConfiguration];
                            }
                        }
                    });
                    [self.movieFileOutput stopRecording];
                }
                _cameraButton.hidden = false;
                if(flashFlag == 0){
                    _flashButton.hidden = false;
                }
                else if(flashFlag == 1){
                    _flashButton.hidden = true;
                }
                [_startCameraActionButton setImage:[UIImage imageNamed:@"Camera_Button_OFF"] forState:UIControlStateNormal];
                [_startCameraActionButton setImage:[UIImage imageNamed:@"camera_Button_ON"] forState:UIControlStateHighlighted];
            }
        });
    }
}

-(void) stopInitialisation : (NSNotification *)notif
{
    UIViewController *viewContr = self.navigationController.visibleViewController;
    if([viewContr.restorationIdentifier  isEqual: @"IPhoneCameraViewController"])
    {
        NSString *code = notif.object;
        loadingCameraFlag = false;
        [self hidingView];
        [self stopTimer];
        if([code  isEqual: @"noNetwork"]){
            [[ErrorManager sharedInstance] noNetworkConnection];
        }
        else if([code  isEqual: @"ResponseError"]){
            if(backgroundEnterFlag == false){
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Syncing Error"
                                                                message:@""
                                                               delegate:self
                                                      cancelButtonTitle:@"Retry"
                                                      otherButtonTitles:@"Exit App",nil];
                [alert show];
            }
        }
        else if(([code  isEqual: @"USER004"]) || ([code  isEqual: @"USER005"]) || ([code  isEqual: @"USER006"])){
            [self loadInitialView];
        }
    }
}

-(void) loadInitialView
{
    if([[NSUserDefaults standardUserDefaults] valueForKey:@"tokenValid"] != nil)
    {
        NSString *tokenValid = [[NSUserDefaults standardUserDefaults] valueForKey:@"tokenValid"];
        if([tokenValid isEqual:@"true"]){
            [self stopTimer];
            dispatch_async( dispatch_get_main_queue(), ^{
                NSURL *documentsPath  = [[FileManagerViewController sharedInstance] getParentDirectoryPath];
                NSString *path = documentsPath.absoluteString;
                
                if([[NSFileManager defaultManager] fileExistsAtPath:path]){
                    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
                }
                [[FileManagerViewController sharedInstance] createParentDirectory];
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                NSString *accessToken = [defaults valueForKey:@"deviceToken"];
                NSString *iden = [[NSBundle mainBundle] bundleIdentifier];
                [defaults removePersistentDomainForName:iden];
                [defaults setValue:accessToken forKey:@"deviceToken"];
                [defaults setInteger:1 forKey:@"shutterActionMode"];
                [defaults setValue:@"false" forKey:@"tokenValid"];
                
                [[ErrorManager sharedInstance] invalidTockenError];
                
                UIStoryboard  *login = [UIStoryboard storyboardWithName:@"Authentication" bundle:nil];
                UIViewController *authenticate = [login instantiateViewControllerWithIdentifier:@"AuthenticateViewController"];
                authenticate.navigationController.navigationBarHidden = true;
                [[self navigationController] pushViewController:authenticate animated:false];
            });
        }
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        _noDataFound.text = @"   Syncing...";
        [self loadingView:@"load" completion:^{
        }];
        timerCount = timerCount * 2;
        [self initialiseTimerForSyncing:timerCount];
        [self initialiseAPICall];
    }
    else{
        exit(0);
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.playiIconView.hidden = YES;
    });
    snapshot = [[UIView alloc]init];
    shutterActionMode = [[NSUserDefaults standardUserDefaults] integerForKey:@"shutterActionMode"];
    _noDataFound.lineBreakMode = NSLineBreakByWordWrapping;
    _noDataFound.numberOfLines = 0;
    _assetsLibrary = [[ALAssetsLibrary alloc]init];
    takePictureFlag = false;
    
    dispatch_async( dispatch_get_main_queue(), ^{
        [_startCameraActionButton setImage:[UIImage imageNamed:@"Camera_Button_OFF"] forState:UIControlStateNormal];
        [_startCameraActionButton setImage:[UIImage imageNamed:@"camera_Button_ON"] forState:UIControlStateHighlighted];
    });
    
    [self loadingView:@"load" completion:^{
        if([[NSUserDefaults standardUserDefaults] valueForKey:@"CallingAPI"] != nil)
        {
            timerCount = 50;
            NSString *initialCall = [[NSUserDefaults standardUserDefaults] valueForKey:@"CallingAPI"];
            if([initialCall isEqualToString:@"initialCall"])
            {
                loadingCameraFlag = true;
                if([[NSUserDefaults standardUserDefaults] valueForKey:@"notificationArrived"] != nil)
                {
                    if([[[NSUserDefaults standardUserDefaults] valueForKey:@"notificationArrived"]  isEqual: @"0"])
                    {
                        [self initialiseTimerForSyncing:timerCount];
                    }
                }
            }
            else{
                NSString *loading = [[NSUserDefaults standardUserDefaults] valueForKey:@"viewFromWhichPage"];
                if([loading  isEqual: @"appDelegateRedirection"]){
                    loadingCameraFlag = true;
                    if([[NSUserDefaults standardUserDefaults] valueForKey:@"notificationArrived"] != nil)
                    {
                        if([[[NSUserDefaults standardUserDefaults] valueForKey:@"notificationArrived"]  isEqual: @"0"])
                        {
                            [self initialiseTimerForSyncing:timerCount];
                        }
                    }
                    dispatch_async( dispatch_get_main_queue(), ^{
                        [self initialiseAPICall];
                    });
                }
                else{
                    dispatch_async( dispatch_get_main_queue(), ^{
                        [self updateThumbnails];
                    });
                    loadingCameraFlag = false;
                    _noDataFound.text = @"Loading camera...";
                }
            }
        }
        else{
            timerCount = 50;
            loadingCameraFlag = true;
            if([[NSUserDefaults standardUserDefaults] valueForKey:@"notificationArrived"] != nil)
            {
                if([[[NSUserDefaults standardUserDefaults] valueForKey:@"notificationArrived"]  isEqual: @"0"])
                {
                    [self initialiseTimerForSyncing:timerCount];
                }
            }
            dispatch_async( dispatch_get_main_queue(), ^{
                [self initialiseAPICall];
            });
        }
        
        if(takePictureFlag == false)
        {
            PhotoViewerInstance.iphoneCam = self;
            SetUpView *viewSet = [[SetUpView alloc]init];
            [viewSet getValue];
        }
        
        [[NSUserDefaults standardUserDefaults] setValue:@"secondCall" forKey:@"CallingAPI"];
        [[NSUserDefaults standardUserDefaults] setValue:@"otherPageRedirection" forKey:@"viewFromWhichPage"];
        
    }];
    backgroundEnterFlag = false;
}

-(void) updateThumbnails
{
    NSString *archiveChanelId = [NSString stringWithFormat:@"%@", [[NSUserDefaults standardUserDefaults] valueForKey:@"archiveId"]];
    GlobalChannelToImageMapping *GlobalChannelToImageMappingObj = [GlobalChannelToImageMapping sharedInstance];
    if(GlobalChannelToImageMappingObj.GlobalChannelImageDict.count > 0){
        if(GlobalChannelToImageMappingObj.GlobalChannelImageDict[archiveChanelId].count > 0)
        {
            UIImage *img = [[UIImage alloc]init];
            if(GlobalChannelToImageMappingObj.GlobalChannelImageDict[archiveChanelId][0][@"thumbImage"] != nil)
            {
                img = GlobalChannelToImageMappingObj.GlobalChannelImageDict[archiveChanelId][0][@"thumbImage"];
                NSString *type = GlobalChannelToImageMappingObj.GlobalChannelImageDict[archiveChanelId][0][@"media_type"];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if([type  isEqual: @"video"])
                    {
                        self.playiIconView.hidden = NO;
                    }
                    else{
                        self.playiIconView.hidden = YES;
                    }
                    self.thumbnailImageView.image = img;
                });
            }
            else{
                img = [UIImage imageNamed:@"thumb12"];
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.thumbnailImageView.image = img;
                });
                
            }
        }
    }
}

-(void)loadingView : (NSString *)name completion:(void (^)(void))completionBlock
{
    dispatch_async( dispatch_get_main_queue(), ^{
        self.activitView.hidden =false;
        self.startCameraActionButton.enabled = false;
        _activityImageView.image =  [UIImage animatedImageNamed:@"loader-" duration:1.0f];
        _activityImageView.hidden = false;
        [__activityIndicatorView startAnimating];
        __activityIndicatorView.hidden = false;
        _noDataFound.hidden = false;
        
    });
    [self enabelOrDisableButtons:0];
    completionBlock();
}

- (void)dealloc {
    if ( SessionRunningContext != nil && CapturingStillImageContext != nil)
    {
    }
    for(AVCaptureInput *input1 in _session.inputs) {
        [_session removeInput:input1];
    }
    for(AVCaptureOutput *output1 in _session.outputs) {
        [_session removeOutput:output1];
    }
    _session=nil;
    _stillImageOutput = nil;
}

-(void) initialiseAPICall
{
    GlobalDataChannelList *GlobalDataChannelListObj = [GlobalDataChannelList sharedInstance];
    [GlobalDataChannelListObj initialise];
    
    ChannelSharedListAPI *ChannelSharedListAPIObj = [ChannelSharedListAPI sharedInstance];
    if (ChannelSharedListAPIObj.SharedChannelListDataSource.count == 0) {
        [ChannelSharedListAPIObj initialisedata];
    }
}

-(void) initialiseTimerForSyncing : (int)count
{
    _noDataFound.text = @"   Syncing...";
    [self stopTimer];
    timer = [NSTimer scheduledTimerWithTimeInterval:count target:self selector:@selector(thisMethodGetsFiredOnceEveryThirtySeconds:) userInfo:nil repeats:NO];
    timeSec = timeSec + count;
}

-(void ) stopTimer
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [timer invalidate];
        timer = nil;
    });
    timeSec = 0 ;
}

- (void) thisMethodGetsFiredOnceEveryThirtySeconds:(NSTimer *)sender {
    UIViewController *viewContr = self.navigationController.visibleViewController;
    if([viewContr.restorationIdentifier  isEqual: @"IPhoneCameraViewController"])
    {
        if(!_activityImageView.hidden)
        {
            dispatch_async( dispatch_get_main_queue(), ^{
                if(backgroundEnterFlag == false){
                    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"Background"])
                    {
                        if([[UIApplication sharedApplication] applicationState] != UIApplicationStateInactive){
                            
                            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Syncing Error Timer"                                                                message:@""
                                                                           delegate:self
                                                                  cancelButtonTitle:@"Retry"
                                                                  otherButtonTitles:@"Exit App",nil];
                            [alert show];
                        }
                    }
                }
                else{
                    [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"Background"];
                }
            });
        }
        loadingCameraFlag = false;
        [self hidingView];
    }
}

-(void) setLeftAndRightThumbnailInCameraPage
{
    NSString *archiveChanelId = [[NSUserDefaults standardUserDefaults] valueForKey:@"archiveId"];
    GlobalChannelToImageMapping *GlobalChannelToImageMappingObj = [GlobalChannelToImageMapping sharedInstance];
    if (GlobalChannelToImageMappingObj.GlobalChannelImageDict[archiveChanelId].count > 0)
    {
        UIImage *img = [[UIImage alloc]init];
        img = GlobalChannelToImageMappingObj.GlobalChannelImageDict[archiveChanelId][0][@"thumbImage"];
        NSString *type = GlobalChannelToImageMappingObj.GlobalChannelImageDict[archiveChanelId][0][@"media_type"];
        dispatch_async(dispatch_get_main_queue(), ^{
            if([type  isEqual: @"video"])
            {
                self.playiIconView.hidden = NO;
            }
            else{
                self.playiIconView.hidden = YES;
            }
            self.thumbnailImageView.image = img;
        });
    }
    
    GlobalStreamList *GlobalStreamListObj = [GlobalStreamList sharedInstance];
    if(GlobalStreamListObj.GlobalStreamDataSource.count > 0)
    {
        UIImage *img = [[UIImage alloc]init];
        img = GlobalStreamListObj.GlobalStreamDataSource[0][@"thumbImage"];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.latestSharedMediaImage.image = img;
        });
    }
}

-(void) setGUIBasedOnMode{
    if (![self isStreamStarted]) {
        if (shutterActionMode == SnapCamSelectionModeLiveStream)
        {
            _flashButton.hidden = true;
            _cameraButton.hidden = true;
            
            if([[NSUserDefaults standardUserDefaults] valueForKey:@"liveResolution"] != nil)
            {
                NSString *resolution = [[NSUserDefaults standardUserDefaults] valueForKey:@"liveResolution"];
                if([resolution isEqualToString:@"240p"])
                {
                    _liveSteamSession = [[VCSimpleSession alloc] initWithVideoSize:CGSizeMake(352,240) frameRate:30 bitrate:40000 useInterfaceOrientation:YES];
                }
                else if([resolution isEqualToString:@"360p"])
                {
                    _liveSteamSession = [[VCSimpleSession alloc] initWithVideoSize:CGSizeMake(480,360) frameRate:30 bitrate:75000 useInterfaceOrientation:YES];
                }
                else if([resolution isEqualToString:@"480p"])
                {
                    _liveSteamSession = [[VCSimpleSession alloc] initWithVideoSize:CGSizeMake(850,480) frameRate:30 bitrate:100000 useInterfaceOrientation:YES];
                }
                else if([resolution isEqualToString:@"720p"])
                {
                    _liveSteamSession = [[VCSimpleSession alloc] initWithVideoSize:CGSizeMake(1280,720) frameRate:30 bitrate:250000 useInterfaceOrientation:YES];
                }
                else if([resolution isEqualToString:@"1080p"])
                {
                    _liveSteamSession = [[VCSimpleSession alloc] initWithVideoSize:CGSizeMake(1920,1080) frameRate:30 bitrate:450000 useInterfaceOrientation:YES];
                }
            }
            else{
                _liveSteamSession = [[VCSimpleSession alloc] initWithVideoSize:CGSizeMake(1280, 720) frameRate:30 bitrate:250000 useInterfaceOrientation:YES];
            }
            [_liveSteamSession.previewView removeFromSuperview];
            AVCaptureVideoPreviewLayer  *ptr;
            [_liveSteamSession getCameraPreviewLayer:(&ptr)];
            _liveSteamSession.previewView.frame = self.view.bounds;
            _liveSteamSession.delegate = self;
        }
        else{
            [_liveSteamSession.previewView removeFromSuperview];
            _liveSteamSession.delegate = nil;
            _cameraButton.hidden = false;
            if(flashFlag == 0){
                _flashButton.hidden = false;
            }
            else if(flashFlag == 1){
                _flashButton.hidden = true;
            }
            self.session = [[AVCaptureSession alloc] init];
            self.previewView.hidden = false;
            self.previewView.session = nil;
            [self configureCameraSettings:@"configure" completion:^{
                self.previewView.session = self.session;
                dispatch_async( self.sessionQueue, ^{
                    switch ( self.setupResult )
                    {
                        case AVCamSetupResultSuccess:
                        {
                            [self addObservers];
                            [self.session startRunning];
                            self.sessionRunning = self.session.isRunning;
                            if(loadingCameraFlag == false){
                                [self hidingView];
                            }
                            break;
                        }
                        case AVCamSetupResultCameraNotAuthorized:
                        {
                            dispatch_async( dispatch_get_main_queue(), ^{
                                NSString *message = NSLocalizedString( @"CA7CH doesn't have permission to use the camera, please change privacy settings", @"Alert message when the user has denied access to the camera");
                                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"AVCam" message:message preferredStyle:UIAlertControllerStyleAlert];
                                UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"OK", @"Alert OK button" ) style:UIAlertActionStyleCancel handler:nil];
                                [alertController addAction:cancelAction];
                                
                                UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"Settings", @"Alert button to open Settings" ) style:UIAlertActionStyleDefault handler:^( UIAlertAction *action ) {
                                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                                }];
                                [alertController addAction:settingsAction];
                                [self presentViewController:alertController animated:YES completion:nil];
                            } );
                            break;
                        }
                        case AVCamSetupResultSessionConfigurationFailed:
                        {
                            dispatch_async( dispatch_get_main_queue(), ^{
                                [self setGUIBasedOnMode];
                            } );
                            
                            break;
                        }
                    }
                });
            }];
        }
    }
}

-(BOOL) isStreamStarted
{
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"StartedStreaming"];
}

-(void)configureCameraSettings: (NSString *)name completion:(void (^)(void))completionBlock
{
    self.sessionQueue = dispatch_queue_create( "session queue", DISPATCH_QUEUE_SERIAL );
    self.setupResult = AVCamSetupResultSuccess;
    switch ( [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo] )
    {
        case AVAuthorizationStatusAuthorized:
        {
            break;
        }
        case AVAuthorizationStatusNotDetermined:
        {
            dispatch_suspend( self.sessionQueue);
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^( BOOL granted ) {
                if ( ! granted ) {
                    self.setupResult = AVCamSetupResultCameraNotAuthorized;
                }
                dispatch_resume( self.sessionQueue );
            }];
            break;
        }
        default:
        {
            self.setupResult = AVCamSetupResultCameraNotAuthorized;
            break;
        }
    }
    
    dispatch_async( self.sessionQueue, ^{
        if ( self.setupResult != AVCamSetupResultSuccess ) {
            return;
        }
        self.backgroundRecordingID = UIBackgroundTaskInvalid;
        NSError *error = nil;
        
        AVCaptureDevice *videoDevice = [IPhoneCameraViewController deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionBack];
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        
        [self.session beginConfiguration];
        
        if ( [self.session canAddInput:videoDeviceInput] ) {
            [self.session addInput:videoDeviceInput];
            self.videoDeviceInput = videoDeviceInput;
            UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
            AVCaptureVideoOrientation initialVideoOrientation = AVCaptureVideoOrientationPortrait;
            if ( statusBarOrientation != UIInterfaceOrientationUnknown ) {
                initialVideoOrientation = (AVCaptureVideoOrientation)statusBarOrientation;
            }
            AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
            if (shutterActionMode == SnapCamSelectionModeVideo)
            {
                [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
                if([self.session canSetSessionPreset:AVCaptureSessionPresetMedium]){
                    [self.session setSessionPreset:AVCaptureSessionPresetMedium];
                }
            }
            previewLayer.connection.videoOrientation = initialVideoOrientation;
        }
        else {
            self.setupResult = AVCamSetupResultSessionConfigurationFailed;
        }
        
        AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
        
        if ( ! audioDeviceInput ) {
        }
        
        if ( [self.session canAddInput:audioDeviceInput] ) {
            [self.session addInput:audioDeviceInput];
        }
        else {
        }
        
        AVCaptureMovieFileOutput *movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
        Float64 TotalSeconds = 10*60;
        int32_t preferredTimeScale = 30;
        CMTime maxDuration = CMTimeMakeWithSeconds(TotalSeconds, preferredTimeScale);
        movieFileOutput.maxRecordedDuration = maxDuration;
        movieFileOutput.minFreeDiskSpaceLimit = 1024 * 1024 * 100;
        
        if ( [self.session canAddOutput:movieFileOutput] ) {
            [self.session addOutput:movieFileOutput];
            AVCaptureConnection *connection = [movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
            if ( connection.isVideoStabilizationSupported ) {
                connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
            }
            self.movieFileOutput = movieFileOutput;
        }
        else
        {
            self.setupResult = AVCamSetupResultSessionConfigurationFailed;
        }
        
        AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        if ( [self.session canAddOutput:stillImageOutput] ) {
            stillImageOutput.outputSettings = @{AVVideoCodecKey : AVVideoCodecJPEG};
            [self.session addOutput:stillImageOutput];
            self.stillImageOutput = stillImageOutput;
        }
        else {
            self.setupResult = AVCamSetupResultSessionConfigurationFailed;
        }
        
        [self.session commitConfiguration];
    } );
    completionBlock();
}

-(void)hidingView
{
    dispatch_async( dispatch_get_main_queue(), ^{
        self.activitView.hidden = true;
        self.startCameraActionButton.enabled = true;
        _activityImageView.hidden = true;
        [__activityIndicatorView stopAnimating];
        __activityIndicatorView.hidden = true;
        _noDataFound.text = @"";
        _noDataFound.hidden = true;
        
        [self initialise];
    });
    [self enabelOrDisableButtons:1];
}

-(void) initialise{
    [self checkCountForLabel];
    [self setGUIModifications];
    fileManager = [[FileManagerViewController alloc]init];
    liveStreaming = [[IPhoneLiveStreaming alloc]init];
    helper = [[LiveStreamingHelpers alloc]init];
}

-(void)enabelOrDisableButtons: (int)value
{
    dispatch_async( dispatch_get_main_queue(), ^{
        if(value == 1){
            self.topView.userInteractionEnabled = true;
            self.bottomView.userInteractionEnabled = true;
        }
        else{
            self.topView.userInteractionEnabled = false;
            self.bottomView.userInteractionEnabled = false;
        }
    });
}

-(void) setButtonCornerRadius{
    _firstButton.imageView.layer.cornerRadius = _firstButton.frame.size.width/2;
    _firstButton.layer.cornerRadius = _firstButton.frame.size.width/2;
    _firstButton.layer.masksToBounds = YES;
    _secondButton.imageView.layer.cornerRadius = _firstButton.frame.size.width/2;
    _secondButton.layer.cornerRadius = _firstButton.frame.size.width/2;
    _secondButton.layer.masksToBounds = YES;
    _thirdButton.imageView.layer.cornerRadius = _firstButton.frame.size.width/2;
    _thirdButton.layer.cornerRadius = _firstButton.frame.size.width/2;
    _thirdButton.layer.masksToBounds = YES;
    _countLabel.layer.cornerRadius = 5;
    _countLabel.layer.masksToBounds = true;
}

-(void) setGUIModifications{
    _currentFlashMode = [[NSUserDefaults standardUserDefaults] integerForKey:@"flashMode"];
    if(_currentFlashMode == 0){
        [self.flashButton setImage:[UIImage imageNamed:@"flash_off"] forState:UIControlStateNormal];
    }
    else if(_currentFlashMode == 1){
        [self.flashButton setImage:[UIImage imageNamed:@"flash_On"] forState:UIControlStateNormal];
    }
    _snapCamMode = SnapCamSelectionModeIPhone;
    flashFlag = 0;
    _activitView.hidden = YES;
}

-(void) checkCountForLabel
{
    NSArray *mediaArray = [[NSUserDefaults standardUserDefaults] objectForKey:@"Shared"];
    if([mediaArray count] <= 0)
    {
        [[NSUserDefaults standardUserDefaults] setObject:@"FirstEntry" forKey:@"First"];
    }
    NSInteger count = 0;
    for (int i=0;i< mediaArray.count;i++)
    {
        count = count + [ mediaArray[i][@"total_no_media_shared"] integerValue];
    }
    if(count==0)
    {
        _countLabel.hidden= true;
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            _countLabel.hidden= false;
            _countLabel.text = [NSString stringWithFormat:@"%ld",(long)count];
        });
    }
}

-(void) loggedInDetails:(NSDictionary *) detailArray userImages : (NSArray *) userImages{
    NSString * sharedUserCount = detailArray[@"sharedUserCount"];
    NSString * mediaSharedCount =  detailArray[@"mediaSharedCount"];
    NSString * latestSharedMediaThumbnail =   detailArray[@"latestSharedMediaThumbnail"];
    NSString * latestCapturedMediaThumbnail =detailArray[@"latestCapturedMediaThumbnail"];
    NSString *latestCapturedMediaType  =  detailArray[@"latestCapturedMediaType"];
    [[NSUserDefaults standardUserDefaults] setObject:mediaSharedCount forKey:@"mediaSharedCount"] ;
    
    NSString * latestMediaURL = [[UrlManager sharedInstance] getMediaURLWithMediaId:[NSString stringWithFormat:@"%@",latestCapturedMediaThumbnail]];
    
    NSString * latestSharedURL = [[UrlManager sharedInstance] getMediaURLWithMediaId:[NSString stringWithFormat:@"%@",latestSharedMediaThumbnail]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        _sharedUserCount.text = sharedUserCount;
        if(userImages.count > 0){
            for(int i=0;i<userImages.count;i++){
                if(i==0){
                    if(userImages[0] != nil){
                        [_firstButton setImage:userImages[0] forState:UIControlStateNormal];
                    }
                    else{
                        [_firstButton setImage:[UIImage imageNamed:@"dummyUser"] forState:UIControlStateNormal];
                    }
                }
                else if(i==1){
                    if(userImages[1] != nil){
                        [_secondButton setImage:userImages[1] forState:UIControlStateNormal];
                    }
                    else{
                        [_secondButton setImage:[UIImage imageNamed:@"dummyUser"] forState:UIControlStateNormal];
                    }
                }
                else if(i==2){
                    if(userImages[2] != nil){
                        [_thirdButton setImage:userImages[2] forState:UIControlStateNormal];
                    }
                    else{
                        [_thirdButton setImage:[UIImage imageNamed:@"dummyUser"] forState:UIControlStateNormal];
                    }
                }
            }
        }
    });
    
    if(takePictureFlag == false){
        dispatch_async(dispatch_get_global_queue(0,0), ^{
            NSData * data = [[NSData alloc] initWithContentsOfURL: [NSURL URLWithString: latestMediaURL]];
            
            if ( data == nil ){
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self updateThumbnails];
                });
            }
            else if ([UIImage imageWithData: data] == nil)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.thumbnailImageView.image = [UIImage imageNamed:@"thumb12"];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self updateThumbnails];
                    });
                    
                });
            }
            else{
                dispatch_async(dispatch_get_main_queue(), ^{
                    if([latestCapturedMediaType  isEqual: @"video"])
                    {
                        self.playiIconView.hidden = NO;
                    }
                    else{
                        self.playiIconView.hidden = YES;
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        self.thumbnailImageView.image = [UIImage imageWithData: data];
                    });
                });
            }
        });
    }
    else{
        [self updateThumbnails];
    }
    
    if([mediaSharedCount  isEqual: @"0"])
    {
        dispatch_async(dispatch_get_global_queue(0,0), ^{
            NSData * data = [[NSData alloc] initWithContentsOfURL: [NSURL URLWithString: latestSharedURL]];
            if ( data == nil )
                return;
            dispatch_async(dispatch_get_main_queue(), ^{
                self.latestSharedMediaImage.image= [UIImage imageWithData: data];
            });
        });
    }
    else{
        NSString *status = [[NSUserDefaults standardUserDefaults] objectForKey:@"First"];
        if([status isEqualToString:@"FirstEntry"])
        {
            _countLabel.hidden= false;
            _countLabel.text = mediaSharedCount;
            [[NSUserDefaults standardUserDefaults] setObject:@"default" forKey:@"First"] ;
        }
        NSArray *mediaArray = [[NSUserDefaults standardUserDefaults] objectForKey:@"Shared"];
        NSInteger count = 0;
        for (int i=0;i< mediaArray.count;i++)
        {
            count = count + [ mediaArray[i][@"total_no_media_shared"] integerValue];
        }
        if(count==0)
        {
            _countLabel.hidden= true;
            [self.view bringSubviewToFront:self.latestSharedMediaImage];
            dispatch_async(dispatch_get_global_queue(0,0), ^{
                NSData * data = [[NSData alloc] initWithContentsOfURL: [NSURL URLWithString: latestSharedURL]];
                if ( data == nil )
                    return;
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.latestSharedMediaImage.image = [UIImage imageWithData: data];
                });
            });
        }
    }
}

#pragma mark button action

- (IBAction)didTapChangeCamera:(id)sender
{
    [UIView transitionWithView:_previewView duration:0.5 options:UIViewAnimationOptionTransitionFlipFromLeft animations:nil completion:^(BOOL finished) {
    }];
    dispatch_async( self.sessionQueue, ^{
        AVCaptureDevice *currentVideoDevice = self.videoDeviceInput.device;
        AVCaptureDevicePosition preferredPosition = AVCaptureDevicePositionUnspecified;
        AVCaptureDevicePosition currentPosition = currentVideoDevice.position;
        
        switch ( currentPosition )
        {
            case AVCaptureDevicePositionUnspecified:
            case AVCaptureDevicePositionFront:
                preferredPosition = AVCaptureDevicePositionBack;
                [self showFlashImage:true];
                break;
            case AVCaptureDevicePositionBack:
                preferredPosition = AVCaptureDevicePositionFront;
                [self showFlashImage:false];
                break;
        }
        
        AVCaptureDevice *videoDevice = [IPhoneCameraViewController deviceWithMediaType:AVMediaTypeVideo preferringPosition:preferredPosition];
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
        [self.session beginConfiguration];
        [self.session removeInput:self.videoDeviceInput];
        
        if ( [self.session canAddInput:videoDeviceInput] ) {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:currentVideoDevice];
            
            [IPhoneCameraViewController setFlashMode:self.currentFlashMode forDevice:videoDevice];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:videoDevice];
            
            [self.session addInput:videoDeviceInput];
            self.videoDeviceInput = videoDeviceInput;
        }
        else {
            [self.session addInput:self.videoDeviceInput];
        }
        
        AVCaptureConnection *connection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ( connection.isVideoStabilizationSupported ) {
            connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
        }
        [self.session commitConfiguration];
    } );
}

-(void)showFlashImage:(BOOL)show
{
    if (show) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.flashButton.hidden = false;
            flashFlag = 0;
        });
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.flashButton.hidden = true;
            flashFlag = 1;
        });
    }
}

- (IBAction)didTapFlashImage:(id)sender {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (_currentFlashMode == AVCaptureFlashModeOn) {
        [self.flashButton setImage:[UIImage imageNamed:@"flash_off"] forState:UIControlStateNormal];
        _currentFlashMode = AVCaptureFlashModeOff;
        [defaults setInteger:_currentFlashMode forKey:@"flashMode"];
    }
    else{
        [self.flashButton setImage:[UIImage imageNamed:@"flash_On"] forState:UIControlStateNormal];
        _currentFlashMode = AVCaptureFlashModeOn;
        [defaults setInteger:_currentFlashMode forKey:@"flashMode"];
    }
}

- (IBAction)didTapsCameraActionButton:(id)sender
{
    if (shutterActionMode == SnapCamSelectionModePhotos) {
        dispatch_async(dispatch_get_main_queue(), ^{
            _cameraButton.hidden = false;
            _playiIconView.hidden = true;
            if(_flashButton.isHidden) {
                _flashButton.hidden = true;
            }
            else{
                _flashButton.hidden = false;
            }
        });
        [self takePicture];
    }
    else if (shutterActionMode == SnapCamSelectionModeVideo)
    {
        [UIApplication sharedApplication].idleTimerDisabled = YES;
        [self startMovieRecording];
    }
    else if (shutterActionMode == SnapCamSelectionModeLiveStream)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            _flashButton.hidden = true;
            _cameraButton.hidden = true;
        });
        
        switch(_liveSteamSession.rtmpSessionState) {
            case VCSessionStateNone:
            case VCSessionStatePreviewStarted:
            case VCSessionStateEnded:
            case VCSessionStateError:
            {
                [liveStreaming startLiveStreamingWithSession:_liveSteamSession];
                [self showProgressBar];
                break;
            }
            default:
                [UIApplication sharedApplication].idleTimerDisabled = NO;
                [liveStreaming stopStreamingClicked];
                [_liveSteamSession endRtmpSession];
                break;
        }
    }
}

#pragma mark take photo

-(void)takePicture
{
    if(self.session != nil){
        dispatch_async( self.sessionQueue, ^{
            AVCaptureConnection *connection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
            AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
            connection.videoOrientation = previewLayer.connection.videoOrientation;
            
            UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
            
            if(orientationFlag == 1)
            {
                if(orientation ==1)
                {
                }
            }
            else
            {
                if(orientationFlag == 3)
                {
                    connection.videoOrientation = UIImageOrientationRight;
                }
                if(orientationFlag == 4)
                {
                    connection.videoOrientation = UIImageOrientationUpMirrored;
                }
                if (orientationFlag == 2)
                {
                    connection.videoOrientation = UIImageOrientationUpMirrored;
                    connection.videoOrientation = UIImageOrientationLeft;
                }
            }
            
            [IPhoneCameraViewController setFlashMode:self.currentFlashMode forDevice:self.videoDeviceInput.device];
            [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^( CMSampleBufferRef imageDataSampleBuffer, NSError *error ) {
                if ( imageDataSampleBuffer ) {
                    NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                    [PHPhotoLibrary requestAuthorization:^( PHAuthorizationStatus status ) {
                        if (status == PHAuthorizationStatusAuthorized ) {
                            dispatch_async( dispatch_get_main_queue(), ^{
                                self.thumbnailImageView.image = [self thumbnaleImage:[UIImage imageWithData:imageData] scaledToFillSize:CGSizeMake(thumbnailSize, thumbnailSize)];
                                takePictureFlag = true;
                                self.playiIconView.hidden = true;
                                self.imageViewAnimate.hidden = NO;
                                [self.view bringSubviewToFront:self.imageViewAnimate];
                                self.imageViewAnimate.image = [UIImage imageWithData:imageData];
                                [self cameraAnimation];
                                
                                if(orientationFlag == 4)
                                {
                                    UIImage *img1 = [UIImage imageWithData:imageData];
                                    UIImage *img2 = rotate(img1, UIImageOrientationUpMirrored);
                                    NSData *imageData1 = UIImageJPEGRepresentation(img2, 5.0);
                                    NSInteger isSave  = [[NSUserDefaults standardUserDefaults] integerForKey:@"SaveToCameraRoll"];
                                    if (isSave != 0)
                                    {
                                        [self.assetsLibrary saveImageData:imageData toAlbum:@"CA7CH" metadata:nil completion:^(NSURL *assetURL, NSError *error)
                                         {
                                         } failure:^(NSError *error)
                                         {
                                         }];
                                    }
                                    
                                    [self saveImage:imageData1];
                                    [self loaduploadManagerForImage];
                                }
                                else{
                                    NSInteger isSave  = [[NSUserDefaults standardUserDefaults] integerForKey:@"SaveToCameraRoll"];
                                    if (isSave != 0)
                                    {
                                        [self.assetsLibrary saveImageData:imageData toAlbum:@"CA7CH" metadata:nil completion:^(NSURL *assetURL, NSError *error)
                                         {
                                         } failure:^(NSError *error)
                                         {
                                         }];
                                    }
                                    
                                    [self saveImage:imageData];
                                    [self loaduploadManagerForImage];
                                }
                            });
                        }
                    }];
                }
                else {
                }
            }];
        });
    }
}

static inline double radians (double degrees) {return degrees * M_PI/180;}

UIImage* rotate(UIImage* src, UIImageOrientation orientation)
{
    UIGraphicsBeginImageContext(src.size);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    if (orientation == UIImageOrientationRight) {
        CGContextRotateCTM (context, radians(90));
    } else if (orientation == UIImageOrientationLeft) {
        CGContextRotateCTM (context, radians(-90));
    } else if (orientation == UIImageOrientationDown) {
    } else if (orientation == UIImageOrientationUp) {
        CGContextRotateCTM (context, radians(90));
    }
    
    [src drawAtPoint:CGPointMake(0, 0)];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

-(void)cameraAnimation
{
    snapshot = [self.imageViewAnimate snapshotViewAfterScreenUpdates:YES];
    snapshot.frame = self.imageViewAnimate.frame;
    [self.view addSubview:snapshot];
    
    [UIView animateKeyframesWithDuration:0.5 delay:0 options: UIViewKeyframeAnimationOptionCalculationModeCubic animations:^{
        [UIView addKeyframeWithRelativeStartTime:0 relativeDuration:0.5 animations:^{
            snapshot.frame = CGRectInset(self.imageViewAnimate.frame, self.imageViewAnimate.frame.size.width/2, self.imageViewAnimate.frame.size.height/2);
        }];
        
        [UIView addKeyframeWithRelativeStartTime:0.5 relativeDuration:0.4 animations:^{
            snapshot.frame = CGRectMake(self.view.frame.size.width*13.4/100, self.view.frame.size.height*85.4/100,44,44);
        }];
    }completion:nil];
    self.imageViewAnimate.image = nil;
    [UIView animateWithDuration:0.1 delay:0.4 options:UIViewAnimationOptionCurveEaseOut animations:^{
        snapshot.alpha = 0.0;
    } completion:nil];
}

#pragma mark save image to db

-(void)saveImage:(NSData *)imageData
{
    NSArray *paths= NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    NSString *filePath=@"";
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"dd_MM_yyyy_HH_mm_ss"];
    NSString *dateString = [dateFormatter stringFromDate:[NSDate date]];
    filePath = [documentsDirectory stringByAppendingPathComponent:dateString];
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
        [[NSFileManager defaultManager] createDirectoryAtPath:filePath withIntermediateDirectories:NO attributes:nil error:nil];
    NSString *imgStr = @"/image";
    NSString *orgFilePath = [NSString stringWithFormat:@"%@%@", filePath,imgStr];
    [imageData writeToFile:orgFilePath atomically:NO];
    [self saveIphoneCameraSnapShots:dateString path:orgFilePath];
}

-(void) saveIphoneCameraSnapShots :(NSString *)imageName path:(NSString *)path{
    AppDelegate *appDel = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    NSManagedObjectContext *context = appDel.managedObjectContext;
    NSManagedObject *newSnapShots =[NSEntityDescription insertNewObjectForEntityForName:@"SnapShots" inManagedObjectContext:context];
    [newSnapShots setValue:imageName forKey:@"imageName"];
    [newSnapShots setValue:path forKey:@"path"];
    [context save:nil];
}

-(void) loaduploadManagerForImage
{
    NSString *path = [self readIphoneCameraSnapShotsFromDB];
    uploadMediaToGCS *obj = [[uploadMediaToGCS alloc]init];
    obj.path = path;
    obj.media = @"image";
    [obj initialise];
}

-(NSString *) readIphoneCameraSnapShotsFromDB {
    AppDelegate *appDel = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    NSManagedObjectContext *context = appDel.managedObjectContext;
    
    NSFetchRequest *request = [[NSFetchRequest alloc]initWithEntityName:@"SnapShots"];
    request.returnsObjectsAsFaults=false;
    
    NSArray *snapShotsArray = [[NSArray alloc]init];
    NSString *snapImagePath;
    snapShotsArray = [context executeFetchRequest:request error:nil];
    
    if([snapShotsArray count] > 0){
        for(NSString *snapShotValue in snapShotsArray)
        {
            snapImagePath = [snapShotValue valueForKey:@"path"];
        }
    }
    return snapImagePath;
}

#pragma mark video recording

- (void)startMovieRecording
{
    dispatch_async( self.sessionQueue, ^{
        if ( ! self.movieFileOutput.isRecording ) {
            if ( [UIDevice currentDevice].isMultitaskingSupported ) {
                self.backgroundRecordingID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
            }
            dispatch_async( dispatch_get_main_queue(), ^{
                _cameraButton.hidden = true;
                _flashButton.hidden = true;
                [_startCameraActionButton setImage:[UIImage imageNamed:@"camera_Button_ON"] forState:UIControlStateNormal];
                if(self.currentFlashMode == 1){
                    if ([self.videoDeviceInput.device hasFlash]&&[self.videoDeviceInput.device hasTorch]) {
                        if (self.videoDeviceInput.device.torchMode == AVCaptureTorchModeOff) {
                            [self.videoDeviceInput.device lockForConfiguration:nil];
                            [self.videoDeviceInput.device setTorchMode:AVCaptureTorchModeOn];
                            [self.videoDeviceInput.device unlockForConfiguration];
                        }
                    }
                }
                [IPhoneCameraViewController setFlashMode:self.currentFlashMode forDevice:self.videoDeviceInput.device];
            });
            
            AVCaptureConnection *connection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
            AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
            connection.videoOrientation = previewLayer.connection.videoOrientation;
            
            UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
            
            if(orientationFlag == 1)
            {
                if(orientation ==1)
                {
                }
            }
            else
            {
                if(orientationFlag == 3)
                {
                    connection.videoOrientation = UIImageOrientationRight;
                }
                if(orientationFlag == 4)
                {
                    connection.videoOrientation = UIImageOrientationUpMirrored;
                }
                if (orientationFlag == 2)
                {
                    connection.videoOrientation = UIImageOrientationUpMirrored;
                    connection.videoOrientation = UIImageOrientationLeft;
                }
            }
            NSArray *paths= NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = [paths firstObject];
            NSString *filePath=@"";
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"dd_MM_yyyy_HH_mm_ss"];
            NSString *dateString = [dateFormatter stringFromDate:[NSDate date]];
            filePath = [documentsDirectory stringByAppendingPathComponent:dateString];
            NSString *outputFilePath = [filePath stringByAppendingString:@"_video.mov"];
            [self.movieFileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:outputFilePath] recordingDelegate:self];
        }
        else {
            dispatch_async( dispatch_get_main_queue(), ^{
                if ([self.videoDeviceInput.device hasFlash]&&[self.videoDeviceInput.device hasTorch]) {
                    if (self.videoDeviceInput.device.torchMode == AVCaptureTorchModeOff) {
                    }else {
                        [self.videoDeviceInput.device lockForConfiguration:nil];
                        [self.videoDeviceInput.device setTorchMode:AVCaptureTorchModeOff];
                        [self.videoDeviceInput.device unlockForConfiguration];
                    }
                }
                _cameraButton.hidden = false;
                if(flashFlag == 0){
                    _flashButton.hidden = false;
                }
                else if(flashFlag == 1){
                    _flashButton.hidden = true;
                }
                
                [_startCameraActionButton setImage:[UIImage imageNamed:@"Camera_Button_OFF"] forState:UIControlStateNormal];
            });
            [self.movieFileOutput stopRecording];
        }
    } );
}

-(void)showProgressBar
{
    dispatch_async( dispatch_get_main_queue(), ^{
        [_iphoneCameraButton setImage:[UIImage imageNamed:@"Live_now_off_mode"] forState:UIControlStateNormal];
        _flashButton.hidden = true;
        _cameraButton.hidden = true;
        _activityImageView.image =  [UIImage animatedImageNamed:@"loader-" duration:1.0f];
        _activityImageView.hidden = false;
        [__activityIndicatorView startAnimating];
        __activityIndicatorView.hidden = false;
        _noDataFound.text = @"Initializing Stream";
        _noDataFound.hidden = false;
        _liveSteamSession.previewView.hidden = true;
        [self setUpInitialBlurView];
    });
}

#pragma mark : VCSessionState Delegate

- (void) connectionStatusChanged:(VCSessionState) state
{
    switch(state) {
        case VCSessionStateStarting:
            break;
        case VCSessionStateStarted:
            [self hideProgressBar];
            [self performSelector:@selector(screenCapture) withObject:nil afterDelay:2.0];
            break;
        case VCSessionStateEnded:
            [[NSUserDefaults standardUserDefaults] setValue:false forKey:@"StartedStreaming"];
            [self setCameraImage];
            break;
        case VCSessionStateError:
            [[NSUserDefaults standardUserDefaults] setValue:false forKey:@"StartedStreaming"];
            [liveStreaming stopStreamingClicked];
            [self setCameraImage];
            break;
        default:
            [self hidingView];
            dispatch_async( dispatch_get_main_queue(), ^{
                self.previewView.session = nil;
                self.previewView.hidden = true;
                [self.view addSubview:_liveSteamSession.previewView];
                [self.view bringSubviewToFront:self.bottomView];
                [self.view bringSubviewToFront:self.topView];
            });
            break;
    }
}

-(void) setCameraImage
{
    dispatch_async( dispatch_get_main_queue(), ^{
        [_iphoneCameraButton setImage:[UIImage imageNamed:@"iphone"] forState:UIControlStateNormal];
    });
}

-(void)hideProgressBar
{
    dispatch_async( dispatch_get_main_queue(), ^{
        [_iphoneCameraButton setImage:[UIImage imageNamed:@"Live_now_mode"] forState:UIControlStateNormal];
        _activityImageView.hidden = true;
        [__activityIndicatorView stopAnimating];
        __activityIndicatorView.hidden = true;
        _noDataFound.hidden = true;
        self.activitView.hidden = true;
        _liveSteamSession.previewView.hidden = false;
        [self.bottomView setUserInteractionEnabled:YES];
        _firstButton.userInteractionEnabled = true;
        _secondButton.userInteractionEnabled = true;
        _thirdButton.userInteractionEnabled = true;
        _iphoneCameraButton.userInteractionEnabled = true;
    } );
}

#pragma mark save livestream images

-(void)screenCapture
{
    dispatch_async( dispatch_get_main_queue(), ^{
        CGSize size = CGSizeMake(_liveSteamSession.previewView.bounds.size.width,_liveSteamSession.previewView.bounds.size.height);
        
        UIGraphicsBeginImageContextWithOptions(size, NO, 7);
        CGRect rec = CGRectMake(0,0,_liveSteamSession.previewView.bounds.size.width,_liveSteamSession.previewView.bounds.size.height);
        
        [self.view drawViewHierarchyInRect:rec afterScreenUpdates:YES];
        
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        UIImage *image1 = [self thumbnaleImage:image scaledToFillSize:CGSizeMake(70, 70)];
        
        [self saveThumbnailImageLive:image1];
        [self uploadThumbToCloud:image1];
    });
    
}

-(void) saveThumbnailImageLive:(UIImage *)liveThumbImage{
    deleteCount = 0;
    NSString *userName = [[NSUserDefaults standardUserDefaults] objectForKey:@"userLoginIdKey"];
    NSString *finalPath = [NSString stringWithFormat:@"%@LiveThumb",userName];
    [[FileManagerViewController sharedInstance] saveImageToFilePathWithMediaName:finalPath mediaImage:liveThumbImage];
}

-(void) uploadThumbToCloud:(UIImage *)image
{
    NSString *urlStr = [[NSUserDefaults standardUserDefaults] objectForKey:@"liveStreamURL"];
    NSData *imageData = UIImageJPEGRepresentation(image, 0.5);
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc]initWithURL:[NSURL URLWithString:urlStr]];
    request.HTTPMethod = @"PUT";
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    request.HTTPBody = imageData;
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if(error != nil)
        {
        }
        else{
            [helper mapLiveStream];
            [self deleteThumbnailImageLive];
        }
    }];
    [dataTask resume];
}

-(void) deleteThumbnailImageLive{
    NSString *userName = [[NSUserDefaults standardUserDefaults] objectForKey:@"userLoginIdKey"];
    NSURL *parentPathStr = [[FileManagerViewController sharedInstance] getParentDirectoryPath];
    NSString *finalPath = [NSString stringWithFormat:@"%@/%@%@",parentPathStr,userName,@"LiveThumb"];
    [[FileManagerViewController sharedInstance] deleteImageFromFilePathWithMediaPath:finalPath];
}

#pragma mark KVO and Notifications

- (void)addObservers
{
    [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"HasObserver"];
    [self.session addObserver:self forKeyPath:@"running" options:NSKeyValueObservingOptionNew context:SessionRunningContext];
    [self.stillImageOutput addObserver:self forKeyPath:@"capturingStillImage" options:NSKeyValueObservingOptionNew context:CapturingStillImageContext];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:self.videoDeviceInput.device];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:self.session];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionWasInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:self.session];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionInterruptionEnded:) name:AVCaptureSessionInterruptionEndedNotification object:self.session];
}

- (void)removeObservers: (NSString *)name completion:(void (^)(void))completionBlock
{
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"HasObserver"] != nil)
    {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"HasObserver"])
        {
            if(SessionRunningContext != nil && self.stillImageOutput != nil  && CapturingStillImageContext != nil)
            {
                @try{
                    [self.session removeObserver:self forKeyPath:@"running" context:SessionRunningContext];
                    [self.stillImageOutput removeObserver:self forKeyPath:@"capturingStillImage" context:CapturingStillImageContext];
                    [[NSUserDefaults standardUserDefaults] setObject:false forKey:@"HasObserver"];
                }@catch(id anException){
                    [[NSUserDefaults standardUserDefaults] setObject:false forKey:@"HasObserver"];
                }
            }
            [self.session stopRunning];
            completionBlock();
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if(CapturingStillImageContext != nil){
        if ( context == CapturingStillImageContext ) {
            BOOL isCapturingStillImage = [change[NSKeyValueChangeNewKey] boolValue];
            
            if ( isCapturingStillImage ) {
                dispatch_async( dispatch_get_main_queue(), ^{
                    self.previewView.layer.opacity = 0.0;
                    [UIView animateWithDuration:0.25 animations:^{
                        self.previewView.layer.opacity = 1.0;
                    }];
                } );
            }
        }
    }
    else if (context == SessionRunningContext ) {
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)sessionRuntimeError:(NSNotification *)notification
{
    NSError *error = notification.userInfo[AVCaptureSessionErrorKey];
    if ( error.code == AVErrorMediaServicesWereReset ) {
        dispatch_async( self.sessionQueue, ^{
            if ( self.isSessionRunning ) {
                [self.session startRunning];
                self.sessionRunning = self.session.isRunning;
            }
            else {
                dispatch_async( dispatch_get_main_queue(), ^{
                } );
            }
        } );
    }
    else {
    }
}

- (void)sessionWasInterrupted:(NSNotification *)notification
{
    BOOL showResumeButton = NO;
    if ( &AVCaptureSessionInterruptionReasonKey ) {
        AVCaptureSessionInterruptionReason reason = [notification.userInfo[AVCaptureSessionInterruptionReasonKey] integerValue];
        if ( reason == AVCaptureSessionInterruptionReasonAudioDeviceInUseByAnotherClient ||
            reason == AVCaptureSessionInterruptionReasonVideoDeviceInUseByAnotherClient ) {
            showResumeButton = YES;
        }
        else if ( reason == AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableWithMultipleForegroundApps ) {
            [UIView animateWithDuration:0.25 animations:^{
            }];
        }
    }
    else {
        showResumeButton = ( [UIApplication sharedApplication].applicationState == UIApplicationStateInactive );
    }
    
    if ( showResumeButton ) {
        [UIView animateWithDuration:0.25 animations:^{
        }];
    }
}

- (void)sessionInterruptionEnded:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self removeObservers:@"remove" completion:^{
            [self setGUIBasedOnMode];
            
        }];
    });
}

#pragma mark File Output Recording Delegate

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    self.backgroundRecordingID = UIBackgroundTaskInvalid;
    BOOL success = YES;
    
    if ( error ) {
        success = [error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] boolValue];
    }
    if ( success ) {
        
        NSData *videoData = [[NSData alloc]initWithContentsOfURL:outputFileURL];
        NSURL *videoUrl = [self writeVideoDataToLocalFile:videoData];
        
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:outputFileURL
                                                    options:[NSDictionary dictionaryWithObjectsAndKeys:
                                                             [NSNumber numberWithBool:YES],
                                                             AVURLAssetPreferPreciseDurationAndTimingKey,
                                                             nil]];
        NSTimeInterval durationInSeconds = 0.0;
        if (asset){
            durationInSeconds = CMTimeGetSeconds(asset.duration) ;
        }
        [PHPhotoLibrary requestAuthorization:^( PHAuthorizationStatus status ) {
            if ( status == PHAuthorizationStatusAuthorized ) {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSData *imageData = [[NSData alloc]init];
                        imageData = [self getThumbNail:outputFileURL];
                        self.thumbnailImageView.image = [self thumbnaleImage:[UIImage imageWithData:imageData] scaledToFillSize:CGSizeMake(thumbnailSize, thumbnailSize)];
                        self.imageViewAnimate.image = [self thumbnaleImage:[UIImage imageWithData:imageData] scaledToFillSize:CGSizeMake(thumbnailSize, thumbnailSize)];
                        [self cameraAnimation];
                        takePictureFlag = true;
                        [_playiIconView setHidden:NO];
                        if(imageData != nil){
                            NSDate* d = [NSDate dateWithTimeIntervalSince1970:durationInSeconds];
                            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                            [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
                            [dateFormatter setDateFormat:@"HH:mm:ss"];
                            NSString* result = [dateFormatter stringFromDate:d];
                            [self saveImage:imageData];
                            [self moveVideoToDocumentDirectory:videoUrl videoDuration:result];
                            
                            NSInteger isSave  = [[NSUserDefaults standardUserDefaults] integerForKey:@"SaveToCameraRoll"];
                            if (isSave != 0)
                            {
                                [self.assetsLibrary saveVideo:videoUrl toAlbum:@"CA7CH" completion:^(NSURL *assetURL, NSError *error)
                                 {
                                 } failure:^(NSError *error)
                                 {
                                 }];
                            }
                        }
                    });
                } completionHandler:^( BOOL success, NSError *error ) {
                    if ( ! success ) {
                    }
                }];
            }
            else {
            }
        }];
    }
    else {
    }
    dispatch_async( dispatch_get_main_queue(), ^{
        self.cameraButton.enabled = ( [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count > 1 );
    });
}

-(NSURL *) writeVideoDataToLocalFile: (NSData *) videoData
{
    NSArray *paths= NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    NSString *filePath=@"";
    NSString *orgFilePath=@"";
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"dd_MM_yyyy_HH_mm_ss"];
    NSString *dateString = [dateFormatter stringFromDate:[NSDate date]];
    filePath = [documentsDirectory stringByAppendingPathComponent:dateString];
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
        [[NSFileManager defaultManager] createDirectoryAtPath:filePath withIntermediateDirectories:NO attributes:nil error:nil];
    NSString *videoStr = @"/video.mov";
    orgFilePath = [NSString stringWithFormat:@"%@%@", filePath,videoStr];
    [videoData writeToFile:orgFilePath atomically:NO];
    NSURL *filePathUrl = [NSURL URLWithString:orgFilePath];
    return filePathUrl;
}

#pragma mark save video
-(void) moveVideoToDocumentDirectory : (NSURL *) path videoDuration: (NSString *) duration
{
    [self loaduploadManager : path videoDuration:duration];
}

-(void) loaduploadManager : (NSURL *)filePath videoDuration: (NSString *) duration
{
    NSString *path = [self readIphoneCameraSnapShotsFromDB];
    uploadMediaToGCS *obj = [[uploadMediaToGCS alloc]init];
    obj.path = path;
    obj.media = @"video";
    obj.videoDuration = duration;
    obj.videoSavedURL = filePath;
    [obj initialise];
}

#pragma mark Device Configuration
- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
    dispatch_async( self.sessionQueue, ^{
        AVCaptureDevice *device = self.videoDeviceInput.device;
        NSError *error = nil;
        if ( [device lockForConfiguration:&error] ) {
            if ( device.isFocusPointOfInterestSupported && [device isFocusModeSupported:focusMode] ) {
                device.focusPointOfInterest = point;
                device.focusMode = focusMode;
            }
            
            if ( device.isExposurePointOfInterestSupported && [device isExposureModeSupported:exposureMode] ) {
                device.exposurePointOfInterest = point;
                device.exposureMode = exposureMode;
            }
            
            device.subjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange;
            [device unlockForConfiguration];
        }
        else {
        }
    } );
}

+ (void)setFlashMode:(AVCaptureFlashMode)flashMode forDevice:(AVCaptureDevice *)device
{
    if ( device.hasFlash && [device isFlashModeSupported:flashMode] ) {
        NSError *error = nil;
        if ( [device lockForConfiguration:&error] ) {
            device.flashMode = flashMode;
            [device unlockForConfiguration];
        }
        else {
        }
    }
}

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
    AVCaptureDevice *captureDevice = devices.firstObject;
    
    for ( AVCaptureDevice *device in devices ) {
        if ( device.position == position ) {
            captureDevice = device;
            break;
        }
    }
    return captureDevice;
}


-(UIImage*) drawImage:(UIImage*) fgImage
              inImage:(UIImage*) bgImage
              atPoint:(CGPoint)  point
{
    UIGraphicsBeginImageContextWithOptions(bgImage.size, NO, 0.0);
    [bgImage drawInRect:CGRectMake(0, 0, bgImage.size.width, bgImage.size.height)];
    [fgImage drawInRect:CGRectMake(bgImage.size.width - fgImage.size.width, bgImage.size.height - fgImage.size.height, fgImage.size.width, fgImage.size.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

#pragma mark save Image to DataBase

-(void) deleteIphoneCameraSnapShots{
    AppDelegate *appDel = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    NSManagedObjectContext *context = appDel.managedObjectContext;
    NSFetchRequest *request = [[NSFetchRequest alloc]initWithEntityName:@"SnapShots"];
    request.returnsObjectsAsFaults=false;
    NSArray *snapShotsArray = [[NSArray alloc]init];
    snapShotsArray = [context executeFetchRequest:request error:nil];
    NSFileManager *defaultManager = [[NSFileManager alloc]init];
    for(int i=0;i<[snapShotsArray count];i++){
        if(![defaultManager fileExistsAtPath:[snapShotsArray[i] valueForKey:@"path"]]){
            NSManagedObject * obj = snapShotsArray[i];
            [context deleteObject:obj];
        }
    }
    [context save:nil];
}

-(void)setUpInitialBlurView
{
    UIGraphicsBeginImageContext(CGSizeMake(self.view.bounds.size.width, (self.view.bounds.size.height+67.0)));
    [[UIImage imageNamed:@"live_stream_blur.png"] drawInRect:CGRectMake(self.view.bounds.origin.x, self.view.bounds.origin.y, self.view.bounds.size.width, (self.view.bounds.size.height+67.0))];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    self.view.backgroundColor = [UIColor colorWithPatternImage:image];
    self.activitView.hidden =false;
    [self.bottomView setUserInteractionEnabled:NO];
    _firstButton.userInteractionEnabled = false;
    _secondButton.userInteractionEnabled = false;
    _thirdButton.userInteractionEnabled = false;
    _iphoneCameraButton.userInteractionEnabled = false;
}

- (IBAction)didTapCamSelectionButton:(id)sender
{
    if ([self isStreamStarted])
    {
        [self generateStreamAlert:@"settingsPageView"];
    }
    else  if ( self.movieFileOutput.isRecording ) {
        [self generateVideoAlert:@"settingsPageView"];
    }
    else{
        [self settingsPageView];
    }
}

#pragma mark Load views

-(void) settingsPageView{
    
    if([self isStreamStarted]){
        [liveStreaming stopStreamingClicked];
        [_liveSteamSession endRtmpSession];
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"shutterActionMode"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"StartedStreaming"];
    }
    
    if(self.sessionQueue != nil){
        dispatch_async( self.sessionQueue, ^{
            if ( self.setupResult == AVCamSetupResultSuccess ) {
                [self.session stopRunning];
                [self removeObservers:@"remove" completion:^{
                    
                }];
            }
        });
    }
    else{
        if ( self.setupResult == AVCamSetupResultSuccess ) {
            [self.session stopRunning];
            [self removeObservers:@"remove" completion:^{
                
            }];
        }
    }
    
    if (self.videoDeviceInput.device.torchMode == AVCaptureTorchModeOff) {
    }else {
        [self.videoDeviceInput.device lockForConfiguration:nil];
        [self.videoDeviceInput.device setTorchMode:AVCaptureTorchModeOff];
        [self.videoDeviceInput.device unlockForConfiguration];
    }
    
    takePictureFlag = false;
    [self stopTimer];
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Settings" bundle:nil];
    SnapCamSelectViewController *snapCamSelectVC = (SnapCamSelectViewController*)[storyboard instantiateViewControllerWithIdentifier:@"SnapCamSelectViewController"];
    snapCamSelectVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    snapCamSelectVC.streamingDelegate = self;
    snapCamSelectVC.snapCamMode = [self getCameraSelectionMode];
    snapCamSelectVC.toggleSnapCamIPhoneMode = SnapCamSelectionModeIPhone;
    [self presentViewController:snapCamSelectVC animated:YES completion:nil];
}

- (IBAction)didTapSharingListIcon:(id)sender
{
    if ([self isStreamStarted])
    {
        [self generateStreamAlert:@"loadSharingView"];
    }
    else  if ( self.movieFileOutput.isRecording ) {
        [self generateVideoAlert:@"loadSharingView"];
    }
    else
    {
        [self loadSharingView];
    }
}

-(void) loadSharingView{
    
    UIStoryboard *sharingStoryboard = [UIStoryboard storyboardWithName:@"sharing" bundle:nil];
    UIViewController *mysharedChannelVC = [sharingStoryboard instantiateViewControllerWithIdentifier:@"MySharedChannelsViewController"];
    
    UINavigationController *navController = [[UINavigationController alloc]initWithRootViewController:mysharedChannelVC];
    navController.navigationBarHidden = true;
    
    navController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self.navigationController presentViewController:navController animated:true completion:^{
    }];
}

- (IBAction)didTapPhotoViewer:(id)sender {
    if ([self isStreamStarted])
    {
        [self generateStreamAlert:@"loadPhotoViewer"];
    }
    else  if ( self.movieFileOutput.isRecording ) {
        [self generateVideoAlert:@"loadPhotoViewer"];
    }
    else
    {
        [self loadPhotoViewer];
    }
}

-(void) loadPhotoViewer
{
    UIStoryboard *streamingStoryboard = [UIStoryboard storyboardWithName:@"PhotoViewer" bundle:nil];
    
    PhotoViewerViewController *photoViewerViewController =( PhotoViewerViewController*)[streamingStoryboard instantiateViewControllerWithIdentifier:@"PhotoViewerViewController"];
    UINavigationController *navController = [[UINavigationController alloc]initWithRootViewController:photoViewerViewController];
    navController.navigationBarHidden = true;
    navController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:navController animated:true completion:^{
        
    }];
}

- (IBAction)didTapStreamThumb:(id)sender {
    
    if ([self isStreamStarted])
    {
        [self generateStreamAlert:@"loadStreamsGalleryView"];
    }
    else  if ( self.movieFileOutput.isRecording ) {
        [self generateVideoAlert:@"loadStreamsGalleryView"];
    }
    else{
        [self loadStreamsGalleryView];
    }
}

-(void) loadStreamsGalleryView
{
    [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"SelectedTab"];
    UIStoryboard *streamingStoryboard = [UIStoryboard storyboardWithName:@"Streaming" bundle:nil];
    StreamsGalleryViewController *streamsGalleryViewController = [streamingStoryboard instantiateViewControllerWithIdentifier:@"StreamsGalleryViewController"];
    [self.navigationController pushViewController:streamsGalleryViewController animated:false];
    
}
-(void) deinit {
}

#pragma mark :- StreamingProtocol delegates
-(void)cameraSelectionMode:(SnapCamSelectionMode)selectionMode
{
    _snapCamMode = selectionMode;
}

-(SnapCamSelectionMode)getCameraSelectionMode
{
    return _snapCamMode;
}

#pragma mark :- Private Methods
-(void)stopLiveStreaming
{
    NSInteger shutterActionMode = [[NSUserDefaults standardUserDefaults] integerForKey:@"shutterActionMode"];
    if (shutterActionMode == SnapCamSelectionModeLiveStream)
    {
        switch(_liveSteamSession.rtmpSessionState) {
            case VCSessionStateNone:
            case VCSessionStatePreviewStarted:
            case VCSessionStateEnded:
            case VCSessionStateError:
                break;
            default:
                [UIApplication sharedApplication].idleTimerDisabled = NO;
                [_liveSteamSession endRtmpSession];
                break;
        }
    }
}

- (void)subjectAreaDidChange:(NSNotification *)notification
{
    CGPoint devicePoint = CGPointMake( 0.5, 0.5 );
    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
}

# pragma mark:- Thumbnail generator
- (UIImage *)thumbnaleImage:(UIImage *)image scaledToFillSize:(CGSize)size
{
    CGFloat scale = MAX(size.width/image.size.width, size.height/image.size.height);
    CGFloat width = image.size.width * scale;
    CGFloat height = image.size.height * scale;
    CGRect imageRect = CGRectMake((size.width - width)/2.0f,
                                  (size.height - height)/2.0f,
                                  width,
                                  height);
    
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    [image drawInRect:imageRect];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

- (NSData *)thumbnailFromVideoAtURL:(NSURL *)contentURL {
    UIImage *theImage = nil;
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:contentURL options:nil];
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;
    NSError *err = NULL;
    CMTime time = CMTimeMake(1, 60);
    CGImageRef imgRef = [generator copyCGImageAtTime:time actualTime:NULL error:&err];
    theImage = [[UIImage alloc] initWithCGImage:imgRef];
    CGImageRelease(imgRef);
    NSData *imageData = [[NSData alloc] init];
    imageData = UIImageJPEGRepresentation(theImage, 1.0);
    return imageData;
}

-(NSData *)getThumbNail:(NSURL*)stringPath
{
    AVURLAsset *asset1 = [[AVURLAsset alloc] initWithURL:stringPath options:nil];
    AVAssetImageGenerator *generate1 = [[AVAssetImageGenerator alloc] initWithAsset:asset1];
    generate1.appliesPreferredTrackTransform = YES;
    NSError *err = NULL;
    CMTime time = CMTimeMake(0.0,600);
    CGImageRef oneRef = [generate1 copyCGImageAtTime:time actualTime:NULL error:&err];
    UIImage *one = [[UIImage alloc] initWithCGImage:oneRef];
    UIImage *result  =  [self drawImage:[UIImage imageNamed:@"Circled Play"] inImage:one atPoint:CGPointMake(50, 50)];
    NSData *imageData = [[NSData alloc] init];
    imageData = UIImageJPEGRepresentation(result,1.0);
    return imageData;
}

-(void)generateVideoAlert:(NSString*)generateStream
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Video Recording In Progress" message:@"Do you want to stop video?" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"No", @"Alert No") style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:cancelAction];
    
    UIAlertAction *OkAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"Yes", @"Alert Yes") style:UIAlertActionStyleDefault handler:^( UIAlertAction *action ) {
        
        dispatch_async( dispatch_get_main_queue(), ^{
            if ([self.videoDeviceInput.device hasFlash]&&[self.videoDeviceInput.device hasTorch]) {
                if (self.videoDeviceInput.device.torchMode == AVCaptureTorchModeOff) {
                }else {
                    [self.videoDeviceInput.device lockForConfiguration:nil];
                    [self.videoDeviceInput.device setTorchMode:AVCaptureTorchModeOff];
                    [self.videoDeviceInput.device unlockForConfiguration];
                }
            }
            _cameraButton.hidden = false;
            if(flashFlag == 0){
                _flashButton.hidden = false;
            }
            else if(flashFlag == 1){
                _flashButton.hidden = true;
            }
            
            [_startCameraActionButton setImage:[UIImage imageNamed:@"Camera_Button_OFF"] forState:UIControlStateNormal];
        });
        [self.movieFileOutput stopRecording];
        
        [[NSUserDefaults standardUserDefaults] setInteger:2 forKey:@"shutterActionMode"];
        
        
        if ([generateStream isEqualToString:@"settingsPageView"])
        {
            [self settingsPageView];
        }
        else if ([generateStream isEqualToString:@"loadSharingView"])
        {
            [self loadSharingView];
        }
        else if ([generateStream isEqualToString:@"loadPhotoViewer"])
        {
            [self loadPhotoViewer];
        }
        else if ([generateStream isEqualToString:@"loadStreamsGalleryView"])
        {
            [self loadStreamsGalleryView];
        }
        
    }];
    [alertController addAction:OkAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

-(void)generateStreamAlert:(NSString*)generateStream
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Streaming In Progress" message:@"Do you want to stop streaming?" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"No", @"Alert No") style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:cancelAction];
    
    UIAlertAction *OkAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"Yes", @"Alert Yes") style:UIAlertActionStyleDefault handler:^( UIAlertAction *action ) {
        
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        [liveStreaming stopStreamingClicked];
        [_liveSteamSession endRtmpSession];
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"shutterActionMode"];
        [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"StartedStreaming"];
        
        if ([generateStream isEqualToString:@"settingsPageView"])
        {
            [self settingsPageView];
        }
        else if ([generateStream isEqualToString:@"loadSharingView"])
        {
            [self loadSharingView];
        }
        else if ([generateStream isEqualToString:@"loadPhotoViewer"])
        {
            [self loadPhotoViewer];
        }
        else if ([generateStream isEqualToString:@"loadStreamsGalleryView"])
        {
            [self loadStreamsGalleryView];
        }
        
    }];
    [alertController addAction:OkAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

@end
