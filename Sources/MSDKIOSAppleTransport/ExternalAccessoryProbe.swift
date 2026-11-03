#if canImport(ExternalAccessory)
import Combine
import ExternalAccessory
import Foundation
import MSDKIOSProbeSupport

/// Accessory metadata for the owner's on-device inventory only. It is never
/// included in run summaries, and the serial number is never read.
public struct ProbeAccessoryDescription: Equatable, Sendable {
    public let connectionID: Int
    public let name: String
    public let manufacturer: String
    public let modelNumber: String
    public let firmwareRevision: String
    public let hardwareRevision: String
    public let protocolNames: [String]

    init(_ accessory: EAAccessory) {
        func text(_ value: String?) -> String { value ?? "" }
        connectionID = accessory.connectionID
        name = text(accessory.name)
        manufacturer = text(accessory.manufacturer)
        modelNumber = text(accessory.modelNumber)
        firmwareRevision = text(accessory.firmwareRevision)
        hardwareRevision = text(accessory.hardwareRevision)
        protocolNames = accessory.protocolStrings
    }
}

/// Public External Accessory binding for one diagnostic run at a time.
///
/// Threading and ownership: main-actor confined. Accessory notifications are
/// observed on the main queue and the session's input stream is scheduled on
/// the main run loop, so every callback runs on the main thread; the
/// `nonisolated` stream callback asserts that with `MainActor.assumeIsolated`.
/// Each run owns at most one session and one expiry task. Ending a run for any
/// reason cancels the task, closes and unschedules the input stream, releases
/// the session and removes the observers. A new run needs an explicit `start`.
///
/// No output stream is opened and no application data is written. Payload is
/// read into one reused 4 KiB buffer, counted and never inspected or kept.
@MainActor
public final class ExternalAccessoryProbe: NSObject, ObservableObject, StreamDelegate {
    @Published public private(set) var controller: ProbeRunController?
    @Published public private(set) var accessoryDescription: ProbeAccessoryDescription?
    @Published public private(set) var startFailure: String?

    private var accessory: EAAccessory?
    private var session: EASession?
    private var sessionAttempted = false
    private var observers: [any NSObjectProtocol] = []
    private var expiryTask: Task<Void, Never>?
    private var readBuffer = [UInt8](repeating: 0, count: ProbeBudget.readChunkBytes)

    public override init() {
        super.init()
    }

    public var isRunning: Bool { controller.map { !$0.isEnded } ?? false }

