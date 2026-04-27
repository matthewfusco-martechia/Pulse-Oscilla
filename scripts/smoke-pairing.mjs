import { createDecipheriv, createPublicKey, diffieHellman, generateKeyPairSync, hkdfSync } from "node:crypto";
import { mkdir } from "node:fs/promises";
import WebSocket from "ws";
import { startHostAgent } from "../packages/host-agent/dist/index.js";

const workspaceRoot = "/tmp/pulse-oscilla-smoke";
await mkdir(workspaceRoot, { recursive: true });

const agent = await startHostAgent({
  workspaceRoot,
  host: "127.0.0.1",
  port: 0
});

try {
  const qr = JSON.parse(agent.pairingPayload);
  const device = generateKeyPairSync("x25519");
  const socket = new WebSocket(agent.endpoint);
  await new Promise((resolve, reject) => {
    socket.once("open", resolve);
    socket.once("error", reject);
  });

  socket.send(JSON.stringify({
    type: "pairing.hello",
    payload: {
      pairingId: qr.pairingId,
      deviceName: "smoke-test",
      devicePublicKey: rawPublicKey(device.publicKey).toString("base64"),
      deviceIdentityPublicKey: rawPublicKey(device.publicKey).toString("base64")
    }
  }));

  const encrypted = JSON.parse(await new Promise((resolve) => {
    socket.once("message", (data) => resolve(data.toString()));
  }));

  const plaintext = decryptAcceptedFrame({
    encrypted,
    qr,
    devicePrivateKey: device.privateKey
  });
  const accepted = JSON.parse(plaintext.toString("utf8"));

  if (accepted.payload.workspaceRoot !== workspaceRoot) {
    throw new Error(`Unexpected workspace root: ${accepted.payload.workspaceRoot}`);
  }

  console.log(`Pairing smoke test passed: ${accepted.payload.workspaceRoot}`);
  socket.close();
} finally {
  await agent.stop();
}

function rawPublicKey(key) {
  return Buffer.from(key.export({ format: "jwk" }).x, "base64url");
}

function decryptAcceptedFrame({ encrypted, qr, devicePrivateKey }) {
  const hostPublicKey = createPublicKey({
    key: {
      kty: "OKP",
      crv: "X25519",
      x: Buffer.from(qr.hostPublicKey, "base64").toString("base64url")
    },
    format: "jwk"
  });
  const shared = diffieHellman({
    privateKey: devicePrivateKey,
    publicKey: hostPublicKey
  });
  const key = Buffer.from(hkdfSync(
    "sha256",
    shared,
    Buffer.from(qr.nonce, "base64"),
    `pulse-oscilla:${qr.pairingId}`,
    32
  ));

  const decipher = createDecipheriv("aes-256-gcm", key, Buffer.from(encrypted.nonce, "base64"));
  decipher.setAAD(Buffer.from(`${encrypted.sessionId}:${encrypted.sequence}`));
  decipher.setAuthTag(Buffer.from(encrypted.tag, "base64"));
  return Buffer.concat([
    decipher.update(Buffer.from(encrypted.ciphertext, "base64")),
    decipher.final()
  ]);
}

