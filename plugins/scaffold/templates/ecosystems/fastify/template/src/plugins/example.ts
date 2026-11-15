/**
 * Example autoloaded plugin for the optional app path.
 *
 * `@fastify/autoload` registers every module in this directory. Here we wire
 * the package's own plugin into the running app and expose a route that uses
 * its decorator. Add more files alongside this one as the service grows.
 */
import type { FastifyInstance, FastifyPluginOptions } from "fastify";
import example from "../index.js";

export default async function (
  fastify: FastifyInstance,
  opts: FastifyPluginOptions,
): Promise<void> {
  await fastify.register(example, opts);

  fastify.get("/greet/:name", (request) => {
    const { name } = request.params as { name: string };
    return { message: fastify.greet(name) };
  });
}
