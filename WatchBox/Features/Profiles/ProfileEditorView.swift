//
//  ProfileEditorView.swift
//  Aura
//

import SwiftUI
#if canImport(PhotosUI) && !os(tvOS)
import PhotosUI
#endif

// MARK: - Встроенный переводчик
fileprivate func tr(_ key: String, _ lang: String) -> String {
    guard lang == "ru" else { return key }
    let dict: [String: String] = [
        "Cancel": "Отмена",
        "Delete this profile?": "Удалить этот профиль?",
        "Delete profile": "Удалить профиль",
        "Its watch history and watchlist will be removed. This can't be undone.": "История просмотров и избранное будут удалены. Это действие необратимо.",
        "Create your profile": "Создайте свой профиль",
        "Add profile": "Добавить профиль",
        "Edit profile": "Редактировать профиль",
        "Everyone gets their own watch history and list.": "У каждого будет своя история просмотров и избранное.",
        "Name": "Имя",
        "Create": "Создать",
        "Save": "Сохранить",
        "Change photo": "Изменить фото",
        "Choose photo": "Выбрать фото",
        "Remove": "Удалить",
        "Add a photo from the iPhone, iPad or Mac app.": "Добавьте фото в приложении на iPhone, iPad или Mac."
    ]
    return dict[key] ?? key
}

struct ProfileEditorView: View {
    @AppStorage("appLanguage") private var appLanguage = "ru"
    
