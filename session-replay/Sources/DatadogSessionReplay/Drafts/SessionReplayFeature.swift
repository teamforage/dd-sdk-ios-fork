/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

/// A draft interface of SR feature.
public class SessionReplayFeature {
    public static var instance: SessionReplayFeature?

    private let recorder: Recorder

    public init() {
        self.recorder = Recorder()
    }

    public func start() { recorder.start() }
    public func stop() { recorder.stop() }
}