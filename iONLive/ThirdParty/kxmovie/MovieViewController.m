
#import "MovieViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import "KxMovieDecoder.h"
#import "KxAudioManager.h"
#import "KxMovieGLView.h"
#import "KxLogger.h"
#import "Connectivity.h"
#import "CA7CH-Swift.h"
#import <CFNetwork/CFNetwork.h>
#import "IPhoneCameraViewController.h"
#import <SpriteKit/SpriteKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import "photoViewCell.h"
#import <QuartzCore/QuartzCore.h>


#define kScreenWidth [[UIScreen mainScreen] bounds].size.width
#define kScreenHeight [[UIScreen mainScreen] bounds].size.height


NSString * const KxMovieParameterMinBufferedDuration = @"KxMovieParameterMinBufferedDuration";
NSString * const KxMovieParameterMaxBufferedDuration = @"KxMovieParameterMaxBufferedDuration";
NSString * const KxMovieParameterDisableDeinterlacing = @"KxMovieParameterDisableDeinterlacing";

////////////////////////////////////////////////////////////////////////////////

//static NSString * formatTimeInterval(CGFloat seconds, BOOL isLeft)
//{
//    seconds = MAX(0, seconds);
//
//    NSInteger s = seconds;
//    NSInteger m = s / 60;
//    NSInteger h = m / 60;
//
//    s = s % 60;
//    m = m % 60;
//
//    NSMutableString *format = [(isLeft && seconds >= 0.5 ? @"-" : @"") mutableCopy];
//    if (h != 0) [format appendFormat:@"%ld:%0.2ld", (long)h, (long)m];
//    else        [format appendFormat:@"%ld", (long)m];
//    [format appendFormat:@":%0.2ld", (long)s];
//
//    return format;
//}

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

@interface MovieViewController () <StreamingProtocol, UIScrollViewDelegate>
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
    IBOutlet NSLayoutConstraint *progressBottomConstraint;
    IBOutlet UIImageView *profilePicture;
    IBOutlet UILabel *typeMedia;
    IBOutlet UILabel *userName;
    IBOutlet UILabel *channelName;
    IBOutlet UIScrollView *scrollViewZoom;
    IBOutlet UILabel *progressLabel;
    IBOutlet UILabel *durationLabel;
    __weak IBOutlet UIImageView *avatarImage;
    __weak IBOutlet UILabel *likeCount;
    
    
    BOOL                _interrupted;
    NSURLSessionDownloadTask *downloadTask;
    
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
    
    NSString *          rtspFilePath;
    NSDictionary        *_parameters;
    UIAlertView *alertViewTemp;
    NSInputStream *inputStream;
    UITapGestureRecognizer *_tapGestureRecognizer;
    NSMutableDictionary *snapShotsDict;
    UrlManager *urlManager;
}

@property (readwrite) BOOL playing;
@property (readwrite) BOOL decoding;
@property (readwrite, strong) KxArtworkFrame *artworkFrame;
@property (nonatomic) Connectivity *wifiReachability;
@property (nonatomic) Connectivity *internetReachability;
@property(nonatomic,strong) MPMoviePlayerController *moviePlayer;

@end

@implementation MovieViewController

int indexForSwipe, screenNumber, orgIndex;
int gestureId = 0;
int playHandleFlag = 0;
int orientationFlagForFullScreenMediaFlag;
int totalCount;

NSString *userId,*accessToken,*mediaDetailId,*notificationType,*channelIdSelected,*mediaTypeSelected,*notificationTypes,*mediaUrlForReplay, *videoDurationSelected;
NSString *mediaURLChk,*mediaTypeChk,*mediaIdChk,*timeDiffChk,*likeCountStrChk,*notifTypeChk,*videoDurationChk;
NSString *likeFlag;

UIImageView *playIconView;
UIView *loadingOverlay;

UIImage *mediaImage;

NSArray *streamORChannelDict;

MovieViewController *obj1;

UIActivityIndicatorView *activityIndicatorProfile;

bool tapHeartDescViewFlag;
bool tapFromDidSelectFlag;
BOOL likeTapFlag;

AVPlayerViewController *_AVPlayerViewController;

NSOperationQueue *mainQueue;
NSBlockOperation *profileOper;
NSBlockOperation *likeOper;

+ (void)initialize
{
    if (!gHistory)
        gHistory = [NSMutableDictionary dictionary];
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

+ (id) movieViewControllerWithContentPath: (NSString *) path
                               parameters: (NSDictionary *) parameters
                                liveVideo:(BOOL)live
{
    obj1 =  [[MovieViewController alloc] initWithContentPath: path parameters: parameters liveVideo:live];
    return obj1;
}

+ (id) movieViewControllerWithImageVideo:(NSString *) channelname
                               channelId: (NSString *) channelId
                                userName: (NSString *) username
                               mediaType: (NSString *) mediaType
                            profileImage: (UIImage *) profileImage
                           VideoImageUrl: (UIImage *) VideoImageUrl
                               notifType: (NSString *) notifType
                                 mediaId: (NSString *) mediaId
                                timeDiff: (NSString *) timeDiff
                            likeCountStr: (NSString *) likeCountStr
                           selectedItem : (int) selectedItem
                           pageIndicator:(int)pageIndicator
                           videoDuration: (NSString *) videoDuration
{
    obj1 = [[MovieViewController alloc]initWithImageVideo:channelname channelId: channelId userName:username mediaType:mediaType profileImage:profileImage VideoImageUrl:VideoImageUrl notifType:notifType mediaId:mediaId timeDiff:timeDiff likeCountStr:likeCountStr selectedItem:selectedItem pageIndicator: pageIndicator videoDuration:videoDuration];
    return obj1;
}

- (id) initWithContentPath: (NSString *) path
                parameters: (NSDictionary *) parameters
                 liveVideo:(BOOL)live
{
    self = [super initWithNibName:@"MovieViewController" bundle:nil];
    if (self) {
        UIGraphicsBeginImageContext(CGSizeMake(self.view.bounds.size.width, (self.view.bounds.size.height+67.0)));
        [[UIImage imageNamed:@"live_stream_blur.png"] drawInRect:CGRectMake(self.view.bounds.origin.x, self.view.bounds.origin.y, self.view.bounds.size.width, (self.view.bounds.size.height+67.0))];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        glView.backgroundColor = [UIColor colorWithPatternImage:image];
        [self.view bringSubviewToFront:glView];
        
        if(live){
            _liveVideo = live;
            rtspFilePath = path;
            _parameters = nil;
            [self setUpDefaultValues];
            closeButton.hidden = true;
            [self setUpInitialGLView];
            [self startDecoder];
            
        }
        else{
            [self.view bringSubviewToFront:glView];
            videoProgressBar.hidden = true;
            progressLabel.hidden = true;
            progressLabel.text = @" ";
            durationLabel.hidden = true;
            scrollViewZoom.alpha = 1.0;
            _liveVideo = live;
            rtspFilePath = path;
            NSString *channel = [parameters valueForKey:@"channelName"];
            NSString *user = [parameters valueForKey:@"userName"];
            UIImage *image = [parameters valueForKey:@"profileImage"];
            NSString *notif = [parameters valueForKey:@"notifType"];
            NSString *channelId = [parameters valueForKey:@"channelId"];
            profilePicture.image = image;
            channelName.text = channel;
            typeMedia.textColor = [UIColor redColor];
            typeMedia.text = @"Live";
            userName.text = [NSString stringWithFormat:@"@%@",user];
            NSUserDefaults *standardDefaults = [[NSUserDefaults alloc]init];
            userId = [standardDefaults valueForKey:@"userLoginIdKey"];
            accessToken = [standardDefaults valueForKey:@"userAccessTockenKey"];
            notificationType = @"LIKE";
            notificationTypes = notif;
            
            mediaDetailId = [parameters valueForKey:@"mediaId"];
            channelIdSelected = channelId;
            mediaTypeSelected = @"live";
            
            likeCount.text = [parameters valueForKey:@"likeCount"];
            [standardDefaults setValue:[parameters valueForKey:@"likeCount"] forKey:@"likeCountFlag"];
            if([userId isEqualToString:user]){
                heartTapButton.hidden = YES;
                typeMedia.text = @"";
                likeCount.hidden = true;
                avatarImage.hidden = true;
            }
            else{
                likeCount.hidden = false;
                avatarImage.hidden = false;
            }
            closeButton.hidden = false;
            _parameters = nil;
            [self setUpDefaultValues];
            [self startDecoder];
        }
    }
    return self;
}

- (id) initWithImageVideo: (NSString *) channelname
                channelId: (NSString *) channelId
                 userName: (NSString *) username
                mediaType: (NSString *) mediaType
             profileImage: (UIImage *) profileImage
            VideoImageUrl: (UIImage *) VideoImageUrl
                notifType: (NSString *) notifType
                  mediaId: (NSString *) mediaId
                 timeDiff: (NSString *) timeDiff
             likeCountStr: (NSString *) likeCountStr
            selectedItem : (int) selectedItem
            pageIndicator: (int) pageIndicator
            videoDuration: (NSString *) videoDuration
{
    
    self = [super initWithNibName:@"MovieViewController" bundle:nil];
    if (self) {
        mediaImage = [UIImage imageNamed:@""];
        mainQueue = [[NSOperationQueue alloc]init];
        profileOper = [[NSBlockOperation alloc]init];
        likeOper = [[NSBlockOperation alloc]init];
        
        _photoCollectionView.hidden = true;
        imageVideoView.userInteractionEnabled = YES;
        [self.view bringSubviewToFront:imageVideoView];
        
        UITapGestureRecognizer *heartBottomDescViewtap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapHeartView:)];
        heartBottomDescViewtap.delegate = self;
        heartBottomDescViewtap.numberOfTapsRequired = 1;
        heartBottomDescViewtap.cancelsTouchesInView = NO;
        [heartView addGestureRecognizer:heartBottomDescViewtap];
        [heartTapButton removeGestureRecognizer:heartBottomDescViewtap];
        
        //Swipe Gesture nuDeclaration
        UISwipeGestureRecognizer *leftSwipe = [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(swipeRecogniser:)];
        leftSwipe.numberOfTouchesRequired = 1;
        leftSwipe.direction = UISwipeGestureRecognizerDirectionLeft;
        leftSwipe.delegate = self;
        [imageVideoView addGestureRecognizer:leftSwipe];
        
        UISwipeGestureRecognizer *rightSwipe = [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(swipeRecogniser:)];
        rightSwipe.numberOfTouchesRequired = 1;
        rightSwipe.direction = UISwipeGestureRecognizerDirectionRight;
        rightSwipe.delegate = self;
        [imageVideoView addGestureRecognizer:rightSwipe];
        
        [self initializeScroll];
        
        streamORChannelDict = [[NSArray alloc]init];
        
        NSUserDefaults *standardDefaults = [[NSUserDefaults alloc]init];
        userId = [standardDefaults valueForKey:@"userLoginIdKey"];
        accessToken = [standardDefaults valueForKey:@"userAccessTockenKey"];
        
        profilePicture.image = profileImage;
        channelName.text = channelname;
        userName.text = [NSString stringWithFormat:@"@%@",username];
        channelIdSelected = channelId;
        
        if([userId isEqualToString:username]){
            heartTapButton.hidden = true;
            likeCount.hidden = true;
            avatarImage.hidden = true;
        }
        else{
            heartTapButton.hidden = false;
            likeCount.hidden = false;
            avatarImage.hidden = false;
        }
        
        indexForSwipe = selectedItem;
        orgIndex = indexForSwipe;
        screenNumber = pageIndicator;
        
        if(pageIndicator == 1){
            streamORChannelDict = [[GlobalStreamList sharedInstance] GlobalStreamDataSource];
        }
        else if(pageIndicator == 2){
            streamORChannelDict = [[SharedChannelDetailsAPI sharedInstance] selectedSharedChannelMediaSource];
        }
        else if(pageIndicator == 0){
            SetUpView *setUpObj = [[SetUpView alloc]init];
            totalCount = (int)[setUpObj getMediaCountWithChannelId:channelIdSelected];
        }
        likeTapFlag = false;
        [self setGUIChanges:mediaType mediaId:mediaId timeDiff:timeDiff likeCountStr:likeCountStr notifType:notifType VideoImageUrl:VideoImageUrl videoDuration:videoDuration];
    }
    return self;
}

