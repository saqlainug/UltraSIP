#import "MSPTypes.h"

@implementation MSPRegistrationEvent

- (instancetype)initWithState:(MSPRegState)state
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

@implementation MSPCallEvent

- (instancetype)initWithCallId:(NSInteger)callId
                    isIncoming:(BOOL)isIncoming
                         phase:(MSPCallPhase)phase
                     earlyFlag:(MSPEarlyMediaFlag)earlyFlag
                   mediaStatus:(MSPMediaStatus)mediaStatus
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

@implementation MSPAccountConfig

- (instancetype)init {
    if ((self = [super init])) {
        _aorUri = @"";
        _registrarUri = @"";
        _username = @"";
        _authID = @"";
        _password = @"";
        _regIntervalSeconds = 0;
    }
    return self;
}

@end
