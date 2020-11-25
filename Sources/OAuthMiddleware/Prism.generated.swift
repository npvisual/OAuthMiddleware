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
    public var signIn: (String, String, String)? {
        get {
            guard case let .signIn(associatedValue0, associatedValue1, associatedValue2) = self else { return nil }
            return (associatedValue0, associatedValue1, associatedValue2)
        }
        set {
            guard case .signIn = self, let newValue = newValue else { return }
            self = .signIn(newValue.0, newValue.1, newValue.2)
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

    public var loggedIn: OAuthState? {
        get {
            guard case let .loggedIn(associatedValue0) = self else { return nil }
            return (associatedValue0)
        }
        set {
            guard case .loggedIn = self, let newValue = newValue else { return }
            self = .loggedIn(newValue)
        }
    }

    public var isLoggedIn: Bool {
        self.loggedIn != nil
    }

    public var loggedOut: Void? {
        get {
            guard case .loggedOut = self else { return nil }
            return ()
        }
    }

    public var isLoggedOut: Bool {
        self.loggedOut != nil
    }

    public var registration: Void? {
        get {
            guard case .registration = self else { return nil }
            return ()
        }
    }

    public var isRegistration: Bool {
        self.registration != nil
    }

    public var failure: OAuthError? {
        get {
            guard case let .failure(associatedValue0) = self else { return nil }
            return (associatedValue0)
        }
        set {
            guard case .failure = self, let newValue = newValue else { return }
            self = .failure(newValue)
        }
    }

    public var isFailure: Bool {
        self.failure != nil
    }

}
