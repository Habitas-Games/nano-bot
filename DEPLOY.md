# Deployment: Making nano-bot Public

This guide explains how to push the project to GitHub and enable public hosting.

---

## Prerequisites

- GitHub account
- Git installed locally
- This repository already initialized with all files committed

---

## Step 1: Create a GitHub repository

1. Go to [github.com/new](https://github.com/new)
2. Repository name: `nano-bot`
3. Description: "A turn-based AI programming competition set inside a simulated human body"
4. **Public** (not private)
5. Do **NOT** initialize with README, .gitignore, or license (we already have these)
6. Click **Create repository**

---

## Step 2: Push local repo to GitHub

Copy the repository URL from GitHub (e.g., `https://github.com/mnavas/nano-bot.git` or `git@github.com:mnavas/nano-bot.git`), then:

```bash
cd /path/to/nano-bot

# Add GitHub as remote
git remote add origin https://github.com/YOUR_USERNAME/nano-bot.git

# Rename default branch to main (if still on master)
git branch -M main

# Push everything
git push -u origin main
```

---

## Step 3: Enable GitHub Pages

1. Go to your repository on GitHub
2. **Settings** → **Pages** (left sidebar)
3. Under **Build and deployment**:
   - **Source**: Select **GitHub Actions**
   - (The workflow at `.github/workflows/pages.yml` will deploy automatically)
4. Click **Save**

The site will deploy automatically on each push to `main`. Wait 1–2 minutes for the first deploy.

---

## Step 4: Verify deployment

Once deployed, your site is live at:

```
https://YOUR_USERNAME.github.io/nano-bot/
```

Check:
- ✅ Homepage loads (`index.html`)
- ✅ Participant guide opens (`docs/participant_guide.html`)
- ✅ All images display (hero, bots, tiles)
- ✅ Navigation links work

---

## Step 5: Custom domain (optional)

To use a custom domain (e.g., `nano-bot.dev`):

1. **Settings** → **Pages**
2. Enter your custom domain in **Custom domain**
3. Update your domain's DNS records to point to GitHub Pages (see GitHub's [docs](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site))

---

## What's deployed?

Everything in the repository root is deployed, except:

- `.godot/` — auto-generated cache (in `.gitignore`)
- `/replays/` — match replays (in `.gitignore`)
- `.git/` — git metadata (automatically excluded)

---

## After deployment: maintain

### Updating content

```bash
# Make changes locally
git add -A
git commit -m "Update docs/features/etc"
git push
# Site auto-deploys within 1–2 minutes
```

### Monitoring

- **Actions** tab on GitHub — view deployment logs
- **GitHub Pages** section in Settings — see deployment status
- **Issues** tab — accept bug reports from users

---

## Environment variables (if needed later)

For future CI/CD (tests, builds), the workflow at `.github/workflows/pages.yml` has:

```yaml
permissions:
  contents: read
  pages: write
  id-token: write
```

This allows automatic deployment without additional secrets.

---

## Troubleshooting

| Issue | Solution |
|---|---|
| Pages not deploying | Check **Actions** tab for workflow errors |
| 404 on site | Verify `index.html` exists in repo root |
| Images broken | Check that image paths in HTML are correct and files exist in repo |
| Old content showing | Clear browser cache or wait for new deploy (1–2 min) |
| HTTPS not working | GitHub Pages auto-enables HTTPS; wait a few minutes or try a different browser |

---

## Next steps

After going public:

1. **Announce** on social media, forums, or communities
2. **Monitor issues** — respond to bug reports and feature requests
3. **Iterate** — update guide, add example strategies, fix bugs
4. **Grow community** — engage participants, accept contributions via PRs

---

## Support

For GitHub Pages issues, see [GitHub's documentation](https://docs.github.com/en/pages).
For project issues, see [CONTRIBUTING.md](CONTRIBUTING.md).
