import { createClient } from "@supabase/supabase-js";
import { Preferences } from "@capacitor/preferences";

// Session storage backed by Capacitor Preferences so the session survives app
// restarts and WKWebView backgrounding (localStorage can be cleared on device).
const capacitorStorage = {
  getItem: async (key: string) => (await Preferences.get({ key })).value,
  setItem: async (key: string, value: string) => {
    await Preferences.set({ key, value });
  },
  removeItem: async (key: string) => {
    await Preferences.remove({ key });
  },
};

// Read Vite env without coupling packages/core's typecheck to vite/client types.
const env = (import.meta as unknown as { env: Record<string, string | undefined> }).env;
const url = env.VITE_SUPABASE_URL;
const anonKey = env.VITE_SUPABASE_ANON_KEY;

if (!url || !anonKey) {
  console.warn(
    "[supabase] Missing VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY — set them in apps/mobile/.env",
  );
}

export const supabase = createClient(url ?? "", anonKey ?? "", {
  auth: {
    storage: capacitorStorage,
    flowType: "pkce",
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: false, // native deep-link handled by the native-auth step
  },
});
