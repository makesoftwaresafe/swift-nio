//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import Foundation
import XCTest
import NIOCore
import NIOConcurrencyHelpers

// FIXME: Duplicated with NIO
func assert(_ condition: @autoclosure () -> Bool, within time: TimeAmount, testInterval: TimeAmount? = nil, _ message: String = "condition not satisfied in time", file: StaticString = #file, line: UInt = #line) {
    let testInterval = testInterval ?? TimeAmount.nanoseconds(time.nanoseconds / 5)
    let endTime = NIODeadline.now() + time

    repeat {
        if condition() { return }
        usleep(UInt32(testInterval.nanoseconds / 1000))
    } while (NIODeadline.now() < endTime)

    if !condition() {
        XCTFail(message, file: (file), line: line)
    }
}

extension EventLoopFuture {
    var isFulfilled: Bool {
        if self.eventLoop.inEventLoop {
            // Easy, we're on the EventLoop. Let's just use our knowledge that we run completed future callbacks
            // immediately.
            var fulfilled = false
            self.whenComplete { _ in
                fulfilled = true
            }
            return fulfilled
        } else {
            let lock = Lock()
            let group = DispatchGroup()
            var fulfilled = false // protected by lock

            group.enter()
            self.eventLoop.execute {
                let isFulfilled = self.isFulfilled // This will now enter the above branch.
                lock.withLock {
                    fulfilled = isFulfilled
                }
                group.leave()
            }
            group.wait() // this is very nasty but this is for tests only, so...
            return lock.withLock { fulfilled }
        }
    }
}

internal func XCTAssertCompareAndSwapSucceeds<Type: NIOAtomicPrimitive>(
    storage: NIOAtomic<Type>,
    expected: Type,
    desired: Type,
    file: StaticString = #file,
    line: UInt = #line
) {
    let swapped = storage.compareAndExchange(expected: expected, desired: desired)
    XCTAssertTrue(swapped, file: file, line: line)
}
