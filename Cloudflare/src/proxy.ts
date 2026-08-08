export const fixtureContainerInstanceName = "fixture-api";

export const vaporContainerOptions = {
  defaultPort: 8080,
  sleepAfter: "10m",
  enableInternet: false,
  pingEndpoint: "localhost/health"
} as const;

export function isVaporFixtureRequest(request: Request): boolean {
  const pathname = new URL(request.url).pathname;
  return (request.method === "GET" && pathname === "/health") ||
    (request.method === "POST" && pathname === "/v1/guides/analyze");
}

export type RequestForwarder = {
  fetch(request: Request): Promise<Response>;
};

export function proxyRequest(request: Request, container: RequestForwarder): Promise<Response> {
  const headers = new Headers();
  for (const name of ["accept", "content-type"]) {
    const value = request.headers.get(name);
    if (value) headers.set(name, value);
  }
  return container.fetch(
    new Request(request.url, {
      body: request.method === "GET" || request.method === "HEAD" ? undefined : request.body,
      headers,
      method: request.method
    })
  );
}

export function proxyFixtureRequest(
  request: Request,
  getContainerByName: (name: string) => RequestForwarder
): Promise<Response> {
  return proxyRequest(request, getContainerByName(fixtureContainerInstanceName));
}
