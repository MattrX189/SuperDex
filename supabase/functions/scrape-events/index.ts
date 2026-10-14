//
//  scrape-events — Supabase Edge Function
//
//  Scrapes events from public listing pages on Luma, Eventbrite,
//  Ticketmaster, SeatGeek and Meetup — no API keys needed — and
//  upserts them into public.events. The iOS app reads that table
//  instead of scraping on-device (scrape once, serve every user).
//
//  Strategy (ported 1:1 from the app's old EventsService.swift):
//  event sites embed schema.org structured data
//  (<script type="application/ld+json">) in their listing pages for
//  search engines. That JSON is far more stable than HTML selectors,
//  so each scraper pulls the page and extracts the Event objects from
//  it. Meetup is the exception: it renders with Next.js, so its
//  events are read from the __NEXT_DATA__ Apollo cache instead.
//  Every page fails independently — one site blocking or changing
//  never affects the others.
//
//  Ticketmaster is fetched via its official (free) Discovery API
//  instead of page scraping: its bot protection blocks datacenter
//  IPs like Supabase's. Requires the TICKETMASTER_API_KEY function
//  secret (developer.ticketmaster.com → your app's Consumer Key);
//  when the secret is absent, Ticketmaster is skipped gracefully.
//  Quota use: 1 call per covered city per run (~20/day of the
//  5,000/day free allowance).
//
//  Scheduled every 6 hours via pg_cron (see events.sql).
//  Invoking without SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY set (e.g.
//  `deno run --allow-net index.ts` locally) runs a dry scrape that
//  reports counts without writing to the database.
//

import { createClient } from "jsr:@supabase/supabase-js@2";

// MARK: - Which cities to scrape

interface City {
  name: string;
  /** e.g. "sf" → lu.ma/sf */
  lumaSlug?: string;
  /** e.g. "ca--san-francisco" → eventbrite.com/d/ca--san-francisco/events/ */
  eventbriteSlug?: string;
  /** Discovery API filter, e.g. { city: "San Francisco", countryCode: "US" } */
  ticketmaster?: { city: string; countryCode: string };
  /** e.g. "new-york" → seatgeek.com/cities/new-york */
  seatgeekSlug?: string;
  /** Meetup location filter, e.g. "us--ca--San Francisco" */
  meetupSlug?: string;
}

const CITIES: City[] = [
  { name: "San Francisco", lumaSlug: "sf", eventbriteSlug: "ca--san-francisco", ticketmaster: { city: "San Francisco", countryCode: "US" }, seatgeekSlug: "san-francisco", meetupSlug: "us--ca--San Francisco" },
  { name: "New York", lumaSlug: "nyc", eventbriteSlug: "ny--new-york", ticketmaster: { city: "New York", countryCode: "US" }, seatgeekSlug: "new-york", meetupSlug: "us--ny--New York" },
  { name: "London", lumaSlug: "london", eventbriteSlug: "united-kingdom--london", ticketmaster: { city: "London", countryCode: "GB" }, meetupSlug: "gb--London" },
  // Luma's page slug is "bangalore" but the events themselves are
  // labelled "Bengaluru" on both Luma and Eventbrite.
  { name: "Bengaluru", lumaSlug: "bangalore", eventbriteSlug: "india--bengaluru", meetupSlug: "in--Bengaluru" },
  { name: "Mumbai", lumaSlug: "mumbai", eventbriteSlug: "india--mumbai", meetupSlug: "in--Mumbai" },
  // Luma's slug is "delhi" but the calendar (and Eventbrite's page)
  // are labelled "New Delhi".
  { name: "New Delhi", lumaSlug: "delhi", eventbriteSlug: "india--new-delhi", meetupSlug: "in--New Delhi" },

  // Gulf cities — Luma only covers Dubai; Eventbrite + Meetup carry
  // the rest. Ticketmaster/SeatGeek have no coverage here.
  { name: "Dubai", lumaSlug: "dubai", eventbriteSlug: "united-arab-emirates--dubai", meetupSlug: "ae--Dubai" },
  { name: "Abu Dhabi", eventbriteSlug: "united-arab-emirates--abu-dhabi", meetupSlug: "ae--Abu Dhabi" },
  { name: "Riyadh", eventbriteSlug: "saudi-arabia--ar-riyad", meetupSlug: "sa--Riyadh" },
  { name: "Jeddah", eventbriteSlug: "saudi-arabia--jeddah", meetupSlug: "sa--Jeddah" },

  // Qatar, Ireland, Scotland. Luma covers Dublin + Edinburgh (not Doha).
  { name: "Doha", eventbriteSlug: "qatar--doha", meetupSlug: "qa--Doha" },
  { name: "Dublin", lumaSlug: "dublin", eventbriteSlug: "ireland--dublin", ticketmaster: { city: "Dublin", countryCode: "IE" }, meetupSlug: "ie--Dublin" },
  { name: "Edinburgh", lumaSlug: "edinburgh", eventbriteSlug: "united-kingdom--edinburgh", ticketmaster: { city: "Edinburgh", countryCode: "GB" }, meetupSlug: "gb--Edinburgh" },
];

