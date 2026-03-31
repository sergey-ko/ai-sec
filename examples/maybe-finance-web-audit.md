# AI-Sec Security Audit: maybe-finance

**Date:** 2026-03-31
**Auditor:** AI-Sec web-app-auditor
**Framework:** OWASP ASVS v4.0.3 L2
**Target:** maybe-finance (Ruby on Rails 7.2, PostgreSQL)
**Commit scope:** Static code analysis of full application codebase

---

## Executive Summary

maybe-finance is a personal finance application built on Ruby on Rails 7.2 that aggregates bank accounts via Plaid, tracks transactions, manages budgets, and provides AI-powered financial chat. The application handles highly sensitive financial data including bank account balances, transaction histories, and Plaid access tokens.

The audit identified **5 Critical**, **6 High**, **7 Medium**, **4 Low**, and **3 Informational** findings. The most severe issues involve unencrypted storage of MFA secrets and Plaid access tokens (conditional encryption), session cookies without `secure` flag, missing Content Security Policy, unauthenticated access to Sidekiq admin panel in non-production environments, and verbose error messages that leak internal application state via the API.

---

## Summary

| Severity | Count |
|----------|-------|
| Critical | 5 |
| High | 6 |
| Medium | 7 |
| Low | 4 |
| Info | 3 |

---

## Findings

### CRITICAL-01: OTP Secret Stored in Plaintext in Database

- **Severity:** Critical
- **CVSS:** 9.1 (AV:N/AC:L/PR:H/UI:N/S:C/C:H/I:H/A:N)
- **ASVS Ref:** V2.8.4, V8.3.4
- **Component:** `app/models/user.rb`, `db/schema.rb` (line 789)

**Evidence:**

The `otp_secret` column in the `users` table is stored as a plaintext `string` with no encryption:

```ruby
# db/schema.rb:789
t.string "otp_secret"
```

The `User` model does not use `encrypts :otp_secret` — there is no Active Record encryption applied to this field. By contrast, `PlaidItem` conditionally encrypts `access_token`, and `ApiKey` encrypts `display_key`. The OTP secret has no such protection.

Additionally, `otp_backup_codes` are stored as a plaintext string array:

```ruby
# db/schema.rb:791
t.string "otp_backup_codes", default: [], array: true
```

**Impact:** An attacker with database read access (SQL injection, backup theft, compromised DB credentials, or cloud misconfiguration) can extract OTP secrets and generate valid TOTP codes, completely bypassing MFA for every user that has it enabled. Backup codes are also exposed.

**Recommendation:**
1. Add `encrypts :otp_secret, deterministic: false` to the `User` model.
2. Encrypt `otp_backup_codes` as well using non-deterministic encryption.
3. Rotate all existing OTP secrets and backup codes after deploying the fix (force users to re-enroll MFA).

---

### CRITICAL-02: Plaid Access Tokens Conditionally Encrypted — Plaintext in Self-Hosted Deployments

- **Severity:** Critical
- **CVSS:** 9.1 (AV:N/AC:L/PR:H/UI:N/S:C/C:H/I:H/A:N)
- **ASVS Ref:** V8.3.4, V6.2.1
- **Component:** `app/models/plaid_item.rb` (lines 7-9)

**Evidence:**

```ruby
# app/models/plaid_item.rb:7-9
if Rails.application.credentials.active_record_encryption.present?
  encrypts :access_token, deterministic: true
end
```

Encryption is conditional — it only activates when `active_record_encryption` credentials are present. For self-hosted instances, the `config/initializers/active_record_encryption.rb` initializer generates encryption keys from `SECRET_KEY_BASE`, but it writes them to `config.active_record.encryption`, NOT to `credentials.active_record_encryption`. This means the `if` check in `PlaidItem` evaluates to `false` for self-hosted instances, and the access token is stored in plaintext.

**Impact:** Plaid access tokens grant full read access to a user's bank accounts, transaction history, and balances. An attacker with database access to a self-hosted instance gets unrestricted access to all connected bank accounts for all users.

**Recommendation:**
1. Change the conditional check to also consider the config-based encryption keys, or remove the conditional entirely and always encrypt.
2. Provide migration tooling to encrypt existing plaintext tokens.

---

### CRITICAL-03: Session Cookie Missing `secure` Flag

- **Severity:** Critical
- **CVSS:** 8.1 (AV:N/AC:H/PR:N/UI:N/S:U/C:H/I:H/A:N)
- **ASVS Ref:** V3.4.1
- **Component:** `app/controllers/concerns/authentication.rb` (line 42)

