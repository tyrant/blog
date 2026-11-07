// Passkey (WebAuthn) sign-in and registration for /admin.
//
// Buttons opt in with data-passkey-action="sign-in" | "register", plus
// data-options-url (server returns the WebAuthn options JSON) and data-verify-url
// (receives the browser's credential). Messages go to [data-passkey-status].
// The server speaks base64url (webauthn-ruby); the browser API wants ArrayBuffers.

const fromB64url = (value) => {
  const base64 = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64 + '='.repeat((4 - (base64.length % 4)) % 4);
  return Uint8Array.from(atob(padded), (char) => char.charCodeAt(0)).buffer;
};

const toB64url = (buffer) => {
  let binary = '';
  for (const byte of new Uint8Array(buffer)) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};

const postJSON = async (url, body = {}) => {
  const response = await fetch(url, {
    method: 'POST',
    credentials: 'same-origin',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content ?? ''
    },
    body: JSON.stringify(body)
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || `Request failed (${response.status}).`);
  return data;
};

const decodeCredentialList = (list) => (list || []).map((cred) => ({ ...cred, id: fromB64url(cred.id) }));

const encodeCredential = (credential) => {
  const { response } = credential;
  const encoded = {
    type: credential.type,
    id: credential.id,
    rawId: toB64url(credential.rawId),
    authenticatorAttachment: credential.authenticatorAttachment,
    clientExtensionResults: credential.getClientExtensionResults(),
    response: { clientDataJSON: toB64url(response.clientDataJSON) }
  };
  if (response.attestationObject) {
    encoded.response.attestationObject = toB64url(response.attestationObject);
    encoded.response.transports = response.getTransports?.() ?? [];
  } else {
    encoded.response.authenticatorData = toB64url(response.authenticatorData);
    encoded.response.signature = toB64url(response.signature);
    encoded.response.userHandle = response.userHandle ? toB64url(response.userHandle) : null;
  }
  return encoded;
};

const signIn = async (button) => {
  const options = await postJSON(button.dataset.optionsUrl);
  options.challenge = fromB64url(options.challenge);
  options.allowCredentials = decodeCredentialList(options.allowCredentials);
  const credential = await navigator.credentials.get({ publicKey: options });
  return postJSON(button.dataset.verifyUrl, { credential: encodeCredential(credential) });
};

const register = async (button) => {
  const options = await postJSON(button.dataset.optionsUrl);
  options.challenge = fromB64url(options.challenge);
  options.user.id = fromB64url(options.user.id);
  options.excludeCredentials = decodeCredentialList(options.excludeCredentials);
  const credential = await navigator.credentials.create({ publicKey: options });
  const nickname = document.querySelector(button.dataset.nicknameInput)?.value ?? '';
  return postJSON(button.dataset.verifyUrl, { credential: encodeCredential(credential), nickname });
};

const ACTIONS = { 'sign-in': signIn, register };

const describeError = (error) => {
  // The user dismissed the browser prompt, or it timed out.
  if (error?.name === 'NotAllowedError') return 'Cancelled — try again when ready.';
  if (error?.name === 'InvalidStateError') return 'That authenticator already has a passkey for this site.';
  return error?.message || 'Something went wrong.';
};

document.addEventListener('click', async (event) => {
  const button = event.target.closest('[data-passkey-action]');
  if (!button) return;

  const status = document.querySelector('[data-passkey-status]');
  const setStatus = (text, isError = false) => {
    if (!status) return;
    status.textContent = text;
    status.classList.toggle('text-danger', isError);
  };

  if (!window.PublicKeyCredential) {
    setStatus('This browser does not support passkeys.', true);
    return;
  }

  button.disabled = true;
  setStatus('Waiting for your passkey…');
  try {
    const result = await ACTIONS[button.dataset.passkeyAction](button);
    window.location.assign(result.redirect_to);
  } catch (error) {
    setStatus(describeError(error), true);
    button.disabled = false;
  }
});
