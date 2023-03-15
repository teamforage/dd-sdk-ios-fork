/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import UIKit

internal class SwiftUIFrameRecorder: NodeRecorder {
    private let snapshotRecorder: SwiftUISnapshotRecorder = SwiftUISnapshotRecorder()
    private lazy var subtreeRecorder: ViewTreeRecorder = ViewTreeRecorder(nodeRecorders: [snapshotRecorder])

    func semantics(of view: UIView, with attributes: ViewAttributes, in context: ViewTreeRecordingContext) -> NodeSemantics? {
        let classDescription = String(describing: view)
        guard classDescription.contains("SwiftUI") else {
            return nil
        }
        let builder = SwiftUIFrameWireframesBuilder(
            wireframeIDs: context.ids.nodeIDs(1, for: view),
            attributes: attributes,
            wireframeRect: view.frame,
            backgroundColor: view.backgroundColor
        )
        let node = Node(viewAttributes: attributes, wireframesBuilder: builder)
        return SpecificElement(subtreeStrategy: .record, nodes: [node])
    }
}

internal struct SwiftUIFrameWireframesBuilder: NodeWireframesBuilder {
    let wireframeIDs: [WireframeID]
    /// Attributes of the `UIView`.
    let attributes: ViewAttributes

    let wireframeRect: CGRect

    let backgroundColor: UIColor?

    func buildWireframes(with builder: WireframesBuilder) -> [SRWireframe] {
        return [
            builder.createShapeWireframe(
                id: wireframeIDs[0],
                frame: wireframeRect,
                borderColor: UIColor.black.cgColor,
                borderWidth: 2,
                backgroundColor: backgroundColor?.cgColor
            )
        ]
    }
}