// MARK: - Categories (rawValues must match the app's EventCategory enum)

type Category =
  | "tech" | "ai" | "crypto" | "climate" | "fitness" | "wellness"
  | "music" | "arts" | "food" | "business" | "networking" | "sports"
  | "other";

type Source = "luma" | "eventbrite" | "ticketmaster" | "seatgeek" | "meetup";

/** Exact mapping from schema.org Event subtypes — declared by the
 *  listing site itself, so no guessing. null for generic/unknown. */
function categoryFromSchemaType(type: string | undefined): Category | null {
  switch (type) {
    case "MusicEvent": case "DanceEvent": return "music";
    case "SportsEvent": return "sports";
    case "TheaterEvent": case "ComedyEvent": case "VisualArtsEvent":
    case "ExhibitionEvent": case "LiteraryEvent": case "ScreeningEvent": return "arts";
    case "FoodEvent": return "food";
    case "BusinessEvent": case "SaleEvent": return "business";
    case "Hackathon": return "tech";
    case "SocialEvent": return "networking";
    default: return null;
  }
}

/** Keyword classification of the title as last resort. Short keywords
 *  like "ai" match whole words only — substring matching would tag
 *  "blockchain" as AI. */
function categoryFromRaw(raw: string | undefined): Category {
  if (!raw) return "other";
  const lower = raw.toLowerCase();
  const tokens = new Set(lower.split(/[^a-z0-9]+/).filter((t) => t.length > 0));
  const word = (...words: string[]) => words.some((w) => tokens.has(w));
  const phrase = (...phrases: string[]) => phrases.some((p) => lower.includes(p));

  // Specific topics first, broader buckets last.
  if (word("ai", "llm", "llms", "gpt", "genai", "agentic")
    || phrase("artificial intelligence", "machine learning", "deep learning")) return "ai";
  if (word("crypto", "web3", "blockchain", "bitcoin", "ethereum", "solana", "nft", "defi")) return "crypto";
  if (word("climate", "sustainability", "cleantech", "decarbonization")
    || phrase("net zero", "carbon", "clean energy")) return "climate";
  if (word("fitness", "yoga", "pilates", "workout", "marathon", "hike", "cycling", "crossfit")
    || phrase("run club")) return "fitness";
  if (word("wellness", "meditation", "mindfulness", "breathwork", "wellbeing")) return "wellness";
  if (phrase("music") || word("concert", "dj", "rave", "gig", "band")) return "music";
  if (word("art", "arts", "theatre", "theater", "film", "comedy", "museum", "gallery", "culture", "dance")) return "arts";
  if (word("food", "drink", "culinary", "tasting", "dinner", "brunch", "wine", "coffee")) return "food";
  if (phrase("sport") || word("nba", "nfl", "mlb", "nhl", "soccer", "cricket", "football")) return "sports";
  if (word("networking", "mixer", "meetup", "community", "social")) return "networking";
  if (word("business", "conference", "summit", "startup", "founders", "pitch", "marketing", "finance")) return "business";
  if (word("tech", "software", "coding", "hackathon", "developer", "developers", "data", "cloud", "saas")) return "tech";
  return "other";
}

