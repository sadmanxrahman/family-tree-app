import { Redirect } from 'expo-router';

// The app opens on the family tree — the heart of the app.
export default function Index() {
  return <Redirect href="/tree" />;
}
