// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
#import "FlutterPDFView.h"

@implementation FLTPDFViewFactory {
    NSObject<FlutterBinaryMessenger>* _messenger;
}

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger>*)messenger {
    self = [super init];
    if (self) {
        _messenger = messenger;
    }
    return self;
}

- (NSObject<FlutterMessageCodec>*)createArgsCodec {
    return [FlutterStandardMessageCodec sharedInstance];
}

- (NSObject<FlutterPlatformView>*)createWithFrame:(CGRect)frame
                                   viewIdentifier:(int64_t)viewId
                                        arguments:(id _Nullable)args {
    FLTPDFViewController* pdfviewController = [[FLTPDFViewController alloc] initWithFrame:frame
                                                                           viewIdentifier:viewId
                                                                                arguments:args
                                                                          binaryMessenger:_messenger];
    return pdfviewController;
}

@end

@implementation FLTPDFViewController {
    PDFView* _pdfView;
    int64_t _viewId;
    FlutterMethodChannel* _channel;
    NSNumber* _pageCount;
    NSNumber* _currentPage;
}

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
              binaryMessenger:(NSObject<FlutterBinaryMessenger>*)messenger {
    if ([super init]) {
        _viewId = viewId;
        
        NSString* channelName = [NSString stringWithFormat:@"plugins.endigo.io/pdfview_%lld", viewId];
        _channel = [FlutterMethodChannel methodChannelWithName:channelName binaryMessenger:messenger];
        
        _pdfView = [[PDFView alloc] initWithFrame:frame];
        
        __weak __typeof__(self) weakSelf = self;
        [_channel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
            [weakSelf onMethodCall:call result:result];
        }];
//        NSDictionary<NSString*, id>* settings = args[@"settings"];
        
        BOOL autoSpacing = [args[@"autoSpacing"] boolValue];
        _pdfView.autoScales = autoSpacing;
        _pdfView.minScaleFactor = [_pdfView scaleFactorForSizeToFit];
        _pdfView.maxScaleFactor = 4.0;
        [_pdfView usePageViewController:autoSpacing withViewOptions:nil];
        _pdfView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
        
        NSString* filePath = args[@"filePath"];
        if ([filePath isKindOfClass:[NSString class]]) {
            NSURL * sourcePDFUrl = [NSURL fileURLWithPath:filePath];
            PDFDocument * document = [[PDFDocument alloc] initWithURL: sourcePDFUrl];
            
            _pdfView.document = document;

            _pdfView.displayMode = kPDFDisplaySinglePageContinuous;
        }
        
        NSString* password = args[@"password"];
        if ([password isKindOfClass:[NSString class]] && [_pdfView.document isEncrypted]) {
            [_pdfView.document unlockWithPassword:password];
        }
        
        BOOL swipeHorizontal = [args[@"swipeHorizontal"] boolValue];
        
        if (swipeHorizontal) {
            _pdfView.displayDirection = kPDFDisplayDirectionHorizontal;
        } else {
            _pdfView.displayDirection = kPDFDisplayDirectionVertical;
        }
        
        _pdfView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePageChanged:) name:PDFViewPageChangedNotification object:_pdfView];
        
    }
    return self;
}

- (UIView*)view {
    return _pdfView;
}

- (void)onMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([[call method] isEqualToString:@"pageCount"]) {
        [self getPageCount:call result:result];
    } else if ([[call method] isEqualToString:@"currentPage"]) {
        [self getCurrentPage:call result:result];
    } else if ([[call method] isEqualToString:@"setPage"]) {
        [self setPage:call result:result];
    } else if ([[call method] isEqualToString:@"updateSettings"]) {
        [self onUpdateSettings:call result:result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)getPageCount:(FlutterMethodCall*)call result:(FlutterResult)result {
    _pageCount = [NSNumber numberWithUnsignedLong: [[_pdfView document] pageCount]];
    result(_pageCount);
}

- (void)getCurrentPage:(FlutterMethodCall*)call result:(FlutterResult)result {
    _currentPage = [NSNumber numberWithUnsignedLong: [_pdfView.document indexForPage: _pdfView.currentPage]];
    result(_currentPage);
}

- (void)setPage:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSDictionary<NSString*, NSNumber*>* arguments = [call arguments];
    NSNumber* page = arguments[@"page"];
    
    [_pdfView goToPage: [_pdfView.document pageAtIndex: page.unsignedLongValue ]];
    result(_currentPage);
}

- (void)onUpdateSettings:(FlutterMethodCall*)call result:(FlutterResult)result {
    result(nil);
}

-(void)handlePageChanged:(NSNotification*)notification {
    [_channel invokeMethod:@"onPageChanged" arguments:@{@"page" : [NSNumber numberWithUnsignedLong: [_pdfView.document indexForPage: _pdfView.currentPage]]}];
}

@end
