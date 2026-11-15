/**
 * Optional application entry point.
 *
 * This file is NOT part of the published package (tsdown only bundles
 * `src/index.ts`). It exists so the plugin can "grow into" a runnable service:
 * `@fastify/autoload` registers everything under `src/plugins/`, and
 * `fastify-cli` boots this default export. See the README for how to run it.
 */
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import AutoLoad from "@fastify/autoload";
import type { FastifyInstance, FastifyPluginOptions } from "fastify";

const __dirname = fileURLToPath(new URL(".", import.meta.url));

export default async function app(
  fastify: FastifyInstance,
  opts: FastifyPluginOptions,
): Promise<void> {
  await fastify.register(AutoLoad, {
    dir: join(__dirname, "plugins"),
    options: opts,
  });
}
