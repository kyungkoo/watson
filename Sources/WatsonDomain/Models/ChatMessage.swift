import Foundation

public struct ChatMessage: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let role: Role
    public var content: String
    
    public enum Role: Sendable {
        case system
        case user
        case assistant
    }
    
    public init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}
