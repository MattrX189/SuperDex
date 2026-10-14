//
//  SuperDexQRPayload.swift
//  SuperDex
//

import Foundation

struct SuperDexQRPayload: Codable {
    static let kindV1 = "superdex.profile.v1"

    let kind: String
    let username: String

    init(username: String) {
        self.kind = Self.kindV1
        self.username = username
    }

    func encodedString() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(from text: String) -> SuperDexQRPayload? {
        guard let data = text.data(using: .utf8),
              let payload = try? JSONDecoder().decode(SuperDexQRPayload.self, from: data),
              payload.kind == kindV1
        else { return nil }
        return payload
    }
}
