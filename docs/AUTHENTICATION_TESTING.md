# Authentication Testing Guide

## Quick Start

1. **Start the Rails server:**
   ```bash
   bin/rails server
   ```

2. **Visit the login page:**
   ```
   http://localhost:3000/session/new
   ```

3. **Enter your email address and click Continue**

4. **Check your email** (in development, it opens in your browser via letter_opener)

5. **Copy the 6-digit code** from the email

6. **Enter the code** on the code entry page

7. **You're logged in!** You'll be redirected to the root path

## Testing Scenarios

### Scenario 1: New User Sign-Up
- Visit `/session/new`
- Enter a new email (e.g., `newuser@example.com`)
- Magic link is sent
- Enter code
- User is created and logged in
- Default team is created automatically

### Scenario 2: Existing User Sign-In
- Visit `/session/new`
- Enter an existing email
- Magic link is sent
- Enter code
- User is logged in

### Scenario 3: Invalid Code
- Visit `/session/new`
- Enter email and get code
- Enter wrong code
- Page shakes, stays on code entry
- Try again with correct code

### Scenario 4: Expired Code
- Visit `/session/new`
- Enter email
- Wait 16 minutes
- Enter code
- Code is invalid (expired)

### Scenario 5: Protected Page Redirect
- Visit a protected page (any page except `/session/new`, `/`, `/ui_test`)
- Not logged in → redirected to `/session/new`
- Email param is NOT passed (no email in original URL)
- After login → redirected back to original page

### Scenario 6: Email Pre-fill
- Visit `/session/new?email=test@example.com`
- Email field is pre-filled
- Continue to get magic link

### Scenario 7: Code Entry Features
- **Paste support**: Copy "ABC123" and paste into code field → auto-submits
- **Auto-uppercase**: Type "abc123" → converts to "ABC123"
- **Strip special chars**: Type "abc-123" → becomes "ABC123"
- **Development autofill**: In dev mode, yellow button auto-fills and submits code

### Scenario 8: Sign Out
- While logged in, visit `/session` with DELETE method (or use a sign-out link)
- Session is destroyed
- Cookie is deleted
- Redirected to root with "You have been signed out" message

### Scenario 9: Deactivated User
- In Rails console: `User.first.deactivate!`
- Try to log in with that email
- Redirected back to login with "This account has been deactivated." message

### Scenario 10: Rate Limiting
- Try to submit login form 11+ times in 3 minutes
- Get "Too many requests" error
- Try to submit code 11+ times in 15 minutes
- Get "Too many attempts" error

## Development Helpers

### View Magic Link Code
In development mode, the code is displayed in two places:
1. **Yellow autofill button** on the code entry page
2. **Console output** (check Rails server logs)
3. **HTTP header** `X-Magic-Link-Code` (check browser dev tools)

### Manual Code Generation in Console
```ruby
user = User.find_by(email: 'test@example.com')
ml = user.send_magic_link
puts "Code: #{ml.code}"
```

### Check Active Sessions
```ruby
Session.all.each do |s|
  puts "Session #{s.id}: #{s.user.email} from #{s.ip_address}"
end
```

### Clear Expired Magic Links
```ruby
MagicLink.cleanup
```

### Test Code Sanitization
```ruby
MagicLink::Code.sanitize("abc-OIL-123")
# => "ABC01123" (O→0, I→1, L→1, dashes removed)
```

## Email Preview

In development, all emails are opened automatically in your browser via letter_opener.

The email will show:
- "Your sign-in code" heading
- 6-digit code in large monospace font
- "This code expires in 15 minutes" notice

## Troubleshooting

### "Enter your email address to sign in" error
- You don't have a pending authentication token
- This happens if you visit `/session/magic_link` directly
- Go back to `/session/new` and start over

### Code doesn't work
- Check that code hasn't expired (15 minutes)
- Make sure you're entering the most recent code
- Check for typos (codes are case-insensitive and ignore dashes)

### Not receiving emails
- In development, check browser for letter_opener window
- Check Rails logs for email delivery
- Verify `config.action_mailer.delivery_method = :letter_opener` in development.rb

### Rate limited
- Wait 3-15 minutes (depending on which endpoint)
- Or restart Rails server to reset rate limit counters

### Session not persisting
- Check that cookies are enabled in browser
- Verify Rails secret key base is set
- Check browser console for cookie errors

## Console Commands

### Create a test user
```ruby
User.create!(email: 'test@example.com', name: 'Test User')
```

### Force sign in (skip magic link)
```ruby
user = User.find_by(email: 'test@example.com')
session = user.sessions.create!(ip_address: '127.0.0.1', user_agent: 'Test')
puts "Session ID: #{session.id}"
# Use this session ID in a signed cookie
```

### Check user's teams
```ruby
user = User.find_by(email: 'test@example.com')
user.teams.each { |t| puts t.name }
```

### Reactivate a deactivated user
```ruby
User.find_by(email: 'test@example.com').reactivate!
```
