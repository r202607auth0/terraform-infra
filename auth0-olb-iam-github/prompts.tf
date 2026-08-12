##############################################################################
# prompts.tf – Custom Prompts & Universal Login
# UC-01: Custom signup prompt to capture account number (CIF)
# UC-03: Legacy user email collection prompt
# Accessibility: WCAG 2.1AA | Bilingual: English + French Canadian
##############################################################################

# ── Universal Login Branding ────────────────────────────────────────────────
resource "auth0_branding" "olb" {
  logo_url    = "https://assets.olb.example.com/logo.png"
  favicon_url = "https://assets.olb.example.com/favicon.ico"

  colors {
    primary         = "#0A3D62"
    page_background = "#FFFFFF"
  }

  font {
    url = "https://fonts.googleapis.com/css2?family=Inter:wght@400;600&display=swap"
  }
}

# ── Custom Universal Login Page ─────────────────────────────────────────────
resource "auth0_branding_universal_login" "olb_pages" {
  body = <<-HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <!-- WCAG 2.1AA meta (UC-01 Acceptance Criteria) -->
      <title>Online Banking – Sign In</title>
      <%- auth0.form.style.inline() %>
    </head>
    <body>
      <main id="main" role="main" aria-label="Authentication">
        <%- auth0.form.html %>
      </main>
      <%- auth0.form.script %>
    </body>
    </html>
  HTML
}

# ── Custom Signup Prompt – CIF Capture (UC-01) ─────────────────────────────
resource "auth0_prompt_custom_text" "signup_en" {
  prompt   = "signup"
  language = "en"
  body     = jsonencode({
    "signup" = {
      "pageTitle"           = "Create Your Online Banking Account"
      "title"               = "Register for Online Banking"
      "description"         = "Enter your account number to get started."
      "submitButtonText"    = "Continue"
      "emailPlaceholder"    = "Email Address"
      "passwordPlaceholder" = "Create Password (min. 12 characters)"
    }
  })
}

resource "auth0_prompt_custom_text" "signup_fr" {
  prompt   = "signup"
  language = "fr-CA"
  body     = jsonencode({
    "signup" = {
      "pageTitle"           = "Créer votre compte de banque en ligne"
      "title"               = "Inscription aux services bancaires en ligne"
      "description"         = "Entrez votre numéro de compte pour commencer."
      "submitButtonText"    = "Continuer"
      "emailPlaceholder"    = "Adresse courriel"
      "passwordPlaceholder" = "Créer un mot de passe (min. 12 caractères)"
    }
  })
}

# ── Login prompt – bilingual (UC-02, UC-03) ────────────────────────────────
resource "auth0_prompt_custom_text" "login_en" {
  prompt   = "login"
  language = "en"
  body     = jsonencode({
    "login" = {
      "pageTitle"        = "Sign In – Online Banking"
      "title"            = "Sign In"
      "submitButtonText" = "Sign In"
      "forgotPasswordText" = "Forgot Password?"
    }
  })
}

resource "auth0_prompt_custom_text" "login_fr" {
  prompt   = "login"
  language = "fr-CA"
  body     = jsonencode({
    "login" = {
      "pageTitle"          = "Connexion – Services bancaires en ligne"
      "title"              = "Connexion"
      "submitButtonText"   = "Se connecter"
      "forgotPasswordText" = "Mot de passe oublié?"
    }
  })
}

# ── MFA enrollment prompt – bilingual (UC-05) ──────────────────────────────
resource "auth0_prompt_custom_text" "mfa_enroll_en" {
  prompt   = "mfa-push-enrollment-qr"
  language = "en"
  body     = jsonencode({
    "mfa-push-enrollment-qr" = {
      "pageTitle" = "Set Up Two-Step Verification"
      "title"     = "Protect Your Account with 2-Step Verification"
    }
  })
}

# ── Password reset prompt – bilingual (UC-07) ──────────────────────────────
resource "auth0_prompt_custom_text" "reset_password_en" {
  prompt   = "reset-password"
  language = "en"
  body     = jsonencode({
    "reset-password" = {
      "pageTitle"        = "Reset Your Password – Online Banking"
      "title"            = "Create a New Password"
      "description"      = "Your new password must be at least 12 characters and include uppercase, lowercase, a number, and a special character."
      "submitButtonText" = "Set New Password"
    }
  })
}

resource "auth0_prompt_custom_text" "reset_password_fr" {
  prompt   = "reset-password"
  language = "fr-CA"
  body     = jsonencode({
    "reset-password" = {
      "pageTitle"        = "Réinitialiser votre mot de passe"
      "title"            = "Créer un nouveau mot de passe"
      "description"      = "Votre mot de passe doit comporter au moins 12 caractères avec majuscules, minuscules, un chiffre et un caractère spécial."
      "submitButtonText" = "Définir le nouveau mot de passe"
    }
  })
}
