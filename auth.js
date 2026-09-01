// Autenticação via API pública do Supabase, sem SDK externo.
const AUTH_SESSION_STORAGE_KEY = "meus_projetos_ia_auth_session";
const supabaseAuthConfig = window.SUPABASE_CONFIG ?? {};

const authScreenElement = document.querySelector("#auth-screen");
const dashboardShellElement = document.querySelector("#dashboard-shell");
const loginFormElement = document.querySelector("#login-form");
const signupFormElement = document.querySelector("#signup-form");
const authMessageElement = document.querySelector("#auth-message");
const authTabElements = document.querySelectorAll("[data-auth-view]");
const signOutButtonElement = document.querySelector("#sign-out-button");
const authenticatedEmailElement = document.querySelector("#authenticated-user-email");
const userAvatarElement = document.querySelector("#user-avatar");
const appMessageElement = document.querySelector("#app-message");

let currentAuthSession = null;
let appMessageTimeout;

function authGetSettings() {
  const url = typeof supabaseAuthConfig.url === "string"
    ? supabaseAuthConfig.url.trim().replace(/\/$/, "")
    : "";
  const anonKey = typeof supabaseAuthConfig.anonKey === "string"
    ? supabaseAuthConfig.anonKey.trim()
    : "";

  return { url, anonKey };
}

function authIsConfigured() {
  const { url, anonKey } = authGetSettings();
  const hasPlaceholder = url.includes("COLE_AQUI") || anonKey.includes("COLE_AQUI");

  try {
    const parsedUrl = new URL(url);
    return !hasPlaceholder && Boolean(anonKey) && ["http:", "https:"].includes(parsedUrl.protocol);
  } catch {
    return false;
  }
}

function authGetErrorMessage(error) {
  const message = String(error?.message ?? error ?? "").trim();
  const normalizedMessage = message.toLocaleLowerCase("pt-BR");

  if (normalizedMessage.includes("invalid login credentials")) return "E-mail ou senha incorretos.";
  if (normalizedMessage.includes("email not confirmed")) return "Confirme seu e-mail antes de entrar.";
  if (normalizedMessage.includes("user already registered") || normalizedMessage.includes("already been registered")) return "Já existe uma conta cadastrada com este e-mail.";
  if (normalizedMessage.includes("password should be at least")) return "A senha precisa ter pelo menos 6 caracteres.";
  if (normalizedMessage.includes("failed to fetch") || normalizedMessage.includes("networkerror")) return "Não foi possível conectar ao Supabase. Verifique sua internet e as credenciais públicas.";

  return message || "Não foi possível concluir a autenticação. Tente novamente.";
}