**Evidence:**

```ruby
# app/controllers/concerns/authentication.rb:42
cookies.signed.permanent[:session_token] = { value: session.id, httponly: true }
```

The session cookie is set with `httponly: true` but WITHOUT `secure: true`. Although production config has `force_ssl = true` (which sets `config.force_ssl`), the cookie itself is not explicitly marked as secure. In deployments behind a reverse proxy with SSL termination (common for self-hosted), `force_ssl` may be disabled via `RAILS_FORCE_SSL=false`, and cookies will be transmitted over plaintext HTTP.

Additionally, the cookie is set as `permanent`, meaning it never expires — there is no session timeout.

**Impact:** Session tokens can be intercepted via network sniffing on non-HTTPS connections (particularly self-hosted deployments). The permanent cookie means a stolen token remains valid indefinitely.

**Recommendation:**
1. Add `secure: Rails.env.production?` (or `secure: true`) to the cookie options.
2. Add `same_site: :lax` or `:strict` to mitigate CSRF attacks via cookie replay.
3. Replace `permanent` with a bounded expiration (e.g., 30 days) and implement session rotation.

---

### CRITICAL-04: No Content Security Policy (CSP)

- **Severity:** Critical
- **CVSS:** 7.5 (AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N)
- **ASVS Ref:** V14.4.3, V14.4.5
- **Component:** `config/initializers/content_security_policy.rb`

**Evidence:**

The entire CSP initializer is commented out:

```ruby
# config/initializers/content_security_policy.rb
# Rails.application.configure do
#   config.content_security_policy do |policy|
#     ...
#   end
# end
```

No Content-Security-Policy header is sent in any response.

**Impact:** The application is fully vulnerable to XSS exploitation. If any XSS vector is found (stored, reflected, or DOM-based), there is no CSP to limit script execution, data exfiltration, or form hijacking. For a financial application handling bank data, this is a severe defense-in-depth gap.

**Recommendation:**
1. Enable and configure CSP with at minimum: `default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; object-src 'none'; frame-ancestors 'none'`.
2. Enable nonce-based script sources for inline scripts.

---

### CRITICAL-05: Sidekiq Web Dashboard Unauthenticated in Non-Production

- **Severity:** Critical
- **CVSS:** 9.0 (AV:N/AC:L/PR:N/UI:N/S:C/C:H/I:H/A:L)
- **ASVS Ref:** V14.2.1, V4.1.1
- **Component:** `config/initializers/sidekiq.rb`, `config/routes.rb` (line 16)

**Evidence:**

```ruby
# config/initializers/sidekiq.rb:3
if Rails.env.production?
  Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
    ...
  end
end
```

```ruby
# config/routes.rb:16
mount Sidekiq::Web => "/sidekiq"
```

Basic auth protection is only applied in production. In development, staging, and self-hosted environments (which may run as `development` or unset environments), `/sidekiq` is fully accessible without any authentication. Sidekiq Web allows viewing all queued jobs (which may contain sensitive parameters), retrying/deleting jobs, and viewing application state.

Furthermore, the default credentials in production are `maybe`/`maybe`:

```ruby
configured_username = ::Digest::SHA256.hexdigest(ENV.fetch("SIDEKIQ_WEB_USERNAME", "maybe"))
configured_password = ::Digest::SHA256.hexdigest(ENV.fetch("SIDEKIQ_WEB_PASSWORD", "maybe"))
```

**Impact:** Complete access to background job queue, ability to view sensitive job arguments (email addresses, user IDs, Plaid sync data), and ability to disrupt application operations by deleting or retrying jobs.

**Recommendation:**
1. Apply authentication in ALL environments, not just production.
2. Remove default credentials and require explicit configuration.
3. Consider routing Sidekiq Web behind application authentication instead of basic auth.

---

### HIGH-01: Lookbook Design System Mounted Without Authentication

- **Severity:** High
- **CVSS:** 5.3 (AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N)
- **ASVS Ref:** V14.2.1
- **Component:** `config/routes.rb` (line 13)

**Evidence:**

```ruby
# config/routes.rb:13
mount Lookbook::Engine, at: "/design-system"
```

Lookbook is mounted at `/design-system` with no authentication gate. It exposes all ViewComponents, their previews, and potentially reveals application structure, partial templates, and internal naming conventions.

**Impact:** Information disclosure of internal application structure. In combination with other vulnerabilities, this gives attackers a detailed map of the application's UI components.

