import Foundation
import SwiftRex
import Combine

// MARK: - ACTIONS
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
    var inputData: InputData? = nil
    var error: OAuthError? = nil
    
    static let empty: OAuthState = .init(userData: UserState())
    
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
        let state = getState()
        switch action {
        case .signIn:
            if let providerID = state.inputData?.providerID,
               let identityToken = state.inputData?.identityToken,
               let nonce = state.inputData?.nonce {
                let result = provider.signIn(
                    providerID: providerID,
                    identityToken: identityToken,
                    nonce: nonce
                )
                switch result {
                case .success: output?.dispatch(.success)
                case .failure: output?.dispatch(.failure)
                }
            }
        case .signOut: return
        default:
            return
        }
    }
}
