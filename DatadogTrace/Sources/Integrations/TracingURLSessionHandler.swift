/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation
import DatadogInternalFork

internal struct TracingURLSessionHandler: DatadogURLSessionHandler {
    /// Integration with Core Context.
    let contextReceiver: ContextMessageReceiver
    /// Tracing sampler used to sample traces generated by the SDK.
    let tracingSampler: Sampler
    /// First party hosts defined by the user.
    let firstPartyHosts: FirstPartyHosts

    weak var tracer: DatadogTracer?

    init(
        tracer: DatadogTracer,
        contextReceiver: ContextMessageReceiver,
        tracingSampler: Sampler,
        firstPartyHosts: FirstPartyHosts
    ) {
        self.tracer = tracer
        self.contextReceiver = contextReceiver
        self.tracingSampler = tracingSampler
        self.firstPartyHosts = firstPartyHosts
    }

    func modify(request: URLRequest, headerTypes: Set<DatadogInternalFork.TracingHeaderType>) -> URLRequest {
        guard let tracer = tracer else {
            return request
        }

        let spanContext = tracer.createSpanContext()

        var request = request
        headerTypes.forEach {
            let writer: TracePropagationHeadersWriter
            switch $0 {
            case .datadog:
                writer = HTTPHeadersWriter(sampler: tracingSampler)
            case .b3:
                writer = B3HTTPHeadersWriter(
                    sampler: tracingSampler,
                    injectEncoding: .single
                )
            case .b3multi:
                writer = B3HTTPHeadersWriter(
                    sampler: tracingSampler,
                    injectEncoding: .multiple
                )
            case .tracecontext:
                writer = W3CHTTPHeadersWriter(sampler: tracingSampler)
            }

            writer.write(
                traceID: spanContext.traceID,
                spanID: spanContext.spanID,
                parentSpanID: spanContext.parentSpanID
            )

            writer.traceHeaderFields.forEach { field, value in
                request.setValue(value, forHTTPHeaderField: field)
            }
        }

        return request
    }

    func interceptionDidStart(interception: DatadogInternalFork.URLSessionTaskInterception) {
        // no-op
    }

    func interceptionDidComplete(interception: DatadogInternalFork.URLSessionTaskInterception) {
        guard
            interception.isFirstPartyRequest,  // `Span` should be only send for 1st party requests
            interception.origin != "rum", // if that request was tracked as RUM resource, the RUM backend will create the span on our behalf
            let tracer = tracer,
            let resourceMetrics = interception.metrics,
            let resourceCompletion = interception.completion
        else {
            return
        }

        let span: OTSpan

        if let trace = interception.trace {
            let context = DDSpanContext(
                traceID: trace.traceID,
                spanID: trace.spanID,
                parentSpanID: trace.parentSpanID,
                baggageItems: .init()
            )

            span = tracer.startSpan(
                spanContext: context,
                operationName: "urlsession.request",
                startTime: resourceMetrics.fetch.start
            )
        } else if tracingSampler.sample() {
            // Span context may not be injected on iOS13+ if `URLSession.dataTask(...)` for `URL`
            // was used to create the session task.
            span = tracer.startSpan(
                operationName: "urlsession.request",
                startTime: resourceMetrics.fetch.start
            )
        } else {
            return
        }

        let url = interception.request.url?.absoluteString ?? "unknown_url"

        if let requestUrl = interception.request.url {
            var urlComponent = URLComponents(url: requestUrl, resolvingAgainstBaseURL: true)
            urlComponent?.query = nil
            let resourceUrl = urlComponent?.url?.absoluteString ?? "unknown_url"
            span.setTag(key: SpanTags.resource, value: resourceUrl)
        }
        let method = interception.request.httpMethod ?? "unknown_method"
        span.setTag(key: OTTags.httpUrl, value: url)
        span.setTag(key: OTTags.httpMethod, value: method)

        if let error = resourceCompletion.error {
            span.setError(error, file: "", line: 0)
        }

        if let httpResponse = resourceCompletion.httpResponse {
            let httpStatusCode = httpResponse.statusCode
            span.setTag(key: OTTags.httpStatusCode, value: httpStatusCode)
            if let error = httpResponse.asClientError() {
                span.setError(error, file: "", line: 0)
                if httpStatusCode == 404 {
                    span.setTag(key: SpanTags.resource, value: "404")
                }
            }
        }

        if let history = contextReceiver.context.applicationStateHistory {
            let appStateHistory = history.take(
                between: resourceMetrics.fetch.start...resourceMetrics.fetch.end
            )

            span.setTag(key: SpanTags.foregroundDuration, value: appStateHistory.foregroundDuration.toNanoseconds)

            let didStartInBackground = appStateHistory.initialSnapshot.state == .background
            let doesEndInBackground = appStateHistory.currentSnapshot.state == .background
            span.setTag(key: SpanTags.isBackground, value: didStartInBackground || doesEndInBackground)
        }

        span.finish(at: resourceMetrics.fetch.end)
    }
}

private extension HTTPURLResponse {
    func asClientError() -> Error? {
        // 4xx Client Errors
        guard statusCode >= 400 && statusCode < 500 else {
            return nil
        }
        let message = "\(statusCode) " + HTTPURLResponse.localizedString(forStatusCode: statusCode)
        return NSError(domain: "HTTPURLResponse", code: statusCode, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
