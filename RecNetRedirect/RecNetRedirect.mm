#import "RecNetRedirect.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <os/log.h>

static os_log_t RRLog(void) {
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        log = os_log_create("net.recflare.RecNetRedirect", "loader");
    });
    return log;
}

static BOOL RRConfigEnabled(void) {
    static BOOL enabled = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *path = [[[NSBundle mainBundle] bundlePath]
                          stringByAppendingPathComponent:@"Data/RecNetRedirect.json"];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (!data) {
            os_log_error(RRLog(), "FAILED: config not found at %{public}@", path);
            return;
        }
        NSError *error = nil;
        id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (![object isKindOfClass:[NSDictionary class]]) {
            os_log_error(RRLog(), "FAILED: invalid JSON config: %{public}@", error);
            return;
        }
        enabled = [object[@"enabled"] boolValue];
        os_log(RRLog(), "Config loaded; enabled=%{public}d", enabled);
    });
    return enabled;
}

static NSURLRequest *RRRewriteRequest(NSURLRequest *request) {
    if (!request || !RRConfigEnabled()) return request;

    NSURL *url = request.URL;
    if (!url || ![url.scheme.lowercaseString isEqualToString:@"https"]) return request;
    if (![url.host.lowercaseString isEqualToString:@"ns.rec.net"]) return request;

    NSURLComponents *components = [NSURLComponents componentsWithURL:url
                                             resolvingAgainstBaseURL:NO];
    if (!components) return request;

    components.host = @"ns.recflare.net";
    NSURL *newURL = components.URL;
    if (!newURL) {
        os_log_error(RRLog(), "FAILED: could not construct redirected URL");
        return request;
    }

    NSMutableURLRequest *copy = [request mutableCopy];
    copy.URL = newURL;
    os_log(RRLog(), "Redirect applied: %{public}@ -> %{public}@",
           url.absoluteString, newURL.absoluteString);
    return copy;
}

@interface NSURLSession (RecNetRedirectHook)
- (NSURLSessionDataTask *)rr_dataTaskWithRequest:(NSURLRequest *)request
                               completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler;
- (NSURLSessionUploadTask *)rr_uploadTaskWithRequest:(NSURLRequest *)request
                                            fromData:(NSData *)body
                                   completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler;
- (NSURLSessionDownloadTask *)rr_downloadTaskWithRequest:(NSURLRequest *)request
                                        completionHandler:(void (^)(NSURL *, NSURLResponse *, NSError *))completionHandler;
@end

static void RRExchange(Class cls, SEL original, SEL replacement) {
    Method a = class_getInstanceMethod(cls, original);
    Method b = class_getInstanceMethod(cls, replacement);
    if (!a || !b) {
        os_log_error(RRLog(), "FAILED: NSURLSession selector unavailable: %{public}s",
                     sel_getName(original));
        return;
    }
    method_exchangeImplementations(a, b);
}

@implementation NSURLSession (RecNetRedirectHook)

- (NSURLSessionDataTask *)rr_dataTaskWithRequest:(NSURLRequest *)request
                               completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    return [self rr_dataTaskWithRequest:RRRewriteRequest(request)
                      completionHandler:completionHandler];
}

- (NSURLSessionUploadTask *)rr_uploadTaskWithRequest:(NSURLRequest *)request
                                            fromData:(NSData *)body
                                   completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    return [self rr_uploadTaskWithRequest:RRRewriteRequest(request)
                                 fromData:body
                        completionHandler:completionHandler];
}

- (NSURLSessionDownloadTask *)rr_downloadTaskWithRequest:(NSURLRequest *)request
                                        completionHandler:(void (^)(NSURL *, NSURLResponse *, NSError *))completionHandler {
    return [self rr_downloadTaskWithRequest:RRRewriteRequest(request)
                          completionHandler:completionHandler];
}

@end

void RecNetRedirectInstall(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        os_log(RRLog(), "CHECKING: installing NSURLSession request hooks");
        RRExchange([NSURLSession class],
                   @selector(dataTaskWithRequest:completionHandler:),
                   @selector(rr_dataTaskWithRequest:completionHandler:));
        RRExchange([NSURLSession class],
                   @selector(uploadTaskWithRequest:fromData:completionHandler:),
                   @selector(rr_uploadTaskWithRequest:fromData:completionHandler:));
        RRExchange([NSURLSession class],
                   @selector(downloadTaskWithRequest:completionHandler:),
                   @selector(rr_downloadTaskWithRequest:completionHandler:));
        os_log(RRLog(), "Hook installation attempted; this does not prove Rec Room uses NSURLSession");
    });
}

__attribute__((constructor))
static void RecNetRedirectFrameworkEntry(void) {
    @autoreleasepool {
        RecNetRedirectInstall();
    }
}
