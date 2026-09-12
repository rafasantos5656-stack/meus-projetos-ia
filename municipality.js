(() => {
  "use strict";

  const municipalityPage = document.querySelector("#prefeitura");
  const selectorField = document.querySelector("#municipality-selector-field");
  const selector = document.querySelector("#municipality-selector");
  const loadingState = document.querySelector("#municipality-loading-state");
  const errorState = document.querySelector("#municipality-error-state");
  const errorMessage = document.querySelector("#municipality-error-message");
  const emptyState = document.querySelector("#municipality-empty-state");
  const content = document.querySelector("#municipality-content");
  const retryButton = document.querySelector("#municipality-retry-button");
  const municipalityName = document.querySelector("#municipality-name");
  const municipalityState = document.querySelector("#municipality-state");
  const municipalityIbgeCode = document.querySelector("#municipality-ibge-code");
  const municipalityPrimaryCnpj = document.querySelector("#municipality-primary-cnpj");
  const municipalityTimezone = document.querySelector("#municipality-timezone");
  const municipalityStatus = document.querySelector("#municipality-status");
  const departmentsList = document.querySelector("#municipality-departments-list");
  const departmentsCount = document.querySelector("#municipality-departments-count");
  const departmentsEmpty = document.querySelector("#municipality-departments-empty");
  const departmentsError = document.querySelector("#municipality-departments-error");
  const overviewDepartmentsList = document.querySelector("#municipality-overview-departments-list");
  const overviewDepartmentsEmpty = document.querySelector("#municipality-overview-departments-empty");
  const overviewDepartmentsError = document.querySelector("#municipality-overview-departments-error");
  const membersList = document.querySelector("#municipality-members-list");
  const membersEmpty = document.querySelector("#municipality-members-empty");
  const membersError = document.querySelector("#municipality-members-error");
  const summaryMayor = document.querySelector("#municipality-summary-mayor");
  const summaryPopulation = document.querySelector("#municipality-summary-population");
  const summaryPopulationMeta = document.querySelector("#municipality-summary-population-meta");
  const summaryWebsite = document.querySelector("#municipality-summary-website");
  const summaryPhone = document.querySelector("#municipality-summary-phone");
  const summaryEmail = document.querySelector("#municipality-summary-email");
  const profileGrid = document.querySelector("#municipality-profile-grid");
  const profileMayor = document.querySelector("#municipality-profile-mayor");
  const profileWebsite = document.querySelector("#municipality-profile-website");
  const profileWebsiteEmpty = document.querySelector("#municipality-profile-website-empty");
  const profilePhone = document.querySelector("#municipality-profile-phone");
  const profileEmail = document.querySelector("#municipality-profile-email");
  const profileEmpty = document.querySelector("#municipality-profile-empty");
  const profileError = document.querySelector("#municipality-profile-error");
  const profileEditButton = document.querySelector("#municipality-profile-edit-button");
  const profileForm = document.querySelector("#municipality-profile-form");
  const profileFormMayor = document.querySelector("#municipality-profile-form-mayor");
  const profileFormWebsite = document.querySelector("#municipality-profile-form-website");
  const profileFormPhone = document.querySelector("#municipality-profile-form-phone");
  const profileFormEmail = document.querySelector("#municipality-profile-form-email");
  const profileCancelButton = document.querySelector("#municipality-profile-cancel-button");
  const profileSaveButton = document.querySelector("#municipality-profile-save-button");
  const profileFormError = document.querySelector("#municipality-profile-form-error");
  const profileFeedback = document.querySelector("#municipality-profile-feedback");
  const profileFormFields = [profileFormMayor, profileFormWebsite, profileFormPhone, profileFormEmail];
  const addressGrid = document.querySelector("#municipality-address-grid");
  const addressPostalCode = document.querySelector("#municipality-address-postal-code");
  const addressStreet = document.querySelector("#municipality-address-street");
  const addressNumber = document.querySelector("#municipality-address-number");
  const addressComplement = document.querySelector("#municipality-address-complement");
  const addressDistrict = document.querySelector("#municipality-address-district");
  const addressCity = document.querySelector("#municipality-address-city");
  const addressState = document.querySelector("#municipality-address-state");
  const addressEmpty = document.querySelector("#municipality-address-empty");
  const addressError = document.querySelector("#municipality-address-error");
  const addressEditButton = document.querySelector("#municipality-address-edit-button");
  const addressForm = document.querySelector("#municipality-address-form");
  const addressFormPostalCode = document.querySelector("#municipality-address-form-postal-code");
  const addressFormStreet = document.querySelector("#municipality-address-form-street");
  const addressFormNumber = document.querySelector("#municipality-address-form-number");
  const addressFormComplement = document.querySelector("#municipality-address-form-complement");
  const addressFormDistrict = document.querySelector("#municipality-address-form-district");
  const addressFormCity = document.querySelector("#municipality-address-form-city");
  const addressFormState = document.querySelector("#municipality-address-form-state");
  const addressCancelButton = document.querySelector("#municipality-address-cancel-button");
  const addressSaveButton = document.querySelector("#municipality-address-save-button");
  const addressFormError = document.querySelector("#municipality-address-form-error");
  const addressFeedback = document.querySelector("#municipality-address-feedback");
  const addressFormFields = [addressFormPostalCode, addressFormStreet, addressFormNumber, addressFormComplement, addressFormDistrict, addressFormCity, addressFormState];
  const contactsList = document.querySelector("#municipality-contacts-list");
  const contactsCount = document.querySelector("#municipality-contacts-count");
  const contactsEmpty = document.querySelector("#municipality-contacts-empty");
  const contactsError = document.querySelector("#municipality-contacts-error");
  const tabButtons = Array.from(document.querySelectorAll("[data-municipality-tab]"));
  const panels = Array.from(document.querySelectorAll("[data-municipality-panel]"));

  if (!municipalityPage || !selector || !content || !profileEditButton || !profileForm || !profileCancelButton || !profileSaveButton || !profileFormError || !profileFeedback || profileFormFields.some((field) => !field) || !addressEditButton || !addressForm || !addressCancelButton || !addressSaveButton || !addressFormError || !addressFeedback || addressFormFields.some((field) => !field) || tabButtons.length === 0 || panels.length === 0) return;

  const roleLabels = Object.freeze({
    municipality_admin: "Administração municipal",
    grants_manager: "Gestão de convênios",
    secretariat: "Secretaria",
    engineering: "Engenharia",
    finance: "Contabilidade e financeiro",
    procurement: "Licitações e compras",
    auditor: "Consulta e auditoria",
  });

  const state = {
    currentUserId: "",
    municipalities: [],
    selectedMunicipalityId: "",
    activeTab: "overview",
    requestId: 0,
    profile: null,
    profileFailed: false,
    isProfileSaving: false,
    address: null,
    addressFailed: false,
    isAddressSaving: false,
  };

  function isMunicipalityRoute() {
    return ["#prefeitura", "#/prefeitura"].includes(window.location.hash || "");
  }

  function isCurrentRequest(requestId) {
    return requestId === state.requestId;
  }

  function getEnvironmentSettings() {
    const environment = window.APP_ENVIRONMENT;
    const config = window.SUPABASE_CONFIG ?? {};
    const url = typeof config.url === "string" ? config.url.trim().replace(/\/$/, "") : "";
    const anonKey = typeof config.anonKey === "string" ? config.anonKey.trim() : "";

    if (!environment?.validated || !url || !anonKey) {
      throw new Error("O ambiente não está pronto para carregar dados municipais.");
    }

    return { url, anonKey };
  }

  async function getAuthenticatedContext() {
    if (typeof window.getSupabaseAuthContext !== "function") {
      throw new Error("A sessão ainda não está disponível.");
    }

    const context = await window.getSupabaseAuthContext();
    if (!context?.accessToken || !context?.userId) {
      throw new Error("Sua sessão expirou. Entre novamente para continuar.");
    }

    return context;
  }

  function createRequestError(message, status = 0, code = "") {
    const error = new Error(message);
    error.status = status;
    error.code = code;
    return error;
  }

  async function municipalityRequest(path, context, hasRetriedAfterRefresh = false) {
    const { url, anonKey } = getEnvironmentSettings();
    let response;

    try {
      response = await fetch(`${url}/rest/v1/${path}`, {
        headers: {
          apikey: anonKey,
          Authorization: `Bearer ${context.accessToken}`,
        },
      });
    } catch {
      throw createRequestError("Não foi possível conectar ao Supabase.");
    }

    if (
      response.status === 401
      && !hasRetriedAfterRefresh
      && typeof window.refreshSupabaseAuthSession === "function"
    ) {
      const refreshedContext = await window.refreshSupabaseAuthSession(context.accessToken);
      if (refreshedContext?.accessToken && refreshedContext.userId) {
        return municipalityRequest(path, refreshedContext, true);
      }
    }

    const responseText = await response.text();
    let payload = null;
    try {
      payload = responseText ? JSON.parse(responseText) : null;
    } catch {
      payload = null;
    }

    if (!response.ok) {
      throw createRequestError(
        payload?.message || payload?.error || "Não foi possível concluir a consulta municipal.",
        response.status,
      );
    }

    return Array.isArray(payload) ? payload : [];
  }

  async function municipalityWriteRequest(path, method, body, context, hasRetriedAfterRefresh = false) {
    const { url, anonKey } = getEnvironmentSettings();
    let response;

    try {
      response = await fetch(`${url}/rest/v1/${path}`, {
        method,
        headers: {
          apikey: anonKey,
          Authorization: `Bearer ${context.accessToken}`,
          "Content-Type": "application/json",
          Prefer: "return=representation",
        },
        body: JSON.stringify(body),
      });
    } catch {
      throw createRequestError("Não foi possível conectar ao Supabase.");
    }

    if (
      response.status === 401
      && !hasRetriedAfterRefresh
      && typeof window.refreshSupabaseAuthSession === "function"
    ) {
      const refreshedContext = await window.refreshSupabaseAuthSession(context.accessToken);
      if (refreshedContext?.accessToken && refreshedContext.userId) {
        return municipalityWriteRequest(path, method, body, refreshedContext, true);
      }
    }

    const responseText = await response.text();
    let payload = null;
    try {
      payload = responseText ? JSON.parse(responseText) : null;
    } catch {
      payload = null;
    }

    if (!response.ok) {
      throw createRequestError(
        payload?.message || payload?.error || "Não foi possível salvar os dados institucionais.",
        response.status,
        payload?.code || "",
      );
    }

    return Array.isArray(payload) ? payload : [];
  }
  function setViewState(view, message = "") {
    loadingState.hidden = view !== "loading";
    errorState.hidden = view !== "error";
    emptyState.hidden = view !== "empty";
    content.hidden = view !== "content";

    if (view === "error") errorMessage.textContent = message;
  }

  function setOptionalValue(element, value) {
    const hasValue = typeof value === "string" && value.trim();
    element.textContent = hasValue ? value.trim() : "Não informado";
    element.classList.toggle("is-not-informed", !hasValue);
  }

  function getMunicipalityStatusLabel(status) {
    const labels = { active: "Ativa", suspended: "Suspensa", archived: "Arquivada" };
    return labels[String(status ?? "").toLowerCase()] ?? "Não informado";
  }

  function getMembershipStatusLabel(status) {
    const labels = { active: "Ativo", invited: "Convite pendente", suspended: "Suspenso", revoked: "Revogado" };
    return labels[String(status ?? "").toLowerCase()] ?? "Status não informado";
  }

  function getDepartmentStatusLabel(status) {
    return String(status ?? "").toLowerCase() === "inactive" ? "Inativo" : "Ativo";
  }

  function getRoleLabel(roleCode) {
    return roleLabels[String(roleCode ?? "")] ?? "Função municipal atribuída";
  }

  function createElement(tagName, className, text = "") {
    const element = document.createElement(tagName);
    if (className) element.className = className;
    if (text) element.textContent = text;
    return element;
  }

  function setActiveTab(tabName, focusButton = false) {
    const tabExists = tabButtons.some((button) => button.dataset.municipalityTab === tabName);
    state.activeTab = tabExists ? tabName : "overview";

    tabButtons.forEach((button) => {
      const isActive = button.dataset.municipalityTab === state.activeTab;
      button.classList.toggle("is-active", isActive);
      button.setAttribute("aria-selected", String(isActive));
      button.tabIndex = isActive ? 0 : -1;
      if (isActive && focusButton) button.focus();
    });

    panels.forEach((panel) => {
      const isActive = panel.dataset.municipalityPanel === state.activeTab;
      panel.hidden = !isActive;
    });
  }

  function renderSelector() {
    selector.replaceChildren();

    state.municipalities.forEach((municipality) => {
      const option = document.createElement("option");
      option.value = municipality.id;
      option.textContent = `${municipality.name} — ${municipality.state}`;
      option.selected = municipality.id === state.selectedMunicipalityId;
      selector.append(option);
    });

    selectorField.hidden = state.municipalities.length <= 1;
  }

  function renderInstitutionalData(municipality) {
    setOptionalValue(municipalityName, municipality.name);
    setOptionalValue(municipalityState, municipality.state);
    setOptionalValue(municipalityIbgeCode, municipality.ibge_code);
    setOptionalValue(municipalityPrimaryCnpj, municipality.primary_cnpj);
    setOptionalValue(municipalityTimezone, municipality.timezone);

    const status = getMunicipalityStatusLabel(municipality.status);
    municipalityStatus.textContent = status;
    municipalityStatus.className = `municipality-status-badge is-${String(municipality.status ?? "").toLowerCase() || "unknown"}`;
  }

  function createDepartmentItem(department) {
    const item = createElement("article", "municipality-department-item");
    const copy = createElement("div", "municipality-department-copy");
    copy.append(createElement("strong", "", department.name || "Secretaria sem nome informado"));

    const metadata = createElement("span", "");
    const details = [];
    if (department.abbreviation) details.push(department.abbreviation);
    details.push(getDepartmentStatusLabel(department.status));
    metadata.textContent = details.join(" · ");
    copy.append(metadata);

    const status = createElement("span", `municipality-mini-status is-${String(department.status ?? "active").toLowerCase()}`, getDepartmentStatusLabel(department.status));
    item.append(copy, status);
    return item;
  }

  function renderDepartmentList(target, departments, failed, emptyElement, errorElement, limit = 0) {
    target.replaceChildren();
    emptyElement.hidden = failed || departments.length > 0;
    errorElement.hidden = !failed;
    if (failed) return;

    const visibleDepartments = limit > 0 ? departments.slice(0, limit) : departments;
    visibleDepartments.forEach((department) => target.append(createDepartmentItem(department)));
    if (limit > 0 && departments.length > limit) {
      target.append(createElement("p", "municipality-list-more", `+ ${departments.length - limit} departamentos disponíveis na aba Estrutura administrativa.`));
    }
  }

  function renderDepartments(departments, failed) {
    departmentsCount.textContent = String(departments.length);
    renderDepartmentList(departmentsList, departments, failed, departmentsEmpty, departmentsError);
    renderDepartmentList(overviewDepartmentsList, departments, failed, overviewDepartmentsEmpty, overviewDepartmentsError, 3);
  }

  function renderMembers(members, memberDepartments, roles, departments, failed, currentUserId) {
    membersList.replaceChildren();
    membersEmpty.hidden = failed || members.length > 0;
    membersError.hidden = !failed;
    if (failed) return;

    const departmentNames = new Map(departments.map((department) => [department.id, department.name]));
    const departmentIdsByMembership = new Map();
    memberDepartments.forEach((relation) => {
      const current = departmentIdsByMembership.get(relation.membership_id) ?? [];
      current.push(relation.department_id);
      departmentIdsByMembership.set(relation.membership_id, current);
    });

    const rolesByMembership = new Map();
    roles.forEach((role) => {
      const current = rolesByMembership.get(role.membership_id) ?? [];
      current.push(getRoleLabel(role.role_code));
      rolesByMembership.set(role.membership_id, current);
    });

    members.forEach((member) => {
      const item = createElement("article", "municipality-member-item");
      const avatar = createElement("span", "municipality-member-avatar", member.user_id === currentUserId ? "Você" : "M");
      avatar.setAttribute("aria-hidden", "true");

      const copy = createElement("div", "municipality-member-copy");
      copy.append(createElement("strong", "", member.user_id === currentUserId ? "Você" : "Membro vinculado"));
      const names = (departmentIdsByMembership.get(member.id) ?? [])
        .map((departmentId) => departmentNames.get(departmentId))
        .filter(Boolean);
      copy.append(createElement("span", "", names.length ? names.join(" · ") : "Setor não informado"));

      const rolesElement = createElement("div", "municipality-member-roles");
      const roleList = rolesByMembership.get(member.id) ?? [];
      if (roleList.length) {
        roleList.forEach((role) => rolesElement.append(createElement("span", "municipality-role-tag", role)));
      } else {
        rolesElement.append(createElement("span", "municipality-role-tag is-muted", "Função não informada"));
      }

      const status = createElement("span", `municipality-mini-status is-${String(member.status ?? "").toLowerCase() || "unknown"}`, getMembershipStatusLabel(member.status));
      const details = createElement("div", "municipality-member-details");
      details.append(copy, rolesElement);
      item.append(avatar, details, status);
      membersList.append(item);
    });
  }

  function formatPopulation(population) {
    const value = Number(population);
    return Number.isFinite(value) ? new Intl.NumberFormat("pt-BR").format(value) : "Não informado";
  }

  function getSafeWebsite(value) {
    if (typeof value !== "string" || !value.trim()) return "";
    try {
      const url = new URL(value.trim());
      return ["http:", "https:"].includes(url.protocol) ? url.href : "";
    } catch {
      return "";
    }
  }

  function getOptionalFieldValue(input) {
    const value = typeof input?.value === "string" ? input.value.trim() : "";
    return value || null;
  }

  function validateInstitutionalProfilePayload() {
    const payload = {
      mayor_name: getOptionalFieldValue(profileFormMayor),
      official_website: getOptionalFieldValue(profileFormWebsite),
      institutional_phone: getOptionalFieldValue(profileFormPhone),
      institutional_email: getOptionalFieldValue(profileFormEmail),
    };

    if (payload.official_website) {
      try {
        const website = new URL(payload.official_website);
        if (!["http:", "https:"].includes(website.protocol) || payload.official_website.length < 8) {
          throw new Error();
        }
      } catch {
        throw createRequestError("Informe um site oficial iniciado por http:// ou https://.");
      }
    }

    if (payload.institutional_phone && (payload.institutional_phone.length < 8 || payload.institutional_phone.length > 40)) {
      throw createRequestError("Informe um telefone institucional entre 8 e 40 caracteres.");
    }

    if (
      payload.institutional_email
      && (payload.institutional_email.length < 3
        || payload.institutional_email.length > 320
        || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(payload.institutional_email))
    ) {
      throw createRequestError("Informe um e-mail institucional válido.");
    }

    return payload;
  }

  function setProfileFormError(message = "") {
    profileFormError.hidden = !message;
    profileFormError.textContent = message;
  }

  function setProfileFeedback(message = "", kind = "success") {
    profileFeedback.hidden = !message;
    profileFeedback.textContent = message;
    if (message) profileFeedback.dataset.kind = kind;
    else delete profileFeedback.dataset.kind;
  }

  function setProfileSaving(isSaving) {
    state.isProfileSaving = isSaving;
    profileEditButton.disabled = isSaving || state.profileFailed;
    addressEditButton.disabled = isSaving || state.addressFailed;
    profileCancelButton.disabled = isSaving;
    profileSaveButton.disabled = isSaving;
    profileSaveButton.textContent = isSaving ? "Salvando…" : "Salvar dados";
    selector.disabled = isSaving || state.isAddressSaving;
    profileForm.setAttribute("aria-busy", String(isSaving));
    profileFormFields.forEach((field) => { field.disabled = isSaving; });
  }

  function setProfileFormValues(profile) {
    profileFormMayor.value = profile?.mayor_name ?? "";
    profileFormWebsite.value = profile?.official_website ?? "";
    profileFormPhone.value = profile?.institutional_phone ?? "";
    profileFormEmail.value = profile?.institutional_email ?? "";
  }

  function closeProfileEditor({ returnFocus = false } = {}) {
    profileForm.hidden = true;
    profileEditButton.setAttribute("aria-expanded", "false");
    setProfileFormError();
    if (returnFocus) profileEditButton.focus();
  }

  function openProfileEditor() {
    if (state.profileFailed || state.isProfileSaving || !state.selectedMunicipalityId) return;
    setProfileFeedback();
    setProfileFormError();
    setProfileFormValues(state.profile);
    profileForm.hidden = false;
    profileEditButton.setAttribute("aria-expanded", "true");
    window.requestAnimationFrame(() => profileFormMayor.focus());
  }

  function isProfilePermissionError(error) {
    const message = String(error?.message ?? "").toLowerCase();
    return Number(error?.status) === 401
      || Number(error?.status) === 403
      || String(error?.code ?? "") === "42501"
      || message.includes("permission denied")
      || message.includes("row-level security");
  }

  async function reloadInstitutionalProfile(context) {
    const municipalityId = state.selectedMunicipalityId;
    if (!municipalityId) return;
    const escapedMunicipalityId = encodeURIComponent(municipalityId);
    const records = await municipalityRequest(
      `municipality_institutional_profiles?select=municipality_id,mayor_name,official_website,institutional_phone,institutional_email&municipality_id=eq.${escapedMunicipalityId}&limit=1`,
      context,
    );
    state.profile = records[0] ?? null;
    state.profileFailed = false;
    renderProfile(state.profile, false);
  }

  async function submitInstitutionalProfile(event) {
    event.preventDefault();
    if (state.isProfileSaving || !state.selectedMunicipalityId) return;

    let payload;
    try {
      payload = validateInstitutionalProfilePayload();
    } catch (error) {
      setProfileFormError(error.message || "Revise os dados informados.");
      return;
    }

    const targetMunicipalityId = state.selectedMunicipalityId;
    const hadProfile = Boolean(state.profile);
    setProfileFormError();
    setProfileSaving(true);

    try {
      const context = await getAuthenticatedContext();
      const escapedMunicipalityId = encodeURIComponent(targetMunicipalityId);
      const result = hadProfile
        ? await municipalityWriteRequest(
          `municipality_institutional_profiles?municipality_id=eq.${escapedMunicipalityId}`,
          "PATCH",
          payload,
          context,
        )
        : await municipalityWriteRequest(
          "municipality_institutional_profiles",
          "POST",
          { municipality_id: targetMunicipalityId, ...payload },
          context,
        );

      if (result.length === 0) {
        throw createRequestError("permission denied", 403, "42501");
      }

      await reloadInstitutionalProfile(context);
      closeProfileEditor();
      setProfileFeedback("Dados institucionais atualizados com sucesso.", "success");
    } catch (error) {
      const isCreationConflict = !hadProfile && (Number(error?.status) === 409 || String(error?.code ?? "") === "23505");
      if (isCreationConflict) {
        try {
          const context = await getAuthenticatedContext();
          await reloadInstitutionalProfile(context);
          closeProfileEditor();
          setProfileFeedback("Um perfil institucional foi criado por outra pessoa. Os dados foram recarregados; revise antes de tentar novamente.", "info");
        } catch {
          setProfileFormError("O perfil já existe, mas não foi possível recarregar os dados. Tente novamente.");
        }
      } else if (isProfilePermissionError(error)) {
        setProfileFormError("Você não possui permissão para editar estes dados.");
      } else {
        setProfileFormError("Não foi possível salvar os dados institucionais. Revise os campos e tente novamente.");
      }
    } finally {
      setProfileSaving(false);
    }
  }
  function renderProfile(profile, failed) {
    state.profile = failed ? null : profile;
    state.profileFailed = failed;
    profileEditButton.hidden = failed;
    profileEditButton.disabled = state.isProfileSaving || failed;
    if (failed && !state.isProfileSaving) closeProfileEditor();

    const hasProfile = Boolean(profile) && !failed;
    profileGrid.hidden = failed || !hasProfile;
    profileEmpty.hidden = failed || hasProfile;
    profileError.hidden = !failed;

    const mayor = hasProfile ? profile.mayor_name : "";
    const website = hasProfile ? profile.official_website : "";
    const phone = hasProfile ? profile.institutional_phone : "";
    const email = hasProfile ? profile.institutional_email : "";

    setOptionalValue(summaryMayor, mayor);
    setOptionalValue(summaryWebsite, website);
    setOptionalValue(summaryPhone, phone);
    setOptionalValue(summaryEmail, email);

    if (!hasProfile) return;

    setOptionalValue(profileMayor, mayor);
    setOptionalValue(profilePhone, phone);
    setOptionalValue(profileEmail, email);

    const safeWebsite = getSafeWebsite(website);
    profileWebsite.hidden = !safeWebsite;
    profileWebsiteEmpty.hidden = Boolean(safeWebsite);
    if (safeWebsite) {
      profileWebsite.href = safeWebsite;
      profileWebsite.textContent = website.trim();
    } else {
      profileWebsite.removeAttribute("href");
      profileWebsite.textContent = "";
      setOptionalValue(profileWebsiteEmpty, website);
    }
  }

  function renderPopulation(record, failed) {
    if (failed || !record) {
      setOptionalValue(summaryPopulation, "");
      summaryPopulationMeta.textContent = failed ? "Não foi possível carregar o registro" : "Sem registro disponível";
      return;
    }

    summaryPopulation.textContent = `${formatPopulation(record.population)} habitantes`;
    summaryPopulation.classList.remove("is-not-informed");
    const source = typeof record.source_name === "string" && record.source_name.trim() ? record.source_name.trim() : "Fonte não informada";
    summaryPopulationMeta.textContent = `${record.reference_year} · ${source}`;
  }

  function getOptionalPostalCodeValue() {
    const value = typeof addressFormPostalCode.value === "string"
      ? addressFormPostalCode.value.replace(/\s+/g, "")
      : "";
    return value || null;
  }

  function getOptionalAddressStateValue() {
    const value = typeof addressFormState.value === "string" ? addressFormState.value.trim() : "";
    return value ? value.toUpperCase() : null;
  }

  function validateMunicipalityAddressPayload() {
    const payload = {
      postal_code: getOptionalPostalCodeValue(),
      street: getOptionalFieldValue(addressFormStreet),
      number: getOptionalFieldValue(addressFormNumber),
      complement: getOptionalFieldValue(addressFormComplement),
      district: getOptionalFieldValue(addressFormDistrict),
      city: getOptionalFieldValue(addressFormCity),
      state: getOptionalAddressStateValue(),
    };

    if (payload.postal_code && !/^\d{5}-?\d{3}$/.test(payload.postal_code)) {
      throw createRequestError("Informe um CEP no formato 00000-000 ou 00000000.");
    }

    if (payload.state && !/^[A-Z]{2}$/.test(payload.state)) {
      throw createRequestError("Informe uma UF com exatamente duas letras.");
    }

    const sizeRules = [
      ["street", 240, "logradouro"],
      ["number", 40, "número"],
      ["complement", 160, "complemento"],
      ["district", 160, "bairro"],
      ["city", 160, "município"],
    ];
    for (const [field, limit, label] of sizeRules) {
      if (payload[field] && payload[field].length > limit) {
        throw createRequestError(`O campo ${label} deve ter no máximo ${limit} caracteres.`);
      }
    }

    return payload;
  }

  function setAddressFormError(message = "") {
    addressFormError.hidden = !message;
    addressFormError.textContent = message;
  }

  function setAddressFeedback(message = "", kind = "success") {
    addressFeedback.hidden = !message;
    addressFeedback.textContent = message;
    if (message) addressFeedback.dataset.kind = kind;
    else delete addressFeedback.dataset.kind;
  }

  function setAddressSaving(isSaving) {
    state.isAddressSaving = isSaving;
    addressEditButton.disabled = isSaving || state.addressFailed;
    profileEditButton.disabled = isSaving || state.profileFailed;
    addressCancelButton.disabled = isSaving;
    addressSaveButton.disabled = isSaving;
    addressSaveButton.textContent = isSaving ? "Salvando…" : "Salvar endereço";
    selector.disabled = isSaving || state.isProfileSaving;
    addressForm.setAttribute("aria-busy", String(isSaving));
    addressFormFields.forEach((field) => { field.disabled = isSaving; });
  }

  function setAddressFormValues(address) {
    addressFormPostalCode.value = address?.postal_code ?? "";
    addressFormStreet.value = address?.street ?? "";
    addressFormNumber.value = address?.number ?? "";
    addressFormComplement.value = address?.complement ?? "";
    addressFormDistrict.value = address?.district ?? "";
    addressFormCity.value = address?.city ?? "";
    addressFormState.value = address?.state ?? "";
  }

  function closeAddressEditor({ returnFocus = false } = {}) {
    addressForm.hidden = true;
    addressEditButton.setAttribute("aria-expanded", "false");
    setAddressFormError();
    if (returnFocus) addressEditButton.focus();
  }

  function openAddressEditor() {
    if (state.addressFailed || state.isAddressSaving || state.isProfileSaving || !state.selectedMunicipalityId) return;
    setAddressFeedback();
    setAddressFormError();
    setAddressFormValues(state.address);
    addressForm.hidden = false;
    addressEditButton.setAttribute("aria-expanded", "true");
    window.requestAnimationFrame(() => addressFormPostalCode.focus());
  }

  async function reloadMunicipalityAddress(context) {
    const municipalityId = state.selectedMunicipalityId;
    if (!municipalityId) return;
    const escapedMunicipalityId = encodeURIComponent(municipalityId);
    const records = await municipalityRequest(
      `municipality_addresses?select=municipality_id,postal_code,street,number,complement,district,city,state&municipality_id=eq.${escapedMunicipalityId}&limit=1`,
      context,
    );
    state.address = records[0] ?? null;
    state.addressFailed = false;
    renderAddress(state.address, false);
  }

  async function submitMunicipalityAddress(event) {
    event.preventDefault();
    if (state.isAddressSaving || state.isProfileSaving || !state.selectedMunicipalityId) return;

    let payload;
    try {
      payload = validateMunicipalityAddressPayload();
    } catch (error) {
      setAddressFormError(error.message || "Revise os dados informados.");
      return;
    }

    const targetMunicipalityId = state.selectedMunicipalityId;
    const hadAddress = Boolean(state.address);
    if (!hadAddress && Object.values(payload).every((value) => value === null)) {
      setAddressFormError("Informe pelo menos um dado para criar o endereço institucional.");
      return;
    }

    setAddressFormError();
    setAddressSaving(true);

    try {
      const context = await getAuthenticatedContext();
      const escapedMunicipalityId = encodeURIComponent(targetMunicipalityId);
      const result = hadAddress
        ? await municipalityWriteRequest(
          `municipality_addresses?municipality_id=eq.${escapedMunicipalityId}`,
          "PATCH",
          payload,
          context,
        )
        : await municipalityWriteRequest(
          "municipality_addresses",
          "POST",
          { municipality_id: targetMunicipalityId, ...payload },
          context,
        );

      if (result.length === 0) {
        throw createRequestError("permission denied", 403, "42501");
      }

      await reloadMunicipalityAddress(context);
      closeAddressEditor();
      setAddressFeedback("Endereço institucional atualizado com sucesso.", "success");
    } catch (error) {
      const isCreationConflict = !hadAddress && (Number(error?.status) === 409 || String(error?.code ?? "") === "23505");
      if (isCreationConflict) {
        try {
          const context = await getAuthenticatedContext();
          await reloadMunicipalityAddress(context);
          closeAddressEditor();
          setAddressFeedback("Um endereço foi criado por outra pessoa. Os dados foram recarregados; revise antes de tentar novamente.", "info");
        } catch {
          setAddressFormError("O endereço já existe, mas não foi possível recarregar os dados. Tente novamente.");
        }
      } else if (isProfilePermissionError(error)) {
        setAddressFormError("Você não possui permissão para editar estes dados.");
      } else {
        setAddressFormError("Não foi possível salvar o endereço institucional. Revise os campos e tente novamente.");
      }
    } finally {
      setAddressSaving(false);
    }
  }
  function renderAddress(address, failed) {
    state.address = failed ? null : address;
    state.addressFailed = failed;
    addressEditButton.hidden = failed;
    addressEditButton.disabled = state.isAddressSaving || failed;
    if (failed && !state.isAddressSaving) closeAddressEditor();

    const hasAddress = Boolean(address) && !failed;
    addressGrid.hidden = failed || !hasAddress;
    addressEmpty.hidden = failed || hasAddress;
    addressError.hidden = !failed;
    if (!hasAddress) return;

    setOptionalValue(addressPostalCode, address.postal_code);
    setOptionalValue(addressStreet, address.street);
    setOptionalValue(addressNumber, address.number);
    setOptionalValue(addressComplement, address.complement);
    setOptionalValue(addressDistrict, address.district);
    setOptionalValue(addressCity, address.city);
    setOptionalValue(addressState, address.state);
  }

  function renderContacts(contacts, departments, failed) {
    contactsList.replaceChildren();
    contactsCount.textContent = String(contacts.length);
    contactsEmpty.hidden = failed || contacts.length > 0;
    contactsError.hidden = !failed;
    if (failed) return;

    const departmentNames = new Map(departments.map((department) => [department.id, department.name]));
    const contactsByDepartment = new Map();
    contacts.forEach((contact) => {
      const current = contactsByDepartment.get(contact.department_id) ?? [];
      current.push(contact);
      contactsByDepartment.set(contact.department_id, current);
    });

    contactsByDepartment.forEach((departmentContacts, departmentId) => {
      const group = createElement("article", "municipality-contact-group");
      const heading = createElement("header", "municipality-contact-group-heading");
      heading.append(createElement("strong", "", departmentNames.get(departmentId) || "Departamento institucional"));
      heading.append(createElement("span", "", `${departmentContacts.length} ${departmentContacts.length === 1 ? "responsável" : "responsáveis"}`));
      group.append(heading);

      const list = createElement("div", "municipality-contact-group-list");
      departmentContacts.forEach((contact) => {
        const item = createElement("div", "municipality-contact-item");
        const copy = createElement("div", "municipality-contact-copy");
        copy.append(createElement("strong", "", contact.full_name || "Responsável não informado"));
        copy.append(createElement("span", "", contact.job_title || "Função não informada"));

        const metadata = createElement("div", "municipality-contact-metadata");
        if (contact.email) metadata.append(createElement("span", "", contact.email));
        if (contact.phone) metadata.append(createElement("span", "", contact.phone));
        if (!contact.email && !contact.phone) metadata.append(createElement("span", "is-not-informed", "Contato não informado"));

        const tags = createElement("div", "municipality-contact-tags");
        if (contact.is_primary) tags.append(createElement("span", "municipality-role-tag is-primary", "Principal"));
        if (String(contact.status ?? "active").toLowerCase() === "inactive") tags.append(createElement("span", "municipality-mini-status is-inactive", "Inativo"));

        item.append(copy, metadata, tags);
        list.append(item);
      });

      group.append(list);
      contactsList.append(group);
    });
  }

  async function fetchSelectedContext(municipalityId, context) {
    const escapedMunicipalityId = encodeURIComponent(municipalityId);
    const [departmentsResult, membersResult, profileResult, addressResult, populationResult, contactsResult] = await Promise.allSettled([
      municipalityRequest(`municipality_departments?select=id,municipality_id,name,abbreviation,status&municipality_id=eq.${escapedMunicipalityId}&order=name.asc`, context),
      municipalityRequest(`municipality_members?select=id,municipality_id,user_id,status&municipality_id=eq.${escapedMunicipalityId}&order=created_at.asc`, context),
      municipalityRequest(`municipality_institutional_profiles?select=municipality_id,mayor_name,official_website,institutional_phone,institutional_email&municipality_id=eq.${escapedMunicipalityId}&limit=1`, context),
      municipalityRequest(`municipality_addresses?select=municipality_id,postal_code,street,number,complement,district,city,state&municipality_id=eq.${escapedMunicipalityId}&limit=1`, context),
      municipalityRequest(`municipality_population_records?select=municipality_id,reference_year,population,source_name,source_url,source_checked_at&municipality_id=eq.${escapedMunicipalityId}&order=reference_year.desc,source_checked_at.desc.nullslast&limit=1`, context),
      municipalityRequest(`municipality_department_contacts?select=municipality_id,department_id,full_name,job_title,email,phone,is_primary,status&municipality_id=eq.${escapedMunicipalityId}&order=department_id.asc,is_primary.desc,full_name.asc`, context),
    ]);

    const departments = departmentsResult.status === "fulfilled" ? departmentsResult.value : [];
    const members = membersResult.status === "fulfilled" ? membersResult.value : [];
    const membershipIds = members.map((member) => String(member.id ?? "")).filter((id) => /^[0-9a-f-]{36}$/i.test(id));
    let memberDepartments = [];
    let roles = [];
    let membersFailed = membersResult.status !== "fulfilled";

    if (!membersFailed && membershipIds.length > 0) {
      const membershipFilter = `in.(${membershipIds.join(",")})`;
      const [memberDepartmentsResult, rolesResult] = await Promise.allSettled([
        municipalityRequest(`municipality_member_departments?select=membership_id,department_id&membership_id=${membershipFilter}`, context),
        municipalityRequest(`municipality_member_roles?select=membership_id,role_code&membership_id=${membershipFilter}`, context),
      ]);
      memberDepartments = memberDepartmentsResult.status === "fulfilled" ? memberDepartmentsResult.value : [];
      roles = rolesResult.status === "fulfilled" ? rolesResult.value : [];
      membersFailed = memberDepartmentsResult.status !== "fulfilled" || rolesResult.status !== "fulfilled";
    }

    return {
      departments,
      departmentsFailed: departmentsResult.status !== "fulfilled",
      members,
      membersFailed,
      memberDepartments,
      roles,
      profile: profileResult.status === "fulfilled" ? profileResult.value[0] ?? null : null,
      profileFailed: profileResult.status !== "fulfilled",
      address: addressResult.status === "fulfilled" ? addressResult.value[0] ?? null : null,
      addressFailed: addressResult.status !== "fulfilled",
      population: populationResult.status === "fulfilled" ? populationResult.value[0] ?? null : null,
      populationFailed: populationResult.status !== "fulfilled",
      contacts: contactsResult.status === "fulfilled" ? contactsResult.value : [],
      contactsFailed: contactsResult.status !== "fulfilled",
    };
  }

  async function loadSelectedMunicipality(context, requestId) {
    if (!state.isProfileSaving) {
      closeProfileEditor();
      setProfileFeedback();
    }
    if (!state.isAddressSaving) {
      closeAddressEditor();
      setAddressFeedback();
    }
    const municipality = state.municipalities.find((item) => item.id === state.selectedMunicipalityId);
    if (!municipality) return;

    setViewState("loading");
    try {
      const details = await fetchSelectedContext(municipality.id, context);
      if (!isCurrentRequest(requestId)) return;

      renderInstitutionalData(municipality);
      renderDepartments(details.departments, details.departmentsFailed);
      renderMembers(details.members, details.memberDepartments, details.roles, details.departments, details.membersFailed, context.userId);
      renderProfile(details.profile, details.profileFailed);
      renderPopulation(details.population, details.populationFailed);
      renderAddress(details.address, details.addressFailed);
      renderContacts(details.contacts, details.departments, details.contactsFailed);
      setViewState("content");
    } catch {
      if (isCurrentRequest(requestId)) {
        setViewState("error", "Não foi possível carregar as informações deste contexto. Tente novamente.");
      }
    }
  }

  async function loadMunicipalityPage({ reloadMunicipalities = true } = {}) {
    if (!isMunicipalityRoute()) return;

    const requestId = ++state.requestId;
    setViewState("loading");
    try {
      const context = await getAuthenticatedContext();
      state.currentUserId = context.userId;

      if (reloadMunicipalities || state.municipalities.length === 0) {
        const municipalities = await municipalityRequest("municipalities?select=id,name,state,ibge_code,primary_cnpj,timezone,status&order=name.asc", context);
        if (!isCurrentRequest(requestId)) return;
        state.municipalities = municipalities;
      }

      if (state.municipalities.length === 0) {
        state.selectedMunicipalityId = "";
        selector.replaceChildren();
        selectorField.hidden = true;
        setViewState("empty");
        return;
      }

      const selectedExists = state.municipalities.some((municipality) => municipality.id === state.selectedMunicipalityId);
      if (!selectedExists) state.selectedMunicipalityId = state.municipalities[0].id;
      renderSelector();
      await loadSelectedMunicipality(context, requestId);
    } catch (error) {
      if (!isCurrentRequest(requestId)) return;
      const message = Number(error?.status) === 401
        ? "Sua sessão expirou. Entre novamente para continuar."
        : "Não foi possível carregar o contexto municipal agora. Tente novamente.";
      setViewState("error", message);
    }
  }

  function resetMunicipalityPage() {
    state.currentUserId = "";
    state.municipalities = [];
    state.selectedMunicipalityId = "";
    state.profile = null;
    state.profileFailed = false;
    state.address = null;
    state.addressFailed = false;
    state.requestId += 1;
    selector.replaceChildren();
    selectorField.hidden = true;
    departmentsList.replaceChildren();
    overviewDepartmentsList.replaceChildren();
    membersList.replaceChildren();
    contactsList.replaceChildren();
    departmentsCount.textContent = "0";
    contactsCount.textContent = "0";
    closeProfileEditor();
    closeAddressEditor();
    setProfileFeedback();
    setAddressFeedback();
    setActiveTab("overview");
    setViewState("empty");
  }

  addressEditButton.addEventListener("click", openAddressEditor);
  addressCancelButton.addEventListener("click", () => closeAddressEditor({ returnFocus: true }));
  addressForm.addEventListener("submit", (event) => { void submitMunicipalityAddress(event); });
  profileEditButton.addEventListener("click", openProfileEditor);
  profileCancelButton.addEventListener("click", () => closeProfileEditor({ returnFocus: true }));
  profileForm.addEventListener("submit", (event) => { void submitInstitutionalProfile(event); });
  selector.addEventListener("change", () => {
    const selected = selector.value;
    if (!state.municipalities.some((municipality) => municipality.id === selected)) return;

    state.selectedMunicipalityId = selected;
    const requestId = ++state.requestId;
    void (async () => {
      try {
        const context = await getAuthenticatedContext();
        await loadSelectedMunicipality(context, requestId);
      } catch {
        if (isCurrentRequest(requestId)) setViewState("error", "Não foi possível trocar o contexto municipal agora. Tente novamente.");
      }
    })();
  });

  retryButton.addEventListener("click", () => {
    void loadMunicipalityPage({ reloadMunicipalities: true });
  });

  tabButtons.forEach((button, index) => {
    button.addEventListener("click", () => setActiveTab(button.dataset.municipalityTab));
    button.addEventListener("keydown", (event) => {
      const keys = ["ArrowRight", "ArrowLeft", "Home", "End"];
      if (!keys.includes(event.key)) return;
      event.preventDefault();
      let nextIndex = index;
      if (event.key === "ArrowRight") nextIndex = (index + 1) % tabButtons.length;
      if (event.key === "ArrowLeft") nextIndex = (index - 1 + tabButtons.length) % tabButtons.length;
      if (event.key === "Home") nextIndex = 0;
      if (event.key === "End") nextIndex = tabButtons.length - 1;
      setActiveTab(tabButtons[nextIndex].dataset.municipalityTab, true);
    });
  });

  window.addEventListener("supabase-auth-ready", (event) => {
    state.currentUserId = String(event.detail?.userId ?? "");
    if (isMunicipalityRoute()) void loadMunicipalityPage({ reloadMunicipalities: true });
  });

  window.addEventListener("supabase-auth-signed-out", resetMunicipalityPage);
  window.addEventListener("hashchange", () => {
    if (isMunicipalityRoute() && state.currentUserId) void loadMunicipalityPage({ reloadMunicipalities: true });
  });

  setActiveTab("overview");
  void (async () => {
    if (!isMunicipalityRoute()) return;
    try {
      const context = await getAuthenticatedContext();
      state.currentUserId = context.userId;
      await loadMunicipalityPage({ reloadMunicipalities: true });
    } catch {
      // A camada de autenticação apresenta a tela adequada quando não há sessão.
    }
  })();
})();