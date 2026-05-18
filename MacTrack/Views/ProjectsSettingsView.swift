import SwiftUI
import SwiftData

struct ProjectsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.sortOrder) private var projects: [Project]

    @State private var selectedProjectID: Project.ID?
    @State private var keywordDraft = ""

    private var selectedProject: Project? {
        guard let selectedProjectID else { return projects.first }
        return projects.first { $0.id == selectedProjectID } ?? projects.first
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            projectList

            Divider()

            Group {
                if let project = selectedProject {
                    projectEditor(project)
                } else {
                    ContentUnavailableView(
                        "No projects",
                        systemImage: "folder.badge.plus",
                        description: Text("Create a project and add keywords to match window titles.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addProject()
                } label: {
                    Label("Add Project", systemImage: "plus")
                }
            }
        }
        .onAppear {
            ProjectStore.migrateAllKeywords(in: modelContext)
            syncSelection()
        }
        .onChange(of: projects.count) { _, _ in
            syncSelection()
        }
    }

    private var projectList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Projects")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            List(selection: $selectedProjectID) {
                ForEach(projects) { project in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(ProjectColors.color(from: project.colorHex))
                            .frame(width: 10, height: 10)
                        Text(project.name)
                            .lineLimit(1)
                    }
                    .tag(project.id)
                    .contextMenu {
                        Button("Delete Project", role: .destructive) {
                            deleteProject(project)
                        }
                    }
                }
                .onDelete(perform: deleteProjectsAtOffsets)
            }
            .listStyle(.sidebar)
            .listRowBackground(Color.clear)
            .frostedGlassContent()
        }
        .frame(width: 220)
        .background(.quaternary.opacity(0.22))
    }

    @ViewBuilder
    private func projectEditor(_ project: Project) -> some View {
        let _ = project.ensureKeywordEntriesLoaded()
        let keywords = project.keywordValues()
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    editorSectionTitle("Project")
                    TextField("Name", text: Bindable(project).name)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                        .onSubmit { save() }
                    ProjectColorSwatches(selection: Bindable(project).colorHex) {
                        save()
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    editorSectionTitle("Keywords (\(keywords.count))")
                    Text("Matched against the focused window title only (case-insensitive).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 8) {
                        ForEach(keywords, id: \.self) { keyword in
                            KeywordChip(keyword: keyword) {
                                project.removeKeyword(keyword)
                                save()
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        TextField("Add keyword", text: $keywordDraft)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                            .onSubmit { addKeyword(to: project) }
                        Button("Add") { addKeyword(to: project) }
                            .disabled(keywordDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frostedGlassContent()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func editorSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func syncSelection() {
        if let selectedProjectID,
           projects.contains(where: { $0.id == selectedProjectID }) {
            return
        }
        selectedProjectID = projects.first?.id
    }

    private func addProject() {
        let project = Project(
            name: "Project \(projects.count + 1)",
            colorHex: ProjectColors.palette[projects.count % ProjectColors.palette.count],
            sortOrder: projects.count
        )
        modelContext.insert(project)
        selectedProjectID = project.id
        save()
    }

    private func deleteProject(_ project: Project) {
        if selectedProjectID == project.id {
            selectedProjectID = nil
        }
        modelContext.delete(project)
        syncSelection()
        save()
    }

    private func deleteProjectsAtOffsets(_ offsets: IndexSet) {
        for index in offsets {
            deleteProject(projects[index])
        }
    }

    private func addKeyword(to project: Project) {
        let trimmed = keywordDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        project.addKeyword(trimmed)
        keywordDraft = ""
        save()
    }

    private func save() {
        try? modelContext.save()
        NotificationCenter.default.post(name: .mactrackProjectsDidChange, object: nil)
    }
}

struct KeywordChip: View {
    let keyword: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(keyword)
                .font(.caption)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary, in: Capsule())
    }
}

/// Simple wrapping layout for keyword chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        let effectiveWidth = maxWidth.isFinite ? maxWidth : 600
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > effectiveWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: effectiveWidth, height: y + rowHeight), frames)
    }
}
