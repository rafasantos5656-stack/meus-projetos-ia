// O Supabase é a fonte principal para usuários autenticados; o localStorage mantém o backup local.
const STORAGE_KEY = "meus_projetos_ia";
const MIGRATION_STORAGE_PREFIX = "meus_projetos_ia_migration_";
const menuButton = document.querySelector(".menu-button");
const sidebar = document.querySelector(".sidebar");
const modal = document.querySelector("#project-modal");
const projectForm = document.querySelector("#project-form");
const projectIdInput = document.querySelector("#project-id");
const projectNameInput = document.querySelector("#project-name");
const emptyProjects = document.querySelector("#empty-projects");
const projectsList = document.querySelector("#projects-list");
const modalTitle = document.querySelector("#modal-title");
const totalProjects = document.querySelector("#total-projects");
const ideaProjects = document.querySelector("#idea-projects");
const inProgressProjects = document.querySelector("#in-progress-projects");
const completedProjects = document.querySelector("#completed-projects");
const pausedProjects = document.querySelector("#paused-projects");
const totalTasks = document.querySelector("#total-tasks");
const completedTasks = document.querySelector("#completed-tasks");
const pendingTasks = document.querySelector("#pending-tasks");
const averageProgress = document.querySelector("#average-progress");
const averageProgressBar = document.querySelector("#average-progress-bar");
const overviewTotalTasks = document.querySelector("#overview-total-tasks");
const overviewCompletedTasks = document.querySelector("#overview-completed-tasks");
const overviewPendingTasks = document.querySelector("#overview-pending-tasks");
const attentionProjectsList = document.querySelector("#attention-projects");
const attentionEmpty = document.querySelector("#attention-empty");
const attentionCount = document.querySelector("#attention-count");
const filteredEmptyProjects = document.querySelector("#filtered-empty-projects");
const projectFilters = document.querySelector(".project-filters");
const filterButtons = document.querySelectorAll(".filter-button");
const showAllProjectsButton = document.querySelector("[data-show-all-projects]");
const projectSearch = document.querySelector("#project-search");
const projectSort = document.querySelector("#project-sort");
const clearProjectControlsButton = document.querySelector("[data-clear-project-controls]");
const dataStatusMessageElement = document.querySelector("#app-message");
const confirmationModalElement = document.querySelector("#confirmation-modal");
const confirmationModalTitleElement = document.querySelector("#confirmation-modal-title");
const confirmationModalDescriptionElement = document.querySelector("#confirmation-modal-description");
const cancelConfirmationButtonElement = document.querySelector("#cancel-confirmation-button");
const confirmDeletionButtonElement = document.querySelector("#confirm-deletion-button");
const navigationLinks = document.querySelectorAll(".main-nav .nav-link[href]");
const reportsFilterForm = document.querySelector("#reports-filter-form");
const reportStartDateInput = document.querySelector("#report-start-date");
const reportEndDateInput = document.querySelector("#report-end-date");
const reportStatusSelect = document.querySelector("#report-status");
const reportPrioritySelect = document.querySelector("#report-priority");
const reportProjectSelect = document.querySelector("#report-project");
const reportDeadlineSelect = document.querySelector("#report-deadline");
const clearReportFiltersButton = document.querySelector("[data-clear-report-filters]");
const reportFilterSummaryElement = document.querySelector("#reports-filter-summary");
const reportProjectsBody = document.querySelector("#report-projects-body");
const reportTasksBody = document.querySelector("#report-tasks-body");
const reportProjectsTableWrap = document.querySelector("#report-projects-table-wrap");
const reportTasksTableWrap = document.querySelector("#report-tasks-table-wrap");
const reportProjectsEmpty = document.querySelector("#report-projects-empty");
const reportTasksEmpty = document.querySelector("#report-tasks-empty");
const reportProjectsCount = document.querySelector("#report-projects-count");
const reportTasksCount = document.querySelector("#report-tasks-count");
const reportAttentionList = document.querySelector("#report-attention-list");
const reportAttentionEmpty = document.querySelector("#report-attention-empty");
const exportExcelButton = document.querySelector("#export-excel-button");
const dashboardVisualsSection = document.querySelector("#dashboard-visuals");
const dashboardStatusChart = document.querySelector("#dashboard-status-chart");
const dashboardStatusEmpty = document.querySelector("#dashboard-status-empty");
const dashboardPriorityChart = document.querySelector("#dashboard-priority-chart");
const dashboardPriorityEmpty = document.querySelector("#dashboard-priority-empty");
const dashboardTaskChart = document.querySelector("#dashboard-task-chart");
const dashboardTaskEmpty = document.querySelector("#dashboard-task-empty");
const dashboardProjectProgressList = document.querySelector("#dashboard-project-progress-list");
const dashboardProjectProgressEmpty = document.querySelector("#dashboard-project-progress-empty");
const dashboardExecutiveAttention = document.querySelector("#dashboard-executive-attention");
const dashboardExecutiveAttentionEmpty = document.querySelector("#dashboard-executive-attention-empty");
const dashboardOverdueCount = document.querySelector("#dashboard-overdue-count");
const dashboardOverdueControl = document.querySelector("#dashboard-overdue-control");
const reportStatusChart = document.querySelector("#report-status-chart");
const reportStatusEmpty = document.querySelector("#report-status-empty");
const reportPriorityChart = document.querySelector("#report-priority-chart");
const reportPriorityEmpty = document.querySelector("#report-priority-empty");
const reportTaskChart = document.querySelector("#report-task-chart");
const reportTaskEmpty = document.querySelector("#report-task-empty");
const reportProjectProgressList = document.querySelector("#report-project-progress-list");
const reportProjectProgressEmpty = document.querySelector("#report-project-progress-empty");
const reportExecutiveAttention = document.querySelector("#report-executive-attention");
const reportExecutiveAttentionEmpty = document.querySelector("#report-executive-attention-empty");
const reportsExecutiveInsight = document.querySelector("#reports-executive-insight");
const reportsExecutiveInsightText = document.querySelector("#reports-executive-insight-text");
const dashboardOverdueTasks = document.querySelector("#dashboard-overdue-tasks");
const dashboardDueTodayTasks = document.querySelector("#dashboard-due-today-tasks");
const dashboardNextSevenTasks = document.querySelector("#dashboard-next-seven-tasks");
const dashboardUpcomingCommitments = document.querySelector("#dashboard-upcoming-commitments");
const dashboardUpcomingCommitmentsEmpty = document.querySelector("#dashboard-upcoming-commitments-empty");
const agendaOverdueTasks = document.querySelector("#agenda-overdue-tasks");
const agendaDueTodayTasks = document.querySelector("#agenda-due-today-tasks");
const agendaNextSevenTasks = document.querySelector("#agenda-next-seven-tasks");
const agendaNextThirtyTasks = document.querySelector("#agenda-next-thirty-tasks");
const agendaNoDateTasks = document.querySelector("#agenda-no-date-tasks");
const agendaPendingCount = document.querySelector("#agenda-pending-count");
const agendaUpcomingCommitments = document.querySelector("#agenda-upcoming-commitments");
const agendaUpcomingEmpty = document.querySelector("#agenda-upcoming-empty");

const localProjectsBackup = loadProjects();
let projects = [];
let activeFilter = "all";
let activeSearch = "";
let activeSort = "newest";
let isSupabaseDataReady = false;
let isSupabaseDataLoading = false;
let isMigrationRunning = false;
let activeSupabaseUserId = null;
let dataMessageTimeout;
let confirmationResolver = null;
let confirmationReturnFocus = null;
let isConfirmationBusy = false;
const defaultReportFilters = Object.freeze({
  startDate: "",
  endDate: "",
  status: "all",
  priority: "all",
  projectId: "all",
  deadline: "all",
});
let reportFilters = { ...defaultReportFilters };
let isExcelExportRunning = false;
let sheetJsLoadingPromise = null;

menuButton?.addEventListener("click", () => {
  sidebar.classList.toggle("is-open");
});

function getToday() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");

  return `${year}-${month}-${day}`;
}

