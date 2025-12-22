import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite("UserDefaultsCredentialStore Tests")
struct UserDefaultsCredentialStoreTests {

    // Use a unique suite name to avoid conflicts with other tests
    private let testSuiteName = "com.claudebar.test.credentials.\(UUID().uuidString)"

    private func makeStore() -> UserDefaultsCredentialStore {
        let defaults = UserDefaults(suiteName: testSuiteName)!
        return UserDefaultsCredentialStore(defaults: defaults)
    }

    private func cleanupDefaults() {
        UserDefaults().removePersistentDomain(forName: testSuiteName)
    }

    // MARK: - Save Tests

    @Test("save stores value in UserDefaults")
    func saveStoresValue() {
        // Given
        let store = makeStore()
        defer { cleanupDefaults() }

        // When
        store.save("test-token", forKey: "test-key")

        // Then
        let retrieved = store.get(forKey: "test-key")
        #expect(retrieved == "test-token")
    }

    @Test("save overwrites existing value")
    func saveOverwritesExistingValue() {
        // Given
        let store = makeStore()
        defer { cleanupDefaults() }
        store.save("old-token", forKey: "test-key")

        // When
        store.save("new-token", forKey: "test-key")

        // Then
        let retrieved = store.get(forKey: "test-key")
        #expect(retrieved == "new-token")
    }

    @Test("save handles empty string")
    func saveHandlesEmptyString() {
        // Given
        let store = makeStore()
        defer { cleanupDefaults() }

        // When
        store.save("", forKey: "test-key")

        // Then
        let retrieved = store.get(forKey: "test-key")
        #expect(retrieved == "")
    }

    // MARK: - Get Tests

    @Test("get returns nil for non-existent key")
    func getReturnsNilForNonExistentKey() {
        // Given
        let store = makeStore()
        defer { cleanupDefaults() }

        // When
        let retrieved = store.get(forKey: "non-existent-key")

        // Then
        #expect(retrieved == nil)
    }

    @Test("get returns stored value")
    func getReturnsStoredValue() {
        // Given
        let store = makeStore()
        defer { cleanupDefaults() }
        store.save("my-secret-token", forKey: "github-token")

        // When
        let retrieved = store.get(forKey: "github-token")

        // Then
        #expect(retrieved == "my-secret-token")
    }

    // MARK: - Delete Tests

    @Test("delete removes stored value")
    func deleteRemovesStoredValue() {
        // Given
        let store = makeStore()
        defer { cleanupDefaults() }
        store.save("to-be-deleted", forKey: "delete-key")

        // When
        store.delete(forKey: "delete-key")

        // Then
        let retrieved = store.get(forKey: "delete-key")
        #expect(retrieved == nil)
    }

    @Test("delete does not throw for non-existent key")
    func deleteDoesNotThrowForNonExistentKey() {
        // Given
        let store = makeStore()
        defer { cleanupDefaults() }

        // When/Then - should not throw
        store.delete(forKey: "non-existent-key")
    }

    // MARK: - Exists Tests

    @Test("exists returns false for non-existent key")
    func existsReturnsFalseForNonExistentKey() {
        // Given
        let store = makeStore()
        defer { cleanupDefaults() }

        // When
        let exists = store.exists(forKey: "non-existent")

        // Then
        #expect(exists == false)
    }

    @Test("exists returns true for stored value")
    func existsReturnsTrueForStoredValue() {
        // Given
        let store = makeStore()
        defer { cleanupDefaults() }
        store.save("some-value", forKey: "exists-key")

        // When
        let exists = store.exists(forKey: "exists-key")

        // Then
        #expect(exists == true)
    }

    @Test("exists returns false after delete")
    func existsReturnsFalseAfterDelete() {
        // Given
        let store = makeStore()
        defer { cleanupDefaults() }
        store.save("temp-value", forKey: "temp-key")
        store.delete(forKey: "temp-key")

        // When
        let exists = store.exists(forKey: "temp-key")

        // Then
        #expect(exists == false)
    }

    // MARK: - Integration Tests

    @Test("full lifecycle: save, get, exists, delete")
    func fullLifecycle() {
        // Given
        let store = makeStore()
        defer { cleanupDefaults() }

        // Initially doesn't exist
        #expect(store.exists(forKey: "lifecycle-key") == false)
        #expect(store.get(forKey: "lifecycle-key") == nil)

        // Save
        store.save("lifecycle-value", forKey: "lifecycle-key")
        #expect(store.exists(forKey: "lifecycle-key") == true)
        #expect(store.get(forKey: "lifecycle-key") == "lifecycle-value")

        // Update
        store.save("updated-value", forKey: "lifecycle-key")
        #expect(store.get(forKey: "lifecycle-key") == "updated-value")

        // Delete
        store.delete(forKey: "lifecycle-key")
        #expect(store.exists(forKey: "lifecycle-key") == false)
        #expect(store.get(forKey: "lifecycle-key") == nil)
    }

    @Test("multiple keys are independent")
    func multipleKeysAreIndependent() {
        // Given
        let store = makeStore()
        defer { cleanupDefaults() }

        // When
        store.save("value1", forKey: "key1")
        store.save("value2", forKey: "key2")
        store.delete(forKey: "key1")

        // Then
        #expect(store.get(forKey: "key1") == nil)
        #expect(store.get(forKey: "key2") == "value2")
    }
}
