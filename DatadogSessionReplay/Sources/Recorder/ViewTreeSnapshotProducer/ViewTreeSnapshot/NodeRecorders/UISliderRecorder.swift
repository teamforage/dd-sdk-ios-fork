/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import UIKit

internal struct UISliderRecorder: NodeRecorder {
    func semantics(of view: UIView, with attributes: ViewAttributes, in context: ViewTreeRecordingContext) -> NodeSemantics? {
        guard let slider = view as? UISlider else {
            return nil
        }

        guard attributes.isVisible else {
            return InvisibleElement.constant
        }

        let ids = context.ids.nodeIDs(4, for: slider)

        let builder = UISliderWireframesBuilder(
            wireframeRect: attributes.frame,
            attributes: attributes,
            backgroundWireframeID: ids[0],
            minTrackWireframeID: ids[1],
            maxTrackWireframeID: ids[2],
            thumbWireframeID: ids[3],
            value: (min: slider.minimumValue, max: slider.maximumValue, current: slider.value),
            isEnabled: slider.isEnabled,
            minTrackTintColor: slider.minimumTrackTintColor?.cgColor ?? slider.tintColor?.cgColor,
            maxTrackTintColor: slider.maximumTrackTintColor?.cgColor,
            thumbTintColor: slider.thumbTintColor?.cgColor
        )
        let node = Node(viewAttributes: attributes, wireframesBuilder: builder)
        return SpecificElement(subtreeStrategy: .ignore, nodes: [node])
    }
}

internal struct UISliderWireframesBuilder: NodeWireframesBuilder {
    var wireframeRect: CGRect
    let attributes: ViewAttributes

    let backgroundWireframeID: WireframeID
    let minTrackWireframeID: WireframeID
    let maxTrackWireframeID: WireframeID
    let thumbWireframeID: WireframeID
    let value: (min: Float, max: Float, current: Float)
    let isEnabled: Bool
    let minTrackTintColor: CGColor?
    let maxTrackTintColor: CGColor?
    let thumbTintColor: CGColor?

    func buildWireframes(with builder: WireframesBuilder) -> [SRWireframe] {
        guard value.max > value.min else {
            return [] // illegal, should not happen
        }

        let normalValue = CGFloat((value.current - value.min) / (value.max - value.min)) // normalized, 0 to 1
        let (left, right) = wireframeRect
            .divided(atDistance: normalValue * wireframeRect.width, from: .minXEdge)

        // Create thumb wireframe:
        let radius = wireframeRect.height * 0.5
        let thumbFrame = CGRect(x: left.maxX, y: left.minY, width: wireframeRect.height, height: wireframeRect.height)
            .offsetBy(dx: -radius, dy: 0)

        let thumb = builder.createShapeWireframe(
            id: thumbWireframeID,
            frame: thumbFrame,
            borderColor: isEnabled ? SystemColors.secondarySystemFill : SystemColors.tertiarySystemFill,
            borderWidth: 1,
            backgroundColor: isEnabled ? (thumbTintColor ?? UIColor.white.cgColor) : SystemColors.tertiarySystemBackground,
            cornerRadius: radius,
            opacity: attributes.alpha
        )

        // Create min track wireframe:
        let leftTrackFrame = left.divided(atDistance: 3, from: .minYEdge)
            .slice
            .putInside(left, horizontalAlignment: .left, verticalAlignment: .middle)

        let leftTrack = builder.createShapeWireframe(
            id: minTrackWireframeID,
            frame: leftTrackFrame,
            borderColor: nil,
            borderWidth: nil,
            backgroundColor: minTrackTintColor ?? SystemColors.tintColor,
            cornerRadius: 0,
            opacity: isEnabled ? attributes.alpha : 0.5
        )

        // Create max track wireframe:
        let rightTrackFrame = right.divided(atDistance: 3, from: .minYEdge)
            .slice
            .putInside(right, horizontalAlignment: .left, verticalAlignment: .middle)

        let rightTrack = builder.createShapeWireframe(
            id: maxTrackWireframeID,
            frame: rightTrackFrame,
            borderColor: nil,
            borderWidth: nil,
            backgroundColor: maxTrackTintColor ?? SystemColors.tertiarySystemFill,
            cornerRadius: 0,
            opacity: isEnabled ? attributes.alpha : 0.5
        )

        if attributes.hasAnyAppearance {
            // Create background wireframe only if view declares visible background
            let backgorund = builder.createShapeWireframe(id: backgroundWireframeID, frame: wireframeRect, attributes: attributes)

            return [backgorund, leftTrack, rightTrack, thumb]
        } else {
            return [leftTrack, rightTrack, thumb]
        }
    }
}