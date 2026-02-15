# Phase 2: Tailwind CSS v4

## Goal

Configure Tailwind CSS v4 with class-based dark mode, typography plugin, forms plugin, and a clean default theme.

## Steps

### 2.1 Verify tailwindcss-rails installation

The `--css=tailwind` flag in Phase 1 should have installed `tailwindcss-rails`. Verify:

```bash
bin/rails tailwindcss:build  # Should succeed
```

If not already installed:
```bash
bin/rails tailwindcss:install
```

### 2.2 Configure app/assets/tailwind/application.css

Replace the generated file with our config:

```css
@import "tailwindcss";
@plugin "@tailwindcss/typography";
@plugin "@tailwindcss/forms";

/* Class-based dark mode (not prefers-color-scheme) */
@custom-variant dark (&:where(.dark, .dark *));

@theme {
  --font-sans: "Inter", ui-sans-serif, system-ui, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji";
}
```

Notes:
- `@custom-variant dark` enables the three-way toggle (light/dark/auto) with a CSS class on `<html>`.
- We use Inter as the default sans font. The layout will load it from Google Fonts (or you can bundle it).
- `@tailwindcss/typography` is for the `prose` class used in articles.
- `@tailwindcss/forms` resets form elements to be easily styled with Tailwind utilities.

### 2.3 Configure app/assets/stylesheets/application.css

This is the non-Tailwind stylesheet for any custom CSS. Keep it minimal:

```css
/* Application styles — keep most styling in Tailwind utilities */

/* Shake animation for invalid magic link code */
@keyframes shake {
  0%, 100% { transform: translateX(0); }
  25% { transform: translateX(-8px); }
  75% { transform: translateX(8px); }
}
.animate-shake {
  animation: shake 0.3s ease-in-out;
}
```

### 2.4 Verify Procfile.dev has CSS watcher

Already set up in Phase 1:
```
css: bin/rails tailwindcss:watch
```

### 2.5 Verify the build output

Run `bin/rails tailwindcss:build` and check that `app/assets/builds/tailwind.css` is generated.

Add to `.gitignore`:
```
/app/assets/builds/tailwind.css
```

(It's built on deploy and in development via the watcher.)

## Verification

- `bin/rails tailwindcss:build` succeeds
- `app/assets/builds/tailwind.css` is generated with Tailwind utilities
- Dark mode variant classes (e.g., `dark:bg-gray-950`) are present in the output when used
- Typography plugin classes (`prose`, `prose-invert`) are available

## Files Created/Modified

- `app/assets/tailwind/application.css`
- `app/assets/stylesheets/application.css`
- `.gitignore` (add builds exclusion)
