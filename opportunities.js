(() => {
  "use strict";

  const elements = {
    page: document.querySelector("#oportunidades"),
    form: document.querySelector("#opportunities-filters"),
    search: document.querySelector("#opportunities-search"),
    sphere: document.querySelector("#opportunities-sphere"),
    area: document.querySelector("#opportunities-area"),
    status: document.querySelector("#opportunities-status"),
    deadline: document.querySelector("#opportunities-deadline"),
    uf: document.querySelector("#opportunities-uf"),
    clear: document.querySelector("#opportunities-clear-filters"),
    coverageNote: document.querySelector("#opportunities-coverage-note"),
    municipalityContext: document.querySelector("#opportunities-municipality-context"),
    municipalityContextName: document.querySelector("#opportunities-municipality-context-name"),
    summaryScope: document.querySelector("#opportunities-summary-scope"),
    openCount: document.querySelector("#opportunities-open-count"),
    openMeta: document.querySelector("#opportunities-open-meta"),
    closingCount: document.querySelector("#opportunities-closing-count"),
    closingMeta: document.querySelector("#opportunities-closing-meta"),
    amountCount: document.querySelector("#opportunities-amount-count"),
    amountMeta: document.querySelector("#opportunities-amount-meta"),
    recentCount: document.querySelector("#opportunities-recent-count"),
    recentMeta: document.querySelector("#opportunities-recent-meta"),
    resultsRegion: document.querySelector("#opportunities-results-region"),
    resultsSummary: document.querySelector("#opportunities-results-summary"),
    loading: document.querySelector("#opportunities-loading"),
    error: document.querySelector("#opportunities-error"),
    retry: document.querySelector("#opportunities-retry"),
    empty: document.querySelector("#opportunities-empty"),
    list: document.querySelector("#opportunities-list"),
    pagination: document.querySelector("#opportunities-pagination"),
    previous: document.querySelector("#opportunities-previous-page"),
    page: document.querySelector("#opportunities-page-indicator"),
    next: document.querySelector("#opportunities-next-page")
  };

  if (Object.values(elements).some(function (element) { return !element; })) return;

  const PAGE_SIZE = 20;
  const SEARCH_DELAY = 300;
  const validSpheres = new Set(["federal", "state", "municipal", "other"]);
  const validStatuses = new Set(["upcoming", "open", "closed", "suspended", "cancelled", "archived"]);
  const validDeadlines = new Set(["no_deadline", "closed", "today", "within_3", "within_7", "within_15", "more_than_15"]);
  const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const CIVIL_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
  const state = {
    requestVersion: 0,
    page: 1,
    pageSize: PAGE_SIZE,
    hasNextPage: false,
    focusResults: false,
    filters: { search: "", sphere: "", area: "", status: "", deadline: "", uf: "" },
    policyAreas: [],
    searchTimer: 0,
    activeMunicipalityId: ""
  };

  function renderActiveMunicipalityContext() {
    const municipality = typeof window.getActiveMunicipalityContext === "function"
      ? window.getActiveMunicipalityContext()
      : null;

    if (!municipality || !municipality.id) {
      state.activeMunicipalityId = "";
      elements.municipalityContextName.textContent = "—";
      elements.municipalityContext.hidden = true;
      return null;
    }

    state.activeMunicipalityId = String(municipality.id);

    const municipalityName = String(municipality.name || "").trim();
    const municipalityState = String(municipality.state || "").trim().toUpperCase();

    elements.municipalityContextName.textContent =
      municipalityName && municipalityState
        ? municipalityName + " — " + municipalityState
        : municipalityName || municipalityState || "Prefeitura selecionada";

    elements.municipalityContext.hidden = false;

    return municipality;
  }

  function isOpportunitiesRoute() {
    return window.location.hash === "#oportunidades" || window.location.hash === "#/oportunidades";
  }

  function isCurrentRequest(version) {
    return isOpportunitiesRoute() && version === state.requestVersion;
  }

  function createRequestError(message, status) {
    const error = new Error(message);
    error.status = status || 0;
    return error;
  }

  function getEnvironmentSettings() {
    const config = window.SUPABASE_CONFIG || {};
    const url = typeof config.url === "string" ? config.url.trim().replace(/\/$/, "") : "";
    const anonKey = typeof config.anonKey === "string" ? config.anonKey.trim() : "";
    if (!url || !anonKey) throw createRequestError("O ambiente não está pronto para a consulta.");
    return { url: url, anonKey: anonKey };
  }

  async function getAuthenticatedContext() {
    if (typeof window.getSupabaseAuthContext !== "function") {
      throw createRequestError("A sessão ainda não está disponível.", 401);
    }
    const context = await window.getSupabaseAuthContext();
    if (!context || !context.accessToken || !context.userId) {
      throw createRequestError("Sua sessão expirou. Entre novamente para continuar.", 401);
    }
    return context;
  }

  async function opportunityRequest(path, context, options) {
    const settings = getEnvironmentSettings();
    const requestOptions = options || {};
    const headers = {
      apikey: settings.anonKey,
      Authorization: "Bearer " + context.accessToken
    };
    if (requestOptions.count) headers.Prefer = "count=exact";
    if (requestOptions.range) headers.Range = requestOptions.range;
    let response;
    try {
      response = await fetch(settings.url + "/rest/v1/" + path, {
        method: "GET",
        headers: headers
      });
    } catch (error) {
      throw createRequestError("Não foi possível conectar ao catálogo de oportunidades.");
    }

    if (response.status === 401 && !requestOptions.retried && typeof window.refreshSupabaseAuthSession === "function") {
      const refreshed = await window.refreshSupabaseAuthSession(context.accessToken);
      if (refreshed && refreshed.accessToken && refreshed.userId) {
        return opportunityRequest(path, refreshed, Object.assign({}, requestOptions, { retried: true }));
      }
    }

    const text = await response.text();
    let payload = null;
    try {
      payload = text ? JSON.parse(text) : null;
    } catch (error) {
      payload = null;
    }
    if (!response.ok) {
      throw createRequestError(
        payload && (payload.message || payload.error) ? (payload.message || payload.error) : "Não foi possível consultar o catálogo.",
        response.status
      );
    }
    return { rows: Array.isArray(payload) ? payload : [], response: response };
  }

  async function opportunityWriteRequest(path, context, options) {
    const settings = getEnvironmentSettings();
    const requestOptions = options || {};
    const method = requestOptions.method || "POST";
    const headers = {
      apikey: settings.anonKey,
      Authorization: "Bearer " + context.accessToken,
      "Content-Type": "application/json"
    };

    if (requestOptions.prefer) {
      headers.Prefer = requestOptions.prefer;
    }

    let response;
    try {
      response = await fetch(settings.url + "/rest/v1/" + path, {
        method: method,
        headers: headers,
        body: JSON.stringify(requestOptions.body || {})
      });
    } catch (error) {
      throw createRequestError("Não foi possível conectar ao Supabase.");
    }

    if (
      response.status === 401 &&
      !requestOptions.retried &&
      typeof window.refreshSupabaseAuthSession === "function"
    ) {
      const refreshed = await window.refreshSupabaseAuthSession(context.accessToken);
      if (refreshed && refreshed.accessToken && refreshed.userId) {
        return opportunityWriteRequest(
          path,
          refreshed,
          Object.assign({}, requestOptions, { retried: true })
        );
      }
    }

    const text = await response.text();
    let payload = null;
    try {
      payload = text ? JSON.parse(text) : null;
    } catch (error) {
      payload = null;
    }

    if (!response.ok) {
      throw createRequestError(
        payload && (payload.message || payload.error)
          ? (payload.message || payload.error)
          : "Não foi possível atualizar a oportunidade para esta Prefeitura.",
        response.status
      );
    }

    return {
      rows: Array.isArray(payload) ? payload : [],
      response: response
    };
  }

  async function loadMunicipalityOpportunityRelations(context, municipalityId, opportunityIds) {
    if (!municipalityId || !Array.isArray(opportunityIds) || opportunityIds.length === 0) {
      return new Map();
    }

    const uniqueOpportunityIds = Array.from(new Set(opportunityIds.filter(Boolean)));
    if (uniqueOpportunityIds.length === 0) return new Map();

    const params = new URLSearchParams();
    params.set("select", "id,municipality_id,opportunity_id,status,notes,created_at,updated_at");
    params.set("municipality_id", "eq." + municipalityId);
    params.set("opportunity_id", "in.(" + uniqueOpportunityIds.join(",") + ")");

    const result = await opportunityRequest(
      "municipality_opportunities?" + params.toString(),
      context
    );

    return new Map(result.rows.map(function (relation) {
      return [relation.opportunity_id, relation];
    }));
  }

  async function saveMunicipalityOpportunityRelation(
    context,
    municipalityId,
    opportunityId,
    status,
    notes,
    existingRelation
  ) {
    const validMunicipalityStatuses = new Set([
      "analyzing",
      "interested",
      "review_later",
      "not_applicable"
    ]);

    if (!municipalityId || !opportunityId) {
      throw createRequestError("Prefeitura ou oportunidade não identificada.");
    }

    if (!validMunicipalityStatuses.has(status)) {
      throw createRequestError("Status municipal inválido.");
    }

    const normalizedNotes = String(notes || "").trim();
    if (normalizedNotes.length > 4000) {
      throw createRequestError("As observações devem ter no máximo 4000 caracteres.");
    }

    const notesValue = normalizedNotes || null;

    if (existingRelation && existingRelation.id) {
      const params = new URLSearchParams();
      params.set("id", "eq." + existingRelation.id);
      params.set("select", "id,municipality_id,opportunity_id,status,notes,created_at,updated_at");

      const result = await opportunityWriteRequest(
        "municipality_opportunities?" + params.toString(),
        context,
        {
          method: "PATCH",
          prefer: "return=representation",
          body: {
            status: status,
            notes: notesValue
          }
        }
      );

      if (result.rows.length !== 1) {
        throw createRequestError("Não foi possível confirmar a atualização da oportunidade.");
      }

      return result.rows[0];
    }

    const params = new URLSearchParams();
    params.set("select", "id,municipality_id,opportunity_id,status,notes,created_at,updated_at");

    const result = await opportunityWriteRequest(
      "municipality_opportunities?" + params.toString(),
      context,
      {
        method: "POST",
        prefer: "return=representation",
        body: {
          municipality_id: municipalityId,
          opportunity_id: opportunityId,
          status: status,
          notes: notesValue
        }
      }
    );

    if (result.rows.length !== 1) {
      throw createRequestError("Não foi possível confirmar o registro da oportunidade.");
    }

    return result.rows[0];
  }

  function normalizeSearch(value) {
    return String(value || "")
      .normalize("NFC")
      .replace(/[^\p{L}\p{N}\s-]/gu, " ")
      .replace(/\s+/g, " ")
      .trim()
      .slice(0, 120);
  }

  function getCivilToday() {
    const date = new Date();
    return String(date.getFullYear()) + "-" +
      String(date.getMonth() + 1).padStart(2, "0") + "-" +
      String(date.getDate()).padStart(2, "0");
  }

  function addCivilDays(civilDate, days) {
    const parts = civilDate.split("-").map(Number);
    const date = new Date(parts[0], parts[1] - 1, parts[2], 12);
    date.setDate(date.getDate() + days);
    return String(date.getFullYear()) + "-" +
      String(date.getMonth() + 1).padStart(2, "0") + "-" +
      String(date.getDate()).padStart(2, "0");
  }

  function parseCivilDate(value) {
    if (!CIVIL_DATE_PATTERN.test(String(value || ""))) return null;
    const parts = String(value).split("-").map(Number);
    const date = new Date(parts[0], parts[1] - 1, parts[2], 12);
    if (date.getFullYear() !== parts[0] || date.getMonth() !== parts[1] - 1 || date.getDate() !== parts[2]) return null;
    return date;
  }

  function formatCivilDate(value) {
    const date = parseCivilDate(value);
    return date
      ? new Intl.DateTimeFormat("pt-BR", { dateStyle: "medium" }).format(date)
      : "Não informado";
  }

  function normalizeFilters() {
    return {
      search: normalizeSearch(elements.search.value),
      sphere: validSpheres.has(elements.sphere.value) ? elements.sphere.value : "",
      area: UUID_PATTERN.test(elements.area.value) ? elements.area.value : "",
      status: validStatuses.has(elements.status.value) ? elements.status.value : "",
      deadline: validDeadlines.has(elements.deadline.value) ? elements.deadline.value : "",
      uf: /^[A-Z]{2}$/.test(elements.uf.value) ? elements.uf.value : ""
    };
  }

  function hasActiveFilters(filters) {
    return Object.values(filters).some(Boolean);
  }

  function appendDeadlineFilter(params, deadline) {
    if (!deadline) return;
    const today = getCivilToday();
    if (deadline === "no_deadline") params.append("closes_on", "is.null");
    if (deadline === "closed") params.append("closes_on", "lt." + today);
    if (deadline === "today") params.append("closes_on", "eq." + today);
    if (deadline === "within_3") {
      params.append("closes_on", "gte." + addCivilDays(today, 1));
      params.append("closes_on", "lte." + addCivilDays(today, 3));
    }
    if (deadline === "within_7") {
      params.append("closes_on", "gte." + addCivilDays(today, 4));
      params.append("closes_on", "lte." + addCivilDays(today, 7));
    }
    if (deadline === "within_15") {
      params.append("closes_on", "gte." + addCivilDays(today, 8));
      params.append("closes_on", "lte." + addCivilDays(today, 15));
    }
    if (deadline === "more_than_15") params.append("closes_on", "gt." + addCivilDays(today, 15));
  }

  function appendBaseFilters(params, filters) {
    params.append("is_published", "eq.true");
    if (filters.sphere) params.append("sphere", "eq." + filters.sphere);
    if (filters.status) params.append("status", "eq." + filters.status);
    appendDeadlineFilter(params, filters.deadline);

    const groups = [];
    if (filters.uf) {
      groups.push(
        "coverage_type.eq.national,and(coverage_type.eq.selected_ufs,eligible_ufs.cs.{" + filters.uf + "})"
      );
    }
    if (filters.search) {
      const term = "*" + filters.search + "*";
      groups.push(
        "title.ilike." + term +
        ",program_name.ilike." + term +
        ",granting_body.ilike." + term +
        ",description.ilike." + term
      );
    }
    if (groups.length === 1) {
      params.append("or", "(" + groups[0] + ")");
    }
    if (groups.length === 2) {
      params.append("and", "(or(" + groups[0] + "),or(" + groups[1] + "))");
    }
  }

  function relationshipSelect(useInner) {
    return (useInner ? "opportunity_policy_areas!inner" : "opportunity_policy_areas") +
      "(policy_area_id,policy_area:policy_areas(id,code,name,status))";
  }

  function buildOpportunitiesUrl(filters, options) {
    const settings = options || {};
    const params = new URLSearchParams();
    const areaFiltered = Boolean(filters.area);
    const select = settings.count
      ? (areaFiltered ? "id," + relationshipSelect(true) : "id")
      : [
          "id",
          "external_id",
          "sphere",
          "granting_body",
          "program_name",
          "title",
          "description",
          "eligibility_summary",
          "coverage_type",
          "eligible_ufs",
          "amount",
          "amount_kind",
          "opens_on",
          "closes_on",
          "status",
          "official_url",
          "source_updated_at",
          "last_checked_at",
          "updated_at",
          "source:opportunity_sources(id,code,name,sphere,official_base_url)",
          relationshipSelect(areaFiltered)
        ].join(",");

    params.set("select", select);
    appendBaseFilters(params, filters);
    if (filters.area) params.append("opportunity_policy_areas.policy_area_id", "eq." + filters.area);
    if (settings.amountKnown) params.append("amount", "not.is.null");
    if (settings.closesOnOrAfter) params.append("closes_on", "gte." + settings.closesOnOrAfter);
    if (settings.closesOnOrBefore) params.append("closes_on", "lte." + settings.closesOnOrBefore);
    if (settings.sourceUpdatedAfter) params.append("source_updated_at", "gte." + settings.sourceUpdatedAfter);
    if (settings.sourceUpdatedIsNull) params.append("source_updated_at", "is.null");
    if (settings.lastCheckedAfter) params.append("last_checked_at", "gte." + settings.lastCheckedAfter);

    if (!settings.count) {
      params.set("order", "closes_on.asc.nullslast,updated_at.desc");
      params.set("limit", String(settings.limit || PAGE_SIZE));
      params.set("offset", String(settings.offset || 0));
    }
    return "opportunities?" + params.toString();
  }

  function countFromResponse(response) {
    const contentRange = response.headers.get("content-range") || "";
    const match = /\/(\d+)$/.exec(contentRange);
    return match ? Number(match[1]) : null;
  }

  async function countOpportunities(context, filters, options) {
    const result = await opportunityRequest(
      buildOpportunitiesUrl(filters, Object.assign({ count: true }, options || {})),
      context,
      { count: true, range: "0-0" }
    );
    return countFromResponse(result.response);
  }

  function setMetric(valueElement, metaElement, value, label) {
    valueElement.textContent = value === null || value === undefined ? "—" : String(value);
    metaElement.textContent = value === null || value === undefined
      ? "Não foi possível calcular agora."
      : (value === 1 ? "1 " + label.replace(/s$/, "") : String(value) + " " + label);
  }

  function resetMetrics() {
    setMetric(elements.openCount, elements.openMeta, null, "");
    setMetric(elements.closingCount, elements.closingMeta, null, "");
    setMetric(elements.amountCount, elements.amountMeta, null, "");
    setMetric(elements.recentCount, elements.recentMeta, null, "");
  }

  function setLoading(isLoading) {
    elements.loading.hidden = !isLoading;
    elements.resultsRegion.setAttribute("aria-busy", isLoading ? "true" : "false");
  }

  function setError(message) {
    const hasError = Boolean(message);
    elements.error.textContent = message || "";
    elements.error.hidden = !hasError;
    elements.retry.hidden = !hasError;
  }

  function setEmpty(isEmpty, message) {
    elements.empty.textContent = message || "Nenhuma oportunidade encontrada.";
    elements.empty.hidden = !isEmpty;
  }

  function updateFilterFeedback(filters) {
    elements.clear.hidden = !hasActiveFilters(filters);
    elements.coverageNote.hidden = false;
    elements.coverageNote.textContent = filters.uf
      ? "Com a UF " + filters.uf + " selecionada, a busca considera apenas oportunidades nacionais ou que incluam explicitamente essa UF. Regras territoriais específicas exigem análise própria."
      : "Sem UF selecionada, o catálogo apresenta oportunidades publicadas conforme a abrangência cadastrada.";
    elements.summaryScope.textContent = hasActiveFilters(filters)
      ? "Contagens atualizadas conforme os filtros ativos"
      : "Contagens do catálogo público publicado";
  }

  function populatePolicyAreas() {
    const selected = state.filters.area;
    elements.area.innerHTML = "";
    const defaultOption = document.createElement("option");
    defaultOption.value = "";
    defaultOption.textContent = "Todas as áreas";
    elements.area.appendChild(defaultOption);

    state.policyAreas.forEach(function (area) {
      const option = document.createElement("option");
      option.value = area.id;
      option.textContent = area.name;
      elements.area.appendChild(option);
    });
    elements.area.value = state.policyAreas.some(function (area) {
      return area.id === selected;
    }) ? selected : "";
    state.filters.area = elements.area.value;
  }

  async function loadPolicyAreas(context, version) {
    elements.area.disabled = true;
    try {
      const result = await opportunityRequest(
        "policy_areas?select=id,code,name,status&status=eq.active&order=name.asc",
        context
      );
      if (!isCurrentRequest(version)) return;
      state.policyAreas = result.rows.filter(function (area) {
        return area && UUID_PATTERN.test(area.id) && typeof area.name === "string";
      });
      populatePolicyAreas();
      elements.area.disabled = false;
    } catch (error) {
      if (!isCurrentRequest(version)) return;
      state.policyAreas = [];
      elements.area.innerHTML = "";
      const option = document.createElement("option");
      option.value = "";
      option.textContent = "Áreas indisponíveis";
      elements.area.appendChild(option);
      elements.area.disabled = true;
    }
  }

  async function loadSummary(context, filters, version) {
    const today = getCivilToday();
    const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
    const canBeOpen = !filters.status || filters.status === "open";
    const openFilters = Object.assign({}, filters, { status: "open" });
    const results = await Promise.allSettled([
      canBeOpen ? countOpportunities(context, openFilters) : Promise.resolve(0),
      canBeOpen ? countOpportunities(context, openFilters, {
        closesOnOrAfter: today,
        closesOnOrBefore: addCivilDays(today, 7)
      }) : Promise.resolve(0),
      countOpportunities(context, filters, { amountKnown: true }),
      countOpportunities(context, filters, { sourceUpdatedAfter: cutoff }),
      countOpportunities(context, filters, {
        sourceUpdatedIsNull: true,
        lastCheckedAfter: cutoff
      })
    ]);

    if (!isCurrentRequest(version)) return;
    const valueOrNull = function (result) {
      return result.status === "fulfilled" && Number.isInteger(result.value) ? result.value : null;
    };
    const sourceRecent = valueOrNull(results[3]);
    const fallbackRecent = valueOrNull(results[4]);
    setMetric(elements.openCount, elements.openMeta, valueOrNull(results[0]), "oportunidades abertas");
    setMetric(elements.closingCount, elements.closingMeta, valueOrNull(results[1]), "com prazo em até 7 dias");
    setMetric(elements.amountCount, elements.amountMeta, valueOrNull(results[2]), "com recursos informados");
    setMetric(
      elements.recentCount,
      elements.recentMeta,
      sourceRecent === null || fallbackRecent === null ? null : sourceRecent + fallbackRecent,
      "atualizadas nos últimos 30 dias"
    );
  }

  function createElement(tagName, className, text) {
    const element = document.createElement(tagName);
    if (className) element.className = className;
    if (text !== undefined && text !== null) element.textContent = text;
    return element;
  }

  function appendMeta(container, label, value) {
    const item = createElement("div", "opportunity-meta-item");
    item.appendChild(createElement("span", "opportunity-meta-label", label));
    item.appendChild(createElement("span", "opportunity-meta-value", value || "Não informado"));
    container.appendChild(item);
  }

  function formatStatus(status) {
    const labels = {
      upcoming: "Em breve",
      open: "Aberta",
      closed: "Encerrada",
      suspended: "Suspensa",
      cancelled: "Cancelada",
      archived: "Arquivada"
    };
    return labels[status] || "Não informado";
  }

  function formatMunicipalityOpportunityStatus(status) {
    const labels = {
      analyzing: "Em análise",
      interested: "Interessada",
      review_later: "Revisar depois",
      not_applicable: "Não se aplica"
    };

    return labels[status] || "Ainda não analisada";
  }

  function formatAmount(amount, kind) {
    if (amount === null || amount === undefined || amount === "") return "Não informado";
    const number = Number(amount);
    if (!Number.isFinite(number)) return "Não informado";
    const label = {
      total_available: "Recursos disponíveis",
      maximum_per_proposal: "Máximo por proposta",
      minimum_per_proposal: "Mínimo por proposta",
      other: "Valor informado"
    }[kind] || "Valor informado (natureza não especificada)";
    const value = new Intl.NumberFormat("pt-BR", {
      style: "currency",
      currency: "BRL",
      maximumFractionDigits: 2
    }).format(number);
    return (label ? label + ": " : "") + value;
  }

  function formatCoverage(opportunity) {
    if (opportunity.coverage_type === "national") return "Nacional";
    if (opportunity.coverage_type === "selected_ufs") {
      return Array.isArray(opportunity.eligible_ufs) && opportunity.eligible_ufs.length
        ? "UFs: " + opportunity.eligible_ufs.join(", ")
        : "UFs selecionadas";
    }
    if (opportunity.coverage_type === "territorial_rule") return "Regra territorial";
    return "Cobertura não informada";
  }

  function classifyDeadline(value) {
    const deadline = parseCivilDate(value);
    if (!deadline) return { label: "Sem prazo informado", tone: "neutral" };
    const today = parseCivilDate(getCivilToday());
    const days = Math.round((deadline.getTime() - today.getTime()) / 86400000);
    if (days < 0) return { label: "Prazo encerrado", tone: "critical" };
    if (days === 0) return { label: "Encerra hoje", tone: "critical" };
    if (days <= 3) return { label: "Até 3 dias", tone: "warning" };
    if (days <= 7) return { label: "Até 7 dias", tone: "warning" };
    if (days <= 15) return { label: "Até 15 dias", tone: "positive" };
    return { label: "Mais de 15 dias", tone: "positive" };
  }

  function activePolicyAreas(rawItems) {
    if (!Array.isArray(rawItems)) return [];
    return rawItems.map(function (item) {
      return item && item.policy_area ? item.policy_area : null;
    }).filter(function (area) {
      return area && area.status === "active" && typeof area.name === "string";
    });
  }

  function isSafeOfficialUrl(value) {
    try {
      const url = new URL(value);
      return url.protocol === "https:" || url.protocol === "http:";
    } catch (error) {
      return false;
    }
  }

  function createMunicipalityOpportunityControls(opportunity, municipalityRelation) {
    const controls = createElement("div", "opportunity-municipality-controls");

    const fields = createElement("div", "opportunity-municipality-fields");

    const statusField = createElement("label", "opportunity-municipality-field");
    statusField.appendChild(createElement(
      "span",
      "opportunity-municipality-field-label",
      "Status"
    ));

    const statusSelect = document.createElement("select");
    statusSelect.className = "opportunity-municipality-select";
    statusSelect.setAttribute("aria-label", "Status da oportunidade para a Prefeitura");

    [
      ["", "Selecione uma situação"],
      ["analyzing", "Em análise"],
      ["interested", "Interessada"],
      ["review_later", "Revisar depois"],
      ["not_applicable", "Não se aplica"]
    ].forEach(function (item) {
      const option = document.createElement("option");
      option.value = item[0];
      option.textContent = item[1];
      statusSelect.appendChild(option);
    });

    statusSelect.value = municipalityRelation?.status || "";
    statusField.appendChild(statusSelect);

    const notesField = createElement(
      "label",
      "opportunity-municipality-field opportunity-municipality-notes-field"
    );
    notesField.appendChild(createElement(
      "span",
      "opportunity-municipality-field-label",
      "Observações"
    ));

    const notesInput = document.createElement("textarea");
    notesInput.className = "opportunity-municipality-notes";
    notesInput.rows = 2;
    notesInput.maxLength = 4000;
    notesInput.placeholder = "Registre observações internas sobre esta oportunidade.";
    notesInput.value = municipalityRelation?.notes || "";
    notesField.appendChild(notesInput);

    fields.appendChild(statusField);
    fields.appendChild(notesField);
    controls.appendChild(fields);

    const actions = createElement("div", "opportunity-municipality-actions");
    const feedback = createElement("span", "opportunity-municipality-feedback", "");
    feedback.setAttribute("aria-live", "polite");

    const saveButton = createElement(
      "button",
      "opportunity-municipality-save",
      municipalityRelation ? "Salvar alterações" : "Registrar análise"
    );
    saveButton.type = "button";

    saveButton.addEventListener("click", async function () {
      const municipality = typeof window.getActiveMunicipalityContext === "function"
        ? window.getActiveMunicipalityContext()
        : null;

      if (!municipality?.id || String(municipality.id) !== state.activeMunicipalityId) {
        feedback.textContent = "O contexto da Prefeitura mudou. Atualize a página e tente novamente.";
        return;
      }

      if (!statusSelect.value) {
        feedback.textContent = "Selecione uma situação antes de salvar.";
        statusSelect.focus();
        return;
      }

      saveButton.disabled = true;
      statusSelect.disabled = true;
      notesInput.disabled = true;
      feedback.textContent = "Salvando...";

      try {
        const context = await getAuthenticatedContext();
        const savedRelation = await saveMunicipalityOpportunityRelation(
          context,
          municipality.id,
          opportunity.id,
          statusSelect.value,
          notesInput.value,
          municipalityRelation
        );

        opportunity.municipalityOpportunity = savedRelation;
        feedback.textContent = "Análise salva com sucesso.";
        saveButton.textContent = "Salvar alterações";

        window.setTimeout(function () {
          if (isOpportunitiesRoute()) {
            refreshCatalog({ resetPage: false });
          }
        }, 350);
      } catch (error) {
        if (error?.status === 401) {
          feedback.textContent = "Sua sessão precisa ser atualizada.";
        } else if (error?.status === 403) {
          feedback.textContent = "Seu perfil pode consultar, mas não alterar esta análise.";
        } else {
          feedback.textContent = error?.message || "Não foi possível salvar a análise.";
        }
      } finally {
        saveButton.disabled = false;
        statusSelect.disabled = false;
        notesInput.disabled = false;
      }
    });

    actions.appendChild(feedback);
    actions.appendChild(saveButton);
    controls.appendChild(actions);

    return controls;
  }

  function createOpportunityCard(opportunity) {
    const source = opportunity.source && typeof opportunity.source === "object" ? opportunity.source : null;
    const areas = activePolicyAreas(opportunity.opportunity_policy_areas);
    const deadline = classifyDeadline(opportunity.closes_on);
    const card = createElement("article", "opportunity-card");
    const header = createElement("div", "opportunity-card-header");
    header.appendChild(createElement(
      "p",
      "opportunity-card-eyebrow",
      formatStatus(opportunity.status) + " · " + (opportunity.sphere || "Esfera não informada")
    ));
    header.appendChild(createElement(
      "h3",
      "opportunity-card-title",
      opportunity.title || opportunity.program_name || "Oportunidade sem título informado"
    ));
    header.appendChild(createElement(
      "p",
      "opportunity-card-description",
      opportunity.description || opportunity.eligibility_summary || "Sem descrição disponível."
    ));
    card.appendChild(header);

    const tags = createElement("div", "opportunity-tags");
    tags.appendChild(createElement("span", "opportunity-tag opportunity-tag-" + deadline.tone, deadline.label));
    if (areas.length) {
      areas.forEach(function (area) {
        tags.appendChild(createElement("span", "opportunity-tag opportunity-tag-area", area.name));
      });
    } else {
      tags.appendChild(createElement("span", "opportunity-tag opportunity-tag-neutral", "Área não classificada"));
    }
    card.appendChild(tags);

    const metadata = createElement("div", "opportunity-metadata");
    appendMeta(metadata, "Programa", opportunity.program_name);
    appendMeta(metadata, "Órgão concedente", opportunity.granting_body);
    appendMeta(metadata, "Fonte", source ? source.name : "Não informado");
    appendMeta(metadata, "Valor", formatAmount(opportunity.amount, opportunity.amount_kind));
    appendMeta(metadata, "Prazo", opportunity.closes_on ? formatCivilDate(opportunity.closes_on) : "Não informado");
    appendMeta(metadata, "Abrangência", formatCoverage(opportunity));
    card.appendChild(metadata);

    const municipalityRelation = opportunity.municipalityOpportunity || null;
    const municipalityManagement = createElement("div", "opportunity-municipality-management");
    const municipalityManagementHeader = createElement("div", "opportunity-municipality-management-header");

    municipalityManagementHeader.appendChild(createElement(
      "span",
      "opportunity-municipality-management-label",
      "Gestão da Prefeitura"
    ));

    municipalityManagementHeader.appendChild(createElement(
      "span",
      "opportunity-municipality-status" +
        (municipalityRelation && municipalityRelation.status
          ? " opportunity-municipality-status-" + municipalityRelation.status
          : " opportunity-municipality-status-unreviewed"),
      formatMunicipalityOpportunityStatus(
        municipalityRelation ? municipalityRelation.status : null
      )
    ));

    municipalityManagement.appendChild(municipalityManagementHeader);
    municipalityManagement.appendChild(
      createMunicipalityOpportunityControls(opportunity, municipalityRelation)
    );
    card.appendChild(municipalityManagement);

    const footer = createElement("div", "opportunity-card-footer");
    const updatedAt = opportunity.source_updated_at || opportunity.last_checked_at;
    footer.appendChild(createElement(
      "span",
      "opportunity-updated",
      updatedAt
        ? "Atualização: " + new Intl.DateTimeFormat("pt-BR", { dateStyle: "medium", timeStyle: "short" }).format(new Date(updatedAt))
        : "Atualização não informada"
    ));
    if (isSafeOfficialUrl(opportunity.official_url)) {
      const link = createElement("a", "opportunity-official-link", "Abrir fonte oficial");
      link.href = opportunity.official_url;
      link.target = "_blank";
      link.rel = "noopener noreferrer";
      footer.appendChild(link);
    }
    card.appendChild(footer);
    return card;
  }

  function setPagination(total, hasNextPage) {
    state.hasNextPage = hasNextPage;
    elements.page.textContent = "Página " + state.page;
    elements.previous.disabled = state.page <= 1 || total === 0;
    elements.next.disabled = !hasNextPage || total === 0;
    elements.pagination.hidden = total === 0;
  }

  function renderResults(rows, total, version) {
    if (!isCurrentRequest(version)) return;
    const visibleRows = rows.slice(0, PAGE_SIZE);
    const hasNextPage = rows.length > PAGE_SIZE;
    elements.list.innerHTML = "";
    visibleRows.forEach(function (opportunity) {
      elements.list.appendChild(createOpportunityCard(opportunity));
    });
    const first = total === 0 ? 0 : (state.page - 1) * PAGE_SIZE + 1;
    const last = Math.min((state.page - 1) * PAGE_SIZE + visibleRows.length, total);
    elements.resultsSummary.textContent = total === 0
      ? "Nenhuma oportunidade encontrada."
      : "Exibindo " + first + "–" + last + " de " + total + " oportunidade" + (total === 1 ? "" : "s") + ".";
    setEmpty(
      total === 0,
      hasActiveFilters(state.filters)
        ? "Nenhuma oportunidade encontrada com os filtros selecionados."
        : "Nenhuma oportunidade publicada disponível no momento."
    );
    setPagination(total, hasNextPage);
    if (state.focusResults) {
      state.focusResults = false;
      elements.resultsRegion.focus({ preventScroll: true });
    }
  }

  async function loadResults(context, filters, version) {
    setLoading(true);
    setError("");
    try {
      const result = await opportunityRequest(
        buildOpportunitiesUrl(filters, {
          limit: PAGE_SIZE + 1,
          offset: (state.page - 1) * PAGE_SIZE
        }),
        context,
        { count: true }
      );
      if (!isCurrentRequest(version)) return;

      const municipality = typeof window.getActiveMunicipalityContext === "function"
        ? window.getActiveMunicipalityContext()
        : null;

      state.activeMunicipalityId = municipality && municipality.id
        ? String(municipality.id)
        : "";

      let rows = result.rows;

      if (municipality && municipality.id && rows.length > 0) {
        const relations = await loadMunicipalityOpportunityRelations(
          context,
          municipality.id,
          rows.map(function (opportunity) {
            return opportunity.id;
          })
        );

        if (!isCurrentRequest(version)) return;

        rows = rows.map(function (opportunity) {
          return Object.assign({}, opportunity, {
            municipalityOpportunity: relations.get(opportunity.id) || null
          });
        });
      }

      const total = countFromResponse(result.response);
      renderResults(rows, total === null ? rows.length : total, version);
    } catch (error) {
      if (!isCurrentRequest(version)) return;
      elements.list.innerHTML = "";
      elements.resultsSummary.textContent = "Não foi possível carregar o catálogo agora.";
      setEmpty(false);
      setPagination(0, false);
      setError(error && error.status === 401
        ? "Sua sessão precisa ser atualizada para consultar as oportunidades."
        : "Não foi possível carregar as oportunidades. Tente novamente.");
    } finally {
      if (isCurrentRequest(version)) setLoading(false);
    }
  }

  async function refreshCatalog(options) {
    const settings = options || {};
    if (!isOpportunitiesRoute()) return;
    const version = ++state.requestVersion;
    if (settings.resetPage) state.page = 1;
    state.filters = normalizeFilters();
    updateFilterFeedback(state.filters);
    resetMetrics();

    let context;
    try {
      context = await getAuthenticatedContext();
    } catch (error) {
      if (!isCurrentRequest(version)) return;
      elements.list.innerHTML = "";
      elements.resultsSummary.textContent = "Faça login para consultar o catálogo.";
      setEmpty(false);
      setError("Não foi possível confirmar sua sessão para consultar as oportunidades.");
      resetMetrics();
      setLoading(false);
      return;
    }
    if (!isCurrentRequest(version)) return;

    await Promise.all([
      loadPolicyAreas(context, version),
      loadSummary(context, state.filters, version),
      loadResults(context, state.filters, version)
    ]);
  }

  function clearFilters() {
    state.page = 1;
    elements.form.reset();
    if (!elements.area.disabled) elements.area.value = "";
    state.filters = normalizeFilters();
    updateFilterFeedback(state.filters);
    refreshCatalog({ resetPage: true });
  }

  function scheduleSearch() {
    window.clearTimeout(state.searchTimer);
    state.searchTimer = window.setTimeout(function () {
      refreshCatalog({ resetPage: true });
    }, SEARCH_DELAY);
  }

  function handleRouteChange() {
    if (!isOpportunitiesRoute()) {
      state.requestVersion += 1;
      return;
    }

    renderActiveMunicipalityContext();
    refreshCatalog({ resetPage: true });
  }

  elements.form.addEventListener("submit", function (event) {
    event.preventDefault();
    refreshCatalog({ resetPage: true });
  });

  elements.form.addEventListener("change", function () {
    refreshCatalog({ resetPage: true });
  });

  elements.search.addEventListener("input", scheduleSearch);
  elements.clear.addEventListener("click", clearFilters);
  elements.retry.addEventListener("click", function () {
    refreshCatalog({ resetPage: false });
  });
  elements.previous.addEventListener("click", function () {
    if (state.page <= 1) return;
    state.page -= 1;
    state.focusResults = true;
    refreshCatalog({ resetPage: false });
  });
  elements.next.addEventListener("click", function () {
    state.page += 1;
    state.focusResults = true;
    refreshCatalog({ resetPage: false });
  });

  window.addEventListener("hashchange", handleRouteChange);
  window.addEventListener("supabase-auth-ready", handleRouteChange);
  window.addEventListener("municipality-context-changed", function (event) {
    const municipalityId = String(event.detail?.id || "");
    const previousMunicipalityId = state.activeMunicipalityId;

    renderActiveMunicipalityContext();

    if (municipalityId === previousMunicipalityId) return;

    if (isOpportunitiesRoute()) {
      refreshCatalog({ resetPage: true });
    }
  });
  window.addEventListener("supabase-auth-signed-out", function () {
    state.requestVersion += 1;
    state.activeMunicipalityId = "";
    window.clearTimeout(state.searchTimer);
    elements.municipalityContextName.textContent = "—";
    elements.municipalityContext.hidden = true;
    elements.list.innerHTML = "";
    elements.resultsSummary.textContent = "Faça login para consultar o catálogo.";
    setEmpty(false);
    setError("");
    resetMetrics();
    setLoading(false);
  });

  updateFilterFeedback(state.filters);
  handleRouteChange();
})();
