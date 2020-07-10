/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

/// Provides set of assertions for single `RUMEvent<DM: RUMDataModel>` JSON object and collection of `[RUMEvent<DM: RUMDataModel>]`.
/// Note: this file is individually referenced by integration tests target, so no dependency on other source files should be introduced except `RUMDataModel` implementations
/// for partial matching concrete RUM events conforming to [rum-events-format](https://github.com/DataDog/rum-events-format).
internal class RUMEventMatcher {
    // MARK: - Initialization

    class func fromJSONObjectData(_ data: Data) throws -> RUMEventMatcher {
        return try RUMEventMatcher(with: data)
    }

    private let jsonMatcher: JSONDataMatcher
    private let jsonData: Data
    private let jsonDataDecoder = JSONDecoder()

    private init(with jsonData: Data) throws {
        self.jsonMatcher = JSONDataMatcher(from: try jsonData.toJSONObject())
        self.jsonData = jsonData
    }

    // MARK: - Full match

    func assertItFullyMatches(jsonString: String, file: StaticString = #file, line: UInt = #line) throws {
        try jsonMatcher.assertItFullyMatches(jsonString: jsonString, file: file, line: line)
    }

    // MARK: - Partial matches

    func model<DM: Decodable>() throws -> DM {
        return try jsonDataDecoder.decode(DM.self, from: jsonData)
    }

    func userID()               throws -> String { try jsonMatcher.value(forKeyPath: "usr.id") }
    func userName()             throws -> String { try jsonMatcher.value(forKeyPath: "usr.name") }
    func userEmail()            throws -> String { try jsonMatcher.value(forKeyPath: "usr.email") }

    func networkReachability()            throws -> String { try jsonMatcher.value(forKeyPath: "meta.network.client.reachability") }
    func networkAvailableInterfaces()     throws -> [String] { try jsonMatcher.value(forKeyPath: "meta.network.client.available_interfaces") }
    func networkConnectionSupportsIPv4()  throws -> Bool { try jsonMatcher.value(forKeyPath: "meta.network.client.supports_ipv4") }
    func networkConnectionSupportsIPv6()  throws -> Bool { try jsonMatcher.value(forKeyPath: "meta.network.client.supports_ipv6") }
    func networkConnectionIsExpensive()   throws -> Bool { try jsonMatcher.value(forKeyPath: "meta.network.client.is_expensive") }
    func networkConnectionIsConstrained() throws -> Bool { try jsonMatcher.value(forKeyPath: "meta.network.client.is_constrained") }

    func mobileNetworkCarrierName()            throws -> String { try jsonMatcher.value(forKeyPath: "meta.network.client.sim_carrier.name") }
    func mobileNetworkCarrierISOCountryCode()  throws -> String { try jsonMatcher.value(forKeyPath: "meta.network.client.sim_carrier.iso_country") }
    func mobileNetworkCarrierRadioTechnology() throws -> String { try jsonMatcher.value(forKeyPath: "meta.network.client.sim_carrier.technology") }
    func mobileNetworkCarrierAllowsVoIP()      throws -> Bool { try jsonMatcher.value(forKeyPath: "meta.network.client.sim_carrier.allows_voip") }
}
