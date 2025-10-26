#if DEBUG
import Foundation

@MainActor
enum TripDataPreviewHarness {
    static func seedIfNeeded(using controller: TripDataController) async {
        await controller.makePreviewSeed()
    }

    static func makeInMemoryController() async -> TripDataController {
        let controller = TripDataController(inMemory: true)
        await seedIfNeeded(using: controller)
        return controller
    }
}
#endif
