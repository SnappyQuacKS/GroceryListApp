import SwiftUI

struct ListDetailView: View {
    let listId: String
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingAddItem     = false
    @State private var showingThemePicker = false
    @State private var showingHiddenItems = false
    @State private var itemToRemove: DisplayItem? = nil
    @State private var itemToEdit: DisplayItem?   = nil
    @State private var editName = ""

    private var list: GroceryList? { store.lists[listId] }

    private var removeAlertShown: Binding<Bool> {
        Binding(get: { itemToRemove != nil }, set: { if !$0 { itemToRemove = nil } })
    }

    var body: some View {
        Group {
            if let list { content(list) }
            else { Text("List not found").foregroundColor(.secondary) }
        }
        // Consume horizontal swipes so the parent tab pager doesn't trigger
        .gesture(DragGesture(minimumDistance: 10).onChanged { _ in })
    }

    @ViewBuilder
    private func content(_ list: GroceryList) -> some View {
        let displayItems = store.compileDisplayItems(listId: listId)
        let hiddenItems  = store.hiddenItems(listId: listId)
        let lineColor  = list.theme.lineColor(colorScheme)
        let paperColor = list.theme.backgroundColor(colorScheme)

        ScrollView {
            VStack(spacing: 0) {
                // Empty first row — items start on the 2nd line
                Color.clear
                    .frame(height: 36)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(lineColor).frame(height: 3)
                    }

                ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                    ItemRow(
                        index: index, item: item, theme: list.theme,
                        onToggle: { store.toggleItem(itemId: item.itemId, in: listId) },
                        onEdit:   { itemToEdit = item; editName = item.name },
                        onRemove: { itemToRemove = item }
                    )
                    .frame(height: 36)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(lineColor).frame(height: 3)
                    }
                }

                // Add item button on the next line
                Button { showingAddItem = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill").font(.body)
                        Text("+ add item").font(.custom("Kreon-Regular", size: 17))
                    }
                    .foregroundColor(list.theme.accentColor(colorScheme))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(list.theme.accentColor(colorScheme).opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(list.theme.accentColor(colorScheme).opacity(0.5), lineWidth: 1.5)
                    )
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(lineColor).frame(height: 3)
                }

                // Hidden items section
                if showingHiddenItems && !hiddenItems.isEmpty {
                    // Section header
                    HStack {
                        Text("Hidden Items")
                            .font(.custom("Kreon-Bold", size: 13))
                            .foregroundColor(list.theme.textColor(colorScheme).opacity(0.5))
                            .padding(.leading, 16)
                        Spacer()
                    }
                    .frame(height: 36)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(lineColor).frame(height: 3)
                    }

                    ForEach(hiddenItems) { item in
                        HStack(spacing: 18) {
                            Text(item.name)
                                .font(.custom("Kreon-Regular", size: 22))
                                .foregroundColor(list.theme.textColor(colorScheme).opacity(0.35))
                                .strikethrough(true, color: list.theme.textColor(colorScheme).opacity(0.25))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 16)

                            Button {
                                store.restoreItem(itemId: item.itemId, in: listId)
                            } label: {
                                Text("Restore")
                                    .font(.custom("Kreon-Regular", size: 13))
                                    .foregroundColor(list.theme.accentColor(colorScheme))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule().fill(list.theme.accentColor(colorScheme).opacity(0.12))
                                    )
                                    .overlay(Capsule().stroke(list.theme.accentColor(colorScheme).opacity(0.4), lineWidth: 1))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.trailing, 16)
                        }
                        .frame(height: 36)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(lineColor).frame(height: 3)
                        }
                    }
                }

                // Canvas filler — continues the ruled lines to the bottom of the screen
                Canvas { ctx, size in
                    var y: CGFloat = 36
                    while y <= size.height {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        ctx.stroke(path, with: .color(lineColor), lineWidth: 3)
                        y += 36
                    }
                }
                .frame(maxWidth: .infinity, minHeight: UIScreen.main.bounds.height)
            }
        }
        .background(paperColor.ignoresSafeArea())
        // Margin line as a full-height overlay
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(Color(red: 0.82, green: 0.32, blue: 0.32).opacity(0.45))
                .frame(width: 3)
                .padding(.leading, 54)
                .ignoresSafeArea()
        }
        .navigationTitle(list.listName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(list.listName)
                    .font(.custom("Kreon-Bold", size: 30))
                    .foregroundColor(list.theme.textColor(colorScheme))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingThemePicker = true } label: {
                        Label("Change Theme", systemImage: "paintpalette")
                    }
                    Button {
                        store.duplicateAsDecoupledCopy(listId: listId)
                    } label: {
                        Label("Duplicate as Standalone Copy", systemImage: "doc.on.doc")
                    }
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingHiddenItems.toggle()
                        }
                    } label: {
                        Label(showingHiddenItems ? "Hide Hidden Items" : "Show Hidden Items",
                              systemImage: showingHiddenItems ? "eye.slash" : "eye")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(list.theme.accentColor(colorScheme))
                }
            }
        }
        // Remove / mask confirmation
        .alert("Remove Item", isPresented: removeAlertShown, presenting: itemToRemove) { item in
            Button(item.isInherited ? "Hide from This List" : "Remove", role: .destructive) {
                store.removeItem(itemId: item.itemId, from: listId)
                itemToRemove = nil
            }
            Button("Cancel", role: .cancel) { itemToRemove = nil }
        } message: { item in
            if item.isInherited {
                Text("This item is inherited from a parent list. It will be hidden here but remain in the original list.")
            } else {
                Text("Remove \"\(item.name)\" from this list?")
            }
        }
        // Edit item name
        .alert("Rename Item", isPresented: .constant(itemToEdit != nil)) {
            TextField("Item name", text: $editName)
            Button("Save") {
                if let item = itemToEdit {
                    store.editItem(itemId: item.itemId, in: listId, newName: editName)
                }
                itemToEdit = nil
            }
            .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) { itemToEdit = nil }
        } message: {
            if let item = itemToEdit, item.isInherited {
                Text("This creates a local override — the parent list is not affected.")
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemSheet(listId: listId).environment(store)
        }
        .sheet(isPresented: $showingThemePicker) {
            ThemePickerSheet(listId: listId)
                .environment(store)
                .presentationDetents([.height(200)])
        }
    }
}

