import { useQuery } from '@tanstack/react-query';
import { z } from 'zod';

import { useAuthStore } from '@/features/auth/authStore';

import { reportError } from './errors';
import { supabase } from './supabase';

/**
 * Remote feature flags from the app_config table (CLAUDE.md rule 5). Change a value in the
 * Supabase dashboard's Table Editor, and it takes effect on the next app launch.
 *
 * Every default is the SAFE value: if the fetch fails, the app is offline, or a row is
 * missing or malformed, the risky feature stays off.
 */
const flagDefaults = {
  ads_enabled: false,
  discovery_enabled: false,
  live_location_enabled: false,
  print_enabled: false,
} as const satisfies Record<string, boolean>;

export type FlagKey = keyof typeof flagDefaults;
export type Flags = Record<FlagKey, boolean>;

export type FlagsStatus = 'loading' | 'loaded' | 'defaults';

const rowsSchema = z.array(z.object({ key: z.string(), value: z.unknown() }));

function isFlagKey(key: string): key is FlagKey {
  return key in flagDefaults;
}

async function fetchFlags(): Promise<Flags> {
  const { data, error } = await supabase
    .from('app_config')
    .select('key, value')
    .is('deleted_at', null);
  if (error) throw error;

  const flags: Flags = { ...flagDefaults };
  for (const row of rowsSchema.parse(data)) {
    // Unknown keys are ignored; a non-boolean value keeps the safe default.
    if (isFlagKey(row.key) && typeof row.value === 'boolean') {
      flags[row.key] = row.value;
    }
  }
  return flags;
}

/** All flags plus where they came from. Most code should use useFlag instead. */
export function useFlags(): { flags: Flags; status: FlagsStatus } {
  // app_config is readable only when signed in, so the fetch is per account and waits
  // for a session. Signing out clears the query cache, so the next account refetches.
  const userId = useAuthStore((state) => state.session?.user.id ?? null);

  const query = useQuery({
    queryKey: ['app_config', userId],
    enabled: userId !== null,
    queryFn: async () => {
      try {
        return await fetchFlags();
      } catch (error) {
        reportError(error, { area: 'flags', action: 'fetchFlags' });
        throw error;
      }
    },
    // Fetched once per app launch: never considered stale, never refetched on focus.
    staleTime: Infinity,
    gcTime: Infinity,
    refetchOnWindowFocus: false,
    refetchOnReconnect: false,
  });

  if (query.data) return { flags: query.data, status: 'loaded' };
  if (query.isPending && userId !== null) return { flags: flagDefaults, status: 'loading' };
  return { flags: flagDefaults, status: 'defaults' };
}

/**
 * Whether a flagged feature is on. Returns the safe default (off) while loading, when
 * signed out, and when the fetch fails, so callers never need their own loading state.
 */
export function useFlag(key: FlagKey): boolean {
  return useFlags().flags[key];
}
