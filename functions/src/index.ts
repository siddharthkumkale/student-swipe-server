/**
 * AI bot support for Student Swipe (Groq + Firestore).
 *
 * Setup:
 * 1. Create Firebase Auth users for each bot; copy their uid.
 * 2. In Firestore `users/{uid}` set a normal profile plus:
 *    isAiBot: true
 *    optional aiPersona: "short extra style instructions"
 * 3. firebase functions:secrets:set GROQ_API_KEY
 * 4. firebase deploy --only functions
 *
 * Behavior:
 * - When a real user likes a bot (swipe subdoc), the bot auto-likes back and a match is written.
 * - When someone sends a chat message and the other participant is a bot, Groq generates a reply.
 */

import {initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {defineSecret} from "firebase-functions/params";
import {onDocumentCreated} from "firebase-functions/v2/firestore";

initializeApp();
const db = getFirestore();

const groqApiKey = defineSecret("GROQ_API_KEY");

const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
const GROQ_MODEL = "llama-3.3-70b-versatile";

interface ChatMessage {
  role: "user" | "assistant";
  content: string;
}

async function callGroq(
  apiKey: string,
  system: string,
  messages: ChatMessage[],
): Promise<string> {
  const res = await fetch(GROQ_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: GROQ_MODEL,
      messages: [{role: "system", content: system}, ...messages],
      max_tokens: 280,
      temperature: 0.85,
    }),
  });
  const raw = await res.text();
  if (!res.ok) {
    throw new Error(`Groq HTTP ${res.status}: ${raw.slice(0, 500)}`);
  }
  const data = JSON.parse(raw) as {
    choices?: Array<{message?: {content?: string}}>;
  };
  const text = data.choices?.[0]?.message?.content?.trim();
  return text && text.length > 0 ? text : "Hey! 😊";
}

/** Human swiped like on someone — if target is AI bot, bot likes back + match. */
export const onHumanLikesAiBot = onDocumentCreated(
  {
    document: "users/{fromUid}/swipes/{toUid}",
    region: "us-central1",
  },
  async (event) => {
    const {fromUid, toUid} = event.params;
    const snap = event.data;
    if (!snap) return;

    const action = snap.data()?.action;
    if (action !== "like") return;

    const botRef = db.doc(`users/${toUid}`);
    const botDoc = await botRef.get();
    if (!botDoc.exists || botDoc.data()?.isAiBot !== true) return;

    const reverseRef = db.doc(`users/${toUid}/swipes/${fromUid}`);
    const reverseSnap = await reverseRef.get();
    if (reverseSnap.exists) return;

    await reverseRef.set({
      action: "like",
      timestamp: FieldValue.serverTimestamp(),
    });

    const humanDoc = await db.doc(`users/${fromUid}`).get();
    const human = humanDoc.data() ?? {};
    const bot = botDoc.data() ?? {};
    const now = FieldValue.serverTimestamp();

    await db.doc(`users/${fromUid}/matches/${toUid}`).set({
      matchedAt: now,
      name: bot.name ?? "Someone",
      ...(bot.photoUrl ? {photoUrl: bot.photoUrl} : {}),
    });
    await db.doc(`users/${toUid}/matches/${fromUid}`).set({
      matchedAt: now,
      name: human.name ?? "Someone",
      ...(human.photoUrl ? {photoUrl: human.photoUrl} : {}),
    });

    logger.info("AI bot auto-matched", {fromUid, toUid});
  },
);

/** New chat message — if sender is human and other user is AI, post Groq reply. */
export const onChatMessageForAiBot = onDocumentCreated(
  {
    document: "chats/{chatId}/messages/{messageId}",
    region: "us-central1",
    secrets: [groqApiKey],
  },
  async (event) => {
    const {chatId} = event.params;
    const snap = event.data;
    if (!snap) return;

    const msg = snap.data();
    const senderId = msg?.senderId as string | undefined;
    const text = (msg?.text as string | undefined)?.trim();
    if (!senderId || !text) return;

    const chatRef = db.doc(`chats/${chatId}`);
    const chatSnap = await chatRef.get();
    if (!chatSnap.exists) return;

    const participants = chatSnap.data()?.participants as string[] | undefined;
    if (!participants || participants.length !== 2) return;

    const otherUid = participants.find((u) => u !== senderId);
    if (!otherUid) return;

    const senderDoc = await db.doc(`users/${senderId}`).get();
    const otherDoc = await db.doc(`users/${otherUid}`).get();

    const senderIsBot = senderDoc.data()?.isAiBot === true;
    const otherIsBot = otherDoc.data()?.isAiBot === true;

    if (senderIsBot) return;
    if (!otherIsBot) return;

    const botUid = otherUid;
    const bot = otherDoc.data() ?? {};
    const human = senderDoc.data() ?? {};

    const system = [
      "You are a friendly university student on a campus app called Student Swipe.",
      "You chat in short, natural messages (often 1–3 sentences). Use casual tone, occasional emoji sparingly.",
      "Stay in character as a peer; do not mention you are an AI, a model, or Groq.",
      "Do not give medical, legal, or financial advice. If asked for something inappropriate, politely decline.",
      bot.name ? `Your display name is ${bot.name}.` : "",
      bot.university ? `You study at or near: ${bot.university}.` : "",
      bot.course ? `Your course/major vibe: ${bot.course}.` : "",
      bot.bio ? `About you: ${bot.bio}` : "",
      typeof bot.aiPersona === "string" && bot.aiPersona.trim()
        ? `Extra character notes: ${bot.aiPersona.trim()}`
        : "",
    ]
      .filter(Boolean)
      .join("\n");

    const historySnap = await chatRef
      .collection("messages")
      .orderBy("createdAt", "desc")
      .limit(24)
      .get();

    const historyDocs = historySnap.docs.reverse();
    const groqMessages: ChatMessage[] = [];
    for (const d of historyDocs) {
      const m = d.data();
      const sid = m.senderId as string;
      const t = (m.text as string)?.trim();
      if (!t) continue;
      if (sid === botUid) {
        groqMessages.push({role: "assistant", content: t});
      } else {
        groqMessages.push({role: "user", content: t});
      }
    }

    const apiKey = groqApiKey.value();
    let reply: string;
    try {
      reply = await callGroq(apiKey, system, groqMessages);
    } catch (e) {
      logger.error("Groq failed", e);
      reply = "Sorry, I’m having trouble replying right now — try again in a bit?";
    }

    const preview =
      reply.length > 80 ? `${reply.substring(0, 80)}...` : reply;

    await chatRef.collection("messages").add({
      senderId: botUid,
      text: reply,
      createdAt: FieldValue.serverTimestamp(),
    });

    await chatRef.update({
      lastMessageText: preview,
      lastMessageAt: FieldValue.serverTimestamp(),
      lastSenderId: botUid,
      readBy: [botUid],
    });

    logger.info("AI bot replied", {chatId, botUid, humanUid: senderId});
  },
);
