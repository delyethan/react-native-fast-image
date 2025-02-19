#import "FFFastImagePreloaderManager.h"
#import "FFFastImagePreloader.h"
#import "FFFastImageSource.h"

@implementation FFFastImagePreloaderManager
{
    bool _hasListeners;
    NSMutableDictionary* _preloaders;
}

RCT_EXPORT_MODULE(FastImagePreloaderManager);

- (dispatch_queue_t)methodQueue
{
    return dispatch_queue_create("com.dylanvann.fastimage.FastImagePreloaderManager", DISPATCH_QUEUE_SERIAL);
}

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

-(instancetype) init {
    if (self = [super init]) {
        _preloaders = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[@"fffastimage-progress", @"fffastimage-complete"];
}

- (void) imagePrefetcher:(nonnull SDWebImagePrefetcher *)imagePrefetcher
 didFinishWithTotalCount:(NSUInteger)totalCount
            skippedCount:(NSUInteger)skippedCount
{
    NSNumber* id = ((FFFastImagePreloader*) imagePrefetcher).id;
    [_preloaders removeObjectForKey:id];
    [self sendEventWithName:@"fffastimage-complete"
                       body:@{ @"id": id, @"finished": [NSNumber numberWithLong:totalCount], @"skipped": [NSNumber numberWithLong:skippedCount]}
    ];
}

- (void) imagePrefetcher:(nonnull SDWebImagePrefetcher *)imagePrefetcher
          didPrefetchURL:(nullable NSURL *)imageURL
           finishedCount:(NSUInteger)finishedCount
              totalCount:(NSUInteger)totalCount
{
    NSNumber* id = ((FFFastImagePreloader*) imagePrefetcher).id;
    BOOL isCached = [self isURLCached:imageURL];
    [self sendEventWithName:@"fffastimage-progress"
                       body:@{
                              @"id": id,
                              @"finished": [NSNumber numberWithLong:finishedCount],
                              @"total": [NSNumber numberWithLong:totalCount],
                              @"url": isCached ? imageURL.absoluteString : [NSNull null]
                              }];
}

RCT_EXPORT_METHOD(createPreloader:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    FFFastImagePreloader* preloader = [[FFFastImagePreloader alloc] init];
    preloader.delegate = self;
    _preloaders[preloader.id] = preloader;
    resolve(preloader.id);
}

RCT_EXPORT_METHOD(preload:(nonnull NSNumber*)preloaderId sources:(nonnull NSArray<FFFastImageSource *> *)sources) {
    NSMutableArray *urls = [NSMutableArray arrayWithCapacity:sources.count];
    
    [sources enumerateObjectsUsingBlock:^(FFFastImageSource * _Nonnull source, NSUInteger idx, BOOL * _Nonnull stop) {
        [source.headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString* header, BOOL *stop) {
            [[SDWebImageDownloader sharedDownloader] setValue:header forHTTPHeaderField:key];
        }];
        [urls setObject:source.url atIndexedSubscript:idx];
    }];
    
    FFFastImagePreloader* preloader = _preloaders[preloaderId];
    [preloader prefetchURLs:urls];
}

RCT_EXPORT_METHOD(getCachePath:(nonnull FFFastImageSource *)source
                  withResolver:(RCTPromiseResolveBlock)resolve
                   andRejecter:(RCTPromiseRejectBlock)reject)
{
    SDWebImageManager *imageManager = [SDWebImageManager sharedManager];
    NSString *key = [imageManager cacheKeyForURL:source.url];
    BOOL isCached = [[SDImageCache sharedImageCache] diskImageDataExistsWithKey:key];

    if (isCached) {
        NSString *cachePath = [[SDImageCache sharedImageCache] cachePathForKey:key];
        resolve(cachePath);
    } else {
        resolve([NSNull null]);
    }
}

# pragma mark helpers

- (BOOL) isURLCached:(NSURL *)url {
    NSString *cacheKey = [[SDWebImageManager sharedManager] cacheKeyForURL:url];
    return [[SDImageCache sharedImageCache] diskImageDataExistsWithKey:cacheKey];
}

@end
