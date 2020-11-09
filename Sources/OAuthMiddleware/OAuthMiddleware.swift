import Foundation
import SwiftRex
import os.log

// MARK: - ACTIONS
//sourcery: Prism
public enum OAuthAction {
    case signIn
    case signOut
    case success
    case failure
}

// MARK: - STATE
public struct OAuthState: Equatable {
    var userData: UserState
    var providerData: [UserState]? = nil
    var metadata: MetadataState? = nil
    public var inputData: InputData? = nil
    var error: OAuthError? = nil
    
    public static let empty: OAuthState = .init(userData: UserState())
    
    public init(
        userData: UserState,
        providerData: [UserState]? = nil,
        metadata: MetadataState? = nil,
        inputData: InputData? = nil
        ) {
        self.userData = userData
        self.providerData = providerData
        self.metadata = metadata
        self.inputData = inputData
    }
}

public struct UserState: Equatable {
    var providerID: String = ""
    var uid: String = ""
    var displayName: String? = nil
    var photoURL: URL? = nil
    var email: String? = nil
    var phoneNumber: String? = nil
    var tenantID: String? = nil
    var profile: [String: NSObject]? = nil
    var username: String? = nil
    var isNewUser: Bool? = nil
}

public struct MetadataState: Equatable {
    var lastSignInDate: Date?
    var creationDate: Date?
}

public struct InputData: Equatable {
    var identityToken: String
    var nonce: String
    var providerID: String
}

public enum OAuthError: Error {
    case InvalidCredential
}

// MARK: - PROTOCOL
public protocol OAuthFlowOperations {
    func signIn(providerID: String, identityToken: String, nonce: String) -> Result<Void, OAuthError>
    func signOut() -> Result<Void, OAuthError>
}

// MARK: - MIDDLEWARE
public class OAuthMiddleware: Middleware {
    public typealias InputActionType = OAuthAction
    public typealias OutputActionType = OAuthAction
    public typealias StateType = OAuthState
    
    private static let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "OauthMiddleware")

    private var output: AnyActionHandler<OutputActionType>? = nil
    private var getState: () -> StateType = {  StateType.empty }

    private var provider: OAuthFlowOperations
    
    public init(provider: OAuthFlowOperations) {
        self.provider = provider
    }
    
    public func receiveContext(getState: @escaping GetState<StateType>, output: AnyActionHandler<OutputActionType>) {
        self.getState = getState
        self.output = output

    }
    
    public func handle(
        action: InputActionType,
        from dispatcher: ActionSource,
        afterReducer : inout AfterReducer
    ) {
        switch action {
        case .signOut:
            let result = provider.signOut()
            switch result {
            case .success: output?.dispatch(.success)
            case .failure:
                os_log(
                    "Failure to sign out...",
                    log: OAuthMiddleware.logger,
                    type: .debug
                )
                output?.dispatch(.failure)
            }
        default:
            return
        }

        afterReducer = .do { [self] in
            let newState = getState()
            os_log(
                "Calling afterReducer closure...",
                log: OAuthMiddleware.logger,
                type: .debug
            )
            switch action {
            case .signIn:
                if let providerID = newState.inputData?.providerID,
                   let identityToken = newState.inputData?.identityToken,
                   let nonce = newState.inputData?.nonce {
                    os_log(
                        "About to exchange identity token...",
                        log: OAuthMiddleware.logger,
                        type: .debug
                    )
                    let result = provider.signIn(
                        providerID: providerID,
                        identityToken: identityToken,
                        nonce: nonce
                    )
                    switch result {
                    case .success:
                        os_log(
                            "Identity token exchange successful...",
                            log: OAuthMiddleware.logger,
                            type: .debug
                        )
                        output?.dispatch(.success)
                    case .failure:
                        os_log(
                            "Identity token exchange failed...",
                            log: OAuthMiddleware.logger,
                            type: .debug
                        )
                        output?.dispatch(.failure)
                    }
                }
            case .signOut: return
            default:
                return
            }
        }
    }
}