async function authRequest(path, { method = "GET", body, accessToken } = {}) {
  const { url, anonKey } = authGetSettings();
  if (!authIsConfigured()) {
    throw new Error("Configure a Project URL e a Publishable/Anon Public Key em supabase-config.js.");
  }

  const response = await fetch(`${url}/auth/v1/${path}`, {
    method,
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${accessToken || anonKey}`,
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });

  const responseText = await response.text();
  let payload = null;
  try {
    payload = responseText ? JSON.parse(responseText) : null;
  } catch {
    payload = null;
  }

  if (!response.ok) {
    throw new Error(payload?.msg || payload?.error_description || payload?.message || "Não foi possível concluir a solicitação.");
  }

  return payload;
}

function authGetSessionExpiration(session) {
  const expiresAt = Number(session?.expires_at);
  if (Number.isFinite(expiresAt) && expiresAt > 0) return expiresAt;

  const expiresIn = Number(session?.expires_in);
  return Math.floor(Date.now() / 1000) + (Number.isFinite(expiresIn) ? expiresIn : 3600);
}

function authReadSession() {
  try {
    const savedSession = localStorage.getItem(AUTH_SESSION_STORAGE_KEY);
    if (!savedSession) return null;

    const session = JSON.parse(savedSession);
    if (!session?.access_token || !session?.refresh_token) return null;

    return session;
  } catch {
    return null;
  }
}

function authSaveSession(session) {
  if (!session?.access_token || !session?.refresh_token) {
    throw new Error("A sessão retornada pelo Supabase é inválida.");
  }

  const savedSession = {
    access_token: session.access_token,
    refresh_token: session.refresh_token,
    expires_at: authGetSessionExpiration(session),
  };

  localStorage.setItem(AUTH_SESSION_STORAGE_KEY, JSON.stringify(savedSession));
  return savedSession;
}

function authClearSession() {
  localStorage.removeItem(AUTH_SESSION_STORAGE_KEY);
}

function authSessionNeedsRefresh(session) {
  return authGetSessionExpiration(session) <= Math.floor(Date.now() / 1000) + 60;
}

async function authRefreshSession(session) {
  const refreshedSession = await authRequest("token?grant_type=refresh_token", {
    method: "POST",
    body: { refresh_token: session.refresh_token },
  });

  return authSaveSession(refreshedSession);
}

function authGetUser(session) {
  return authRequest("user", { accessToken: session.access_token });
}

function authSetMessage(message = "", type = "info") {
  if (!message) {
    authMessageElement.hidden = true;
    authMessageElement.textContent = "";
    authMessageElement.className = "auth-message";
    return;
  }

  authMessageElement.hidden = false;
  authMessageElement.className = `auth-message is-${type}`;
  authMessageElement.textContent = message;
}

function authShowAppMessage(message) {
  window.clearTimeout(appMessageTimeout);
  appMessageElement.hidden = false;
  appMessageElement.textContent = message;
  appMessageTimeout = window.setTimeout(() => {
    appMessageElement.hidden = true;
  }, 4200);
}

function authSetControlsDisabled(disabled) {
  authScreenElement.querySelectorAll("button, input").forEach((control) => {
    control.disabled = disabled;
  });
}

function authSetView(view) {
  const isLogin = view === "login";
  loginFormElement.hidden = !isLogin;
  signupFormElement.hidden = isLogin;
  authTabElements.forEach((tab) => {
    const isActive = tab.dataset.authView === view;
    tab.classList.toggle("is-active", isActive);
    tab.setAttribute("aria-selected", String(isActive));
    tab.tabIndex = isActive ? 0 : -1;
  });
  authSetMessage();
}

function authGetAvatarLabel(email) {
  const identifier = String(email ?? "").split("@")[0].replace(/[^\p{L}\p{N}]+/gu, " ").trim();
  const initials = identifier.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]).join("");
  return (initials || "MP").toLocaleUpperCase("pt-BR");
}

function authHideProjectModal() {
  const projectModal = document.querySelector("#project-modal");
  projectModal?.classList.remove("is-visible");
  projectModal?.setAttribute("aria-hidden", "true");
  document.body.classList.remove("modal-open");
}

function authShowDashboard(user) {
  authenticatedEmailElement.textContent = user?.email || "Usuário autenticado";
  userAvatarElement.textContent = authGetAvatarLabel(user?.email);
  authScreenElement.hidden = true;
  dashboardShellElement.hidden = false;
}

function authShowScreen() {
  authHideProjectModal();
  dashboardShellElement.hidden = true;
  authScreenElement.hidden = false;
}

async function initializeAuth() {
  authSetView("login");

  if (!authIsConfigured()) {
    authShowScreen();
    authSetControlsDisabled(true);
    authSetMessage("Configure a Project URL e a Publishable/Anon Public Key em supabase-config.js para habilitar o acesso.", "info");
    return;
  }

  const savedSession = authReadSession();
  if (!savedSession) {
    authShowScreen();
    return;
  }

  authSetControlsDisabled(true);
  try {
    const validSession = authSessionNeedsRefresh(savedSession)
      ? await authRefreshSession(savedSession)
      : savedSession;
    const user = await authGetUser(validSession);
    currentAuthSession = validSession;
    authShowDashboard(user);
  } catch {
    authClearSession();
    currentAuthSession = null;
    authShowScreen();
    authSetMessage("Sua sessão expirou. Entre novamente para continuar.", "info");
  } finally {
    authSetControlsDisabled(false);
  }
}

async function authSignIn(event) {
  event.preventDefault();
  if (!loginFormElement.reportValidity()) return;

  const formData = new FormData(loginFormElement);
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  authSetMessage();
  authSetControlsDisabled(true);

  try {
    const response = await authRequest("token?grant_type=password", {
      method: "POST",
      body: { email, password },
    });
    currentAuthSession = authSaveSession(response);
    const user = response.user ?? await authGetUser(currentAuthSession);
    loginFormElement.reset();
    authShowDashboard(user);
    authShowAppMessage("Login realizado com sucesso.");
  } catch (error) {
    authSetMessage(authGetErrorMessage(error), "error");
  } finally {
    authSetControlsDisabled(false);
  }
}

async function authSignUp(event) {
  event.preventDefault();
  if (!signupFormElement.reportValidity()) return;

  const formData = new FormData(signupFormElement);
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  const passwordConfirmation = String(formData.get("passwordConfirmation") ?? "");

  if (password !== passwordConfirmation) {
    authSetMessage("A confirmação de senha não corresponde à senha informada.", "error");
    return;
  }

  authSetMessage();
  authSetControlsDisabled(true);
  try {
    const response = await authRequest("signup", {
      method: "POST",
      body: { email, password },
    });
    const session = response.session ?? response;
    signupFormElement.reset();

    if (session?.access_token && session?.refresh_token) {
      currentAuthSession = authSaveSession(session);
      authShowDashboard(response.user ?? await authGetUser(currentAuthSession));
      authShowAppMessage("Conta criada com sucesso.");
      return;
    }

    authSetView("login");
    loginFormElement.elements.email.value = email;
    authSetMessage("Conta criada. Verifique seu e-mail para confirmar o cadastro antes de entrar.", "success");
  } catch (error) {
    authSetMessage(authGetErrorMessage(error), "error");
  } finally {
    authSetControlsDisabled(false);
  }
}

async function authSignOut() {
  signOutButtonElement.disabled = true;
  try {
    if (currentAuthSession?.access_token && authIsConfigured()) {
      await authRequest("logout", {
        method: "POST",
        accessToken: currentAuthSession.access_token,
      });
    }
  } catch {
    // A sessão local ainda deve ser removida quando a conexão estiver indisponível.
  } finally {
    authClearSession();
    currentAuthSession = null;
    signOutButtonElement.disabled = false;
    authShowScreen();
    authSetView("login");
    authSetMessage("Você saiu da sua conta com segurança.", "success");
  }
}

authTabElements.forEach((tab) => {
  tab.addEventListener("click", () => authSetView(tab.dataset.authView));
});

loginFormElement.addEventListener("submit", authSignIn);
signupFormElement.addEventListener("submit", authSignUp);
signOutButtonElement.addEventListener("click", authSignOut);

initializeAuth();