/**
 * __REPO_NAME__
 *
 * __DESCRIPTION__
 *
 * A Fastify v5 plugin written with `fastify-plugin` so its decorators and
 * hooks are available on the encapsulating instance. This file is the
 * published entry point. Replace the example option and decorator with the
 * plugin's real surface.
 */
import fp from "fastify-plugin";
import type { FastifyPluginAsync } from "fastify";

/** Options accepted by the plugin. */
export interface ExampleOptions {
  /** Greeting prefix used by the `greet` decorator. Defaults to `"Hello"`. */
  greeting?: string;
}

declare module "fastify" {
  interface FastifyInstance {
    /** Greet a name using the configured greeting prefix. */
    greet(name: string): string;
  }
}

const plugin: FastifyPluginAsync<ExampleOptions> = async (fastify, opts) => {
  const greeting = opts.greeting ?? "Hello";

  fastify.decorate("greet", function greet(name: string): string {
    return `${greeting}, ${name}!`;
  });
};

export default fp(plugin, {
  fastify: "5.x",
  name: "__REPO_NAME__",
});
