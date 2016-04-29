//
//  MovieViewController.m
//  LiveStreamingKXMovie
//
//  Created by Vinitha on 11/20/15.
//  Copyright © 2015 Vinitha K S. All rights reserved.
//

#import "MovieViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import "KxMovieDecoder.h"
#import "KxAudioManager.h"
#import "KxMovieGLView.h"
#import "KxLogger.h"
#import "Connectivity.h"
#import "iONLive-Swift.h"
#import <CFNetwork/CFNetwork.h>
#import "IPhoneCameraViewController.h"
#import <SpriteKit/SpriteKit.h>


#define kScreenWidth [[UIScreen mainScreen] bounds].size.width
#define kScreenHeight [[UIScreen mainScreen] bounds].size.height


NSString * const KxMovieParameterMinBufferedDuration = @"KxMovieParameterMinBufferedDuration";
NSString * const KxMovieParameterMaxBufferedDuration = @"KxMovieParameterMaxBufferedDuration";
NSString * const KxMovieParameterDisableDeinterlacing = @"KxMovieParameterDisableDeinterlacing";

////////////////////////////////////////////////////////////////////////////////

static NSString * formatTimeInterval(CGFloat seconds, BOOL isLeft)
{
    seconds = MAX(0, seconds);
    
    NSInteger s = seconds;
    NSInteger m = s / 60;
    NSInteger h = m / 60;
    
    s = s % 60;
    m = m % 60;
    
    NSMutableString *format = [(isLeft && seconds >= 0.5 ? @"-" : @"") mutableCopy];
    if (h != 0) [format appendFormat:@"%d:%0.2d", h, m];
    else        [format appendFormat:@"%d", m];
    [format appendFormat:@":%0.2d", s];
    
    return format;
}

////////////////////////////////////////////////////////////////////////////////

enum {
    
    KxMovieInfoSectionGeneral,
    KxMovieInfoSectionVideo,
    KxMovieInfoSectionAudio,
    KxMovieInfoSectionSubtitles,
    KxMovieInfoSectionMetadata,
    KxMovieInfoSectionCount,
};

enum {
    
    KxMovieInfoGeneralFormat,
    KxMovieInfoGeneralBitrate,
    KxMovieInfoGeneralCount,
};

////////////////////////////////////////////////////////////////////////////////

static NSMutableDictionary * gHistory;

#define LOCAL_MIN_BUFFERED_DURATION   0.2
#define LOCAL_MAX_BUFFERED_DURATION   0.4
#define NETWORK_MIN_BUFFERED_DURATION 0.5
#define NETWORK_MAX_BUFFERED_DURATION 2.0

@interface MovieViewController () <StreamingProtocol>
{
    
    IBOutlet UIButton *cameraSelectionButton;
    IBOutlet UIButton *cameraButton;
    IBOutlet UIButton *closeButton;
    IBOutlet UIButton *thirdCircleButton;
    IBOutlet UIButton *secondCircleButton;
    IBOutlet UIButton *firstCircleButton;
    __weak IBOutlet UIButton *hidingHeartButton;
    
    
    IBOutlet UIButton *heart2Button;
    
    IBOutlet UIButton *heart4Button;
    IBOutlet UIButton *heart3Button;
    IBOutlet UIImageView *activityImageView;
    IBOutlet UIImageView *imageView;
    IBOutlet KxMovieGLView *glView;
    
    IBOutlet UIImageView *imageVideoView;
    IBOutlet UIView *topView;
    IBOutlet UIView *mainView;
    IBOutlet UIView *bottomView;
    IBOutlet UIView *liveView;
    __weak IBOutlet UIView *heartView;
    __weak IBOutlet UIView *heartBottomDescView;
    
    IBOutlet UIButton *heartTapButton;
    IBOutlet UIButton *cameaThumbNailImage;
    IBOutlet UILabel *noDataFound;
    IBOutlet UILabel *numberOfSharedChannels;
    IBOutlet UIActivityIndicatorView *_activityIndicatorView;
    
    IBOutlet UIProgressView *videoProgressBar;
    __weak IBOutlet NSLayoutConstraint *heartButtomBottomConstraint;
    int likeFlag;
    
    IBOutlet UIImageView *profilePicture;
    
    IBOutlet UILabel *typeMedia;
    IBOutlet UILabel *userName;
    
    IBOutlet UILabel *channelName;
    
    BOOL                _interrupted;
    NSURLSessionDownloadTask *downloadTask;
    //heart View
    
    KxMovieDecoder      *_decoder;
    dispatch_queue_t    _dispatchQueue;
    NSMutableArray      *_videoFrames;
    NSMutableArray      *_audioFrames;
    NSData              *_currentAudioFrame;
    
    NSUInteger          _currentAudioFramePos;
    NSTimeInterval      _tickCorrectionTime;
    NSTimeInterval      _tickCorrectionPosition;
    NSUInteger          _tickCounter;
    
    BOOL                _backGround;
    BOOL                _fitMode;
    BOOL                _infoMode;
    BOOL                _restoreIdleTimer;
    BOOL                _liveVideo;
    BOOL                _disableUpdateHUD;
    BOOL                _buffered;
    
    SnapCamSelectionMode _snapCamMode;
    
    CGFloat             _bufferedDuration;
    CGFloat             _minBufferedDuration;
    CGFloat             _maxBufferedDuration;
    CGFloat             _moviePosition;
    
    //    BOOL                _savedIdleTimer;
    NSString *          rtspFilePath;
    NSDictionary        *_parameters;
    UIAlertView *alertViewTemp;
    NSInputStream *inputStream;
    UITapGestureRecognizer *_tapGestureRecognizer;
    NSMutableDictionary *snapShotsDict;
    
    NSString *userId,*accessToken,*mediaDetailId,*notificationType;
    
    MPMoviePlayerController *moviePlayer;
    
}

@property (readwrite) BOOL playing;
@property (readwrite) BOOL decoding;
@property (readwrite, strong) KxArtworkFrame *artworkFrame;
@property (nonatomic) Connectivity *wifiReachability;
@property (nonatomic) Connectivity *internetReachability;

@end

@implementation MovieViewController

+ (void)initialize
{
    if (!gHistory)
        gHistory = [NSMutableDictionary dictionary];
}

- (BOOL)prefersStatusBarHidden { return NO; }

+ (id) movieViewControllerWithContentPath: (NSString *) path
                               parameters: (NSDictionary *) parameters
                                liveVideo:(BOOL)live
{
    //    id<KxAudioManager> audioManager = [KxAudioManager audioManager];
    //    [audioManager activateAudioSession];
    
    return [[MovieViewController alloc] initWithContentPath: path parameters: parameters liveVideo:live];
}


+ (id) movieViewControllerWithImageVideo: (NSString *) mediaUrl
                                channelName: (NSString *) channelname
                                userName: (NSString *) username
                                mediaType: (NSString *) mediaType
                                profileImage: (UIImage *) profileImage
                                VideoImageUrl: (UIImage *) VideoImageUrl
                                notifType: (NSString *) notifType
                                mediaId: (NSString *) mediaId
{
    
    return [[MovieViewController alloc]initWithImageVideo:mediaUrl channelName:channelname userName:username mediaType:mediaType profileImage:profileImage VideoImageUrl:VideoImageUrl notifType:notifType mediaId:mediaId];
}


