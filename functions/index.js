const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");

admin.initializeApp();

const API_KEY = "AIzaSyB4dk_SquT4pNmksWRh-LSg-MrIHYl3H_0";
const genAI = new GoogleGenerativeAI(API_KEY);

/**
 * ASYNC TRIGGER: Processes AI requests added to Firestore.
 * This handles "Scale horizontally" and "Asynchronous Processing".
 */
exports.processAiRequest = functions.firestore
    .document("ai_requests/{requestId}")
    .onCreate(async (snapshot, context) => {
        const data = snapshot.data();
        const { prompt, type, userId } = data;

        if (!prompt) {
            return snapshot.ref.update({
                status: "error",
                error: "Missing prompt",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        try {
            // Update status to processing
            await snapshot.ref.update({
                status: "processing",
                startedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
            let systemInstruction = "You are a legal expert specializing in Indian Family Law.";

            if (type === "alimony") {
                systemInstruction += " Analyze financial details for Alimony strategy based on Rajnesh v. Neha guidelines.";
            } else if (type === "draft") {
                systemInstruction += " Generate professional, court-ready legal documents in formal language (Petition, Notice, Affidavit).";
            } else if (type === "summary") {
                systemInstruction += " Analyze the provided incident or transcript and provide a court-ready legal summary with Key Facts and Legal Relevance.";
            } else if (type === "rag") {
                systemInstruction = "You are a legal research assistant for Indian family law. Provide structured legal information based ONLY on the provided legal texts, case laws, and community insights. Do not give final legal advice.";
            } else if (type === "case") {
                systemInstruction += " Analyze the user's case description and match it with the most suitable lawyer specialization.";
            }

            const result = await model.generateContent(`${systemInstruction}\n\nInput:\n${prompt}`);
            const response = await result.response;
            const text = response.text();

            if (!text) {
                throw new Error("AI returned an empty response.");
            }

            // Update with results
            return snapshot.ref.update({
                response: text,
                status: "completed",
                completedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

        } catch (error) {
            console.error("Gemini Error:", error);
            return snapshot.ref.update({
                status: "error",
                error: error.message,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
    });

/**
 * LEGACY: Direct Callable (Synchronous)
 */
exports.analyzeLegalCase = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Only logged-in users can use AI features.",
        );
    }

    const { prompt, type } = data;
    if (!prompt) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Prompt/Data is required.",
        );
    }

    try {
        const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

        let systemInstruction = "You are a legal expert specializing in Indian Family Law.";

        if (type === "alimony") {
            systemInstruction += " Analyze financial details for Alimony strategy based on Rajnesh v. Neha guidelines.";
        } else if (type === "draft") {
            systemInstruction += " Generate professional, court-ready legal documents in formal language (Petition, Notice, Affidavit).";
        } else if (type === "summary") {
            systemInstruction += " Analyze the provided incident or transcript and provide a court-ready legal summary with Key Facts and Legal Relevance.";
        } else if (type === "rag") {
            systemInstruction = "You are a legal research assistant for Indian family law. Provide structured legal information based ONLY on the provided legal texts, case laws, and community insights. Do not give final legal advice.";
        } else if (type === "case") {
            systemInstruction += " Analyze the user's case description and match it with the most suitable lawyer specialization.";
        }

        const result = await model.generateContent(`${systemInstruction}\n\nInput:\n${prompt}`);
        const response = await result.response;
        const text = response.text();

        if (!text) {
            throw new Error("AI returned an empty response.");
        }

        return {
            text: text,
            status: "success",
        };
    } catch (error) {
        console.error("Gemini Error:", error);
        throw new functions.https.HttpsError(
            "internal",
            "AI Analysis failed: " + error.message,
        );
    }
});

/**
 * TRANSLATION EVENT HANDLER:
 * This handles custom logic after the "Translate Text" extension finishes.
 * Requires "Eventarc" to be enabled in Google Cloud Console.
 */
// const { onCustomEventPublished } = require("firebase-functions/v2/eventarc");
// exports.onTranslationComplete = onCustomEventPublished(
//     "firebase.extensions.firestore-translate-text.v1.onCompletion",
//     (e) => {
//         const { input, translated } = e.data;
//         console.log("Translation finished for:", input);
//         // You could send a push notification here!
//         return null;
//     });