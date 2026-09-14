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
  const departmentNewButton = document.querySelector("#municipality-department-new-button");
  const departmentForm = document.querySelector("#municipality-department-form");
  const departmentFormTitle = document.querySelector("#municipality-department-form-title");
  const departmentFormName = document.querySelector("#municipality-department-form-name");
  const departmentFormAbbreviation = document.querySelector("#municipality-department-form-abbreviation");
  const departmentFormUnitType = document.querySelector("#municipality-department-form-unit-type");
  const departmentFormParent = document.querySelector("#municipality-department-form-parent");
  const departmentFormStatus = document.querySelector("#municipality-department-form-status");
  const departmentCancelButton = document.querySelector("#municipality-department-cancel-button");
  const departmentSaveButton = document.querySelector("#municipality-department-save-button");
  const departmentFormError = document.querySelector("#municipality-department-form-error");
  const departmentFeedback = document.querySelector("#municipality-department-feedback");
  const departmentFormFields = [departmentFormName, departmentFormAbbreviation, departmentFormUnitType, departmentFormParent, departmentFormStatus];
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
  const contactNewButton = document.querySelector("#municipality-contact-new-button");
  const contactForm = document.querySelector("#municipality-contact-form");
  const contactFormTitle = document.querySelector("#municipality-contact-form-title");
  const contactFormName = document.querySelector("#municipality-contact-form-name");
  const contactFormJobTitle = document.querySelector("#municipality-contact-form-job-title");
  const contactFormDepartment = document.querySelector("#municipality-contact-form-department");
  const contactFormStatus = document.querySelector("#municipality-contact-form-status");
  const contactFormEmail = document.querySelector("#municipality-contact-form-email");
  const contactFormPhone = document.querySelector("#municipality-contact-form-phone");
  const contactFormPrimary = document.querySelector("#municipality-contact-form-primary");
  const contactCancelButton = document.querySelector("#municipality-contact-cancel-button");
  const contactSaveButton = document.querySelector("#municipality-contact-save-button");
  const contactFormError = document.querySelector("#municipality-contact-form-error");
  const contactFeedback = document.querySelector("#municipality-contact-feedback");
  const contactFormFields = [contactFormName, contactFormJobTitle, contactFormDepartment, contactFormStatus, contactFormEmail, contactFormPhone, contactFormPrimary];
  const tabButtons = Array.from(document.querySelectorAll("[data-municipality-tab]"));
  const panels = Array.from(document.querySelectorAll("[data-municipality-panel]"));

  if (!municipalityPage || !selector || !content || !profileEditButton || !profileForm || !profileCancelButton || !profileSaveButton || !profileFormError || !profileFeedback || profileFormFields.some((field) => !field) || !addressEditButton || !addressForm || !addressCancelButton || !addressSaveButton || !addressFormError || !addressFeedback || addressFormFields.some((field) => !field) || !departmentNewButton || !departmentForm || !departmentFormTitle || !departmentCancelButton || !departmentSaveButton || !departmentFormError || !departmentFeedback || departmentFormFields.some((field) => !field) || !contactNewButton || !contactForm || !contactFormTitle || !contactCancelButton || !contactSaveButton || !contactFormError || !contactFeedback || contactFormFields.some((field) => !field) || tabButtons.length === 0 || panels.length === 0) return;

  const roleLabels = Object.freeze({
    municipality_admin: "Administração municipal",
    grants_manager: "Gestão de convênios",
    secretariat: "Secretaria",
    engineering: "Engenharia",
    finance: "Contabilidade e financeiro",
    procurement: "Licitações e compras",
    auditor: "Consulta e auditoria",
  });

  const departmentTypeLabels = Object.freeze({
    secretariat: "Secretaria",
    department: "Departamento",
    sector: "Setor",
    unit: "Unidade",
  });
  const departmentTypeValues = new Set(Object.keys(departmentTypeLabels));
  const departmentStatusValues = new Set(["active", "inactive"]);

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
    departments: [],
    departmentsFailed: false,
    members: [],
    membersFailed: false,
    memberDepartments: [],
    roles: [],
    contacts: [],
    contactsFailed: false,
    structureCanManage: false,
    isDepartmentSaving: false,
    editingDepartmentId: "",
    contactsCanManage: false,
    isContactSaving: false,
    editingContactId: "",
    editingContactMembershipId: null,
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

  function getContactStatusLabel(status) {
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

  function getDepartmentTypeLabel(unitType) {
    return departmentTypeLabels[String(unitType ?? "unit").toLowerCase()] ?? "Unidade";
  }

  function compareDepartmentNames(first, second) {
    return String(first?.name ?? "").localeCompare(String(second?.name ?? ""), "pt-BR", { sensitivity: "base" });
  }

  function getDepartmentHierarchy(departments) {
    const byId = new Map(departments.map((department) => [String(department.id ?? ""), department]));
    const childrenByParent = new Map();
    const roots = [];

    departments.forEach((department) => {
      const parentId = String(department.parent_department_id ?? "");
      if (!parentId || !byId.has(parentId)) {
        roots.push(department);
        return;
      }
      const children = childrenByParent.get(parentId) ?? [];
      children.push(department);
      childrenByParent.set(parentId, children);
    });

    const ordered = [];
    const visited = new Set();
    const appendBranch = (department, depth = 0) => {
      const departmentId = String(department.id ?? "");
      if (!departmentId || visited.has(departmentId)) return;
      visited.add(departmentId);
      const parent = byId.get(String(department.parent_department_id ?? ""));
      ordered.push({ department, depth, parentName: parent?.name ?? "" });
      (childrenByParent.get(departmentId) ?? []).sort(compareDepartmentNames).forEach((child) => appendBranch(child, depth + 1));
    };

    roots.sort(compareDepartmentNames).forEach((department) => appendBranch(department));
    departments.slice().sort(compareDepartmentNames).forEach((department) => appendBranch(department));
    return ordered;
  }

  function createDepartmentItem(department, { depth = 0, parentName = "", showActions = false } = {}) {
    const item = createElement("article", "municipality-department-item");
    item.classList.toggle("is-child", depth > 0);
    item.style.setProperty("--municipality-department-depth", String(Math.min(depth, 5)));

    if (depth > 0) item.append(createElement("span", "municipality-department-tree-guide"));

    const copy = createElement("div", "municipality-department-copy");
    copy.append(createElement("strong", "", department.name || "Unidade sem nome informado"));

    const metadata = createElement("span", "");
    const details = [];
    if (department.abbreviation) details.push(department.abbreviation);
    details.push(getDepartmentTypeLabel(department.unit_type));
    if (parentName) details.push(`Vinculado a: ${parentName}`);
    metadata.textContent = details.join(" · ");
    copy.append(metadata);

    const tags = createElement("div", "municipality-department-tags");
    tags.append(createElement("span", "municipality-role-tag municipality-department-type", getDepartmentTypeLabel(department.unit_type)));
    tags.append(createElement("span", `municipality-mini-status is-${String(department.status ?? "active").toLowerCase()}`, getDepartmentStatusLabel(department.status)));

    item.append(copy, tags);

    if (showActions) {
      const actions = createElement("div", "municipality-department-actions");
      const editButton = createElement("button", "municipality-department-action", "Editar");
      editButton.type = "button";
      editButton.addEventListener("click", () => openDepartmentEditor(department, editButton));

      const isInactive = String(department.status ?? "active").toLowerCase() === "inactive";
      const statusButton = createElement("button", "municipality-department-action is-status", isInactive ? "Reativar" : "Inativar");
      statusButton.type = "button";
      statusButton.addEventListener("click", () => { void updateDepartmentStatus(department, statusButton); });
      actions.append(editButton, statusButton);
      item.append(actions);
    }

    return item;
  }

  function renderDepartmentList(target, departments, failed, emptyElement, errorElement, limit = 0, showActions = false) {
    target.replaceChildren();
    emptyElement.hidden = failed || departments.length > 0;
    errorElement.hidden = !failed;
    if (failed) return;

    const hierarchy = getDepartmentHierarchy(departments);
    const visibleDepartments = limit > 0 ? hierarchy.slice(0, limit) : hierarchy;
    visibleDepartments.forEach(({ department, depth, parentName }) => {
      target.append(createDepartmentItem(department, { depth, parentName, showActions }));
    });

    if (limit > 0 && hierarchy.length > limit) {
      target.append(createElement("p", "municipality-list-more", `+ ${hierarchy.length - limit} unidades disponíveis na aba Estrutura administrativa.`));
    }
  }

  function updateDepartmentWriteControls() {
    const canManage = state.structureCanManage && !state.departmentsFailed;
    departmentNewButton.hidden = !canManage;
    departmentNewButton.disabled = !canManage || state.isDepartmentSaving;
    if (!canManage && !state.isDepartmentSaving) closeDepartmentEditor();
  }

  function renderDepartments(departments, failed) {
    state.departments = failed ? [] : departments;
    state.departmentsFailed = failed;
    departmentsCount.textContent = String(departments.length);
    renderDepartmentList(departmentsList, departments, failed, departmentsEmpty, departmentsError, 0, state.structureCanManage && !failed);
    renderDepartmentList(overviewDepartmentsList, departments, failed, overviewDepartmentsEmpty, overviewDepartmentsError, 3);
    updateDepartmentWriteControls();
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
    selector.disabled = isSaving || state.isAddressSaving || state.isDepartmentSaving;
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

  function getStructureWritePermission(members, roles, currentUserId) {
    const activeCurrentMembershipIds = new Set(
      members
        .filter((member) => member.user_id === currentUserId && String(member.status ?? "").toLowerCase() === "active")
        .map((member) => String(member.id ?? "")),
    );
    const isMunicipalityAdmin = roles.some((role) => (
      activeCurrentMembershipIds.has(String(role.membership_id ?? ""))
      && role.role_code === "municipality_admin"
    ));

    // A policy de leitura de memberships só mostra outros vínculos ao
    // anchor_superadmin. Isto serve apenas de pista visual; o RLS decide a escrita.
    const hasSuperadminReadScope = members.some((member) => member.user_id && member.user_id !== currentUserId);
    return isMunicipalityAdmin || hasSuperadminReadScope;
  }

  function setDepartmentFormError(message = "") {
    departmentFormError.hidden = !message;
    departmentFormError.textContent = message;
  }

  function setDepartmentFeedback(message = "", kind = "success") {
    departmentFeedback.hidden = !message;
    departmentFeedback.textContent = message;
    if (message) departmentFeedback.dataset.kind = kind;
    else delete departmentFeedback.dataset.kind;
  }

  function setDepartmentSaving(isSaving) {
    state.isDepartmentSaving = isSaving;
    const canManage = state.structureCanManage && !state.departmentsFailed;
    departmentNewButton.disabled = isSaving || !canManage;
    departmentCancelButton.disabled = isSaving;
    departmentSaveButton.disabled = isSaving;
    departmentSaveButton.textContent = isSaving ? "Salvando…" : "Salvar unidade";
    selector.disabled = isSaving || state.isProfileSaving || state.isAddressSaving;
    departmentForm.setAttribute("aria-busy", String(isSaving));
    departmentFormFields.forEach((field) => { field.disabled = isSaving; });
    departmentsList.querySelectorAll("button").forEach((button) => { button.disabled = isSaving; });
  }

  function populateDepartmentParentOptions(selectedParentId = "", editingDepartmentId = "") {
    departmentFormParent.replaceChildren();
    const noParentOption = document.createElement("option");
    noParentOption.value = "";
    noParentOption.textContent = "Nenhuma — unidade de nível principal";
    departmentFormParent.append(noParentOption);

    getDepartmentHierarchy(state.departments).forEach(({ department, depth }) => {
      if (String(department.id ?? "") === String(editingDepartmentId ?? "")) return;
      const option = document.createElement("option");
      option.value = department.id;
      option.textContent = `${"— ".repeat(Math.min(depth, 3))}${department.name || "Unidade sem nome"} — ${getDepartmentTypeLabel(department.unit_type)}`;
      option.selected = String(department.id ?? "") === String(selectedParentId ?? "");
      departmentFormParent.append(option);
    });
  }

  function setDepartmentFormValues(department = null) {
    const isEditing = Boolean(department);
    state.editingDepartmentId = isEditing ? String(department.id ?? "") : "";
    departmentFormTitle.textContent = isEditing ? "Editar unidade" : "Nova unidade";
    departmentSaveButton.textContent = "Salvar unidade";
    departmentFormName.value = department?.name ?? "";
    departmentFormAbbreviation.value = department?.abbreviation ?? "";
    departmentFormUnitType.value = departmentTypeValues.has(String(department?.unit_type ?? "").toLowerCase())
      ? String(department.unit_type).toLowerCase()
      : "unit";
    departmentFormStatus.value = departmentStatusValues.has(String(department?.status ?? "").toLowerCase())
      ? String(department.status).toLowerCase()
      : "active";
    populateDepartmentParentOptions(department?.parent_department_id ?? "", state.editingDepartmentId);
  }

  function closeDepartmentEditor({ returnFocus = false, focusTarget = null } = {}) {
    departmentForm.hidden = true;
    departmentNewButton.setAttribute("aria-expanded", "false");
    state.editingDepartmentId = "";
    setDepartmentFormError();
    if (returnFocus) (focusTarget || departmentNewButton).focus();
  }

  function openDepartmentEditor(department = null, focusTarget = null) {
    if (!state.structureCanManage || state.departmentsFailed || state.isDepartmentSaving || state.isProfileSaving || state.isAddressSaving || !state.selectedMunicipalityId) return;
    setDepartmentFeedback();
    setDepartmentFormError();
    setDepartmentFormValues(department);
    departmentForm.hidden = false;
    departmentNewButton.setAttribute("aria-expanded", "true");
    departmentForm.dataset.returnFocus = focusTarget ? "action" : "new";
    window.requestAnimationFrame(() => departmentFormName.focus());
  }

  function validateDepartmentPayload() {
    const name = typeof departmentFormName.value === "string" ? departmentFormName.value.trim() : "";
    const abbreviation = getOptionalFieldValue(departmentFormAbbreviation);
    const unitType = String(departmentFormUnitType.value ?? "").toLowerCase();
    const status = String(departmentFormStatus.value ?? "").toLowerCase();
    const parentDepartmentId = String(departmentFormParent.value ?? "") || null;

    if (!name) throw createRequestError("Informe o nome da unidade administrativa.");
    if (abbreviation && abbreviation.length > 30) throw createRequestError("A sigla deve ter no máximo 30 caracteres.");
    if (!departmentTypeValues.has(unitType)) throw createRequestError("Selecione um tipo de unidade válido.");
    if (!departmentStatusValues.has(status)) throw createRequestError("Selecione um status válido.");
    if (parentDepartmentId && parentDepartmentId === state.editingDepartmentId) {
      throw createRequestError("Uma unidade não pode ser sua própria unidade superior.");
    }
    if (parentDepartmentId && !state.departments.some((department) => String(department.id ?? "") === parentDepartmentId)) {
      throw createRequestError("Selecione uma unidade superior válida deste município.");
    }

    return {
      name,
      abbreviation,
      unit_type: unitType,
      parent_department_id: parentDepartmentId,
      status,
    };
  }

  function isDepartmentCycleError(error) {
    const message = String(error?.message ?? "").toLowerCase();
    return String(error?.code ?? "") === "23514"
      && (message.includes("ciclo") || message.includes("própria unidade superior"))
      || message.includes("não pode conter ciclos")
      || message.includes("própria unidade superior");
  }

  async function reloadMunicipalityDepartments(context) {
    const municipalityId = state.selectedMunicipalityId;
    if (!municipalityId) return;
    const escapedMunicipalityId = encodeURIComponent(municipalityId);
    const departments = await municipalityRequest(
      `municipality_departments?select=id,municipality_id,name,abbreviation,status,unit_type,parent_department_id&municipality_id=eq.${escapedMunicipalityId}&order=name.asc`,
      context,
    );
    if (municipalityId !== state.selectedMunicipalityId) return;
    state.departments = departments;
    state.departmentsFailed = false;
    renderDepartments(departments, false);
    renderMembers(state.members, state.memberDepartments, state.roles, departments, state.membersFailed, state.currentUserId);
    renderContacts(state.contacts, departments, state.contactsFailed);
  }

  function getDepartmentWriteError(error) {
    if (isProfilePermissionError(error)) return "Você não possui permissão para alterar a estrutura administrativa deste município.";
    if (isDepartmentCycleError(error)) return "Essa alteração criaria um ciclo na estrutura administrativa. Escolha outra unidade superior.";
    if (String(error?.code ?? "") === "23505") return "Já existe uma unidade com esse nome nesta Prefeitura.";
    return "Não foi possível salvar a unidade administrativa. Revise os dados e tente novamente.";
  }

  async function submitMunicipalityDepartment(event) {
    event.preventDefault();
    if (!state.structureCanManage || state.isDepartmentSaving || state.isProfileSaving || state.isAddressSaving || !state.selectedMunicipalityId) return;

    let payload;
    try {
      payload = validateDepartmentPayload();
    } catch (error) {
      setDepartmentFormError(error.message || "Revise os dados informados.");
      return;
    }

    const targetMunicipalityId = state.selectedMunicipalityId;
    const editingDepartmentId = state.editingDepartmentId;
    const isEditing = Boolean(editingDepartmentId);
    setDepartmentFormError();
    setDepartmentSaving(true);

    try {
      const context = await getAuthenticatedContext();
      const result = isEditing
        ? await municipalityWriteRequest(
          `municipality_departments?id=eq.${encodeURIComponent(editingDepartmentId)}&municipality_id=eq.${encodeURIComponent(targetMunicipalityId)}`,
          "PATCH",
          payload,
          context,
        )
        : await municipalityWriteRequest(
          "municipality_departments",
          "POST",
          { municipality_id: targetMunicipalityId, ...payload },
          context,
        );

      if (result.length === 0) throw createRequestError("permission denied", 403, "42501");
      await reloadMunicipalityDepartments(context);
      closeDepartmentEditor();
      setDepartmentFeedback(isEditing ? "Unidade administrativa atualizada com sucesso." : "Unidade administrativa criada com sucesso.", "success");
    } catch (error) {
      setDepartmentFormError(getDepartmentWriteError(error));
    } finally {
      setDepartmentSaving(false);
    }
  }

  async function updateDepartmentStatus(department, focusTarget = null) {
    if (!state.structureCanManage || state.isDepartmentSaving || !state.selectedMunicipalityId || !department?.id) return;
    const targetMunicipalityId = state.selectedMunicipalityId;
    const currentStatus = String(department.status ?? "active").toLowerCase();
    const nextStatus = currentStatus === "inactive" ? "active" : "inactive";
    setDepartmentFeedback();
    setDepartmentSaving(true);

    try {
      const context = await getAuthenticatedContext();
      const result = await municipalityWriteRequest(
        `municipality_departments?id=eq.${encodeURIComponent(department.id)}&municipality_id=eq.${encodeURIComponent(targetMunicipalityId)}`,
        "PATCH",
        { status: nextStatus },
        context,
      );
      if (result.length === 0) throw createRequestError("permission denied", 403, "42501");
      await reloadMunicipalityDepartments(context);
      setDepartmentFeedback(nextStatus === "inactive" ? "Unidade administrativa inativada com sucesso." : "Unidade administrativa reativada com sucesso.", "success");
      if (focusTarget && document.contains(focusTarget)) focusTarget.focus();
    } catch (error) {
      setDepartmentFeedback(getDepartmentWriteError(error), "error");
    } finally {
      setDepartmentSaving(false);
    }
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
    selector.disabled = isSaving || state.isProfileSaving || state.isDepartmentSaving;
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

  function setContactFormError(message = "") {
    contactFormError.hidden = !message;
    contactFormError.textContent = message;
  }

  function setContactFeedback(message = "", kind = "success") {
    contactFeedback.hidden = !message;
    contactFeedback.textContent = message;
    if (message) contactFeedback.dataset.kind = kind;
    else delete contactFeedback.dataset.kind;
  }

  function updateContactWriteControls() {
    const canManage = state.contactsCanManage && !state.contactsFailed && !state.departmentsFailed;
    contactNewButton.hidden = !canManage;
    contactNewButton.disabled = !canManage || state.isContactSaving;
    if (!canManage && !state.isContactSaving) closeContactEditor();
  }

  function setContactSaving(isSaving) {
    state.isContactSaving = isSaving;
    const canManage = state.contactsCanManage && !state.contactsFailed && !state.departmentsFailed;
    contactNewButton.disabled = isSaving || !canManage;
    contactCancelButton.disabled = isSaving;
    contactSaveButton.disabled = isSaving;
    contactSaveButton.textContent = isSaving ? "Salvando…" : "Salvar responsável";
    selector.disabled = isSaving || state.isProfileSaving || state.isAddressSaving || state.isDepartmentSaving;
    contactForm.setAttribute("aria-busy", String(isSaving));
    contactFormFields.forEach((field) => { field.disabled = isSaving; });
    contactsList.querySelectorAll("button").forEach((button) => { button.disabled = isSaving; });
  }

  function populateContactDepartmentOptions(selectedDepartmentId = "") {
    contactFormDepartment.replaceChildren();
    const placeholder = document.createElement("option");
    placeholder.value = "";
    placeholder.textContent = "Selecione uma unidade";
    contactFormDepartment.append(placeholder);

    getDepartmentHierarchy(state.departments).forEach(({ department, depth }) => {
      const option = document.createElement("option");
      option.value = String(department.id ?? "");
      const inactiveLabel = String(department.status ?? "active").toLowerCase() === "inactive" ? " · Inativa" : "";
      option.textContent = `${"— ".repeat(Math.min(depth, 3))}${department.name || "Unidade sem nome"} — ${getDepartmentTypeLabel(department.unit_type)}${inactiveLabel}`;
      option.selected = option.value === String(selectedDepartmentId ?? "");
      contactFormDepartment.append(option);
    });
  }

  function setContactFormValues(contact = null) {
    const isEditing = Boolean(contact);
    state.editingContactId = isEditing ? String(contact.id ?? "") : "";
    state.editingContactMembershipId = isEditing && contact.membership_id ? String(contact.membership_id) : null;
    contactFormTitle.textContent = isEditing ? "Editar responsável" : "Novo responsável";
    contactSaveButton.textContent = "Salvar responsável";
    contactFormName.value = contact?.full_name ?? "";
    contactFormJobTitle.value = contact?.job_title ?? "";
    contactFormEmail.value = contact?.email ?? "";
    contactFormPhone.value = contact?.phone ?? "";
    contactFormPrimary.checked = Boolean(contact?.is_primary);
    contactFormStatus.value = departmentStatusValues.has(String(contact?.status ?? "").toLowerCase())
      ? String(contact.status).toLowerCase()
      : "active";
    populateContactDepartmentOptions(contact?.department_id ?? "");
  }

  function closeContactEditor({ returnFocus = false, focusTarget = null } = {}) {
    contactForm.hidden = true;
    contactNewButton.setAttribute("aria-expanded", "false");
    state.editingContactId = "";
    state.editingContactMembershipId = null;
    setContactFormError();
    if (returnFocus) (focusTarget || contactNewButton).focus();
  }

  function openContactEditor(contact = null, focusTarget = null) {
    if (!state.contactsCanManage || state.contactsFailed || state.departmentsFailed || state.isContactSaving || state.isProfileSaving || state.isAddressSaving || state.isDepartmentSaving || !state.selectedMunicipalityId) return;
    setContactFeedback();
    setContactFormError();
    setContactFormValues(contact);
    contactForm.hidden = false;
    contactNewButton.setAttribute("aria-expanded", "true");
    window.requestAnimationFrame(() => contactFormName.focus());
  }

  function validateContactPayload() {
    const fullName = typeof contactFormName.value === "string" ? contactFormName.value.trim() : "";
    const jobTitle = getOptionalFieldValue(contactFormJobTitle);
    const email = getOptionalFieldValue(contactFormEmail);
    const phone = getOptionalFieldValue(contactFormPhone);
    const departmentId = String(contactFormDepartment.value ?? "");
    const status = String(contactFormStatus.value ?? "").toLowerCase();

    if (!fullName) throw createRequestError("Informe o nome completo do responsável.");
    if (fullName.length > 160) throw createRequestError("O nome completo deve ter no máximo 160 caracteres.");
    if (jobTitle && jobTitle.length > 160) throw createRequestError("O cargo/função deve ter no máximo 160 caracteres.");
    if (!departmentId || !state.departments.some((department) => String(department.id ?? "") === departmentId)) {
      throw createRequestError("Selecione uma unidade administrativa válida deste município.");
    }
    if (email && (email.length < 3 || email.length > 320 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))) {
      throw createRequestError("Informe um e-mail válido.");
    }
    if (phone && (phone.length < 8 || phone.length > 40)) {
      throw createRequestError("Informe um telefone entre 8 e 40 caracteres.");
    }
    if (!departmentStatusValues.has(status)) throw createRequestError("Selecione um status válido.");

    return {
      department_id: departmentId,
      membership_id: state.editingContactMembershipId,
      full_name: fullName,
      job_title: jobTitle,
      email,
      phone,
      is_primary: Boolean(contactFormPrimary.checked),
      status,
    };
  }

  function getContactWriteError(error) {
    if (isProfilePermissionError(error)) return "Você não possui permissão para alterar os responsáveis deste município.";
    if (String(error?.code ?? "") === "23505") return "Já existe um responsável principal ativo para esta unidade.";
    if (String(error?.code ?? "") === "23503") return "A unidade administrativa selecionada não está disponível neste município.";
    return "Não foi possível salvar o responsável. Revise os dados e tente novamente.";
  }

  async function reloadMunicipalityContacts(context) {
    const municipalityId = state.selectedMunicipalityId;
    if (!municipalityId) return;
    const records = await municipalityRequest(
      `municipality_department_contacts?select=id,municipality_id,department_id,membership_id,full_name,job_title,email,phone,is_primary,status&municipality_id=eq.${encodeURIComponent(municipalityId)}&order=department_id.asc,is_primary.desc,full_name.asc`,
      context,
    );
    if (municipalityId !== state.selectedMunicipalityId) return;
    state.contacts = records;
    state.contactsFailed = false;
    renderContacts(records, state.departments, false);
  }

  async function submitMunicipalityContact(event) {
    event.preventDefault();
    if (!state.contactsCanManage || state.contactsFailed || state.departmentsFailed || state.isContactSaving || state.isProfileSaving || state.isAddressSaving || state.isDepartmentSaving || !state.selectedMunicipalityId) return;

    let payload;
    try {
      payload = validateContactPayload();
    } catch (error) {
      setContactFormError(error.message || "Revise os dados informados.");
      return;
    }

    const targetMunicipalityId = state.selectedMunicipalityId;
    const editingContactId = state.editingContactId;
    const isEditing = Boolean(editingContactId);
    setContactFormError();
    setContactSaving(true);

    try {
      const context = await getAuthenticatedContext();
      const result = isEditing
        ? await municipalityWriteRequest(
          `municipality_department_contacts?id=eq.${encodeURIComponent(editingContactId)}&municipality_id=eq.${encodeURIComponent(targetMunicipalityId)}`,
          "PATCH",
          payload,
          context,
        )
        : await municipalityWriteRequest(
          "municipality_department_contacts",
          "POST",
          { municipality_id: targetMunicipalityId, ...payload },
          context,
        );

      if (result.length === 0) throw createRequestError("permission denied", 403, "42501");
      await reloadMunicipalityContacts(context);
      closeContactEditor();
      setContactFeedback(isEditing ? "Responsável atualizado com sucesso." : "Responsável criado com sucesso.", "success");
    } catch (error) {
      setContactFormError(getContactWriteError(error));
    } finally {
      setContactSaving(false);
    }
  }

  async function updateContactStatus(contact, focusTarget = null) {
    if (!state.contactsCanManage || state.contactsFailed || state.isContactSaving || !state.selectedMunicipalityId || !contact?.id) return;
    const targetMunicipalityId = state.selectedMunicipalityId;
    const nextStatus = String(contact.status ?? "active").toLowerCase() === "inactive" ? "active" : "inactive";
    setContactFeedback();
    setContactSaving(true);

    try {
      const context = await getAuthenticatedContext();
      const result = await municipalityWriteRequest(
        `municipality_department_contacts?id=eq.${encodeURIComponent(contact.id)}&municipality_id=eq.${encodeURIComponent(targetMunicipalityId)}`,
        "PATCH",
        { status: nextStatus },
        context,
      );
      if (result.length === 0) throw createRequestError("permission denied", 403, "42501");
      await reloadMunicipalityContacts(context);
      setContactFeedback(nextStatus === "inactive" ? "Responsável inativado com sucesso." : "Responsável reativado com sucesso.", "success");
      if (focusTarget && document.contains(focusTarget)) focusTarget.focus();
    } catch (error) {
      setContactFeedback(getContactWriteError(error), "error");
    } finally {
      setContactSaving(false);
    }
  }

  function renderContacts(contacts, departments, failed) {
    contactsList.replaceChildren();
    contactsCount.textContent = String(contacts.length);
    contactsEmpty.hidden = failed || contacts.length > 0;
    contactsError.hidden = !failed;
    updateContactWriteControls();
    if (failed) return;

    const departmentsById = new Map(departments.map((department) => [String(department.id ?? ""), department]));
    const contactsByDepartment = new Map();
    contacts.forEach((contact) => {
      const departmentId = String(contact.department_id ?? "");
      const current = contactsByDepartment.get(departmentId) ?? [];
      current.push(contact);
      contactsByDepartment.set(departmentId, current);
    });

    getDepartmentHierarchy(departments).forEach(({ department }) => {
      const departmentId = String(department.id ?? "");
      const departmentContacts = contactsByDepartment.get(departmentId) ?? [];
      if (!departmentContacts.length) return;

      const group = createElement("article", "municipality-contact-group");
      const heading = createElement("header", "municipality-contact-group-heading");
      heading.append(createElement("strong", "", `${department.name || "Unidade institucional"} — ${getDepartmentTypeLabel(department.unit_type)}`));
      heading.append(createElement("span", "", `${departmentContacts.length} ${departmentContacts.length === 1 ? "responsável" : "responsáveis"}`));
      group.append(heading);

      const list = createElement("div", "municipality-contact-group-list");
      departmentContacts.forEach((contact) => {
        const item = createElement("article", "municipality-contact-item");
        const copy = createElement("div", "municipality-contact-copy");
        copy.append(createElement("strong", "", contact.full_name || "Responsável não informado"));
        copy.append(createElement("span", "", contact.job_title || "Função não informada"));

        const metadata = createElement("div", "municipality-contact-metadata");
        if (contact.email) metadata.append(createElement("span", "", contact.email));
        if (contact.phone) metadata.append(createElement("span", "", contact.phone));
        if (!contact.email && !contact.phone) metadata.append(createElement("span", "is-not-informed", "Contato não informado"));

        const tags = createElement("div", "municipality-contact-tags");
        if (contact.is_primary) tags.append(createElement("span", "municipality-role-tag is-primary", "Responsável principal"));
        tags.append(createElement("span", `municipality-mini-status is-${String(contact.status ?? "active").toLowerCase()}`, getContactStatusLabel(contact.status)));
        item.append(copy, metadata, tags);

        if (state.contactsCanManage) {
          const actions = createElement("div", "municipality-contact-actions");
          const editButton = createElement("button", "municipality-contact-action", "Editar");
          editButton.type = "button";
          editButton.addEventListener("click", () => openContactEditor(contact, editButton));
          const isInactive = String(contact.status ?? "active").toLowerCase() === "inactive";
          const statusButton = createElement("button", "municipality-contact-action is-status", isInactive ? "Reativar" : "Inativar");
          statusButton.type = "button";
          statusButton.addEventListener("click", () => { void updateContactStatus(contact, statusButton); });
          actions.append(editButton, statusButton);
          item.append(actions);
        }
        list.append(item);
      });
      group.append(list);
      contactsList.append(group);
      contactsByDepartment.delete(departmentId);
    });

    // Dados inconsistentes não são esperados devido à FK composta; se algum
    // registro legado escapar da consulta de unidades, ele continua legível sem
    // expor identificadores técnicos ou controles de escrita.
    contactsByDepartment.forEach((departmentContacts, departmentId) => {
      if (departmentsById.has(departmentId)) return;
      const group = createElement("article", "municipality-contact-group");
      const heading = createElement("header", "municipality-contact-group-heading");
      heading.append(createElement("strong", "", "Unidade institucional indisponível"));
      heading.append(createElement("span", "", `${departmentContacts.length} ${departmentContacts.length === 1 ? "responsável" : "responsáveis"}`));
      group.append(heading);
      const list = createElement("div", "municipality-contact-group-list");
      departmentContacts.forEach((contact) => {
        const item = createElement("article", "municipality-contact-item");
        const copy = createElement("div", "municipality-contact-copy");
        copy.append(createElement("strong", "", contact.full_name || "Responsável não informado"));
        copy.append(createElement("span", "", contact.job_title || "Função não informada"));
        item.append(copy);
        list.append(item);
      });
      group.append(list);
      contactsList.append(group);
    });
  }
  async function fetchSelectedContext(municipalityId, context) {
    const escapedMunicipalityId = encodeURIComponent(municipalityId);
    const [departmentsResult, membersResult, profileResult, addressResult, populationResult, contactsResult] = await Promise.allSettled([
      municipalityRequest(`municipality_departments?select=id,municipality_id,name,abbreviation,status,unit_type,parent_department_id&municipality_id=eq.${escapedMunicipalityId}&order=name.asc`, context),
      municipalityRequest(`municipality_members?select=id,municipality_id,user_id,status&municipality_id=eq.${escapedMunicipalityId}&order=created_at.asc`, context),
      municipalityRequest(`municipality_institutional_profiles?select=municipality_id,mayor_name,official_website,institutional_phone,institutional_email&municipality_id=eq.${escapedMunicipalityId}&limit=1`, context),
      municipalityRequest(`municipality_addresses?select=municipality_id,postal_code,street,number,complement,district,city,state&municipality_id=eq.${escapedMunicipalityId}&limit=1`, context),
      municipalityRequest(`municipality_population_records?select=municipality_id,reference_year,population,source_name,source_url,source_checked_at&municipality_id=eq.${escapedMunicipalityId}&order=reference_year.desc,source_checked_at.desc.nullslast&limit=1`, context),
      municipalityRequest(`municipality_department_contacts?select=id,municipality_id,department_id,membership_id,full_name,job_title,email,phone,is_primary,status&municipality_id=eq.${escapedMunicipalityId}&order=department_id.asc,is_primary.desc,full_name.asc`, context),
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
    if (!state.isDepartmentSaving) {
      closeDepartmentEditor();
      setDepartmentFeedback();
    }
    if (!state.isContactSaving) {
      closeContactEditor();
      setContactFeedback();
    }
    const municipality = state.municipalities.find((item) => item.id === state.selectedMunicipalityId);
    if (!municipality) return;

    setViewState("loading");
    try {
      const details = await fetchSelectedContext(municipality.id, context);
      if (!isCurrentRequest(requestId)) return;

      state.members = details.members;
      state.membersFailed = details.membersFailed;
      state.memberDepartments = details.memberDepartments;
      state.roles = details.roles;
      state.contacts = details.contacts;
      state.contactsFailed = details.contactsFailed;
      state.structureCanManage = !details.departmentsFailed && getStructureWritePermission(details.members, details.roles, context.userId);
      state.contactsCanManage = state.structureCanManage && !details.contactsFailed;

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
    state.departments = [];
    state.departmentsFailed = false;
    state.members = [];
    state.membersFailed = false;
    state.memberDepartments = [];
    state.roles = [];
    state.contacts = [];
    state.contactsFailed = false;
    state.structureCanManage = false;
    state.isDepartmentSaving = false;
    state.editingDepartmentId = "";
    state.contactsCanManage = false;
    state.isContactSaving = false;
    state.editingContactId = "";
    state.editingContactMembershipId = null;
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
    closeDepartmentEditor();
    closeContactEditor();
    setProfileFeedback();
    setAddressFeedback();
    setDepartmentFeedback();
    setContactFeedback();
    setActiveTab("overview");
    setViewState("empty");
  }

  departmentNewButton.addEventListener("click", () => openDepartmentEditor());
  departmentCancelButton.addEventListener("click", () => closeDepartmentEditor({ returnFocus: true }));
  departmentForm.addEventListener("submit", (event) => { void submitMunicipalityDepartment(event); });
  contactNewButton.addEventListener("click", () => openContactEditor());
  contactCancelButton.addEventListener("click", () => closeContactEditor({ returnFocus: true }));
  contactForm.addEventListener("submit", (event) => { void submitMunicipalityContact(event); });
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