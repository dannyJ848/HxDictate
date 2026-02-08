# Enable WebSearch for Psyche

This lets me search the web for current info (latest models, iOS updates, etc.)

---

## Option 1: Brave Search API (Recommended)

### Step 1: Get API Key
1. Go to https://brave.com/search/api/
2. Sign up for free tier (2000 queries/month)
3. Generate API key

### Step 2: Configure OpenClaw

```bash
# Option A: Via openclaw CLI
openclaw configure --section web
# Enter your Brave API key when prompted

# Option B: Environment variable
export BRAVE_API_KEY="your_key_here"

# Add to your shell profile for persistence
echo 'export BRAVE_API_KEY="your_key_here"' >> ~/.zshrc
```

### Step 3: Test
```bash
openclaw web-search "latest whisper.cpp iOS performance"
```

---

## Option 2: Alternative Search APIs

If Brave doesn't work for you:

### Serper.dev (Google Search API)
```bash
openclaw configure --section serper
# Enter Serper API key
```

### Tavily (AI-optimized search)
```bash
openclaw configure --section tavily
# Enter Tavily API key
```

---

## What I Can Do With WebSearch

Once enabled, I can:

- **Check for newer models** — "Is there a Whisper Large v4 yet?"
- **Find optimized builds** — "llama.cpp iOS Metal performance tips"
- **Research medical AI** — "FDA-approved medical dictation apps 2025"
- **iOS updates** — "iOS 18 on-device ML new features"
- **Model downloads** — Direct links to latest GGUF files

---

## Free Tier Limits

| Provider | Free Queries | Rate Limit |
|----------|--------------|------------|
| Brave | 2000/month | 1/sec |
| Serper | 2500/month | N/A |
| Tavily | 1000/month | 20/min |

For development, Brave's 2000/month is plenty.

---

## Quick Test

After setup, ask me:
> "Search for the latest DeepSeek model releases"

If I can search, I'll find and summarize current info. If not, I'll tell you websearch isn't configured.