function createId() {
  if (window.crypto?.randomUUID) return window.crypto.randomUUID();

  return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function loadProjects() {
  const savedProjects = localStorage.getItem(STORAGE_KEY);
  if (!savedProjects) return [];

  try {
    const parsedProjects = JSON.parse(savedProjects);
    if (!Array.isArray(parsedProjects)) return [];

    return parsedProjects.map((project) => ({
      ...project,
      tasks: Array.isArray(project.tasks) ? project.tasks : [],
    }));
  } catch {
    return [];
  }
}

function showDataMessage(message) {
  if (!dataStatusMessageElement) return;

  window.clearTimeout(dataMessageTimeout);
  dataStatusMessageElement.hidden = false;
  dataStatusMessageElement.className = "app-message";
  dataStatusMessageElement.textContent = message;
  dataMessageTimeout = window.setTimeout(() => {
    dataStatusMessageElement.hidden = true;
  }, 5200);
}

function getConfirmationFocusableElements() {
  return Array.from(confirmationModalElement.querySelectorAll(
    'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
  )).filter((element) => !element.hidden);
}

function resetConfirmationButtonState() {
  cancelConfirmationButtonElement.disabled = false;
  confirmDeletionButtonElement.disabled = false;
  confirmDeletionButtonElement.textContent = "Excluir";
  confirmDeletionButtonElement.removeAttribute("data-loading");
}

function finishDeletionConfirmation(result = false, restoreFocus = true) {
  const wasVisible = confirmationModalElement.classList.contains("is-visible");
  const resolver = confirmationResolver;
  confirmationResolver = null;
  isConfirmationBusy = false;
  resetConfirmationButtonState();
  confirmationModalElement.classList.remove("is-visible");
  confirmationModalElement.setAttribute("aria-hidden", "true");
  if (!document.querySelector(".modal-backdrop.is-visible")) {
    document.body.classList.remove("modal-open");
  }

  if (restoreFocus && confirmationReturnFocus instanceof HTMLElement && confirmationReturnFocus.isConnected) {
    confirmationReturnFocus.focus();
  }
  confirmationReturnFocus = null;
  if (wasVisible && resolver) resolver(result);
}

function requestDeletionConfirmation({ title, message, triggerElement }) {
  if (confirmationResolver || isConfirmationBusy) return Promise.resolve(false);

  confirmationModalTitleElement.textContent = title;
  confirmationModalDescriptionElement.textContent = message;
  confirmationReturnFocus = triggerElement instanceof HTMLElement ? triggerElement : document.activeElement;
  resetConfirmationButtonState();
  confirmationModalElement.classList.add("is-visible");
  confirmationModalElement.setAttribute("aria-hidden", "false");
  document.body.classList.add("modal-open");
  window.setTimeout(() => cancelConfirmationButtonElement.focus(), 0);

  return new Promise((resolve) => {
    confirmationResolver = resolve;
  });
}

function createDataError(message, status = 0, code = "") {
  const error = new Error(message);
  error.status = status;
  error.code = code;
  return error;
}

function getSupabaseDataSettings() {
  const config = window.SUPABASE_CONFIG ?? {};
  const url = typeof config.url === "string" ? config.url.trim().replace(/\/$/, "") : "";
  const anonKey = typeof config.anonKey === "string" ? config.anonKey.trim() : "";

  if (!url || !anonKey) {
    throw createDataError("A configuração pública do Supabase não está disponível.");
  }

  try {
    const parsedUrl = new URL(url);
    if (!["http:", "https:"].includes(parsedUrl.protocol)) throw new Error();
  } catch {
    throw createDataError("A Project URL do Supabase não é válida.");
  }

  return { url, anonKey };
}

async function getAuthenticatedDataContext() {
  if (typeof window.getSupabaseAuthContext !== "function") {
    throw createDataError("A sessão ainda não está disponível.");
  }

  const context = await window.getSupabaseAuthContext();
  if (!context?.accessToken || !context?.userId) {
    throw createDataError("Sua sessão expirou. Entre novamente para continuar.", 401);
  }

  return context;
}

async function supabaseDataRequest(path, options = {}) {
  const context = options.context ?? await getAuthenticatedDataContext();
  const { url, anonKey } = getSupabaseDataSettings();
  let response;

  try {
    response = await fetch(url + "/rest/v1/" + path, {
      method: options.method ?? "GET",
      headers: {
        apikey: anonKey,
        Authorization: "Bearer " + context.accessToken,
        ...(options.body ? { "Content-Type": "application/json" } : {}),
        ...(options.prefer ? { Prefer: options.prefer } : {}),
      },
      ...(options.body ? { body: JSON.stringify(options.body) } : {}),
    });
  } catch {
    throw createDataError("Não foi possível conectar ao Supabase.");
  }

  if (
    response.status === 401
    && !options.hasRetriedAfterRefresh
    && typeof window.refreshSupabaseAuthSession === "function"
  ) {
    try {
      const refreshedContext = await window.refreshSupabaseAuthSession(context.accessToken);
      if (refreshedContext?.accessToken && refreshedContext.userId) {
        return supabaseDataRequest(path, {
          ...options,
          context: refreshedContext,
          hasRetriedAfterRefresh: true,
        });
      }
    } catch {
      throw createDataError("Sua sessão expirou. Entre novamente para continuar.", 401);
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
    throw createDataError(
      payload?.message || payload?.error || "Não foi possível concluir a operação.",
      response.status,
      payload?.code || "",
    );
  }

  return payload;
}

function getDataErrorMessage(error, fallbackMessage) {
  const status = Number(error?.status);
  const message = String(error?.message ?? "").toLocaleLowerCase("pt-BR");

  if (status === 401 || message.includes("sessão expirou")) {
    return "Sua sessão expirou. Entre novamente para continuar.";
  }
  if (status === 403) {
    return "Você não tem permissão para realizar esta operação.";
  }
  if (message.includes("failed to fetch") || message.includes("network") || message.includes("conectar")) {
    return "Não foi possível conectar ao Supabase. Verifique sua internet e tente novamente.";
  }

  return fallbackMessage;
}

function asSingleRow(payload, errorMessage) {
  if (!Array.isArray(payload) || payload.length === 0) {
    throw createDataError(errorMessage);
  }

  return payload[0];
}

function getUserFilter(userId) {
  return "user_id=eq." + encodeURIComponent(String(userId));
}

function getIdFilter(columnName, id) {
  return columnName + "=eq." + encodeURIComponent(String(id));
}

function mapRemoteProjectToInterface(project, projectTasks) {
  const interfaceProject = {
    id: String(project.id),
    name: String(project.name ?? ""),
    description: String(project.description ?? ""),
    goal: String(project.objective ?? ""),
    status: String(project.status ?? "Ideia"),
    priority: String(project.priority ?? "Média"),
    date: String(project.project_date ?? ""),
    tasks: projectTasks.map((task) => ({
      id: String(task.id),
      description: String(task.description ?? ""),
      completed: Boolean(task.completed),
      dueDate: String(task.due_date ?? ""),
    })),
  };

  interfaceProject.progress = calculateProgress(interfaceProject);
  return interfaceProject;
}

async function fetchRemoteProjectsAndTasks() {
  const context = await getAuthenticatedDataContext();
  const userFilter = getUserFilter(context.userId);
  const projectPath = "projects?select=id,name,description,objective,status,priority,project_date&"
    + userFilter + "&order=created_at.desc";
  const taskPath = "tasks?select=id,project_id,description,completed,due_date&"
    + userFilter + "&order=created_at.asc";
  const results = await Promise.all([
    supabaseDataRequest(projectPath, { context }),
    supabaseDataRequest(taskPath, { context }),
  ]);
  const remoteProjects = Array.isArray(results[0]) ? results[0] : [];
  const remoteTasks = Array.isArray(results[1]) ? results[1] : [];
  const tasksByProjectId = new Map();

  remoteTasks.forEach((task) => {
    const projectId = String(task.project_id);
    const currentTasks = tasksByProjectId.get(projectId) ?? [];
    currentTasks.push(task);
    tasksByProjectId.set(projectId, currentTasks);
  });

  return {
    userId: context.userId,
    projects: remoteProjects.map((project) => (
      mapRemoteProjectToInterface(project, tasksByProjectId.get(String(project.id)) ?? [])
    )),
  };
}

async function loadRemoteProjects() {
  const remoteData = await fetchRemoteProjectsAndTasks();
  projects = remoteData.projects;
  activeSupabaseUserId = remoteData.userId;
  renderProjects();
  return remoteData;
}

function canManageSupabaseData() {
  if (isMigrationRunning) {
    showDataMessage("A importação dos projetos está em andamento. Aguarde a conclusão.");
    return false;
  }

  if (!isSupabaseDataReady) {
    showDataMessage("Estamos carregando seus projetos. Tente novamente em instantes.");
    return false;
  }

  return true;
}

function getProjectDatabasePayload(project, userId, legacyId) {
  const payload = {
    user_id: userId,
    name: project.name,
    description: project.description,
    objective: project.goal,
    status: project.status,
    priority: project.priority,
    project_date: project.date,
  };

  if (legacyId !== null && legacyId !== undefined) payload.legacy_id = legacyId;
  return payload;
}

async function createRemoteProject(project, legacyId = null) {
  const context = await getAuthenticatedDataContext();
  const payload = await supabaseDataRequest("projects", {
    method: "POST",
    context,
    prefer: "return=representation",
    body: getProjectDatabasePayload(project, context.userId, legacyId),
  });

  return asSingleRow(payload, "Não foi possível confirmar a criação do projeto.");
}

async function updateRemoteProject(projectId, project) {
  const context = await getAuthenticatedDataContext();
  const payload = await supabaseDataRequest(
    "projects?" + getIdFilter("id", projectId) + "&" + getUserFilter(context.userId),
    {
      method: "PATCH",
      context,
      prefer: "return=representation",
      body: {
        name: project.name,
        description: project.description,
        objective: project.goal,
        status: project.status,
        priority: project.priority,
        project_date: project.date,
      },
    },
  );

  return asSingleRow(payload, "O projeto não foi encontrado ou não pôde ser atualizado.");
}

async function createRemoteTask(projectId, description, legacyId = null, dueDate) {
  const context = await getAuthenticatedDataContext();
  const body = {
    project_id: projectId,
    user_id: context.userId,
    description,
    completed: false,
  };
  if (dueDate !== undefined) body.due_date = normalizeOptionalTaskDueDate(dueDate);
  if (legacyId !== null && legacyId !== undefined) body.legacy_id = legacyId;

  const payload = await supabaseDataRequest("tasks", {
    method: "POST",
    context,
    prefer: "return=representation",
    body,
  });

  return asSingleRow(payload, "Não foi possível confirmar a criação da tarefa.");
}

async function updateRemoteTaskCompletion(taskId, completed) {
  const context = await getAuthenticatedDataContext();
  const payload = await supabaseDataRequest(
    "tasks?" + getIdFilter("id", taskId) + "&" + getUserFilter(context.userId),
    {
      method: "PATCH",
      context,
      prefer: "return=representation",
      body: { completed },
    },
  );

  return asSingleRow(payload, "A tarefa não foi encontrada ou não pôde ser atualizada.");
}

async function updateRemoteTaskDueDate(taskId, dueDate) {
  const context = await getAuthenticatedDataContext();
  const payload = await supabaseDataRequest(
    "tasks?" + getIdFilter("id", taskId) + "&" + getUserFilter(context.userId),
    {
      method: "PATCH",
      context,
      prefer: "return=representation",
      body: { due_date: normalizeOptionalTaskDueDate(dueDate) },
    },
  );

  return asSingleRow(payload, "A tarefa não foi encontrada ou não pôde ser atualizada.");
}

async function deleteRemoteTask(taskId) {
  const context = await getAuthenticatedDataContext();
  const payload = await supabaseDataRequest(
    "tasks?" + getIdFilter("id", taskId) + "&" + getUserFilter(context.userId),
    {
      method: "DELETE",
      context,
      prefer: "return=representation",
    },
  );

  return asSingleRow(payload, "A tarefa não foi encontrada ou não pôde ser excluída.");
}

async function deleteRemoteProject(projectId) {
  const context = await getAuthenticatedDataContext();
  let tasksWereDeleted = false;

  try {
    await supabaseDataRequest(
      "tasks?" + getIdFilter("project_id", projectId) + "&" + getUserFilter(context.userId),
      {
        method: "DELETE",
        context,
        prefer: "return=representation",
      },
    );
    tasksWereDeleted = true;

    const payload = await supabaseDataRequest(
      "projects?" + getIdFilter("id", projectId) + "&" + getUserFilter(context.userId),
      {
        method: "DELETE",
        context,
        prefer: "return=representation",
      },
    );

    return asSingleRow(payload, "O projeto não foi encontrado ou não pôde ser excluído.");
  } catch (error) {
    error.tasksWereDeleted = tasksWereDeleted;
    throw error;
  }
}

function getMigrationStorageKey(userId) {
  return MIGRATION_STORAGE_PREFIX + String(userId);
}

function readMigrationState(userId) {
  try {
    const savedState = localStorage.getItem(getMigrationStorageKey(userId));
    if (!savedState) return null;

    const state = JSON.parse(savedState);
    if (!state || typeof state !== "object") return null;

    return {
      ...state,
      projectIds: state.projectIds && typeof state.projectIds === "object" ? state.projectIds : {},
      taskIds: state.taskIds && typeof state.taskIds === "object" ? state.taskIds : {},
    };
  } catch {
    return null;
  }
}

function saveMigrationState(userId, state) {
  localStorage.setItem(getMigrationStorageKey(userId), JSON.stringify(state));
}

function getLegacyId(item, itemType) {
  if (item?.id === null || item?.id === undefined || String(item.id).trim() === "") {
    throw createDataError("Há " + itemType + " sem identificador no backup local.");
  }

  return String(item.id);
}

function isUniqueViolation(error) {
  return Number(error?.status) === 409 || error?.code === "23505";
}

async function findRemoteProjectByLegacyId(userId, legacyId) {
  const context = await getAuthenticatedDataContext();
  if (context.userId !== userId) throw createDataError("A conta autenticada foi alterada.");

  const payload = await supabaseDataRequest(
    "projects?select=id&" + getUserFilter(userId) + "&legacy_id=eq." + encodeURIComponent(legacyId) + "&limit=1",
    { context },
  );

  return Array.isArray(payload) && payload.length ? payload[0] : null;
}

async function findRemoteTaskByLegacyId(userId, legacyId) {
  const context = await getAuthenticatedDataContext();
  if (context.userId !== userId) throw createDataError("A conta autenticada foi alterada.");

  const payload = await supabaseDataRequest(
    "tasks?select=id,project_id,completed&" + getUserFilter(userId) + "&legacy_id=eq." + encodeURIComponent(legacyId) + "&limit=1",
    { context },
  );

  return Array.isArray(payload) && payload.length ? payload[0] : null;
}

async function getOrCreateMigratedProject(localProject, userId, state) {
  const legacyId = getLegacyId(localProject, "projeto");
  let remoteProject = await findRemoteProjectByLegacyId(userId, legacyId);

  if (!remoteProject) {
    try {
      remoteProject = await createRemoteProject(localProject, legacyId);
    } catch (error) {
      if (!isUniqueViolation(error)) throw error;
      remoteProject = await findRemoteProjectByLegacyId(userId, legacyId);
      if (!remoteProject) throw error;
    }
  }

  state.projectIds[legacyId] = String(remoteProject.id);
  saveMigrationState(userId, state);
  return remoteProject;
}

async function getOrCreateMigratedTask(localTask, remoteProjectId, userId, state) {
  const legacyId = getLegacyId(localTask, "tarefa");
  let remoteTask = await findRemoteTaskByLegacyId(userId, legacyId);

  if (remoteTask && String(remoteTask.project_id) !== String(remoteProjectId)) {
    throw createDataError("Uma tarefa do backup local já está vinculada a outro projeto.");
  }

  if (!remoteTask) {
    try {
      remoteTask = await createRemoteTask(remoteProjectId, String(localTask.description ?? ""), legacyId);
    } catch (error) {
      if (!isUniqueViolation(error)) throw error;
      remoteTask = await findRemoteTaskByLegacyId(userId, legacyId);
      if (!remoteTask) throw error;
      if (String(remoteTask.project_id) !== String(remoteProjectId)) {
        throw createDataError("Uma tarefa do backup local já está vinculada a outro projeto.");
      }
    }
  }

  if (Boolean(remoteTask.completed) !== Boolean(localTask.completed)) {
    await updateRemoteTaskCompletion(remoteTask.id, Boolean(localTask.completed));
  }

  state.taskIds[legacyId] = String(remoteTask.id);
  saveMigrationState(userId, state);
}

async function runLocalMigration(userId) {
  const previousState = readMigrationState(userId);
  const state = previousState?.status === "in_progress"
    ? previousState
    : {
      version: 1,
      status: "in_progress",
      startedAt: new Date().toISOString(),
      projectIds: {},
      taskIds: {},
    };

  isMigrationRunning = true;
  saveMigrationState(userId, state);

  try {
    for (const localProject of localProjectsBackup) {
      const remoteProject = await getOrCreateMigratedProject(localProject, userId, state);
      for (const localTask of localProject.tasks ?? []) {
        await getOrCreateMigratedTask(localTask, remoteProject.id, userId, state);
      }
    }

    state.status = "completed";
    state.completedAt = new Date().toISOString();
    saveMigrationState(userId, state);
  } catch (error) {
    state.status = "in_progress";
    try {
      saveMigrationState(userId, state);
    } catch {
      // Os índices legacy_id continuam evitando duplicação mesmo se o marcador local falhar.
    }
    showDataMessage("A importação foi interrompida. Seus projetos locais continuam intactos e você poderá retomá-la depois.");
    isMigrationRunning = false;
    return;
  }

  isMigrationRunning = false;
  try {
    await loadRemoteProjects();
    showDataMessage("Projetos e tarefas importados com sucesso para sua conta.");
  } catch {
    showDataMessage("A importação foi concluída, mas não foi possível atualizar a tela. Atualize a página para carregar os dados.");
  }
}

async function offerLocalMigration(userId, remoteProjectCount) {
  if (localProjectsBackup.length === 0) return;

  const migrationState = readMigrationState(userId);
  if (migrationState?.status === "completed") return;

  if (migrationState?.status === "in_progress") {
    const shouldResume = window.confirm(
      "Uma importação anterior foi interrompida. Deseja retomá-la agora? Seus dados locais permanecem salvos neste navegador.",
    );
    if (shouldResume) await runLocalMigration(userId);
    return;
  }

  if (remoteProjectCount !== 0) return;

  const shouldMigrate = window.confirm(
    "Encontramos projetos salvos neste navegador. Deseja importá-los para sua conta? O backup local será mantido.",
  );
  if (shouldMigrate) await runLocalMigration(userId);
}

async function initializeSupabaseProjects() {
  if (isSupabaseDataLoading) return;

  isSupabaseDataLoading = true;
  isSupabaseDataReady = false;
  activeSupabaseUserId = null;
  projects = [];
  renderProjects();

  try {
    const remoteData = await loadRemoteProjects();
    isSupabaseDataReady = true;
    await offerLocalMigration(remoteData.userId, remoteData.projects.length);
  } catch (error) {
    isSupabaseDataReady = false;
    projects = [];
    renderProjects();
    showDataMessage(getDataErrorMessage(error, "Não foi possível carregar seus projetos agora."));
  } finally {
    isSupabaseDataLoading = false;
  }
}

window.addEventListener("supabase-auth-ready", () => {
  void initializeSupabaseProjects();
});

window.addEventListener("supabase-auth-signed-out", () => {
  isSupabaseDataReady = false;
  isSupabaseDataLoading = false;
  isMigrationRunning = false;
  activeSupabaseUserId = null;
  projects = [];
  renderProjects();
});

function calculateProgress(project) {
  const tasks = project.tasks ?? [];
  if (tasks.length === 0) return 0;

  const completedTasks = tasks.filter((task) => task.completed).length;
  return Math.round((completedTasks / tasks.length) * 100);
}

function openProjectModal(project) {
  projectForm.reset();
  projectIdInput.value = "";
  document.querySelector("#project-date").value = getToday();
  modalTitle.textContent = "Novo projeto";

  if (project) {
    projectIdInput.value = project.id;
    document.querySelector("#project-name").value = project.name;
    document.querySelector("#project-description").value = project.description;
    document.querySelector("#project-goal").value = project.goal;
    document.querySelector("#project-status").value = project.status;
    document.querySelector("#project-priority").value = project.priority;
    document.querySelector("#project-date").value = project.date;
    modalTitle.textContent = "Editar projeto";
  }

  modal.classList.add("is-visible");
  modal.setAttribute("aria-hidden", "false");
  document.body.classList.add("modal-open");
  projectNameInput.focus();
}

function closeProjectModal() {
  modal.classList.remove("is-visible");
  modal.setAttribute("aria-hidden", "true");
  document.body.classList.remove("modal-open");
}

function parseProjectDate(dateValue) {
  if (typeof dateValue !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(dateValue)) {
    return null;
  }

  const [year, month, day] = dateValue.split("-").map(Number);
  const date = new Date(year, month - 1, day);
  const isValidDate = date.getFullYear() === year
    && date.getMonth() === month - 1
    && date.getDate() === day;

  if (!isValidDate) return null;

  date.setHours(0, 0, 0, 0);
  return date;
}

function formatDate(dateValue) {
  const date = parseProjectDate(dateValue);
  if (!date) return "Sem data";

  return new Intl.DateTimeFormat("pt-BR", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  }).format(date);
}

function isOverdue(project) {
  const projectDate = parseProjectDate(project.date);
  if (!projectDate || project.status === "Concluído") return false;

  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return projectDate < today;
}

const TASK_DEADLINE_ORDER = Object.freeze({
  overdue: 0,
  today: 1,
  "next-7": 2,
  "next-30": 3,
  later: 4,
  "no-date": 5,
  completed: 6,
});

function normalizeOptionalTaskDueDate(value) {
  const dueDate = String(value ?? "").trim();
  return parseProjectDate(dueDate) ? dueDate : null;
}

function getCalendarDayDifference(firstDate, secondDate) {
  const firstCalendarDay = Date.UTC(firstDate.getFullYear(), firstDate.getMonth(), firstDate.getDate());
  const secondCalendarDay = Date.UTC(secondDate.getFullYear(), secondDate.getMonth(), secondDate.getDate());
  return Math.round((firstCalendarDay - secondCalendarDay) / 86400000);
}

function getTaskDeadlineState(task, today = parseProjectDate(getToday())) {
  const dueDate = parseProjectDate(task?.dueDate);
  if (task?.completed) {
    return { key: "completed", label: "Concluída", dueDate, daysUntil: null, isUrgent: false };
  }
  if (!dueDate) {
    return { key: "no-date", label: "Sem prazo", dueDate: null, daysUntil: null, isUrgent: false };
  }

  const daysUntil = getCalendarDayDifference(dueDate, today);
  if (daysUntil < 0) return { key: "overdue", label: "Atrasada", dueDate, daysUntil, isUrgent: true };
  if (daysUntil === 0) return { key: "today", label: "Vence hoje", dueDate, daysUntil, isUrgent: true };
  if (daysUntil <= 7) return { key: "next-7", label: "Próximos 7 dias", dueDate, daysUntil, isUrgent: false };
  if (daysUntil <= 30) return { key: "next-30", label: "Próximos 30 dias", dueDate, daysUntil, isUrgent: false };
  return { key: "later", label: "Mais adiante", dueDate, daysUntil, isUrgent: false };
}

function getTaskDeadlineRows(projectCollection = projects) {
  const today = parseProjectDate(getToday());
  const rows = [];
  (projectCollection ?? []).forEach((project) => {
    (project.tasks ?? []).forEach((task) => {
      rows.push({ project, task, deadline: getTaskDeadlineState(task, today) });
    });
  });
  return rows;
}

function compareTaskDeadlineRows(firstRow, secondRow) {
  const categoryDifference = TASK_DEADLINE_ORDER[firstRow.deadline.key] - TASK_DEADLINE_ORDER[secondRow.deadline.key];
  if (categoryDifference !== 0) return categoryDifference;
  const firstDueTime = firstRow.deadline.dueDate?.getTime() ?? Number.POSITIVE_INFINITY;
  const secondDueTime = secondRow.deadline.dueDate?.getTime() ?? Number.POSITIVE_INFINITY;
  if (firstDueTime !== secondDueTime) return firstDueTime - secondDueTime;
  const priorityDifference = getPriorityValue(secondRow.project.priority) - getPriorityValue(firstRow.project.priority);
  if (priorityDifference !== 0) return priorityDifference;
  return String(firstRow.task.description ?? "").localeCompare(String(secondRow.task.description ?? ""), "pt-BR", { sensitivity: "base" });
}

function getTaskDeadlineSummary(projectCollection = projects) {
  const allRows = getTaskDeadlineRows(projectCollection);
  const pendingRows = allRows.filter((row) => !row.task.completed).sort(compareTaskDeadlineRows);
  const countByState = (state) => pendingRows.filter((row) => row.deadline.key === state).length;
  return {
    allRows,
    pendingRows,
    overdue: countByState("overdue"),
    today: countByState("today"),
    next7: countByState("next-7"),
    next30: countByState("next-30"),
    later: countByState("later"),
    noDate: countByState("no-date"),
  };
}

function hasPendingTasks(project) {
  return (project.tasks ?? []).some((task) => !task.completed);
}

function needsPriorityAttention(project) {
  return project.priority === "Alta"
    && project.status === "Em andamento"
    && hasPendingTasks(project);
}

function normalizeText(value) {
  return String(value ?? "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase("pt-BR");
}

function getPriorityValue(priority) {
  return { Baixa: 1, Média: 2, Alta: 3 }[priority] ?? 0;
}

function compareByProjectDate(firstProject, secondProject, direction) {
  const firstDate = parseProjectDate(firstProject.date)?.getTime();
  const secondDate = parseProjectDate(secondProject.date)?.getTime();

  if (firstDate === undefined && secondDate === undefined) return 0;
  if (firstDate === undefined) return 1;
  if (secondDate === undefined) return -1;
  return (firstDate - secondDate) * direction;
}

function sortProjects(projectList) {
  return [...projectList].sort((firstProject, secondProject) => {
    let comparison = 0;
    const firstName = String(firstProject.name ?? "");
    const secondName = String(secondProject.name ?? "");

    if (activeSort === "newest") comparison = compareByProjectDate(firstProject, secondProject, -1);
    if (activeSort === "oldest") comparison = compareByProjectDate(firstProject, secondProject, 1);
    if (activeSort === "priority-high") comparison = getPriorityValue(secondProject.priority) - getPriorityValue(firstProject.priority);
    if (activeSort === "priority-low") comparison = getPriorityValue(firstProject.priority) - getPriorityValue(secondProject.priority);
    if (activeSort === "progress-high") comparison = calculateProgress(secondProject) - calculateProgress(firstProject);
    if (activeSort === "progress-low") comparison = calculateProgress(firstProject) - calculateProgress(secondProject);
    if (activeSort === "alphabetical") {
      comparison = firstName.localeCompare(secondName, "pt-BR", { sensitivity: "base" });
    }

    if (comparison !== 0) return comparison;
    return firstName.localeCompare(secondName, "pt-BR", { sensitivity: "base" });
  });
}

function formatClass(value) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/\s+/g, "-");
}

