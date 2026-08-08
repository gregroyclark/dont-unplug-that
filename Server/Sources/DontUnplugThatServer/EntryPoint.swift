import Vapor

@main
enum DontUnplugThatServerEntryPoint {
    static func main() async throws {
        var environment = try Environment.detect()
        try LoggingSystem.bootstrap(from: &environment)

        let application = try await Application.make(environment)
        do {
            try configure(application)
            try await application.execute()
            try await application.asyncShutdown()
        } catch {
            try? await application.asyncShutdown()
            throw error
        }
    }
}