- (id) initWithContentPath: (NSString *) path
                parameters: (NSDictionary *) parameters
                 liveVideo:(BOOL)live
{
    self = [super initWithNibName:@"MovieViewController" bundle:nil];
    
    if (self) {
        
        _liveVideo = live;
        rtspFilePath = path;
        _parameters = nil;
        [self setUpDefaultValues];
        NSLog(@"rtsp File Path = %@",path);
        //        [self setUpBlurView];
        //        if (_liveVideo) {
        //            [self checkWifiConnectionAndStartDecoder];
        //        }
        //        else
        //        {
        [self startDecoder];
        //        }
    }
    return self;
}

- (id) initWithImageVideo: (NSString *) mediaUrl
                channelName: (NSString *) channelname
                userName: (NSString *) username
                mediaType: (NSString *) mediaType
                profileImage: (UIImage *) profileImage
                VideoImageUrl: (UIImage *) VideoImageUrl
                notifType: (NSString *) notifType
                mediaId: (NSString *) mediaId
{
    self = [super initWithNibName:@"MovieViewController" bundle:nil];
    if (self) {
        [self setUpDefaultValues];
        [self setUpViewForImageVideo];
        if([mediaType  isEqual: @"video"])
        {
            imageVideoView.hidden = true;
            imageView.hidden = true;
            videoProgressBar.hidden = false;
            
            UIImageView *backgroundImage = [[UIImageView alloc] initWithFrame:glView.frame];
            backgroundImage.image = VideoImageUrl;
            topView.hidden = false;
            [glView addSubview:backgroundImage];
            [glView sendSubviewToBack:backgroundImage];
             NSURL *url = [self convertStringToUrl:mediaUrl];
            [self downloadVideo:url];
        }
        else{
             [self setUpImageVideo:mediaType mediaUrl:mediaUrl];
        }
        
      
        profilePicture.image = profileImage;
        channelName.text = channelname;
        if([mediaType  isEqual: @"live"]){
            typeMedia.text = mediaType;
        }
        else{
            typeMedia.text = @"";
        }
        userName.text = username;
        if([notifType isEqual: @"likes"])
        {
            likeFlag = 0;
        }
        else{
            likeFlag = 1;
        }
        
        NSUserDefaults *standardDefaults = [[NSUserDefaults alloc]init];
        userId = [standardDefaults valueForKey:@"userLoginIdKey"];
        accessToken = [standardDefaults valueForKey:@"userAccessTockenKey"];
        notificationType = @"LIKE";
        mediaDetailId = mediaId;
        
        if([userId isEqualToString:username]){
            heartTapButton.hidden = YES;
            typeMedia.text = @"";
            userName.text = @"";
        }

        
    }
    return self;
}

-(void) setUpImageVideo : (NSString*) mediaType mediaUrl:(NSString *) mediaUrl
{
    NSURL *url = [self convertStringToUrl:mediaUrl];
    NSLog(@"%@",url);
    UIImage *mediaImage;
    NSData *data = [[NSData alloc] initWithContentsOfURL:url];
    if(data != nil)
    {
        mediaImage = [[UIImage alloc]initWithData:data];
    }
    else{
        mediaImage = [UIImage imageNamed:@"photo3"];
    }
     imageVideoView.image = mediaImage;
}

-(void) downloadVideo: (NSURL *) url
{
    NSMutableURLRequest *downloadReq = [[NSMutableURLRequest alloc]initWithURL:url];
    NSURLSession *session = [NSURLSession sessionWithConfiguration: [NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    downloadTask = [session downloadTaskWithRequest:downloadReq];
    videoProgressBar.hidden = false;
    videoProgressBar.progressViewStyle = UIProgressViewStyleDefault;
    videoProgressBar.center = glView.center;
    videoProgressBar.transform = CGAffineTransformScale(videoProgressBar.transform, 1, 4);
    [downloadTask resume];
   
    
}

-(void) URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    float progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
    videoProgressBar.progress = progress;
    NSLog(@"%f", progress);
   
    if(progress == 1.0)
    {
        videoProgressBar.hidden = true;
    }
}

-(void) URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
 
    NSData *data = [[NSData alloc]initWithContentsOfURL:location];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *writePath = [[paths objectAtIndex:0] stringByAppendingString:@"/video.mov"];
    NSURL *fileURL = [NSURL fileURLWithPath:writePath];
    NSLog(@"%@",fileURL);
    if(data!= nil)
    {
        bool write = [data writeToURL:fileURL atomically:YES];
        if(write){
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(playerDidFinish:)
                                                name:MPMoviePlayerPlaybackDidFinishNotification object:moviePlayer];
            moviePlayer = [[MPMoviePlayerController alloc]initWithContentURL:fileURL];
            MPMoviePlayerController *player = moviePlayer;
            player.view.frame = CGRectMake(glView.frame.origin.x, glView.frame.origin.y, glView.frame.size.width, glView.frame.size.height - heartBottomDescView.frame.size.height);
            [player.view sizeToFit];
            player.scalingMode = MPMovieScalingModeFill;
            player.movieSourceType = MPMovieSourceTypeFile;
            player.controlStyle = MPMovieControlStyleNone;
            player.repeatMode = MPMovieRepeatModeNone;
            [glView addSubview:[player view]];
            [player play];
        }
        
    }
  
}

-(void) playerDidFinish :(NSNotification *) notif
{
    [moviePlayer.view removeFromSuperview];
    
}

-(void) setUpViewForImageVideo
{
    heart2Button.hidden = true;
    heart3Button.hidden = true;
    heart4Button.hidden = true;
    hidingHeartButton.hidden = true;
 //   videoProgressBar.hidden = true;
    likeFlag = false;
    heartBottomDescView.hidden = false;
    topView.hidden = false;
    noDataFound.hidden = true;
    _activityIndicatorView.hidden = true;
    cameraSelectionButton.hidden = true;
    liveView.hidden = true;
    numberOfSharedChannels.hidden = true;
    bottomView.hidden = true;
    activityImageView.hidden = true;
    closeButton.hidden = false;
    heartView.hidden = false;
    imageView.hidden = true;
    imageVideoView.hidden = false;
    topView.backgroundColor = [UIColor clearColor];
}

-(NSURL *) convertStringToUrl:(NSString *) url
{
    NSURL *searchURL = [NSURL URLWithString:url];
    return searchURL;
}


-(void)setUpDefaultValues
{
    videoProgressBar.hidden = true;
    imageVideoView.hidden = true;
    _snapCamMode = SnapCamSelectionModeSnapCam;
    _backGround =  false;
    [self.view.window setBackgroundColor:[UIColor grayColor]];
    [cameraButton setImage:[UIImage imageNamed:@"camera_Button_ON"] forState:UIControlStateHighlighted];
}

-(void)setUpInitialBlurView
{
    UIGraphicsBeginImageContext(CGSizeMake(self.view.bounds.size.width, (self.view.bounds.size.height+67.0)));
    NSLog(@"glView.bounds%f",self.view.bounds.size.height);
    [[UIImage imageNamed:@"live_stream_blur.png"] drawInRect:CGRectMake(self.view.bounds.origin.x, self.view.bounds.origin.y, self.view.bounds.size.width, (self.view.bounds.size.height+67.0))];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    glView.backgroundColor = [UIColor colorWithPatternImage:image];
}

#pragma mark : LoadView

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setUpView];
    [self setUpThumbailImage];
}