function createActionButton(label, icon, action) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = `icon-action ${action === "delete" ? "delete-action" : ""}`;
  button.setAttribute("aria-label", label);
  button.dataset.action = action;
  button.innerHTML = icon;

  return button;
}

function createTaskDeadlineBadge(deadline) {
  const badge = document.createElement("span");
  badge.className = `task-deadline-badge is-${deadline.key}`;
  badge.textContent = deadline.label;
  return badge;
}

function createTaskDeadlineEditor(project, task) {
  const editor = document.createElement("form");
  editor.className = "task-deadline-editor";
  editor.dataset.taskDeadlineForm = "true";
  editor.dataset.projectId = project.id;
  editor.dataset.taskId = task.id;

  const field = document.createElement("label");
  field.className = "task-deadline-editor-field";
  const fieldLabel = document.createElement("span");
  fieldLabel.textContent = "Prazo";
  const input = document.createElement("input");
  input.type = "date";
  input.name = "taskDueDate";
  input.value = task.dueDate || "";
  input.setAttribute("aria-label", `Prazo da tarefa: ${task.description}`);
  field.append(fieldLabel, input);

  const actions = document.createElement("div");
  actions.className = "task-deadline-editor-actions";
  const saveButton = document.createElement("button");
  saveButton.type = "submit";
  saveButton.className = "task-deadline-save-button";
  saveButton.textContent = "Salvar prazo";

  const removeButton = document.createElement("button");
  removeButton.type = "button";
  removeButton.className = "task-deadline-text-button";
  removeButton.textContent = "Remover prazo";
  removeButton.disabled = !task.dueDate;
  removeButton.dataset.action = "remove-task-deadline";
  removeButton.dataset.projectId = project.id;
  removeButton.dataset.taskId = task.id;

  const cancelButton = document.createElement("button");
  cancelButton.type = "button";
  cancelButton.className = "task-deadline-text-button";
  cancelButton.textContent = "Cancelar";
  cancelButton.dataset.action = "cancel-task-deadline-edit";
  cancelButton.dataset.projectId = project.id;
  cancelButton.dataset.taskId = task.id;

  actions.append(saveButton, removeButton, cancelButton);
  editor.append(field, actions);
  return editor;
}

function openTaskDeadlineEditor(triggerButton, project, task) {
  const taskItem = triggerButton.closest(".task-item");
  if (!taskItem) return;

  const existingEditor = taskItem.querySelector("[data-task-deadline-form]");
  if (existingEditor) {
    existingEditor.elements.taskDueDate?.focus();
    return;
  }

  projectsList.querySelectorAll("[data-task-deadline-form]").forEach((editor) => editor.remove());
  const editor = createTaskDeadlineEditor(project, task);
  taskItem.append(editor);
  editor.elements.taskDueDate?.focus();
}

function setTaskDeadlineEditorSaving(editor) {
  editor.dataset.saving = "true";
  editor.setAttribute("aria-busy", "true");
  editor.querySelectorAll("input, button").forEach((control) => {
    control.disabled = true;
  });
  const saveButton = editor.querySelector("button[type=submit]");
  if (saveButton) saveButton.textContent = "Salvando…";
}