-(void) initializeScroll
{
    scrollViewZoom.contentSize = CGSizeMake(imageVideoView.frame.size.width, imageVideoView.frame.size.height);
    scrollViewZoom.maximumZoomScale = 30.0;
    scrollViewZoom.minimumZoomScale = 1.0;
    scrollViewZoom.zoomScale = 1;
    scrollViewZoom.clipsToBounds = YES;
    scrollViewZoom.delegate = self;
    scrollViewZoom.delaysContentTouches = NO;
    scrollViewZoom.backgroundColor = [UIColor lightGrayColor];
}

-(UIView *) viewForZoomingInScrollView:(UIScrollView *)inScroll {
    return imageVideoView;
}

-(void) setGUIChanges: (NSString *) mediaType
              mediaId: (NSString *) mediaId
             timeDiff: (NSString *) timeDiff
         likeCountStr: (NSString *) likeCountStr
            notifType: (NSString *) notifType
        VideoImageUrl: (UIImage *) VideoImageUrl
        videoDuration: (NSString *) videoDuration
{
    urlManager = [UrlManager sharedInstance];
    [self setUpDefaultValues];
    [self setUpViewForImageVideo];
    likeCount.text = likeCountStr;
    
    if([mediaType  isEqual: @"live"]){
        typeMedia.textColor = [UIColor redColor];
        typeMedia.text = mediaType;
    }
    else{
        typeMedia.textColor = [UIColor blackColor];
        typeMedia.text = timeDiff;
    }
    
    NSUserDefaults *standardDefaults = [[NSUserDefaults alloc]init];
    [standardDefaults setValue:likeCountStr forKey:@"likeCountFlag"];
    
    mediaUrlForReplay = [[UrlManager sharedInstance] getFullImageForMediaWithMediaId:mediaId userName:userId accessToken:accessToken];
    
    notificationTypes = notifType;
    notificationType = @"LIKE";
    mediaDetailId = mediaId;
    mediaTypeSelected = mediaType;
    videoDurationSelected = videoDuration;
    
    if([mediaType  isEqual: @"video"])
    {
        [self removeOverlay];
//        durationLabel.text = videoDurationSelected;
        durationLabel.hidden = true;
//        [glView bringSubviewToFront:durationLabel];
        videoProgressBar.hidden = true;
        progressLabel.hidden = true;
        progressLabel.text = @" ";
        scrollViewZoom.alpha = 1.0;
        topView.hidden = false;
        imageVideoView.contentMode = UIViewContentModeScaleAspectFill;
        mediaImage = VideoImageUrl;
        [playIconView removeFromSuperview];
        playIconView = [[UIImageView alloc]init];
        playIconView.image = [UIImage imageNamed:@"Circled Play"];
        CGFloat width = [UIScreen mainScreen].bounds.size.width;
        CGFloat height = [UIScreen mainScreen].bounds.size.height;
        playIconView.frame = CGRectMake(width/2 - 20, height/2 - 20, 40, 40);
        [glView addSubview:playIconView];
        [glView bringSubviewToFront:playIconView];
        [self setGuiBasedOnOrientation];
        UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(playVideoAutomatically)];
        singleTap.numberOfTapsRequired = 1;
        singleTap.delegate = self;
        [playIconView setUserInteractionEnabled:YES];
        [playIconView addGestureRecognizer:singleTap];
        if(!tapFromDidSelectFlag)
        {
            [self setUpTransitionForSwipe];
        }
    }
    else{
        videoProgressBar.hidden = true;
        progressLabel.hidden = true;
        progressLabel.text = @" ";
        durationLabel.hidden = true;
        scrollViewZoom.alpha = 1.0;
        [playIconView removeFromSuperview];
        [self setUpImageVideo:mediaType mediaUrl:mediaUrlForReplay mediaDetailId:mediaDetailId];
    }
}

- (BOOL)gestureRecognizer:(UITapGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isKindOfClass:[UIButton class]]){
        return NO;
    }
    return YES;
}

-(void) tapHeartView :(UITapGestureRecognizer *) tap
{
    if(![videoProgressBar isHidden]){
        videoProgressBar.hidden = false;
    }
    else{
        videoProgressBar.hidden = true;
    }
    
    if(![progressLabel isHidden]){
        scrollViewZoom.alpha = 0.4;
        progressLabel.hidden = false;
    }
    else{
        scrollViewZoom.alpha = 1.0;
        progressLabel.hidden = true;
        progressLabel.text = @" ";
    }
    
//    if(!tapHeartDescViewFlag)
//    {
//        _photoCollectionView.hidden = false;
//        dispatch_async(dispatch_get_main_queue(), ^(void){
//            if(indexForSwipe != -1){
//                [_photoCollectionView reloadData];
//                if(screenNumber == 0){
//                    if(indexForSwipe < totalCount){
//                        [_photoCollectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:indexForSwipe inSection:0] atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:NO];
//                    }
//                    else if(indexForSwipe == totalCount){
//                        [_photoCollectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:indexForSwipe - 1 inSection:0] atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:NO];
//                        indexForSwipe = indexForSwipe - 1;
//                    }
//                }
//                else{
//                    if(indexForSwipe < [streamORChannelDict count])
//                    {
//                        [_photoCollectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:indexForSwipe inSection:0] atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:NO];
//                    }
//                    else if(indexForSwipe == [streamORChannelDict count]){
//                        [_photoCollectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:indexForSwipe - 1 inSection:0] atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:NO];
//                        indexForSwipe = indexForSwipe - 1;
//                    }
//                }
//            }
//        });
//        _bottomConstraintForHeartView.constant = 50;
//        progressBottomConstraint.constant = -25;
//        tapHeartDescViewFlag = true;
//    }
//    else{
        _photoCollectionView.hidden = true;
        _bottomConstraintForHeartView.constant = 3;
        progressBottomConstraint.constant = -70;
        tapHeartDescViewFlag = false;
//    }
}