// MARK: - Row shape (mirrors public.events / the app's AppEvent)

interface EventRow {
  registration_url: string;
  title: string;
  description: string | null;
  category: Category;
  city: string;
  venue: string | null;
  start_date: string | null; // ISO timestamptz
  image_url: string | null;
  price_text: string | null;
  source: Source;
}

// MARK: - Shared scraping helpers

/** Desktop Safari UA — listing pages serve their full SEO markup
 *  (including JSON-LD) to regular browsers. */
const USER_AGENT =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 " +
  "(KHTML, like Gecko) Version/17.4 Safari/605.1.15";

async function fetchHTML(url: string): Promise<string> {
  const response = await fetch(url, {
    headers: {
      "User-Agent": USER_AGENT,
      "Accept": "text/html,application/xhtml+xml",
      "Accept-Language": "en-US,en;q=0.9",
    },
    signal: AbortSignal.timeout(20_000),
    redirect: "follow",
  });
  if (!response.ok) throw new Error(`HTTP ${response.status} for ${url}`);
  return await response.text();
}

/** Pulls every <script type="application/ld+json"> block out of the
 *  page and returns all schema.org objects whose @type is an Event
 *  (Event, MusicEvent, SportsEvent, ...), however deeply nested
 *  (@graph, ItemList → item, arrays, ...). */
