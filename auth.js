// Autenticação via API pública do Supabase, sem SDK externo.
const AUTH_SESSION_STORAGE_KEY = "meus_projetos_ia_auth_session";
const supabaseAuthConfig = window.SUPABASE_CONFIG ?? {};

const authScreenElement = document.querySelector("#auth-screen");
const dashboardShellElement = document.querySelector("#dashboard-shell");
const loginFormElement = document.querySelector("#login-form");
const signupFormElement = document.querySelector("#signup-form");
const forgotPasswordFormElement = document.querySelector("#forgot-password-form");
const resetPasswordFormElement = document.querySelector("#reset-password-form");
const authMessageElement = document.querySelector("#auth-message");
const authTabsElement = document.querySelector(".auth-tabs");
const authTabElements = document.querySelectorAll(".auth-tab[data-auth-view]");
const authViewTriggerElements = document.querySelectorAll("[data-auth-view]");
const forgotPasswordButtonElement = document.querySelector("#forgot-password-button");
const cancelResetPasswordButtonElement = document.querySelector("#cancel-reset-password-button");
const signOutButtonElement = document.querySelector("#sign-out-button");
const authenticatedEmailElement = document.querySelector("#authenticated-user-email");
const userAvatarElement = document.querySelector("#user-avatar");
const appMessageElement = document.querySelector("#app-message");
const authPanelTitleElement = document.querySelector(".auth-panel-heading h2");
const authPanelDescriptionElement = document.querySelector(".auth-panel-heading p:last-child");
const profileModalElement = document.querySelector("#profile-modal");
const profilePasswordFormElement = document.querySelector("#profile-password-form");
const profileEmailElement = document.querySelector("#profile-email");
const profileMessageElement = document.querySelector("#profile-message");
const profileOpenButtonElements = document.querySelectorAll("[data-open-profile-modal], #open-profile-modal, #open-profile-from-header");
const profileCloseButtonElements = document.querySelectorAll("[data-close-profile-modal]");

let currentAuthSession = null;
let currentAuthUser = null;
let recoverySession = null;
let sessionRefreshPromise = null;
let profileModalReturnFocus = null;
let isProfilePasswordChangeRunning = false;
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
  if (normalizedMessage.includes("password should be at least")) return "A senha informada não atende aos requisitos de segurança.";
  if (normalizedMessage.includes("failed to fetch") || normalizedMessage.includes("networkerror")) return "Não foi possível conectar ao Supabase. Verifique sua internet e as credenciais públicas.";

  return message || "Não foi possível concluir a autenticação. Tente novamente.";
}

function authGetResetPasswordErrorMessage(error) {
  const message = String(error?.message ?? error ?? "").toLocaleLowerCase("pt-BR");

  if (message.includes("jwt") || message.includes("token") || message.includes("expired") || message.includes("invalid")) {
    return "Este link de recuperação expirou ou já foi utilizado. Solicite um novo link.";
  }
  if (message.includes("password")) return "A nova senha não atende aos requisitos de segurança.";
  if (message.includes("failed to fetch") || message.includes("networkerror")) {
    return "Não foi possível atualizar sua senha agora. Verifique sua conexão e tente novamente.";
  }

  return "Não foi possível atualizar sua senha. Solicite um novo link de recuperação e tente novamente.";
}

