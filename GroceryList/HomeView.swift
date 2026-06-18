import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
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
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.sortedLists) { list in
                    SwipeableListCard(
                        list: list,
                        onDelete: { listToDelete = list },
                        onRename: { listToRename = list; renameText = list.listName },
                        onDuplicate: { store.duplicateAsDecoupledCopy(listId: list.listId) }
                    )
                }
            }
            .padding()
            .padding(.bottom, 72)
        }
    }
}

// MARK: - Swipeable List Card

struct SwipeableListCard: View {
    let list: GroceryList
    let onDelete: () -> Void
    let onRename: () -> Void
    let onDuplicate: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var offset: CGFloat = 0
    @State private var lastOffset: CGFloat = 0
    @State private var navigateToDetail = false
    @State private var wasDragging = false
    private let revealWidth: CGFloat = 72

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button — width grows proportionally as card slides
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    offset = 0; lastOffset = 0
                }
                onDelete()
            } label: {
                ZStack {
                    Color.red
                    Image(systemName: "trash.fill")
                        .foregroundColor(.white)
                        .font(.title2)
                        .opacity(Double(min(1, (-offset / revealWidth) * 1.5)))
                        .scaleEffect(min(1, 0.4 + 0.6 * (-offset / revealWidth)))
                }
                .frame(width: max(0, -offset))
            }
            .buttonStyle(PlainButtonStyle())

            // Card + ellipsis overlay
            ZStack(alignment: .topTrailing) {
                Button {
                    if !wasDragging { navigateToDetail = true }
                } label: {
                    ListCardView(list: list)
                }
                .buttonStyle(PlainButtonStyle())
                .navigationDestination(isPresented: $navigateToDetail) {
                    ListDetailView(listId: list.listId)
                }

                Menu {
                    Button { onRename() } label: {
                        Label("Rename List", systemImage: "pencil")
                    }
                    Button { onDuplicate() } label: {
                        Label("Make Standalone Copy", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.body)
                        .foregroundColor(list.theme.accentColor.opacity(0.85))
                        .padding(10)
                }
            }
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if abs(value.translation.width) > 4 {
                            wasDragging = true
                        }
                        let proposed = lastOffset + value.translation.width
                        offset = max(-revealWidth, min(0, proposed))
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndTranslation.width - value.translation.width
                        let finalOffset = lastOffset + value.translation.width
                        let reveal: Bool
                        if velocity < -80      { reveal = true }
                        else if velocity > 80  { reveal = false }
                        else                   { reveal = finalOffset < -(revealWidth / 2) }
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                            offset = reveal ? -revealWidth : 0
                            lastOffset = reveal ? -revealWidth : 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            wasDragging = false
                        }
                    }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: (list.theme == .dark ? Color.white : list.theme.accentColor).opacity(0.18), radius: 8, x: 0, y: 0)
        .shadow(color: (list.theme == .dark ? Color.white : list.theme.accentColor).opacity(0.08), radius: 16, x: 0, y: 0)
    }
}

// MARK: - List Card

struct ListCardView: View {
    let list: GroceryList
    @Environment(AppStore.self) private var store
    @AppStorage("isDarkMode") private var isDarkMode = false

    private var itemCount: Int {
        store.compileDisplayItems(listId: list.listId).count
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            list.theme.backgroundColor

            // Ruled-paper lines
            GeometryReader { geo in
                VStack(spacing: 0) {
                    ForEach(0..<Int(geo.size.height / 22) + 2, id: \.self) { _ in
                        Spacer().frame(height: 21.5)
                        Rectangle().fill(list.theme.lineColor).frame(height: 0.5)
                    }
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(list.listName)
                        .font(.custom("Kreon-Bold", size: 22))
                        .foregroundColor(list.theme.textColor)

                    if let parent = store.parentList(for: list) {
                        HStack(spacing: 4) {
                            Image(systemName: "link").font(.caption2)
                            Text("extends \(parent.listName)").font(.custom("Kreon-Regular", size: 12))
                        }
                        .foregroundColor(list.theme.textColor.opacity(0.65))
                    }

                    Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                        .font(.custom("Kreon-Regular", size: 13))
                        .foregroundColor(list.theme.textColor.opacity(0.50))
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
                                    RoundedRectangle(cornerRadius: 8).fill(theme.backgroundColor).frame(height: 42)
                                    if selectedTheme == theme {
                                        Image(systemName: "checkmark").font(.caption.bold()).foregroundColor(theme.textColor)
                                    }
                                }
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedTheme == theme ? theme.accentColor : Color.gray.opacity(0.25),
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
