import MapKit
import SwiftUI

struct AddPlaceView: View {
    @Binding var isPresented: Bool

    @Environment(PlannerStore.self) private var store
    @State private var search = PlaceSearch()
    @State private var query = ""
    @State private var resolving: MKLocalSearchCompletion?
    @State private var errorMessage: String?
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("City, town, or time zone", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($fieldFocused)
                .onChange(of: query) { _, newValue in
                    errorMessage = nil
                    search.update(query: newValue)
                }
                .onSubmit(addFirst)

            List {
                if !search.completions.isEmpty {
                    Section("Places") {
                        ForEach(search.completions, id: \.self) { completion in
                            Button { add(completion) } label: {
                                row(title: completion.title, detail: completion.subtitle, busy: resolving == completion)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !search.zoneMatches.isEmpty {
                    Section("Time zones") {
                        ForEach(search.zoneMatches) { place in
                            Button { finish(place) } label: {
                                row(title: place.name, detail: place.detail, busy: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.inset)
            .overlay {
                if query.isEmpty {
                    Text("Type any city or town — it keeps its own name\neven when its time zone is named after another city.")
                        .multilineTextAlignment(.center)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding()
                } else if search.completions.isEmpty && search.zoneMatches.isEmpty && search.failed {
                    Text("No matches. City search needs a network connection.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(12)
        .frame(width: 380, height: 360)
        .onAppear { fieldFocused = true }
    }

    private func row(title: String, detail: String, busy: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if busy { ProgressView().controlSize(.small) }
        }
        .contentShape(.rect)
    }

    private func addFirst() {
        if let first = search.completions.first {
            add(first)
        } else if let first = search.zoneMatches.first {
            finish(first)
        }
    }

    private func add(_ completion: MKLocalSearchCompletion) {
        guard resolving == nil else { return }
        resolving = completion
        Task {
            defer { resolving = nil }
            do {
                finish(try await search.resolve(completion))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func finish(_ place: Place) {
        store.add(place)
        isPresented = false
    }
}
