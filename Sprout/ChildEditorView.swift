import SwiftUI

/// Add or edit a child profile (the story hero). Name, age (2–8), pronouns, and an optional
/// favorite thing that flavors the stories.
struct ChildEditorView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    /// nil = create a new child; otherwise edit the given one.
    let child: Child?

    @State private var name = ""
    @State private var age = 4
    @State private var pronouns: Pronouns = .they
    @State private var favoriteThing = ""

    private var isEditing: Bool { child != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Child") {
                    TextField("First name", text: $name)
                        .textInputAutocapitalization(.words)
                    Stepper("Age: \(age)", value: $age, in: 2...8)
                    Picker("Pronouns", selection: $pronouns) {
                        ForEach(Pronouns.allCases) { p in Text(p.label).tag(p) }
                    }
                }
                Section {
                    TextField("e.g. dinosaurs, the color blue", text: $favoriteThing)
                } header: {
                    Text("Loves (optional)")
                } footer: {
                    Text("We'll gently weave this into their stories.")
                }
            }
            .navigationTitle(isEditing ? "Edit child" : "Add child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let child else { return }
        name = child.name
        age = child.age
        pronouns = child.pronouns
        favoriteThing = child.favoriteThing ?? ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let fav = favoriteThing.trimmingCharacters(in: .whitespaces)
        if let child {
            appModel.updateChild(child, name: trimmedName, age: age,
                                 pronouns: pronouns, favoriteThing: fav)
        } else {
            appModel.createChild(name: trimmedName, age: age,
                                 pronouns: pronouns, favoriteThing: fav)
        }
        Haptics.success()
        dismiss()
    }
}
