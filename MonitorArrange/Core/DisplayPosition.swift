import Foundation

enum DisplayPosition: String, CaseIterable, Codable {
    case top
    case left
    case right
    case bottom

    var label: String {
        switch self {
        case .top: "위"
        case .left: "왼쪽"
        case .right: "오른쪽"
        case .bottom: "아래"
        }
    }

    var icon: String {
        switch self {
        case .top: "arrow.up.square"
        case .left: "arrow.left.square"
        case .right: "arrow.right.square"
        case .bottom: "arrow.down.square"
        }
    }

    /// 맞닿는 반대편 가장자리. 외장 화면에서 내장 화면을 향한 가장자리를 구할 때 쓴다.
    var opposite: DisplayPosition {
        switch self {
        case .top: .bottom
        case .bottom: .top
        case .left: .right
        case .right: .left
        }
    }
}