-(void) setUpTransitionForSwipe{
    CATransition *transition = [CATransition animation];
    transition.duration = 0.3;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    transition.type = kCATransitionMoveIn;
    
    if (gestureId == 0)
    {
        transition.subtype = kCATransitionFromRight;
    }
    else if (gestureId == 1)
    {
        transition.subtype = kCATransitionFromLeft;
    }
    [imageVideoView.layer addAnimation:transition forKey:nil];
    dispatch_async(dispatch_get_main_queue(), ^(void){
        videoProgressBar.hidden = true;
        progressLabel.hidden = true;
        progressLabel.text = @" ";
        scrollViewZoom.alpha = 1.0;
//        if(indexForSwipe != -1){
//            [_photoCollectionView reloadData];
//            if(screenNumber == 0){
//                if(indexForSwipe < totalCount){
//                    [_photoCollectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:indexForSwipe inSection:0] atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:NO];
//                }
//                else if(indexForSwipe == totalCount){
//                    [_photoCollectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:indexForSwipe - 1 inSection:0] atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:NO];
//                    indexForSwipe = indexForSwipe - 1;
//                }
//            }
//            else{
//                if(indexForSwipe < [streamORChannelDict count])
//                {
//                    [_photoCollectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:indexForSwipe inSection:0] atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:NO];
//                }
//                else if(indexForSwipe == [streamORChannelDict count]){
//                    [_photoCollectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:indexForSwipe - 1 inSection:0] atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:NO];
//                    indexForSwipe = indexForSwipe - 1;
//                }
//            }
//        }
    });
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    if (scrollView.zoomScale < 1.0) {
        scrollView.minimumZoomScale = 1.0;
    }
}

-(void) scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view{
    if([mediaTypeSelected  isEqual: @"video"]){
        scrollViewZoom.minimumZoomScale = 1.0;
        scrollViewZoom.maximumZoomScale = 1.0;
    }
    else{
        scrollViewZoom.minimumZoomScale = 1.0;
        scrollViewZoom.maximumZoomScale = 30.0;
    }
}

-(void) scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale{
}

-(void) setGuiBasedOnOrientation
{
    CATransition *transition = [CATransition animation];
    transition.duration = 0.3;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    transition.type = kCATransitionFade;
    transition.delegate = self;
    [[imageVideoView layer] addAnimation:transition forKey:nil];
    
    if([mediaTypeSelected isEqualToString:@"image"]){
        orientationFlagForFullScreenMediaFlag = [self getFullscreenMediaOrientation];
        UIImage *orientedImage = [[UIImage alloc]init];
        orientedImage = mediaImage;
        
        switch (orientationFlagForFullScreenMediaFlag) {
            case 1:
                if(mediaImage.size.width > mediaImage.size.height)
                {
                    imageVideoView.contentMode = UIViewContentModeScaleAspectFit;
                }
                else{
                    imageVideoView.contentMode = UIViewContentModeScaleAspectFill;
                }
                orientedImage = mediaImage;
                break;
            case 2:
                if(mediaImage.size.width > mediaImage.size.height)
                {
                    imageVideoView.contentMode = UIViewContentModeScaleAspectFit;
                    orientedImage = [UIImage imageWithCGImage:mediaImage.CGImage scale:1.0 orientation:UIImageOrientationRight];
                }
                else{
                    imageVideoView.contentMode = UIViewContentModeScaleAspectFit;
                    orientedImage = [UIImage imageWithCGImage:mediaImage.CGImage scale:1.0 orientation:UIImageOrientationDown];
                }
                break;
            case 3:
                if(mediaImage.size.width > mediaImage.size.height)
                {
                    imageVideoView.contentMode = UIViewContentModeScaleAspectFit;
                    orientedImage = [UIImage imageWithCGImage:mediaImage.CGImage scale:1.0 orientation:UIImageOrientationLeft];
                }
                else{
                    imageVideoView.contentMode = UIViewContentModeScaleAspectFit;
                    orientedImage = [UIImage imageWithCGImage:mediaImage.CGImage scale:1.0 orientation:UIImageOrientationUp];
                }
                break;
            default:
                break;
        }
        dispatch_async(dispatch_get_main_queue(), ^(void){
            imageVideoView.image = orientedImage;
        });
    }
    else{
        [self setGuiBasedOnOrientationForVideo];
    }
}

-(void) setGuiBasedOnOrientationForVideo{
    orientationFlagForFullScreenMediaFlag = [self getFullscreenMediaOrientation];
    UIImage *orientedImage = [[UIImage alloc]init];
    orientedImage = mediaImage;
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    CGFloat height = [UIScreen mainScreen].bounds.size.height;
    switch (orientationFlagForFullScreenMediaFlag) {
        case 1:
            imageVideoView.contentMode = UIViewContentModeScaleAspectFill;
            orientedImage = mediaImage;
            playIconView.image = [UIImage imageNamed:@"Circled Play"];
            playIconView.frame = CGRectMake(width/2 - 20, height/2 - 20, 40, 40);
            break;
        case 2:
            imageVideoView.contentMode = UIViewContentModeScaleAspectFit;
            orientedImage = [UIImage imageWithCGImage:mediaImage.CGImage scale:1.0 orientation:UIImageOrientationRight];
            playIconView.image = [UIImage imageWithCGImage:[UIImage imageNamed:@"Circled Play"].CGImage scale:1.0 orientation:UIImageOrientationRight];
            playIconView.frame = CGRectMake(width/2 - 20, height/2 - 40, 40, 40);
            break;
        case 3:
            imageVideoView.contentMode = UIViewContentModeScaleAspectFit;
            orientedImage = [UIImage imageWithCGImage:mediaImage.CGImage scale:1.0 orientation:UIImageOrientationLeft];
            playIconView.image = [UIImage imageWithCGImage:[UIImage imageNamed:@"Circled Play"].CGImage scale:1.0 orientation:UIImageOrientationLeft];
            playIconView.frame = CGRectMake(width/2 - 20, height/2 - 40, 40, 40);
            break;
        default:
            break;
    }
    dispatch_async(dispatch_get_main_queue(), ^(void){
        imageVideoView.image = orientedImage;
    });
}

-(void) setUpImageVideo : (NSString*) mediaType mediaUrl:(NSString *) mediaUrl mediaDetailId: (NSString *) mediaDetailId
{
    if((indexForSwipe == orgIndex) && (![mediaTypeSelected  isEqual: @"video"]))
    {
        [self removeOverlay];
        [self showOverlay1];
    }
    
    orientationFlagForFullScreenMediaFlag = [self getFullscreenMediaOrientation];
    imageVideoView.hidden = false;
    imageView.hidden = false;
    videoProgressBar.hidden = true;
    progressLabel.hidden = true;
    progressLabel.text = @" ";
    scrollViewZoom.alpha = 1.0;
    [self.view bringSubviewToFront:imageVideoView];
    NSURL *parentPath = [[FileManagerViewController sharedInstance] getParentDirectoryPath];
    NSString *parentPathStr = [parentPath absoluteString];
    NSString *mediaNamePath = [NSString stringWithFormat:@"%@full",mediaDetailId];
    NSString *savingPath = [NSString stringWithFormat:@"%@/%@full",parentPathStr,mediaDetailId];
    bool fileExistFlag = [[FileManagerViewController sharedInstance] fileExistWithMediaPath:savingPath];
    if(fileExistFlag == true){
        [self removeOverlay];
        mediaImage = [[FileManagerViewController sharedInstance] getImageFromFilePathWithMediaPath:savingPath];
        [self setGuiBasedOnOrientation];
        if((indexForSwipe != orgIndex) && (![mediaTypeSelected  isEqual: @"video"]) && (!tapFromDidSelectFlag))
        {
            [self setUpTransitionForSwipe];
        }
    }
    else{
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            NSURL *url = [self convertStringToUrl:mediaUrl];
            NSData *data = [[NSData alloc] initWithContentsOfURL:url];
            if(data != nil)
            {
                mediaImage = [[UIImage alloc]initWithData:data];
                if(mediaImage == nil){
                    NSString *failedString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    NSArray *fullString = [failedString componentsSeparatedByString:@","];
                    NSArray *errorString = [fullString[1] componentsSeparatedByString:@":"];
                    NSString *orgString = errorString[1];
                    NSCharacterSet *invertCharSet = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
                    orgString = [orgString stringByTrimmingCharactersInSet:invertCharSet];
                    if(([orgString  isEqual: @"USER004"]) || ([orgString  isEqual: @"USER005"]) || ([orgString  isEqual: @"USER006"])){
                        [self loadInitialView];
                    }
                    mediaImage = [UIImage imageNamed:@"thumb12"];
                }
            }
            else{
                mediaImage = [UIImage imageNamed:@"thumb12"];
            }
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [NSTimer scheduledTimerWithTimeInterval: 1.0f
                                                 target: self
                                               selector:@selector(onHide:)
                                               userInfo: nil repeats:NO];
                [[FileManagerViewController sharedInstance] saveImageToFilePathWithMediaName:mediaNamePath mediaImage:mediaImage];
            });
        });
    }
}

