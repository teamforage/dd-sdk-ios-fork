/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import XCTest
@testable import Datadog

class FileReaderTests: XCTestCase {
    override func setUp() {
        super.setUp()
        temporaryDirectory.create()
    }

    override func tearDown() {
        temporaryDirectory.delete()
        super.tearDown()
    }

    func testItReadsSingleBatch() throws {
        let reader = FileReader(
            dataFormat: .mockWith(prefix: "[", suffix: "]"),
            orchestrator: FilesOrchestrator(
                directory: temporaryDirectory,
                performance: StoragePerformanceMock.readAllFiles,
                dateProvider: SystemDateProvider()
            )
        )
        _ = try temporaryDirectory
            .createFile(named: Date.mockAny().toFileName)
            .append(data: DataBlock(type: .event, data: "ABCD".utf8Data).serialize())

        XCTAssertEqual(try temporaryDirectory.files().count, 1)
        let batch = reader.readNextBatch()
        XCTAssertEqual(batch?.data, "[ABCD]".utf8Data)
    }

    func testItReadsSingleEncryptedBatch() throws {
        // Given
        // base64(foo) = Zm9v
        let data = Array(repeating: "Zm9v".utf8Data, count: 3)
            .map { DataBlock(type: .event, data: $0).serialize() }
            .reduce(.init(), +)

        _ = try temporaryDirectory
            .createFile(named: Date.mockAny().toFileName)
            .append(data: data)

        let reader = FileReader(
            dataFormat: .mockWith(prefix: "[", suffix: "]", separator: ","),
            orchestrator: FilesOrchestrator(
                directory: temporaryDirectory,
                performance: StoragePerformanceMock.readAllFiles,
                dateProvider: SystemDateProvider()
            ),
            encryption: DataEncryptionMock(
                decrypt: { _ in "bar".utf8Data }
            )
        )

        // When
        let batch = reader.readNextBatch()

        // Then
        XCTAssertEqual(batch?.data, "[bar,bar,bar]".utf8Data)
    }

    func testItMarksBatchesAsRead() throws {
        let dateProvider = RelativeDateProvider(advancingBySeconds: 60)
        let reader = FileReader(
            dataFormat: .mockWith(prefix: "[", suffix: "]"),
            orchestrator: FilesOrchestrator(
                directory: temporaryDirectory,
                performance: StoragePerformanceMock.readAllFiles,
                dateProvider: dateProvider
            )
        )
        let file1 = try temporaryDirectory.createFile(named: dateProvider.currentDate().toFileName)
        try file1.append(data: DataBlock(type: .event, data: "1".utf8Data).serialize())

        let file2 = try temporaryDirectory.createFile(named: dateProvider.currentDate().toFileName)
        try file2.append(data: DataBlock(type: .event, data: "2".utf8Data).serialize())

        let file3 = try temporaryDirectory.createFile(named: dateProvider.currentDate().toFileName)
        try file3.append(data: DataBlock(type: .event, data: "3".utf8Data).serialize())

        var batch: Batch
        batch = try reader.readNextBatch().unwrapOrThrow()
        XCTAssertEqual(batch.data, "[1]".utf8Data)
        reader.markBatchAsRead(batch)

        batch = try reader.readNextBatch().unwrapOrThrow()
        XCTAssertEqual(batch.data, "[2]".utf8Data)
        reader.markBatchAsRead(batch)

        batch = try reader.readNextBatch().unwrapOrThrow()
        XCTAssertEqual(batch.data, "[3]".utf8Data)
        reader.markBatchAsRead(batch)

        XCTAssertNil(reader.readNextBatch())
        XCTAssertEqual(try temporaryDirectory.files().count, 0)
    }
}
