//
//  PermissionBubbleView.swift
//  ClaudeIsland
//
//  Speech bubble for permission requests, appears below the notch.
//  Shows tool name, full input details (including question options), and action buttons.
//

import SwiftUI

struct PermissionBubbleView: View {
    let session: SessionState
    @ObservedObject var viewModel: MascotViewModel
    /// X offset of the mascot this bubble belongs to (relative to notch center)
    let pointerOffsetX: CGFloat
    let onApprove: () -> Void
    let onDeny: () -> Void
    /// Called when user selects option(s) and approves — passes selected labels joined by newline
    let onApproveWithSelection: ((String) -> Void)?

    @State private var isVisible = false
    /// For single-select questions
    @State private var selectedOptionIndex: Int?
    /// For multi-select questions
    @State private var selectedOptionIndices: Set<Int> = []

    private var toolName: String {
        guard let name = session.pendingToolName else { return "Tool" }
        return MCPToolFormatter.formatToolName(name)
    }

    /// Extract structured question options from toolInput if this is an AskUserQuestion
    private var questionItems: [QuestionDisplayItem] {
        guard let permission = session.activePermission,
              let input = permission.toolInput,
              permission.toolName == "AskUserQuestion",
              let questionsAny = input["questions"]?.value as? [[String: Any]] else {
            return []
        }

        return questionsAny.compactMap { q -> QuestionDisplayItem? in
            guard let question = q["question"] as? String else { return nil }
            let header = q["header"] as? String
            let multiSelect = q["multiSelect"] as? Bool ?? false
            var options: [OptionDisplayItem] = []
            if let optionsArray = q["options"] as? [[String: Any]] {
                options = optionsArray.compactMap { opt -> OptionDisplayItem? in
                    guard let label = opt["label"] as? String else { return nil }
                    let description = opt["description"] as? String
                    return OptionDisplayItem(label: label, description: description)
                }
            }
            return QuestionDisplayItem(question: question, header: header, options: options, multiSelect: multiSelect)
        }
    }

    /// Keys that carry verbose content — Claude already explains the change in the terminal
    private static let verboseKeys: Set<String> = [
        "old_string", "new_string", "content", "new_source",
        "description", "prompt", "operations", "timeout",
        "replace_all",
    ]

    /// Format tool input for display (non-question tools)
    private var inputLines: [InputLine] {
        guard let permission = session.activePermission,
              let input = permission.toolInput else { return [] }

        // Skip if this is AskUserQuestion (handled separately)
        if permission.toolName == "AskUserQuestion" { return [] }

        return input.sorted(by: { $0.key < $1.key }).compactMap { key, value -> InputLine? in
            // Skip verbose content keys — the terminal already shows what's changing
            if Self.verboseKeys.contains(key) { return nil }

            let valueStr: String
            switch value.value {
            case let str as String:
                valueStr = str
            case let num as Int:
                valueStr = String(num)
            case let num as Double:
                valueStr = String(num)
            case let bool as Bool:
                valueStr = bool ? "true" : "false"
            default:
                valueStr = "..."
            }
            return InputLine(key: key, value: valueStr)
        }
    }

    private let bubbleWidth: CGFloat = 380

    /// Whether this is a plan approval (ExitPlanMode)
    private var isPlanApproval: Bool {
        session.activePermission?.toolName == "ExitPlanMode"
    }

    /// Whether this is an Edit tool
    private var isEditTool: Bool {
        session.activePermission?.toolName == "Edit"
    }

