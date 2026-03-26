# Plan: media.gxb.vc — Media Processing API

API-only Rails app that accepts media URLs (YouTube videos, direct MP4s, podcast RSS feeds, audio files), downloads them, extracts audio, and serves everything via a token-authenticated REST API. Transcription happens externally (e.g., whisper.cpp on a local machine) and is uploaded back via the API.

Supports multiple media types through a unified pipeline:
- **YouTube videos** → download → extract audio → transcribe
- **Direct video URLs** (MP4, etc.) → download → extract audio → transcribe
- **Podcast episodes** (RSS feed or direct audio URL) → download audio → transcribe
- **Direct audio files** (MP3, WAV, etc.) → download → transcribe

## Domain: media.gxb.vc

Port: 3122 (next available after gxb:3121)

---

## 1. YouTube Download Strategy — Use Your Mac

The key insight: **your Mac at home IS a residential IP with real browser cookies.** Don't pay a proxy service to simulate what you already have for free.

### The Problem
YouTube blocks VPS/datacenter IPs, requires cookies from real browser sessions, and uses SABR which breaks naive downloaders. On a server, you don't have any of this. But on your Mac, you have everything YouTube wants to see.

### Architecture: Split Download Workers

The VPS handles the easy stuff. Your Mac handles YouTube.

```
┌─────────────────────────────────────┐
│  VPS (media.gxb.vc)                │
│                                     │
│  API server + job orchestrator      │
│  Downloads: direct URLs, podcasts   │
│  Processing: ffmpeg audio extract   │
│  Storage: streams to B2             │
│                                     │
│  YouTube jobs sit in "needs_download"│
│  state, waiting for Mac worker      │
└──────────────┬──────────────────────┘
               │ API calls over Tailscale
┌──────────────▼──────────────────────┐
│  Your Mac (home, residential IP)    │
│                                     │
│  Polls API for YouTube jobs         │
│  yt-dlp --cookies-from-browser firefox │
│  Uploads directly to B2             │
│  Notifies API when done             │
│                                     │
│  Fallback: agent-chrome MediaRecorder │
│  for age-restricted / stubborn videos│
└─────────────────────────────────────┘
```

