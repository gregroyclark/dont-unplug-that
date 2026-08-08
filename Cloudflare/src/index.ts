import { Container, getContainer } from "@cloudflare/containers";
import type { AuthEnv } from "./auth";
import {
  isVaporFixtureRequest,
  proxyFixtureRequest,
  RequestForwarder,
  vaporContainerOptions
} from "./proxy";
import { routeWorker } from "./router";
import { cleanupPendingAccountDeletions } from "./session";
import { cleanupPendingGuidePhotoDeletions } from "./sync";

export class VaporAPIContainer extends Container {
  defaultPort = vaporContainerOptions.defaultPort;
  sleepAfter = vaporContainerOptions.sleepAfter;
  enableInternet = vaporContainerOptions.enableInternet;
  pingEndpoint = vaporContainerOptions.pingEndpoint;
}

export async function handleRequest(
  request: Request,
  env: Env,
  findContainer: (name: string) => RequestForwarder
): Promise<Response> {
  if (isVaporFixtureRequest(request)) return proxyFixtureRequest(request, findContainer);
  return routeWorker(request, env as AuthEnv);
}

export default {
  fetch(request, env): Promise<Response> {
    return handleRequest(request, env, (name) => getContainer(env.VAPOR_API, name));
  },
  async scheduled(_controller, env): Promise<void> {
    await cleanupPendingAccountDeletions(env as AuthEnv, 100);
    await cleanupPendingGuidePhotoDeletions(env as AuthEnv, 100);
  }
} satisfies ExportedHandler<Env>;