async function saveTaskDeadline(project, task, dueDate, editor) {
  if (editor?.dataset.saving === "true" || !canManageSupabaseData()) return;

  setTaskDeadlineEditorSaving(editor);
  try {
    const remoteTask = await updateRemoteTaskDueDate(task.id, dueDate);
    task.dueDate = String(remoteTask.due_date ?? "");
    renderProjects();
    showDataMessage(task.dueDate ? "Prazo da tarefa atualizado." : "Prazo removido. A tarefa ficou sem prazo.");
  } catch (error) {
    // O prazo em memória só muda após a resposta do Supabase; a renderização restaura o valor original.
    renderProjects();
    showDataMessage(getDataErrorMessage(error, "Não foi possível atualizar o prazo da tarefa. Tente novamente."));
  }
}
function createTaskItem(project, task) {
  const deadline = getTaskDeadlineState(task);
  const item = document.createElement("li");
  item.className = `task-item is-deadline-${deadline.key}`;
  const label = document.createElement("label");
  label.className = "task-label";
  const checkbox = document.createElement("input");
  checkbox.type = "checkbox";
  checkbox.checked = task.completed;
  checkbox.dataset.taskToggle = "true";
  checkbox.dataset.projectId = project.id;
  checkbox.dataset.taskId = task.id;
  checkbox.setAttribute("aria-label", `Marcar tarefa: ${task.description}`);
  const copy = document.createElement("span");
  copy.className = "task-copy";
  const description = document.createElement("span");
  description.className = "task-description";
  if (task.completed) description.classList.add("is-completed");
  description.textContent = task.description;
  const deadlineInfo = document.createElement("span");
  deadlineInfo.className = "task-deadline";
  const deadlineDate = document.createElement("span");
  deadlineDate.className = "task-deadline-date";
  deadlineDate.textContent = task.dueDate ? `Prazo: ${formatDate(task.dueDate)}` : "Sem prazo definido";
  deadlineInfo.append(deadlineDate, createTaskDeadlineBadge(deadline));
  copy.append(description, deadlineInfo);
  label.append(checkbox, copy);
  const actions = document.createElement("div");
  actions.className = "task-actions";
  const editDeadlineButton = document.createElement("button");
  editDeadlineButton.type = "button";
  editDeadlineButton.className = "task-deadline-edit-button";
  editDeadlineButton.textContent = "Editar prazo";
  editDeadlineButton.dataset.action = "edit-task-deadline";
  editDeadlineButton.dataset.projectId = project.id;
  editDeadlineButton.dataset.taskId = task.id;
  editDeadlineButton.setAttribute("aria-label", `Editar prazo da tarefa: ${task.description}`);

  const deleteButton = createActionButton(
    "Excluir tarefa",
    '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M10 11v5M14 11v5M6 7l1 13h10l1-13M9 7V4h6v3" /></svg>',
    "delete-task",
  );
  deleteButton.classList.add("task-delete-button");
  deleteButton.dataset.projectId = project.id;
  deleteButton.dataset.taskId = task.id;
  actions.append(editDeadlineButton, deleteButton);
  item.append(label, actions);
  return item;
}

function createTasksSection(project) {
  const section = document.createElement("section");
  section.className = "tasks-section";
  section.setAttribute("aria-label", `Tarefas do projeto ${project.name}`);
  const tasks = project.tasks ?? [];
  const completedTasks = tasks.filter((task) => task.completed).length;
  const pendingTasks = tasks.length - completedTasks;
  const progress = calculateProgress(project);
  const progressHeader = document.createElement("div");
  progressHeader.className = "progress-header";
  const progressLabel = document.createElement("span");
  progressLabel.textContent = "Progresso";
  const progressValue = document.createElement("strong");
  progressValue.textContent = `${progress}%`;
  progressHeader.append(progressLabel, progressValue);
  const progressBar = document.createElement("div");
  progressBar.className = "progress-bar";
  progressBar.setAttribute("role", "progressbar");
  progressBar.setAttribute("aria-label", `Progresso de ${project.name}`);
  progressBar.setAttribute("aria-valuemin", "0");
  progressBar.setAttribute("aria-valuemax", "100");
  progressBar.setAttribute("aria-valuenow", String(progress));
  const progressFill = document.createElement("span");
  progressFill.style.width = `${progress}%`;
  progressBar.append(progressFill);
  const tasksHeader = document.createElement("div");
  tasksHeader.className = "tasks-header";
  const title = document.createElement("h4");
  title.textContent = "Tarefas";
  const counter = document.createElement("span");
  counter.textContent = `${completedTasks}/${tasks.length} concluídas · ${pendingTasks} pendentes`;
  tasksHeader.append(title, counter);
  const taskList = document.createElement("ul");
  taskList.className = "task-list";
  if (tasks.length === 0) {
    const emptyTask = document.createElement("li");
    emptyTask.className = "empty-task-message";
    emptyTask.textContent = "Nenhuma tarefa adicionada ainda.";
    taskList.append(emptyTask);
  } else {
    taskList.append(...tasks.map((task) => createTaskItem(project, task)));
  }
  const addTaskForm = document.createElement("form");
  addTaskForm.className = "add-task-form";
  addTaskForm.dataset.taskForm = "true";
  addTaskForm.dataset.projectId = project.id;
  const taskInput = document.createElement("input");
  taskInput.className = "task-description-input";
  taskInput.type = "text";
  taskInput.name = "taskDescription";
  taskInput.placeholder = "Adicionar uma tarefa";
  taskInput.setAttribute("aria-label", "Descrição da nova tarefa");
  taskInput.maxLength = 160;
  taskInput.required = true;
  const dueDateField = document.createElement("label");
  dueDateField.className = "task-due-date-field";
  const dueDateLabel = document.createElement("span");
  dueDateLabel.textContent = "Prazo";
  const dueDateInput = document.createElement("input");
  dueDateInput.className = "task-due-date-input";
  dueDateInput.type = "date";
  dueDateInput.name = "taskDueDate";
  dueDateInput.setAttribute("aria-label", "Prazo opcional da nova tarefa");
  dueDateField.append(dueDateLabel, dueDateInput);
  const addButton = document.createElement("button");
  addButton.type = "submit";
  addButton.textContent = "Adicionar";
  addTaskForm.append(taskInput, dueDateField, addButton);
  section.append(progressHeader, progressBar, tasksHeader, taskList, addTaskForm);
  return section;
}
function createProjectCard(project) {
  const card = document.createElement("article");
  card.className = "project-card";
  const overdue = isOverdue(project);
  if (overdue) card.classList.add("is-overdue");

  const header = document.createElement("div");
  header.className = "project-card-header";

  const title = document.createElement("h3");
  title.textContent = project.name;

  const actions = document.createElement("div");
  actions.className = "card-actions";
  actions.append(
    createActionButton(
      "Editar projeto",
      '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 20h4l10.5-10.5a2.8 2.8 0 0 0-4-4L4 16v4Z" /><path d="m13.5 6.5 4 4" /></svg>',
      "edit",
    ),
    createActionButton(
      "Excluir projeto",
      '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M10 11v5M14 11v5M6 7l1 13h10l1-13M9 7V4h6v3" /></svg>',
      "delete",
    ),
  );
  actions.querySelectorAll("button").forEach((button) => {
    button.dataset.id = project.id;
  });
  header.append(title, actions);

  const description = document.createElement("p");
  description.className = "project-description";
  description.textContent = project.description;

  const badges = document.createElement("div");
  badges.className = "project-badges";
  const statusBadge = document.createElement("span");
  statusBadge.className = `badge status-${formatClass(project.status)}`;
  statusBadge.textContent = project.status;
  const priorityBadge = document.createElement("span");
  priorityBadge.className = `badge priority-${formatClass(project.priority)}`;
  priorityBadge.textContent = `Prioridade ${project.priority}`;
  badges.append(statusBadge, priorityBadge);
  if (overdue) {
    const overdueBadge = document.createElement("span");
    overdueBadge.className = "badge overdue-badge";
    overdueBadge.textContent = "Atrasado";
    badges.append(overdueBadge);
  }

  const goal = document.createElement("p");
  goal.className = "project-goal";
  const goalLabel = document.createElement("strong");
  goalLabel.textContent = "Objetivo: ";
  goal.append(goalLabel, project.goal);

  const tasksSection = createTasksSection(project);

  const footer = document.createElement("footer");
  footer.className = "project-card-footer";
  const date = document.createElement("span");
  date.className = "project-date";
  date.textContent = `Data: ${formatDate(project.date)}`;
  footer.append(date);

  card.append(header, description, badges, goal, tasksSection, footer);
  return card;
}

function createAttentionCard(project) {
  const card = document.createElement("article");
  card.className = "attention-card";
  const overdue = isOverdue(project);
  if (overdue) card.classList.add("is-overdue");

  const title = document.createElement("h3");
  title.textContent = project.name;

  const badges = document.createElement("div");
  badges.className = "project-badges";
  const statusBadge = document.createElement("span");
  statusBadge.className = `badge status-${formatClass(project.status)}`;
  statusBadge.textContent = project.status;
  const priorityBadge = document.createElement("span");
  priorityBadge.className = `badge priority-${formatClass(project.priority)}`;
  priorityBadge.textContent = `Prioridade ${project.priority}`;
  badges.append(statusBadge, priorityBadge);
  if (overdue) {
    const overdueBadge = document.createElement("span");
    overdueBadge.className = "badge overdue-badge";
    overdueBadge.textContent = "Atrasado";
    badges.append(overdueBadge);
  }

  const pendingProjectTasks = project.tasks.filter((task) => !task.completed).length;
  const details = document.createElement("p");
  const reasons = [];
  if (needsPriorityAttention(project)) {
    reasons.push(`${pendingProjectTasks} tarefa${pendingProjectTasks === 1 ? "" : "s"} pendente${pendingProjectTasks === 1 ? "" : "s"}`);
  }
  if (overdue) reasons.push(`Data vencida: ${formatDate(project.date)}`);
  const reasonLabel = document.createElement("strong");
  reasonLabel.textContent = reasons.join(" · ");
  details.append(reasonLabel, ` · ${calculateProgress(project)}% de progresso`);

  card.append(title, badges, details);
  return card;
}

function getVisualPercentage(value, total) {
  if (total <= 0) return 0;
  return Math.round((value / total) * 100);
}

function isLowProgressVisualSignal(project) {
  const tasks = project.tasks ?? [];
  return project.status === "Em andamento"
    && tasks.length > 0
    && calculateProgress(project) < 50;
}

function getVisualChartData(projectCollection) {
  const visualProjects = Array.isArray(projectCollection) ? projectCollection : [];
  const allTasks = visualProjects.flatMap((project) => project.tasks ?? []);
  const totalProjectsCount = visualProjects.length;
  const totalTasksCount = allTasks.length;
  const statusItems = [
    { label: "Ideia", className: "visual-status-idea", filter: "Ideia" },
    { label: "Em andamento", className: "visual-status-progress", filter: "Em andamento" },
    { label: "Pausado", className: "visual-status-paused", filter: "Pausado" },
    { label: "Concluído", className: "visual-status-completed", filter: "Concluído" },
  ].map((item) => {
    const count = visualProjects.filter((project) => project.status === item.label).length;
    return { ...item, count, percentage: getVisualPercentage(count, totalProjectsCount) };
  });
  const priorityItems = [
    { label: "Baixa", className: "visual-priority-low", filter: null },
    { label: "Média", className: "visual-priority-medium", filter: null },
    { label: "Alta", className: "visual-priority-high", filter: "high-priority" },
  ].map((item) => {
    const count = visualProjects.filter((project) => project.priority === item.label).length;
    return { ...item, count, percentage: getVisualPercentage(count, totalProjectsCount) };
  });
  const completedTasksCount = allTasks.filter((task) => task.completed).length;

  return {
    projects: visualProjects,
    totalProjects: totalProjectsCount,
    totalTasks: totalTasksCount,
    completedTasks: completedTasksCount,
    pendingTasks: totalTasksCount - completedTasksCount,
    completedTasksPercentage: getVisualPercentage(completedTasksCount, totalTasksCount),
    pendingTasksPercentage: getVisualPercentage(totalTasksCount - completedTasksCount, totalTasksCount),
    overdueProjects: visualProjects.filter(isOverdue).length,
    statusItems,
    priorityItems,
  };
}

function getExecutiveAttentionDetails(project) {
  const taskSummary = getProjectTaskSummary(project);
  const tags = [];
  let score = 0;

  if (isOverdue(project)) {
    tags.push({ label: "Atrasado", className: "is-overdue" });
    score += 8;
  }
  if (needsPriorityAttention(project)) {
    tags.push({ label: "Alta prioridade com pendências", className: "is-priority" });
    score += 5;
  }
  if (project.status === "Em andamento" && taskSummary.pendingTasks > 0) {
    tags.push({ label: "Em andamento com pendências", className: "is-pending" });
    score += 2;
  }
  if (isLowProgressVisualSignal(project)) {
    tags.push({ label: "Baixo progresso", className: "is-low-progress" });
    score += 1;
  }

  return {
    project,
    tags,
    score,
    taskSummary,
  };
}

function sortProjectsForVisuals(projectCollection) {
  return [...projectCollection]
    .map(getExecutiveAttentionDetails)
    .sort((firstItem, secondItem) => {
      if (secondItem.score !== firstItem.score) return secondItem.score - firstItem.score;
      if (firstItem.taskSummary.progress !== secondItem.taskSummary.progress) {
        return firstItem.taskSummary.progress - secondItem.taskSummary.progress;
      }
      return String(firstItem.project.name ?? "").localeCompare(
        String(secondItem.project.name ?? ""),
        "pt-BR",
        { sensitivity: "base" },
      );
    });
}