-(void) loadInitialView
{
    if([[NSUserDefaults standardUserDefaults] valueForKey:@"tokenValid"] != nil)
    {
        NSString *tokenValid = [[NSUserDefaults standardUserDefaults] valueForKey:@"tokenValid"];
        if([tokenValid isEqual:@"true"]){
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
                
                //                [[ErrorManager sharedInstance] tockenExpired];
                
                UIStoryboard  *login = [UIStoryboard storyboardWithName:@"Authentication" bundle:nil];
                UIViewController *authenticate = [login instantiateViewControllerWithIdentifier:@"AuthenticateNavigationController"];
                authenticate.navigationController.navigationBarHidden = true;
                //                [[self navigationController] pushViewController:authenticate animated:false];
                
                [self presentViewController:authenticate animated:false completion:^{
                    [[ErrorManager sharedInstance] invalidTockenError];
                }];
            });
        }
    }
}

-(void)onHide:(NSTimer *)timer {
    [self removeOverlay];
    
    if((indexForSwipe != orgIndex) && (![mediaTypeSelected  isEqual: @"video"]) && (!tapFromDidSelectFlag))
    {
        [self setUpTransitionForSwipe];
    }
    
    [self setGuiBasedOnOrientation];
}

-(void) playVideoAutomatically
{
    [glView bringSubviewToFront:videoProgressBar];
    NSURL *parentPath = [[FileManagerViewController sharedInstance] getParentDirectoryPath];
    NSString *parentPathStr = [parentPath absoluteString];
    NSString *mediaPath = [NSString stringWithFormat:@"/%@video.mov",mediaDetailId];
    NSString *savingPath = [parentPathStr stringByAppendingString:mediaPath];
    BOOL fileExistFlag = [[FileManagerViewController sharedInstance] fileExistWithMediaPath:savingPath];
    if(fileExistFlag == true)
    {
        videoProgressBar.hidden = true;
        progressLabel.hidden = true;
        progressLabel.text = @" ";
        scrollViewZoom.alpha = 1.0;
        scrollViewZoom.zoomScale = 1.0;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        [[AVAudioSession sharedInstance] setActive: YES error: nil];
        NSURL *url = [NSURL fileURLWithPath:savingPath];
        _AVPlayerViewController = [AVPlayerViewController new];
        _AVPlayerViewController.delegate = self;
        _AVPlayerViewController.showsPlaybackControls = YES;
        _AVPlayerViewController.allowsPictureInPicturePlayback = YES;
        _AVPlayerViewController.videoGravity = AVLayerVideoGravityResizeAspect;
        _AVPlayerViewController.player = [AVPlayer playerWithURL:url];
        [_AVPlayerViewController.player play];
        _AVPlayerViewController.player.closedCaptionDisplayEnabled = NO;
        [self presentViewController:_AVPlayerViewController animated:NO completion:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playerDidFinish:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:[_AVPlayerViewController.player currentItem]];
        
        topView.hidden = false;
        cameraSelectionButton.hidden = true;
        liveView.hidden = true;
        playIconView.hidden = false;
        numberOfSharedChannels.hidden = true;
        topView.backgroundColor = [UIColor clearColor];
        [glView bringSubviewToFront:heartView];
        [glView bringSubviewToFront:topView];
        playHandleFlag = 1;
    }
    else{
        NSURL *url = [self convertStringToUrl:mediaUrlForReplay];
        [self downloadVideo:url];
    }
}

-(void) showOverlay
{
    imageVideoView.userInteractionEnabled = false;
    [self.view bringSubviewToFront:topView];
    IONLLoadingView *loadingOverlayController = [[IONLLoadingView alloc]initWithNibName:@"IONLLoadingOverlay" bundle:nil];
    loadingOverlayController.view.frame = CGRectMake(0, 0, imageVideoView.frame.size.width,imageVideoView.frame.size.height + heartView.frame.size.height);
    [loadingOverlayController startLoading];
    loadingOverlay = [[UIView alloc]init];
    loadingOverlay = loadingOverlayController.view;
    [imageVideoView addSubview:loadingOverlay];
}

-(void) showOverlay1
{
    scrollViewZoom.userInteractionEnabled = false;
    imageVideoView.userInteractionEnabled = false;
    [self.view bringSubviewToFront:topView];
    IONLLoadingView *loadingOverlayController = [[IONLLoadingView alloc]initWithNibName:@"IONLLoadingOverlay" bundle:nil];
    loadingOverlayController.view.frame = CGRectMake(0, 0, imageVideoView.frame.size.width,imageVideoView.frame.size.height + heartView.frame.size.height);
    [loadingOverlayController startLoading];
    loadingOverlay = [[UIView alloc]init];
    loadingOverlay = loadingOverlayController.view;
    [imageVideoView addSubview:loadingOverlay];
    _photoCollectionView.userInteractionEnabled = false;
    heartView.userInteractionEnabled = false;
    _photoCollectionView.alpha = 0.5;
    heartView.alpha = 0.5;
}

-(void) removeOverlay{
    scrollViewZoom.userInteractionEnabled = true;
    [loadingOverlay removeFromSuperview];
    imageVideoView.userInteractionEnabled = true;
//    _photoCollectionView.userInteractionEnabled = true;
    heartView.userInteractionEnabled = true;
    _photoCollectionView.alpha = 1.0;
    heartView.alpha = 1.0;
}

-(void) playbackStateChange:(NSNotification *) notif
{
    switch ([_moviePlayer playbackState]) {
        case MPMoviePlaybackStateStopped:
            NSLog(@"Stopped");
            break;
        case MPMoviePlaybackStatePlaying:
            NSLog(@"Playing");
            playHandleFlag = 1;
            break;
        case MPMoviePlaybackStatePaused:
            NSLog(@"Paused");
            playHandleFlag = 1;
            break;
        case MPMoviePlaybackStateInterrupted:
            NSLog(@"Interrupted");
            break;
        case MPMoviePlaybackStateSeekingForward:
            NSLog(@"Seeking Forward");
            break;
        case MPMoviePlaybackStateSeekingBackward:
            NSLog(@"Seeking Backward");
            break;
        default:
            break;
    }
}

-(void) checkVideoStatus
{
    if (playHandleFlag == 1)
    {
        playHandleFlag = 0;
        [_moviePlayer stop];
        [_moviePlayer.view removeFromSuperview];
        self.view.userInteractionEnabled = true;
    }
    if(downloadTask.state == 0)
    {
        [downloadTask cancel];
    }
}

