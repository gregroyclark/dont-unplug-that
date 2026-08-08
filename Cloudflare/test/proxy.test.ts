import { describe, expect, it } from "vitest";

import {
  fixtureContainerInstanceName,
  proxyFixtureRequest,
  proxyRequest,
  vaporContainerOptions
} from "../src/proxy";

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

  it("passes the original Request to the container and returns its Response", async () => {
    const request = new Request("https://api.example.test/v1/guides/analyze?fixture=true", {
      method: "POST",
      headers: { "content-type": "application/json", "x-request-id": "proxy-test" },
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
    expect(forwardedRequest).toBe(request);
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
});
