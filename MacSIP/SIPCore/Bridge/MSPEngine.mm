//
// MSPEngine implementation. The ONLY file that touches PJSIP directly
// (with MSPBridgeInternal.hpp). See MSPEngine.h for the contract.
//

#import "MSPEngine.h"

#include <pjsua2.hpp>

#include <atomic>
#include <map>
#include <memory>
#include <set>
#include <string>

NSErrorDomain const MSPErrorDomain = @"com.macsip.SIPCore";

#pragma mark - Engine worker thread

/// Single dedicated OS thread running a run loop. All PJSIP access happens
/// here; the thread is registered with PJLIB implicitly by libCreate()
/// (pj_init registers the calling thread) and defensively re-checked.
@interface MSPWorker : NSObject
- (void)start;
- (void)async:(dispatch_block_t)block;
- (void)cancel;
@end

@implementation MSPWorker {
    NSThread *_thread;
}

- (void)start {
    _thread = [[NSThread alloc] initWithTarget:self selector:@selector(threadMain) object:nil];
    _thread.name = @"com.macsip.sip-engine";
    _thread.qualityOfService = NSQualityOfServiceUserInitiated;
    [_thread start];
}

- (void)threadMain {
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
    while (!NSThread.currentThread.isCancelled) {
        @autoreleasepool {
            [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        }
    }
}

- (void)async:(dispatch_block_t)block {
    [self performSelector:@selector(runBlock:) onThread:_thread withObject:[block copy] waitUntilDone:NO];
}

- (void)runBlock:(dispatch_block_t)block {
    block();
}

- (void)cancel {
    [_thread cancel];
}

@end

#pragma mark - C++ bridge internals

@class MSPEngine;
static void MSPEmitReg(MSPEngine *engine, MSPRegistrationEvent *event);
static void MSPEmitCall(MSPEngine *engine, MSPCallEvent *event, BOOL isNewIncoming);
static void MSPEngineAsync(MSPEngine *engine, dispatch_block_t block);

namespace macsip {

/// True between libCreate() and libDestroy(); pj_thread_is_registered may
/// only be called while PJLIB is initialized.
static std::atomic<bool> g_pjlibReady{false};

/// Defensive registration for any non-PJLIB-created thread that ends up
/// executing engine blocks (CLAUDE.md threading rule 2). In this design all
/// engine blocks run on the one thread that called libCreate (auto-
/// registered by pj_init), so this is a belt-and-braces guard, not a
/// license to call PJSIP from other threads. The descriptor is thread-local
/// so it stays valid for the thread's lifetime.
void ensureThreadRegisteredIfStarted() {
    if (!g_pjlibReady.load(std::memory_order_acquire)) {
        return;
    }
    if (pj_thread_is_registered()) {
        return;
    }
    static thread_local pj_thread_desc desc;
    pj_thread_t *thread = nullptr;
    pj_bzero(desc, sizeof(desc));
    pj_thread_register("msp-engine", desc, &thread);
}

class BridgeCall;

struct EngineCore {
    std::unique_ptr<pj::Endpoint> endpoint;
    std::unique_ptr<pj::Account> account;
    // Owned raw pointers; mutated ONLY on the engine thread. Values are
    // deleted exactly once, on the engine thread, after erase.
    std::map<int, BridgeCall *> calls;
    std::set<int> mutedCalls;
    bool started = false;
};

static MSPMediaStatus mediaStatusFrom(const pj::CallInfo &info) {
    for (const auto &media : info.media) {
        if (media.type != PJMEDIA_TYPE_AUDIO) continue;
        switch (media.status) {
            case PJSUA_CALL_MEDIA_ACTIVE: return MSPMediaStatusActive;
            case PJSUA_CALL_MEDIA_LOCAL_HOLD: return MSPMediaStatusLocalHold;
            case PJSUA_CALL_MEDIA_REMOTE_HOLD: return MSPMediaStatusRemoteHold;
            case PJSUA_CALL_MEDIA_ERROR: return MSPMediaStatusError;
            default: break;
        }
    }
    return MSPMediaStatusNone;
}

/// Splits `"Display" <sip:u@h>` into display + URI (best effort).
static void parseRemote(const std::string &raw, NSString **uriOut, NSString **displayOut) {
    NSString *full = [NSString stringWithUTF8String:raw.c_str()] ?: @"";
    NSString *uri = full;
    NSString *display = @"";
    NSRange lt = [full rangeOfString:@"<"];
    NSRange gt = [full rangeOfString:@">"];
    if (lt.location != NSNotFound && gt.location != NSNotFound && gt.location > lt.location) {
        uri = [full substringWithRange:NSMakeRange(lt.location + 1, gt.location - lt.location - 1)];
        display = [[full substringToIndex:lt.location]
            stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" \"'"]];
    }
    *uriOut = uri;
    *displayOut = display;
}

class BridgeCall : public pj::Call {
  public:
    BridgeCall(pj::Account &account, MSPEngine *engine, bool incoming, int callId = PJSUA_INVALID_ID)
        : pj::Call(account, callId), engine_(engine), incoming_(incoming) {}

    bool incoming() const { return incoming_; }

    MSPCallEvent *snapshotEvent(MSPCallPhase phaseOverride = (MSPCallPhase)-1) {
        pj::CallInfo info;
        try {
            info = getInfo();
        } catch (const pj::Error &) {
            return nil;
        }
        MSPCallPhase phase;
        MSPEarlyMediaFlag early = MSPEarlyMediaFlagNone;
        switch (info.state) {
            case PJSIP_INV_STATE_CALLING: phase = MSPCallPhaseCalling; break;
            case PJSIP_INV_STATE_INCOMING: phase = MSPCallPhaseIncoming; break;
            case PJSIP_INV_STATE_EARLY:
                phase = incoming_ ? MSPCallPhaseIncoming : MSPCallPhaseEarly;
                early = (info.lastStatusCode == 183 || mediaStatusFrom(info) == MSPMediaStatusActive)
                            ? MSPEarlyMediaFlagEarlyMedia
                            : MSPEarlyMediaFlagRinging;
                break;
            case PJSIP_INV_STATE_CONNECTING: phase = MSPCallPhaseConnecting; break;
            case PJSIP_INV_STATE_CONFIRMED: phase = MSPCallPhaseConfirmed; break;
            case PJSIP_INV_STATE_DISCONNECTED: phase = MSPCallPhaseDisconnected; break;
            default: phase = incoming_ ? MSPCallPhaseIncoming : MSPCallPhaseCalling; break;
        }
        if (phaseOverride != (MSPCallPhase)-1) phase = phaseOverride;
        NSString *uri = @"";
        NSString *display = @"";
        parseRemote(info.remoteUri, &uri, &display);
        return [[MSPCallEvent alloc] initWithCallId:info.id
                                         isIncoming:incoming_
                                              phase:phase
                                          earlyFlag:early
                                        mediaStatus:mediaStatusFrom(info)
                                            sipCode:(NSInteger)info.lastStatusCode
                                          remoteUri:uri
                                  remoteDisplayName:display
                                             reason:[NSString stringWithUTF8String:info.lastReason.c_str()] ?: @""];
    }

    void onCallState(pj::OnCallStateParam &prm) override;
    void onCallMediaState(pj::OnCallMediaStateParam &prm) override;

  private:
    __weak MSPEngine *engine_;
    const bool incoming_;
};

class BridgeAccount : public pj::Account {
  public:
    explicit BridgeAccount(MSPEngine *engine) : engine_(engine) {}

    void onRegState(pj::OnRegStateParam &prm) override {
        long expires = -1;
        bool active = false;
        try {
            pj::AccountInfo info = getInfo();
            active = info.regIsActive;
            expires = info.regExpiresSec;
        } catch (const pj::Error &) {
        }
        MSPRegState state;
        if (prm.status != PJ_SUCCESS || prm.code >= 300) {
            state = MSPRegStateFailed;
        } else if (prm.code / 100 == 2) {
            state = (active && expires > 0) ? MSPRegStateRegistered : MSPRegStateUnregistered;
        } else {
            state = MSPRegStateRegistering;
        }
        NSInteger code = prm.code > 0 ? prm.code : (prm.status != PJ_SUCCESS ? 408 : 0);
        MSPRegistrationEvent *event = [[MSPRegistrationEvent alloc]
             initWithState:state
                   sipCode:code
            expiresSeconds:expires
                    reason:[NSString stringWithUTF8String:prm.reason.c_str()] ?: @""];
        MSPEmitReg(engine_, event);
    }

    void onIncomingCall(pj::OnIncomingCallParam &iprm) override;

  private:
    __weak MSPEngine *engine_;
};

}  // namespace macsip

