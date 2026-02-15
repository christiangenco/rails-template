# Phase 7: Profile & Email Change - COMPLETE ✓

## Implementation Summary

Phase 7 has been fully implemented with all features for user profile management and secure email change flow.

## Files Created

### Controllers (3 files)
- ✓ `app/controllers/profiles_controller.rb` - Profile show/update
- ✓ `app/controllers/users/email_addresses_controller.rb` - Email change request
- ✓ `app/controllers/users/email_addresses/confirmations_controller.rb` - Email change confirmation

### Models & Concerns (1 file)
- ✓ `app/models/concerns/user/email_address_changeable.rb` - Email change logic with SignedGlobalID tokens

### Mailers (1 file)
- ✓ `app/mailers/user_mailer.rb` - Email change confirmation & notification mailers

### Views (8 files)
- ✓ `app/views/profiles/show.html.erb` - Profile page with name edit
- ✓ `app/views/users/email_addresses/new.html.erb` - Email change form
- ✓ `app/views/users/email_addresses/create.html.erb` - "Check your email" confirmation
- ✓ `app/views/users/email_addresses/confirmations/show.html.erb` - Final email change confirmation
- ✓ `app/views/user_mailer/email_change_confirmation.html.erb` - HTML email for confirmation
- ✓ `app/views/user_mailer/email_change_confirmation.text.erb` - Text email for confirmation
- ✓ `app/views/user_mailer/email_changed_notification.html.erb` - HTML notification to old email
- ✓ `app/views/user_mailer/email_changed_notification.text.erb` - Text notification to old email

### Test Previews (1 file)
- ✓ `test/mailers/previews/user_mailer_preview.rb` - Mailer preview for testing

## Files Modified

### Models
- ✓ `app/models/user.rb` - Added `include User::EmailAddressChangeable`

### Routes
- ✓ `config/routes.rb` - Added profile and email change routes

## Routes Added

```
GET    /profile                                          profiles#show
PATCH  /profile                                          profiles#update
GET    /users/email_addresses/new                        users/email_addresses#new
POST   /users/email_addresses                            users/email_addresses#create
GET    /users/email_addresses/:token/confirmation        users/email_addresses/confirmations#show
POST   /users/email_addresses/:token/confirmation        users/email_addresses/confirmations#create
```

## Features Implemented

### Profile Management
- ✅ View and edit user name
- ✅ Display current email (read-only)
- ✅ Link to change email address
- ✅ Form validation and error handling

### Email Change Flow
1. ✅ User enters new email address
2. ✅ Validation:
   - Valid email format
   - Not the same as current email
   - Not already taken by another user
3. ✅ Sends confirmation email to NEW address
4. ✅ User clicks link in email (30-minute expiration)
5. ✅ Shows final confirmation page
6. ✅ User confirms the change
7. ✅ Email is updated
8. ✅ Notification sent to OLD email address

### Security Features
- ✅ SignedGlobalID tokens with 30-minute expiration
- ✅ Token includes old and new email for verification
- ✅ Verification that user's email hasn't changed since token was generated
- ✅ Prevents reuse of tokens after email change
- ✅ Notification sent to old email address for security awareness

### Email Templates
- ✅ Both HTML and text versions for all emails
- ✅ Professional styling with inline CSS
- ✅ Clear call-to-action buttons
- ✅ Security warnings and instructions
- ✅ Accessible and mobile-friendly

## Verification Results

All verification checks passed:

```
✓ User model includes EmailAddressChangeable concern
✓ Can generate email change token
✓ Can verify email change token
✓ Expired tokens are rejected
✓ email_change_confirmation mailer works (HTML + text)
✓ email_changed_notification mailer works (HTML + text)
✓ ProfilesController exists
✓ Users::EmailAddressesController exists
✓ Users::EmailAddresses::ConfirmationsController exists
✓ All routes configured correctly
✓ All views created
```

## How to Test

### 1. Profile Page
```bash
# Visit the profile page (requires authentication)
open http://localhost:3000/profile
```

### 2. Email Change Flow
```bash
# Click "Change email" on profile page
# Enter new email address
# Check email inbox for confirmation link
# Click confirmation link
# Confirm the change
# Check old email for notification
```

### 3. Mailer Previews
```bash
# View email templates in browser
open http://localhost:3000/rails/mailers/user_mailer/email_change_confirmation
open http://localhost:3000/rails/mailers/user_mailer/email_changed_notification
```

### 4. Rails Console Testing
```ruby
# In rails console (bin/rails console)
user = User.first

# Generate token
token = user.generate_email_change_token(to: "new@example.com")

# Verify token
result = User.verify_email_change_token(token)
# => {user: #<User>, old_email: "...", new_email: "new@example.com"}

# Send confirmation email
user.send_email_change_confirmation("new@example.com")

# Change email
user.change_email_address!("new@example.com")
```

## Token Security

The implementation uses Rails' `SignedGlobalID` which provides:

- **Cryptographic signing** - Prevents tampering
- **Expiration** - Tokens expire after 30 minutes
- **Purpose scoping** - Token only valid for email change
- **Parameter embedding** - Old and new email embedded in token
- **Verification** - Ensures user's email hasn't changed since token creation

Token format:
```ruby
user.to_sgid(
  for: "change_email_address",
  expires_in: 30.minutes,
  old_email: "current@example.com",
  new_email: "new@example.com"
).to_s
```

## Edge Cases Handled

1. ✅ Token expired (30 minutes)
2. ✅ Token used after email already changed
3. ✅ New email same as current email
4. ✅ New email already taken by another user
5. ✅ Invalid email format
6. ✅ User's current email changed after token generation
7. ✅ Token verification for wrong user

## Next Steps

Phase 7 is complete. Ready to proceed to:
- **Phase 8**: Active Storage & Action Text (file uploads, rich text editor)

## Notes

- Email change requires user to be authenticated
- Confirmation link sent to NEW email (not current email)
- Notification sent to OLD email for security
- Uses `deliver_later` for background email delivery (requires job queue)
- Token embedded in URL is the SignedGlobalID, not a separate database record
- No database changes needed - uses existing `users.email` column