async function authRequest(path, { method = "GET", body, accessToken } = {}) {
  const { url, anonKey } = authGetSettings();
  if (!authIsConfigured()) {
    throw new Error("Configure uma Project URL e uma Publishable/Anon Public Key válidas em supabase-config.js.");
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

function authHandleExpiredSession(message = "Sua sessão expirou. Entre novamente para continuar.") {
  authClearSession();
  currentAuthSession = null;
  currentAuthUser = null;
  recoverySession = null;
  authCloseProfileModal(false);
  window.dispatchEvent(new Event("supabase-auth-signed-out"));
  authShowScreen();
  authSetView("login");
  authSetMessage(message, "info");
}

function authGetCurrentDataContext() {
  if (!currentAuthSession?.access_token || !currentAuthUser?.id) return null;

  return {
    accessToken: currentAuthSession.access_token,
    userId: currentAuthUser.id,
  };
}

async function authRefreshCurrentSession(staleAccessToken = "") {
  if (!currentAuthSession?.refresh_token || !currentAuthUser?.id) {
    authHandleExpiredSession();
    throw new Error("Sua sessão expirou. Entre novamente para continuar.");
  }

  if (staleAccessToken && currentAuthSession.access_token !== staleAccessToken) {
    return authGetCurrentDataContext();
  }

  if (!sessionRefreshPromise) {
    sessionRefreshPromise = (async () => {
      try {
        const refreshedSession = await authRefreshSession(currentAuthSession);
        const refreshedUser = await authGetUser(refreshedSession);
        if (!refreshedUser?.id || refreshedUser.id !== currentAuthUser.id) {
          throw new Error("A sessão não pertence mais ao usuário autenticado.");
        }

        currentAuthSession = refreshedSession;
        currentAuthUser = refreshedUser;
        return authGetCurrentDataContext();
      } catch {
        authHandleExpiredSession();
        throw new Error("Sua sessão expirou. Entre novamente para continuar.");
      } finally {
        sessionRefreshPromise = null;
      }
    })();
  }

  return sessionRefreshPromise;
}

async function authGetSupabaseDataContext() {
  if (!authGetCurrentDataContext()) return null;

  if (authSessionNeedsRefresh(currentAuthSession)) {
    return authRefreshCurrentSession();
  }

  return authGetCurrentDataContext();
}

function authNotifyDataLayer(user) {
  currentAuthUser = user?.id ? user : null;
  if (!currentAuthUser) return;

  window.dispatchEvent(new CustomEvent("supabase-auth-ready", {
    detail: { userId: currentAuthUser.id },
  }));
}

// A camada de dados recebe o token somente em memória, nunca por URL ou formulário.
window.getSupabaseAuthContext = authGetSupabaseDataContext;
// Reutilizada pela camada de dados após uma resposta 401; faz uma única renovação compartilhada.
window.refreshSupabaseAuthSession = authRefreshCurrentSession;

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

function authShowAppMessage(message, type = "info") {
  window.clearTimeout(appMessageTimeout);
  appMessageElement.hidden = false;
  appMessageElement.className = `app-message is-${type}`;
  appMessageElement.textContent = message;
  appMessageTimeout = window.setTimeout(() => {
    appMessageElement.hidden = true;
    appMessageElement.textContent = "";
    appMessageElement.className = "app-message";
  }, 4200);
}

window.showAppMessage = authShowAppMessage;

function authSetControlsDisabled(disabled) {
  authScreenElement.querySelectorAll("button, input").forEach((control) => {
    control.disabled = disabled;
  });
  authScreenElement.setAttribute("aria-busy", String(disabled));
}

function authSetFormLoading(formElement, isLoading, loadingLabel) {
  const submitButton = formElement?.querySelector('button[type="submit"]');
  if (!submitButton) return;

  if (isLoading) {
    submitButton.dataset.idleLabel = submitButton.textContent;
    submitButton.textContent = loadingLabel;
    submitButton.classList.add("is-loading");
    authSetControlsDisabled(true);
    return;
  }

  submitButton.textContent = submitButton.dataset.idleLabel || submitButton.textContent;
  delete submitButton.dataset.idleLabel;
  submitButton.classList.remove("is-loading");
  authSetControlsDisabled(false);
}

function authSetPanelCopy(view) {
  const viewCopy = {
    login: ["Boas-vindas", "Use seu e-mail para acessar seu painel pessoal."],
    signup: ["Crie sua conta", "Comece a organizar seus projetos em um espaço só seu."],
    recovery: ["Recuperar senha", "Enviaremos instruções para redefinir seu acesso."],
    reset: ["Definir nova senha", "Escolha uma senha segura para continuar."],
  };
  const [title, description] = viewCopy[view] || viewCopy.login;
  authPanelTitleElement.textContent = title;
  authPanelDescriptionElement.textContent = description;
}

function authSetView(view) {
  const validViews = new Set(["login", "signup", "recovery", "reset"]);
  const nextView = validViews.has(view) ? view : "login";
  const isLogin = nextView === "login";
  const isSignup = nextView === "signup";
  const isCredentialView = isLogin || isSignup;

  loginFormElement.hidden = !isLogin;
  signupFormElement.hidden = !isSignup;
  forgotPasswordFormElement.hidden = nextView !== "recovery";
  resetPasswordFormElement.hidden = nextView !== "reset";
  authTabsElement.hidden = !isCredentialView;

  authTabElements.forEach((tab) => {
    const isActive = tab.dataset.authView === nextView;
    tab.classList.toggle("is-active", isActive);
    tab.setAttribute("aria-selected", String(isActive));
    tab.tabIndex = isActive ? 0 : -1;
  });

  authSetPanelCopy(nextView);
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
  if (!user?.email) {
    authHandleExpiredSession("Não foi possível identificar a conta autenticada. Entre novamente para continuar.");
    return;
  }

  const email = user.email;
  authenticatedEmailElement.textContent = email;
  profileEmailElement.textContent = email;
  userAvatarElement.textContent = authGetAvatarLabel(email);
  authScreenElement.hidden = true;
  dashboardShellElement.hidden = false;
}

function authSetProfileMessage(message = "", type = "info") {
  if (!message) {
    profileMessageElement.hidden = true;
    profileMessageElement.textContent = "";
    profileMessageElement.className = "auth-message profile-message";
    return;
  }

  profileMessageElement.hidden = false;
  profileMessageElement.className = `auth-message profile-message is-${type}`;
  profileMessageElement.textContent = message;
}

function authSetProfilePasswordLoading(isLoading, loadingLabel = "") {
  const submitButton = profilePasswordFormElement.querySelector('button[type="submit"]');
  profilePasswordFormElement.querySelectorAll("input, button").forEach((control) => {
    control.disabled = isLoading;
  });
  profilePasswordFormElement.setAttribute("aria-busy", String(isLoading));

  if (isLoading) {
    submitButton.dataset.idleLabel = submitButton.textContent;
    submitButton.textContent = loadingLabel;
    submitButton.classList.add("is-loading");
    return;
  }

  submitButton.textContent = submitButton.dataset.idleLabel || submitButton.textContent;
  delete submitButton.dataset.idleLabel;
  submitButton.classList.remove("is-loading");
}

function authOpenProfileModal() {
  if (!currentAuthUser?.email) {
    authHandleExpiredSession();
    return;
  }

  profileModalReturnFocus = document.activeElement;
  profileEmailElement.textContent = currentAuthUser.email;
  profilePasswordFormElement.reset();
  authSetProfileMessage();
  profileModalElement.classList.add("is-visible");
  profileModalElement.setAttribute("aria-hidden", "false");
  document.body.classList.add("modal-open");
  window.setTimeout(() => profilePasswordFormElement.elements.currentPassword?.focus(), 0);
}

function authCloseProfileModal(restoreFocus = true) {
  if (!profileModalElement?.classList.contains("is-visible") || isProfilePasswordChangeRunning) return;

  profileModalElement.classList.remove("is-visible");
  profileModalElement.setAttribute("aria-hidden", "true");
  profilePasswordFormElement.reset();
  authSetProfileMessage();
  if (!document.querySelector(".modal-backdrop.is-visible")) {
    document.body.classList.remove("modal-open");
  }

  if (restoreFocus && profileModalReturnFocus instanceof HTMLElement && profileModalReturnFocus.isConnected) {
    profileModalReturnFocus.focus();
  }
  profileModalReturnFocus = null;
}

function authGetProfilePasswordErrorMessage(error) {
  const message = String(error?.message ?? error ?? "").toLocaleLowerCase("pt-BR");

  if (message.includes("invalid login credentials") || message.includes("current password")) {
    return "A senha atual está incorreta.";
  }
  if (message.includes("reauthentication") || message.includes("reauthenticate")) {
    return "Por segurança, entre novamente na sua conta antes de alterar a senha.";
  }
  if (message.includes("password")) return "A nova senha não atende aos requisitos de segurança.";
  if (message.includes("failed to fetch") || message.includes("networkerror")) {
    return "Não foi possível atualizar sua senha agora. Verifique sua conexão e tente novamente.";
  }

  return "Não foi possível atualizar sua senha. Tente novamente.";
}

async function authChangePasswordFromProfile(event) {
  event.preventDefault();
  if (isProfilePasswordChangeRunning || !profilePasswordFormElement.reportValidity()) return;

  const formData = new FormData(profilePasswordFormElement);
  const currentPassword = String(formData.get("currentPassword") ?? "");
  const newPassword = String(formData.get("newPassword") ?? "");
  const newPasswordConfirmation = String(formData.get("newPasswordConfirmation") ?? "");

  if (newPassword.length < 8) {
    authSetProfileMessage("A nova senha precisa ter pelo menos 8 caracteres.", "error");
    return;
  }
  if (newPassword !== newPasswordConfirmation) {
    authSetProfileMessage("A confirmação de senha não corresponde à nova senha informada.", "error");
    return;
  }
  if (currentPassword === newPassword) {
    authSetProfileMessage("Escolha uma nova senha diferente da senha atual.", "error");
    return;
  }
  if (!currentAuthUser?.id || !currentAuthUser.email) {
    authHandleExpiredSession();
    return;
  }

  authSetProfileMessage();
  isProfilePasswordChangeRunning = true;
  authSetProfilePasswordLoading(true, "Atualizando senha…");
  let passwordChanged = false;

  try {
    // Confirma a senha atual e cria uma sessão recente antes da alteração.
    const reauthentication = await authRequest("token?grant_type=password", {
      method: "POST",
      body: { email: currentAuthUser.email, password: currentPassword },
    });
    const refreshedSession = authSaveSession(reauthentication);
    const verifiedUser = reauthentication.user ?? await authGetUser(refreshedSession);
    if (!verifiedUser?.id || verifiedUser.id !== currentAuthUser.id) {
      throw new Error("A sessão reautenticada não corresponde à conta atual.");
    }

    currentAuthSession = refreshedSession;
    currentAuthUser = verifiedUser;
    const updatedUser = await authRequest("user", {
      method: "PUT",
      accessToken: currentAuthSession.access_token,
      body: { password: newPassword, current_password: currentPassword },
    });
    if (updatedUser?.id && updatedUser.id !== currentAuthUser.id) {
      throw new Error("A conta autenticada foi alterada durante a atualização.");
    }

    currentAuthUser = updatedUser?.id ? updatedUser : currentAuthUser;
    authShowDashboard(currentAuthUser);
    passwordChanged = true;
  } catch (error) {
    authSetProfileMessage(authGetProfilePasswordErrorMessage(error), "error");
  } finally {
    isProfilePasswordChangeRunning = false;
    authSetProfilePasswordLoading(false);
  }

  if (passwordChanged) {
    authCloseProfileModal(false);
    authShowAppMessage("Senha atualizada com sucesso.", "success");
  }
}

function authShowScreen() {
  authHideProjectModal();
  authCloseProfileModal(false);
  dashboardShellElement.hidden = true;
  authScreenElement.hidden = false;
}

function authGetRecoveryRedirectUrl() {
  const redirectUrl = new URL(window.location.href);
  if (!["http:", "https:"].includes(redirectUrl.protocol)) {
    throw new Error("Abra o projeto por um servidor local ou pelo GitHub Pages para recuperar a senha.");
  }

  redirectUrl.search = "";
  redirectUrl.hash = "";
  return redirectUrl.href;
}

function authRemoveHashFromAddressBar() {
  if (!window.location.hash) return;

  const cleanUrl = new URL(window.location.href);
  cleanUrl.hash = "";
  window.history.replaceState(null, document.title, `${cleanUrl.pathname}${cleanUrl.search}`);
}

function authConsumeRecoveryCallback() {
  const hash = window.location.hash.startsWith("#") ? window.location.hash.slice(1) : "";
  if (!hash) return null;

  const parameters = new URLSearchParams(hash);
  const type = parameters.get("type");
  const isRecovery = type === "recovery";
  const hasCallbackError = parameters.has("error") || parameters.has("error_code");

  if (!isRecovery && !hasCallbackError) return null;

  authRemoveHashFromAddressBar();

  if (!isRecovery || hasCallbackError) {
    return {
      mode: "error",
      message: "Este link de recuperação expirou, já foi utilizado ou não é válido. Solicite um novo link.",
    };
  }

  const accessToken = parameters.get("access_token");
  if (!accessToken) {
    return {
      mode: "error",
      message: "Não foi possível validar o link de recuperação. Solicite um novo link.",
    };
  }

  const expiresAt = Number(parameters.get("expires_at"));
  return {
    mode: "reset",
    session: {
      accessToken,
      expiresAt: Number.isFinite(expiresAt) && expiresAt > 0
        ? expiresAt
        : Math.floor(Date.now() / 1000) + 3600,
    },
  };
}

function authStartRecoveryMode(session) {
  // A sessão do link não é persistida: ela existe apenas enquanto esta página estiver aberta.
  recoverySession = session;
  authClearSession();
  currentAuthSession = null;
  currentAuthUser = null;
  window.dispatchEvent(new Event("supabase-auth-signed-out"));
  authShowScreen();
  authSetView("reset");
  authSetMessage("Crie uma nova senha com pelo menos 8 caracteres.", "info");
  window.setTimeout(() => resetPasswordFormElement.elements.password?.focus(), 0);
}

function authExitRecoveryMode(message = "", type = "info") {
  recoverySession = null;
  authClearSession();
  currentAuthSession = null;
  currentAuthUser = null;
  resetPasswordFormElement.reset();
  authShowScreen();
  authSetView("login");
  if (message) authSetMessage(message, type);
}

function authRecoverySessionIsValid() {
  return Boolean(
    recoverySession?.accessToken
    && recoverySession.expiresAt > Math.floor(Date.now() / 1000) + 5,
  );
}

async function initializeAuth() {
  const recoveryCallback = authConsumeRecoveryCallback();
  authSetView("login");

  if (!authIsConfigured()) {
    authShowScreen();
    authSetControlsDisabled(true);
    authSetMessage("Configure uma Project URL e uma Publishable/Anon Public Key válidas em supabase-config.js para habilitar o acesso.", "info");
    return;
  }

  if (recoveryCallback?.mode === "reset") {
    authStartRecoveryMode(recoveryCallback.session);
    return;
  }

  if (recoveryCallback?.mode === "error") {
    authShowScreen();
    authSetMessage(recoveryCallback.message, "error");
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
    authNotifyDataLayer(user);
    authShowDashboard(user);
  } catch {
    authHandleExpiredSession();
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
  authSetFormLoading(loginFormElement, true, "Entrando…");

  try {
    const response = await authRequest("token?grant_type=password", {
      method: "POST",
      body: { email, password },
    });
    currentAuthSession = authSaveSession(response);
    const user = response.user ?? await authGetUser(currentAuthSession);
    authNotifyDataLayer(user);
    loginFormElement.reset();
    authShowDashboard(user);
    authShowAppMessage("Login realizado com sucesso.", "success");
  } catch (error) {
    authSetMessage(authGetErrorMessage(error), "error");
  } finally {
    authSetFormLoading(loginFormElement, false);
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
  authSetFormLoading(signupFormElement, true, "Criando conta…");
  try {
    const response = await authRequest("signup", {
      method: "POST",
      body: { email, password },
    });
    const session = response.session ?? response;
    signupFormElement.reset();

    if (session?.access_token && session?.refresh_token) {
      currentAuthSession = authSaveSession(session);
      const user = response.user ?? await authGetUser(currentAuthSession);
      authNotifyDataLayer(user);
      authShowDashboard(user);
      authShowAppMessage("Conta criada com sucesso.", "success");
      return;
    }

    authSetView("login");
    loginFormElement.elements.email.value = email;
    authSetMessage("Conta criada. Verifique seu e-mail para confirmar o cadastro antes de entrar.", "success");
  } catch (error) {
    authSetMessage(authGetErrorMessage(error), "error");
  } finally {
    authSetFormLoading(signupFormElement, false);
  }
}

async function authRequestPasswordRecovery(event) {
  event.preventDefault();
  if (!forgotPasswordFormElement.reportValidity()) return;

  const formData = new FormData(forgotPasswordFormElement);
  const email = String(formData.get("email") ?? "").trim();
  const genericMessage = "Se houver uma conta associada a este e-mail, enviaremos as instruções para redefinir sua senha.";
  authSetMessage();
  authSetFormLoading(forgotPasswordFormElement, true, "Enviando instruções…");

  try {
    await authRequest("recover", {
      method: "POST",
      body: {
        email,
        redirect_to: authGetRecoveryRedirectUrl(),
      },
    });
  } catch (error) {
    // A resposta permanece genérica para não revelar se um e-mail possui cadastro.
  } finally {
    forgotPasswordFormElement.reset();
    authSetFormLoading(forgotPasswordFormElement, false);
    authSetMessage(genericMessage, "success");
  }
}

async function authResetPassword(event) {
  event.preventDefault();
  if (!resetPasswordFormElement.reportValidity()) return;

  const formData = new FormData(resetPasswordFormElement);
  const password = String(formData.get("password") ?? "");
  const passwordConfirmation = String(formData.get("passwordConfirmation") ?? "");

  if (password.length < 8) {
    authSetMessage("A nova senha precisa ter pelo menos 8 caracteres.", "error");
    return;
  }
  if (password !== passwordConfirmation) {
    authSetMessage("A confirmação de senha não corresponde à nova senha informada.", "error");
    return;
  }
  if (!authRecoverySessionIsValid()) {
    authExitRecoveryMode("Este link de recuperação expirou ou já foi utilizado. Solicite um novo link.", "error");
    return;
  }

  authSetMessage();
  authSetFormLoading(resetPasswordFormElement, true, "Salvando nova senha…");
  try {
    await authRequest("user", {
      method: "PUT",
      accessToken: recoverySession.accessToken,
      body: { password },
    });
    authExitRecoveryMode("Senha atualizada com sucesso. Entre com sua nova senha.", "success");
  } catch (error) {
    authSetMessage(authGetResetPasswordErrorMessage(error), "error");
  } finally {
    authSetFormLoading(resetPasswordFormElement, false);
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
    currentAuthUser = null;
    recoverySession = null;
    authCloseProfileModal(false);
    window.dispatchEvent(new Event("supabase-auth-signed-out"));
    signOutButtonElement.disabled = false;
    authShowScreen();
    authSetView("login");
    authSetMessage("Você saiu da sua conta com segurança.", "success");
  }
}

authViewTriggerElements.forEach((trigger) => {
  trigger.addEventListener("click", () => authSetView(trigger.dataset.authView));
});

forgotPasswordButtonElement.addEventListener("click", () => authSetView("recovery"));
cancelResetPasswordButtonElement.addEventListener("click", () => {
  authExitRecoveryMode("A recuperação foi cancelada. Você pode entrar normalmente.", "info");
});
loginFormElement.addEventListener("submit", authSignIn);
signupFormElement.addEventListener("submit", authSignUp);
forgotPasswordFormElement.addEventListener("submit", authRequestPasswordRecovery);
resetPasswordFormElement.addEventListener("submit", authResetPassword);
profileOpenButtonElements.forEach((button) => button.addEventListener("click", authOpenProfileModal));
profileCloseButtonElements.forEach((button) => button.addEventListener("click", () => authCloseProfileModal()));
profileModalElement.addEventListener("click", (event) => {
  if (event.target === profileModalElement) authCloseProfileModal();
});
profilePasswordFormElement.addEventListener("submit", authChangePasswordFromProfile);
signOutButtonElement.addEventListener("click", authSignOut);

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && profileModalElement.classList.contains("is-visible")) {
    event.preventDefault();
    authCloseProfileModal();
  }
});

initializeAuth();