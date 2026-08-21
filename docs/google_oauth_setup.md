# Google OAuth setup for Saki Chat

The Google OAuth Client ID supplied for the Saki Chat project is:

```text
543559795997-inds88818ki7koj5qqmthq0osgg0cc5h.apps.googleusercontent.com
```

This ID is public OAuth client metadata. Supabase still requires the matching Google OAuth Client Secret in the Google provider configuration; do not commit or paste the secret into the Flutter project.

## Supabase provider settings

In Supabase Auth Provider settings, enable Google and enter the Client ID and matching Client Secret. Add the following redirect URLs to the Supabase redirect allow list:

```text
https://uhaugikrudchlunaufjj.supabase.co/auth/v1/callback
https://8080-i4cnwrwg7od5jc89wmu3y-5b008138.sg1.manus.computer
saki.chat.co://login-callback
```

## Google Cloud settings

Create or edit a Web OAuth client. Add the Saki Chat web origin as an Authorized JavaScript origin while testing. Add the Supabase callback URL below as an Authorized redirect URI:

```text
https://uhaugikrudchlunaufjj.supabase.co/auth/v1/callback
```

The Flutter application calls Supabase `signInWithOAuth` and uses the current web origin on web or `saki.chat.co://login-callback` on Android/iOS. The native Android intent filter and iOS URL scheme are already included in the project.

References: [Supabase Google OAuth](https://supabase.com/docs/guides/auth/social-login/auth-google), [Supabase native deep linking](https://supabase.com/docs/guides/auth/native-mobile-deep-linking), and [supabase_flutter OAuth reference](https://supabase.com/docs/reference/dart/auth-signinwithoauth).
