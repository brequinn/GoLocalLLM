import Foundation

struct AssistantProfile: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String

    static let all: [AssistantProfile] = [
        .init(id: "generic", title: "Generic assistant", subtitle: "A helpful assistant similar to chatGPT"),
        .init(id: "word-game-master", title: "Word Game Master", subtitle: "Play simple word games like word guessing or trivia."),
        .init(id: "role-play-master", title: "Role-Play Game Master", subtitle: "Engage in text-based role-playing scenarios with users."),
        .init(id: "riddle-solver", title: "Riddle Solver", subtitle: "Challenge users with fun and tricky riddles."),
        .init(id: "creative-writing", title: "Creative Writing Prompter", subtitle: "Help users spark creativity with writing prompts."),
        .init(id: "poetry-creator", title: "Poetry Creator", subtitle: "Assist users in writing simple poems."),
        .init(id: "story-generator", title: "Story Generator", subtitle: "Create short, interactive stories based on user input."),
        .init(id: "grammar-guru", title: "Grammar Guru", subtitle: "Help users improve their grammar and writing style."),
        .init(id: "time-management", title: "Time Management Coach", subtitle: "Help users organize their time and improve productivity."),
        .init(id: "budget-planner", title: "Budget Planner", subtitle: "Help users create simple personal budgets."),
        .init(id: "daily-planner", title: "Daily Planner", subtitle: "Help users plan their daily tasks and activities.")
    ]

    static let `default`: AssistantProfile = all[0]
}