-(void)viewWillAppear:(BOOL)animated
{
    activityImageView.image =  [UIImage animatedImageNamed:@"loader-" duration:1.0f];
    [super viewWillAppear:animated];
    //    [self addApplicationObservers];
    [self.navigationController setNavigationBarHidden:true];
    [self changeCameraSelectionImage];
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    NSLog(@"applicationDidBecomeActive");
    
    //    _savedIdleTimer = [[UIApplication sharedApplication] isIdleTimerDisabled];
    //
    //
    //TODO make _interrupted No ,click on back button
    //    _interrupted = NO;
    //    if (_decoder) {
    //        [self reInitialiseDecoder];
    //    }
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    //    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self hideProgressBar];
    
    //    if (_decoder) {
    //
    //        [self close];
    //    }
    //
    //    //    [[UIApplication sharedApplication] setIdleTimerDisabled:_savedIdleTimer];
    //
    //    _buffered = NO;
    //    _interrupted = YES;
    
    LoggerStream(1, @"viewWillDisappear %@", self);
}

#pragma mark : Methods to check ping server to check Wifi Connected

-(void)timerToCheckWifiConnected
{
    NSLog(@"Status of outPutStream: %lu", (unsigned long)[inputStream streamStatus]);
    
    //    if ([inputStream streamStatus] == 2) {
    //        [self closeInputStream];
    [self hideStatusMessage];
    if (alertViewTemp.isVisible) {
        [alertViewTemp dismissWithClickedButtonIndex:0 animated:false];
    }
    [self restartDecoder];
    //    }
    //    else
    //    {
    //        [self closeInputStream];
    //        [self showMessageForNoStreamOrLiveDataFound];
    //        [self showInputNetworkErrorMessage:nil];
    //    }
}

//- (void)closeInputStream {
//    NSLog(@"Closing streams.");
//
//    [inputStream close];
//
//    [inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
//
//    inputStream = nil;
//}
//
//-(void)checkWifiConnectionAndStartDecoder
//{
//
//    NSURL *website = [self checkEmptyUrl];
//
//    if (!website) {
//        [self showMessageForNoStreamOrLiveDataFound];
//        [self showInputNetworkErrorMessage:nil];
//        return;
//    }
//
////    [self openInputStream:website port:554];
//    [self startTimer];
//}
//
//-(void)openInputStream:(NSURL *)website port :(int)port
//{
//    CFReadStreamRef readStream;
//    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)[website host], 554, &readStream, nil);
//
//    inputStream = (__bridge_transfer NSInputStream *)readStream;
//    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
//    [inputStream open];
//
//}
//
//-(void)startTimer
//{
//    [NSTimer scheduledTimerWithTimeInterval:1.0
//                                     target:self
//                                   selector:@selector(timerToCheckWifiConnected)
//                                   userInfo:nil
//                                    repeats:NO];
//}

-(NSURL*)checkEmptyUrl
{
    //  NSString *urlStr = @"rtsp://192.168.42.1/live";
    
    NSString *urlStr = @"rtsp://192.168.2.30";
    if (![urlStr isEqualToString:@""]) {
        NSURL *website = [NSURL URLWithString:urlStr];
        if (!website) {
            [self showInputNetworkErrorMessage:nil];
        }
        return website;
    }
    return nil;
}

#pragma mark : Restart viewfinder

-(void)restartDecoder
{
    noDataFound.hidden = true;
    if (alertViewTemp.isVisible) {
        [alertViewTemp dismissWithClickedButtonIndex:0 animated:false];
    }
    NSLog(@"rtsp File Path = %@",rtspFilePath);
    _interrupted = false;
    self.playing = NO;
    [self showProgressBar];
    //    id<KxAudioManager> audioManager = [KxAudioManager audioManager];
    //    [audioManager activateAudioSession];
    [self startDecoder];
}

-(void)reInitialiseDecoder
{
    [self showProgressBar];
    
    dispatch_after (dispatch_time (DISPATCH_TIME_NOW, (int64_t) (3 * NSEC_PER_SEC)), dispatch_get_main_queue (), ^ {
        
        //        if (_liveVideo) {
        //            [self checkWifiConnectionAndStartDecoder];
        //        }
        //        else
        //        {
        [self restartDecoder];
        //        }
    });
}

#pragma mark : AnimatedActivityImageView

-(void)showProgressBar
{
    activityImageView.image =  [UIImage animatedImageNamed:@"loader-" duration:1.0f];
    activityImageView.hidden = false;
    [_activityIndicatorView startAnimating];
    _activityIndicatorView.hidden = false;
}

-(void)hideProgressBar
{
    activityImageView.hidden = true;
    [_activityIndicatorView stopAnimating];
    _activityIndicatorView.hidden = true;
}

#pragma mark : Customize View

-(void)setUpThumbailImage
{
    IPhoneCameraViewController *iphoneCameraViewController = [[IPhoneCameraViewController alloc]init];
    [iphoneCameraViewController deleteIphoneCameraSnapShots];
    snapShotsDict = iphoneCameraViewController.displayIphoneCameraSnapShots;
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    if([snapShotsDict count] > 0){
        NSLog(@"SnapshotDict=%@",snapShotsDict);
        NSMutableArray *dateArray=[[NSMutableArray alloc]init];
        NSArray *snapShotKeys=[[NSArray alloc]init];
        snapShotKeys = [snapShotsDict allKeys];
        for(int i=0; i<[snapShotKeys count]; i++){
            [dateFormat setDateFormat:@"dd_MM_yyyy_HH_mm_ss"];
            NSDate *date = [dateFormat dateFromString:snapShotKeys[i]];
            dateArray[i]=date;
        }
        NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:nil ascending:NO];
        NSArray *dateArray1 = [dateArray sortedArrayUsingDescriptors:@[sd]];
        UIImage * thumbaNailImage = [iphoneCameraViewController thumbnaleImage:[UIImage imageWithData:[NSData dataWithContentsOfFile:[snapShotsDict valueForKey:[NSString stringWithFormat:@"%@",[dateFormat stringFromDate:dateArray1[0]]]]]] scaledToFillSize:CGSizeMake(45, 45)];
        
        [cameaThumbNailImage setImage:thumbaNailImage forState:UIControlStateNormal];
    }
    else{
        [cameaThumbNailImage setImage:[UIImage imageNamed:@"photo1"] forState:UIControlStateNormal];
    }
}

-(void)setUpView
{
    [self setUpInitialBlurView];
    [self setUpInitialGLView];
    
    //    if (_decoder) {
    //
    //        [self setupPresentView];
    //    }
    //    _savedIdleTimer = [[UIApplication sharedApplication] isIdleTimerDisabled];
    [self addApplicationObservers];
    
    [self setUpPresentViewAndRestorePlay];
    //    [self addApplicationObservers];
    //    _interrupted = NO;
    //    if (_decoder) {
    //
    //        [self setupPresentView];
    //        [self restorePlay];
    //
    //    } else {
    //
    //        [_activityIndicatorView startAnimating];
    //    }
    [self addTapGestures];
}

-(void)setUpPresentViewAndRestorePlay
{
    _interrupted = NO;
    if (_decoder) {
        
        [self setupPresentView];
        [self restorePlay];
        
    } else {
        [self showProgressBar];
        //        activityImageView.image =  [UIImage animatedImageNamed:@"loader-" duration:1.0f];
        //        [_activityIndicatorView startAnimating];
    }
}