-(void)swipeRecogniser:(UISwipeGestureRecognizer *)swipeReceived
{
    if(scrollViewZoom.zoomScale <= 1.0){
        tapFromDidSelectFlag = false;
        [self removeOverlay];
        [self showOverlay1];
        orgIndex = -11;
        UIImage *VideoImageUrlChk;
        if (swipeReceived.direction == UISwipeGestureRecognizerDirectionLeft)
        {
            gestureId = 0;
        }
        else if (swipeReceived.direction == UISwipeGestureRecognizerDirectionRight)  //Swipe Right Direction check starts
        {
            gestureId = 1;
        }
        if(screenNumber == 0)
        {
            if(gestureId == 0)
            {
                if(indexForSwipe < 0)
                {
                    indexForSwipe = 0;
                }
                if(indexForSwipe < totalCount)
                {
                    indexForSwipe = indexForSwipe + 1;
                }
            }
            else
            {
                if(indexForSwipe < 0)
                {
                    indexForSwipe = 0;
                }
                if (indexForSwipe == totalCount)
                {
                    indexForSwipe = (int)totalCount - 1;
                }
                indexForSwipe = indexForSwipe - 1;
            }
            
            if(indexForSwipe != -1 && indexForSwipe < totalCount){
                if(scrollViewZoom.zoomScale != 1)
                {
                    [NSThread sleepForTimeInterval:0.7];
                }
                
                scrollViewZoom.zoomScale = 1.0;
                scrollViewZoom.minimumZoomScale = 1.0;
                scrollViewZoom.maximumZoomScale = 30.0;
                progressLabel.text = @" ";
                [self checkVideoStatus];
                
                if(indexForSwipe < totalCount)
                {
                    if (indexForSwipe != -1)
                    {
                        mediaTypeChk = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelIdSelected][indexForSwipe][@"gcs_object_type"];
                        mediaIdChk = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelIdSelected][indexForSwipe][@"media_detail_id"];
                        NSString *createdTime = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelIdSelected][indexForSwipe][@"created_time_stamp"];
                        timeDiffChk = [[FileManagerViewController sharedInstance] getTimeDifferenceWithDateStr:createdTime];
                        likeCountStrChk = @"0";
                        notifTypeChk = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelIdSelected][indexForSwipe][@"notification_type"];
                        VideoImageUrlChk = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelIdSelected][indexForSwipe][@"thumbImage"];
                        videoDurationChk = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelIdSelected][indexForSwipe][@"video_duration"];
                        [self setGUIChanges:mediaTypeChk mediaId:mediaIdChk timeDiff:timeDiffChk likeCountStr:likeCountStrChk notifType:notifTypeChk VideoImageUrl:VideoImageUrlChk videoDuration:videoDurationChk];
                    }
                    else{
                        [self removeOverlay];
                    }
                }
                else{
                    [self removeOverlay];
                }
            }
            else{
                if(indexForSwipe < 0)
                {
                    indexForSwipe = 0;
                }
                if (indexForSwipe == totalCount)
                {
                    indexForSwipe = (int)totalCount - 1;
                }
                [self removeOverlay];
            }
        }
        else
        {
            if(gestureId == 0)
            {
                if(indexForSwipe < 0)
                {
                    indexForSwipe = 0;
                }
                if(indexForSwipe < [streamORChannelDict count])
                {
                    indexForSwipe = indexForSwipe + 1;
                }
            }
            else
            {
                if(indexForSwipe < 0)
                {
                    indexForSwipe = 0;
                }
                if (indexForSwipe == [streamORChannelDict count])
                {
                    indexForSwipe = (int)[streamORChannelDict count] - 1;
                }
                indexForSwipe = indexForSwipe - 1;
            }
            
            if(indexForSwipe != -1 && indexForSwipe < [streamORChannelDict count]){
                if(scrollViewZoom.zoomScale != 1)
                {
                    [NSThread sleepForTimeInterval:0.7];
                }
                
                scrollViewZoom.zoomScale = 1.0;
                scrollViewZoom.minimumZoomScale = 1.0;
                scrollViewZoom.maximumZoomScale = 30.0;
                progressLabel.text = @" ";
                [self checkVideoStatus];
                
                if(indexForSwipe < [streamORChannelDict count])
                {
                    if (indexForSwipe != -1)
                    {
                        if (screenNumber == 1)
                        {
                            [activityIndicatorProfile removeFromSuperview];
                            activityIndicatorProfile = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
                            activityIndicatorProfile.alpha = 1.0;
                            [heartView addSubview:activityIndicatorProfile];
                            activityIndicatorProfile.frame =  CGRectMake(profilePicture.frame.origin.x + 5 , profilePicture.frame.origin.y + 7, 30.0,30.0);
                            profilePicture.alpha = 0.2;
                            activityIndicatorProfile.color = [UIColor blueColor];
                            [activityIndicatorProfile stopAnimating];
                            [activityIndicatorProfile startAnimating];//to start animating
                        }
                        mediaTypeChk = streamORChannelDict[indexForSwipe][@"mediaType"];
                        mediaIdChk = streamORChannelDict[indexForSwipe][@"mediaId"];
                        NSString *createdTime = streamORChannelDict[indexForSwipe][@"createdTime"];
                        timeDiffChk = [[FileManagerViewController sharedInstance] getTimeDifferenceWithDateStr:createdTime];
                        likeCountStrChk = @"";
                        notifTypeChk = streamORChannelDict[indexForSwipe][@"notification"];
                        VideoImageUrlChk = streamORChannelDict[indexForSwipe][@"mediaUrl"];
                        videoDurationChk = streamORChannelDict[indexForSwipe][@"video_duration"];
                        SetUpView *setUpObj = [[SetUpView alloc]init];
                        if(screenNumber == 1){
                            [profileOper cancel];
                            profileOper = [NSBlockOperation blockOperationWithBlock:^{
                                [setUpObj getProfileImageSelectedIndexWithUserIdKey:[NSString stringWithFormat:@"%@",streamORChannelDict[indexForSwipe][@"user_name"]] objects:obj1 operObj:profileOper];
                            }];
                            [mainQueue addOperation:profileOper];
                            
                            channelName.text = streamORChannelDict[indexForSwipe][@"channel_name"];
                            userName.text = [NSString stringWithFormat:@"@%@",streamORChannelDict[indexForSwipe][@"user_name"]];
                            channelIdSelected = streamORChannelDict[indexForSwipe][@"ch_detail_id"];
                        }
                        
                        if(screenNumber == 1 || screenNumber == 2){
                            likeTapFlag = false;
                            [likeOper cancel];
                            likeOper = [NSBlockOperation blockOperationWithBlock:^{
                                [setUpObj getLikeCountWithMediaType:mediaTypeChk mediaId:mediaIdChk Objects:obj1 operObjs:likeOper];
                            }];
                            [mainQueue addOperation:likeOper];
                        }
                        
                        [self setGUIChanges:mediaTypeChk mediaId:mediaIdChk timeDiff:timeDiffChk likeCountStr:likeCountStrChk notifType:notifTypeChk VideoImageUrl:VideoImageUrlChk videoDuration:videoDurationChk];
                    }
                    else{
                        [self removeOverlay];
                    }
                }
                else{
                    [self removeOverlay];
                }
            }
            else{
                if(indexForSwipe < 0)
                {
                    indexForSwipe = 0;
                }
                if (indexForSwipe == [streamORChannelDict count])
                {
                    indexForSwipe = (int)[streamORChannelDict count] - 1;
                }
                [self removeOverlay];
            }
        }
    }
}

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return true;
}

-(void) downloadVideo: (NSURL *) url
{
    playIconView.hidden = true;
    NSMutableURLRequest *downloadReq = [[NSMutableURLRequest alloc]initWithURL:url];
    NSURLSession *session = [NSURLSession sessionWithConfiguration: [NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    downloadTask = [session downloadTaskWithRequest:downloadReq];
    videoProgressBar.hidden = true;
    progressLabel.hidden = false;
    scrollViewZoom.zoomScale = 1.0;
    scrollViewZoom.maximumZoomScale = 1.0;
    [glView bringSubviewToFront:progressLabel];
    progressLabel.text = @"Downloading...";
    scrollViewZoom.alpha = 0.4;
    videoProgressBar.progressViewStyle = UIProgressViewStyleDefault;
    videoProgressBar.progress = 0.0;
    [videoProgressBar setTransform:CGAffineTransformMakeScale(1.0, 3.0)];
    [topView bringSubviewToFront:closeButton];
    [downloadTask resume];
}

-(void) URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    scrollViewZoom.maximumZoomScale = 1.0;
    videoProgressBar.hidden = false;
    progressLabel.hidden = false;
    scrollViewZoom.alpha = 0.4;
    float progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
    videoProgressBar.progress = progress;
    int y = (int)round(progress*100);
    NSString *str1 = @"Downloading";
    NSString *str2 = @"%";
    NSString *mainStr = [NSString stringWithFormat:@"%@ %d %@", str1, y, str2];
    progressLabel.text = mainStr;
    if(progress == 1.0)
    {
        scrollViewZoom.maximumZoomScale = 30.0;
        progressLabel.hidden = true;
        progressLabel.text = @" ";
        scrollViewZoom.alpha = 1.0;
        videoProgressBar.hidden = true;
        scrollViewZoom.zoomScale = 1.0;
    }
}

-(void) URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    NSData *data = [[NSData alloc]initWithContentsOfURL:location];
    NSURL *parentPath = [[FileManagerViewController sharedInstance] getParentDirectoryPath];
    NSString *parentPathStr = [parentPath absoluteString];
    NSString *mediaPath = [NSString stringWithFormat:@"/%@video.mov",mediaDetailId];
    NSString *savingPath = [parentPathStr stringByAppendingString:mediaPath];
    NSURL *fileURL = [NSURL fileURLWithPath:savingPath];
    if(data!= nil)
    {
        NSString *failedString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if(failedString != nil){
            NSArray *fullString = [failedString componentsSeparatedByString:@","];
            NSArray *errorString = [fullString[1] componentsSeparatedByString:@":"];
            NSString *orgString = errorString[1];
            NSCharacterSet *invertCharSet = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
            orgString = [orgString stringByTrimmingCharactersInSet:invertCharSet];
            if(([orgString  isEqual: @"USER004"]) || ([orgString  isEqual: @"USER005"]) || ([orgString  isEqual: @"USER006"])){
                [self loadInitialView];
            }
        }
        else{
            bool write = [data writeToURL:fileURL atomically:YES];
            if(write)
            {
                [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
                [[AVAudioSession sharedInstance] setActive: YES error: nil];
                NSURL *url = [NSURL fileURLWithPath:savingPath];
                _AVPlayerViewController = [AVPlayerViewController new];
                _AVPlayerViewController.delegate = self;
                _AVPlayerViewController.showsPlaybackControls = YES;
                _AVPlayerViewController.allowsPictureInPicturePlayback = YES;
                _AVPlayerViewController.videoGravity = AVLayerVideoGravityResizeAspect;
                _AVPlayerViewController.player = [AVPlayer playerWithURL:url];
                [_AVPlayerViewController.player play];
                _AVPlayerViewController.player.closedCaptionDisplayEnabled = NO;
                [self presentViewController:_AVPlayerViewController animated:NO completion:nil];
                
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(playerDidFinish:)
                                                             name:AVPlayerItemDidPlayToEndTimeNotification
                                                           object:[_AVPlayerViewController.player currentItem]];
                topView.hidden = false;
                cameraSelectionButton.hidden = true;
                liveView.hidden = true;
                numberOfSharedChannels.hidden = true;
                playIconView.hidden = false;
                topView.backgroundColor = [UIColor clearColor];
                [glView bringSubviewToFront:heartView];
                [glView bringSubviewToFront:topView];
                playHandleFlag = 1;
            }
        }
    }
}

