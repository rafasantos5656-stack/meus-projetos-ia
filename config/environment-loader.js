// Carrega a configuração permitida para a origem atual antes de qualquer request ao Supabase.
// Este arquivo não contém credenciais privadas.
(() => {
  "use strict";

  const productionOrigin = "https://rafasantos5656-stack.github.io";
  const productionPaths = new Set([
    "/meus-projetos-ia/",
    "/meus-projetos-ia/index.html",
  ]);
  const developmentOrigins = new Set([
    "http://127.0.0.1:4173",
    "http://localhost:4173",
    "http://127.0.0.1:3000",
    "http://localhost:3000",
  ]);
  const productionSupabaseHost = "abgijcibarzdcockadiv.supabase.co";
  const currentOrigin = window.location.origin;
  const currentPath = window.location.pathname;

  function identifyExpectedEnvironment() {
    if (developmentOrigins.has(currentOrigin)) return "development";

    if (currentOrigin === productionOrigin && productionPaths.has(currentPath)) {
      return "production";
    }

    return null;
  }

  function createState(environment, validated, error = "", supabaseHost = "") {
    return Object.freeze({
      environment,
      validated,
      error,
      origin: currentOrigin,
      supabaseHost,
    });
  }

  function publishState(state) {
    window.APP_ENVIRONMENT = state;
    document.documentElement.dataset.appEnvironment = state.validated
      ? state.environment
      : "blocked";
    window.dispatchEvent(new CustomEvent("app-environment-ready", { detail: state }));
    return state;
  }

  function validateConfiguration(expectedEnvironment) {
    const config = window.SUPABASE_CONFIG;
    const invalidConfigurationMessage = "A configuração deste ambiente é inválida. Nenhuma conexão com o Supabase foi iniciada.";

    if (!config || typeof config !== "object") {
      return { valid: false, error: invalidConfigurationMessage };
    }

    const environment = typeof config.environment === "string" ? config.environment.trim() : "";
    const url = typeof config.url === "string" ? config.url.trim().replace(/\/$/, "") : "";
    const anonKey = typeof config.anonKey === "string" ? config.anonKey.trim() : "";
    const hasPlaceholder = [url, anonKey].some((value) => /COLE_AQUI|SEU_PROJETO|YOUR_/i.test(value));

    if (environment !== expectedEnvironment || !url || !anonKey || hasPlaceholder) {
      return { valid: false, error: invalidConfigurationMessage };
    }

    try {
      const parsedUrl = new URL(url);
      const isSupabaseProject = parsedUrl.protocol === "https:" && parsedUrl.hostname.endsWith(".supabase.co");

      if (!isSupabaseProject) {
        return { valid: false, error: invalidConfigurationMessage };
      }

      if (expectedEnvironment === "development" && parsedUrl.hostname === productionSupabaseHost) {
        return {
          valid: false,
          error: "Proteção ativada: localhost não pode usar o Supabase de produção. Corrija a configuração DEV antes de continuar.",
        };
      }

      if (expectedEnvironment === "production" && parsedUrl.hostname !== productionSupabaseHost) {
        return {
          valid: false,
          error: "Proteção ativada: a versão pública aceita somente a configuração de produção.",
        };
      }

      window.SUPABASE_CONFIG = Object.freeze({
        environment,
        url: parsedUrl.origin,
        anonKey,
      });

      return { valid: true, supabaseHost: parsedUrl.hostname };
    } catch {
      return { valid: false, error: invalidConfigurationMessage };
    }
  }

  const expectedEnvironment = identifyExpectedEnvironment();

  window.APP_ENVIRONMENT_READY = new Promise((resolve) => {
    if (!expectedEnvironment) {
      resolve(publishState(createState(
        "blocked",
        false,
        "Esta origem não é autorizada. Nenhuma conexão com o Supabase foi iniciada.",
      )));
      return;
    }

    const configPath = expectedEnvironment === "development"
      ? "./config/supabase-config.development.local.js"
      : "./config/supabase-config.production.js";

    try {
      delete window.SUPABASE_CONFIG;
    } catch {
      window.SUPABASE_CONFIG = undefined;
    }

    const configScript = document.createElement("script");
    configScript.src = configPath;
    configScript.async = true;
    configScript.onload = () => {
      const validation = validateConfiguration(expectedEnvironment);
      resolve(publishState(createState(
        expectedEnvironment,
        validation.valid,
        validation.error,
        validation.supabaseHost,
      )));
    };
    configScript.onerror = () => {
      const missingDevMessage = expectedEnvironment === "development"
        ? "A configuração DEV local não foi encontrada. Crie config/supabase-config.development.local.js a partir do arquivo de exemplo. Nenhuma conexão com o Supabase foi iniciada."
        : "A configuração pública de produção não foi encontrada. Nenhuma conexão com o Supabase foi iniciada.";
      resolve(publishState(createState(expectedEnvironment, false, missingDevMessage)));
    };

    document.head.append(configScript);
  });
})();