//
// Immutable Objective-C event/config values crossing the SIPCore bridge.
// No PJSIP types here; the .mm implementation translates.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Registration phase as reported by the stack.
typedef NS_ENUM(NSInteger, USPRegState) {
    USPRegStateUnregistered = 0,
    USPRegStateRegistering = 1,
    USPRegStateRegistered = 2,
    USPRegStateFailed = 3,
};

/// Raw call phase (mirrors PJSIP invite states; Swift maps to Domain
/// CallState using direction + the documented state machine).
typedef NS_ENUM(NSInteger, USPCallPhase) {
    USPCallPhaseCalling = 0,      // outgoing INVITE sent
    USPCallPhaseIncoming = 1,     // incoming INVITE received
    USPCallPhaseEarly = 2,        // 18x progress
    USPCallPhaseConnecting = 3,   // 200 exchanged, awaiting ACK
    USPCallPhaseConfirmed = 4,    // established
    USPCallPhaseDisconnected = 5, // terminal
};

typedef NS_ENUM(NSInteger, USPMediaStatus) {
    USPMediaStatusNone = 0,
    USPMediaStatusActive = 1,
    USPMediaStatusLocalHold = 2,
    USPMediaStatusRemoteHold = 3,
    USPMediaStatusError = 4,
};

/// Whether the early phase carries media (183 + SDP) — outgoing only.
typedef NS_ENUM(NSInteger, USPEarlyMediaFlag) {
    USPEarlyMediaFlagNone = 0,
    USPEarlyMediaFlagRinging = 1,    // 180
    USPEarlyMediaFlagEarlyMedia = 2, // 183 with SDP
};

@interface USPRegistrationEvent : NSObject
@property(nonatomic, readonly) USPRegState state;
/// Last SIP status code (0 if none).
@property(nonatomic, readonly) NSInteger sipCode;
/// Registration expiry in seconds (<= 0 if unknown/not registered).
@property(nonatomic, readonly) NSInteger expiresSeconds;
/// Reason phrase; safe for logs (no credentials).
@property(nonatomic, readonly, copy) NSString *reason;
- (instancetype)initWithState:(USPRegState)state
                      sipCode:(NSInteger)sipCode
               expiresSeconds:(NSInteger)expiresSeconds
                       reason:(NSString *)reason NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface USPCallEvent : NSObject
@property(nonatomic, readonly) NSInteger callId;
@property(nonatomic, readonly) BOOL isIncoming;
@property(nonatomic, readonly) USPCallPhase phase;
@property(nonatomic, readonly) USPEarlyMediaFlag earlyFlag;
@property(nonatomic, readonly) USPMediaStatus mediaStatus;
/// Last SIP status code seen on the call (0 if none yet).
@property(nonatomic, readonly) NSInteger sipCode;
@property(nonatomic, readonly, copy) NSString *remoteUri;
@property(nonatomic, readonly, copy) NSString *remoteDisplayName;
/// Reason phrase for terminal states; safe for logs.
@property(nonatomic, readonly, copy) NSString *reason;
- (instancetype)initWithCallId:(NSInteger)callId
                    isIncoming:(BOOL)isIncoming
                         phase:(USPCallPhase)phase
                     earlyFlag:(USPEarlyMediaFlag)earlyFlag
                   mediaStatus:(USPMediaStatus)mediaStatus
                       sipCode:(NSInteger)sipCode
                     remoteUri:(NSString *)remoteUri
             remoteDisplayName:(NSString *)remoteDisplayName
                        reason:(NSString *)reason NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

typedef NS_ENUM(NSInteger, USPSRTPPolicy) {
    USPSRTPPolicyDisabled = 0,
    USPSRTPPolicyOptional = 1,
    USPSRTPPolicyMandatory = 2,
};

/// Transient account configuration handed to the bridge. The password is
/// passed through to the SIP stack's credential store and is never logged,
/// persisted, or echoed back by the bridge (CLAUDE.md security rules).
@interface USPAccountConfig : NSObject
@property(nonatomic, copy) NSString *aorUri;       // sip:user@domain
@property(nonatomic, copy) NSString *registrarUri; // sip:domain[;transport=…]
/// Optional outbound proxy URI (routes ALL account requests); empty = none.
@property(nonatomic, copy) NSString *proxyUri;
@property(nonatomic, copy) NSString *username;
@property(nonatomic, copy) NSString *authID;       // empty = username
@property(nonatomic, copy) NSString *password;
@property(nonatomic) NSInteger regIntervalSeconds; // 0 = stack default
@property(nonatomic) USPSRTPPolicy srtpPolicy;
/// Per-account TLS trust override (default NO = verify). Changing this
/// recreates the TLS transport; only valid while no calls are active.
@property(nonatomic) BOOL tlsVerifyDisabled;
/// NAT traversal. stunServer "host[:port]" (empty = none; applied
/// endpoint-wide). TURN credential is transient like the SIP password.
@property(nonatomic, copy) NSString *stunServer;
@property(nonatomic) BOOL iceEnabled;
@property(nonatomic, copy) NSString *turnServer;
@property(nonatomic, copy) NSString *turnUsername;
@property(nonatomic, copy) NSString *turnPassword;
/// UDP keepalive seconds (0 = stack default).
@property(nonatomic) NSInteger keepaliveSeconds;
/// Session timers: 0 = off, 1 = optional, 2 = required.
@property(nonatomic) NSInteger sessionTimerMode;
/// Session-Expires seconds (0 = stack default).
@property(nonatomic) NSInteger sessionTimerExpirySeconds;
@property(nonatomic) BOOL contactRewrite;
@property(nonatomic) BOOL viaRewrite;
@end

NS_ASSUME_NONNULL_END