-(void)addApplicationObservers
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self checkWifiReachability];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:[UIApplication sharedApplication]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:[UIApplication sharedApplication]];
}

-(void)checkWifiReachability
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    self.wifiReachability = [Connectivity reachabilityForLocalWiFi];
    [self.wifiReachability startNotifier];
    self.internetReachability = [Connectivity reachabilityForInternetConnection];
    [self.internetReachability startNotifier];
}

-(void)reachabilityChanged:(NSNotification *)note
{
    Connectivity * curReach = [note object];
    NSLog(@"Reahcbility changes");
    if (curReach == self.wifiReachability && curReach.currentReachabilityStatus == ReachableViaWiFi)
    {
        if (_liveVideo) {
            [self restartDecoder];
        }
        NSLog(@"Wifi Connected");
    }
}


-(void)setUpInitialGLView
{
    [topView setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:0.4]];
    heartView.hidden = true;
    [self updateGlViewDefaultValues];
    
}
-(void)setUpGlViewForLive
{
    closeButton.hidden = true;
    bottomView.hidden = false;
    noDataFound.text = @"Trying to connect camera";
    noDataFound.hidden = false;
    liveView.hidden = false;
    numberOfSharedChannels.hidden = false;
    cameraSelectionButton.hidden = false;
}

-(void)setUpGlViewForPlayBack
{
    closeButton.hidden = false;
    bottomView.hidden = true;
    noDataFound.text = @"Retrieving stream";
    noDataFound.hidden = false;
    liveView.hidden = true;
    numberOfSharedChannels.hidden = true;
    cameraSelectionButton.hidden = true;
}

-(void)updateGlViewDefaultValues
{
    if (_liveVideo == true)
    {
        [self setUpGlViewForLive];
    }
    else
    {
        [self setUpGlViewForPlayBack];
    }
}

-(void)setUpViewForLiveAndStreaming
{
    noDataFound.hidden = true;
    [glView setBackgroundColor:[UIColor whiteColor]];
    if (_liveVideo == true) {
        [self customiseViewForLive];
    }
    else
    {
        [self customiseViewForStreaming];
    }
}

-(void)customiseViewForLive
{
    imageVideoView.hidden = true;
    heartView.hidden = true;
    bottomView.hidden = false;
    topView.hidden = false;
    liveView.hidden = false;
    numberOfSharedChannels.hidden = false;
    closeButton.hidden = true;
    heartBottomDescView.hidden = true;
}

-(void)customiseViewForStreaming
{
    imageVideoView.hidden = true;
    heartView.hidden = false;
    heartBottomDescView.hidden = false;
    numberOfSharedChannels.hidden = true;
    bottomView.hidden = true;
    topView.hidden = false;
    liveView.hidden = true;
    closeButton.hidden = false;
}

-(void)changeLiveNowSelectionImage
{
    BOOL streamStarted = [self isStreamStarted];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (streamStarted == false) {
            
            [cameraSelectionButton setImage:[UIImage imageNamed:@"Live_now_off_mode"] forState:UIControlStateNormal];
        }
        else{
            
            [cameraSelectionButton setImage:[UIImage imageNamed:@"Live_now_mode"] forState:UIControlStateNormal];
        }
    });
    
}
#pragma mark : Deallocation

- (void) dealloc
{
    [self pause];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_dispatchQueue) {
        _dispatchQueue = NULL;
    }
    
    LoggerStream(1, @"%@ dealloc", self);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    if (self.playing) {
        
        [self pause];
        [self freeBufferedFrames];
        
        if (_maxBufferedDuration > 0) {
            
            _minBufferedDuration = _maxBufferedDuration = 0;
            [self play];
            
            LoggerStream(0, @"didReceiveMemoryWarning, disable buffering and continue playing");
            
        } else {
            
            // force ffmpeg to free allocated memory
            [_decoder closeFile];
            [_decoder openFile:nil error:nil];
            
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure", nil)
                                        message:NSLocalizedString(@"Out of memory", nil)
                                       delegate:nil
                              cancelButtonTitle:NSLocalizedString(@"Close", nil)
                              otherButtonTitles:nil] show];
        }
        
    } else {
        
        [self freeBufferedFrames];
        [_decoder closeFile];
        [_decoder openFile:nil error:nil];
    }
}

#pragma mark : Listen Notifications

-(void)applicationDidBecomeActive: (NSNotification *)notification
{
    if (_backGround) {
        _backGround = false;
        NSLog(@"applicationDidBecomeActive");
        [self reInitialiseDecoder];
    }
}

-(void)applicationDidEnterBackground: (NSNotification *)notification
{
    _backGround =  true;
    [self close];
}

-(void)close
{
    _interrupted = true;
    self.playing = NO;
    [self freeBufferedFrames];
    dispatch_after (dispatch_time (DISPATCH_TIME_NOW, (int64_t) (0.1 * NSEC_PER_SEC)), dispatch_get_main_queue (), ^ {
        [NSThread sleepForTimeInterval:1.0];
        [_decoder closeFile];
    });
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - gesture recognizer

-(void) addTapGestures
{
    if (_liveVideo) {
        _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTapToPlayViewfinder:)];
        _tapGestureRecognizer.numberOfTapsRequired = 1;
        
        [self.view addGestureRecognizer:_tapGestureRecognizer];
    }
}

- (void) handleSingleTapToPlayViewfinder: (UITapGestureRecognizer *) sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        
        if (sender == _tapGestureRecognizer && ([_activityIndicatorView isAnimating] == false)) {
            
            if (self.playing == false && _liveVideo) {
                noDataFound.hidden = true;
                NSLog(@"reInitialising didTap");
                [self reInitialiseDecoder];
            }
        }
    }
}

#pragma mark - private
#pragma mark : startDecoder

-(void)startDecoder
{
    __weak MovieViewController *weakSelf = self;
    
    KxMovieDecoder *decoder = [[KxMovieDecoder alloc] init];
    
    decoder.interruptCallback = ^BOOL(){
        
        __strong MovieViewController *strongSelf = weakSelf;
        return strongSelf ? [strongSelf interruptDecoder] : YES;
    };
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        NSError *error = nil;
        [decoder openFile:rtspFilePath error:&error];
        if (error) {
            NSLog(@"error can't open file");
        }
        
        __strong MovieViewController *strongSelf = weakSelf;
        if (strongSelf) {
            
            dispatch_sync(dispatch_get_main_queue(), ^{
                
                [strongSelf setMovieDecoder:decoder withError:error];
            });
        }
    });
}