**Recommendation:**
1. Restrict Lookbook to development/test environments only.
2. If needed in production, gate behind admin authentication.

---

### HIGH-02: API Error Messages Leak Internal Application State

- **Severity:** High
- **CVSS:** 5.3 (AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N)
- **ASVS Ref:** V7.4.1, V14.3.3
- **Component:** `app/controllers/api/v1/transactions_controller.rb`, `app/controllers/api/v1/accounts_controller.rb`

**Evidence:**

Multiple API endpoints rescue all exceptions and include the raw exception message in the response:

```ruby
# app/controllers/api/v1/transactions_controller.rb:47-49
rescue => e
  Rails.logger.error "TransactionsController#index error: #{e.message}"
  render json: {
    error: "internal_server_error",
    message: "Error: #{e.message}"  # <-- Raw exception message exposed
  }, status: :internal_server_error
```

This pattern is repeated in `index`, `show`, `create`, `update`, and `destroy` actions across the API controllers.

**Impact:** Internal exception messages can reveal database schema details, gem versions, file paths, SQL fragments, and other information useful for further exploitation.

**Recommendation:**
1. Return generic error messages to the API consumer: `"An internal error occurred"`.
2. Log detailed errors server-side only.
3. Add a unique error ID for correlation between client-visible errors and server logs.

---

### HIGH-03: MFA Disable Does Not Require Re-Authentication

- **Severity:** High
- **CVSS:** 6.5 (AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:N/A:N)
- **ASVS Ref:** V2.8.1
- **Component:** `app/controllers/mfa_controller.rb` (lines 42-45)

**Evidence:**

```ruby
# app/controllers/mfa_controller.rb:42-45
def disable
  Current.user.disable_mfa!
  redirect_to settings_security_path, notice: t(".success")
end
```

Disabling MFA is a single DELETE request with no re-authentication (no password confirmation, no current OTP code verification). If an attacker has an active session (e.g., via session fixation, XSS-stolen cookie, or unattended workstation), they can silently disable MFA.

**Impact:** An attacker with session access can disable MFA, then maintain persistent access even if the user later changes their password, because the session token remains valid.

**Recommendation:**
1. Require current password and/or current OTP code before allowing MFA disable.
2. Invalidate all other sessions after MFA state changes.

---

### HIGH-04: Password Change Does Not Invalidate Existing Sessions

- **Severity:** High
- **CVSS:** 6.5 (AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:N/A:N)
- **ASVS Ref:** V3.3.3, V2.1.6
- **Component:** `app/controllers/passwords_controller.rb`

**Evidence:**

```ruby
# app/controllers/passwords_controller.rb:5-8
def update
  if Current.user.update(password_params)
    redirect_to root_path, notice: t(".success")
  end
end
```

After a password change, the user is redirected to root. No sessions are invalidated. An attacker who previously compromised a session retains access even after the victim changes their password.

Similarly, `password_resets_controller.rb` does not invalidate sessions after password reset.

**Impact:** Credential change does not revoke compromised sessions, violating the principle that password change should terminate all other sessions.

**Recommendation:**
1. After password change or reset, destroy all sessions except the current one.
2. `Current.user.sessions.where.not(id: Current.session.id).destroy_all`

---

### HIGH-05: Permanent Session Cookie With No Expiry or Rotation

- **Severity:** High
- **CVSS:** 6.5 (AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:N/A:N)
- **ASVS Ref:** V3.3.1, V3.3.2, V3.7.1
- **Component:** `app/controllers/concerns/authentication.rb` (line 42)

**Evidence:**

```ruby
cookies.signed.permanent[:session_token] = { value: session.id, httponly: true }
```

- `permanent` sets the cookie to expire 20 years from now.
- There is no server-side session expiry (no `expires_at` column on `sessions` table, no periodic cleanup).
- There is no session rotation after login (same session ID persists).
- There is no idle timeout.

**Impact:** A stolen session token remains valid indefinitely. There is no mechanism to detect or limit session replay attacks.

**Recommendation:**
1. Set a reasonable cookie expiry (e.g., 30 days).
2. Add `expires_at` column to sessions and enforce server-side.
3. Implement idle timeout (e.g., 30 minutes of inactivity).
4. Rotate session ID on privilege changes (login, password change, MFA toggle).

---

### HIGH-06: Impersonation Session `complete` Action Missing Authorization Check

- **Severity:** High
- **CVSS:** 6.5 (AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:N/A:N)
- **ASVS Ref:** V4.1.2
- **Component:** `app/controllers/impersonation_sessions_controller.rb` (lines 35-38)