    /// Extract allowed prompts from ExitPlanMode toolInput for display
    private var planAllowedPrompts: [String] {
        guard isPlanApproval,
              let input = session.activePermission?.toolInput,
              let promptsAny = input["allowedPrompts"]?.value as? [[String: Any]] else {
            return []
        }
        return promptsAny.compactMap { $0["prompt"] as? String }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Triangle pointer pointing up toward the mascot
            Triangle()
                .fill(Color(white: 0.1))
                .frame(width: 12, height: 6)
                .offset(x: pointerOffsetX)

            // Bubble content
            VStack(alignment: .leading, spacing: 8) {
                // Session identifier — project name with colored dot
                HStack(spacing: 4) {
                    Circle()
                        .fill(isPlanApproval ? TerminalColors.blue : TerminalColors.amber)
                        .frame(width: 6, height: 6)
                    Text(session.projectName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)

                    Spacer()

                    Text(toolName)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(isPlanApproval ? TerminalColors.blue.opacity(0.7) : TerminalColors.amber.opacity(0.7))
                        .lineLimit(1)
                }

                Divider().background(Color.white.opacity(0.1))

                // Content: questions, plan prompts, edit diff, or tool input
                if !questionItems.isEmpty {
                    questionsContent
                } else if isPlanApproval && !planAllowedPrompts.isEmpty {
                    planPromptsContent
                } else if isEditTool {
                    editDiffContent
                } else if !inputLines.isEmpty {
                    toolInputContent
                }

                // Action buttons
                HStack(spacing: 8) {
                    Button {
                        onDeny()
                    } label: {
                        Text(isPlanApproval ? "Reject" : "Deny")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())

                    Button {
                        handleApprove()
                    } label: {
                        Text(approveButtonLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isPlanApproval
                                        ? TerminalColors.blue
                                        : (hasSelection ? TerminalColors.green : TerminalColors.green.opacity(0.6)))
                            )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
            .padding(12)
            .frame(width: bubbleWidth)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.1))
                    .shadow(color: .black.opacity(0.6), radius: 12)
            )
        }
        .contentShape(Rectangle())
        .scaleEffect(isVisible ? 1 : 0.85)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                isVisible = true
            }
            viewModel.cancelBubbleDismiss()
        }
    }

    // MARK: - Selection State

    private var hasSelection: Bool {
        if let item = questionItems.first {
            if item.multiSelect {
                return !selectedOptionIndices.isEmpty
            } else {
                return selectedOptionIndex != nil
            }
        }
        return false
    }

    private var approveButtonLabel: String {
        if isPlanApproval { return "Approve Plan" }

        guard let item = questionItems.first else { return "Allow" }

        if item.multiSelect {
            let count = selectedOptionIndices.count
            if count > 0 {
                return "Submit (\(count))"
            }
            return "Allow"
        } else {
            if selectedOptionIndex != nil {
                return "Submit"
            }
            return "Allow"
        }
    }

    private func handleApprove() {
        guard let item = questionItems.first else {
            onApprove()
            return
        }

        if item.multiSelect {
            if !selectedOptionIndices.isEmpty {
                // Build the selection string: each selected label on its own line
                let labels = selectedOptionIndices.sorted().compactMap { idx -> String? in
                    guard idx < item.options.count else { return nil }
                    return item.options[idx].label
                }
                onApproveWithSelection?(labels.joined(separator: "\n"))
            } else {
                onApprove()
            }
        } else {
            if let idx = selectedOptionIndex, idx < item.options.count {
                onApproveWithSelection?(item.options[idx].label)
            } else {
                onApprove()
            }
        }
    }

    // MARK: - Questions Content (AskUserQuestion)

    @ViewBuilder
    private var questionsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(questionItems.enumerated()), id: \.offset) { _, item in

                    VStack(alignment: .leading, spacing: 6) {
                        if let header = item.header {
                            Text(header)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                                .textCase(.uppercase)
                        }

                        Text(item.question)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))

                        // Clickable options
                        ForEach(Array(item.options.enumerated()), id: \.offset) { idx, option in
                            let isSelected = item.multiSelect
                                ? selectedOptionIndices.contains(idx)
                                : selectedOptionIndex == idx

                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if item.multiSelect {
                                        if selectedOptionIndices.contains(idx) {
                                            selectedOptionIndices.remove(idx)
                                        } else {
                                            selectedOptionIndices.insert(idx)
                                        }
                                    } else {
                                        selectedOptionIndex = (selectedOptionIndex == idx) ? nil : idx
                                    }
                                }
                            } label: {
                                HStack(alignment: .top, spacing: 6) {
                                    // Checkbox for multi-select, radio for single-select
                                    if item.multiSelect {
                                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                            .font(.system(size: 12))
                                            .foregroundColor(isSelected ? .black : TerminalColors.amber)
                                            .frame(width: 16)
                                    } else {
                                        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                            .font(.system(size: 12))
                                            .foregroundColor(isSelected ? .black : TerminalColors.amber)
                                            .frame(width: 16)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.label)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(isSelected ? .black : .white.opacity(0.85))

                                        if let desc = option.description {
                                            Text(desc)
                                                .font(.system(size: 10))
                                                .foregroundColor(isSelected ? .black.opacity(0.6) : .white.opacity(0.5))
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(isSelected ? TerminalColors.green : Color.white.opacity(0.05))
                                )
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: 200)
    }

    // MARK: - Edit Diff Content

    @ViewBuilder
    private var editDiffContent: some View {
        if let input = session.activePermission?.toolInput {
            let stringInput = input.reduce(into: [String: String]()) { dict, pair in
                if let str = pair.value.value as? String {
                    dict[pair.key] = str
                }
            }
            EditInputDiffView(input: stringInput)
        }
    }

    // MARK: - Plan Prompts Content (ExitPlanMode)

    @ViewBuilder
    private var planPromptsContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Plan needs permission for:")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))

            ForEach(Array(planAllowedPrompts.enumerated()), id: \.offset) { _, prompt in
                HStack(spacing: 5) {
                    Circle()
                        .fill(TerminalColors.blue.opacity(0.6))
                        .frame(width: 4, height: 4)
                    Text(prompt)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
            }
        }
    }

    // MARK: - Tool Input Content (generic tools)

    @ViewBuilder
    private var toolInputContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(inputLines.enumerated()), id: \.offset) { _, line in
                VStack(alignment: .leading, spacing: 1) {
                    Text(line.key)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))

                    Text(line.value)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(4)
                }
            }
        }
    }
}

// MARK: - Display Models

private struct QuestionDisplayItem {
    let question: String
    let header: String?
    let options: [OptionDisplayItem]
    let multiSelect: Bool
}

private struct OptionDisplayItem {
    let label: String
    let description: String?
}

private struct InputLine {
    let key: String
    let value: String
}

// MARK: - Triangle Shape

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
