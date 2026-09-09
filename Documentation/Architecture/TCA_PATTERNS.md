# TCA Patterns in Gjuha

Reference guide for consistent TCA usage across the project.

---

## Feature Module Template

```swift
// Features/FeatureName/FeatureNameFeature.swift

@Reducer
struct FeatureNameFeature {
    @ObservableState
    struct State: Equatable {
        // All state the view needs to render
    }

    enum Action {
        // BindableAction for features with @Bindable views
        // case binding(BindingAction<State>)
    }

    @Dependency(\.someRepository) var someRepository

    var body: some ReducerOf<Self> {
        // BindingReducer() if using @Bindable views
        Reduce { state, action in
            switch action {
            // Handle all cases
            }
        }
    }
}
```

---

## Child Feature Composition

```swift
@Reducer
struct ParentFeature {
    @ObservableState
    struct State: Equatable {
        var child = ChildFeature.State()
    }

    enum Action {
        case child(ChildFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.child, action: \.child) {
            ChildFeature()
        }
        Reduce { state, action in
            switch action {
            case .child(.someChildAction):
                // React to child actions
                return .none
            case .child:
                return .none
            }
        }
    }
}
```

---

## Navigation Stack

```swift
// Drill-down navigation with StackState
@Reducer
struct RootFeature {
    @ObservableState
    struct State: Equatable {
        var path = StackState<Path.State>()
    }

    enum Action {
        case path(StackActionOf<Path>)
    }

    @Reducer
    enum Path {
        case detail(DetailFeature)
        case settings(SettingsFeature)
    }
}

// In the view:
NavigationStackStore(store.scope(state: \.path, action: \.path)) {
    RootView(store: ...)
} destination: { store in
    switch store.case {
    case .detail(let s): DetailView(store: s)
    case .settings(let s): SettingsView(store: s)
    }
}
```

---

## Async Effects Pattern

```swift
case .loadData:
    state.isLoading = true
    return .run { send in
        // Async work - never touch state directly here
        let result = await someRepository.fetch()
        await send(.dataLoaded(result))
    }

case .dataLoaded(let result):
    state.isLoading = false
    state.items = result
    return .none
```

---

## Dependency Registration

```swift
// In the repository file:
private enum MyRepositoryKey: DependencyKey {
    static let liveValue: any MyRepository = LiveMyRepository()
    static let testValue: any MyRepository = MockMyRepository()
}

extension DependencyValues {
    var myRepository: any MyRepository {
        get { self[MyRepositoryKey.self] }
        set { self[MyRepositoryKey.self] = newValue }
    }
}

// Usage in reducer:
@Dependency(\.myRepository) var myRepository
```

---

## Testing Reducers

```swift
@Test
func testSomeAction() async {
    let store = TestStore(initialState: SomeFeature.State()) {
        SomeFeature()
    } withDependencies: {
        $0.myRepository = MockMyRepository()
    }

    await store.send(.someAction) {
        $0.someState = expectedValue
    }

    await store.receive(.resultAction) {
        $0.otherState = anotherValue
    }
}
```
