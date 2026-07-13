//
// Immutable Objective-C event/config values crossing the SIPCore bridge.
// No PJSIP types here; the .mm implementation translates.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Registration phase as reported by the stack.
typedef NS_ENUM(NSInteger, MSPRegState) {
    MSPRegStateUnregistered = 0,
    MSPRegStateRegistering = 1,
    MSPRegStateRegistered = 2,
    MSPRegStateFailed = 3,
};

/// Raw call phase (mirrors PJSIP invite states; Swift maps to Domain
/// CallState using direction + the documented state machine).
typedef NS_ENUM(NSInteger, MSPCallPhase) {
    MSPCallPhaseCalling = 0,      // outgoing INVITE sent
    MSPCallPhaseIncoming = 1,     // incoming INVITE received
    MSPCallPhaseEarly = 2,        // 18x progress
    MSPCallPhaseConnecting = 3,   // 200 exchanged, awaiting ACK
    MSPCallPhaseConfirmed = 4,    // established
    MSPCallPhaseDisconnected = 5, // terminal
};

typedef NS_ENUM(NSInteger, MSPMediaStatus) {
    MSPMediaStatusNone = 0,
    MSPMediaStatusActive = 1,
    MSPMediaStatusLocalHold = 2,
    MSPMediaStatusRemoteHold = 3,
    MSPMediaStatusError = 4,
};

/// Whether the early phase carries media (183 + SDP) — outgoing only.
typedef NS_ENUM(NSInteger, MSPEarlyMediaFlag) {
    MSPEarlyMediaFlagNone = 0,
    MSPEarlyMediaFlagRinging = 1,    // 180
    MSPEarlyMediaFlagEarlyMedia = 2, // 183 with SDP
};

@interface MSPRegistrationEvent : NSObject
@property(nonatomic, readonly) MSPRegState state;
/// Last SIP status code (0 if none).
@property(nonatomic, readonly) NSInteger sipCode;
/// Registration expiry in seconds (<= 0 if unknown/not registered).
@property(nonatomic, readonly) NSInteger expiresSeconds;
/// Reason phrase; safe for logs (no credentials).
@property(nonatomic, readonly, copy) NSString *reason;
- (instancetype)initWithState:(MSPRegState)state
                      sipCode:(NSInteger)sipCode
               expiresSeconds:(NSInteger)expiresSeconds
                       reason:(NSString *)reason NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface MSPCallEvent : NSObject
@property(nonatomic, readonly) NSInteger callId;
@property(nonatomic, readonly) BOOL isIncoming;
@property(nonatomic, readonly) MSPCallPhase phase;
@property(nonatomic, readonly) MSPEarlyMediaFlag earlyFlag;
@property(nonatomic, readonly) MSPMediaStatus mediaStatus;
/// Last SIP status code seen on the call (0 if none yet).
@property(nonatomic, readonly) NSInteger sipCode;
@property(nonatomic, readonly, copy) NSString *remoteUri;
@property(nonatomic, readonly, copy) NSString *remoteDisplayName;
/// Reason phrase for terminal states; safe for logs.
@property(nonatomic, readonly, copy) NSString *reason;
- (instancetype)initWithCallId:(NSInteger)callId
                    isIncoming:(BOOL)isIncoming
                         phase:(MSPCallPhase)phase
                     earlyFlag:(MSPEarlyMediaFlag)earlyFlag
                   mediaStatus:(MSPMediaStatus)mediaStatus
                       sipCode:(NSInteger)sipCode
                     remoteUri:(NSString *)remoteUri
             remoteDisplayName:(NSString *)remoteDisplayName
                        reason:(NSString *)reason NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

typedef NS_ENUM(NSInteger, MSPSRTPPolicy) {
    MSPSRTPPolicyDisabled = 0,
    MSPSRTPPolicyOptional = 1,
    MSPSRTPPolicyMandatory = 2,
};

/// Transient account configuration handed to the bridge. The password is
/// passed through to the SIP stack's credential store and is never logged,
/// persisted, or echoed back by the bridge (CLAUDE.md security rules).
@interface MSPAccountConfig : NSObject
@property(nonatomic, copy) NSString *aorUri;       // sip:user@domain
@property(nonatomic, copy) NSString *registrarUri; // sip:domain[;transport=…]
/// Optional outbound proxy URI (routes ALL account requests); empty = none.
@property(nonatomic, copy) NSString *proxyUri;
@property(nonatomic, copy) NSString *username;
@property(nonatomic, copy) NSString *authID;       // empty = username
@property(nonatomic, copy) NSString *password;
@property(nonatomic) NSInteger regIntervalSeconds; // 0 = stack default
@property(nonatomic) MSPSRTPPolicy srtpPolicy;
/// Per-account TLS trust override (default NO = verify). Changing this
/// recreates the TLS transport; only valid while no calls are active.
@property(nonatomic) BOOL tlsVerifyDisabled;
@end

NS_ASSUME_NONNULL_END
