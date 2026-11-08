import Darwin
import Foundation
import Security

struct MugshotClient: Sendable {
    enum Failure: Error {
        case unavailable, untrusted, invalidReply
    }

    private let path = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/faceid/faceid.sock").path

    func checkConnection() throws {
        guard try request("PING\n") == "PONG\n" else { throw Failure.invalidReply }
    }

    func verifyFace() throws -> Bool {
        // Mugshot 1.3's face-only scan. Unlike VERIFY, this cannot fall back to Touch ID.
        // The request only returns a match; Mugshot's separate coordinator types passwords.
        switch try request("VERIFY_LOCK\n") {
        case "OK\n": return true
        case "FAIL\n": return false
        default: throw Failure.invalidReply
        }
    }

    private func request(_ command: String) throws -> String {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw Failure.unavailable }
        defer { close(fd) }

        var noSignal: Int32 = 1
        var timeout = timeval(tv_sec: 8, tv_usec: 0)
        guard setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout.size(ofValue: noSignal))) == 0,
              setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout))) == 0,
              setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout))) == 0 else {
            throw Failure.unavailable
        }

        var address = sockaddr_un()
        let bytes = Array(path.utf8CString)
        guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { throw Failure.unavailable }
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes.map { UInt8(bitPattern: $0) }) }
        let addressLength = socklen_t(address.sun_len)
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, addressLength)
            }
        }
        guard connected == 0 else { throw Failure.unavailable }
        try verifyPeer(fd)

        let commandBytes = Array(command.utf8)
        guard commandBytes.withUnsafeBytes({ send(fd, $0.baseAddress, $0.count, 0) }) == commandBytes.count else {
            throw Failure.unavailable
        }

        var reply = [UInt8]()
        var buffer = [UInt8](repeating: 0, count: 32)
        while reply.count < 32 {
            let count = buffer.withUnsafeMutableBytes { recv(fd, $0.baseAddress, $0.count, 0) }
            guard count >= 0 else { throw Failure.unavailable }
            if count == 0 {
                guard let value = String(bytes: reply, encoding: .ascii) else { throw Failure.invalidReply }
                return value
            }
            reply.append(contentsOf: buffer.prefix(count))
        }
        throw Failure.invalidReply
    }

    private func verifyPeer(_ fd: Int32) throws {
        var user: uid_t = 0
        var group: gid_t = 0
        var token = audit_token_t()
        var tokenSize = socklen_t(MemoryLayout.size(ofValue: token))
        guard getpeereid(fd, &user, &group) == 0, user == geteuid(),
              getsockopt(fd, SOL_LOCAL, LOCAL_PEERTOKEN, &token, &tokenSize) == 0,
              tokenSize == MemoryLayout.size(ofValue: token) else { throw Failure.untrusted }

        let data = withUnsafeBytes(of: token) { Data($0) }
        let attributes = [kSecGuestAttributeAudit as String: data] as CFDictionary
        let rule = "anchor apple generic and identifier \"faceid\" and certificate leaf[subject.OU] = \"RQUR2C3YDZ\""
        var peer: SecCode?
        var requirement: SecRequirement?
        let flags = SecCSFlags(rawValue: 0)
        guard SecCodeCopyGuestWithAttributes(nil, attributes, flags, &peer) == errSecSuccess,
              SecRequirementCreateWithString(rule as CFString, flags, &requirement) == errSecSuccess,
              let peer, let requirement, SecCodeCheckValidity(peer, flags, requirement) == errSecSuccess else {
            throw Failure.untrusted
        }
    }
}
