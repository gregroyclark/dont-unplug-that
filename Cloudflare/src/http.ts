export type Json = null | boolean | number | string | Json[] | { [key: string]: Json };

export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly current?: Json
  ) {
    super(message);
  }
}

export function errorResponse(error: unknown): Response {
  if (error instanceof HttpError) {
    const body: { error: { code: string; message: string; current?: Json } } = {
      error: { code: error.code, message: error.message }
    };
    if (error.current !== undefined) body.error.current = error.current;
    return Response.json(body, { status: error.status });
  }
  return Response.json(
    { error: { code: "internal_error", message: "The request could not be completed" } },
    { status: 500 }
  );
}

export function requiredHeader(request: Request, name: string): string {
  const value = request.headers.get(name);
  if (!value) throw new HttpError(400, "missing_header", `${name} is required`);
  return value;
}

export function requiredIfMatch(request: Request): number {
  const value = request.headers.get("if-match");
  if (!value) throw new HttpError(428, "precondition_required", "If-Match is required");
  const match = /^"(0|[1-9][0-9]*)"$/.exec(value);
  if (!match) throw new HttpError(400, "invalid_precondition", "If-Match must be a quoted integer revision");
  return Number(match[1]);
}

export function requireIfNoneMatchStar(request: Request): void {
  if (request.headers.get("if-none-match") !== "*") {
    throw new HttpError(428, "precondition_required", "If-None-Match: * is required");
  }
}

export async function jsonBody(request: Request, maximumBytes = 131_072): Promise<Json> {
  const contentLength = request.headers.get("content-length");
  if (contentLength && (!/^[0-9]+$/.test(contentLength) || Number(contentLength) > maximumBytes)) {
    throw new HttpError(413, "payload_too_large", "The JSON payload is too large");
  }
  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > maximumBytes) {
    throw new HttpError(413, "payload_too_large", "The JSON payload is too large");
  }
  try {
    return JSON.parse(text) as Json;
  } catch {
    throw new HttpError(400, "invalid_json", "The request body must be valid JSON");
  }
}

export function record(value: Json, code = "invalid_payload"): { [key: string]: Json } {
  if (value === null || Array.isArray(value) || typeof value !== "object") {
    throw new HttpError(400, code, "The request body must be an object");
  }
  return value;
}

export function stringField(value: Json | undefined, name: string): string {
  if (typeof value !== "string" || !value) {
    throw new HttpError(400, "invalid_payload", `${name} must be a non-empty string`);
  }
  return value;
}

export function notFound(): HttpError {
  return new HttpError(404, "not_found", "The requested resource was not found");
}

export function base64url(bytes: ArrayBuffer): string {
  const values = new Uint8Array(bytes);
  let binary = "";
  for (const value of values) binary += String.fromCharCode(value);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

export function base64(bytes: ArrayBuffer): string {
  const values = new Uint8Array(bytes);
  let binary = "";
  for (const value of values) binary += String.fromCharCode(value);
  return btoa(binary);
}

export async function sha256(value: string | ArrayBuffer): Promise<string> {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
  return base64url(await crypto.subtle.digest("SHA-256", bytes));
}

export function equalBytes(left: Uint8Array, right: Uint8Array): boolean {
  if (left.length !== right.length) return false;
  let different = 0;
  for (let index = 0; index < left.length; index += 1) different |= left[index]! ^ right[index]!;
  return different === 0;
}

export function decodeBase64(value: string): Uint8Array | null {
  try {
    const binary = atob(value);
    return Uint8Array.from(binary, (character) => character.charCodeAt(0));
  } catch {
    return null;
  }
}
