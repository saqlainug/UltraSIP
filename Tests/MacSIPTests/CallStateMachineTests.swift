import XCTest

@testable import MacSIP

final class CallStateMachineTests: XCTestCase {
    // MARK: Outgoing call machine (docs/SIP_STATE_MACHINES.md)

    func testOutgoingHappyPath() {
        XCTAssertTrue(CallState.dialing.canTransition(to: .ringing, direction: .outgoing))
        XCTAssertTrue(CallState.ringing.canTransition(to: .earlyMedia, direction: .outgoing))
        XCTAssertTrue(CallState.earlyMedia.canTransition(to: .connecting, direction: .outgoing))
        XCTAssertTrue(CallState.connecting.canTransition(to: .connected(hold: .none), direction: .outgoing))
    }

    func testOutgoingCanSkipRinging() {
        XCTAssertTrue(CallState.dialing.canTransition(to: .connecting, direction: .outgoing))
        XCTAssertTrue(CallState.dialing.canTransition(to: .earlyMedia, direction: .outgoing))
    }

    func testIncomingStatesForbiddenOnOutgoing() {
        XCTAssertFalse(CallState.dialing.canTransition(to: .incomingRinging, direction: .outgoing))
        XCTAssertFalse(CallState.incomingRinging.canTransition(to: .connecting, direction: .outgoing))
    }

    // MARK: Incoming call machine

    func testIncomingHappyPath() {
        XCTAssertTrue(CallState.incomingRinging.canTransition(to: .connecting, direction: .incoming))
        XCTAssertTrue(CallState.connecting.canTransition(to: .connected(hold: .none), direction: .incoming))
    }

    func testIncomingCannotUseOutgoingProgress() {
        XCTAssertFalse(CallState.incomingRinging.canTransition(to: .ringing, direction: .incoming))
        XCTAssertFalse(CallState.dialing.canTransition(to: .connecting, direction: .incoming))
    }

    // MARK: Hold

    func testHoldTransitionsWithinConnected() {
        let active = CallState.connected(hold: .none)
        let held = CallState.connected(hold: .local)
        XCTAssertTrue(active.canTransition(to: held, direction: .outgoing))
        XCTAssertTrue(held.canTransition(to: active, direction: .outgoing))
    }

    // MARK: Terminal guards (stale/duplicate callback protection)

    func testDisconnectedIsTerminal() {
        let terminal = CallState.disconnected(.normal)
        XCTAssertTrue(terminal.isTerminal)
        XCTAssertFalse(terminal.canTransition(to: .connected(hold: .none), direction: .outgoing))
        XCTAssertFalse(terminal.canTransition(to: .disconnected(.busy), direction: .outgoing))
        XCTAssertFalse(terminal.canTransition(to: .dialing, direction: .outgoing))
    }

    func testAnyNonTerminalStateCanDisconnect() {
        let nonTerminal: [CallState] = [
            .dialing, .ringing, .earlyMedia, .incomingRinging, .connecting,
            .connected(hold: .none), .connected(hold: .remote),
        ]
        for state in nonTerminal {
            XCTAssertTrue(
                state.canTransition(to: .disconnected(.remoteHangup), direction: .outgoing),
                "\(state) must be able to disconnect")
        }
    }

    // MARK: User-facing outcomes

    func testDisconnectReasonsUseSpecMappings() {
        XCTAssertEqual(DisconnectReason.busy.userFacingDescription, "Busy")
        XCTAssertEqual(
            DisconnectReason.failed(code: 404, reason: "Not Found").userFacingDescription, "Number not found")
        XCTAssertEqual(DisconnectReason.failed(code: 604, reason: "").userFacingDescription, "Call failed (604)")
    }

    // MARK: Durations (SPEC §18: no fake zero talk durations)

    func testUnansweredCallHasNilTalkDuration() {
        let start = Date(timeIntervalSince1970: 1000)
        let snapshot = CallSnapshot(
            id: CallID(1), direction: .outgoing, remoteURI: "sip:100@pbx", remoteDisplayName: "",
            state: .disconnected(.busy), muted: false, mediaActive: false,
            startedAt: start, connectedAt: nil, endedAt: start.addingTimeInterval(12))
        XCTAssertNil(snapshot.talkDuration())
        XCTAssertEqual(snapshot.ringDuration(), 12, accuracy: 0.001)
    }

    func testConnectedCallComputesTalkDuration() {
        let start = Date(timeIntervalSince1970: 1000)
        let snapshot = CallSnapshot(
            id: CallID(2), direction: .incoming, remoteURI: "sip:101@pbx", remoteDisplayName: "Bob",
            state: .disconnected(.normal), muted: false, mediaActive: false,
            startedAt: start, connectedAt: start.addingTimeInterval(4),
            endedAt: start.addingTimeInterval(64))
        XCTAssertEqual(snapshot.talkDuration()!, 60, accuracy: 0.001)
        XCTAssertEqual(snapshot.ringDuration(), 4, accuracy: 0.001)
    }
}
