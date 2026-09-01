// Projetos e tarefas ficam salvos apenas no navegador do usuário.
const STORAGE_KEY = "meus_projetos_ia";

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

let projects = loadProjects();
let activeFilter = "all";
let activeSearch = "";
let activeSort = "newest";

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

function saveProjects() {
  const projectsToSave = projects.map((project) => ({
    ...project,
    tasks: project.tasks,
    progress: calculateProgress(project),
  }));

  localStorage.setItem(STORAGE_KEY, JSON.stringify(projectsToSave));
}

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

function createTaskItem(project, task) {
  const item = document.createElement("li");
  item.className = "task-item";

  const label = document.createElement("label");
  label.className = "task-label";
  const checkbox = document.createElement("input");
  checkbox.type = "checkbox";
  checkbox.checked = task.completed;
  checkbox.dataset.taskToggle = "true";
  checkbox.dataset.projectId = project.id;
  checkbox.dataset.taskId = task.id;
  checkbox.setAttribute("aria-label", `Marcar tarefa: ${task.description}`);

  const description = document.createElement("span");
  description.className = "task-description";
  if (task.completed) description.classList.add("is-completed");
  description.textContent = task.description;
  label.append(checkbox, description);

  const deleteButton = createActionButton(
    "Excluir tarefa",
    '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M10 11v5M14 11v5M6 7l1 13h10l1-13M9 7V4h6v3" /></svg>',
    "delete-task",
  );
  deleteButton.classList.add("task-delete-button");
  deleteButton.dataset.projectId = project.id;
  deleteButton.dataset.taskId = task.id;

  item.append(label, deleteButton);
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
  taskInput.type = "text";
  taskInput.name = "taskDescription";
  taskInput.placeholder = "Adicionar uma tarefa";
  taskInput.setAttribute("aria-label", "Descrição da nova tarefa");
  taskInput.maxLength = 160;
  taskInput.required = true;
  const addButton = document.createElement("button");
  addButton.type = "submit";
  addButton.textContent = "Adicionar";
  addTaskForm.append(taskInput, addButton);

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
  };
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

function renderProjects() {
  const filteredProjects = getFilteredProjects();
  const hasProjects = projects.length > 0;
  const hasFilteredProjects = filteredProjects.length > 0;
  emptyProjects.hidden = hasProjects;
  filteredEmptyProjects.hidden = !hasProjects || hasFilteredProjects;
  projectsList.hidden = !hasFilteredProjects;
  projectsList.replaceChildren(...filteredProjects.map(createProjectCard));
  updateDashboard();
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

modal.addEventListener("click", (event) => {
  if (event.target === modal) closeProjectModal();
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && modal.classList.contains("is-visible")) {
    closeProjectModal();
  }
});

projectForm.addEventListener("submit", (event) => {
  event.preventDefault();

  if (!projectForm.reportValidity()) return;

  const formData = new FormData(projectForm);
  const existingProject = projects.find((item) => item.id === projectIdInput.value);
  const project = {
    ...(existingProject ?? {}),
    id: projectIdInput.value || createId(),
    name: formData.get("name").trim(),
    description: formData.get("description").trim(),
    goal: formData.get("goal").trim(),
    status: formData.get("status"),
    priority: formData.get("priority"),
    date: formData.get("date"),
    tasks: existingProject?.tasks ?? [],
  };

  const projectIndex = projects.findIndex((item) => item.id === project.id);
  if (projectIndex >= 0) {
    projects[projectIndex] = project;
  } else {
    projects.unshift(project);
  }

  saveProjects();
  renderProjects();
  closeProjectModal();
});

projectsList.addEventListener("submit", (event) => {
  const addTaskForm = event.target.closest("[data-task-form]");
  if (!addTaskForm) return;

  event.preventDefault();
  if (!addTaskForm.reportValidity()) return;

  const project = projects.find((item) => item.id === addTaskForm.dataset.projectId);
  const taskDescription = addTaskForm.elements.taskDescription.value.trim();
  if (!project || !taskDescription) return;

  project.tasks.push({
    id: createId(),
    description: taskDescription,
    completed: false,
  });

  saveProjects();
  renderProjects();
});

projectsList.addEventListener("change", (event) => {
  const taskToggle = event.target.closest("[data-task-toggle]");
  if (!taskToggle) return;

  const project = projects.find((item) => item.id === taskToggle.dataset.projectId);
  const task = project?.tasks.find((item) => item.id === taskToggle.dataset.taskId);
  if (!task) return;

  task.completed = taskToggle.checked;
  saveProjects();
  renderProjects();
});

projectsList.addEventListener("click", (event) => {
  const actionButton = event.target.closest("[data-action]");
  if (!actionButton) return;

  const projectId = actionButton.dataset.projectId || actionButton.dataset.id;
  const project = projects.find((item) => item.id === projectId);
  if (!project) return;

  if (actionButton.dataset.action === "edit") {
    openProjectModal(project);
  }

  if (actionButton.dataset.action === "delete") {
    const taskCount = project.tasks.length;
    const taskDescription = taskCount === 1 ? "1 tarefa vinculada" : `${taskCount} tarefas vinculadas`;
    const confirmed = window.confirm(
      `Excluir o projeto "${project.name}" e ${taskDescription}? Todos esses dados serão removidos do navegador e não poderão ser recuperados.`,
    );
    if (confirmed) {
      projects = projects.filter((item) => item.id !== project.id);
      saveProjects();
      renderProjects();
    }
  }

  if (actionButton.dataset.action === "delete-task") {
    const task = project.tasks.find((item) => item.id === actionButton.dataset.taskId);
    if (!task) return;

    const confirmed = window.confirm(
      `Excluir a tarefa "${task.description}" do projeto "${project.name}"? Esta ação não poderá ser desfeita.`,
    );
    if (confirmed) {
      project.tasks = project.tasks.filter((item) => item.id !== task.id);
      saveProjects();
      renderProjects();
    }
  }
});

renderProjects();