    enum Mode: Identifiable, Hashable {
        case create(first: Bool)
        case edit(Profile)

        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let p): return p.id
            }
        }
    }

    let mode: Mode
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var colorIndex = Int.random(in: 0..<Profile.colors.count)
    @State private var pickedImage: UIImage?
    @State private var removePhoto = false
    @State private var confirmDelete = false
    @State private var saving = false
    
    // ИСПРАВЛЕНИЕ: Добавляем FocusState для управления клавиатурой
    @FocusState private var isNameFocused: Bool

    #if canImport(PhotosUI) && !os(tvOS)
    @State private var pickerItem: PhotosPickerItem?
    #endif

    private var existing: Profile? {
        if case .edit(let p) = mode { return p }
        return nil
    }
    private var isFirst: Bool {
        if case .create(let first) = mode { return first }
        return false
    }
    private var draft: Profile {
        Profile(id: existing?.id ?? "draft",
                name: name.isEmpty ? "?" : name,
                colorIndex: colorIndex,
                avatarURLString: removePhoto ? nil : existing?.avatarURLString,
                createdAt: existing?.createdAt ?? Date())
    }
    private var canSave: Bool {
        !saving && !profiles.isWorking && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    #if os(tvOS)
    private let avatarSize: CGFloat = 220
    #else
    private let avatarSize: CGFloat = 132
    #endif

    var body: some View {
        Group {
            if isFirst {
                content
            } else {
                NavigationStack {
                    content
                        .toolbar {
                            #if !os(tvOS)
                            ToolbarItem(placement: .cancellationAction) {
                                Button(tr("Cancel", appLanguage)) { dismiss() }
                            }
                            #endif
                        }
                }
            }
        }
        // ИСПРАВЛЕНИЕ: Убираем принудительную темную тему (.preferredColorScheme(.dark)),
        // если хотите, чтобы экран адаптировался под систему.
        // Если он ВСЕГДА должен быть темным (как экран входа) - раскомментируйте строку ниже:
        // .preferredColorScheme(.dark) 
        .onAppear {
            profiles.errorMessage = nil
            if let existing {
                name = existing.name
                colorIndex = existing.colorIndex
            }
        }
        .confirmationDialog(tr("Delete this profile?", appLanguage), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(tr("Delete profile", appLanguage), role: .destructive) {
                guard let existing else { return }
                Task {
                    await profiles.delete(existing)
                    dismiss()
                }
            }
        } message: {
            Text(tr("Its watch history and watchlist will be removed. This can't be undone.", appLanguage))
        }
    }

    private var content: some View {
        ZStack(alignment: .topTrailing) {
            Theme.background.ignoresSafeArea()
                // ИСПРАВЛЕНИЕ: Скрываем клавиатуру по клику на фон
                .onTapGesture { isNameFocused = false }
            
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text(tr(isFirst ? "Create your profile" : (existing == nil ? "Add profile" : "Edit profile"), appLanguage))
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.primary) // ИСПРАВЛЕНИЕ: Был .white, стал .primary для светлой темы
                        if isFirst {
                            Text(tr("Everyone gets their own watch history and list.", appLanguage))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 32)

                    ProfileAvatar(profile: draft, size: avatarSize, preview: pickedImage)

                    photoControls

                    // ИСПРАВЛЕНИЕ: Текстовое поле теперь корректно отображается и на светлой теме
                    TextField(tr("Name", appLanguage), text: $name)
                        .textContentType(.name)
                        .focused($isNameFocused) // Подключаем фокус
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.center)
                        .font(.title3)
                        .foregroundStyle(.primary) // Был .white
                        .tint(Theme.accent) // Был .white
                        .padding()
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onChange(of: name) { _, new in
                            if new.count > Profile.maxNameLength { name = String(new.prefix(Profile.maxNameLength)) }
                        }
                        .onSubmit {
                            isNameFocused = false // Скрываем клаву при нажатии "Return"
                            if canSave { save() }
                        }

                    colorSwatches

                    Button(action: {
                        isNameFocused = false // Скрываем клаву при клике
                        save()
                    }) {
                        ZStack {
                            if saving || profiles.isWorking {
                                ProgressView().tint(Theme.onAccent)
                            } else {
                                Text(tr(existing == nil ? "Create" : "Save", appLanguage)).fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .foregroundStyle(Theme.onAccent)
                    .disabled(!canSave)

                    if existing != nil {
                        Button(tr("Delete profile", appLanguage), role: .destructive) { 
                            isNameFocused = false
                            confirmDelete = true 
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .disabled(profiles.isWorking)
                    }

                    if let error = profiles.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            // ИСПРАВЛЕНИЕ: Скрываем клавиатуру при скролле (iOS 16+)
            .scrollDismissesKeyboard(.interactively)
            
            // КНОПКА СМЕНЫ ЯЗЫКА ТОЛЬКО ДЛЯ ПЕРВОГО ЭКРАНА РЕГИСТРАЦИИ
            if isFirst {
                Picker("Language", selection: $appLanguage) {
                    Text("🇷🇺 RU").tag("ru")
                    Text("🇺🇸 EN").tag("en")
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                .padding()
            }
        }
    }

    @ViewBuilder
    private var photoControls: some View {
        #if canImport(PhotosUI) && !os(tvOS)
        HStack(spacing: 16) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label(tr(draft.hasPhoto || pickedImage != nil ? "Change photo" : "Choose photo", appLanguage), systemImage: "photo")
            }
            .buttonStyle(.bordered)
            .tint(.primary) // ИСПРАВЛЕНИЕ: Был .white
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        pickedImage = image
                        removePhoto = false
                    }
                }
            }
            if draft.hasPhoto || pickedImage != nil {
                Button(tr("Remove", appLanguage)) {
                    pickedImage = nil
                    pickerItem = nil
                    removePhoto = true
                }
                .buttonStyle(.bordered)
                .tint(.primary) // ИСПРАВЛЕНИЕ: Был .white
            }
        }
        #else
        Text(tr("Add a photo from the iPhone, iPad or Mac app.", appLanguage))
            .font(.footnote)
            .foregroundStyle(.secondary)
        #endif
    }

    private var colorSwatches: some View {
        HStack(spacing: 18) {
            ForEach(Profile.colors.indices, id: \.self) { i in
                Button {
                    isNameFocused = false // Скрываем клаву при выборе цвета
                    colorIndex = i
                } label: {
                    Circle()
                        .fill(Profile.colors[i])
                        .frame(width: 40, height: 40)
                        .overlay {
                            if colorIndex == i {
                                // ИСПРАВЛЕНИЕ: Сделал рамку серой/чёрной, чтобы она была видна на белом фоне
                                Circle().strokeBorder(Color.primary, lineWidth: 3).padding(-5)
                            }
                        }
                }
                .buttonStyle(ProfileTileStyle())
                .accessibilityLabel("Colour \(i + 1)")
            }
        }
    }

    private func save() {
        guard canSave else { return }
        saving = true
        Task {
            defer { saving = false }
            var target: Profile?
            if let existing {
                var updated = existing
                updated.name = name
                updated.colorIndex = colorIndex
                if updated.name != existing.name { await profiles.rename(existing, to: name) }
                if colorIndex != existing.colorIndex { await profiles.setColor(existing, index: colorIndex) }
                target = profiles.profiles.first { $0.id == existing.id } ?? updated
                if removePhoto, existing.hasPhoto, let t = target { await profiles.removePhoto(t) }
            } else {
                target = await profiles.create(name: name, colorIndex: colorIndex)
            }
            guard let target else { return }
            if let pickedImage {
                await profiles.setPhoto(profiles.profiles.first { $0.id == target.id } ?? target, image: pickedImage)
            }
            if profiles.errorMessage == nil {
                if isFirst { profiles.select(profiles.profiles.first { $0.id == target.id } ?? target) }
                dismiss()
            }
        }
    }
}