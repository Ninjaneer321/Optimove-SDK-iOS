//  Copyright © 2019 Optimove. All rights reserved.

import XCTest
@testable import OptimoveCore

class MockKeyValueStorage: KeyValueStorage {
    var assertFunction: ((_ value: Any?, _ key: StorageKey) -> Void)?
    var state: [StorageKey: Any?] = [:]

    func set(value: Any?, key: StorageKey) {
        state[key] = value
        self.assertFunction?(value, key)
    }

    func value(for key: StorageKey) -> Any? {
        return state[key] ?? nil
    }

    subscript<T>(key: StorageKey) -> T? {
        get {
            return value(for: key) as? T
        }
        set(newValue) {
            set(value: newValue, key: key)
        }
    }
}

class MockFileStorage: FileStorage {

    var storage: [String: Data] = [:]

    func isExist(fileName: String, isGroupContainer: Bool) -> Bool {
        return storage[fileName] != nil
    }

    func save<T: Codable>(data: T, toFileName: String, isGroupContainer: Bool) throws {
        storage[toFileName] = try JSONEncoder().encode(data)
    }

    func saveData(data: Data, toFileName: String, isGroupContainer: Bool) throws {
        storage[toFileName] = data
    }

    func load<T: Codable>(fileName: String, isGroupContainer: Bool) throws -> T {
        return try JSONDecoder().decode(T.self, from: try unwrap(storage[fileName]))
    }

    func loadData(fileName: String, isGroupContainer: Bool) throws -> Data {
        return try unwrap(storage[fileName])
    }

    func delete(fileName: String, isGroupContainer: Bool) throws {
        return storage[fileName] = nil
    }

}

class KeyValueStorageTests: XCTestCase {

    var storage: OptimoveStorage!
    let stub_data = Data(capacity: 42)

    override func setUp() {

        storage = StorageFacade(
            groupedStorage: MockKeyValueStorage(),
            sharedStorage: MockKeyValueStorage(),
            fileStorage: MockFileStorage()
        )
    }

    // MARK: Throwable

    func test_customerID() {
        // when
        storage.customerID = StubVariables.string

        // then
        XCTAssertNoThrow(try storage.getCustomerID())
    }

    func test_no_customerID() {
        // when
        storage.customerID = nil

        // then
        XCTAssertThrowsError(try storage.getCustomerID())
    }

    func test_initialVisitorId() {
        // when
        storage.initialVisitorId = StubVariables.string

        // then
        XCTAssertNoThrow(try storage.getInitialVisitorId())
    }

    func test_no_initialVisitorId() {
        // when
        storage.initialVisitorId = nil

        // then
        XCTAssertThrowsError(try storage.getInitialVisitorId())
    }

    func test_tenantToken() {
        // when
        storage.tenantToken = StubVariables.string

        // then
        XCTAssertNoThrow(try storage.getTenantToken())
    }

    func test_no_tenantToken() {
        // when
        storage.tenantToken = nil

        // then
        XCTAssertThrowsError(try storage.getTenantToken())
    }

    func test_visitorID() {
        // when
        storage.visitorID = StubVariables.string

        // then
        XCTAssertNoThrow(try storage.getVisitorID())
    }

    func test_no_visitorID() {
        // when
        storage.visitorID = nil

        // then
        XCTAssertThrowsError(try storage.getVisitorID())
    }

    func test_version() {
        // when
        storage.version = StubVariables.string

        // then
        XCTAssertNoThrow(try storage.getVersion())
    }

    func test_no_version() {
        // when
        storage.version = nil

        // then
        XCTAssertThrowsError(try storage.getVersion())
    }

    func test_userEmail() {
        // when
        storage.userEmail = StubVariables.string

        // then
        XCTAssertNoThrow(try storage.getUserEmail())
    }

    func test_no_userEmail() {
        // when
        storage.userEmail = nil

        // then
        XCTAssertThrowsError(try storage.getUserEmail())
    }

    func test_apnsToken() {
        // when
        storage.apnsToken = stub_data

        // then
        XCTAssertNoThrow(try storage.getApnsToken())
    }

    func test_no_apnsToken() {
        // when
        storage.apnsToken = nil

        // then
        XCTAssertThrowsError(try storage.getApnsToken())
    }

    func test_firstRunTimestamp() {
        // when
        storage.firstRunTimestamp = 42

        // then
        XCTAssertNoThrow(try storage.getFirstRunTimestamp())
    }

    func test_no_firstRunTimestamp() {
        // when
        storage.firstVisitTimestamp = nil

        // then
        XCTAssertThrowsError(try storage.getFirstRunTimestamp())
    }

    func test_configurationEndPoint() {
        // when
        storage.configurationEndPoint = StubVariables.url

        // then
        XCTAssertNoThrow(try storage.getConfigurationEndPoint())
    }

    func test_no_configurationEndPoint() {
        // when
        storage.configurationEndPoint = nil

        // then
        XCTAssertThrowsError(try storage.getConfigurationEndPoint())
    }

    func test_siteId() {
        // when
        storage.siteID = StubVariables.int

        // then
        XCTAssertNoThrow(try storage.getSiteID())
    }

    func test_error_description() {
        // when
        storage.siteID = nil

        // then
        do {
            _ = try storage.getSiteID()
            XCTFail("Should be fail")
        } catch {
            XCTAssert(error.localizedDescription == "StorageError: No value for key siteID")
        }
    }

    func test_no_siteId() {
        // when
        storage.siteID = nil

        // then
        XCTAssertThrowsError(try storage.getSiteID())
    }

    // MARK: Simple

    func test_isSettingUserSuccess() {
        // when
        let value = StubVariables.bool
        storage.isSettingUserSuccess = value

        // then
        XCTAssert(storage.isSettingUserSuccess == value)
    }

    func test_no_isSettingUserSuccess() {
        // then
        XCTAssertNil(storage.isSettingUserSuccess)
    }

    func test_optFlag_set() {
        // when
        let value = StubVariables.bool
        storage.optFlag = value

        // then
        XCTAssert(storage.optFlag == value)
    }

    func test_optFlag_get() {
        // then
        XCTAssert(storage.optFlag == false)
    }

    func test_realtimeSetUserIdFailed() {
        // when
        let value = StubVariables.bool
        storage.realtimeSetUserIdFailed = value

        // then
        XCTAssert(storage.realtimeSetUserIdFailed == value)
    }

    func test_no_realtimeSetUserIdFailed() {
        // then
        XCTAssert(storage.realtimeSetUserIdFailed == false)
    }

    func test_realtimeSetEmailFailed() {
        // when
        let value = StubVariables.bool
        storage.realtimeSetEmailFailed = value

        // then
        XCTAssert(storage.realtimeSetEmailFailed == value)
    }

    func test_no_realtimeSetEmailFailed() {
        // then
        XCTAssert(storage.realtimeSetEmailFailed == false)
    }

    func test_push_campaign_disabled_default_value() {
        // then
        XCTAssert(!storage.arePushCampaignsDisabled)
    }

    func test_push_campaign_disabled_toggle() {
        storage.arePushCampaignsDisabled.toggle()

        // then
        XCTAssert(storage.arePushCampaignsDisabled)
    }
}
