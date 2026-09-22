import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // Family data changes slowly; avoid refetching on every screen visit.
      staleTime: 60_000,
      retry: 2,
    },
  },
});
