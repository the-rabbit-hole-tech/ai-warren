import { describe, expect, it } from "vitest";
import Fastify from "fastify";
import plugin from "./index.js";

describe("__REPO_NAME__ plugin", () => {
  it("decorates the instance with a default greeting", async () => {
    const app = Fastify();
    await app.register(plugin);
    await app.ready();

    expect(app.greet("world")).toBe("Hello, world!");

    await app.close();
  });

  it("honors a custom greeting option and serves it via a route", async () => {
    const app = Fastify();
    await app.register(plugin, { greeting: "Hi" });
    app.get("/greet/:name", (request) => {
      const { name } = request.params as { name: string };
      return { message: app.greet(name) };
    });
    await app.ready();

    const response = await app.inject({ method: "GET", url: "/greet/world" });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ message: "Hi, world!" });

    await app.close();
  });
});