- (void) setMovieDecoder: (KxMovieDecoder *) decoder
               withError: (NSError *) error
{
    LoggerStream(2, @"setMovieDecoder");
    
    if (!error && decoder) {
        
        _decoder        = decoder;
        _dispatchQueue  = dispatch_queue_create("KxMovie", DISPATCH_QUEUE_SERIAL);
        _videoFrames    = [NSMutableArray array];
        _audioFrames    = [NSMutableArray array];
        
        if (_decoder.isNetwork) {
            
            _minBufferedDuration = NETWORK_MIN_BUFFERED_DURATION;
            _maxBufferedDuration = NETWORK_MAX_BUFFERED_DURATION;
            
        } else {
            
            _minBufferedDuration = LOCAL_MIN_BUFFERED_DURATION;
            _maxBufferedDuration = LOCAL_MAX_BUFFERED_DURATION;
        }
        
        if (!_decoder.validVideo)
            _minBufferedDuration *= 1.0; // increase for audio
        
        // allow to tweak some parameters at runtime
        if (_parameters.count) {
            
            id val;
            
            val = [_parameters valueForKey: KxMovieParameterMinBufferedDuration];
            if ([val isKindOfClass:[NSNumber class]])
                _minBufferedDuration = [val floatValue];
            
            val = [_parameters valueForKey: KxMovieParameterMaxBufferedDuration];
            if ([val isKindOfClass:[NSNumber class]])
                _maxBufferedDuration = [val floatValue];
            
            val = [_parameters valueForKey: KxMovieParameterDisableDeinterlacing];
            if ([val isKindOfClass:[NSNumber class]])
                _decoder.disableDeinterlacing = [val boolValue];
            
            if (_maxBufferedDuration < _minBufferedDuration)
                _maxBufferedDuration = _minBufferedDuration * 2;
        }
        
        LoggerStream(2, @"buffered limit: %.1f - %.1f", _minBufferedDuration, _maxBufferedDuration);
        
        if (self.isViewLoaded) {
            
            [self setupPresentView];
            
            if (_activityIndicatorView.isAnimating) {
                [self hideProgressBar];
                
                NSLog(@"setMovieDecoder: (KxMovieDecoder *) decoder");
                [self restorePlay];
            }
        }
        
    } else if (error && self.isViewLoaded && self.view.window) {
        
        [self handleDecoderError:error];
    }
    else
    {
        if (self.isViewLoaded && self.view.window) {
            
            [self hideProgressBar];
            //            [self showErrorMessage:error];
        }
    }
}

-(void)handleDecoderError:(NSError *)error
{
    NSLog(@"Handle Decoder failed");
    [self hideProgressBar];
    [self updateViewFinderMessageForNoConnectionFound];
    
    if ( _liveVideo == false) {
        [self handlePlayBackDecoderError:error];
    }
    else
    {
        [self showInputNetworkErrorMessage:error];
    }
}

#pragma mark : Error Handling

-(void)showErrorMessage:(NSError*) error
{
    if (!_interrupted )
    {
        [self showMessageForNoStreamOrLiveDataFound];
        if (_liveVideo) {
            [self showInputNetworkErrorMessage:error];
        }
        else
        {
            [self handlePlayBackDecoderError: error];
        }
    }
}

-(void)updateViewFinderMessageForNoConnectionFound
{
    [self showNoDataFoundText];
    if(_liveVideo == true)
    {
        noDataFound.text = @"Could not connect, Tap To refresh connecton...";
    }
    else{
        noDataFound.text = @"Unable to fetch stream!";
    }
}

-(void)showNoDataFoundText
{
    noDataFound.hidden = false;
    _activityIndicatorView.hidden = true;
}

-(void)showMessageForNoStreamOrLiveDataFound
{
    [self showNoDataFoundText];
    if(_liveVideo == true)
    {
        noDataFound.text = @"Could not connect to camera,Tap To refresh connecton...";
    }
    else{
        noDataFound.text = @"Unable to fetch stream!";
    }
}

-(void)showInputNetworkErrorMessage:(NSError *)error
{
    if (alertViewTemp.isVisible == false && _liveVideo) {
        
        [self hideProgressBar];
        self.playing = false;
        NSString * message = [self getInterruptionErrorMessage:error];
        NSString * title = [self getErrorTitle:error];
        [self showViewFinderErrorWithTitle:title AndMessage:message];
    }
}

-(void)showViewFinderErrorWithTitle:(NSString*) title AndMessage:(NSString*)message
{
    alertViewTemp = [[UIAlertView alloc] initWithTitle:NSLocalizedString(title, nil)
                                               message:message
                                              delegate:self
                                     cancelButtonTitle:NSLocalizedString(@"Close", nil)
                                     otherButtonTitles:@"Settings", nil];
    alertViewTemp.tag = 102;
    [alertViewTemp show];
    
}

-(NSString*)getInterruptionErrorMessage:(NSError *)error
{
    if (error == nil) {
        
        return @"Please check your wifi connection";
    }
    else
    {
        return @"Unable to communicate with camera! Please try again...";
    }
}

-(NSString *)getErrorTitle:(NSError*)error
{
    if (error == nil) {
        return @"Couldn't Connect Camera";
    }
    else
    {
        return @"Communication Error!";
    }
}

- (void) handlePlayBackDecoderError: (NSError *) error
{
    NSString * errorVal = [self getErrorMessage:error];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure", nil)
                                                        message:errorVal
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Close", nil)
                                              otherButtonTitles:nil];
    alertView.tag = 101;
    [alertView show];
}

-(NSString*)getErrorMessage:(NSError *) error
{
    if (error) {
        return @"Live stream Interrupted";
    }
    else
    {
        return  @"Unable to fetch stream";
    }
    
    return @"NetworkError";
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (alertView.tag) {
            
        case 101:
            if (buttonIndex == 0)
            {
                [self showMessageForNoStreamOrLiveDataFound];
                [self dismissViewControllerAnimated:true
                                         completion:^{
                                             
                                         }];
            }
            break;
            
        case 102:
            if (buttonIndex == 1)
            {
                if(&UIApplicationOpenSettingsURLString != nil)
                {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                }
            }
            else if (buttonIndex == 0)
            {
                return;
            }
            break;
        default:
            break;
    }
}

#pragma mark : Play
- (void) restorePlay
{
    NSLog(@"restorePlay");
    [self play];
}

-(void) play
{
    if (self.playing)
        return;
    
    if (!_decoder.validVideo &&
        !_decoder.validAudio) {
        
        return;
    }
    
    if (_interrupted)
        return;
    
    self.playing = YES;
    _interrupted = NO;
    _disableUpdateHUD = NO;
    _tickCorrectionTime = 0;
    _tickCounter = 0;
    
    
    NSLog(@"asyncDecodeFrames");
    [self asyncDecodeFrames];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self tick];
    });
    
    if (_decoder.validAudio)
        [self enableAudio:YES];
    
    LoggerStream(1, @"play movie");
}

- (void) pause
{
    if (!self.playing)
        return;
    
    self.playing = NO;
    //_interrupted = YES;
    [self enableAudio:NO];
    LoggerStream(1, @"pause movie");
}

- (void) setupPresentView
{
    BOOL isGlView = false;
    
    if (_decoder.validVideo) {
        
        [self setUpViewForLiveAndStreaming];
        isGlView = [glView initWithDecoder:_decoder];
        
        if (isGlView == false)
            glView = nil;
    }
    
    if (isGlView == false) {
        
        LoggerVideo(0, @"fallback to use RGB video frame and UIKit");
        [_decoder setupVideoFrameFormat:KxVideoFrameFormatRGB];
    }
    
    UIView *frameView = [self frameView];
    
    frameView.contentMode = UIViewContentModeScaleAspectFill;
    frameView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    
    [self.view bringSubviewToFront:frameView];
}

- (UIView *) frameView
{
    return glView ? glView : imageView;
}