**Evidence:**

```ruby
# Lines 35-38
def complete
  @impersonation_session.complete!
  redirect_to root_path, notice: t(".success")
end
```

The `complete` action does NOT check `require_super_admin!` (only `create`, `join`, `leave` do). It also does not verify that the caller is the impersonator or the impersonated user. The `set_impersonation_session` finds sessions belonging to either role of the `true_user`, but any authenticated user who is either the impersonator or impersonated can complete the session. This is potentially exploitable if a non-super-admin user who was being impersonated can prematurely end or manipulate the impersonation flow.

**Impact:** Authorization bypass in the impersonation workflow. Users may be able to complete impersonation sessions they should not control.

**Recommendation:**
1. Add `require_super_admin!` to the `complete` action, or explicitly check that the caller is the impersonator.

---

### MEDIUM-01: No Rate Limiting on Login Endpoint

- **Severity:** Medium
- **CVSS:** 5.3 (AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N)
- **ASVS Ref:** V2.2.1
- **Component:** `app/controllers/sessions_controller.rb`, `config/initializers/rack_attack.rb`

**Evidence:**

Rack::Attack is configured but only throttles:
1. `/oauth/token` endpoint (10/min)
2. `/api/*` endpoints

There is NO throttle rule for the web login endpoint (`POST /sessions`). The `SessionsController#create` has no account lockout mechanism either.

The API login (`POST /api/v1/auth/login`) is covered by the general API rate limit (100/hour in production), but this is generous for a login endpoint.

**Impact:** Brute-force attacks against user passwords via the web login form are not rate-limited. An attacker can attempt thousands of passwords per minute.

**Recommendation:**
1. Add Rack::Attack throttle for `POST /sessions` (e.g., 5 attempts per minute per IP, 10 per hour per email).
2. Implement progressive delay or account lockout after N failed attempts.

---

### MEDIUM-02: No `SameSite` Attribute on Session Cookie

- **Severity:** Medium
- **CVSS:** 4.3 (AV:N/AC:L/PR:N/UI:R/S:U/C:N/I:L/A:N)
- **ASVS Ref:** V3.4.3
- **Component:** `app/controllers/concerns/authentication.rb` (line 42)

**Evidence:**

```ruby
cookies.signed.permanent[:session_token] = { value: session.id, httponly: true }
```

No `same_site` option is set. Modern browsers default to `Lax`, but this should be explicitly set for security-critical applications.

**Impact:** Without explicit `SameSite`, the cookie behavior depends on browser defaults. Older browsers may send the cookie on cross-site requests, enabling CSRF attacks that bypass the CSRF token requirement.

**Recommendation:**
1. Add `same_site: :lax` (or `:strict` if cross-origin navigation is not needed).

---

### MEDIUM-03: Permissions Policy Not Configured

- **Severity:** Medium
- **CVSS:** 3.1 (AV:N/AC:H/PR:N/UI:R/S:U/C:L/I:N/A:N)
- **ASVS Ref:** V14.4.6
- **Component:** `config/initializers/permissions_policy.rb`

**Evidence:**

The entire permissions policy initializer is commented out:

```ruby
# Rails.application.config.permissions_policy do |policy|
#   policy.camera      :none
#   ...
# end
```

**Impact:** The application does not restrict which browser features can be used, leaving it open to feature abuse in XSS scenarios (camera, microphone, geolocation, payment API).

**Recommendation:**
1. Enable and configure the permissions policy to restrict unnecessary browser features.

---

### MEDIUM-04: User Params Allow Mass Assignment of Sensitive Attributes

- **Severity:** Medium
- **CVSS:** 5.4 (AV:N/AC:L/PR:L/UI:N/S:U/C:N/I:H/A:N)
- **ASVS Ref:** V5.1.2
- **Component:** `app/controllers/users_controller.rb` (lines 89-94)

**Evidence:**

```ruby
def user_params
  params.require(:user).permit(
    :first_name, :last_name, :email, :profile_image, :redirect_to, :delete_profile_image, :onboarded_at,
    :show_sidebar, :default_period, :show_ai_sidebar, :ai_enabled, :theme, :set_onboarding_preferences_at, :set_onboarding_goals_at,
    family_attributes: [ :name, :currency, :country, :locale, :date_format, :timezone, :id ],
    goals: []
  )
end
```