**Why this is better than proxies:**
- **$0/month** instead of $5-15/month for residential proxies
- **Real residential IP** — not a proxy that YouTube might fingerprint
- **Real browser cookies** — `yt-dlp --cookies-from-browser firefox` works locally on Mac (the only reliable cookie method in 2026, since Chrome's DPAPI encryption kills all other extraction)
- **MediaRecorder fallback** — for truly stubborn/age-restricted videos, `agent-chrome` can capture the video stream from your logged-in Chrome session (see `~/docs/downloading-age-restricted-youtube-videos.md`)
- **Already on Tailscale** — Mac can reach the API and B2 without any network setup
- **Mac is always on** — already running cron jobs

### Mac Worker Script (`~/cron/minutely/media-download-worker.sh`)

```bash
#!/bin/bash
# Poll for YouTube download jobs, download locally, upload to B2

API="https://media.gxb.vc/api/v1"
TOKEN="$MEDIA_API_TOKEN"

# Get next YouTube job needing download
JOB=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "$API/media?status=needs_download&source_type=youtube&limit=1")

VIDEO_ID=$(echo "$JOB" | jq -r '.[0].id // empty')
[ -z "$VIDEO_ID" ] && exit 0

URL=$(echo "$JOB" | jq -r '.[0].url')

# Claim the job (prevent double-processing)
curl -s -X PATCH -H "Authorization: Bearer $TOKEN" \
  "$API/media/$VIDEO_ID" -d '{"status":"downloading"}'

# Download with yt-dlp using local Firefox cookies
TMPDIR=$(mktemp -d)
yt-dlp --cookies-from-browser firefox \
  -f "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]" \
  -o "$TMPDIR/%(id)s.%(ext)s" \
  --write-info-json \
  "$URL" 2>"$TMPDIR/error.log"

if [ $? -eq 0 ]; then
  # Upload video file to B2 via the API (or directly to B2)
  VIDEO_FILE=$(find "$TMPDIR" -name "*.mp4" -o -name "*.webm" | head -1)
  META_FILE=$(find "$TMPDIR" -name "*.info.json" | head -1)

  curl -X PATCH -H "Authorization: Bearer $TOKEN" \
    -F "video_file=@$VIDEO_FILE" \
    -F "metadata=@$META_FILE" \
    "$API/media/$VIDEO_ID/upload"
else
  # Report failure
  ERROR=$(cat "$TMPDIR/error.log" | tail -5)
  curl -s -X PATCH -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"status\":\"download_failed\",\"error_message\":\"$ERROR\"}" \
    "$API/media/$VIDEO_ID"
fi

rm -rf "$TMPDIR"
```

### Tier 2: VPS direct download (for non-YouTube or if Mac is offline)
For direct video/audio URLs and podcast episodes, the VPS downloads them directly — no proxy needed. These are public files that don't fight scrapers.

### Tier 3: Fallback for stubborn YouTube videos
If yt-dlp fails even on the Mac (age-restricted, etc.), the agent-chrome MediaRecorder approach captures the actual video stream from a logged-in Chrome session. This is slower (real-time recording) but works for anything you can play in a browser.

### For direct MP4/video/audio URLs
The VPS handles these directly using the `Down` gem or `open-uri` — no special handling needed.

### For podcasts
Parse RSS feed → extract episode enclosure URL → download directly on VPS. Podcast audio files are always public and never geo-blocked.

---

## 2. Data Models

### `ApiToken` (authentication)
```
id: bigint (PK)
name: string          # "fileinbox-prod", "book-app", etc.
token_digest: string  # bcrypt digest of the actual token (shown once on creation)
active: boolean       # can be revoked
last_used_at: datetime
created_at/updated_at
```

No User model needed — just API tokens. Each token represents a client app. Token is generated once, shown to the creator, and only the digest is stored (like GitHub personal access tokens).

### `MediaItem`
```
id: bigint (PK)
api_token_id: bigint (FK)       # which client submitted this
url: string                      # original URL submitted
normalized_url: string           # canonical form (strip tracking params, normalize youtube URLs)
media_type: string               # "video", "audio"
source_type: string              # "youtube", "direct_video", "direct_audio", "podcast", "upload"
status: string                   # see state machine below
title: string
description: text
duration_seconds: integer
thumbnail_url: string
source_metadata: jsonb           # raw metadata from yt-dlp/HTTP headers/RSS
source_strategy: string          # which download method succeeded ("mac_worker", "vps_direct", "media_recorder")
error_message: text              # if failed, why
webhook_url: string              # optional, per-submission callback URL

# For podcast episodes:
podcast_feed_url: string         # the RSS feed URL
podcast_name: string             # podcast title from RSS
episode_number: integer

# Active Storage attachments:
#   has_one_attached :original_file  # the downloaded video or audio file
#   has_one_attached :audio_file     # extracted audio (only for videos; for audio sources, original_file IS the audio)

created_at/updated_at
```

**Status state machine:**
```
pending → needs_download → downloading → downloaded → extracting_audio → audio_ready → transcribed
              │                │                              │
              └── failed ◄─────┴──────────────────────────────┘
```

- `pending` — just created, about to fetch metadata
- `needs_download` — metadata fetched, waiting for download (YouTube jobs wait here for Mac worker)
- `downloading` — claimed by a worker, actively downloading
- `downloaded` — file stored in B2, audio extraction queued (or skipped if source is audio)
- `extracting_audio` — ffmpeg running
- `audio_ready` — audio available, ready for external transcription
- `transcribed` — at least one transcription uploaded
- `failed` — terminal failure (with error_message)

For audio sources (podcasts, direct audio), the flow skips `extracting_audio` — the original file IS the audio, so it goes straight from `downloaded` → `audio_ready`.

### `Transcription`
```
id: bigint (PK)
media_item_id: bigint (FK)
language: string              # "en", etc.
format: string                # "vtt", "srt", "txt", "json"
content: text                 # the actual transcription text
segments: jsonb               # timestamped segments [{start, end, text}, ...]
model: string                 # "whisper-large-v3", etc.
created_at/updated_at
```

A media item can have multiple transcriptions (different languages, different models, corrections).

---

## 3. API Design

All endpoints require `Authorization: Bearer <token>` header.

### Media Items

```
POST   /api/v1/media           # Submit a URL or upload a file
GET    /api/v1/media           # List media (filterable by status, source_type, media_type)
GET    /api/v1/media/:id       # Get media details + status + download URLs
PATCH  /api/v1/media/:id       # Update status, upload files (used by Mac worker)
DELETE /api/v1/media/:id       # Remove a media item
```

**POST /api/v1/media**
```json
// Submit by URL:
{
  "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
  "webhook_url": "https://myapp.com/webhooks/media-ready"  // optional
}

// Podcast episode:
{
  "url": "https://feeds.example.com/podcast.xml",
  "episode_url": "https://cdn.example.com/ep42.mp3"  // optional, otherwise fetches latest
}

// Or upload directly:
// multipart form with `file` field + optional `webhook_url`
```

**Response (201 or 200 if already exists):**
```json
{
  "id": 42,
  "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
  "media_type": "video",
  "source_type": "youtube",
  "status": "pending",
  "title": null,
  "duration_seconds": null,
  "original_file_url": null,
  "audio_file_url": null,
  "transcriptions": [],
  "created_at": "2026-03-24T18:41:00Z"
}
```

If the normalized URL already exists, return the existing media item with its current status (200 instead of 201). The `webhook_url` is per-submission — if a new client submits an already-processed item, they get the data immediately.

**GET /api/v1/media/:id**
```json
{
  "id": 42,
  "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
  "media_type": "video",
  "source_type": "youtube",
  "status": "audio_ready",
  "title": "Rick Astley - Never Gonna Give You Up",
  "description": "...",
  "duration_seconds": 213,
  "thumbnail_url": "https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg",
  "source_metadata": { ... },
  "original_file_url": "https://media.gxb.vc/rails/active_storage/blobs/...",
  "audio_file_url": "https://media.gxb.vc/rails/active_storage/blobs/...",
  "transcriptions": [
    {
      "id": 7,
      "language": "en",
      "format": "json",
      "model": "whisper-large-v3",
      "content": "...",
      "segments": [...]
    }
  ],
  "created_at": "2026-03-24T18:41:00Z"
}
```

**PATCH /api/v1/media/:id** (used by Mac worker + status updates)
```
# Claim a job:
{"status": "downloading"}

# Upload completed download (multipart):
video_file=@file.mp4  metadata=@info.json

# Report failure:
{"status": "failed", "error_message": "yt-dlp: HTTP 403"}
```

### Transcriptions

```
POST   /api/v1/media/:media_id/transcriptions    # Upload a transcription
GET    /api/v1/media/:media_id/transcriptions     # List transcriptions
GET    /api/v1/media/:media_id/transcriptions/:id # Get one
DELETE /api/v1/media/:media_id/transcriptions/:id # Remove
```

**POST /api/v1/media/:media_id/transcriptions**
```json
{
  "language": "en",
  "format": "json",
  "model": "whisper-large-v3",
  "content": "full text of transcription...",
  "segments": [
    {"start": 0.0, "end": 2.5, "text": "We're no strangers to love"},
    {"start": 2.5, "end": 5.1, "text": "You know the rules and so do I"}
  ]
}
```

### Webhooks

When a media item reaches `audio_ready` or `transcribed` (or `failed`), POST to the `webhook_url`:
```json
{
  "event": "media.audio_ready",
  "media": { /* full media JSON */ }
}
```

Events: `media.needs_download`, `media.downloaded`, `media.audio_ready`, `media.transcribed`, `media.failed`

---

## 4. Job Pipeline

All jobs use Solid Queue. Each job triggers the next on success.

### VPS-side jobs (for direct URLs, podcasts, audio)

```
ProcessMediaJob (entry point — created on POST /api/v1/media)
  └─→ FetchMetadataJob
        ├─ YouTube: yt-dlp --dump-json via Mac worker (or skip, Mac fetches metadata during download)
        ├─ Direct video/audio: HEAD request for content-type, content-length
        ├─ Podcast RSS: parse feed, extract episode metadata
        └─ Sets title, description, duration, thumbnail_url, source_metadata
            └─→ For YouTube: set status to "needs_download" (Mac worker picks it up)
                For everything else: DownloadMediaJob
                  ├─ Uses Down gem to stream directly to B2 via Active Storage
                  └─→ ExtractAudioJob (only for video sources)
                        ├─ ffmpeg -i input.mp4 -vn -acodec libmp3lame -q:a 2 audio.mp3
                        ├─ Attaches audio_file via Active Storage
                        └─ Sets status to "audio_ready"
                            └─→ WebhookDeliveryJob (if webhook_url present)
```

For audio sources (podcasts, direct MP3), skip ExtractAudioJob — the original file IS the audio. Just copy the attachment reference and go straight to `audio_ready`.

### Mac-side workers (two cron scripts)

**1. YouTube Download Worker** (`~/cron/minutely/media-download-worker.sh`)
Polls for `needs_download` + `source_type=youtube` jobs. Downloads with yt-dlp using local Firefox cookies. Uploads to the API. (See script in Section 1.)

**2. Transcription Worker** (`~/cron/minutely/media-transcribe-worker.sh`)
```bash
#!/bin/bash
# Poll for media needing transcription
API="https://media.gxb.vc/api/v1"
TOKEN="$MEDIA_API_TOKEN"

ITEMS=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "$API/media?status=audio_ready&limit=1")

ITEM_ID=$(echo "$ITEMS" | jq -r '.[0].id // empty')
[ -z "$ITEM_ID" ] && exit 0

# Download audio
AUDIO_URL=$(echo "$ITEMS" | jq -r '.[0].audio_file_url')
TMPDIR=$(mktemp -d)
curl -s -o "$TMPDIR/audio.mp3" "$AUDIO_URL"

# Transcribe with whisper.cpp
whisper-cpp -m ~/models/ggml-large-v3.bin \
  -f "$TMPDIR/audio.mp3" -oj -of "$TMPDIR/transcript"

# Upload transcription
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"language\": \"en\",
    \"format\": \"json\",
    \"model\": \"whisper-large-v3\",
    \"content\": $(jq -Rs . < "$TMPDIR/transcript.txt"),
    \"segments\": $(jq '.transcription' < "$TMPDIR/transcript.json")
  }" \
  "$API/media/$ITEM_ID/transcriptions"

rm -rf "$TMPDIR"
```

Both cron scripts process one item per run (minutely cron = up to 1 item/minute). For bursts, could run them more frequently or process multiple items per run.

---

## 5. Active Storage Configuration

For production, use S3-compatible storage (DigitalOcean Spaces or AWS S3). Videos can be large, so:

- Set `config.active_storage.service = :digitalocean` (or `:amazon`)
- Enable direct uploads for the upload-a-file flow
- Set reasonable `content_types_allowed` on attachments
- Use `variant_processor` for thumbnails if needed later

---

## 6. Implementation Steps

### Phase 1: Scaffold
1. Clone rails-template, run `bin/setup-new-project --name media --domain media.gxb.vc --server-ip <IP>`
2. Strip out all non-API stuff (views, layouts, Tailwind, Alpine — API only)
3. Set `config.api_only = true` in `application.rb`
4. Add port 3122 to `~/projects/.ports`

### Phase 2: Auth
5. Generate `ApiToken` model with `token_digest`, `name`, `active`, `last_used_at`
6. Add `authenticate_api_token!` concern for controllers
7. Add rake task to create tokens: `rake api_tokens:create NAME=fileinbox`

### Phase 3: MediaItem model + API
8. Generate `MediaItem` model with all fields
9. Generate `Transcription` model
10. Build `Api::V1::MediaController` (CRUD + upload endpoint)
11. Build `Api::V1::TranscriptionsController` (CRUD nested under media)
12. URL normalization logic (strip tracking params, normalize `youtu.be` → `youtube.com`, etc.)
13. Deduplication: find_or_create by `normalized_url`
14. Source type detection (YouTube URL patterns, audio file extensions, RSS feeds)

### Phase 4: Job pipeline (VPS side)
15. `FetchMetadataJob` — HEAD for direct URLs, RSS parsing for podcasts
16. `DownloadMediaJob` — stream direct URLs to B2 via Active Storage
17. `ExtractAudioJob` — ffmpeg audio extraction (video sources only)
18. `WebhookDeliveryJob` — POST to webhook_url with retry
19. Wire up the job chain

### Phase 5: B2 + Active Storage
20. Create B2 bucket, generate application keys
21. Configure `storage.yml` with B2 S3-compatible endpoint
22. Pin `aws-sdk-s3` gem version
23. Test uploads and signed URL generation

### Phase 6: Deploy
24. Provision 2GB DigitalOcean droplet
25. Configure Kamal for media.gxb.vc
26. Set up DigitalOcean DNS (gxb.vc DNS is on DigitalOcean)
27. Install ffmpeg in Dockerfile
28. Deploy and test with direct URL submissions

### Phase 7: Mac workers
29. Write YouTube download worker script
30. Write transcription worker script
31. Set up both as cron jobs on Mac
32. Create API token for Mac worker
33. Test full YouTube pipeline: submit URL → Mac downloads → B2 → audio extract → transcribe → upload

### Phase 8: Podcast support
34. Add RSS feed parsing (can use `feedjira` gem)
35. Test with a few podcast feeds
36. Optionally: bulk import from an OPML file

---

## 7. Dependencies

**Server-side (in Dockerfile):**
- `ffmpeg` (for audio extraction)
- Ruby gems: `down` (for direct URL downloads), `aws-sdk-s3` (~1.177.0, for B2), `feedjira` (RSS parsing), `faraday` (webhooks)

**Local (your Mac):**
- `yt-dlp` (latest, update frequently)
- Firefox (for cookie extraction)
- `whisper.cpp` with large-v3 model
- `curl` + `jq` for the worker scripts
- `agent-chrome` (fallback for stubborn videos)

**Services:**
- Backblaze B2 bucket ($6/TB/month)
- DigitalOcean 2GB droplet ($12/month)
- No proxy service needed!

---

## 8. Decisions Made

1. **Server**: New small droplet (2GB RAM). Video processing is bursty but not concurrent — jobs run sequentially. ffmpeg and yt-dlp are fine on 2GB for one-at-a-time processing. The video files themselves stream directly to B2, so disk usage stays low (just temp files during processing).

2. **Storage**: Backblaze B2 via S3-compatible API.
   - **$6/TB/month** storage (vs $23/TB on S3, $20/TB on DO Spaces)
   - **Free egress up to 3x monthly storage** (e.g., store 100GB → 300GB free egress/month). Since this is just one client app pulling files, egress will be minimal.
   - **Free egress to Cloudflare** if we ever need CDN
   - Rails Active Storage works with B2 via the `aws-sdk-s3` gem — B2 is S3-compatible. Just set the endpoint in `storage.yml`:
     ```yaml
     backblaze:
       service: S3
       access_key_id: <%= Rails.application.credentials.dig(:b2, :key_id) %>
       secret_access_key: <%= Rails.application.credentials.dig(:b2, :access_key) %>
       endpoint: https://s3.us-west-004.backblazeb2.com
       bucket: videos-gxb-vc
       region: us-west-004
       # B2 doesn't support AWS's newer checksum headers yet
       request_checksum_calculation: when_required
       response_checksum_validation: when_required
     ```
   - **Important**: Pin `aws-sdk-s3` gem to ~1.177.0 — newer versions send Data Integrity Protection headers that B2 doesn't support yet.
   - **Video retention**: Keep forever. At $6/TB/month, even 1TB of video is only $6/mo.
   - **Streaming to bucket**: For downloads, we can pipe yt-dlp output directly through to B2 using Active Storage's `#attach` with an IO stream, keeping temp disk usage minimal on the 2GB droplet.

3. **Proxy provider**: **None needed!** Your Mac at home is a residential IP with real browser cookies. See Section 1 for the full architecture. YouTube downloads happen on the Mac, everything else downloads directly on the VPS. $0/month.

4. **Rate limiting**: Not for v1. Single client, trusted. Add later if needed.

5. **Cobalt / RapidAPI**: Skip both. See below for reference.

### What is Cobalt? (skipped)
[Cobalt](https://github.com/imputnet/cobalt) is an open-source media downloader with a clean REST API. You self-host it as a Docker container, send it a URL via `POST /`, and it returns a download link. It supports YouTube, TikTok, Twitter, Instagram, etc. Think of it as "yt-dlp as a web service." The catch: YouTube keeps blocking it, and self-hosted instances need residential proxies too — same problem we're avoiding by using the Mac worker approach.

### What about RapidAPI? (skipped)
RapidAPI is a marketplace of third-party APIs. Several vendors offer YouTube download APIs (free tiers: 100-500 req/month, paid: $10-30/month). They handle yt-dlp/proxy headaches on their end. The problem: small vendors who break/disappear regularly. Could be a Tier 2 fallback if the Mac worker ever fails, but not worth setting up proactively.

## 9. Cost Estimate (Monthly)

| Item | Cost |
|------|------|
| DigitalOcean 2GB droplet | $12/mo |
| Backblaze B2 (100GB stored) | $0.60/mo |
| B2 egress (free up to 3× storage) | $0 |
| YouTube proxy | $0 (Mac worker) |
| Domain (media.gxb.vc) | Already own gxb.vc |
| **Total** | **~$13/mo** |

At 1TB stored (~500 videos), still only $18/mo. Scales very cheaply.
