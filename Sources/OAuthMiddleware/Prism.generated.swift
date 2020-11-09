// Generated using Sourcery 1.0.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all

import Foundation
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif

extension OAuthAction {
    public var signIn: Void? {
        get {
            guard case .signIn = self else { return nil }
            return ()
        }
    }

    public var isSignIn: Bool {
        self.signIn != nil
    }

    public var signOut: Void? {
        get {
            guard case .signOut = self else { return nil }
            return ()
        }
    }

    public var isSignOut: Bool {
        self.signOut != nil
    }

    public var success: Void? {
        get {
            guard case .success = self else { return nil }
            return ()
        }
    }

    public var isSuccess: Bool {
        self.success != nil
    }

    public var failure: Void? {
        get {
            guard case .failure = self else { return nil }
            return ()
        }
    }

    public var isFailure: Bool {
        self.failure != nil
    }

}