The `onboarded_at`, `set_onboarding_preferences_at`, and `set_onboarding_goals_at` timestamps are user-controllable. More critically, `family_attributes` includes `:id`, which could potentially allow a user to associate themselves with a different family by providing a different family ID (though `accepts_nested_attributes_for :family, update_only: true` mitigates full exploitation, the inclusion of `:id` is still risky).

**Impact:** Users can manipulate onboarding timestamps to bypass onboarding flows. The family `:id` in nested attributes is a defense-in-depth violation even if `update_only: true` prevents cross-family association.

**Recommendation:**
1. Remove `:onboarded_at`, `:set_onboarding_preferences_at`, `:set_onboarding_goals_at` from permitted params (set these server-side).
2. Remove `:id` from `family_attributes` — `update_only: true` already targets the associated record.

---

### MEDIUM-05: Invitation Role Controllable by Inviter

- **Severity:** Medium
- **CVSS:** 4.3 (AV:N/AC:L/PR:L/UI:N/S:U/C:N/I:L/A:N)
- **ASVS Ref:** V4.2.1
- **Component:** `app/controllers/invitations_controller.rb` (line 57)

**Evidence:**

```ruby
def invitation_params
  params.require(:invitation).permit(:email, :role)
end
```

An admin user creates invitations and can set `:role`. However, the permitted roles are not validated against an allowlist in the controller. While the `User` model has `enum :role, { member: "member", admin: "admin", super_admin: "super_admin" }`, if an admin sends a role of `super_admin`, this could escalate privilege beyond what the admin intended.

**Impact:** Admin users could potentially create invitations with `super_admin` role, escalating privileges beyond their own level.

**Recommendation:**
1. Validate that the invited role does not exceed the inviter's own role.
2. Restrict invitation roles to `member` and `admin` only; `super_admin` should be set through a different mechanism.

---

### MEDIUM-06: OAuth Access Token Expiry Set to 1 Year

- **Severity:** Medium
- **CVSS:** 4.0 (AV:N/AC:H/PR:L/UI:N/S:U/C:H/I:N/A:N)
- **ASVS Ref:** V3.3.1
- **Component:** `config/initializers/doorkeeper.rb` (line 111)

**Evidence:**

```ruby
access_token_expires_in 1.year
```

OAuth access tokens are valid for 1 year. The mobile API creates tokens with 30-day expiry, but the Doorkeeper default covers all other OAuth flows.

**Impact:** Long-lived access tokens increase the window of exploitation if a token is compromised. For a financial application, this is excessive.

**Recommendation:**
1. Reduce default token expiry to 1 hour or less.
2. Rely on refresh tokens for re-authentication.

---

### MEDIUM-07: API Search Vulnerable to SQL Wildcard Injection

- **Severity:** Medium
- **CVSS:** 3.7 (AV:N/AC:H/PR:L/UI:N/S:U/C:N/I:N/A:L)
- **ASVS Ref:** V5.3.4
- **Component:** `app/controllers/api/v1/transactions_controller.rb` (lines 243-250)

**Evidence:**

```ruby
def apply_search(query)
  search_term = "%#{params[:search]}%"
  query.joins(:entry)
       .left_joins(:merchant)
       .where(
         "entries.name ILIKE ? OR entries.notes ILIKE ? OR merchants.name ILIKE ?",
         search_term, search_term, search_term
       )
end
```

The search term is wrapped with `%` for LIKE matching, but user input containing `%` or `_` SQL wildcard characters is not sanitized. This is technically SQL injection-safe due to parameterized queries, but `%` and `_` in user input can cause unexpected matching behavior and potential denial of service with crafted patterns.

**Impact:** Users can craft search terms with wildcard characters to cause excessive database scanning or retrieve unintended results.

**Recommendation:**
1. Sanitize wildcards: `ActiveRecord::Base.sanitize_sql_like(params[:search])`.

---

### LOW-01: API Key Source Validation Too Permissive

- **Severity:** Low
- **CVSS:** 2.0 (AV:N/AC:H/PR:H/UI:N/S:U/C:L/I:N/A:N)
- **ASVS Ref:** V13.1.1
- **Component:** `app/controllers/settings/api_keys_controller.rb` (line 55)

**Evidence:**

```ruby
def api_key_params
  permitted_params = params.require(:api_key).permit(:name, :scopes)
  ...
end
```

The `source` field is not set from params in the web controller, but it also is not explicitly set to `"web"` — it defaults to whatever is in the model. If the `source` field has no default, this could lead to validation errors or unexpected behavior.

**Impact:** Minor — the `source` field has validation but the controller does not explicitly set it.

