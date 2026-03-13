# Mockup Builder Prompt

Paste this into your Claude Code system prompt or use it as a prefix.

---

I'm about to describe something to build as a visual mockup. Build it as a **single self-contained HTML file** with these requirements:

- **Tailwind CSS** via CDN: `<script src="https://cdn.tailwindcss.com"></script>`
- **Alpine.js** via CDN: `<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>`
- All styles, scripts, and markup in one `.html` file — no external dependencies beyond those two CDNs
- **Be token-efficient**: define all hard-coded/sample data as a JSON object in an `x-data` attribute or a `<script>` block, then render it with Alpine's `x-for`, `x-text`, `x-show`, etc. Don't repeat markup for every item — loop over the data instead.
- Use realistic sample data (real-looking names, dates, amounts, etc.) — enough to make the mockup feel populated but not excessive
- Make it look polished: use Tailwind utility classes for spacing, color, typography, and responsive layout
- Include interactive behavior where it makes sense (toggles, modals, tab switching, form inputs) using Alpine.js

Save the file to `~/GXB/mockups/` with a descriptive kebab-case filename (e.g. `todo-list.html`).

After saving, run:
```bash
open ~/GXB/mockups/  # open the folder in Finder
open ~/GXB/mockups/<filename>.html  # open in the default browser
```

Here's what I want you to build:
