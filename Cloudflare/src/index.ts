import { Container, getContainer } from "@cloudflare/containers";
import {
  proxyFixtureRequest,
  vaporContainerOptions
} from "./proxy";

export class VaporAPIContainer extends Container {
  defaultPort = vaporContainerOptions.defaultPort;
  sleepAfter = vaporContainerOptions.sleepAfter;
  enableInternet = vaporContainerOptions.enableInternet;
  pingEndpoint = vaporContainerOptions.pingEndpoint;
}

export default {
  fetch(request, env): Promise<Response> {
    return proxyFixtureRequest(request, (name) => getContainer(env.VAPOR_API, name));
  }
} satisfies ExportedHandler<Env>;
