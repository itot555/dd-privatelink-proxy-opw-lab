/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_ENABLE_RUM: string;
  readonly VITE_RUM_APPLICATION_ID: string;
  readonly VITE_RUM_CLIENT_TOKEN: string;
  readonly VITE_DD_SITE: string;
  readonly VITE_DD_ENV: string;
  readonly VITE_DD_VERSION: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
