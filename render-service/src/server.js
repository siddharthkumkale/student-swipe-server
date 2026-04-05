/**
 * Free-tier host (e.g. Render): Groq replies + AI bot auto-match.
 *
 * Env (Render dashboard → Environment):
 *   GROQ_API_KEY              — from console.groq.com
 *   FIREBASE_SERVICE_ACCOUNT_JSON — service account JSON (one line), OR
 *   FIREBASE_SERVICE_ACCOUNT_BASE64 — same JSON UTF-8 then base64 (easier in Render UI)
 *   PORT                      — set automatically by Render
 *
 * The service account must have permission to read/write Firestore for your project.
 */

const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');

const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';
const GROQ_MODEL = 'llama-3.3-70b-versatile';

let firestoreReady = false;

/** Returns true if Firebase Admin is usable (does not exit the process). */
function tryInitAdmin() {
  if (firestoreReady) return true;
  let raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw && process.env.FIREBASE_SERVICE_ACCOUNT_BASE64) {
    raw = Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT_BASE64, 'base64').toString('utf8');
  }
  if (!raw) return false;
  try {
    const cred = JSON.parse(raw);
    if (admin.apps.length === 0) {
      admin.initializeApp({ credential: admin.credential.cert(cred) });
    }
    firestoreReady = true;
    console.log('Firebase Admin initialized');
    return true;
  } catch (e) {
    console.error('Firebase init failed:', e.message || e);
    return false;
  }
}

tryInitAdmin();
if (!firestoreReady) {
  console.warn(
    '[student-swipe-ai] No FIREBASE_SERVICE_ACCOUNT_JSON / _BASE64 yet — service stays online; add the env var in Render and redeploy for AI features.'
  );
}

const app = express();
app.use(cors({ origin: true }));
app.use(express.json({ limit: '256kb' }));

function requireFirebase(req, res, next) {
  if (!tryInitAdmin()) {
    return res.status(503).json({
      error:
        'Server missing Firebase credentials. Render → Web Service "student-swipe-ai" → Environment → add FIREBASE_SERVICE_ACCOUNT_JSON (one-line JSON) or FIREBASE_SERVICE_ACCOUNT_BASE64 → Save → Redeploy.',
    });
  }
  req.fs = admin.firestore();
  next();
}

app.get('/', (_req, res) => {
  res.type('text').send(
    `Student Swipe AI service. Firebase: ${firestoreReady ? 'ok' : 'NOT CONFIGURED'}. Groq: ${process.env.GROQ_API_KEY ? 'set' : 'NOT SET'}. POST /api/ensure-match, /api/chat-reply`,
  );
});

app.get('/health', (_req, res) =>
  res.json({
    ok: true,
    firebase: firestoreReady,
    groq: Boolean(process.env.GROQ_API_KEY),
  }),
);

async function verifyUser(req) {
  const h = req.headers.authorization || '';
  const m = h.match(/^Bearer\s+(.+)$/i);
  if (!m) return null;
  try {
    return await admin.auth().verifyIdToken(m[1]);
  } catch {
    return null;
  }
}

function chatId(a, b) {
  return [a, b].sort().join('_');
}

/** Fixed demo bot UIDs (Firestore only — no Auth login). Idempotent seed. */
const DEMO_AI_BOTS = [
  {
    uid: 'ss_demo_ai_01',
    name: 'Alex',
    email: 'alex.demo@student-swipe.app',
    university: 'Riverside University',
    course: 'Computer Science',
    year: '2nd year',
    bio: 'Hackathons, coffee, and late-night coding. Always down to team up on a project.',
    skills: ['Python', 'UI design', 'Public speaking'],
    isAiBot: true,
    aiPersona: 'Warm, uses short messages and occasional emoji.',
  },
  {
    uid: 'ss_demo_ai_02',
    name: 'Jordan',
    email: 'jordan.demo@student-swipe.app',
    university: 'Riverside University',
    course: 'Business & Marketing',
    year: '3rd year',
    bio: 'Love pitching ideas and meeting builders. Let’s make something people actually use.',
    skills: ['Marketing', 'Pitch decks', 'Notion'],
    isAiBot: true,
    aiPersona: 'Professional but friendly; concise replies.',
  },
  {
    uid: 'ss_demo_ai_03',
    name: 'Sam',
    email: 'sam.demo@student-swipe.app',
    university: 'Metro State',
    course: 'Psychology',
    year: '1st year',
    bio: 'Here for study buddies and chill convos between classes.',
    skills: ['Research', 'Writing', 'Spanish'],
    isAiBot: true,
    aiPersona: 'Supportive peer; casual tone.',
  },
];