- (void) audioCallbackFillData: (float *) outData
                     numFrames: (UInt32) numFrames
                   numChannels: (UInt32) numChannels
{
    //fillSignalF(outData,numFrames,numChannels);
    //return;
    
    if (_buffered) {
        memset(outData, 0, numFrames * numChannels * sizeof(float));
        return;
    }
    
    @autoreleasepool {
        
        while (numFrames > 0) {
            
            if (!_currentAudioFrame) {
                
                @synchronized(_audioFrames) {
                    
                    NSUInteger count = _audioFrames.count;
                    
                    if (count > 0) {
                        
                        KxAudioFrame *frame = _audioFrames[0];
                        
#ifdef DUMP_AUDIO_DATA
                        LoggerAudio(2, @"Audio frame position: %f", frame.position);
#endif
                        if (_decoder.validVideo) {
                            
                            const CGFloat delta = _moviePosition - frame.position;
                            
                            if (delta < -0.1) {
                                
                                memset(outData, 0, numFrames * numChannels * sizeof(float));
                                //#ifdef DEBUG
                                //                                LoggerStream(0, @"desync audio (outrun) wait %.4f %.4f", _moviePosition, frame.position);
                                //                                _debugAudioStatus = 1;
                                //                                _debugAudioStatusTS = [NSDate date];
                                //#endif
                                break; // silence and exit
                            }
                            
                            [_audioFrames removeObjectAtIndex:0];
                            
                            if (delta > 0.1 && count > 1) {
                                
                                //#ifdef DEBUG
                                //                                LoggerStream(0, @"desync audio (lags) skip %.4f %.4f", _moviePosition, frame.position);
                                //                                _debugAudioStatus = 2;
                                //                                _debugAudioStatusTS = [NSDate date];
                                //#endif
                                continue;
                            }
                            
                        } else {
                            
                            [_audioFrames removeObjectAtIndex:0];
                            _moviePosition = frame.position;
                            _bufferedDuration -= frame.duration;
                        }
                        
                        _currentAudioFramePos = 0;
                        _currentAudioFrame = frame.samples;
                    }
                }
            }
            
            if (_currentAudioFrame) {
                
                const void *bytes = (Byte *)_currentAudioFrame.bytes + _currentAudioFramePos;
                const NSUInteger bytesLeft = (_currentAudioFrame.length - _currentAudioFramePos);
                const NSUInteger frameSizeOf = numChannels * sizeof(float);
                const NSUInteger bytesToCopy = MIN(numFrames * frameSizeOf, bytesLeft);
                const NSUInteger framesToCopy = bytesToCopy / frameSizeOf;
                
                memcpy(outData, bytes, bytesToCopy);
                numFrames -= framesToCopy;
                outData += framesToCopy * numChannels;
                
                if (bytesToCopy < bytesLeft)
                    _currentAudioFramePos += bytesToCopy;
                else
                    _currentAudioFrame = nil;
                
            } else {
                
                memset(outData, 0, numFrames * numChannels * sizeof(float));
                //LoggerStream(1, @"silence audio");
                //#ifdef DEBUG
                //                _debugAudioStatus = 3;
                //                _debugAudioStatusTS = [NSDate date];
                //#endif
                break;
            }
        }
    }
}

- (void) enableAudio: (BOOL) on
{
    id<KxAudioManager> audioManager = [KxAudioManager audioManager];
    
    if (on && _decoder.validAudio) {
        
        audioManager.outputBlock = ^(float *outData, UInt32 numFrames, UInt32 numChannels) {
            
            [self audioCallbackFillData: outData numFrames:numFrames numChannels:numChannels];
        };
        
        [audioManager play];
        
        LoggerAudio(2, @"audio device smr: %d fmt: %d chn: %d",
                    (int)audioManager.samplingRate,
                    (int)audioManager.numBytesPerSample,
                    (int)audioManager.numOutputChannels);
        
    } else {
        
        [audioManager pause];
        audioManager.outputBlock = nil;
    }
}

- (BOOL) addFrames: (NSArray *)frames
{
    if (_decoder.validVideo) {
        
        @synchronized(_videoFrames) {
            
            for (KxMovieFrame *frame in frames)
                if (frame.type == KxMovieFrameTypeVideo) {
                    [_videoFrames addObject:frame];
                    _bufferedDuration += frame.duration;
                }
        }
    }
    
    if (_decoder.validAudio) {
        
        @synchronized(_audioFrames) {
            
            for (KxMovieFrame *frame in frames)
                if (frame.type == KxMovieFrameTypeAudio) {
                    [_audioFrames addObject:frame];
                    if (!_decoder.validVideo)
                        _bufferedDuration += frame.duration;
                }
        }
        
        if (!_decoder.validVideo) {
            
            for (KxMovieFrame *frame in frames)
                if (frame.type == KxMovieFrameTypeArtwork)
                    self.artworkFrame = (KxArtworkFrame *)frame;
        }
    }
    
    return self.playing && _bufferedDuration < _maxBufferedDuration;
}

- (BOOL) decodeFrames
{
    //NSAssert(dispatch_get_current_queue() == _dispatchQueue, @"bugcheck");
    
    NSArray *frames = nil;
    
    if (_decoder.validVideo ||
        _decoder.validAudio) {
        
        frames = [_decoder decodeFrames:0];
    }
    
    if (frames.count) {
        return [self addFrames: frames];
    }
    return NO;
}

- (void) asyncDecodeFrames
{
    if (self.decoding)
        return;
    
    __weak MovieViewController *weakSelf = self;
    __weak KxMovieDecoder *weakDecoder = _decoder;
    
    const CGFloat duration = _decoder.isNetwork ? .0f : 0.1f;
    
    self.decoding = YES;
    dispatch_async(_dispatchQueue, ^{
        
        {
            //            NSLog(@"_dispatchQueue");
            __strong MovieViewController *strongSelf = weakSelf;
            if (!strongSelf.playing)
            {
                //                NSLog(@"strongSelf.playing:");
                return;
            }
        }
        
        BOOL good = YES;
        while (good) {
            
            good = NO;
            //            NSLog(@"good");
            
            @autoreleasepool {
                
                __strong KxMovieDecoder *decoder = weakDecoder;
                
                if (decoder && (decoder.validVideo || decoder.validAudio)) {
                    
                    //            NSLog(@"[decoder decodeFrames:duration];");
                    //                    NSLog(@"decoder.validVideo");
                    
                    NSArray *frames = [decoder decodeFrames:duration];
                    //                    NSLog(@"frames.count %lu", (unsigned long)frames.count);
                    
                    if (frames.count) {
                        
                        __strong MovieViewController *strongSelf = weakSelf;
                        if (strongSelf)
                        {
                            good = [strongSelf addFrames:frames];
                            //                            NSLog(@"No frames to add");
                        }
                    }
                    else{
                        //show disconnected pop up here.
                        //                        NSLog(@"No frames found! %lu", (unsigned long)frames.count);
                    }
                }
            }
        }
        {
            //            NSLog(@"strongSelf.decoding = NO");
            __strong MovieViewController *strongSelf = weakSelf;
            if (strongSelf) strongSelf.decoding = NO;
        }
    });
    //    NSLog(@"Exit async decode frames");
}

