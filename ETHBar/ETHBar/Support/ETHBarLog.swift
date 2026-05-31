import Foundation

enum ETHBarLog {
    enum Category: String {
        case provider = "Provider"
        case store = "Store"
        case webSocket = "WS"
    }

    static func debug(_ message: String, category: Category, separated: Bool = false) {
        #if DEBUG
        let output = "[ETHBar][\(category.rawValue)] \(message)"

        if separated {
            print("------------------")
            print(output)
            print("------------------")
        } else {
            print(output)
        }
        #endif
    }
}
