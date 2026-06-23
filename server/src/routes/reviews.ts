import { Hono } from "hono";
import { SignJWT, importPKCS8 } from "jose";

export const reviewRoutes = new Hono();

// IDs públicos das lojas (não são segredo).
const APPSTORE_ID = "6771110673";
const PACKAGE = "com.stitchmind.app";
const COUNTRIES = ["br", "us"];

type Review = {
  author: string;
  rating: number;
  title: string | null;
  text: string;
  store: "appstore" | "googleplay";
};

type Summary = {
  stores: {
    appstore: { rating: number; count: number };
    googleplay: { rating: number; count: number };
  };
  rating: number; // média ponderada das duas lojas
  count: number; // total de avaliações
  reviews: Review[]; // só as que têm texto
};

// Cache simples em memória (1h) — evita martelar as lojas.
let cache: { at: number; data: Summary } | null = null;
const TTL = 60 * 60 * 1000;

// ─── App Store (RSS público, sem auth) ──────────────────────────────
async function fetchAppStore(): Promise<{ rating: number; count: number; reviews: Review[] }> {
  let rating = 0;
  let count = 0;
  const reviews: Review[] = [];
  const seen = new Set<string>();

  for (const country of COUNTRIES) {
    try {
      const lk = await fetch(
        `https://itunes.apple.com/lookup?bundleId=${PACKAGE}&country=${country}`,
      ).then((r) => r.json());
      const app = lk.results?.[0];
      if (app && (app.userRatingCount ?? 0) > count) {
        rating = app.averageUserRating ?? rating;
        count = app.userRatingCount ?? count;
      }

      const rss = await fetch(
        `https://itunes.apple.com/${country}/rss/customerreviews/id=${APPSTORE_ID}/sortBy=mostRecent/json`,
      ).then((r) => r.json());
      let entries = rss.feed?.entry ?? [];
      if (!Array.isArray(entries)) entries = [entries];
      for (const e of entries) {
        if (!e?.["im:rating"]) continue; // a 1ª entry às vezes é o app
        const text = (e.content?.label ?? "").trim();
        if (!text) continue;
        const key = `${e.author?.name?.label}-${e.title?.label}`;
        if (seen.has(key)) continue;
        seen.add(key);
        reviews.push({
          author: e.author?.name?.label ?? "Usuário",
          rating: parseInt(e["im:rating"].label, 10) || 5,
          title: e.title?.label ?? null,
          text,
          store: "appstore",
        });
      }
    } catch {
      /* ignora país que falhar */
    }
  }
  return { rating, count, reviews };
}

// ─── Google Play (Play Developer API — requer service account) ──────
// Configure GOOGLE_PLAY_SA com o JSON da conta de serviço vinculada no
// Play Console (Configurações → acesso à API). Sem isso, é ignorado.
async function fetchGooglePlay(): Promise<{ rating: number; count: number; reviews: Review[] }> {
  const raw = Bun.env.GOOGLE_PLAY_SA;
  if (!raw) return { rating: 0, count: 0, reviews: [] };
  try {
    const sa = JSON.parse(raw);
    const now = Math.floor(Date.now() / 1000);
    const key = await importPKCS8(sa.private_key, "RS256");
    const assertion = await new SignJWT({
      scope: "https://www.googleapis.com/auth/androidpublisher",
    })
      .setProtectedHeader({ alg: "RS256" })
      .setIssuer(sa.client_email)
      .setSubject(sa.client_email)
      .setAudience("https://oauth2.googleapis.com/token")
      .setIssuedAt(now)
      .setExpirationTime(now + 3600)
      .sign(key);

    const tok = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    }).then((r) => r.json());
    if (!tok.access_token) return { rating: 0, count: 0, reviews: [] };

    const data = await fetch(
      `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE}/reviews?maxResults=20&translationLanguage=pt-BR`,
      { headers: { Authorization: `Bearer ${tok.access_token}` } },
    ).then((r) => r.json());

    const reviews: Review[] = [];
    let sum = 0;
    let n = 0;
    for (const rv of data.reviews ?? []) {
      const com = rv.comments?.find((c: any) => c.userComment)?.userComment;
      if (!com) continue;
      const star = com.starRating ?? 0;
      sum += star;
      n += 1;
      const text = (com.text ?? "").trim();
      if (text) {
        reviews.push({
          author: rv.authorName || "Usuário",
          rating: star,
          title: null,
          text,
          store: "googleplay",
        });
      }
    }
    return { rating: n ? sum / n : 0, count: n, reviews };
  } catch {
    return { rating: 0, count: 0, reviews: [] };
  }
}

async function build(): Promise<Summary> {
  const [ios, android] = await Promise.all([fetchAppStore(), fetchGooglePlay()]);
  const count = ios.count + android.count;
  const rating =
    count > 0
      ? (ios.rating * ios.count + android.rating * android.count) / count
      : 0;
  // intercala as reviews das duas lojas, mais recentes primeiro
  const reviews = [...ios.reviews, ...android.reviews].slice(0, 20);
  return {
    stores: {
      appstore: { rating: ios.rating, count: ios.count },
      googleplay: { rating: android.rating, count: android.count },
    },
    rating: Math.round(rating * 10) / 10,
    count,
    reviews,
  };
}

reviewRoutes.get("/reviews", async (c) => {
  if (cache && Date.now() - cache.at < TTL) return c.json(cache.data);
  try {
    const data = await build();
    cache = { at: Date.now(), data };
    return c.json(data);
  } catch (err) {
    if (cache) return c.json(cache.data); // serve stale em erro
    return c.json({ error: "Não foi possível obter avaliações." }, 502);
  }
});
