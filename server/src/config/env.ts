export function parsePort(value: string, name: string): number {
  const port = Number(value);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error(`${name} must be an integer between 1 and 65535.`);
  }
  return port;
}

export interface JwtSecrets {
  access: Buffer;
  refresh: Buffer;
}

function readJwtSecret(name: string): Buffer {
  const value = process.env[name] ?? '';
  const secret = Buffer.from(value, 'base64url');
  if (secret.length !== 32 || secret.toString('base64url') !== value) {
    throw new Error(`Configure ${name} with 32 random bytes encoded as unpadded base64url.`);
  }
  return secret;
}

export function readJwtSecrets(): JwtSecrets {
  const access = readJwtSecret('JWT_ACCESS_SECRET');
  const refresh = readJwtSecret('JWT_REFRESH_SECRET');
  if (access.equals(refresh)) {
    throw new Error('JWT_ACCESS_SECRET and JWT_REFRESH_SECRET must be different.');
  }
  return { access, refresh };
}