- (void) tick
{
    if (_buffered && ((_bufferedDuration > _minBufferedDuration) || _decoder.isEOF)) {
        
        _tickCorrectionTime = 0;
        _buffered = NO;
        //        [_activityIndicatorView stopAnimating];
        //        _activityIndicatorView.hidden = true;
    }
    
    CGFloat interval = 0;
    if (!_buffered)
        interval = [self presentFrame];
    
    if (self.playing) {
        
        const NSUInteger leftFrames =
        (_decoder.validVideo ? _videoFrames.count : 0) +
        (_decoder.validAudio ? _audioFrames.count : 0);
        
        if (0 == leftFrames) {
            
            if (_decoder.isEOF) {
                
                NSLog(@"returning!!");
                NSError * error = [NSError errorWithDomain:@"No frames found!,Please try again" code:-57 userInfo:nil];
                [self showErrorMessage:error];
                return;
                
            }
            //            NSLog(@"0 == leftFrames0");
            if (_minBufferedDuration > 0 && !_buffered) {
                
                _buffered = YES;
                //                activityImageView.image =  [UIImage animatedImageNamed:@"loader-" duration:1.0f];
                [_activityIndicatorView startAnimating];
                //                NSLog(@"_minBufferedDuration > 0 && !_buffered");
                
            }
        }
        
        if (!leftFrames ||
            !(_bufferedDuration > _minBufferedDuration)) {
            
            [self asyncDecodeFrames];
        }
        
        const NSTimeInterval correction = [self tickCorrection];
        const NSTimeInterval time = MAX(interval + correction, 0.01);
        //        NSLog(@"time%f",time);
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self tick];
        });
    }
    
    if ((_tickCounter++ % 3) == 0) {
        //        [self updateHUD];
    }
}


- (CGFloat) tickCorrection
{
    if (_buffered)
        return 0;
    
    const NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    if (!_tickCorrectionTime) {
        
        _tickCorrectionTime = now;
        _tickCorrectionPosition = _moviePosition;
        return 0;
    }
    
    NSTimeInterval dPosition = _moviePosition - _tickCorrectionPosition;
    NSTimeInterval dTime = now - _tickCorrectionTime;
    NSTimeInterval correction = dPosition - dTime;
    
    if (correction > 1.f || correction < -1.f) {
        
        LoggerStream(1, @"tick correction reset %.2f", correction);
        correction = 0;
        _tickCorrectionTime = 0;
    }
    
    return correction;
}

- (CGFloat) presentFrame
{
    CGFloat interval = 0;
    
    if (_decoder.validVideo) {
        
        KxVideoFrame *frame;
        
        @synchronized(_videoFrames) {
            
            if (_videoFrames.count > 0) {
                
                frame = _videoFrames[0];
                [_videoFrames removeObjectAtIndex:0];
                _bufferedDuration -= frame.duration;
            }
        }
        
        if (frame)
            interval = [self presentVideoFrame:frame];
        
    } else if (_decoder.validAudio) {
        
        //interval = _bufferedDuration * 0.5;
        
        if (self.artworkFrame) {
            
            imageView.image = [self.artworkFrame asImage];
            self.artworkFrame = nil;
        }
    }
    
    return interval;
}

- (CGFloat) presentVideoFrame: (KxVideoFrame *) frame
{
    if (glView) {
        
        [glView render:frame];
        
    } else {
        
        KxVideoFrameRGB *rgbFrame = (KxVideoFrameRGB *)frame;
        imageView.image = [rgbFrame asImage];
    }
    
    _moviePosition = frame.position;
    
    return frame.duration;
}

#pragma mark : Button Actions

- (IBAction)didTapCloseButton:(id)sender {
    NSLog(@"%ld",(long)downloadTask.state);
    if(downloadTask.state == 0)
    {
        [downloadTask cancel];
    }
    
        [self dismissViewControllerAnimated:true
                             completion:^{
                                 
                             }];
}

- (IBAction)didTapLiveButton:(id)sender {
    
    if ([self isViewFinderLoading]) {
        return;
    }
    [self doLiveButtonActions];
}

-(void)doLiveButtonActions
{
    if (_snapCamMode == SnapCamSelectionModeLiveStream )
    {
        [self doActionsForLiveStreamingMode];
    }
    else
    {
        NSLog(@"Live Stream mode not selected");
    }
}

- (IBAction)didTapStreamThumb:(id)sender {
    
    if ([self isViewFinderLoading]) {
        return;
    }
    
    [self loadStreamsGalleryView];
}

- (IBAction)didTapcCamSelectionButton:(id)sender
{
    if ([self isViewFinderLoading]) {
        return;
    }
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Settings" bundle:nil];
    SnapCamSelectViewController *snapCamSelectVC = (SnapCamSelectViewController*)[storyboard instantiateViewControllerWithIdentifier:@"SnapCamSelectViewController"];
    snapCamSelectVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    snapCamSelectVC.streamingDelegate = self;
    snapCamSelectVC.snapCamMode = [self getCameraSelectionMode];
    snapCamSelectVC.toggleSnapCamIPhoneMode = SnapCamSelectionModeSnapCam;
    
    UINavigationController *nav = [[UINavigationController alloc]initWithRootViewController:snapCamSelectVC];
    nav.navigationBarHidden = true;
    [self presentViewController:nav animated:YES completion:nil];
    //[self presentViewController:snapCamSelectVC animated:YES completion:nil];
    
}
- (IBAction)didTapPhotoViewer:(id)sender {
    
    if ([self isViewFinderLoading]) {
        return;
    }
    
    [self loadPhotoViewer];
}


- (void)addHeart {
    
    CALayer *heartLayer=[[CALayer alloc]init];
    [heartLayer setFrame:CGRectMake(kScreenWidth - 20, kScreenHeight - 100, 28, 26)];
    heartLayer.contents=(__bridge id _Nullable)([[UIImage imageNamed:@"hearth"] CGImage]);
    [self.view.layer addSublayer:heartLayer];
    __weak CALayer *weakHeartLayer=heartLayer;
    [CATransaction begin];
    [CATransaction setCompletionBlock:^(){
        [weakHeartLayer removeFromSuperlayer];
    }];
    
    CAAnimationGroup *animation = [self createAnimation:heartLayer.frame];
    animation.duration = 2 + (arc4random() % 6 - 2);
    animation.fillMode = kCAFillModeForwards;
    animation.removedOnCompletion = NO;
    [heartLayer addAnimation:animation forKey:nil];
    [CATransaction commit];
}

- (CAAnimationGroup *)createAnimation:(CGRect)frame {
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    CGMutablePathRef path = CGPathCreateMutable();
    
    int height = -100 + arc4random() % 40 - 20;
    int xOffset = frame.origin.x;
    int yOffset = frame.origin.y;
    int waveWidth = 50;
    CGPoint p1 = CGPointMake(xOffset, height * 0 + yOffset);
    CGPoint p2 = CGPointMake(xOffset, height * 1 + yOffset);
    CGPoint p3 = CGPointMake(xOffset, height * 2 + yOffset);
    CGPoint p4 = CGPointMake(xOffset, height * 2 + yOffset);
    
    CGPathMoveToPoint(path, NULL, p1.x,p1.y);
    
    if (arc4random() % 2) {
        CGPathAddQuadCurveToPoint(path, NULL, p1.x - arc4random() % waveWidth, p1.y + height / 2.0, p2.x, p2.y);
        CGPathAddQuadCurveToPoint(path, NULL, p2.x + arc4random() % waveWidth, p2.y + height / 2.0, p3.x, p3.y);
        CGPathAddQuadCurveToPoint(path, NULL, p3.x - arc4random() % waveWidth, p3.y + height / 2.0, p4.x, p4.y);
    } else {
        CGPathAddQuadCurveToPoint(path, NULL, p1.x + arc4random() % waveWidth, p1.y + height / 2.0, p2.x, p2.y);
        CGPathAddQuadCurveToPoint(path, NULL, p2.x - arc4random() % waveWidth, p2.y + height / 2.0, p3.x, p3.y);
        CGPathAddQuadCurveToPoint(path, NULL, p3.x + arc4random() % waveWidth, p3.y + height / 2.0, p4.x, p4.y);
    }
    animation.path = path;
    animation.calculationMode = kCAAnimationCubicPaced;
    CGPathRelease(path);
    
    //透明渐变
    CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnimation.fromValue = @0.95f;
    opacityAnimation.toValue  = @0.0f;
    opacityAnimation.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    
    
    CAAnimationGroup *animGroup = [CAAnimationGroup animation];
    animGroup.animations = @[animation, opacityAnimation];
    return animGroup;
}