// MARK: - Item Row

struct ItemRow: View {
    let index: Int
    let item: DisplayItem
    let theme: ListTheme
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 18) {
            // Number
            Text("\(index + 1).")
                .font(.custom("Kreon-Regular", size: 21))
                .foregroundColor(theme.textColor(colorScheme).opacity(0.42))
                .frame(width: 28, alignment: .trailing)

            // Name + inherited indicator right next to it
            HStack(spacing: 4) {
                Text(item.name)
                    .font(.custom("Kreon-Regular", size: 22))
                    .strikethrough(item.isChecked, color: theme.textColor(colorScheme).opacity(0.45))
                    .foregroundColor(item.isChecked ? theme.textColor(colorScheme).opacity(0.4) : theme.textColor(colorScheme))
                    .onTapGesture(count: 2) { onEdit() }
                if item.isInherited {
                    Image(systemName: "link")
                        .font(.caption2)
                        .foregroundColor(theme.accentColor(colorScheme).opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Checkbox
            Button(action: onToggle) {
                Image(systemName: item.isChecked ? "checkmark.square.fill" : "square")
                    .foregroundColor(item.isChecked ? theme.accentColor(colorScheme) : theme.textColor(colorScheme).opacity(0.3))
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())

            // Remove
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red.opacity(0.52))
                    .font(.body)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Add Item Sheet

struct AddItemSheet: View {
    let listId: String
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Item name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit { addItem() }
                Spacer()
            }
            .padding()
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addItem() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.height(160)])
    }

    private func addItem() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.addItem(to: listId, name: trimmed)
        dismiss()
    }
}

// MARK: - Theme Picker Sheet

struct ThemePickerSheet: View {
    let listId: String
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var currentTheme: ListTheme {
        store.lists[listId]?.theme ?? .natural
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Color Theme").font(.headline).padding(.top, 20)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                ForEach(ListTheme.allCases, id: \.self) { theme in
                    Button {
                        store.updateTheme(theme, for: listId)
                        dismiss()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(theme.backgroundColor(colorScheme)).frame(height: 52)
                            if currentTheme == theme {
                                Image(systemName: "checkmark").font(.caption.bold()).foregroundColor(theme.textColor(colorScheme))
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(currentTheme == theme ? theme.accentColor(colorScheme) : Color.gray.opacity(0.2),
                                    lineWidth: currentTheme == theme ? 2 : 1))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            Spacer()
        }
    }
}