function createDistributionRow(item, canFilterProjects, isDominant = false) {
  const isInteractive = canFilterProjects && item.filter;
  const row = document.createElement(isInteractive ? "button" : "div");
  row.className = `distribution-row ${item.className}${isInteractive ? " is-interactive" : ""}${isDominant ? " is-dominant" : ""}`;
  row.setAttribute(
    "aria-label",
    `${item.label}: ${item.count} projeto${item.count === 1 ? "" : "s"}, ${item.percentage}%${isDominant ? ", maior concentração do conjunto" : ""}`,
  );
  if (isInteractive) {
    row.type = "button";
    row.dataset.dashboardProjectFilter = item.filter;
  }

  const label = document.createElement("span");
  label.className = "distribution-label";
  label.textContent = item.label;
  const track = document.createElement("span");
  track.className = "distribution-track";
  track.setAttribute("aria-hidden", "true");
  const fill = document.createElement("span");
  fill.style.setProperty("--chart-share", `${item.percentage}%`);
  track.append(fill);
  const value = document.createElement("span");
  value.className = "distribution-value";
  value.textContent = `${item.count} · ${item.percentage}%`;
  row.append(label, track, value);
  return row;
}

function renderDistributionChart(chartElement, emptyElement, items, totalProjectsCount, canFilterProjects) {
  if (!chartElement || !emptyElement) return;

  const hasProjects = totalProjectsCount > 0;
  chartElement.hidden = !hasProjects;
  emptyElement.hidden = hasProjects;
  const predominantCount = hasProjects ? Math.max(...items.map((item) => item.count)) : 0;
  chartElement.replaceChildren(...(hasProjects
    ? items.map((item) => createDistributionRow(
      item,
      canFilterProjects,
      predominantCount > 0 && item.count === predominantCount,
    ))
    : []));
}

function createTaskLegendItem(label, count, percentage) {
  const item = document.createElement("li");
  const text = document.createElement("span");
  text.textContent = label;
  const value = document.createElement("strong");
  value.textContent = `${count} · ${percentage}%`;
  text.append(value);
  item.append(text);
  return item;
}

function renderTaskCompositionChart(chartElement, emptyElement, visualData) {
  if (!chartElement || !emptyElement) return;

  const hasTasks = visualData.totalTasks > 0;
  chartElement.hidden = !hasTasks;
  emptyElement.hidden = hasTasks;
  if (!hasTasks) {
    chartElement.replaceChildren();
    return;
  }

  const donut = document.createElement("div");
  donut.className = "task-donut";
  donut.style.setProperty("--completed-share", `${visualData.completedTasksPercentage}%`);
  donut.setAttribute("aria-hidden", "true");
  const donutCenter = document.createElement("div");
  donutCenter.className = "task-donut-center";
  const total = document.createElement("strong");
  total.textContent = String(visualData.totalTasks);
  const totalLabel = document.createElement("span");
  totalLabel.textContent = "tarefas";
  donutCenter.append(total, totalLabel);
  donut.append(donutCenter);

  const legend = document.createElement("ul");
  legend.className = "task-chart-legend";
  legend.append(
    createTaskLegendItem("Concluídas", visualData.completedTasks, visualData.completedTasksPercentage),
    createTaskLegendItem("Pendentes", visualData.pendingTasks, visualData.pendingTasksPercentage),
  );
  chartElement.replaceChildren(donut, legend);
}

function createProjectProgressRow(item) {
  const row = document.createElement("article");
  row.className = `project-progress-row${item.score > 0 ? " is-attention" : ""}`;
  const name = document.createElement("strong");
  name.className = "project-progress-name";
  name.textContent = item.project.name;
  const value = document.createElement("span");
  value.className = "project-progress-value";
  value.textContent = `${item.taskSummary.progress}%`;
  const details = document.createElement("small");
  details.textContent = `${item.project.status} · ${item.taskSummary.completedTasks}/${item.taskSummary.totalTasks} tarefas concluídas`;
  const track = document.createElement("div");
  track.className = "project-progress-track";
  track.setAttribute("aria-label", `Progresso de ${item.project.name}: ${item.taskSummary.progress}%`);
  const fill = document.createElement("span");
  fill.style.setProperty("--project-progress", `${item.taskSummary.progress}%`);
  track.append(fill);
  row.append(name, value, details, track);
  return row;
}

function renderProjectProgressComparison(listElement, emptyElement, projectCollection) {
  if (!listElement || !emptyElement) return;

  const sortedProjects = sortProjectsForVisuals(projectCollection);
  const hasProjects = sortedProjects.length > 0;
  listElement.hidden = !hasProjects;
  emptyElement.hidden = hasProjects;
  listElement.replaceChildren(...sortedProjects.map(createProjectProgressRow));
}

function createExecutiveAttentionItem(item) {
  const row = document.createElement("article");
  row.className = "executive-attention-item";
  const copy = document.createElement("div");
  copy.className = "executive-attention-copy";
  const name = document.createElement("strong");
  name.textContent = item.project.name;
  const details = document.createElement("span");
  details.textContent = `${item.taskSummary.pendingTasks} tarefa${item.taskSummary.pendingTasks === 1 ? "" : "s"} pendente${item.taskSummary.pendingTasks === 1 ? "" : "s"} · ${item.project.status}`;
  copy.append(name, details);
  const progress = document.createElement("span");
  progress.className = "executive-attention-progress";
  progress.textContent = `${item.taskSummary.progress}%`;
  const tags = document.createElement("div");
  tags.className = "executive-attention-tags";
  item.tags.forEach((tag) => {
    const tagElement = document.createElement("span");
    tagElement.className = `executive-attention-tag ${tag.className}`;
    tagElement.textContent = tag.label;
    tags.append(tagElement);
  });
  row.append(copy, progress, tags);
  return row;
}

function renderExecutiveAttention(listElement, emptyElement, projectCollection) {
  if (!listElement || !emptyElement) return;

  const attentionItems = sortProjectsForVisuals(projectCollection).filter((item) => item.tags.length > 0);
  const hasAttentionItems = attentionItems.length > 0;
  listElement.hidden = !hasAttentionItems;
  emptyElement.hidden = hasAttentionItems;
  listElement.replaceChildren(...attentionItems.map(createExecutiveAttentionItem));
}

function renderVisualSuite(projectCollection, elements, canFilterProjects = false) {
  const visualData = getVisualChartData(projectCollection);
  renderDistributionChart(
    elements.statusChart,
    elements.statusEmpty,
    visualData.statusItems,
    visualData.totalProjects,
    canFilterProjects,
  );
  renderDistributionChart(
    elements.priorityChart,
    elements.priorityEmpty,
    visualData.priorityItems,
    visualData.totalProjects,
    canFilterProjects,
  );
  renderTaskCompositionChart(elements.taskChart, elements.taskEmpty, visualData);
  renderProjectProgressComparison(elements.progressList, elements.progressEmpty, visualData.projects);
  renderExecutiveAttention(elements.attentionList, elements.attentionEmpty, visualData.projects);
  return visualData;
}

function renderDashboardVisuals() {
  const visualData = renderVisualSuite(projects, {
    statusChart: dashboardStatusChart,
    statusEmpty: dashboardStatusEmpty,
    priorityChart: dashboardPriorityChart,
    priorityEmpty: dashboardPriorityEmpty,
    taskChart: dashboardTaskChart,
    taskEmpty: dashboardTaskEmpty,
    progressList: dashboardProjectProgressList,
    progressEmpty: dashboardProjectProgressEmpty,
    attentionList: dashboardExecutiveAttention,
    attentionEmpty: dashboardExecutiveAttentionEmpty,
  }, true);
  if (dashboardOverdueCount) dashboardOverdueCount.textContent = String(visualData.overdueProjects);
}

function getReportExecutiveInsight(report) {
  const filteredProjects = report.filteredProjects;
  const overdueProjects = filteredProjects.filter(isOverdue);
  const overdueHighPriorityProjects = overdueProjects.filter((project) => project.priority === "Alta");
  const priorityAttentionProjects = filteredProjects.filter(needsPriorityAttention);
  const lowProgressProjects = filteredProjects.filter(isLowProgressVisualSignal);
  const activePendingProjects = filteredProjects.filter((project) => (
    project.status === "Em andamento" && hasPendingTasks(project)
  ));
  const formatCount = (count) => `${count} projeto${count === 1 ? "" : "s"}`;

  if (!filteredProjects.length) {
    return { positive: false, text: "Nenhum projeto corresponde aos filtros selecionados." };
  }
  if (overdueHighPriorityProjects.length) {
    const count = overdueHighPriorityProjects.length;
    return {
      positive: false,
      text: `Atenção necessária: ${formatCount(count)} ${count === 1 ? "está atrasado e classificado como alta prioridade." : "estão atrasados e classificados como alta prioridade."}`,
    };
  }
  if (overdueProjects.length) {
    const count = overdueProjects.length;
    return {
      positive: false,
      text: `Atenção necessária: ${formatCount(count)} ${count === 1 ? "está atrasado." : "estão atrasados."}`,
    };
  }
  if (priorityAttentionProjects.length) {
    const count = priorityAttentionProjects.length;
    return {
      positive: false,
      text: `Atenção necessária: ${formatCount(count)} ${count === 1 ? "de alta prioridade está com tarefas pendentes." : "de alta prioridade estão com tarefas pendentes."}`,
    };
  }
  if (lowProgressProjects.length) {
    const count = lowProgressProjects.length;
    return {
      positive: false,
      text: `Atenção necessária: ${formatCount(count)} em andamento ${count === 1 ? "está com progresso abaixo de 50%." : "estão com progresso abaixo de 50%."}`,
    };
  }
  if (activePendingProjects.length) {
    const count = activePendingProjects.length;
    return {
      positive: false,
      text: `Acompanhamento: ${formatCount(count)} em andamento ${count === 1 ? "tem tarefa pendente." : "têm tarefas pendentes."}`,
    };
  }
  return {
    positive: true,
    text: "Visão positiva: não há projetos atrasados nem itens que precisem de atenção no conjunto filtrado.",
  };
}

function renderReportExecutiveInsight(report) {
  if (!reportsExecutiveInsight || !reportsExecutiveInsightText) return;

  const insight = getReportExecutiveInsight(report);
  reportsExecutiveInsightText.textContent = insight.text;
  reportsExecutiveInsight.classList.toggle("is-positive", insight.positive);
}
function renderReportVisuals(report) {
  renderVisualSuite(report.filteredProjects, {
    statusChart: reportStatusChart,
    statusEmpty: reportStatusEmpty,
    priorityChart: reportPriorityChart,
    priorityEmpty: reportPriorityEmpty,
    taskChart: reportTaskChart,
    taskEmpty: reportTaskEmpty,
    progressList: reportProjectProgressList,
    progressEmpty: reportProjectProgressEmpty,
    attentionList: reportExecutiveAttention,
    attentionEmpty: reportExecutiveAttentionEmpty,
  });
  renderReportExecutiveInsight(report);
}

function focusVisualDestination(selector) {
  const destination = document.querySelector(selector);
  if (!destination) return;
  destination.setAttribute("tabindex", "-1");
  window.setTimeout(() => destination.focus({ preventScroll: true }), 0);
}

function applyDashboardProjectFilter(filter) {
  if (!filter) return;
  setActiveFilter(filter);
  window.location.hash = "#projetos";
  sidebar.classList.remove("is-open");
  focusVisualDestination("#recentes-titulo");
}

function openOverdueReportsFromDashboard() {
  reportFilters = { ...defaultReportFilters, deadline: "overdue" };
  reportStartDateInput.value = "";
  reportEndDateInput.value = "";
  reportStatusSelect.value = "all";
  reportPrioritySelect.value = "all";
  reportDeadlineSelect.value = "overdue";
  renderReports();
  window.location.hash = "#relatorios";
  sidebar.classList.remove("is-open");
  focusVisualDestination("#reports-title");
}
function getDashboardData() {
  const allTasks = projects.flatMap((project) => project.tasks ?? []);
  const completedTasksCount = allTasks.filter((task) => task.completed).length;
  const pendingTasksCount = allTasks.length - completedTasksCount;
  const attentionProjects = projects.filter((project) => (
    needsPriorityAttention(project) || isOverdue(project)
  ));
  const averageProgressValue = projects.length === 0
    ? 0
    : Math.round(projects.reduce((total, project) => total + calculateProgress(project), 0) / projects.length);
  const deadlineSummary = getTaskDeadlineSummary(projects);

  return {
    totalProjects: projects.length,
    ideaProjects: projects.filter((project) => project.status === "Ideia").length,
    inProgressProjects: projects.filter((project) => project.status === "Em andamento").length,
    pausedProjects: projects.filter((project) => project.status === "Pausado").length,
    completedProjects: projects.filter((project) => project.status === "Concluído").length,
    totalTasks: allTasks.length,
    completedTasks: completedTasksCount,
    pendingTasks: pendingTasksCount,
    averageProgress: averageProgressValue,
    attentionProjects,
    deadlineSummary,
  };
}

