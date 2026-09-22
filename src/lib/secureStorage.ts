import * as SecureStore from 'expo-secure-store';

/**
 * Storage adapter for the Supabase session, backed by the iOS Keychain / Android Keystore.
 *
 * SecureStore values are limited to 2048 bytes, and a Supabase session (two JWTs plus
 * user metadata) is usually larger, so each value is split across several keys.
 * 500 code points × at most 4 bytes each stays under the limit even for non-Latin names.
 */
const CHUNK_CODE_POINTS = 500;

const countKey = (key: string) => `${key}.chunks`;
const chunkKey = (key: string, index: number) => `${key}.${index}`;

async function getItem(key: string): Promise<string | null> {
  const count = await SecureStore.getItemAsync(countKey(key));
  if (count === null) return null;

  const chunks = await Promise.all(
    Array.from({ length: Number(count) }, (_, i) => SecureStore.getItemAsync(chunkKey(key, i))),
  );
  // A missing chunk means a write was interrupted; a partial session is worse than none.
  if (chunks.some((chunk) => chunk === null)) return null;
  return chunks.join('');
}

async function removeItem(key: string): Promise<void> {
  const count = await SecureStore.getItemAsync(countKey(key));
  // Remove the count first so a crash mid-removal leaves no readable half-session.
  await SecureStore.deleteItemAsync(countKey(key));
  if (count === null) return;
  await Promise.all(
    Array.from({ length: Number(count) }, (_, i) => SecureStore.deleteItemAsync(chunkKey(key, i))),
  );
}

async function setItem(key: string, value: string): Promise<void> {
  await removeItem(key);

  // Split by code point, not UTF-16 unit, so an emoji is never cut in half.
  const codePoints = Array.from(value);
  const chunks: string[] = [];
  for (let i = 0; i < codePoints.length; i += CHUNK_CODE_POINTS) {
    chunks.push(codePoints.slice(i, i + CHUNK_CODE_POINTS).join(''));
  }

  await Promise.all(chunks.map((chunk, i) => SecureStore.setItemAsync(chunkKey(key, i), chunk)));
  // Written last: the value only becomes readable once every chunk is in place.
  await SecureStore.setItemAsync(countKey(key), String(chunks.length));
}

export const secureStorage = { getItem, setItem, removeItem };
