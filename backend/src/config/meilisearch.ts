import { MeiliSearch } from "meilisearch";
import { env } from "./env";

export const meilisearch = env.MEILISEARCH_API_KEY
  ? new MeiliSearch({
      host: env.MEILISEARCH_HOST,
      apiKey: env.MEILISEARCH_API_KEY,
    })
  : null;
