export const fixtureContainerInstanceName = "fixture-api";

export const vaporContainerOptions = {
  defaultPort: 8080,
  sleepAfter: "10m",
  enableInternet: false,
  pingEndpoint: "localhost/health"
} as const;

type RequestForwarder = {
  fetch(request: Request): Promise<Response>;
};

export function proxyRequest(request: Request, container: RequestForwarder): Promise<Response> {
  return container.fetch(request);
}

export function proxyFixtureRequest(
  request: Request,
  getContainerByName: (name: string) => RequestForwarder
): Promise<Response> {
  return proxyRequest(request, getContainerByName(fixtureContainerInstanceName));
}