**Recommendation:**
1. Explicitly set `source: "web"` when building API keys from the web controller.

---

### LOW-02: Webhook Error Messages Expose Internal Details

- **Severity:** Low
- **CVSS:** 3.1 (AV:N/AC:H/PR:N/UI:R/S:U/C:L/I:N/A:N)
- **ASVS Ref:** V7.4.1
- **Component:** `app/controllers/webhooks_controller.rb` (line 18)

**Evidence:**

```ruby
rescue => error
  Sentry.capture_exception(error)
  render json: { error: "Invalid webhook: #{error.message}" }, status: :bad_request
end
```

The Plaid webhook error handler includes the raw exception message in the response. While the webhook endpoint is unauthenticated, returning internal error details could aid an attacker probing the endpoint.

**Impact:** Information leakage via webhook error responses.

**Recommendation:**
1. Return a generic error message: `{ error: "Invalid webhook" }`.

---

### LOW-03: No Host Authorization Configured in Production

- **Severity:** Low
- **CVSS:** 3.1 (AV:N/AC:H/PR:N/UI:R/S:U/C:N/I:L/A:N)
- **ASVS Ref:** V14.5.3
- **Component:** `config/environments/production.rb` (lines 102-108)

**Evidence:**

```ruby
# config.hosts = [
#   "example.com",
# ]
# config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
```

Host authorization is commented out. Without this, the application accepts requests with any `Host` header, enabling DNS rebinding attacks or cache poisoning.

**Impact:** DNS rebinding attacks could allow an attacker on a local network to interact with the application as a trusted origin.

**Recommendation:**
1. Configure `config.hosts` with the expected production domain(s).

---

### LOW-04: Development Mode Allows All Hosts

- **Severity:** Low
- **CVSS:** 2.0 (AV:L/AC:H/PR:N/UI:N/S:U/C:L/I:N/A:N)
- **ASVS Ref:** V14.5.3
- **Component:** `config/environments/development.rb` (line 87)

**Evidence:**

```ruby
config.hosts = nil
```

All hosts are allowed in development. This is expected for development but worth noting for self-hosted deployments that may run in development mode.

**Impact:** If self-hosted instances run in development mode (which some do for simplicity), any host header is accepted.

**Recommendation:**
1. Document that self-hosted instances must run in production mode.

---

### INFO-01: Doorkeeper OAuth Force SSL Disabled for Redirect URIs

- **Severity:** Info
- **CVSS:** N/A
- **ASVS Ref:** V14.4.1
- **Component:** `config/initializers/doorkeeper.rb` (line 307)

**Evidence:**

```ruby
force_ssl_in_redirect_uri false
```

This is intentionally disabled to support mobile apps with custom URL schemes (e.g., `myapp://callback`). This is documented and acceptable for mobile OAuth flows, but means that HTTP redirect URIs are also accepted.

---

### INFO-02: Active Record Encryption Keys Derived from SECRET_KEY_BASE

- **Severity:** Info
- **CVSS:** N/A
- **ASVS Ref:** V6.2.2
- **Component:** `config/initializers/active_record_encryption.rb`

**Evidence:**

For self-hosted instances, all encryption keys are derived deterministically from `SECRET_KEY_BASE` using SHA-256. This means compromising `SECRET_KEY_BASE` compromises all encryption. While this is a reasonable convenience for self-hosted users, it concentrates key material.

**Recommendation:**
1. Document this risk for self-hosted deployers.
2. Encourage production deployments to provide independent encryption keys.

---

### INFO-03: `faker` Gem in Development Group

- **Severity:** Info
- **CVSS:** N/A
- **ASVS Ref:** V14.2.1
- **Component:** `Gemfile` (line 102)

`faker` is properly scoped to the `development` group and will not be available in production. No action needed.

---

## ASVS Compliance Matrix

### V2 — Authentication