    /// Starts one run. A BLOCKED activation makes no External Accessory call.
    public func start(runID: String, cohort: ProbeCohort, activation: ProbeActivation) {
        guard !isRunning else { return }
        accessoryDescription = nil
        startFailure = nil
        sessionAttempted = false
        do {
            controller = try ProbeRunController(runID: runID, cohort: cohort, activation: activation,
                                                startedAtMilliseconds: ProbeClock.nowMilliseconds())
        } catch {
            controller = nil
            startFailure = String(describing: error)
            return
        }

        let manager = EAAccessoryManager.shared()
        manager.registerForLocalNotifications()
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: .EAAccessoryDidConnect, object: nil, queue: .main) { [weak self] note in
                let connectionID = (note.userInfo?[EAAccessoryKey] as? EAAccessory)?.connectionID
                MainActor.assumeIsolated { self?.accessoryConnected(connectionID: connectionID) }
            },
            center.addObserver(forName: .EAAccessoryDidDisconnect, object: nil, queue: .main) { [weak self] note in
                let connectionID = (note.userInfo?[EAAccessoryKey] as? EAAccessory)?.connectionID
                MainActor.assumeIsolated { self?.accessoryDisconnected(connectionID: connectionID) }
            },
        ]
        expiryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: ProbeBudget.maximumWindowMilliseconds * 1_000_000)
            guard !Task.isCancelled else { return }
            self?.expireWindow()
        }

        let connected = manager.connectedAccessories
        var preferred = connected.first
        if case .sessionObservation(let name) = activation {
            preferred = connected.first { $0.protocolStrings.contains(name) } ?? preferred
        }
        if let preferred { observe(preferred) }
    }

    /// Ends the current run, for example on the operator's request or when the
    /// app leaves the foreground.
    public func stop(_ reason: ProbeStopReason) {
        controller?.stop(reason, at: ProbeClock.nowMilliseconds())
        cleanUpIfEnded()
    }

    public nonisolated func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        let streamID = ObjectIdentifier(aStream)
        let rawEvent = eventCode.rawValue
        MainActor.assumeIsolated { self.streamEvent(streamID: streamID, rawEvent: rawEvent) }
    }

    private func record(_ event: ProbeEvent) {
        controller?.record(event, at: ProbeClock.nowMilliseconds())
        cleanUpIfEnded()
    }

    private func accessoryConnected(connectionID: Int?) {
        guard isRunning, let connectionID,
              let found = EAAccessoryManager.shared().connectedAccessories
                .first(where: { $0.connectionID == connectionID }) else { return }
        observe(found)
    }

    private func accessoryDisconnected(connectionID: Int?) {
        guard isRunning, let connectionID, let accessory, accessory.connectionID == connectionID else {
            controller?.noteLateCallback()
            return
        }
        record(.accessoryDetached(accessoryID: Self.identifier(accessory)))
    }

    /// Records the run's one accessory and its advertised protocols; any other
    /// accessory is outside this run.
    private func observe(_ candidate: EAAccessory) {
        guard isRunning else { return }
        if let accessory {
            guard accessory.connectionID == candidate.connectionID else { return }
        } else {
            accessory = candidate
            record(.accessoryVisible(accessoryID: Self.identifier(candidate)))
        }
        accessoryDescription = ProbeAccessoryDescription(candidate)
        record(.protocolsAdvertised(accessoryID: Self.identifier(candidate), names: candidate.protocolStrings))
        openSessionIfPermitted()
    }

    private func openSessionIfPermitted() {
        guard !sessionAttempted, let accessory, let controller,
              case .sessionObservation(let name) = controller.activation,
              controller.mayCreateSession(protocolName: name) else { return }
        sessionAttempted = true
        guard let created = EASession(accessory: accessory, forProtocol: name) else {
            record(.sessionCreationFailed(protocolName: name))
            return
        }
        session = created
        let sessionID = controller.state.runID + "-session"
        record(.sessionCreated(sessionID: sessionID, protocolName: name))
        guard isRunning else { return }
        guard let input = created.inputStream else {
            record(.streamError(sessionID: sessionID, stream: .input))
            return
        }
        input.delegate = self
        input.schedule(in: .main, forMode: .default)
        input.open()
    }

    private func streamEvent(streamID: ObjectIdentifier, rawEvent: UInt) {
        guard isRunning, let input = session?.inputStream, ObjectIdentifier(input) == streamID,
              let sessionID = controller?.state.sessionID else {
            controller?.noteLateCallback()
            return
        }
        let event = Stream.Event(rawValue: rawEvent)
        if event.contains(.openCompleted) {
            record(.streamOpened(sessionID: sessionID, stream: .input))
        }
        if event.contains(.hasBytesAvailable) {
            record(.bytesAvailable(sessionID: sessionID))
            readOnce(from: input, sessionID: sessionID)
        }
        if event.contains(.errorOccurred) {
            record(.streamError(sessionID: sessionID, stream: .input))
        }
        if event.contains(.endEncountered) {
            record(.streamEnd(sessionID: sessionID, stream: .input))
        }
    }

    /// One bounded read per bytes-available event. The stream signals again
    /// while more data is waiting.
    private func readOnce(from input: InputStream, sessionID: String) {
        guard let length = controller?.nextReadLength, length > 0 else { return }
        let count = readBuffer.withUnsafeMutableBufferPointer { buffer in
            input.read(buffer.baseAddress!, maxLength: length)
        }
        if count > 0 {
            record(.readCompleted(sessionID: sessionID, byteCount: UInt64(count)))
        } else if count == 0 {
            record(.readCompleted(sessionID: sessionID, byteCount: 0))
        } else {
            record(.readFailed(sessionID: sessionID))
        }
    }

    private func expireWindow() {
        controller?.expireWindow()
        cleanUpIfEnded()
    }

    private func cleanUpIfEnded() {
        guard controller?.needsCleanup == true else { return }
        expiryTask?.cancel()
        expiryTask = nil
        if let input = session?.inputStream {
            input.delegate = nil
            input.close()
            input.remove(from: .main, forMode: .default)
        }
        session = nil
        accessory = nil
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers = []
        EAAccessoryManager.shared().unregisterForLocalNotifications()
        controller?.markCleanupCompleted(at: ProbeClock.nowMilliseconds())
    }

    private static func identifier(_ accessory: EAAccessory) -> UInt64 {
        UInt64(UInt(bitPattern: accessory.connectionID))
    }
}
#endif
