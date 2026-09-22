import * as ExpoCrypto from 'expo-crypto';

/**
 * React Native has no Web Crypto API, so supabase-js silently weakens PKCE: it builds the
 * one-time verifier with Math.random (predictable) and sends it as a "plain" challenge
 * instead of a SHA-256 hash. These two functions, backed by expo-crypto (included in
 * Expo Go), are exactly what supabase-js checks for: crypto.getRandomValues and
 * crypto.subtle.digest('SHA-256', …).
 *
 * Deliberately minimal: only SHA-256 digest is provided. Anything calling another
 * SubtleCrypto method gets a clear error rather than a silent fallback.
 *
 * Must be imported before supabase-js creates its client.
 */

type RandomArray = Parameters<typeof ExpoCrypto.getRandomValues>[0];

type DigestAlgorithm = string | { name: string };

type CryptoShape = {
  getRandomValues?: <T extends RandomArray>(array: T) => T;
  subtle?: {
    digest: (algorithm: DigestAlgorithm, data: BufferSource) => Promise<ArrayBuffer>;
  };
};

const scope = globalThis as unknown as { crypto?: CryptoShape };
const cryptoObject: CryptoShape = scope.crypto ?? {};

if (typeof cryptoObject.getRandomValues !== 'function') {
  cryptoObject.getRandomValues = (array) => ExpoCrypto.getRandomValues(array);
}

if (!cryptoObject.subtle) {
  cryptoObject.subtle = {
    digest: (algorithm, data) => {
      const name = typeof algorithm === 'string' ? algorithm : algorithm.name;
      if (name.toUpperCase() !== 'SHA-256') {
        return Promise.reject(
          new Error(`cryptoPolyfill: only SHA-256 is supported, got "${name}"`),
        );
      }
      return ExpoCrypto.digest(ExpoCrypto.CryptoDigestAlgorithm.SHA256, data);
    },
  };
}

scope.crypto = cryptoObject;
