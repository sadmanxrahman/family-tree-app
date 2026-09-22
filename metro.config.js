// Sentry's Metro config adds a debug ID to each bundle so uploaded source maps can be
// matched to crashes, turning minified production stack traces back into real file
// names and line numbers. Uploads happen during EAS Build/Update (see SENTRY_* in
// .env.example); in Expo Go the bundle isn't minified, so traces are readable anyway.
const { getSentryExpoConfig } = require('@sentry/react-native/metro');

module.exports = getSentryExpoConfig(__dirname);
