//
// MSPEngine — the single owner of the PJSIP runtime.
//
// Ownership & threading contract (ARCHITECTURE.md, CLAUDE.md):
// - One dedicated engine thread executes ALL PJSIP calls. Public methods
//   are asynchronous and hop onto it; none block the caller.
// - Delegate events are emitted on a private serial queue, already
//   converted to immutable MSP* values; the Swift side republishes on the
//   main actor. Never call back into MSPEngine synchronously from a
//   delegate callback.
// - Teardown order inside stop: calls → account → transports/endpoint
//   (libDestroy). After stop completes the engine can be started again.
//

#import <Foundation/Foundation.h>

#import "MSPTypes.h"

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const MSPErrorDomain;

@protocol MSPEngineDelegate <NSObject>
- (void)sipEngineRegistrationChanged:(MSPRegistrationEvent *)event;
- (void)sipEngineCallChanged:(MSPCallEvent *)event;
- (void)sipEngineIncomingCall:(MSPCallEvent *)event;
@end

@interface MSPEngine : NSObject

@property(nonatomic, weak, nullable) id<MSPEngineDelegate> delegate;

/// Starts the PJSIP runtime (endpoint + UDP/TCP/TLS transports; TLS
/// verifies against system trust unless a per-account override recreates
/// it) on the engine thread. Idempotent: starting a started engine
/// reports no error. port 0 = ephemeral local SIP port. useNullAudio
/// replaces the sound device with PJSIP's null device (integration tests
/// only — keeps media flowing without microphone/TCC involvement).
/// Contract: call stopWithCompletion: before releasing a started engine.
- (void)startWithUserAgent:(NSString *)userAgent
                      port:(NSInteger)port
              useNullAudio:(BOOL)useNullAudio
                completion:(void (^)(NSError *_Nullable error))completion;

/// Stops everything in the documented teardown order. Idempotent.
- (void)stopWithCompletion:(void (^)(void))completion;

/// Creates or replaces the single SIP account and begins registration.
- (void)configureAccount:(MSPAccountConfig *)config
              completion:(void (^)(NSError *_Nullable error))completion;

/// Unregisters and removes the account (no-op when absent).
- (void)removeAccountWithCompletion:(void (^)(void))completion;

/// Manual re-registration (no-op when no account).
- (void)refreshRegistration;

/// Network-path or wake recovery: restarts transports, re-registers, and
/// re-INVITEs active calls via PJSIP's IP-change handling. Safe to call
/// repeatedly; no-op when stopped.
- (void)handleNetworkChanged;

/// Places an outgoing call. On success the callback receives the stable
/// call id later used in MSPCallEvent.
- (void)makeCallTo:(NSString *)uri
        completion:(void (^)(NSError *_Nullable error, NSInteger callId))completion;

- (void)answerCall:(NSInteger)callId;
- (void)rejectCall:(NSInteger)callId busy:(BOOL)busy;
- (void)hangupCall:(NSInteger)callId;
- (void)setCall:(NSInteger)callId held:(BOOL)held;
- (void)setCall:(NSInteger)callId muted:(BOOL)muted;
/// RFC 4733 digits (0-9, *, #, A-D).
- (void)sendDTMF:(NSString *)digits toCall:(NSInteger)callId;

/// RTP packet counters for a call's first audio stream (media
/// verification: a 200 OK is not a working call). Reports -1/-1 when the
/// call or its stream doesn't exist.
- (void)statsForCall:(NSInteger)callId
          completion:(void (^)(NSInteger txPackets, NSInteger rxPackets))completion;

/// Audio devices as {index: NSNumber, name: NSString, input: BOOL,
/// output: BOOL} dictionaries, plus the currently selected indices
/// (-1 = system default).
- (void)audioDevicesWithCompletion:(void (^)(NSArray<NSDictionary *> *devices,
                                             NSInteger captureIndex,
                                             NSInteger playbackIndex))completion;

/// Selects audio devices (-1 = follow system default). Safe mid-call.
- (void)setCaptureDevice:(NSInteger)captureIndex
           playbackDevice:(NSInteger)playbackIndex
               completion:(void (^)(NSError *_Nullable error))completion;

/// Sanitized runtime diagnostics (versions, transport, codecs, account
/// state). Never contains credentials.
- (void)diagnosticsWithCompletion:(void (^)(NSString *info))completion;

@end

NS_ASSUME_NONNULL_END