| Req | Description | Status | Evidence |
|-----|-------------|--------|----------|
| V2.1.1 | Password minimum 8 chars | PASS | `RegistrationsController` enforces 8+ chars, upper+lower, digit, special char |
| V2.1.2 | Password max 64+ chars | N/A | No explicit max enforced (Rails default allows long passwords) |
| V2.1.6 | Password change requires current password | PARTIAL | `PasswordsController` permits `password_challenge` but with empty default — weak enforcement |
| V2.1.7 | Password length enforcement | PASS | 8 char minimum with complexity requirements |
| V2.2.1 | Anti-automation on login | FAIL | No rate limiting on `POST /sessions` (MEDIUM-01) |
| V2.4.1 | Password hashed with bcrypt | PASS | `has_secure_password` uses bcrypt |
| V2.5.1 | Password reset time-limited token | PASS | `generates_token_for :password_reset, expires_in: 15.minutes` |
| V2.5.3 | Password reset does not reveal account existence | PASS | Always redirects to "pending" step regardless of email existence |
| V2.8.1 | MFA implementation | PASS | TOTP via `rotp` gem with backup codes |
| V2.8.4 | MFA secrets encrypted | FAIL | `otp_secret` stored plaintext (CRITICAL-01) |
| V2.8.6 | MFA disable requires re-auth | FAIL | No re-auth for MFA disable (HIGH-03) |

### V3 — Session Management

| Req | Description | Status | Evidence |
|-----|-------------|--------|----------|
| V3.2.1 | Session ID generated server-side | PASS | UUID primary key on sessions table |
| V3.3.1 | Session expiry | FAIL | Permanent cookie, no server-side expiry (HIGH-05) |
| V3.3.2 | Idle timeout | FAIL | No idle timeout mechanism |
| V3.3.3 | Sessions invalidated on password change | FAIL | No session invalidation (HIGH-04) |
| V3.4.1 | Cookie secure flag | FAIL | Missing `secure` flag (CRITICAL-03) |
| V3.4.2 | Cookie httponly flag | PASS | `httponly: true` set |
| V3.4.3 | Cookie SameSite | PARTIAL | Not explicitly set (MEDIUM-02) |
| V3.7.1 | Session ID rotated on auth changes | FAIL | No rotation on login, password change, or MFA toggle |

### V4 — Access Control

| Req | Description | Status | Evidence |
|-----|-------------|--------|----------|
| V4.1.1 | All resources have access control | PARTIAL | Sidekiq/Lookbook accessible without auth (CRITICAL-05, HIGH-01) |
| V4.1.2 | IDOR prevention | PASS | All controllers scope queries through `Current.family` — e.g., `family.accounts.find(params[:id])`, `Current.family.categories.find(params[:id])`, `Current.user.chats.find(params[:id])`. This consistently prevents cross-family data access. |
| V4.1.3 | Principle of least privilege | PASS | Role-based access: member/admin/super_admin with appropriate checks |
| V4.2.1 | CSRF protection | PASS | Rails default CSRF via `verify_authenticity_token`, properly disabled for API/webhooks |
| V4.2.2 | Authorization on API endpoints | PASS | `authorize_scope!` checks and family-scoped queries |

### V5 — Input Validation

| Req | Description | Status | Evidence |
|-----|-------------|--------|----------|
| V5.1.1 | Input validation on all parameters | PASS | Strong Parameters used consistently |
| V5.1.2 | Mass assignment protection | PARTIAL | Most controllers are good, but `UsersController` permits sensitive timestamps (MEDIUM-04) |
| V5.3.1 | SQL injection protection | PASS | Parameterized queries throughout; ActiveRecord ORM used |
| V5.3.3 | XSS prevention | PASS | ERB auto-escaping by default in Rails |
| V5.3.4 | SQL wildcard sanitization | FAIL | API search does not sanitize LIKE wildcards (MEDIUM-07) |
| V5.5.1 | File upload validation | PASS | Profile images restricted to JPEG/PNG, 10MB limit |

### V7 — Error Handling and Logging

| Req | Description | Status | Evidence |
|-----|-------------|--------|----------|
| V7.1.1 | Generic error messages | FAIL | API returns raw exception messages (HIGH-02) |
| V7.1.2 | No stack traces in responses | PASS | Production config disables full error reports |
| V7.1.3 | Sensitive data filtered from logs | PASS | `filter_parameters` includes passwords, emails, tokens, secrets, OTP, SSN |
| V7.4.1 | Error responses don't leak info | FAIL | Webhooks and API expose error.message (HIGH-02, LOW-02) |

### V8 — Data Protection

| Req | Description | Status | Evidence |
|-----|-------------|--------|----------|
| V8.1.1 | Sensitive data identified | PASS | Financial data, bank tokens, OTP secrets clearly sensitive |
| V8.2.1 | Sensitive data encrypted at rest | FAIL | OTP secrets plaintext, Plaid tokens conditionally encrypted (CRITICAL-01, CRITICAL-02) |
| V8.3.1 | Sensitive data in URL parameters | PASS | No sensitive data in URLs observed |
| V8.3.4 | Encryption of PII at rest | PARTIAL | API keys encrypted; OTP and Plaid tokens inconsistent |