-(void) playerDidFinish :(NSNotification *) notif
{
    scrollViewZoom.zoomScale = 1.0;
    [_AVPlayerViewController removeFromParentViewController];
    [self dismissViewControllerAnimated:true completion:nil];
    //    [self dismissViewControllerAnimated:_AVPlayerViewController completion:nil];
    [playIconView removeFromSuperview];
    playIconView = [[UIImageView alloc]init];
    playIconView.image = [UIImage imageNamed:@"Circled Play"];
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    CGFloat height = [UIScreen mainScreen].bounds.size.height;
    playIconView.frame = CGRectMake(width/2 - 20, height/2 - 20, 40, 40);
    [glView addSubview:playIconView];
    [glView bringSubviewToFront:playIconView];
    
    [self setGuiBasedOnOrientation];
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapDetected)];
    singleTap.numberOfTapsRequired = 1;
    [playIconView setUserInteractionEnabled:YES];
    [playIconView addGestureRecognizer:singleTap];
}

-(void) tapDetected
{
    NSURL *parentPath = [[FileManagerViewController sharedInstance] getParentDirectoryPath];
    NSString *parentPathStr = [parentPath absoluteString];
    NSString *mediaPath = [NSString stringWithFormat:@"/%@video.mov",mediaDetailId];
    NSString *savingPath = [parentPathStr stringByAppendingString:mediaPath];
    videoProgressBar.hidden = true;
    progressLabel.hidden = true;
    progressLabel.text = @" ";
    scrollViewZoom.alpha = 1.0;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive: YES error: nil];
    NSURL *url = [NSURL fileURLWithPath:savingPath];
    _AVPlayerViewController = [AVPlayerViewController new];
    _AVPlayerViewController.delegate = self;
    _AVPlayerViewController.showsPlaybackControls = YES;
    _AVPlayerViewController.allowsPictureInPicturePlayback = YES;
    _AVPlayerViewController.videoGravity = AVLayerVideoGravityResizeAspect;
    _AVPlayerViewController.player = [AVPlayer playerWithURL:url];
    [_AVPlayerViewController.player play];
    _AVPlayerViewController.player.closedCaptionDisplayEnabled = NO;
    [self presentViewController:_AVPlayerViewController animated:NO completion:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerDidFinish:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:[_AVPlayerViewController.player currentItem]];
    topView.hidden = false;
    cameraSelectionButton.hidden = true;
    liveView.hidden = true;
    numberOfSharedChannels.hidden = true;
    playIconView.hidden = false;
    topView.backgroundColor = [UIColor clearColor];
    [glView bringSubviewToFront:heartView];
    [glView bringSubviewToFront:topView];
    playHandleFlag = 1;
}

-(void) setUpViewForImageVideo
{
    heart2Button.hidden = true;
    heart3Button.hidden = true;
    heart4Button.hidden = true;
    hidingHeartButton.hidden = true;
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
    progressLabel.hidden = true;
    progressLabel.text = @" ";
    imageVideoView.hidden = true;
    scrollViewZoom.alpha = 1.0;
    _snapCamMode = SnapCamSelectionModeSnapCam;
    _backGround =  false;
    [self.view.window setBackgroundColor:[UIColor grayColor]];
    [cameraButton setImage:[UIImage imageNamed:@"camera_Button_ON"] forState:UIControlStateHighlighted];
}

-(void)setUpInitialBlurView
{
    UIGraphicsBeginImageContext(CGSizeMake(self.view.bounds.size.width, (self.view.bounds.size.height+67.0)));
    [[UIImage imageNamed:@""] drawInRect:CGRectMake(self.view.bounds.origin.x, self.view.bounds.origin.y, self.view.bounds.size.width, (self.view.bounds.size.height+67.0))];
    //  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    //    glView.backgroundColor = [UIColor colorWithPatternImage:image];
    glView.backgroundColor = [UIColor whiteColor];
}

#pragma mark : LoadView

- (void)viewDidLoad
{
    [super viewDidLoad];
    totalCount = 0;
    tapHeartDescViewFlag = false;
    tapFromDidSelectFlag = false;
//    self.photoCollectionView.delegate = self;
//    self.photoCollectionView.dataSource = self;
    
    durationLabel.hidden = true;
    progressLabel.hidden = true;
    scrollViewZoom.alpha = 1.0;
    progressLabel.text = @" ";
    
//    [self.view bringSubviewToFront:self.photoCollectionView];
//    [self.photoCollectionView registerNib:[UINib nibWithNibName:@"photoCell" bundle:nil] forCellWithReuseIdentifier:@"photoViewCell"];
//    UICollectionViewFlowLayout *flow = [[UICollectionViewFlowLayout alloc] init];
//    flow.scrollDirection = UICollectionViewScrollDirectionHorizontal;
//    flow.minimumInteritemSpacing = 3;
//    flow.minimumLineSpacing = 3;
//    _photoCollectionView.collectionViewLayout = flow;
    
    profilePicture.layer.cornerRadius = profilePicture.frame.size.width/2;
    profilePicture.layer.masksToBounds = YES;
    
    [self setUpView];
    [self setUpThumbailImage];
    
    self.photoCollectionView.hidden = true;
    
    mainQueue = [[NSOperationQueue alloc]init];
    profileOper = [[NSBlockOperation alloc]init];
    likeOper = [[NSBlockOperation alloc]init];
}

-(void)viewWillAppear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChangedForFullscreenMedia:) name:UIDeviceOrientationDidChangeNotification object:[UIDevice currentDevice]];
    
    [self setGuiBasedOnOrientation];
    if (_liveVideo) {
        activityImageView.image =  [UIImage animatedImageNamed:@"loader-" duration:1.0f];
        [super viewWillAppear:animated];
        [self.navigationController setNavigationBarHidden:true];
        [self changeCameraSelectionImage];
    }
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:UIDeviceOrientationDidChangeNotification];
    [[NSNotificationCenter defaultCenter] removeObserver:@"tokenExpiredInMovie"];
    [self hideProgressBar];
    LoggerStream(1, @"viewWillDisappear %@", self);
}

- (void) orientationChangedForFullscreenMedia:(NSNotification *)note
{
    [self setGuiBasedOnOrientation];
}

-(int) getFullscreenMediaOrientation
{
    UIDevice *device = [UIDevice currentDevice];
    switch(device.orientation)
    {
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationPortraitUpsideDown:
            orientationFlagForFullScreenMediaFlag = 1;
            break;
        case UIDeviceOrientationLandscapeLeft:
            orientationFlagForFullScreenMediaFlag = 2;
            break;
        case UIDeviceOrientationLandscapeRight:
            orientationFlagForFullScreenMediaFlag = 3;
            break;
        default:
            orientationFlagForFullScreenMediaFlag = 1;
            break;
    }
    return orientationFlagForFullScreenMediaFlag;
}


#pragma mark : Methods to check ping server to check Wifi Connected
-(void)timerToCheckWifiConnected
{
    [self hideStatusMessage];
    if (alertViewTemp.isVisible) {
        [alertViewTemp dismissWithClickedButtonIndex:0 animated:false];
    }
    [self restartDecoder];
}

#pragma mark : Restart viewfinder

-(void)restartDecoder
{
//    noDataFound.hidden = true;
    if (alertViewTemp.isVisible) {
        [alertViewTemp dismissWithClickedButtonIndex:0 animated:false];
    }
    _interrupted = false;
    self.playing = NO;
    [self showProgressBar];
    [self startDecoder];
}

-(void)reInitialiseDecoder
{
    [self showProgressBar];
    dispatch_after (dispatch_time (DISPATCH_TIME_NOW, (int64_t) (3 * NSEC_PER_SEC)), dispatch_get_main_queue (), ^ {
        [self restartDecoder];
    });
}

#pragma mark : AnimatedActivityImageView

-(void)showProgressBar
{
    activityImageView.image =  [UIImage animatedImageNamed:@"loader-" duration:1.0f];
    activityImageView.hidden = false;
    [_activityIndicatorView startAnimating];
    _activityIndicatorView.hidden = false;
    noDataFound.hidden = false;
}

-(void)hideProgressBar
{
    activityImageView.hidden = true;
    [_activityIndicatorView stopAnimating];
    _activityIndicatorView.hidden = true;
    noDataFound.hidden = true;
}

#pragma mark : Customize View