function createDashboardCommitmentItem(row) {
  const item = document.createElement("article");
  item.className = `dashboard-commitment-item is-${row.deadline.key}`;
  const copy = document.createElement("div");
  copy.className = "dashboard-commitment-copy";
  const title = document.createElement("strong");
  title.textContent = row.task.description;
  const details = document.createElement("span");
  details.textContent = `${row.project.name} · ${row.task.dueDate ? formatDate(row.task.dueDate) : "Sem prazo"}`;
  copy.append(title, details);
  item.append(copy, createTaskDeadlineBadge(row.deadline));
  return item;
}

function renderDashboardCommitments(deadlineSummary) {
  if (!dashboardUpcomingCommitments || !dashboardUpcomingCommitmentsEmpty) return;
  const urgentRows = deadlineSummary.pendingRows.slice(0, 4);
  const hasCommitments = urgentRows.length > 0;
  dashboardUpcomingCommitments.hidden = !hasCommitments;
  dashboardUpcomingCommitmentsEmpty.hidden = hasCommitments;
  dashboardUpcomingCommitments.replaceChildren(...urgentRows.map(createDashboardCommitmentItem));
}

function createAgendaBadge(text, className) {
  const badge = document.createElement("span");
  badge.className = className;
  badge.textContent = text;
  return badge;
}

function createAgendaCommitmentItem(row) {
  const item = document.createElement("article");
  item.className = `agenda-commitment-item is-${row.deadline.key}`;
  const copy = document.createElement("div");
  copy.className = "agenda-commitment-copy";
  const taskName = document.createElement("strong");
  taskName.textContent = row.task.description;
  const projectName = document.createElement("span");
  projectName.textContent = `${row.project.name} · ${row.task.dueDate ? `Prazo: ${formatDate(row.task.dueDate)}` : "Sem prazo definido"}`;
  copy.append(taskName, projectName);
  const metadata = document.createElement("div");
  metadata.className = "agenda-commitment-meta";
  metadata.append(
    createTaskDeadlineBadge(row.deadline),
    createAgendaBadge(`Prioridade ${row.project.priority}`, `badge priority-${formatClass(row.project.priority)}`),
    createAgendaBadge(row.project.status, `badge status-${formatClass(row.project.status)}`),
  );
  item.append(copy, metadata);
  return item;
}

function renderAgenda() {
  if (!agendaUpcomingCommitments || !agendaUpcomingEmpty) return;
  const deadlineSummary = getTaskDeadlineSummary(projects);
  if (agendaOverdueTasks) agendaOverdueTasks.textContent = String(deadlineSummary.overdue);
  if (agendaDueTodayTasks) agendaDueTodayTasks.textContent = String(deadlineSummary.today);
  if (agendaNextSevenTasks) agendaNextSevenTasks.textContent = String(deadlineSummary.next7);
  if (agendaNextThirtyTasks) agendaNextThirtyTasks.textContent = String(deadlineSummary.next30);
  if (agendaNoDateTasks) agendaNoDateTasks.textContent = String(deadlineSummary.noDate);
  if (agendaPendingCount) {
    agendaPendingCount.textContent = deadlineSummary.pendingRows.length
      ? `${deadlineSummary.pendingRows.length} tarefa${deadlineSummary.pendingRows.length === 1 ? "" : "s"} pendente${deadlineSummary.pendingRows.length === 1 ? "" : "s"}`
      : "Nenhuma tarefa pendente";
  }
  const hasCommitments = deadlineSummary.pendingRows.length > 0;
  agendaUpcomingCommitments.hidden = !hasCommitments;
  agendaUpcomingEmpty.hidden = hasCommitments;
  agendaUpcomingCommitments.replaceChildren(...deadlineSummary.pendingRows.map(createAgendaCommitmentItem));
}

function renderAttentionProjects(attentionProjects) {
  const hasAttentionProjects = attentionProjects.length > 0;
  attentionEmpty.hidden = hasAttentionProjects;
  attentionProjectsList.hidden = !hasAttentionProjects;
  attentionProjectsList.replaceChildren(...attentionProjects.map(createAttentionCard));
  attentionCount.textContent = hasAttentionProjects
    ? `${attentionProjects.length} projeto${attentionProjects.length === 1 ? "" : "s"}`
    : "Nenhum projeto";
}

function updateDashboard() {
  const dashboard = getDashboardData();

  totalProjects.textContent = dashboard.totalProjects;
  ideaProjects.textContent = dashboard.ideaProjects;
  inProgressProjects.textContent = dashboard.inProgressProjects;
  pausedProjects.textContent = dashboard.pausedProjects;
  completedProjects.textContent = dashboard.completedProjects;
  totalTasks.textContent = dashboard.totalTasks;
  completedTasks.textContent = dashboard.completedTasks;
  pendingTasks.textContent = dashboard.pendingTasks;
  averageProgress.textContent = `${dashboard.averageProgress}%`;
  averageProgressBar.style.width = `${dashboard.averageProgress}%`;
  overviewTotalTasks.textContent = dashboard.totalTasks;
  overviewCompletedTasks.textContent = dashboard.completedTasks;
  overviewPendingTasks.textContent = dashboard.pendingTasks;
  renderAttentionProjects(dashboard.attentionProjects);
  if (dashboardOverdueTasks) dashboardOverdueTasks.textContent = String(dashboard.deadlineSummary.overdue);
  if (dashboardDueTodayTasks) dashboardDueTodayTasks.textContent = String(dashboard.deadlineSummary.today);
  if (dashboardNextSevenTasks) dashboardNextSevenTasks.textContent = String(dashboard.deadlineSummary.next7);
  renderDashboardCommitments(dashboard.deadlineSummary);
  renderDashboardVisuals();
}

function getFilteredProjects() {
  let filteredProjects = projects;

  if (activeFilter === "high-priority") {
    filteredProjects = filteredProjects.filter((project) => project.priority === "Alta");
  } else if (activeFilter !== "all") {
    filteredProjects = filteredProjects.filter((project) => project.status === activeFilter);
  }

  const normalizedSearch = normalizeText(activeSearch.trim());
  if (normalizedSearch) {
    filteredProjects = filteredProjects.filter((project) => (
      normalizeText(project.name).includes(normalizedSearch)
    ));
  }

  return sortProjects(filteredProjects);
}

function setActiveFilter(filter) {
  activeFilter = filter;
  filterButtons.forEach((button) => {
    const isActive = button.dataset.filter === activeFilter;
    button.classList.toggle("is-active", isActive);
    button.setAttribute("aria-pressed", String(isActive));
  });
  renderProjects();
}

function clearProjectControls() {
  activeFilter = "all";
  activeSearch = "";
  activeSort = "newest";
  projectSearch.value = "";
  projectSort.value = "newest";
  filterButtons.forEach((button) => {
    const isActive = button.dataset.filter === "all";
    button.classList.toggle("is-active", isActive);
    button.setAttribute("aria-pressed", String(isActive));
  });
  renderProjects();
}

function getProjectTaskSummary(project) {
  const tasks = project.tasks ?? [];
  const completedTasks = tasks.filter((task) => task.completed).length;

  return {
    totalTasks: tasks.length,
    completedTasks,
    pendingTasks: tasks.length - completedTasks,
    progress: calculateProgress(project),
  };
}

function formatReportCount(count, singular, plural = `${singular}s`) {
  return `${count} ${count === 1 ? singular : plural}`;
}

function refreshReportProjectOptions() {
  if (!reportProjectSelect) return;

  const requestedProjectId = reportFilters.projectId;
  const projectOptions = [...projects].sort((firstProject, secondProject) => (
    String(firstProject.name ?? "").localeCompare(String(secondProject.name ?? ""), "pt-BR", { sensitivity: "base" })
  ));
  const options = document.createDocumentFragment();
  const allOption = document.createElement("option");
  allOption.value = "all";
  allOption.textContent = "Todos";
  options.append(allOption);

  projectOptions.forEach((project) => {
    const option = document.createElement("option");
    option.value = String(project.id);
    option.textContent = project.name;
    options.append(option);
  });

  reportProjectSelect.replaceChildren(options);
  const selectedProjectStillExists = projectOptions.some((project) => String(project.id) === requestedProjectId);
  if (requestedProjectId !== "all" && !selectedProjectStillExists) {
    reportFilters.projectId = "all";
  }
  reportProjectSelect.value = reportFilters.projectId;
}

function projectMatchesReportFilters(project) {
  const projectDate = parseProjectDate(project.date);
  const startDate = parseProjectDate(reportFilters.startDate);
  const endDate = parseProjectDate(reportFilters.endDate);

  if (startDate && (!projectDate || projectDate < startDate)) return false;
  if (endDate && (!projectDate || projectDate > endDate)) return false;
  if (reportFilters.status !== "all" && project.status !== reportFilters.status) return false;
  if (reportFilters.priority !== "all" && project.priority !== reportFilters.priority) return false;
  if (reportFilters.projectId !== "all" && String(project.id) !== reportFilters.projectId) return false;
  if (reportFilters.deadline === "overdue" && !isOverdue(project)) return false;
  if (reportFilters.deadline === "on-time" && (!projectDate || isOverdue(project))) return false;

  return true;
}

function getReportProjects() {
  return projects
    .filter(projectMatchesReportFilters)
    .sort((firstProject, secondProject) => {
      const dateComparison = compareByProjectDate(firstProject, secondProject, -1);
      if (dateComparison !== 0) return dateComparison;
      return String(firstProject.name ?? "").localeCompare(String(secondProject.name ?? ""), "pt-BR", { sensitivity: "base" });
    });
}

function getReportData() {
  const filteredProjects = getReportProjects();
  const taskRows = [];
  const attentionProjects = filteredProjects.filter((project) => (
    isOverdue(project) || needsPriorityAttention(project)
  ));
  const allTasks = filteredProjects.flatMap((project) => project.tasks ?? []);
  const completedTasksCount = allTasks.filter((task) => task.completed).length;
  const averageProgressValue = filteredProjects.length === 0
    ? 0
    : Math.round(filteredProjects.reduce((total, project) => total + calculateProgress(project), 0) / filteredProjects.length);

  filteredProjects.forEach((project) => {
    (project.tasks ?? []).forEach((task) => {
      taskRows.push({ project, task });
    });
  });

  taskRows.sort((firstRow, secondRow) => {
    const projectComparison = String(firstRow.project.name ?? "").localeCompare(
      String(secondRow.project.name ?? ""),
      "pt-BR",
      { sensitivity: "base" },
    );
    if (projectComparison !== 0) return projectComparison;
    return String(firstRow.task.description ?? "").localeCompare(
      String(secondRow.task.description ?? ""),
      "pt-BR",
      { sensitivity: "base" },
    );
  });

  return {
    filteredProjects,
    taskRows,
    attentionProjects,
    metrics: {
      totalProjects: filteredProjects.length,
      ideaProjects: filteredProjects.filter((project) => project.status === "Ideia").length,
      inProgressProjects: filteredProjects.filter((project) => project.status === "Em andamento").length,
      pausedProjects: filteredProjects.filter((project) => project.status === "Pausado").length,
      completedProjects: filteredProjects.filter((project) => project.status === "Concluído").length,
      overdueProjects: filteredProjects.filter(isOverdue).length,
      totalTasks: allTasks.length,
      completedTasks: completedTasksCount,
      pendingTasks: allTasks.length - completedTasksCount,
      averageProgress: `${averageProgressValue}%`,
    },
    executive: {
      activeProjects: filteredProjects.filter((project) => project.status === "Em andamento").length,
      overdueProjects: filteredProjects.filter(isOverdue).length,
      pendingTasks: allTasks.length - completedTasksCount,
      averageProgress: `${averageProgressValue}%`,
      highPriorityProjects: filteredProjects.filter((project) => project.priority === "Alta").length,
      attentionProjects: attentionProjects.length,
    },
  };
}

function setReportMetrics(selector, values) {
  document.querySelectorAll(selector).forEach((element) => {
    const value = values[element.dataset.reportMetric ?? element.dataset.executiveMetric];
    element.textContent = value ?? "0";
  });
}

function getReportFilterSummary(projectCount) {
  const hasFilters = Object.values(reportFilters).some((value) => value !== "" && value !== "all");
  if (projectCount === 0) return "Nenhum projeto encontrado";
  return hasFilters
    ? `${formatReportCount(projectCount, "projeto")} com filtros aplicados`
    : `${formatReportCount(projectCount, "projeto")} da sua conta`;
}

function createReportTextCell(text, className = "") {
  const cell = document.createElement("td");
  if (className) cell.className = className;
  cell.textContent = text;
  return cell;
}

function createReportBadge(text, className) {
  const badge = document.createElement("span");
  badge.className = className;
  badge.textContent = text;
  return badge;
}

