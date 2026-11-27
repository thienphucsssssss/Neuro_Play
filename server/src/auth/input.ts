const usernamePattern = /^[a-zA-Z0-9_]{3,32}$/;
const emailPattern = /^[^\s@\p{Cc}\p{Cs}]+@[^\s@\p{Cc}\p{Cs}]+\.[^\s@\p{Cc}\p{Cs}]+$/u;

function isObject(body: unknown): body is Record<string, unknown> {
  return typeof body === 'object' && body !== null && !Array.isArray(body);
}

function trimmed(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function isEmail(value: string): boolean {
  return [...value].length <= 254 && emailPattern.test(value);
}

function isPassword(value: unknown): value is string {
  if (typeof value !== 'string' || [...value].length < 15) return false;
  const utf8 = Buffer.from(value, 'utf8');
  return utf8.length <= 72 && utf8.toString('utf8') === value;
}

export function readRegistration(body: unknown) {
  if (!isObject(body)) return null;

  const enteredUsername = trimmed(body.username);
  const email = trimmed(body.email).toLowerCase();
  const { password } = body;
  if (!usernamePattern.test(enteredUsername) || !isEmail(email) || !isPassword(password)) return null;
  if (body.displayName !== undefined && typeof body.displayName !== 'string') return null;

  const username = enteredUsername.toLowerCase();
  const displayName = body.displayName?.trim() || username;
  if ([...displayName].length > 80) return null;

  return { username, email, password, displayName };
}

export function readLogin(body: unknown) {
  if (!isObject(body)) return null;

  const enteredIdentifier = trimmed(body.identifier);
  const identifier = enteredIdentifier.toLowerCase();
  const { password } = body;
  if ((!usernamePattern.test(enteredIdentifier) && !isEmail(identifier)) || !isPassword(password)) return null;

  return { identifier, password };
}

export function readRefreshToken(body: unknown): string | null {
  if (!isObject(body) || typeof body.refreshToken !== 'string' || body.refreshToken.length === 0) return null;
  return body.refreshToken;
}