-(void)setUpThumbailImage
{
    IPhoneCameraViewController *iphoneCameraViewController = [[IPhoneCameraViewController alloc]init];
    [iphoneCameraViewController deleteIphoneCameraSnapShots];
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    if([snapShotsDict count] > 0){
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
    if(_liveVideo == false){
        [self setUpInitialGLView];
    }
    [self addApplicationObservers];
    [self setUpPresentViewAndRestorePlay];
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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(addHeartPushNotification:)
                                                 name:@"pushNotificationLike"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(loadInitialView)
                                                 name:@"tokenExpiredInMovie"
                                               object:nil];
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
    if (curReach == self.wifiReachability && curReach.currentReachabilityStatus == ReachableViaWiFi)
    {
        if (_liveVideo) {
            [self restartDecoder];
        }
    }
}

- (void) addHeartPushNotification:(NSNotification *) notification
{
    [self addHeart];
}

-(void)setUpInitialGLView
{
    [topView setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:0.4]];
    heartView.hidden = true;
    [self updateGlViewDefaultValues];
    
}

-(void)setUpGlViewForLive
{
    videoProgressBar.hidden = true;
    progressLabel.hidden = true;
    closeButton.hidden = true;
    progressLabel.text = @" ";
    scrollViewZoom.alpha = 1.0;
    bottomView.hidden = false;
    noDataFound.text = @"Trying to connect camera";
    noDataFound.hidden = false;
    liveView.hidden = false;
    numberOfSharedChannels.hidden = false;
    cameraSelectionButton.hidden = false;
}

-(void)setUpGlViewForPlayBack
{
    videoProgressBar.hidden = true;
    progressLabel.hidden = true;
    progressLabel.text = @" ";
    closeButton.hidden = true;
    scrollViewZoom.alpha = 1.0;
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
    videoProgressBar.hidden = true;
    progressLabel.hidden = true;
    imageVideoView.hidden = true;
    progressLabel.text = @" ";
    scrollViewZoom.alpha = 1.0;
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
        if(_liveVideo){
            [self reInitialiseDecoder];
        }
    }
    if([mediaTypeSelected isEqual:@"video"]){
        NSURL *parentPath = [[FileManagerViewController sharedInstance] getParentDirectoryPath];
        NSString *parentPathStr = [parentPath absoluteString];
        NSString *mediaPath = [NSString stringWithFormat:@"/%@video.mov",mediaDetailId];
        NSString *savingPath = [parentPathStr stringByAppendingString:mediaPath];
        BOOL fileExistFlag = [[FileManagerViewController sharedInstance] fileExistWithMediaPath:savingPath];
        
        if(fileExistFlag == false){
            videoProgressBar.hidden = true;
            progressLabel.hidden = true;
            progressLabel.text = @" ";
            scrollViewZoom.alpha = 1.0;
            NSURL *url = [self convertStringToUrl:mediaUrlForReplay];
            [self downloadVideo:url];
        }
        else{
            [playIconView removeFromSuperview];
            playIconView = [[UIImageView alloc]init];
            playIconView.image = [UIImage imageNamed:@"Circled Play"];
            CGFloat width = [UIScreen mainScreen].bounds.size.width;
            CGFloat height = [UIScreen mainScreen].bounds.size.height;
            playIconView.frame = CGRectMake(width/2 - 20, height/2 - 20, 40, 40);
            [glView addSubview:playIconView];
            [glView bringSubviewToFront:playIconView];
            
            UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapDetected)];
            singleTap.numberOfTapsRequired = 1;
            [playIconView setUserInteractionEnabled:YES];
            [playIconView addGestureRecognizer:singleTap];
        }
    }
    else if([mediaTypeSelected isEqual:@"live"]){
        if(_liveVideo == false){
            if(self.playing){
                [self restorePlay];
            }
        }
    }
}

-(void)applicationDidEnterBackground: (NSNotification *)notification
{
    [playIconView removeFromSuperview];
    if([mediaTypeSelected  isEqual: @"video"]){
        [self checkVideoStatus];
        [_moviePlayer.view removeFromSuperview];
        _moviePlayer = nil;
        [downloadTask cancel];
        downloadTask = nil;
        videoProgressBar.hidden = true;
        videoProgressBar.progress = 0.0;
        progressLabel.hidden = true;
        progressLabel.text = @"";
        scrollViewZoom.alpha = 1.0;
    }
    
    if([mediaTypeSelected  isEqual: @"live"])
    {
        
    }
    else{
        _backGround =  true;
        [self close];
    }
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

-(void) checkToCloseViewWhileMediaDelete : (NSString *)mediaId
{
    if(mediaId == mediaDetailId)
    {
        if(downloadTask.state == 0)
        {
            [downloadTask cancel];
            
        }
        [_moviePlayer stop];
        _moviePlayer = nil;
        [self removeOverlay];
        [self dismissViewControllerAnimated:true
                                 completion:^{
                                     
                                 }];
    }
    
}
-(void) cleanMyDayComplete :(NSString *) chanel
{
    if([channelIdSelected isEqualToString:chanel])
    {
        if(downloadTask.state == 0)
        {
            [downloadTask cancel];
            
        }
        [_moviePlayer stop];
        _moviePlayer = nil;
        [self dismissViewControllerAnimated:true
                                 completion:^{
                                     
                                 }];
    }
}
-(void) checkToCloseWhileMyDayCleanUp :(NSString *) channelIdShare
{
    if([channelIdSelected isEqualToString: channelIdShare] )
    {
        if(downloadTask.state == 0)
        {
            [downloadTask cancel];
            
        }
        [_moviePlayer stop];
        _moviePlayer = nil;
        [self removeOverlay];
        [self dismissViewControllerAnimated:true
                                 completion:^{
                                     
                                 }];
    }
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
        }
    }
}

-(void)handleDecoderError:(NSError *)error
{
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
    if (_snapCamMode == SnapCamSelectionModeLiveStream ){
        [self showNoDataFoundText];
        if(_liveVideo == true)
        {
            noDataFound.text = @"Could not connect, Tap To refresh connecton...";
        }
        else{
            noDataFound.text = @"Unable to fetch stream!";
        }
    }
}

-(void)showNoDataFoundText
{
    noDataFound.hidden = false;
    _activityIndicatorView.hidden = true;
}

-(void)showMessageForNoStreamOrLiveDataFound
{
    if (_snapCamMode == SnapCamSelectionModeLiveStream ){
        [self showNoDataFoundText];
        if(_liveVideo == true)
        {
            noDataFound.text = @"Could not connect to camera,Tap To refresh connecton...";
        }
        else{
            noDataFound.text = @"Unable to fetch stream!";
        }
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
-(void) mediaDeletedErrorMessage
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Deleted"
                                                        message:@"shared media deleted"
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Ok", nil)
                                              otherButtonTitles:nil];
    alertView.tag = 105;
    [alertView show];
}
-(NSString*)getErrorMessage:(NSError *) error
{
    if ([error.description containsString:@"kxmovie"]) {
        return @"Unable to fetch stream";
    }
    else
    {
        return @"Live stream Interrupted";
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
        case 105 :
            if (buttonIndex == 1)
            {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"ShowAlert" object:@"1"];
            }
            else if (buttonIndex == 0)
            {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"ShowAlert" object:@"0"];
                
                return;
            }
            
        default:
            break;
    }
}

#pragma mark : Play
- (void) restorePlay
{
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
                                break; // silence and exit
                            }
                            
                            [_audioFrames removeObjectAtIndex:0];
                            
                            if (delta > 0.1 && count > 1) {
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
            __strong MovieViewController *strongSelf = weakSelf;
            if (!strongSelf.playing)
            {
                return;
            }
        }
        
        BOOL good = YES;
        while (good) {
            
            good = NO;
            @autoreleasepool {
                
                __strong KxMovieDecoder *decoder = weakDecoder;
                
                if (decoder && (decoder.validVideo || decoder.validAudio)) {
                    NSArray *frames = [decoder decodeFrames:duration];
                    if (frames.count) {
                        
                        __strong MovieViewController *strongSelf = weakSelf;
                        if (strongSelf)
                        {
                            good = [strongSelf addFrames:frames];
                        }
                    }
                    else{
                    }
                }
            }
        }
        {
            __strong MovieViewController *strongSelf = weakSelf;
            if (strongSelf) strongSelf.decoding = NO;
        }
    });
}

