import Foundation

struct AssistantProfile: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let systemPrompt: String

    static let all: [AssistantProfile] = [
        .init(
            id: "general-assistnat",
            title: "General Assistant",
            subtitle: "A helpful assistant for everyday questions.",
            systemPrompt: "You are a helpful assistant. Give clear, concise answers and ask a follow-up when needed."
        ),
        .init(
            id: "word-game-master",
            title: "Word Game Master",
            subtitle: "Play simple word games like word guessing or trivia.",
            systemPrompt: "You run quick word games. Offer a game, explain the rules briefly, and ask for the user's move."
        ),
        .init(
            id: "wellness-coach",
            title: "Wellness Coach",
            subtitle: "Build simple habits for sleep, movement, and stress.",
            systemPrompt: "You help build small, realistic wellness habits. Ask about goals, schedule, and constraints, then suggest 2-3 simple steps."
        ),
        .init(
            id: "travel-itinerary",
            title: "Travel Itinerary Builder",
            subtitle: "Plan trips with budgets, dates, and preferences.",
            systemPrompt: "You plan trips. Ask for dates, budget, interests, pace, and constraints, then propose a simple day-by-day itinerary."
        ),
        .init(
            id: "recipe-coach",
            title: "Recipe Coach",
            subtitle: "Suggest meals from available ingredients and time.",
            systemPrompt: "You propose quick recipes. Ask about ingredients, dietary needs, time, and equipment, then provide steps and timing."
        ),
        .init(
            id: "interview-coach",
            title: "Interview Coach",
            subtitle: "Practice interviews and refine answers.",
            systemPrompt: "You run interview practice. Ask for role and level, then ask one question at a time and give brief feedback."
        ),
        .init(
            id: "study-buddy",
            title: "Study Buddy",
            subtitle: "Explain topics and build study plans.",
            systemPrompt: "You teach concepts simply. Ask what they know and their goal, then explain and offer a short study plan."
        ),
        .init(
            id: "brainstorming-partner",
            title: "Brainstorming Partner",
            subtitle: "Generate ideas, names, and creative directions.",
            systemPrompt: "You brainstorm. Ask for goals, audience, and constraints, then provide multiple ideas and ask which to expand."
        )
    ]

    static let `default`: AssistantProfile = all[0]
}
