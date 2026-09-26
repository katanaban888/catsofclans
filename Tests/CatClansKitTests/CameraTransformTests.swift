import XCTest
import CatClansKit

final class CameraTransformTests: XCTestCase {
    func testFitShowsEntireMapInPhoneAndTabletViewports() {
        for viewport in [V2(667, 260), V2(1194, 750), V2(320, 600)] {
            let camera = MapCamera(worldSize: V2(944, 768), viewport: viewport)
            let top = camera.worldToScreen(V2(0, 0))
            let bottom = camera.worldToScreen(camera.worldSize)
            XCTAssertGreaterThanOrEqual(top.x, -0.0001)
            XCTAssertGreaterThanOrEqual(top.y, -0.0001)
            XCTAssertLessThanOrEqual(bottom.x, viewport.x + 0.0001)
            XCTAssertLessThanOrEqual(bottom.y, viewport.y + 0.0001)
        }
    }

    func testRoundTripAfterZoomAndPan() {
        for zoom in [1.0, 1.5, 2.75, 4] {
            var camera = MapCamera(worldSize: V2(800, 800), viewport: V2(700, 300), zoom: zoom)
            camera.pan(screenDelta: V2(-190, 90))
            for point in [V2(0, 0), V2(400, 340), V2(790, 799), V2(255, 612)] {
                let result = camera.screenToWorld(camera.worldToScreen(point))
                XCTAssertEqual(result.x, point.x, accuracy: 0.000001)
                XCTAssertEqual(result.y, point.y, accuracy: 0.000001)
            }
        }
    }

    func testPanAndZoomCannotLoseMap() {
        var camera = MapCamera(worldSize: V2(800, 800), viewport: V2(500, 300), zoom: 4)
        for delta in [V2(1e9, 1e9), V2(-1e9, -1e9)] {
            camera.pan(screenDelta: delta)
            let top = camera.worldToScreen(V2(0, 0))
            let bottom = camera.worldToScreen(camera.worldSize)
            XCTAssertLessThanOrEqual(top.x, 0.0001)
            XCTAssertLessThanOrEqual(top.y, 0.0001)
            XCTAssertGreaterThanOrEqual(bottom.x, 500 - 0.0001)
            XCTAssertGreaterThanOrEqual(bottom.y, 300 - 0.0001)
        }
        camera.setZoom(100)
        XCTAssertEqual(camera.zoom, 4)
        camera.setZoom(-100)
        XCTAssertEqual(camera.zoom, 1)
        XCTAssertEqual(camera.center, V2(400, 400))
    }

    func testResizeKeepsZoomAndHomeFocus() {
        var camera = MapCamera(worldSize: V2(944, 768), viewport: V2(667, 280), zoom: 2)
        camera.focus(V2(472, 384), zoom: 2)
        camera.resize(V2(1194, 700))
        XCTAssertEqual(camera.zoom, 2)
        XCTAssertEqual(camera.worldToScreen(V2(472, 384)), V2(597, 350))
    }

    func testNonFiniteUserInputIsIgnored() {
        var camera = MapCamera(worldSize: V2(800, 800), viewport: V2(700, 300))
        let before = camera
        camera.setZoom(.nan)
        camera.pan(screenDelta: V2(.infinity, 0))
        camera.focus(V2(0, .nan))
        camera.resize(V2(.nan, 0))
        XCTAssertEqual(camera, before)
    }

    func testDeploymentGhostAndSimulationUseIdenticalWorldPoint() {
        var camera = MapCamera(worldSize: V2(800, 800), viewport: V2(700, 300), zoom: 3)
        camera.pan(screenDelta: V2(90, -130))
        let screen = camera.worldToScreen(V2(234, 612))
        let point = BattleMapInput.deploymentPoint(screen: screen, camera: camera)!
        XCTAssertEqual(point.x, 11.7, accuracy: 0.000001)
        XCTAssertEqual(point.y, 30.6, accuracy: 0.000001)
        var state = GameState.newGame(seed: 7)
        state.army[UnitID.kitten.rawValue] = 1
        let sim = BattleSim(state: state, enemy: EnemyGenerator.base(difficulty: 1, seed: 7),
                            seed: 7, manualDeployment: true)!
        XCTAssertTrue(sim.deployNext(at: point))
        XCTAssertEqual(sim.units.last?.pos, point)
        XCTAssertEqual(BattleMapInput.deploymentPoint(world: V2(800, 800)), V2(39.5, 39.5))
        XCTAssertEqual(BattleMapInput.deploymentPoint(world: V2(0, 400)), V2(0.5, 20))
    }

    func testRejectsOutsideMapUpperHalfAndLetterboxing() {
        let camera = MapCamera(worldSize: V2(800, 800), viewport: V2(800, 300))
        XCTAssertNil(BattleMapInput.deploymentPoint(screen: V2(0, 220), camera: camera))
        for world in [V2(-1, 600), V2(801, 600), V2(500, 399), V2(500, 801), V2(.nan, 600)] {
            XCTAssertNil(BattleMapInput.deploymentPoint(world: world))
        }
    }
}
