import Foundation

@main
struct ConnectionProbe {
    static func main() throws {
        try MugshotClient().checkConnection()
        print("Signed Mugshot engine responded to PING. No camera scan was started.")
    }
}
