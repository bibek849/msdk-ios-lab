import Dispatch
import Foundation

/// Owner-selected run mode. Anything not explicitly selected stays BLOCKED.
public enum ProbeRunMode: String, Sendable, CaseIterable {
    case blocked = "BLOCKED"
    case enumerationOnly = "ENUMERATION_ONLY"
    case sessionObservation = "SESSION_OBSERVATION"
}

public enum ProbeBlockReason: String, Sendable {
    case profileBlocked = "PROFILE_BLOCKED"
    case unknownMode = "UNKNOWN_MODE"
    case missingSourceIdentity = "MISSING_SOURCE_IDENTITY"
    case missingPermissionBasis = "MISSING_PERMISSION_BASIS"
    case missingProtocol = "MISSING_PROTOCOL"
    case protocolNotDeclared = "PROTOCOL_NOT_DECLARED"
}

/// What the app may do for a run. Only `sessionObservation` permits creating a
/// session, and only for its one protocol. No mode permits writing.
public enum ProbeActivation: Equatable, Sendable {
    case blocked(ProbeBlockReason)
    case enumerationOnly
    case sessionObservation(protocolName: String)

    public var permitsObservation: Bool {
        switch self {
        case .blocked: return false
        case .enumerationOnly, .sessionObservation: return true
        }
    }

    /// Shareable label; it never contains the protocol name.
    public var label: String {
        switch self {
        case .blocked(let reason): return "BLOCKED: " + reason.rawValue
        case .enumerationOnly: return ProbeRunMode.enumerationOnly.rawValue
        case .sessionObservation: return ProbeRunMode.sessionObservation.rawValue
        }
    }
}

/// Owner-reviewed local run configuration, read from build-time Info.plist
/// values. The committed defaults declare no protocol and select BLOCKED.
public struct ProbeRunProfile: Equatable, Sendable {
    public static let modeKey = "ProbeRunMode"
    public static let protocolKey = "ProbeAccessoryProtocol"
    public static let permissionBasisKey = "ProbePermissionBasis"
    public static let sourceKey = "ProbeSourceSHA"
    public static let declaredProtocolsKey = "UISupportedExternalAccessoryProtocols"

    /// `nil` when a mode value is present but unrecognized.
    public let mode: ProbeRunMode?
    public let protocolName: String?
    public let permissionBasis: String?
    public let sourceSHA: String?
    public let declaredProtocols: [String]

    public init(mode: ProbeRunMode?, protocolName: String?, permissionBasis: String?,
                sourceSHA: String?, declaredProtocols: [String]) {
        self.mode = mode
        self.protocolName = protocolName
        self.permissionBasis = permissionBasis
        self.sourceSHA = sourceSHA
        self.declaredProtocols = declaredProtocols
    }

    /// Missing, blank or unexpanded `$(…)` values count as unset; a missing
    /// mode is BLOCKED and an unrecognized one is blocked as UNKNOWN_MODE.
    public init(infoDictionary: [String: Any]) {
        func value(_ key: String) -> String? { Self.normalized(infoDictionary[key] as? String) }
        let mode: ProbeRunMode?
        if let rawMode = value(Self.modeKey) {
            mode = ProbeRunMode(rawValue: rawMode)
        } else {
            mode = .blocked
        }
        self.init(mode: mode,
                  protocolName: value(Self.protocolKey),
                  permissionBasis: value(Self.permissionBasisKey),
                  sourceSHA: value(Self.sourceKey),
                  declaredProtocols: (infoDictionary[Self.declaredProtocolsKey] as? [String] ?? [])
                      .compactMap(Self.normalized))
    }

    public var activation: ProbeActivation {
        guard let mode else { return .blocked(.unknownMode) }
        if mode == .blocked { return .blocked(.profileBlocked) }
        guard let sourceSHA, Self.isFullCommitSHA(sourceSHA) else { return .blocked(.missingSourceIdentity) }
        guard permissionBasis != nil else { return .blocked(.missingPermissionBasis) }
        if mode == .enumerationOnly { return .enumerationOnly }
        guard let protocolName else { return .blocked(.missingProtocol) }
        guard declaredProtocols.contains(protocolName) else { return .blocked(.protocolNotDeclared) }
        return .sessionObservation(protocolName: protocolName)
    }

    static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty, !trimmed.contains("$(") else { return nil }
        return trimmed
    }

    /// A full 40-character lowercase hexadecimal Git commit identity.
    static func isFullCommitSHA(_ value: String) -> Bool {
        value.utf8.count == 40 && value.utf8.allSatisfy { (0x30...0x39).contains($0) || (0x61...0x66).contains($0) }
    }
}

/// Monotonic milliseconds for live observations. It does not use wall time.
public enum ProbeClock {
    public static func nowMilliseconds() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds / 1_000_000
    }
}