- (IBAction)didTapHeartImage:(id)sender
{
    [self addHeart];
    if(likeFlag == 1){
        SetUpView *setUpObj = [[SetUpView alloc]init];
        [setUpObj setMediaLikes:userId accessToken:accessToken notifType:notificationType mediaDetailId:mediaDetailId];
        likeFlag = 0;
    }
    
    //    if (heartButtomBottomConstraint.constant == 111.0)
    //    {
    //        // show heartDescView
    //        heartBottomDescView.hidden = false;
    //        hidingHeartButton.hidden = true;
    //        heartButtomBottomConstraint.constant = 65.0;
    //    }
    //    else{
    //        heartBottomDescView.hidden = true;
    //        hidingHeartButton.hidden = false;
    //        heartButtomBottomConstraint.constant = 111.0;
    //    }
    
}

- (IBAction)didTapSharingListIcon:(id)sender
{
    if ([self isViewFinderLoading]) {
        return;
    }
    
    UIStoryboard *sharingStoryboard = [UIStoryboard storyboardWithName:@"sharing" bundle:nil];
    UIViewController *mysharedChannelVC = [sharingStoryboard instantiateViewControllerWithIdentifier:@"MySharedChannelsViewController"];
    
    UINavigationController *navController = [[UINavigationController alloc]initWithRootViewController:mysharedChannelVC];
    navController.navigationBarHidden = true;
    
    navController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self.navigationController presentViewController:navController animated:true completion:^{
    }];
}

-(BOOL)isViewFinderLoading
{
    if (_activityIndicatorView.isAnimating && self.playing == false) {
        return true;
    }
    return false;
}

#pragma mark : Live streaming

-(void)doActionsForLiveStreamingMode
{
    if(self.playing){
        
        [self initializingStream];
    }
    else {
        [self updateStreamingIfViewFinderStopped];
    }
}

-(void)initializingStream
{
    BOOL initializingStream = [[NSUserDefaults standardUserDefaults] boolForKey:@"InitializingStream"];
    
    if (initializingStream) {
        
        [self showInitializingStreamAlert];
    }
    else
    {
        [self updateStreaming];
    }
}

-(void)updateStreaming
{
    UploadStream * stream = [[UploadStream alloc]init];
    stream.streamingStatus = self;
    [self startOrStopStreaming:stream];
}

-(void)startOrStopStreaming:(UploadStream *)stream
{
    if ([self isStreamStarted] == false) {
        
        [self startStreaming:stream];
    }
    else
    {
        [self stopStreaming:stream];
    }
}

-(void)startStreaming:(UploadStream *)stream
{
    [stream startStreamingClicked];
    [self showInitializingStreamMessage];
}

-(void)stopStreaming:(UploadStream *)stream
{
    [stream stopStreamingClicked];
    [self resetBufferedDuration];
}

-(void)updateStreamingIfViewFinderStopped
{
    if( [self isStreamStarted] == false)
    {
        [self showInputNetworkErrorMessage:nil];
    }
    else
    {
        [self stopStreamingIfViewFinderIsUnableToConnect];
    }
}

-(void)stopStreamingIfViewFinderIsUnableToConnect
{
    UploadStream * stream = [[UploadStream alloc]init];
    stream.streamingStatus = self;
    [self stopStreaming:stream];
}

#pragma mark : - Handle Interruptions

-(void)showInitializingStreamAlert
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Initializing Stream"
                                                    message:@"Streaming is being initialized,please wait!"
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Close", nil)
                                          otherButtonTitles:nil];
    alert.tag = 103;
    [alert show];
}

-(void)showInitializingStreamMessage
{
    noDataFound.hidden = false;
    noDataFound.text = @"Initializing Stream...";
}

-(BOOL)isStreamStarted
{
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    return  [defaults boolForKey:@"StartedStreaming"];
}

-(void) loadStreamsGalleryView
{
    UIStoryboard *streamingStoryboard = [UIStoryboard storyboardWithName:@"Streaming" bundle:nil];
    StreamsGalleryViewController *streamsGalleryViewController = [streamingStoryboard instantiateViewControllerWithIdentifier:@"StreamsGalleryViewController"];
    [self.navigationController pushViewController:streamsGalleryViewController animated:true];
}

-(void)resetBufferedDuration
{
    _minBufferedDuration = NETWORK_MIN_BUFFERED_DURATION;
    _maxBufferedDuration = NETWORK_MAX_BUFFERED_DURATION;
}

- (void) freeBufferedFrames
{
    @synchronized(_videoFrames) {
        [_videoFrames removeAllObjects];
    }
    
    @synchronized(_audioFrames) {
        
        [_audioFrames removeAllObjects];
        _currentAudioFrame = nil;
    }
    
    _bufferedDuration = 0;
}

- (BOOL) interruptDecoder
{
    //if (!_decoder)
    //    return NO;
    return _interrupted;
}

-(void) loadPhotoViewer
{
    UIStoryboard *streamingStoryboard = [UIStoryboard storyboardWithName:@"PhotoViewer" bundle:nil];
    PhotoViewerViewController *photoViewerViewController =( PhotoViewerViewController*)[streamingStoryboard instantiateViewControllerWithIdentifier:@"PhotoViewerViewController"];
    photoViewerViewController.snapShots = snapShotsDict;
    UINavigationController *navController = [[UINavigationController alloc]initWithRootViewController:photoViewerViewController];
    navController.navigationBarHidden = true;
    navController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:navController animated:true completion:^{
    }];
}

-(SnapCamSelectionMode)getCameraSelectionMode
{
    return _snapCamMode;
}

#pragma mark - Streaming protocol

-(void) updateStreamingStatus
{
    [self hideStatusMessage];
    [self changeCameraSelectionImage];
}

-(void)hideStatusMessage
{
    noDataFound.text = @"";
    noDataFound.hidden = true;
}

-(void)cameraSelectionMode:(SnapCamSelectionMode)selectionMode
{
    _snapCamMode = selectionMode;
}

-(void)changeCameraSelectionImage
{
    if (_snapCamMode == SnapCamSelectionModeLiveStream) {
        [self changeLiveNowSelectionImage];
    }
    else{
        dispatch_async(dispatch_get_main_queue(), ^{
            [cameraSelectionButton setImage:[UIImage imageNamed:@"Live_camera.png"] forState:UIControlStateNormal];
        });
    }
}

@end
