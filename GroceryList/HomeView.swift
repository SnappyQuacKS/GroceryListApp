import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingAddList = false
    @State private var listToDelete: GroceryList? = nil
    @State private var listToRename: GroceryList? = nil
    @State private var renameText = ""

    private var deleteAlertShown: Binding<Bool> {
        Binding(get: { listToDelete != nil }, set: { if !$0 { listToDelete = nil } })
    }

    private var renameAlertShown: Binding<Bool> {
        Binding(get: { listToRename != nil }, set: { if !$0 { listToRename = nil } })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinedPaperBackground(showMargin: false)

                if store.lists.isEmpty {
                    emptyState
                } else {
                    listContent
                }

                // Floating action button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button { showingAddList = true } label: {
                            Image(systemName: "plus")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color(red: 0.15, green: 0.55, blue: 0.38))
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.22), radius: 6, x: 0, y: 3)
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 12)
                    }
                }
            }
            .navigationTitle("My Lists")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { listId in
                ListDetailView(listId: listId)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("My Lists")
                        .font(.custom("Kreon-Bold", size: 40))
                }
            }
            .alert("Delete List", isPresented: deleteAlertShown, presenting: listToDelete) { list in
                Button("Delete", role: .destructive) {
                    store.deleteList(list.listId)
                    listToDelete = nil
                }
                Button("Cancel", role: .cancel) { listToDelete = nil }
            } message: { list in
                Text("Delete \"\(list.listName)\"? Child lists will be re-parented automatically.")
            }
            .alert("Rename List", isPresented: renameAlertShown) {
                TextField("List name", text: $renameText)
                Button("Save") {
                    let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty, let list = listToRename {
                        store.renameList(list.listId, to: trimmed)
                    }
                    listToRename = nil
                }
                Button("Cancel", role: .cancel) { listToRename = nil }
            }
        }
        .sheet(isPresented: $showingAddList) {
            AddListSheet().environment(store)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 52))
                .foregroundColor(Color.secondary.opacity(0.5))
            Text("No lists yet").font(.custom("Kreon-Bold", size: 20)).foregroundColor(.secondary)
            Text("Tap + to create your first grocery list")
                .font(.custom("Kreon-Regular", size: 15)).foregroundColor(Color.secondary.opacity(0.7))
        }
    }

    private var listContent: some View {
        List {
            ForEach(store.sortedLists) { list in
                NavigationLink(value: list.listId) {
                    ListCardView(list: list)
                }
                .buttonStyle(PlainButtonStyle())
                .shadow(color: list.theme.accentColor(colorScheme).opacity(0.18), radius: 8, x: 0, y: 0)
                .shadow(color: list.theme.accentColor(colorScheme).opacity(0.08), radius: 16, x: 0, y: 0)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        listToRename = list
                        renameText = list.listName
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.blue)
                    Button {
                        store.duplicateAsDecoupledCopy(listId: list.listId)
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    .tint(.orange)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        listToDelete = list
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(Color.clear)
        .padding(.bottom, 72)
    }
}

// MARK: - List Card

struct ListCardView: View {
    let list: GroceryList
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    private var itemCount: Int {
        store.compileDisplayItems(listId: list.listId).count
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            list.theme.backgroundColor(colorScheme)

            // Ruled-paper lines
            GeometryReader { geo in
                VStack(spacing: 0) {
                    ForEach(0..<Int(geo.size.height / 22) + 2, id: \.self) { _ in
                        Spacer().frame(height: 21.5)
                        Rectangle().fill(list.theme.lineColor(colorScheme)).frame(height: 0.5)
                    }
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(list.listName)
                        .font(.custom("Kreon-Bold", size: 22))
                        .foregroundColor(list.theme.textColor(colorScheme))

                    if let parent = store.parentList(for: list) {
                        HStack(spacing: 4) {
                            Image(systemName: "link").font(.caption2)
                            Text("extends \(parent.listName)").font(.custom("Kreon-Regular", size: 12))
                        }
                        .foregroundColor(list.theme.textColor(colorScheme).opacity(0.65))
                    }

                    Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                        .font(.custom("Kreon-Regular", size: 13))
                        .foregroundColor(list.theme.textColor(colorScheme).opacity(0.50))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(minHeight: 74)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.18), lineWidth: 1))
    }
}

// MARK: - Add List Sheet

struct AddListSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var name = ""
    @State private var selectedParentId: String? = nil
    @State private var selectedTheme: ListTheme = .natural

    var body: some View {
        NavigationStack {
            Form {
                Section("List Name") {
                    TextField("e.g. List for 6/20", text: $name)
                }

                if !store.sortedLists.isEmpty {
                    Section {
                        Picker("Base List", selection: $selectedParentId) {
                            Text("None").tag(String?.none)
                            ForEach(store.sortedLists) { list in
                                Text(list.listName).tag(String?.some(list.listId))
                            }
                        }
                    } header: {
                        Text("Inherit From (Optional)")
                    } footer: {
                        Text("Child list will display its own items plus everything from the parent chain.")
                    }
                }

                Section("Color Theme") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                        ForEach(ListTheme.allCases, id: \.self) { theme in
                            Button { selectedTheme = theme } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8).fill(theme.backgroundColor(colorScheme)).frame(height: 42)
                                    if selectedTheme == theme {
                                        Image(systemName: "checkmark").font(.caption.bold()).foregroundColor(theme.textColor(colorScheme))
                                    }
                                }
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedTheme == theme ? theme.accentColor(colorScheme) : Color.gray.opacity(0.25),
                                            lineWidth: selectedTheme == theme ? 2 : 1))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.createList(name: name.trimmingCharacters(in: .whitespaces),
                                         parentId: selectedParentId, theme: selectedTheme)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
