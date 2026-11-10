#import "GeneratedPluginRegistrant.h"
#import <Flutter/Flutter.h>

// FlutterEngine's initializer is declared nonnull but can return nil, for
// example when iPadOS rejects a standalone Debug launch. Check it in Obj-C.
static inline FlutterEngine * _Nullable StartRunnerFlutterEngine(void) {
  FlutterEngine *engine = [[FlutterEngine alloc] initWithName:@"art_road_engine"];
  if (engine == nil || ![engine run]) {
    NSLog(@"Runner: Flutter engine could not start.");
    return nil;
  }
  return engine;
}
