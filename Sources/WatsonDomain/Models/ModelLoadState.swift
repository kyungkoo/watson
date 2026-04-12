import Foundation

public enum ModelLoadState: Sendable, Equatable {
    case downloading(percent: Int)
    case finalizing
}
