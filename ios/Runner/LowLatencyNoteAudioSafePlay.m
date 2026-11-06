#import "LowLatencyNoteAudioSafePlay.h"

@implementation LowLatencyNoteAudioSafePlay

+ (BOOL)playNode:(AVAudioPlayerNode *)node error:(NSError **)error {
  if (node == nil) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:@"LowLatencyNoteAudio"
                                   code:1
                               userInfo:@{NSLocalizedDescriptionKey : @"node is nil"}];
    }
    return NO;
  }

  @try {
    [node play];
    return YES;
  } @catch (NSException *exception) {
    if (error != NULL) {
      NSString *reason = exception.reason ?: exception.name;
      *error = [NSError errorWithDomain:@"LowLatencyNoteAudio"
                                   code:2
                               userInfo:@{NSLocalizedDescriptionKey : reason}];
    }
    return NO;
  }
}

+ (BOOL)scheduleBuffer:(AVAudioPCMBuffer *)buffer
                onNode:(AVAudioPlayerNode *)node
     completionHandler:(void (^)(void))completionHandler
                 error:(NSError **)error {
  if (node == nil || buffer == nil) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:@"LowLatencyNoteAudio"
                                   code:3
                               userInfo:@{NSLocalizedDescriptionKey : @"node or buffer is nil"}];
    }
    return NO;
  }

  @try {
    [node scheduleBuffer:buffer atTime:nil options:0 completionHandler:completionHandler];
    return YES;
  } @catch (NSException *exception) {
    if (error != NULL) {
      NSString *reason = exception.reason ?: exception.name;
      *error = [NSError errorWithDomain:@"LowLatencyNoteAudio"
                                   code:4
                               userInfo:@{NSLocalizedDescriptionKey : reason}];
    }
    return NO;
  }
}

+ (BOOL)scheduleBuffer:(AVAudioPCMBuffer *)buffer
                onNode:(AVAudioPlayerNode *)node
     playedBackHandler:(void (^)(void))completionHandler
                 error:(NSError **)error {
  if (node == nil || buffer == nil) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:@"LowLatencyNoteAudio"
                                   code:3
                               userInfo:@{NSLocalizedDescriptionKey : @"node or buffer is nil"}];
    }
    return NO;
  }

  @try {
    [node scheduleBuffer:buffer
                  atTime:nil
                 options:0
   completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack
       completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
         if (completionHandler != nil) {
           completionHandler();
         }
       }];
    return YES;
  } @catch (NSException *exception) {
    if (error != NULL) {
      NSString *reason = exception.reason ?: exception.name;
      *error = [NSError errorWithDomain:@"LowLatencyNoteAudio"
                                   code:4
                               userInfo:@{NSLocalizedDescriptionKey : reason}];
    }
    return NO;
  }
}

+ (NSError *)errorWithCode:(NSInteger)code exception:(NSException *)exception {
  NSString *reason = exception.reason ?: exception.name ?: @"AVAudioEngine exception";
  return [NSError errorWithDomain:@"LowLatencyNoteAudio"
                             code:code
                         userInfo:@{NSLocalizedDescriptionKey : reason}];
}

+ (BOOL)attachNode:(AVAudioNode *)node
          toEngine:(AVAudioEngine *)engine
             error:(NSError **)error {
  if (node == nil || engine == nil) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:@"LowLatencyNoteAudio"
                                   code:5
                               userInfo:@{NSLocalizedDescriptionKey : @"node or engine is nil"}];
    }
    return NO;
  }
  @try {
    [engine attachNode:node];
    return YES;
  } @catch (NSException *exception) {
    if (error != NULL) {
      *error = [self errorWithCode:6 exception:exception];
    }
    return NO;
  }
}

+ (BOOL)connectNode:(AVAudioNode *)node
             toNode:(AVAudioNode *)destination
             format:(AVAudioFormat *)format
           inEngine:(AVAudioEngine *)engine
              error:(NSError **)error {
  if (node == nil || destination == nil || engine == nil) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:@"LowLatencyNoteAudio"
                                   code:7
                               userInfo:@{NSLocalizedDescriptionKey : @"node, destination or engine is nil"}];
    }
    return NO;
  }
  @try {
    [engine connect:node to:destination format:format];
    return YES;
  } @catch (NSException *exception) {
    if (error != NULL) {
      *error = [self errorWithCode:8 exception:exception];
    }
    return NO;
  }
}

+ (BOOL)prepareAndStartEngine:(AVAudioEngine *)engine
                        error:(NSError **)error {
  if (engine == nil) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:@"LowLatencyNoteAudio"
                                   code:9
                               userInfo:@{NSLocalizedDescriptionKey : @"engine is nil"}];
    }
    return NO;
  }
  @try {
    [engine prepare];
    NSError *startError = nil;
    if (![engine startAndReturnError:&startError]) {
      if (error != NULL) {
        *error = startError ?: [NSError errorWithDomain:@"LowLatencyNoteAudio"
                                                   code:10
                                               userInfo:@{NSLocalizedDescriptionKey : @"engine failed to start"}];
      }
      return NO;
    }
    return YES;
  } @catch (NSException *exception) {
    if (error != NULL) {
      *error = [self errorWithCode:11 exception:exception];
    }
    return NO;
  }
}

@end
