(() => {
  "use strict";

  const routes = Object.freeze({
    dashboard: { view: "dashboard", title: "Dashboard", eyebrow: "Visão estratégica", aliases: ["", "#inicio", "#dashboard", "#/dashboard"] },
    radar: { view: "radar", title: "Radar Âncora", eyebrow: "Inteligência", aliases: ["#radar", "#/radar"] },
    oportunidades: { view: "oportunidades", title: "Oportunidades", eyebrow: "Inteligência", aliases: ["#oportunidades", "#/oportunidades"] },
    captacoes: { view: "captacoes", title: "Captações", eyebrow: "Gestão", aliases: ["#captacoes", "#/captacoes"] },
    convenios: { view: "convenios", title: "Convênios", eyebrow: "Gestão", aliases: ["#convenios", "#/convenios"] },
    agenda: { view: "agenda", title: "Agenda", eyebrow: "Gestão", aliases: ["#agenda", "#/agenda"] },
    documentos: { view: "documentos", title: "Documentos", eyebrow: "Gestão", aliases: ["#documentos", "#/documentos"] },
    "prestacao-contas": { view: "prestacao-contas", title: "Prestação de Contas", eyebrow: "Gestão", aliases: ["#prestacao-contas", "#/prestacao-contas"] },
    prefeitura: { view: "prefeitura", title: "Prefeitura", eyebrow: "Gestão municipal", aliases: ["#prefeitura", "#/prefeitura"] },
    usuarios: { view: "usuarios", title: "Usuários", eyebrow: "Gestão municipal", aliases: ["#usuarios", "#/usuarios"] },
    relatorios: { view: "relatorios", title: "Relatórios", eyebrow: "Análise", aliases: ["#relatorios", "#/relatorios"] },
    configuracoes: { view: "configuracoes", title: "Configurações", eyebrow: "Conta e plataforma", aliases: ["#configuracoes", "#/configuracoes"] },
    projetos: { view: "projects", title: "Projetos e tarefas", eyebrow: "Módulo legado", aliases: ["#projetos", "#/projetos"] },
    tarefas: { view: "projects", title: "Tarefas", eyebrow: "Módulo legado", aliases: ["#tarefas", "#/tarefas"] },
  });

  const routeByAlias = new Map();
  Object.entries(routes).forEach(([key, route]) => route.aliases.forEach((alias) => routeByAlias.set(alias, key)));

  const views = Array.from(document.querySelectorAll("[data-platform-view]"));
  const navigationLinks = Array.from(document.querySelectorAll("[data-platform-route]"));
  const pageEyebrow = document.querySelector("#page-eyebrow");
  const pageTitle = document.querySelector("#page-title");
  const environmentBadge = document.querySelector("#environment-badge");
  const sidebar = document.querySelector(".sidebar");

  function resolveRoute() {
    const routeKey = routeByAlias.get(window.location.hash || "") || "dashboard";
    return { key: routeKey, ...routes[routeKey] };
  }

  function renderEnvironmentBadge() {
    if (!environmentBadge) return;
    const state = window.APP_ENVIRONMENT;
    const isDevelopment = state?.validated && state.environment === "development";
    environmentBadge.hidden = !isDevelopment;
    environmentBadge.textContent = isDevelopment ? "● Desenvolvimento" : "";
  }

  function renderRoute() {
    const route = resolveRoute();

    views.forEach((view) => {
      const isActive = view.dataset.platformView === route.view;
      view.hidden = !isActive;
      view.classList.toggle("is-active", isActive);
    });

    navigationLinks.forEach((link) => {
      const isActive = link.dataset.platformRoute === route.key;
      link.classList.toggle("active", isActive);
      link.toggleAttribute("aria-current", isActive);
    });

    if (pageEyebrow) pageEyebrow.textContent = route.eyebrow;
    if (pageTitle) pageTitle.textContent = route.title;
    document.documentElement.dataset.platformRoute = route.key;
    document.title = `ÂNCORA — ${route.title}`;
    renderEnvironmentBadge();
  }

  navigationLinks.forEach((link) => {
    link.addEventListener("click", () => sidebar?.classList.remove("is-open"));
  });

  window.addEventListener("hashchange", renderRoute);
  window.addEventListener("app-environment-ready", renderEnvironmentBadge);
  window.PlatformNavigation = Object.freeze({ refresh: renderRoute });
  renderRoute();
})();