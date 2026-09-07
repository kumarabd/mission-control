import type { PortfolioSnapshot, ProjectSnapshot } from "../domain/project";

export type ReadScope = Readonly<{ sourceId: string; accessScope: string }>;

export interface ProjectAdapter {
  listProjects(scope: ReadScope, signal?: AbortSignal): Promise<PortfolioSnapshot>;
  getProject(scope: ReadScope, projectId: string, signal?: AbortSignal): Promise<ProjectSnapshot>;
}

export class AdapterValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AdapterValidationError";
  }
}

export class AdapterNotFoundError extends Error {
  constructor(projectId: string) {
    super(`Project '${projectId}' was not found.`);
    this.name = "AdapterNotFoundError";
  }
}

function abortIfRequested(signal?: AbortSignal) {
  if (signal?.aborted) {
    throw new DOMException("The project read was cancelled.", "AbortError");
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function validateAvailability(value: unknown, path: string): void {
  if (!isRecord(value) || (value.status !== "available" && value.status !== "unavailable")) {
    throw new AdapterValidationError(`${path} must declare available or unavailable status.`);
  }

  if (value.status === "available" && typeof value.source !== "string") {
    throw new AdapterValidationError(`${path}.source must be a string.`);
  }
}

function validateProject(value: unknown): ProjectSnapshot {
  if (!isRecord(value)) {
    throw new AdapterValidationError("Project response must be an object.");
  }

  for (const field of ["id", "name", "retrievedAt"]) {
    if (typeof value[field] !== "string" || value[field].length === 0) {
      throw new AdapterValidationError(`Project ${field} must be a non-empty string.`);
    }
  }

  for (const field of ["description", "lifecycle", "progress", "nextAction", "concerns", "designs"]) {
    validateAvailability(value[field], `Project ${field}`);
  }

  if (!Array.isArray(value.documents) || value.documents.some((document) => !isRecord(document) || typeof document.label !== "string" || typeof document.href !== "string")) {
    throw new AdapterValidationError("Project documents must contain label and href strings.");
  }

  return value as unknown as ProjectSnapshot;
}

export function validatePortfolio(value: unknown): PortfolioSnapshot {
  if (!isRecord(value) || !Array.isArray(value.projects) || typeof value.retrievedAt !== "string") {
    throw new AdapterValidationError("Portfolio response must contain projects and retrievedAt.");
  }

  return {
    projects: value.projects.map(validateProject),
    retrievedAt: value.retrievedAt,
  };
}

export class FixtureProjectAdapter implements ProjectAdapter {
  constructor(private readonly portfolio: unknown) {}

  async listProjects(scope: ReadScope, signal?: AbortSignal): Promise<PortfolioSnapshot> {
    void scope;
    abortIfRequested(signal);
    await Promise.resolve();
    abortIfRequested(signal);
    return validatePortfolio(this.portfolio);
  }

  async getProject(scope: ReadScope, projectId: string, signal?: AbortSignal): Promise<ProjectSnapshot> {
    const portfolio = await this.listProjects(scope, signal);
    const project = portfolio.projects.find((candidate) => candidate.id === projectId);
    if (!project) {
      throw new AdapterNotFoundError(projectId);
    }

    return project;
  }
}