/** Ensure demo AI profiles exist (Admin write; any logged-in user may trigger). */
app.post('/api/seed-demo-profiles', requireFirebase, async (req, res) => {
  const user = await verifyUser(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const db = req.fs;
  try {
    let created = 0;
    for (const b of DEMO_AI_BOTS) {
      const ref = db.doc(`users/${b.uid}`);
      const snap = await ref.get();
      if (snap.exists) continue;
      await ref.set(
        {
          uid: b.uid,
          name: b.name,
          email: b.email,
          university: b.university,
          course: b.course,
          year: b.year,
          bio: b.bio,
          skills: b.skills,
          additionalPhotos: [],
          isAiBot: true,
          aiPersona: b.aiPersona,
          createdAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      created += 1;
    }
    return res.json({ ok: true, created, total: DEMO_AI_BOTS.length });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: String(e.message || e) });
  }
});

async function callGroq(system, messages) {
  const key = process.env.GROQ_API_KEY;
  if (!key) throw new Error('GROQ_API_KEY not set');
  const res = await fetch(GROQ_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${key}`,
    },
    body: JSON.stringify({
      model: GROQ_MODEL,
      messages: [{ role: 'system', content: system }, ...messages],
      max_tokens: 280,
      temperature: 0.85,
    }),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`Groq ${res.status}: ${text.slice(0, 400)}`);
  const data = JSON.parse(text);
  const out = data.choices?.[0]?.message?.content?.trim();
  return out && out.length > 0 ? out : 'Hey! 😊';
}

/** After human likes an AI profile: bot likes back + match docs. */
app.post('/api/ensure-match', requireFirebase, async (req, res) => {
  const user = await verifyUser(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const db = req.fs;
  const fromUid = user.uid;
  const { botUid } = req.body || {};
  if (!botUid || typeof botUid !== 'string') {
    return res.status(400).json({ error: 'botUid required' });
  }

  try {
    const botDoc = await db.doc(`users/${botUid}`).get();
    if (!botDoc.exists || botDoc.data()?.isAiBot !== true) {
      return res.status(400).json({ error: 'Not an AI bot user' });
    }

    const swipeDoc = await db.doc(`users/${fromUid}/swipes/${botUid}`).get();
    if (!swipeDoc.exists || swipeDoc.data()?.action !== 'like') {
      return res.status(400).json({ error: 'You have not liked this user' });
    }

    const reverseRef = db.doc(`users/${botUid}/swipes/${fromUid}`);
    const reverseSnap = await reverseRef.get();
    if (!reverseSnap.exists) {
      await reverseRef.set({
        action: 'like',
        timestamp: FieldValue.serverTimestamp(),
      });
    }

    const humanDoc = await db.doc(`users/${fromUid}`).get();
    const human = humanDoc.data() || {};
    const bot = botDoc.data() || {};
    const now = FieldValue.serverTimestamp();

    await db.doc(`users/${fromUid}/matches/${botUid}`).set({
      matchedAt: now,
      name: bot.name || 'Someone',
      ...(bot.photoUrl ? { photoUrl: bot.photoUrl } : {}),
    });
    await db.doc(`users/${botUid}/matches/${fromUid}`).set({
      matchedAt: now,
      name: human.name || 'Someone',
      ...(human.photoUrl ? { photoUrl: human.photoUrl } : {}),
    });

    return res.json({ ok: true });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: String(e.message || e) });
  }
});

/** Generate AI reply to the latest human message in chat with botUid. */
app.post('/api/chat-reply', requireFirebase, async (req, res) => {
  const user = await verifyUser(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const db = req.fs;
  const humanUid = user.uid;
  const { botUid } = req.body || {};
  if (!botUid || typeof botUid !== 'string') {
    return res.status(400).json({ error: 'botUid required' });
  }

  try {
    const botDoc = await db.doc(`users/${botUid}`).get();
    if (!botDoc.exists || botDoc.data()?.isAiBot !== true) {
      return res.status(400).json({ error: 'Not an AI bot user' });
    }

    const cid = chatId(humanUid, botUid);
    const chatRef = db.doc(`chats/${cid}`);
    const chatSnap = await chatRef.get();
    if (!chatSnap.exists) {
      return res.status(400).json({ error: 'No chat yet' });
    }
    const parts = chatSnap.data()?.participants || [];
    if (parts.length !== 2 || !parts.includes(humanUid) || !parts.includes(botUid)) {
      return res.status(400).json({ error: 'Invalid chat' });
    }

    const humanDoc = await db.doc(`users/${humanUid}`).get();
    if (humanDoc.data()?.isAiBot === true) {
      return res.status(400).json({ error: 'Invalid caller' });
    }

    const historySnap = await chatRef
      .collection('messages')
      .orderBy('createdAt', 'desc')
      .limit(24)
      .get();

    const docs = historySnap.docs.slice().reverse();
    const last = docs.length ? docs[docs.length - 1].data() : null;
    if (!last || last.senderId !== humanUid) {
      return res.json({ ok: true, skipped: true });
    }

    const bot = botDoc.data() || {};
    const system = [
      'You are a friendly university student on a campus app called Student Swipe.',
      'You chat in short, natural messages (often 1–3 sentences). Casual tone; emoji sparingly.',
      'Do not say you are an AI or a language model.',
      'No medical/legal/financial advice; decline inappropriate topics politely.',
      bot.name ? `Your display name is ${bot.name}.` : '',
      bot.university ? `Campus context: ${bot.university}.` : '',
      bot.course ? `Course vibe: ${bot.course}.` : '',
      bot.bio ? `About you: ${bot.bio}` : '',
      typeof bot.aiPersona === 'string' && bot.aiPersona.trim()
        ? `Character notes: ${bot.aiPersona.trim()}`
        : '',
    ]
      .filter(Boolean)
      .join('\n');

    const groqMessages = [];
    for (const d of docs) {
      const m = d.data();
      const sid = m.senderId;
      const t = (m.text || '').trim();
      if (!t) continue;
      if (sid === botUid) groqMessages.push({ role: 'assistant', content: t });
      else groqMessages.push({ role: 'user', content: t });
    }

    let reply;
    try {
      reply = await callGroq(system, groqMessages);
    } catch (e) {
      console.error(e);
      reply = "Sorry, I'm having trouble replying — try again in a moment?";
    }

    const preview = reply.length > 80 ? `${reply.slice(0, 80)}...` : reply;

    await chatRef.collection('messages').add({
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

    return res.json({ ok: true });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: String(e.message || e) });
  }
});

const port = Number(process.env.PORT) || 3000;
app.listen(port, () => console.log(`AI service listening on ${port}`));
