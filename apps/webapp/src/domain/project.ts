export type Availability<T> =
  | { status: "available"; value: T; source: string }
  | { status: "unavailable"; reason: string; source?: string };

export type ProjectDesign = {
  component: string;
  status: "draft" | "accepted";
  source: string;
};

export type ProjectConcern = {
  id: string;
  status: "open" | "investigating" | "accepted-risk";
  area: string;
  source: string;
};

export type ProjectSnapshot = {
  id: string;
  name: string;
  description: Availability<string>;
  lifecycle: Availability<string>;
  progress: Availability<number>;
  nextAction: Availability<string>;
  concerns: Availability<ProjectConcern[]>;
  designs: Availability<ProjectDesign[]>;
  documents: { label: string; href: string }[];
  retrievedAt: string;
};

export type PortfolioSnapshot = {
  projects: ProjectSnapshot[];
  retrievedAt: string;
};