### V13 — API Security

| Req | Description | Status | Evidence |
|-----|-------------|--------|----------|
| V13.1.1 | API authentication | PASS | OAuth2 + API key dual auth |
| V13.1.2 | API rate limiting | PASS | Rack::Attack + custom API key rate limiter |
| V13.1.3 | API input validation | PASS | Strong parameters and scope authorization |
| V13.2.1 | API error handling | FAIL | Raw exception messages returned (HIGH-02) |
| V13.4.1 | API versioning | PASS | `/api/v1/` namespace |

### V14 — Configuration

| Req | Description | Status | Evidence |
|-----|-------------|--------|----------|
| V14.1.1 | Build environment isolated | PASS | Standard Rails environment separation |
| V14.2.1 | No unnecessary features | FAIL | Lookbook and Sidekiq Web exposed (CRITICAL-05, HIGH-01) |
| V14.3.3 | Security headers | FAIL | No CSP (CRITICAL-04), no Permissions-Policy (MEDIUM-03) |
| V14.4.1 | HTTPS enforcement | PASS | `force_ssl` enabled in production config |
| V14.5.3 | Host header validation | FAIL | Not configured (LOW-03) |

---

## Positive Security Observations

The application demonstrates several strong security practices that are worth highlighting:

1. **Consistent IDOR Prevention:** Every controller scopes database queries through `Current.family` or `Current.user`, making cross-tenant data access extremely difficult. This is the single most important security control for a multi-tenant finance app, and it is implemented correctly.

2. **Strong Password Policy:** The application enforces 8+ characters, uppercase, lowercase, digit, and special character requirements at registration and via the API.

3. **Proper CSRF Protection:** Rails default CSRF token verification is active for all web endpoints, correctly disabled only for API and webhook endpoints that use their own authentication.

4. **Hashed OAuth Tokens:** Doorkeeper is configured with `hash_token_secrets` and `hash_application_secrets`, preventing token theft from the database.

5. **PKCE Enforcement:** `force_pkce` is enabled in Doorkeeper configuration, protecting against authorization code interception attacks.

6. **Webhook Signature Verification:** Both Plaid and Stripe webhooks validate cryptographic signatures before processing.

7. **Password Reset Token Security:** Uses Rails `generates_token_for` with 15-minute expiry and ties the token to the password salt, auto-invalidating on password change.

8. **Parameter Filtering:** Comprehensive log filtering of passwords, emails, tokens, secrets, OTP codes, and SSNs.

9. **API Rate Limiting:** Dual-layer rate limiting via Rack::Attack and custom per-key rate limiter with proper headers.

10. **UUIDs for Primary Keys:** All models use UUIDs instead of sequential integers, eliminating enumeration attacks.

---

## Remediation Priority

| Priority | Finding | Effort |
|----------|---------|--------|
| 1 | CRITICAL-01: Encrypt OTP secrets | Low (add `encrypts` + migration) |
| 2 | CRITICAL-02: Fix Plaid token encryption conditional | Low (fix conditional check) |
| 3 | CRITICAL-03: Add `secure`, `same_site` to session cookie | Low (one line change) |
| 4 | CRITICAL-05: Authenticate Sidekiq in all environments | Low (move auth out of `if production?`) |
| 5 | HIGH-04: Invalidate sessions on password change | Low (add one line after password update) |
| 6 | HIGH-03: Require re-auth for MFA disable | Medium (add confirmation step) |
| 7 | HIGH-05: Add session expiry and rotation | Medium (schema change + logic) |
| 8 | CRITICAL-04: Enable Content Security Policy | Medium (requires testing with all inline scripts) |
| 9 | HIGH-02: Sanitize API error messages | Low (change rescue blocks) |
| 10 | MEDIUM-01: Rate limit login endpoint | Low (add Rack::Attack rule) |
| 11 | HIGH-01: Restrict Lookbook to dev only | Low (conditional mount) |
| 12 | HIGH-06: Fix impersonation complete auth | Low (add before_action) |
| 13 | MEDIUM-04: Remove sensitive attrs from user_params | Low |
| 14 | MEDIUM-05: Validate invitation role bounds | Low |
| 15 | MEDIUM-06: Reduce OAuth token expiry | Low |
| 16 | MEDIUM-07: Sanitize SQL wildcards | Low |
| 17 | LOW-01 through LOW-04 | Low |

---

*Report generated by AI-Sec web-app-auditor. For questions about this audit, contact the AI-Sec team.*
