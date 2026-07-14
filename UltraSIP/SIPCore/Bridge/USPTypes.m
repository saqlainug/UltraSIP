#import "USPTypes.h"

@implementation USPRegistrationEvent

- (instancetype)initWithState:(USPRegState)state
                      sipCode:(NSInteger)sipCode
               expiresSeconds:(NSInteger)expiresSeconds
                       reason:(NSString *)reason {
    if ((self = [super init])) {
        _state = state;
        _sipCode = sipCode;
        _expiresSeconds = expiresSeconds;
        _reason = [reason copy];
    }
    return self;
}

@end

@implementation USPCallEvent

- (instancetype)initWithCallId:(NSInteger)callId
                    isIncoming:(BOOL)isIncoming
                         phase:(USPCallPhase)phase
                     earlyFlag:(USPEarlyMediaFlag)earlyFlag
                   mediaStatus:(USPMediaStatus)mediaStatus
                       sipCode:(NSInteger)sipCode
                     remoteUri:(NSString *)remoteUri
             remoteDisplayName:(NSString *)remoteDisplayName
                        reason:(NSString *)reason {
    if ((self = [super init])) {
        _callId = callId;
        _isIncoming = isIncoming;
        _phase = phase;
        _earlyFlag = earlyFlag;
        _mediaStatus = mediaStatus;
        _sipCode = sipCode;
        _remoteUri = [remoteUri copy];
        _remoteDisplayName = [remoteDisplayName copy];
        _reason = [reason copy];
    }
    return self;
}

@end

@implementation USPAccountConfig

- (instancetype)init {
    if ((self = [super init])) {
        _aorUri = @"";
        _registrarUri = @"";
        _proxyUri = @"";
        _username = @"";
        _authID = @"";
        _password = @"";
        _regIntervalSeconds = 0;
        _srtpPolicy = USPSRTPPolicyDisabled;
        _tlsVerifyDisabled = NO;
        _stunServer = @"";
        _iceEnabled = NO;
        _turnServer = @"";
        _turnUsername = @"";
        _turnPassword = @"";
        _keepaliveSeconds = 0;
        _sessionTimerMode = 1;  // optional (PJSIP default)
        _sessionTimerExpirySeconds = 0;
        _contactRewrite = YES;
        _viaRewrite = YES;
    }
    return self;
}

@end