function schemaEvents(html: string): Record<string, unknown>[] {
  const pattern = /<script[^>]*type=["']application\/ld\+json["'][^>]*>(.*?)<\/script>/gis;
  const events: Record<string, unknown>[] = [];
  for (const match of html.matchAll(pattern)) {
    try {
      collectEvents(JSON.parse(match[1]), events);
    } catch {
      // Malformed JSON block — skip it.
    }
  }
  return events;
}

function collectEvents(object: unknown, events: Record<string, unknown>[]) {
  if (Array.isArray(object)) {
    for (const element of object) collectEvents(element, events);
    return;
  }
  if (object === null || typeof object !== "object") return;
  const dict = object as Record<string, unknown>;

  const rawType = dict["@type"];
  const types: string[] = typeof rawType === "string" ? [rawType]
    : Array.isArray(rawType) ? rawType.filter((t): t is string => typeof t === "string")
    : [];
  if (types.some((t) => t.endsWith("Event") || t === "Event")) {
    events.push(dict);
  }

  // Recurse into containers like @graph, itemListElement, item.
  for (const value of Object.values(dict)) collectEvents(value, events);
}

function decodeHTMLEntities(string: string): string {
  const entities: Record<string, string> = {
    "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": '"',
    "&#39;": "'", "&#x27;": "'", "&apos;": "'", "&nbsp;": " ",
  };
  let result = string;
  for (const [entity, character] of Object.entries(entities)) {
    result = result.replaceAll(entity, character);
  }
  return result;
}

/** Handles full ISO timestamps, local datetimes like
 *  "2026-06-12T19:00:00" (Ticketmaster) and date-only strings like
 *  "2026-06-13" (Eventbrite). Returns an ISO string or null. */
function parseDate(string: unknown): string | null {
  if (typeof string !== "string" || string.length === 0) return null;
  const date = new Date(string);
  return isNaN(date.getTime()) ? null : date.toISOString();
}

/** Sites label the same city differently ("Bengaluru" vs "Bangalore",
 *  ...). Canonical names follow what the platforms themselves use. */
function normalizeCity(raw: string): string {
  const city = raw.trim();
  const aliases: Record<string, string> = {
    "bangalore": "Bengaluru",
    "kings county": "Brooklyn",
    "new york city": "New York",
    "nyc": "New York",
    "manhattan": "New York",
    "greater london": "London",
    "sf": "San Francisco",
  };
  return aliases[city.toLowerCase()] ?? city;
}

/** Maps a schema.org Event dictionary to an EventRow.
 *  Category priority: the listing page's own category (when scraped
 *  from a per-category page), then the schema.org subtype the site
 *  declared, then keyword classification of the title. */
function mapSchemaEvent(
  dict: Record<string, unknown>,
  source: Source,
  fallbackCity: string,
  forcedCategory?: Category,
): EventRow | null {
  const rawName = dict["name"];
  const urlString = dict["url"];
  if (typeof rawName !== "string" || typeof urlString !== "string") return null;
  let url: URL;
  try {
    url = new URL(urlString);
  } catch {
    return null;
  }
  if (!url.protocol.startsWith("http")) return null;

  const name = decodeHTMLEntities(rawName);

  // City is always the metro whose page we scraped (fallbackCity) —
  // this keeps the app's filter to one entry per metro instead of a
  // long tail of suburbs. The venue name carries the precise location.
  const city = normalizeCity(fallbackCity);
  let venue: string | null = null;
  const location = dict["location"];
  if (location && typeof location === "object" && !Array.isArray(location)) {
    const loc = location as Record<string, unknown>;
    if (typeof loc["name"] === "string") venue = decodeHTMLEntities(loc["name"]);
    else if (typeof loc["address"] === "string" && loc["address"].length > 0) {
      venue = decodeHTMLEntities(loc["address"]);
    }
  }

  // Image: string, array of strings, or ImageObject
  let imageURL: string | null = null;
  const image = dict["image"];
  if (typeof image === "string") imageURL = image;
  else if (Array.isArray(image) && typeof image[0] === "string") imageURL = image[0];
  else if (image && typeof image === "object") {
    const src = (image as Record<string, unknown>)["url"];
    if (typeof src === "string") imageURL = src;
  }

  // Offers → price text
  let priceText: string | null = null;
  const rawOffers = dict["offers"];
  const offer = Array.isArray(rawOffers)
    ? (rawOffers[0] as Record<string, unknown> | undefined)
    : (rawOffers && typeof rawOffers === "object" ? rawOffers as Record<string, unknown> : undefined);
  if (offer) {
    const currency = typeof offer["priceCurrency"] === "string" ? offer["priceCurrency"] : "";
    const rawPrice = offer["lowPrice"] ?? offer["price"];
    if (rawPrice !== undefined && rawPrice !== null && `${rawPrice}`.length > 0) {
      const price = `${rawPrice}`;
      priceText = Number(price) === 0 ? "Free" : `From ${currency} ${price}`.trim();
    }
  }

  const rawDescription = dict["description"];
  const description = typeof rawDescription === "string" && rawDescription.length > 0
    ? decodeHTMLEntities(rawDescription)
    : null;
  const rawType = dict["@type"];
  const typeHint = typeof rawType === "string" ? rawType
    : Array.isArray(rawType) ? rawType[0] as string | undefined
    : undefined;
  const category = forcedCategory
    ?? categoryFromSchemaType(typeHint)
    ?? categoryFromRaw(name);

  return {
    registration_url: url.toString(),
    title: name,
    description,
    category,
    city,
    venue,
    start_date: parseDate(dict["startDate"]),
    image_url: imageURL,
    price_text: priceText,
    source,
  };
}

// MARK: - Scrape jobs

/** One listing page to scrape, with an optional category the page
 *  itself vouches for (e.g. Eventbrite's /music--events/ pages). */
interface ScrapeJob {
  url: string;
  source: Source;
  fallbackCity: string;
  forcedCategory?: Category;
  /** Meetup pages need Next.js parsing instead of JSON-LD. */
  parser?: "jsonld" | "meetup";
}

function buildJobs(): ScrapeJob[] {
  const jobs: ScrapeJob[] = [];

  for (const city of CITIES) {
    // Luma — city pages like lu.ma/sf
    if (city.lumaSlug) {
      jobs.push({ url: `https://lu.ma/${city.lumaSlug}`, source: "luma", fallbackCity: city.name });
    }

    // Eventbrite — per-category listing pages: every event scraped from
    // one of these was filed there by Eventbrite, so the category is
    // site-declared, not guessed.
    if (city.eventbriteSlug) {
      const categoryPages: [string, Category][] = [
        ["music--events", "music"],
        ["science-and-tech--events", "tech"],
        ["business--events", "business"],
        ["food-and-drink--events", "food"],
        ["arts--events", "arts"],
        ["health--events", "wellness"],
        ["sports-and-fitness--events", "sports"],
      ];
      for (const [slug, category] of categoryPages) {
        jobs.push({
          url: `https://www.eventbrite.com/d/${city.eventbriteSlug}/${slug}/`,
          source: "eventbrite",
          fallbackCity: city.name,
          forcedCategory: category,
        });
      }
    }

    // Ticketmaster is NOT page-scraped: its bot protection blocks
    // datacenter IPs. It's fetched via the Discovery API instead —
    // see fetchTicketmaster below.

    // SeatGeek — city pages. As of 2026-07 these return 404 (SeatGeek
    // removed/blocked them; the old on-device scraper hit the same
    // wall). Kept because failures are free and independent — if the
    // pages come back, coverage resumes automatically. SF/NYC are
    // meanwhile covered by Ticketmaster.
    if (city.seatgeekSlug) {
      jobs.push({
        url: `https://seatgeek.com/cities/${city.seatgeekSlug}`,
        source: "seatgeek",
        fallbackCity: city.name,
      });
    }

    // Meetup — find pages (Next.js Apollo state, not JSON-LD)
    if (city.meetupSlug) {
      jobs.push({
        url: `https://www.meetup.com/find/?location=${encodeURIComponent(city.meetupSlug)}&source=EVENTS`,
        source: "meetup",
        fallbackCity: city.name,
        parser: "meetup",
      });
    }
  }

  return jobs;
}

// MARK: - Ticketmaster (official Discovery API — free tier)

/** Maps a Discovery API "segment" (Ticketmaster's own top-level
 *  taxonomy) to an app category — site-declared, no guessing. */
function categoryFromTMSegment(segment: string | undefined, title: string): Category {
  switch (segment) {
    case "Music": return "music";
    case "Sports": return "sports";
    case "Arts & Theatre": case "Film": return "arts";
    default: return categoryFromRaw(title);
  }
}

/** One Discovery API call per covered city: the next ~100 events,
 *  soonest first. Free tier allows 5,000 calls/day and 5 req/s;
 *  this uses a handful per run, requested sequentially to stay far
 *  under the rate limit. */
async function fetchTicketmaster(apiKey: string): Promise<EventRow[]> {
  const rows: EventRow[] = [];

  for (const city of CITIES) {
    if (!city.ticketmaster) continue;
    const params = new URLSearchParams({
      apikey: apiKey,
      city: city.ticketmaster.city,
      countryCode: city.ticketmaster.countryCode,
      size: "100",
      sort: "date,asc",
    });
    const response = await fetch(
      `https://app.ticketmaster.com/discovery/v2/events.json?${params}`,
      { signal: AbortSignal.timeout(20_000) },
    );
    if (!response.ok) throw new Error(`Ticketmaster API HTTP ${response.status} for ${city.name}`);
    const json = await response.json();
    const events = json?._embedded?.events;
    if (!Array.isArray(events)) continue;

    for (const event of events) {
      const title = event?.name;
      const urlString = event?.url;
      if (typeof title !== "string" || typeof urlString !== "string") continue;
      try {
        new URL(urlString);
      } catch {
        continue;
      }

      // Prefer the wide 16:9 renditions the app's cards display.
      const images = Array.isArray(event?.images) ? event.images : [];
      const image = images.find((i: Record<string, unknown>) =>
        i?.ratio === "16_9" && typeof i?.width === "number" && i.width >= 640,
      ) ?? images[0];
      const imageURL = typeof image?.url === "string" ? image.url : null;

      const range = Array.isArray(event?.priceRanges) ? event.priceRanges[0] : undefined;
      let priceText: string | null = null;
      if (typeof range?.min === "number") {
        const currency = typeof range?.currency === "string" ? range.currency : "";
        priceText = range.min === 0 ? "Free" : `From ${currency} ${range.min}`.trim();
      }

      const venue = event?._embedded?.venues?.[0]?.name;
      const segment = event?.classifications?.[0]?.segment?.name;
      const startDate = parseDate(event?.dates?.start?.dateTime)
        ?? parseDate(event?.dates?.start?.localDate);

      rows.push({
        registration_url: urlString,
        title: decodeHTMLEntities(title),
        description: typeof event?.info === "string" && event.info.length > 0
          ? decodeHTMLEntities(event.info)
          : null,
        category: categoryFromTMSegment(
          typeof segment === "string" ? segment : undefined,
          title,
        ),
        city: normalizeCity(city.name),
        venue: typeof venue === "string" ? decodeHTMLEntities(venue) : null,
        start_date: startDate,
        image_url: imageURL,
        price_text: priceText,
        source: "ticketmaster",
      });
    }
  }

  return rows;
}

// MARK: - Meetup (Next.js Apollo state)

/** Meetup renders with Next.js: the find page holds every event in its
 *  Apollo cache (props.pageProps.__APOLLO_STATE__) as objects with
 *  __typename == "Event". Walk that cache and map each one. */
function parseMeetup(html: string, fallbackCity: string): EventRow[] {
  const match = html.match(
    /<script id="__NEXT_DATA__" type="application\/json"[^>]*>(.*?)<\/script>/s,
  );
  if (!match) return [];
  let apollo: Record<string, unknown>;
  try {
    const next = JSON.parse(match[1]);
    const pageProps = next?.props?.pageProps;
    apollo = pageProps?.__APOLLO_STATE__ ?? pageProps?.apolloState;
  } catch {
    return [];
  }
  if (!apollo || typeof apollo !== "object") return [];

  /** Resolves an Apollo value that may be either an inline object or a
   *  {"__ref": "Type:id"} pointer into the normalized cache. */
  const resolve = (value: unknown): Record<string, unknown> | null => {
    if (!value || typeof value !== "object" || Array.isArray(value)) return null;
    const dict = value as Record<string, unknown>;
    const ref = dict["__ref"];
    if (typeof ref === "string") {
      const target = apollo[ref];
      return target && typeof target === "object" ? target as Record<string, unknown> : null;
    }
    return dict;
  };

  const rows: EventRow[] = [];
  for (const value of Object.values(apollo)) {
    if (!value || typeof value !== "object") continue;
    const event = value as Record<string, unknown>;
    if (event["__typename"] !== "Event") continue;

    const title = event["title"];
    const urlString = event["eventUrl"];
    if (typeof title !== "string" || typeof urlString !== "string") continue;
    try {
      new URL(urlString);
    } catch {
      continue;
    }

    // Venue (may be inline or an Apollo __ref). City is the scraped
    // metro; online events get their own "Online" bucket.
    const venueDict = resolve(event["venue"]);
    const isOnline = event["eventType"] === "ONLINE";
    const city = isOnline ? "Online" : normalizeCity(fallbackCity);
    const venueName = isOnline
      ? "Online event"
      : (typeof venueDict?.["name"] === "string" ? venueDict["name"] as string : null);

    // Photo (Apollo __ref → PhotoInfo.highResUrl).
    let imageURL: string | null = null;
    const photo = resolve(event["featuredEventPhoto"] ?? event["displayPhoto"]);
    const src = photo?.["highResUrl"] ?? photo?.["source"];
    if (typeof src === "string") imageURL = src;

    // Fee: absent means free; present carries amount + currency.
    let priceText = "Free";
    const fee = resolve(event["feeSettings"]);
    const amount = fee?.["amount"];
    if (typeof amount === "number" && amount > 0) {
      const currency = typeof fee?.["currency"] === "string" ? fee["currency"] as string : "";
      priceText = `From ${currency} ${Math.trunc(amount)}`.trim();
    }

    const rawDescription = event["description"];
    const description = typeof rawDescription === "string" && rawDescription.length > 0
      ? decodeHTMLEntities(rawDescription)
      : null;

    rows.push({
      registration_url: urlString,
      title: decodeHTMLEntities(title),
      description,
      category: categoryFromRaw(title),
      city,
      venue: venueName,
      start_date: parseDate(event["dateTime"]),
      image_url: imageURL,
      price_text: priceText,
      source: "meetup",
    });
  }
  return rows;
}

// MARK: - Orchestration

/** Deno.env in the deployed function; process.env when the pipeline
 *  runs under Node for local testing. */
function readEnv(name: string): string | undefined {
  const g = globalThis as Record<string, any>;
  return g.Deno?.env?.get?.(name) ?? g.process?.env?.[name];
}

interface ScrapeSummary {
  pages: number;
  pagesFailed: number;
  perSource: Record<string, number>;
  deduped: number;
  errors: string[];
}

async function scrapeAll(): Promise<{ rows: EventRow[]; summary: ScrapeSummary }> {
  const jobs = buildJobs();
  // The TICKETMASTER_API_KEY secret (if set in the dashboard) takes
  // priority; otherwise fall back to the project's baked-in key.
  const tmApiKey = readEnv("TICKETMASTER_API_KEY")
    ?? "FVFsbAR8DDeltztK3LHBqyKBdkGGAw0l";

  const pageTasks = jobs.map(async (job): Promise<EventRow[]> => {
    const html = await fetchHTML(job.url);
    if (job.parser === "meetup") return parseMeetup(html, job.fallbackCity);
    return schemaEvents(html)
      .map((dict) => mapSchemaEvent(dict, job.source, job.fallbackCity, job.forcedCategory))
      .filter((row): row is EventRow => row !== null);
  });
  // Ticketmaster rides along as one extra "job": present only when
  // the TICKETMASTER_API_KEY secret is configured, and failing
  // independently like every scraped page.
  const tasks = tmApiKey ? [...pageTasks, fetchTicketmaster(tmApiKey)] : pageTasks;
  const taskLabels = [
    ...jobs.map((job) => job.url),
    ...(tmApiKey ? ["ticketmaster discovery api"] : []),
  ];

  const results = await Promise.allSettled(tasks);

  const summary: ScrapeSummary = {
    pages: tasks.length,
    pagesFailed: 0,
    perSource: {},
    deduped: 0,
    errors: tmApiKey ? [] : ["ticketmaster skipped: TICKETMASTER_API_KEY secret not set"],
  };

  // Dedup by registration URL (the same event can appear on multiple
  // scraped pages); when duplicated, keep the entry with a
  // site-declared category over one filed under "other".
  const byURL = new Map<string, EventRow>();
  results.forEach((result, index) => {
    if (result.status === "rejected") {
      summary.pagesFailed += 1;
      // Keep error list short — some sites fail routinely.
      if (summary.errors.length < 15) {
        summary.errors.push(`${taskLabels[index]}: ${result.reason?.message ?? result.reason}`);
      }
      return;
    }
    for (const row of result.value) {
      summary.perSource[row.source] = (summary.perSource[row.source] ?? 0) + 1;
      const existing = byURL.get(row.registration_url);
      if (existing && existing.category !== "other") continue;
      byURL.set(row.registration_url, row);
    }
  });

  summary.deduped = byURL.size;
  return { rows: [...byURL.values()], summary };
}

// MARK: - Handler

Deno.serve(async (_request) => {
  try {
    const { rows, summary } = await scrapeAll();

    const supabaseURL = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    let upserted = 0;
    let dryRun = true;
    if (supabaseURL && serviceKey && rows.length > 0) {
      dryRun = false;
      const supabase = createClient(supabaseURL, serviceKey);
      const now = new Date().toISOString();
      const { error } = await supabase
        .from("events")
        .upsert(
          rows.map((row) => ({ ...row, last_seen_at: now, updated_at: now })),
          { onConflict: "registration_url" },
        );
      if (error) throw new Error(`upsert failed: ${error.message}`);
      upserted = rows.length;
    }

    const body = { ok: true, dryRun, upserted, ...summary };
    console.log(JSON.stringify(body));
    return new Response(JSON.stringify(body), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(JSON.stringify({ ok: false, error: message }));
    return new Response(JSON.stringify({ ok: false, error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