#pragma mark - MSPEngine

@interface MSPEngine () {
    macsip::EngineCore _core;
    MSPWorker *_worker;
    dispatch_queue_t _delegateQueue;
}
@end

@implementation MSPEngine

- (instancetype)init {
    if ((self = [super init])) {
        _worker = [[MSPWorker alloc] init];
        [_worker start];
        _delegateQueue = dispatch_queue_create("com.macsip.sip-events", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc {
    [_worker cancel];
}

#pragma mark Internal plumbing (engine thread only)

- (void)onEngine:(dispatch_block_t)block {
    [_worker async:^{
        macsip::ensureThreadRegisteredIfStarted();
        block();
    }];
}

- (void)emitRegistrationEvent:(MSPRegistrationEvent *)event {
    id<MSPEngineDelegate> delegate = self.delegate;
    if (!delegate) return;
    dispatch_async(_delegateQueue, ^{ [delegate sipEngineRegistrationChanged:event]; });
}

- (void)emitCallEvent:(MSPCallEvent *)event incoming:(BOOL)isNewIncoming {
    if (!event) return;
    id<MSPEngineDelegate> delegate = self.delegate;
    if (!delegate) return;
    dispatch_async(_delegateQueue, ^{
        if (isNewIncoming) {
            [delegate sipEngineIncomingCall:event];
        } else {
            [delegate sipEngineCallChanged:event];
        }
    });
}

- (macsip::EngineCore *)core {
    return &_core;
}

static NSError *MSPErrorFromPJ(const pj::Error &error) {
    NSString *reason = [NSString stringWithUTF8String:error.reason.c_str()] ?: @"SIP stack error";
    return [NSError errorWithDomain:MSPErrorDomain
                               code:error.status
                           userInfo:@{NSLocalizedDescriptionKey : reason}];
}

#pragma mark Lifecycle

- (void)startWithUserAgent:(NSString *)userAgent
                      port:(NSInteger)port
              useNullAudio:(BOOL)useNullAudio
                completion:(void (^)(NSError *_Nullable))completion {
    std::string ua([userAgent UTF8String] ?: "MacSIP");
    [self onEngine:^{
        if (self->_core.started) {
            dispatch_async(self->_delegateQueue, ^{ completion(nil); });
            return;
        }
        try {
            self->_core.endpoint = std::make_unique<pj::Endpoint>();
            self->_core.endpoint->libCreate();
            macsip::g_pjlibReady.store(true, std::memory_order_release);
            pj::EpConfig config;
            // Level ≤3: no SIP message traces in logs (they carry
            // Authorization headers — CLAUDE.md redaction rules).
            config.logConfig.level = 3;
            config.logConfig.consoleLevel = 3;
            config.uaConfig.userAgent = ua;
            self->_core.endpoint->libInit(config);
            pj::TransportConfig transport;
            transport.port = (unsigned)port;  // 0 = ephemeral (M1: UDP only)
            self->_core.endpoint->transportCreate(PJSIP_TRANSPORT_UDP, transport);
            self->_core.endpoint->libStart();
            if (useNullAudio) {
                self->_core.endpoint->audDevManager().setNullDev();
            }
            self->_core.started = true;
            dispatch_async(self->_delegateQueue, ^{ completion(nil); });
        } catch (const pj::Error &e) {
            NSError *error = MSPErrorFromPJ(e);
            self->_core.endpoint.reset();
            self->_core.started = false;
            dispatch_async(self->_delegateQueue, ^{ completion(error); });
        }
    }];
}

- (void)stopWithCompletion:(void (^)(void))completion {
    [self onEngine:^{
        if (self->_core.started) {
            // Teardown order: calls → account → endpoint (CLAUDE.md rule 4).
            for (auto &pair : self->_core.calls) {
                try {
                    pj::CallOpParam prm;
                    pair.second->hangup(prm);
                } catch (const pj::Error &) {
                }
                delete pair.second;
            }
            self->_core.calls.clear();
            self->_core.mutedCalls.clear();
            self->_core.account.reset();
            macsip::g_pjlibReady.store(false, std::memory_order_release);
            try {
                self->_core.endpoint->libDestroy();
            } catch (const pj::Error &) {
            }
            self->_core.endpoint.reset();
            self->_core.started = false;
        }
        dispatch_async(self->_delegateQueue, ^{ completion(); });
    }];
}

#pragma mark Account

- (void)configureAccount:(MSPAccountConfig *)config
              completion:(void (^)(NSError *_Nullable))completion {
    std::string aor([config.aorUri UTF8String] ?: "");
    std::string registrar([config.registrarUri UTF8String] ?: "");
    std::string user([config.username UTF8String] ?: "");
    std::string authID([config.authID UTF8String] ?: "");
    std::string password([config.password UTF8String] ?: "");
    long interval = config.regIntervalSeconds;
    [self onEngine:^{
        if (!self->_core.started) {
            NSError *error = [NSError errorWithDomain:MSPErrorDomain
                                                 code:-1
                                             userInfo:@{NSLocalizedDescriptionKey : @"Engine not started"}];
            dispatch_async(self->_delegateQueue, ^{ completion(error); });
            return;
        }
        try {
            self->_core.account.reset();  // replace: unregister + delete old
            pj::AccountConfig accountConfig;
            accountConfig.idUri = aor;
            accountConfig.regConfig.registrarUri = registrar;
            accountConfig.regConfig.registerOnAdd = true;
            if (interval > 0) accountConfig.regConfig.timeoutSec = (unsigned)interval;
            pj::AuthCredInfo cred("digest", "*", authID.empty() ? user : authID, 0, password);
            accountConfig.sipConfig.authCreds.push_back(cred);
            auto account = std::make_unique<macsip::BridgeAccount>(self);
            account->create(accountConfig, true);
            self->_core.account = std::move(account);
            dispatch_async(self->_delegateQueue, ^{ completion(nil); });
        } catch (const pj::Error &e) {
            NSError *error = MSPErrorFromPJ(e);
            dispatch_async(self->_delegateQueue, ^{ completion(error); });
        }
    }];
}

- (void)removeAccountWithCompletion:(void (^)(void))completion {
    [self onEngine:^{
        self->_core.account.reset();
        if (completion) dispatch_async(self->_delegateQueue, ^{ completion(); });
    }];
}

- (void)refreshRegistration {
    [self onEngine:^{
        if (!self->_core.account) return;
        try {
            self->_core.account->setRegistration(true);
        } catch (const pj::Error &) {
        }
    }];
}

#pragma mark Calls

- (void)makeCallTo:(NSString *)uri
        completion:(void (^)(NSError *_Nullable, NSInteger))completion {
    std::string destination([uri UTF8String] ?: "");
    [self onEngine:^{
        if (!self->_core.started || !self->_core.account) {
            NSError *error = [NSError errorWithDomain:MSPErrorDomain
                                                 code:-2
                                             userInfo:@{NSLocalizedDescriptionKey : @"No account configured"}];
            dispatch_async(self->_delegateQueue, ^{ completion(error, -1); });
            return;
        }
        auto *call = new macsip::BridgeCall(*self->_core.account, self, false);
        try {
            pj::CallOpParam prm(true);
            call->makeCall(destination, prm);
        } catch (const pj::Error &e) {
            delete call;
            NSError *error = MSPErrorFromPJ(e);
            dispatch_async(self->_delegateQueue, ^{ completion(error, -1); });
            return;
        }
        int callId = call->getId();
        self->_core.calls[callId] = call;
        dispatch_async(self->_delegateQueue, ^{ completion(nil, callId); });
        [self emitCallEvent:call->snapshotEvent() incoming:NO];
    }];
}

- (void)withCall:(NSInteger)callId do:(void (^)(macsip::BridgeCall *call))operation {
    [self onEngine:^{
        auto found = self->_core.calls.find((int)callId);
        if (found == self->_core.calls.end()) return;  // stale id — dropped
        operation(found->second);
    }];
}

- (void)answerCall:(NSInteger)callId {
    [self withCall:callId do:^(macsip::BridgeCall *call) {
        try {
            pj::CallOpParam prm(true);
            prm.statusCode = PJSIP_SC_OK;
            call->answer(prm);
        } catch (const pj::Error &) {
        }
    }];
}

- (void)rejectCall:(NSInteger)callId busy:(BOOL)busy {
    [self withCall:callId do:^(macsip::BridgeCall *call) {
        try {
            pj::CallOpParam prm;
            prm.statusCode = busy ? PJSIP_SC_BUSY_HERE : PJSIP_SC_DECLINE;
            call->hangup(prm);
        } catch (const pj::Error &) {
        }
    }];
}

- (void)hangupCall:(NSInteger)callId {
    [self withCall:callId do:^(macsip::BridgeCall *call) {
        try {
            pj::CallOpParam prm;
            call->hangup(prm);
        } catch (const pj::Error &) {
        }
    }];
}

- (void)setCall:(NSInteger)callId held:(BOOL)held {
    [self withCall:callId do:^(macsip::BridgeCall *call) {
        try {
            pj::CallOpParam prm(true);
            if (held) {
                call->setHold(prm);
            } else {
                prm.opt.flag |= PJSUA_CALL_UNHOLD;
                call->reinvite(prm);
            }
        } catch (const pj::Error &) {
        }
    }];
}

- (void)setCall:(NSInteger)callId muted:(BOOL)muted {
    [self withCall:callId do:^(macsip::BridgeCall *call) {
        if (muted) {
            self->_core.mutedCalls.insert((int)callId);
        } else {
            self->_core.mutedCalls.erase((int)callId);
        }
        try {
            pj::AudioMedia media = call->getAudioMedia(-1);
            auto &manager = self->_core.endpoint->audDevManager();
            if (muted) {
                manager.getCaptureDevMedia().stopTransmit(media);
            } else {
                manager.getCaptureDevMedia().startTransmit(media);
            }
        } catch (const pj::Error &) {
            // No active audio yet — the mute flag applies on media activation.
        }
    }];
}

- (void)sendDTMF:(NSString *)digits toCall:(NSInteger)callId {
    std::string dtmf([digits UTF8String] ?: "");
    [self withCall:callId do:^(macsip::BridgeCall *call) {
        try {
            call->dialDtmf(dtmf);
        } catch (const pj::Error &) {
        }
    }];
}

- (void)statsForCall:(NSInteger)callId
          completion:(void (^)(NSInteger, NSInteger))completion {
    [self onEngine:^{
        NSInteger tx = -1;
        NSInteger rx = -1;
        auto found = self->_core.calls.find((int)callId);
        if (found != self->_core.calls.end()) {
            try {
                pj::StreamStat stat = found->second->getStreamStat(0);
                tx = (NSInteger)stat.rtcp.txStat.pkt;
                rx = (NSInteger)stat.rtcp.rxStat.pkt;
            } catch (const pj::Error &) {
            }
        }
        dispatch_async(self->_delegateQueue, ^{ completion(tx, rx); });
    }];
}

#pragma mark Diagnostics

- (void)diagnosticsWithCompletion:(void (^)(NSString *))completion {
    [self onEngine:^{
        NSMutableString *info = [NSMutableString string];
        if (!self->_core.started) {
            [info appendString:@"Engine: stopped\n"];
        } else {
            try {
                [info appendFormat:@"PJSIP: %s\n", self->_core.endpoint->libVersion().full.c_str()];
                [info appendString:@"Transport: UDP (ephemeral port)\nCodecs:\n"];
                for (const auto &codec : self->_core.endpoint->codecEnum2()) {
                    [info appendFormat:@"  %s (priority %d)\n", codec.codecId.c_str(), (int)codec.priority];
                }
                if (self->_core.account) {
                    pj::AccountInfo accountInfo = self->_core.account->getInfo();
                    [info appendFormat:@"Account: %s\nRegistered: %s (expires %ds)\n",
                                       accountInfo.uri.c_str(), accountInfo.regIsActive ? "yes" : "no",
                                       (int)accountInfo.regExpiresSec];
                } else {
                    [info appendString:@"Account: none\n"];
                }
                [info appendFormat:@"Active calls: %zu\n", self->_core.calls.size()];
            } catch (const pj::Error &e) {
                [info appendFormat:@"Diagnostics error: %s\n", e.reason.c_str()];
            }
        }
        NSString *result = [info copy];
        dispatch_async(self->_delegateQueue, ^{ completion(result); });
    }];
}

@end

#pragma mark - C++ → ObjC callback plumbing

namespace macsip {

void BridgeCall::onCallState(pj::OnCallStateParam &prm) {
    MSPEngine *engine = engine_;
    if (!engine) return;
    MSPCallEvent *event = snapshotEvent();
    if (!event) return;
    if (event.phase == MSPCallPhaseDisconnected) {
        // Hop: erase from registry, emit terminal event, then delete the
        // C++ object on the engine thread (never inside this callback).
        int callId = (int)event.callId;
        MSPEngineAsync(engine, ^{
            auto *core = [engine core];
            auto found = core->calls.find(callId);
            if (found != core->calls.end()) {
                BridgeCall *call = found->second;
                core->calls.erase(found);
                core->mutedCalls.erase(callId);
                MSPEmitCall(engine, event, NO);
                delete call;
            } else {
                MSPEmitCall(engine, event, NO);
            }
        });
    } else {
        MSPEmitCall(engine, event, NO);
    }
}

void BridgeCall::onCallMediaState(pj::OnCallMediaStateParam &prm) {
    MSPEngine *engine = engine_;
    if (!engine) return;
    int callId = -1;
    try {
        callId = getId();
    } catch (const pj::Error &) {
        return;
    }
    MSPEngineAsync(engine, ^{
        auto *core = [engine core];
        auto found = core->calls.find(callId);
        if (found == core->calls.end()) return;  // already terminal
        BridgeCall *call = found->second;
        try {
            pj::AudioMedia media = call->getAudioMedia(-1);
            auto &manager = core->endpoint->audDevManager();
            media.startTransmit(manager.getPlaybackDevMedia());
            if (core->mutedCalls.count(callId) == 0) {
                manager.getCaptureDevMedia().startTransmit(media);
            }
        } catch (const pj::Error &) {
            // No active audio stream (hold, or media not audio) — fine.
        }
        MSPEmitCall(engine, call->snapshotEvent(), NO);
    });
}

void BridgeAccount::onIncomingCall(pj::OnIncomingCallParam &iprm) {
    MSPEngine *engine = engine_;
    if (!engine) return;
    auto *call = new BridgeCall(*this, engine, true, iprm.callId);
    int callId = iprm.callId;
    MSPEngineAsync(engine, ^{
        auto *core = [engine core];
        MSPCallEvent *event = call->snapshotEvent(MSPCallPhaseIncoming);
        if (!event) {
            // Remote already cancelled before we registered the call.
            delete call;
            return;
        }
        core->calls[callId] = call;
        try {
            pj::CallOpParam prm;
            prm.statusCode = PJSIP_SC_RINGING;
            call->answer(prm);
        } catch (const pj::Error &) {
        }
        MSPEmitCall(engine, event, YES);
    });
}

}  // namespace macsip

static void MSPEmitReg(MSPEngine *engine, MSPRegistrationEvent *event) {
    [engine emitRegistrationEvent:event];
}

static void MSPEmitCall(MSPEngine *engine, MSPCallEvent *event, BOOL isNewIncoming) {
    [engine emitCallEvent:event incoming:isNewIncoming];
}

static void MSPEngineAsync(MSPEngine *engine, dispatch_block_t block) {
    [engine onEngine:block];
}