function createReportProjectRow(project) {
  const row = document.createElement("tr");
  const taskSummary = getProjectTaskSummary(project);
  const projectDate = parseProjectDate(project.date);
  const overdue = isOverdue(project);

  const statusCell = document.createElement("td");
  statusCell.append(createReportBadge(project.status, `badge status-${formatClass(project.status)}`));
  const priorityCell = document.createElement("td");
  priorityCell.append(createReportBadge(project.priority, `badge priority-${formatClass(project.priority)}`));
  const deadlineCell = document.createElement("td");
  const deadline = document.createElement("span");
  deadline.className = "report-deadline";
  if (!projectDate) {
    deadline.classList.add("is-no-date");
    deadline.textContent = "Sem data";
  } else if (overdue) {
    deadline.classList.add("is-overdue");
    deadline.textContent = "Atrasado";
  } else if (project.status === "Concluído") {
    deadline.textContent = "Concluído";
  } else {
    deadline.textContent = "Em dia";
  }
  deadlineCell.append(deadline);

  const progressCell = document.createElement("td");
  progressCell.className = "report-progress-cell";
  const progressLabel = document.createElement("span");
  progressLabel.className = "report-progress-label";
  progressLabel.textContent = `${taskSummary.progress}%`;
  const progressTrack = document.createElement("div");
  progressTrack.className = "report-progress-track";
  progressTrack.setAttribute("aria-label", `Progresso de ${project.name}: ${taskSummary.progress}%`);
  const progressFill = document.createElement("span");
  progressFill.style.width = `${taskSummary.progress}%`;
  progressTrack.append(progressFill);
  progressCell.append(progressLabel, progressTrack);

  row.append(
    createReportTextCell(project.name, "report-project-name"),
    createReportTextCell(project.description || "—", "report-description-cell"),
    createReportTextCell(project.goal || "—", "report-goal-cell"),
    statusCell,
    priorityCell,
    createReportTextCell(formatDate(project.date), "report-date-cell"),
    deadlineCell,
    createReportTextCell(String(taskSummary.totalTasks), "report-count-cell"),
    createReportTextCell(String(taskSummary.completedTasks), "report-count-cell"),
    createReportTextCell(String(taskSummary.pendingTasks), "report-count-cell"),
    progressCell,
  );
  return row;
}

function createReportTaskRow({ project, task }) {
  const row = document.createElement("tr");
  const statusCell = document.createElement("td");
  statusCell.append(createReportBadge(
    task.completed ? "Concluída" : "Pendente",
    `report-task-status${task.completed ? " is-completed" : ""}`,
  ));
  const priorityCell = document.createElement("td");
  priorityCell.append(createReportBadge(project.priority, `badge priority-${formatClass(project.priority)}`));

  row.append(
    createReportTextCell(project.name, "report-project-name"),
    createReportTextCell(task.description, "report-task-name"),
    statusCell,
    createReportTextCell(formatDate(project.date), "report-date-cell"),
    priorityCell,
  );
  return row;
}

function getReportAttentionReason(project) {
  const reasons = [];
  if (isOverdue(project)) reasons.push("data vencida");
  if (needsPriorityAttention(project)) {
    const { pendingTasks } = getProjectTaskSummary(project);
    reasons.push(`alta prioridade · ${pendingTasks} pendente${pendingTasks === 1 ? "" : "s"}`);
  }
  return reasons.join(" · ");
}

function createReportAttentionItem(project) {
  const item = document.createElement("article");
  item.className = "report-attention-item";
  const name = document.createElement("strong");
  name.textContent = project.name;
  const reason = document.createElement("span");
  reason.textContent = getReportAttentionReason(project);
  item.append(name, reason);
  return item;
}

function renderReports() {
  if (!reportsFilterForm) return;

  refreshReportProjectOptions();
  const report = getReportData();
  const hasProjects = report.filteredProjects.length > 0;
  const hasTasks = report.taskRows.length > 0;
  const hasAttentionProjects = report.attentionProjects.length > 0;

  setReportMetrics("[data-report-metric]", report.metrics);
  setReportMetrics("[data-executive-metric]", report.executive);
  reportFilterSummaryElement.textContent = getReportFilterSummary(report.filteredProjects.length);
  reportProjectsCount.textContent = formatReportCount(report.filteredProjects.length, "projeto");
  reportTasksCount.textContent = formatReportCount(report.taskRows.length, "tarefa");

  reportProjectsBody.replaceChildren(...report.filteredProjects.map(createReportProjectRow));
  reportTasksBody.replaceChildren(...report.taskRows.map(createReportTaskRow));
  reportProjectsTableWrap.hidden = !hasProjects;
  reportTasksTableWrap.hidden = !hasTasks;
  reportProjectsEmpty.hidden = hasProjects;
  reportTasksEmpty.hidden = hasTasks;

  reportAttentionList.hidden = !hasAttentionProjects;
  reportAttentionEmpty.hidden = hasAttentionProjects;
  reportAttentionList.replaceChildren(...report.attentionProjects.map(createReportAttentionItem));
  renderReportVisuals(report);
}

function syncReportFilters() {
  reportFilters = {
    startDate: reportStartDateInput.value,
    endDate: reportEndDateInput.value,
    status: reportStatusSelect.value,
    priority: reportPrioritySelect.value,
    projectId: reportProjectSelect.value,
    deadline: reportDeadlineSelect.value,
  };
  renderReports();
}

function clearReportFilters() {
  reportFilters = { ...defaultReportFilters };
  reportsFilterForm.reset();
  renderReports();
}

function updateNavigationState() {
  const activeHash = window.location.hash || "#inicio";
  navigationLinks.forEach((link) => {
    const isActive = link.getAttribute("href") === activeHash;
    link.classList.toggle("active", isActive);
    if (isActive) {
      link.setAttribute("aria-current", "page");
    } else {
      link.removeAttribute("aria-current");
    }
  });
}
function showReportMessage(message, type = "info") {
  if (typeof window.showAppMessage === "function") {
    window.showAppMessage(message, type);
    return;
  }
  showDataMessage(message);
}

function setExcelExportLoading(isLoading) {
  if (!exportExcelButton) return;

  if (isLoading) {
    exportExcelButton.dataset.idleLabel = exportExcelButton.textContent.trim();
    exportExcelButton.textContent = "Gerando Excel…";
    exportExcelButton.classList.add("is-loading");
  } else {
    exportExcelButton.textContent = exportExcelButton.dataset.idleLabel || "Exportar Excel";
    exportExcelButton.classList.remove("is-loading");
  }

  exportExcelButton.disabled = isLoading;
  exportExcelButton.setAttribute("aria-busy", String(isLoading));
  reportsFilterForm?.querySelectorAll("input, select, button").forEach((control) => {
    control.disabled = isLoading;
  });
  reportsFilterForm?.setAttribute("aria-busy", String(isLoading));
}

function loadLocalSheetJs() {
  if (window.XLSX) return Promise.resolve(window.XLSX);
  if (sheetJsLoadingPromise) return sheetJsLoadingPromise;

  sheetJsLoadingPromise = new Promise((resolve, reject) => {
    const sheetJsScript = document.createElement("script");
    sheetJsScript.src = "./vendor/xlsx.full.min.js";
    sheetJsScript.async = true;
    sheetJsScript.onload = () => {
      if (window.XLSX) {
        resolve(window.XLSX);
      } else {
        reject(new Error("A biblioteca local para exportação não foi inicializada."));
      }
    };
    sheetJsScript.onerror = () => reject(new Error("Não foi possível carregar a biblioteca local para exportação."));
    document.head.append(sheetJsScript);
  }).catch((error) => {
    sheetJsLoadingPromise = null;
    throw error;
  });

  return sheetJsLoadingPromise;
}

function getSafeExcelText(value) {
  const text = String(value ?? "");
  return /^\s*[=+\-@]/.test(text) ? `'${text}` : text;
}

function getReportDeadlineLabel(project) {
  if (!parseProjectDate(project.date)) return "Sem data";
  return isOverdue(project) ? "Atrasado" : "Dentro do prazo";
}

function getExcelProjectRow(project) {
  const taskSummary = getProjectTaskSummary(project);
  return [
    getSafeExcelText(project.name),
    getSafeExcelText(project.description),
    getSafeExcelText(project.goal),
    getSafeExcelText(project.status),
    getSafeExcelText(project.priority),
    formatDate(project.date),
    getReportDeadlineLabel(project),
    taskSummary.totalTasks,
    taskSummary.completedTasks,
    taskSummary.pendingTasks,
    taskSummary.progress / 100,
  ];
}

function getExcelTaskRow({ project, task }) {
  return [
    getSafeExcelText(project.name),
    getSafeExcelText(task.description),
    task.completed ? "Concluída" : "Pendente",
    formatDate(project.date),
    getSafeExcelText(project.priority),
  ];
}

function getExcelFilterRows() {
  const selectedProject = projects.find((project) => String(project.id) === reportFilters.projectId);
  const period = reportFilters.startDate && reportFilters.endDate
    ? `${formatDate(reportFilters.startDate)} até ${formatDate(reportFilters.endDate)}`
    : reportFilters.startDate
      ? `A partir de ${formatDate(reportFilters.startDate)}`
      : reportFilters.endDate
        ? `Até ${formatDate(reportFilters.endDate)}`
        : "Todos os períodos";
  const deadlines = {
    all: "Todos",
    overdue: "Somente atrasados",
    "on-time": "Somente dentro do prazo",
  };

  return [
    ["Período", period],
    ["Status", reportFilters.status === "all" ? "Todos" : reportFilters.status],
    ["Prioridade", reportFilters.priority === "all" ? "Todas" : reportFilters.priority],
    ["Projeto", selectedProject ? getSafeExcelText(selectedProject.name) : "Todos"],
    ["Atraso", deadlines[reportFilters.deadline] ?? "Todos"],
  ];
}

function createExcelTableWorksheet(XLSX, headers, rows, columnWidths, percentageColumnIndex = null) {
  const worksheet = XLSX.utils.aoa_to_sheet([headers, ...rows]);
  worksheet["!cols"] = columnWidths.map((width) => ({ wch: width }));

  if (rows.length > 0) {
    worksheet["!autofilter"] = {
      ref: XLSX.utils.encode_range({
        s: { r: 0, c: 0 },
        e: { r: rows.length, c: headers.length - 1 },
      }),
    };
  }

  if (Number.isInteger(percentageColumnIndex)) {
    rows.forEach((_, index) => {
      const cellAddress = XLSX.utils.encode_cell({ r: index + 1, c: percentageColumnIndex });
      if (worksheet[cellAddress]) worksheet[cellAddress].z = "0%";
    });
  }

  return worksheet;
}

function buildReportWorkbook(XLSX, report) {
  const projectHeaders = ["Projeto", "Descrição", "Objetivo", "Status", "Prioridade", "Data", "Situação do prazo", "Total de tarefas", "Concluídas", "Pendentes", "Progresso %"];
  const taskHeaders = ["Projeto", "Tarefa", "Status", "Data do projeto", "Prioridade do projeto"];
  const overdueProjects = report.filteredProjects.filter(isOverdue);
  const generatedAt = new Intl.DateTimeFormat("pt-BR", {
    dateStyle: "short",
    timeStyle: "short",
  }).format(new Date());
  const summaryRows = [
    ["Relatório de Projetos de IA"],
    [],
    ["Gerado em", generatedAt],
    [],
    ["Filtros aplicados"],
    ...getExcelFilterRows(),
    [],
    ["Indicador", "Valor"],
    ["Total de projetos", report.metrics.totalProjects],
    ["Ideias", report.metrics.ideaProjects],
    ["Em andamento", report.metrics.inProgressProjects],
    ["Pausados", report.metrics.pausedProjects],
    ["Concluídos", report.metrics.completedProjects],
    ["Projetos atrasados", report.metrics.overdueProjects],
    ["Total de tarefas", report.metrics.totalTasks],
    ["Tarefas concluídas", report.metrics.completedTasks],
    ["Tarefas pendentes", report.metrics.pendingTasks],
    ["Progresso médio", report.metrics.averageProgress],
    ["Projetos de alta prioridade", report.executive.highPriorityProjects],
    ["Itens que precisam de atenção", report.executive.attentionProjects],
  ];
  const workbook = XLSX.utils.book_new();
  const summaryWorksheet = XLSX.utils.aoa_to_sheet(summaryRows);
  summaryWorksheet["!cols"] = [{ wch: 32 }, { wch: 46 }];
  const projectsWorksheet = createExcelTableWorksheet(
    XLSX,
    projectHeaders,
    report.filteredProjects.map(getExcelProjectRow),
    [28, 42, 42, 18, 14, 14, 20, 16, 13, 13, 14],
    10,
  );
  const tasksWorksheet = createExcelTableWorksheet(
    XLSX,
    taskHeaders,
    report.taskRows.map(getExcelTaskRow),
    [28, 46, 14, 18, 20],
  );
  const overdueWorksheet = createExcelTableWorksheet(
    XLSX,
    projectHeaders,
    overdueProjects.map(getExcelProjectRow),
    [28, 42, 42, 18, 14, 14, 20, 16, 13, 13, 14],
    10,
  );

  XLSX.utils.book_append_sheet(workbook, summaryWorksheet, "Resumo");
  XLSX.utils.book_append_sheet(workbook, projectsWorksheet, "Projetos");
  XLSX.utils.book_append_sheet(workbook, tasksWorksheet, "Tarefas");
  XLSX.utils.book_append_sheet(workbook, overdueWorksheet, "Atrasados");
  return workbook;
}

