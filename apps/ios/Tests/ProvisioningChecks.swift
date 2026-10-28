import Foundation

@main
struct ProvisioningChecks {
    static func main() {
        precondition(Provisioning.isMissing(status: 404, body: Data(#"{"error":"no_tenant"}"#.utf8)))
        precondition(!Provisioning.isMissing(status: 404, body: Data("not found".utf8)))   // workspace exists, our route doesn't (yet)
        precondition(!Provisioning.isMissing(status: 502, body: Data("no_tenant".utf8)))
        precondition(!Provisioning.isMissing(status: 200, body: Data()))
        print("ProvisioningChecks passed")
    }
}
