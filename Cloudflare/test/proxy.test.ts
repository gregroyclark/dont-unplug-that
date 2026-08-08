import { describe, expect, it } from "vitest";

import {
  fixtureContainerInstanceName,
  isVaporFixtureRequest,
  proxyFixtureRequest,
  proxyRequest,
  vaporContainerOptions
} from "../src/proxy";
import { handleRequest } from "../src/index";
import { workerEnv } from "./support";

describe("Vapor container proxy", () => {
  it("uses the approved container runtime settings", () => {
    expect(fixtureContainerInstanceName).toBe("fixture-api");
    expect(vaporContainerOptions).toEqual({
      defaultPort: 8080,
      sleepAfter: "10m",
      enableInternet: false,
      pingEndpoint: "localhost/health"
    });
  });

  it("forwards only the approved anonymous request surface to the container", async () => {
    const request = new Request("https://api.example.test/v1/guides/analyze?fixture=true", {
      method: "POST",
      headers: {
        authorization: "Bearer secret",
        cookie: "session=secret",
        "cf-access-jwt-assertion": "assertion",
        "content-type": "application/json",
        "proxy-authorization": "Basic secret",
        "x-user-id": "forged"
      },
      body: '{"base64EncodedImage":"ZmFrZQ=="}'
    });
    const response = new Response("from-container", { status: 201 });
    let forwardedRequest: Request | undefined;
    const container = {
      fetch(incoming: Request): Promise<Response> {
        forwardedRequest = incoming;
        return Promise.resolve(response);
      }
    };

    await expect(proxyRequest(request, container)).resolves.toBe(response);
    expect(forwardedRequest).toBeDefined();
    expect(forwardedRequest).not.toBe(request);
    expect(forwardedRequest!.url).toBe(request.url);
    expect(forwardedRequest!.headers.get("content-type")).toBe("application/json");
    expect(forwardedRequest!.headers.get("authorization")).toBeNull();
    expect(forwardedRequest!.headers.get("cookie")).toBeNull();
    expect(forwardedRequest!.headers.get("proxy-authorization")).toBeNull();
    expect(forwardedRequest!.headers.get("cf-access-jwt-assertion")).toBeNull();
    expect(forwardedRequest!.headers.get("x-user-id")).toBeNull();
  });

  it("selects the one stable fixture-api instance", async () => {
    const request = new Request("https://api.example.test/health");
    const response = new Response("ok");
    let selectedName: string | undefined;

    await expect(
      proxyFixtureRequest(request, (name) => {
        selectedName = name;
        return { fetch: () => Promise.resolve(response) };
      })
    ).resolves.toBe(response);

    expect(selectedName).toBe("fixture-api");
  });

  it("routes only the two exact Vapor fixture endpoints", () => {
    expect(isVaporFixtureRequest(new Request("https://api.example.test/health"))).toBe(true);
    expect(isVaporFixtureRequest(new Request("https://api.example.test/health/"))).toBe(false);
    expect(isVaporFixtureRequest(new Request("https://api.example.test/health", { method: "POST" }))).toBe(false);
    expect(isVaporFixtureRequest(new Request("https://api.example.test/v1/guides/analyze", { method: "POST" }))).toBe(true);
    expect(isVaporFixtureRequest(new Request("https://api.example.test/v1/guides/analyze?fixture=true", { method: "GET" }))).toBe(false);
    expect(isVaporFixtureRequest(new Request("https://api.example.test/v1/sync/snapshot"))).toBe(false);
  });

  it("does not obtain a Container for auth or sync routes", async () => {
    let wakeCount = 0;
    const container = () => {
      wakeCount += 1;
      return { fetch: async () => new Response("unexpected") };
    };
    const auth = await handleRequest(new Request("https://api.example.test/api/auth/get-session"), workerEnv, container);
    const sync = await handleRequest(new Request("https://api.example.test/v1/sync/snapshot"), workerEnv, container);
    expect(auth.status).toBe(404);
    expect(sync.status).toBe(401);
    expect(wakeCount).toBe(0);
  });
});