async function exportReportsToExcel() {
  if (isExcelExportRunning) return;

  const report = getReportData();
  if (report.filteredProjects.length === 0) {
    showReportMessage("Não há dados para exportar com os filtros selecionados.", "info");
    return;
  }

  isExcelExportRunning = true;
  setExcelExportLoading(true);

  try {
    const XLSX = await loadLocalSheetJs();
    const workbook = buildReportWorkbook(XLSX, report);
    XLSX.writeFileXLSX(workbook, `relatorio-projetos-ia-${getToday()}.xlsx`, { compression: true });
    showReportMessage("Relatório Excel gerado com os filtros atuais.", "success");
  } catch {
    showReportMessage("Não foi possível gerar o arquivo Excel. Tente novamente.", "error");
  } finally {
    isExcelExportRunning = false;
    setExcelExportLoading(false);
  }
}
function renderProjects() {
  const filteredProjects = getFilteredProjects();
  const hasProjects = projects.length > 0;
  const hasFilteredProjects = filteredProjects.length > 0;
  emptyProjects.hidden = hasProjects;
  filteredEmptyProjects.hidden = !hasProjects || hasFilteredProjects;
  projectsList.hidden = !hasFilteredProjects;
  projectsList.replaceChildren(...filteredProjects.map(createProjectCard));
  updateDashboard();
  renderAgenda();
  renderReports();
}

document.querySelectorAll("[data-open-project-modal]").forEach((button) => {
  button.addEventListener("click", () => openProjectModal());
});

document.querySelectorAll("[data-close-project-modal]").forEach((button) => {
  button.addEventListener("click", closeProjectModal);
});

projectFilters.addEventListener("click", (event) => {
  const filterButton = event.target.closest("[data-filter]");
  if (!filterButton) return;

  setActiveFilter(filterButton.dataset.filter);
});

showAllProjectsButton.addEventListener("click", () => setActiveFilter("all"));

projectSearch.addEventListener("input", (event) => {
  activeSearch = event.target.value;
  renderProjects();
});

projectSort.addEventListener("change", (event) => {
  activeSort = event.target.value;
  renderProjects();
});

clearProjectControlsButton.addEventListener("click", clearProjectControls);

reportsFilterForm.addEventListener("submit", (event) => event.preventDefault());
reportsFilterForm.addEventListener("input", syncReportFilters);
reportsFilterForm.addEventListener("change", syncReportFilters);
clearReportFiltersButton.addEventListener("click", clearReportFilters);
exportExcelButton?.addEventListener("click", exportReportsToExcel);

document.querySelectorAll("[data-dashboard-project-filter]").forEach((control) => {
  control.addEventListener("click", () => applyDashboardProjectFilter(control.dataset.dashboardProjectFilter));
});

dashboardVisualsSection?.addEventListener("click", (event) => {
  const control = event.target.closest("[data-dashboard-project-filter]");
  if (control) applyDashboardProjectFilter(control.dataset.dashboardProjectFilter);
});

dashboardOverdueControl?.addEventListener("click", openOverdueReportsFromDashboard);

navigationLinks.forEach((link) => {
  link.addEventListener("click", () => {
    window.setTimeout(updateNavigationState, 0);
    sidebar.classList.remove("is-open");
  });
});
window.addEventListener("hashchange", updateNavigationState);
updateNavigationState();

modal.addEventListener("click", (event) => {
  if (event.target === modal) closeProjectModal();
});

document.addEventListener("keydown", (event) => {
  if (confirmationModalElement.classList.contains("is-visible")) {
    if (event.key === "Escape" && !isConfirmationBusy) {
      event.preventDefault();
      finishDeletionConfirmation(false);
      return;
    }

    if (event.key === "Tab") {
      const focusableElements = getConfirmationFocusableElements();
      if (!focusableElements.length) return;

      const firstElement = focusableElements[0];
      const lastElement = focusableElements[focusableElements.length - 1];
      if (event.shiftKey && document.activeElement === firstElement) {
        event.preventDefault();
        lastElement.focus();
      } else if (!event.shiftKey && document.activeElement === lastElement) {
        event.preventDefault();
        firstElement.focus();
      }
    }
    return;
  }

  if (event.key === "Escape" && modal.classList.contains("is-visible")) {
    closeProjectModal();
  }
});

confirmationModalElement.addEventListener("click", (event) => {
  if (event.target === confirmationModalElement && !isConfirmationBusy) {
    finishDeletionConfirmation(false);
  }
});

cancelConfirmationButtonElement.addEventListener("click", () => {
  if (!isConfirmationBusy) finishDeletionConfirmation(false);
});

confirmDeletionButtonElement.addEventListener("click", () => {
  if (isConfirmationBusy || !confirmationResolver) return;

  isConfirmationBusy = true;
  cancelConfirmationButtonElement.disabled = true;
  confirmDeletionButtonElement.disabled = true;
  confirmDeletionButtonElement.dataset.loading = "true";
  confirmDeletionButtonElement.textContent = "Excluindo…";
  const resolver = confirmationResolver;
  confirmationResolver = null;
  resolver(true);
});

projectForm.addEventListener("submit", async (event) => {
  event.preventDefault();

  if (!projectForm.reportValidity() || !canManageSupabaseData()) return;

  const formData = new FormData(projectForm);
  const existingProject = projects.find((item) => item.id === projectIdInput.value);
  const project = {
    ...(existingProject ?? {}),
    name: String(formData.get("name") ?? "").trim(),
    description: String(formData.get("description") ?? "").trim(),
    goal: String(formData.get("goal") ?? "").trim(),
    status: String(formData.get("status") ?? ""),
    priority: String(formData.get("priority") ?? ""),
    date: String(formData.get("date") ?? ""),
    tasks: existingProject?.tasks ?? [],
  };
  const saveButton = projectForm.querySelector(".save-button");
  if (saveButton) saveButton.disabled = true;

  try {
    const remoteProject = existingProject
      ? await updateRemoteProject(existingProject.id, project)
      : await createRemoteProject(project);
    const updatedProject = mapRemoteProjectToInterface(remoteProject, project.tasks);
    const projectIndex = projects.findIndex((item) => item.id === updatedProject.id);

    if (projectIndex >= 0) {
      projects[projectIndex] = updatedProject;
    } else {
      projects.unshift(updatedProject);
    }

    renderProjects();
    closeProjectModal();
    showDataMessage(existingProject ? "Projeto atualizado com sucesso." : "Projeto criado com sucesso.");
  } catch (error) {
    showDataMessage(getDataErrorMessage(
      error,
      existingProject ? "Não foi possível atualizar o projeto. Tente novamente." : "Não foi possível criar o projeto. Tente novamente.",
    ));
  } finally {
    if (saveButton) saveButton.disabled = false;
  }
});

projectsList.addEventListener("submit", async (event) => {
  const taskDeadlineForm = event.target.closest("[data-task-deadline-form]");
  if (taskDeadlineForm) {
    event.preventDefault();
    if (!taskDeadlineForm.reportValidity() || !canManageSupabaseData()) return;

    const project = projects.find((item) => item.id === taskDeadlineForm.dataset.projectId);
    const task = project?.tasks.find((item) => item.id === taskDeadlineForm.dataset.taskId);
    if (!project || !task) return;

    await saveTaskDeadline(
      project,
      task,
      String(taskDeadlineForm.elements.taskDueDate?.value ?? ""),
      taskDeadlineForm,
    );
    return;
  }

  const addTaskForm = event.target.closest("[data-task-form]");
  if (!addTaskForm) return;
  event.preventDefault();
  if (!addTaskForm.reportValidity() || !canManageSupabaseData()) return;

  const project = projects.find((item) => item.id === addTaskForm.dataset.projectId);
  const taskDescription = addTaskForm.elements.taskDescription.value.trim();
  const taskDueDate = String(addTaskForm.elements.taskDueDate?.value ?? "");
  if (!project || !taskDescription) return;

  const addButton = addTaskForm.querySelector("button[type=submit]");
  if (addButton) addButton.disabled = true;

  try {
    const remoteTask = await createRemoteTask(project.id, taskDescription, null, taskDueDate);
    project.tasks.push({
      id: String(remoteTask.id),
      description: String(remoteTask.description ?? taskDescription),
      completed: Boolean(remoteTask.completed),
      dueDate: String(remoteTask.due_date ?? ""),
    });
    renderProjects();
    showDataMessage("Tarefa adicionada com sucesso.");
  } catch (error) {
    showDataMessage(getDataErrorMessage(error, "Não foi possível adicionar a tarefa. Tente novamente."));
  } finally {
    if (addButton) addButton.disabled = false;
  }
});

projectsList.addEventListener("change", async (event) => {
  const taskToggle = event.target.closest("[data-task-toggle]");
  if (!taskToggle || !canManageSupabaseData()) return;

  const project = projects.find((item) => item.id === taskToggle.dataset.projectId);
  const task = project?.tasks.find((item) => item.id === taskToggle.dataset.taskId);
  if (!task) return;

  taskToggle.disabled = true;
  try {
    const remoteTask = await updateRemoteTaskCompletion(task.id, taskToggle.checked);
    task.completed = Boolean(remoteTask.completed);
    renderProjects();
    showDataMessage(task.completed ? "Tarefa concluída." : "Tarefa reaberta.");
  } catch (error) {
    renderProjects();
    showDataMessage(getDataErrorMessage(error, "Não foi possível atualizar a tarefa. Tente novamente."));
  } finally {
    taskToggle.disabled = false;
  }
});

projectsList.addEventListener("click", async (event) => {
  const actionButton = event.target.closest("[data-action]");
  if (!actionButton) return;

  const projectId = actionButton.dataset.projectId || actionButton.dataset.id;
  const project = projects.find((item) => item.id === projectId);
  if (!project) return;

  if (actionButton.dataset.action === "edit-task-deadline") {
    if (!canManageSupabaseData()) return;
    const task = project.tasks.find((item) => item.id === actionButton.dataset.taskId);
    if (!task) return;
    openTaskDeadlineEditor(actionButton, project, task);
    return;
  }

  if (actionButton.dataset.action === "cancel-task-deadline-edit") {
    const editor = actionButton.closest("[data-task-deadline-form]");
    editor?.remove();
    const editButton = Array.from(projectsList.querySelectorAll('[data-action="edit-task-deadline"]'))
      .find((button) => button.dataset.taskId === actionButton.dataset.taskId);
    editButton?.focus();
    return;
  }

  if (actionButton.dataset.action === "remove-task-deadline") {
    if (!canManageSupabaseData()) return;
    const task = project.tasks.find((item) => item.id === actionButton.dataset.taskId);
    const editor = actionButton.closest("[data-task-deadline-form]");
    if (!task || !editor || !task.dueDate) return;
    await saveTaskDeadline(project, task, "", editor);
    return;
  }

  if (actionButton.dataset.action === "edit") {
    if (!canManageSupabaseData()) return;
    openProjectModal(project);
    return;
  }

  if (actionButton.dataset.action === "delete") {
    if (!canManageSupabaseData()) return;

    const taskCount = project.tasks.length;
    const taskDescription = taskCount === 1 ? "1 tarefa vinculada" : taskCount + " tarefas vinculadas";
    const confirmed = await requestDeletionConfirmation({
      title: "Excluir projeto",
      message: "Excluir o projeto \"" + project.name + "\" e " + taskDescription
        + " da sua conta? A exclusão no Supabase é permanente. O backup local antigo não será apagado.",
      triggerElement: actionButton,
    });
    if (!confirmed) return;

    actionButton.disabled = true;
    try {
      await deleteRemoteProject(project.id);
      projects = projects.filter((item) => item.id !== project.id);
      renderProjects();
      showDataMessage("Projeto excluído com sucesso.");
    } catch (error) {
      if (error?.tasksWereDeleted) {
        try {
          await loadRemoteProjects();
        } catch {
          // A mensagem abaixo já orienta o usuário sem expor detalhes internos.
        }
        showDataMessage("A exclusão do projeto não foi concluída. As tarefas foram removidas e os dados foram recarregados.");
      } else {
        showDataMessage(getDataErrorMessage(error, "Não foi possível excluir o projeto. Tente novamente."));
      }
    } finally {
      actionButton.disabled = false;
      finishDeletionConfirmation(false, false);
    }
    return;
  }

  if (actionButton.dataset.action === "delete-task") {
    if (!canManageSupabaseData()) return;

    const task = project.tasks.find((item) => item.id === actionButton.dataset.taskId);
    if (!task) return;

    const confirmed = await requestDeletionConfirmation({
      title: "Excluir tarefa",
      message: "Excluir a tarefa \"" + task.description + "\" do projeto \"" + project.name
        + "\"? Esta ação será removida da sua conta e não poderá ser desfeita.",
      triggerElement: actionButton,
    });
    if (!confirmed) return;

    actionButton.disabled = true;
    try {
      await deleteRemoteTask(task.id);
      project.tasks = project.tasks.filter((item) => item.id !== task.id);
      renderProjects();
      showDataMessage("Tarefa excluída com sucesso.");
    } catch (error) {
      showDataMessage(getDataErrorMessage(error, "Não foi possível excluir a tarefa. Tente novamente."));
    } finally {
      actionButton.disabled = false;
      finishDeletionConfirmation(false, false);
    }
  }
});

renderProjects();