- (void) tick
{
    if (_buffered && ((_bufferedDuration > _minBufferedDuration) || _decoder.isEOF)) {
        
        _tickCorrectionTime = 0;
        _buffered = NO;
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
                NSError * error = [NSError errorWithDomain:@"No frames found!,Please try again" code:-57 userInfo:nil];
                [self showErrorMessage:error];
                return;
                
            }
            if (_minBufferedDuration > 0 && !_buffered) {
                
                _buffered = YES;
                [_activityIndicatorView startAnimating];
            }
        }
        
        if (!leftFrames ||
            !(_bufferedDuration > _minBufferedDuration)) {
            
            [self asyncDecodeFrames];
        }
        
        const NSTimeInterval correction = [self tickCorrection];
        const NSTimeInterval time = MAX(interval + correction, 0.01);
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self tick];
        });
    }
    
    if ((_tickCounter++ % 3) == 0) {
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


-(void) closeView
{
    if(downloadTask.state == 0)
    {
        [downloadTask cancel];
        
    }
    [_moviePlayer stop];
    _moviePlayer = nil;
    [self dismissViewControllerAnimated:true
                             completion:^{
                                 
                             }];
}
#pragma mark : Button Actions

- (IBAction)didTapCloseButton:(id)sender {
    if(downloadTask.state == 0)
    {
        [downloadTask cancel];
        
    }
    [_moviePlayer stop];
    _moviePlayer = nil;
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
    NSUserDefaults *standardDefaults = [[NSUserDefaults alloc]init];
    likeFlag = [standardDefaults valueForKey:@"likeCountFlag"];
    if(likeTapFlag == false){
        likeTapFlag = true;
        NSString *type;
        if([mediaTypeSelected  isEqual: @"live"])
        {
            type = @"liveStreamId";
        }
        else{
            type = @"mediaDetailId";
        }
        SetUpView *setUpObj = [[SetUpView alloc]init];
        [setUpObj setMediaLikesWithUserName:userId accessToken:accessToken notifType:notificationType mediaDetailId:mediaDetailId channelId:channelIdSelected objects:obj1 typeMedia:type];
    }
}

-(void) successFromSetUpView:(NSString *) count
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSUserDefaults *standardDefaults = [[NSUserDefaults alloc]init];
        [standardDefaults setValue:count forKey:@"likeCountFlag"];
        [likeCount setText:count];
        likeFlag = count;
    });
}
-(void) successFromSetUpViewProfileImage :(UIImage *)profImage
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [activityIndicatorProfile removeFromSuperview];
        profilePicture.backgroundColor = [UIColor clearColor];
        profilePicture.alpha = 1.0;
        profilePicture.image =profImage;
    });
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
    return _interrupted;
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

#pragma mark : Collection View Delegates

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
//    if (screenNumber == 1 || screenNumber == 2)
//    {
//        if ([streamORChannelDict count] > 0)
//        {
//            return [streamORChannelDict count];
//        }
//        else{
//            return 0;
//        }
//    }
//    else if(screenNumber == 0){
//        if (totalCount > 0)
//        {
//            return totalCount;
//        }
//        else{
//            return 0;
//        }
//    }
    return 0;
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *cellIdentifier = @"photoViewCell";
//    NSString * thumbImageKey = @"thumbImage";
    photoViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath]  ;
//    
//    cell.layer.shouldRasterize = true;
//    cell.layer.rasterizationScale = [[UIScreen mainScreen]scale];
//    
//    if(indexPath.row == indexForSwipe)
//    {
//        cell.layer.borderWidth = 3;
//        cell.layer.borderColor = [UIColor colorWithRed: 44.0/255.0 green:214.0/255.0 blue:229.0/255.0 alpha:0.7].CGColor;
//    }
//    else{
//        cell.layer.borderWidth = 0;
//        cell.layer.borderColor =[UIColor clearColor].CGColor;
//    }
//    if (screenNumber == 1 || screenNumber == 2)
//    {
//        cell.thumbImageView.image = streamORChannelDict[indexPath.row][thumbImageKey];
//        if([streamORChannelDict[indexPath.row][@"mediaType"] isEqualToString:@"video"])
//        {
//            cell.videoIconImgView.hidden = false;
//        }
//        else{
//            cell.videoIconImgView.hidden = true;
//        }
//    }
//    else if (screenNumber == 0){
//        cell.thumbImageView.image = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelIdSelected][indexPath.row][thumbImageKey];
//        if([GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelIdSelected][indexPath.row][@"gcs_object_type"] isEqualToString:@"video"])
//        {
//            cell.videoIconImgView.hidden = false;
//        }
//        else{
//            cell.videoIconImgView.hidden = true;
//        }
//    }
//    
    return cell;
}

//- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
//{
//    return CGSizeMake(50, 46);
//}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
//    
//    scrollViewZoom.zoomScale = 1.0;
//    scrollViewZoom.minimumZoomScale = 1.0;
//    scrollViewZoom.maximumZoomScale = 30.0;
//    if(indexForSwipe != (int)indexPath.row){
//        [self checkVideoStatus];
//        orgIndex = -11;
//        tapFromDidSelectFlag = false;
//        indexForSwipe = (int)indexPath.row;
//        [self removeOverlay];
//        [self showOverlay1];
//        [self setSelectionForPhotoView];
//        dispatch_async(dispatch_get_main_queue(),^{
//            progressLabel.hidden = true;
//            progressLabel.text = @" ";
//            videoProgressBar.hidden = true;
//            scrollViewZoom.alpha = 1.0;
//            [self.photoCollectionView reloadData];
//        });
//    }
}
//-(void) setSelectionForPhotoView
//{
//    tapFromDidSelectFlag = true;
//    UIImage *VideoImageUrlChk;
//    
//    if(screenNumber == 0)
//    {
//        mediaTypeChk = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelIdSelected][indexForSwipe][@"gcs_object_type"];
//        mediaIdChk = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelIdSelected][indexForSwipe][@"media_detail_id"];
//        NSString *createdTime = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelIdSelected][indexForSwipe][@"created_time_stamp"];
//        timeDiffChk = [[FileManagerViewController sharedInstance] getTimeDifferenceWithDateStr:createdTime];
//        likeCountStrChk = @"0";
//        notifTypeChk = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelIdSelected][indexForSwipe][@"notification_type"];
//        VideoImageUrlChk = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelIdSelected][indexForSwipe][@"thumbImage"];
//        videoDurationChk = GlobalChannelToImageMapping.sharedInstance.GlobalChannelImageDict[channelIdSelected][indexForSwipe][@"video_duration"];
//        [self setGUIChanges:mediaTypeChk mediaId:mediaIdChk timeDiff:timeDiffChk likeCountStr:likeCountStrChk notifType:notifTypeChk VideoImageUrl:VideoImageUrlChk videoDuration:videoDurationChk];
//    }
//    else
//    {
//        mediaTypeChk = streamORChannelDict[indexForSwipe][@"mediaType"];
//        mediaIdChk = streamORChannelDict[indexForSwipe][@"mediaId"];
//        NSString *createdTime = streamORChannelDict[indexForSwipe][@"createdTime"];
//        timeDiffChk = [[FileManagerViewController sharedInstance] getTimeDifferenceWithDateStr:createdTime];
//        likeCountStrChk = @"";
//        notifTypeChk = streamORChannelDict[indexForSwipe][@"notification"];
//        VideoImageUrlChk = streamORChannelDict[indexForSwipe][@"mediaUrl"];
//        videoDurationChk = streamORChannelDict[indexForSwipe][@"video_duration"];
//        SetUpView *setUpObj = [[SetUpView alloc]init];
//        if(screenNumber == 1){
//            if (screenNumber == 1)
//            {
//                [activityIndicatorProfile removeFromSuperview];
//                activityIndicatorProfile = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
//                activityIndicatorProfile.alpha = 1.0;
//                [heartView addSubview:activityIndicatorProfile];
//                activityIndicatorProfile.frame =  CGRectMake(profilePicture.frame.origin.x + 5 , profilePicture.frame.origin.y + 7, 30.0,30.0);
//                profilePicture.alpha = 0.2;
//                activityIndicatorProfile.color = [UIColor blueColor];
//                [activityIndicatorProfile stopAnimating];
//                [activityIndicatorProfile startAnimating];//to start animating
//            }
//            
//            [profileOper cancel];
//            profileOper = [NSBlockOperation blockOperationWithBlock:^{
//                [setUpObj getProfileImageSelectedIndexWithUserIdKey:[NSString stringWithFormat:@"%@",streamORChannelDict[indexForSwipe][@"user_name"]] objects:obj1 operObj:profileOper];
//            }];
//            [mainQueue addOperation:profileOper];
//            channelName.text = streamORChannelDict[indexForSwipe][@"channel_name"];
//            userName.text = [NSString stringWithFormat:@"@%@",streamORChannelDict[indexForSwipe][@"user_name"]];
//            channelIdSelected = streamORChannelDict[indexForSwipe][@"ch_detail_id"];
//        }
//        if(screenNumber == 1 || screenNumber == 2){
//            likeTapFlag = false;
//            [likeOper cancel];
//            likeOper = [NSBlockOperation blockOperationWithBlock:^{
//                [setUpObj getLikeCountWithMediaType:mediaTypeChk mediaId:mediaIdChk Objects:obj1 operObjs:likeOper];
//            }];
//            [mainQueue addOperation:likeOper];
//        }
//        
//        [self setGUIChanges:mediaTypeChk mediaId:mediaIdChk timeDiff:timeDiffChk likeCountStr:likeCountStrChk notifType:notifTypeChk VideoImageUrl:VideoImageUrlChk videoDuration:videoDurationChk];
//    }

//}

@end
