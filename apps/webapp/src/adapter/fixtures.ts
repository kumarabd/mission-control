import type { PortfolioSnapshot } from "../domain/project";

const retrievedAt = "2026-09-06T00:00:00.000Z";

export const representativePortfolio: PortfolioSnapshot = {
  retrievedAt,
  projects: [
    {
      id: "minimal-project",
      name: "Minimal project",
      description: { status: "available", value: "A README and PRD are enough to participate.", source: "README.md" },
      lifecycle: { status: "available", value: "Planned", source: "PRD.md" },
      progress: { status: "unavailable", reason: "No designated plan source." },
      nextAction: { status: "unavailable", reason: "No supported next-action field." },
      concerns: { status: "unavailable", reason: "No concern register is indexed." },
      designs: { status: "unavailable", reason: "No implementation design is indexed." },
      documents: [{ label: "README", href: "https://example.test/minimal/README.md" }, { label: "PRD", href: "https://example.test/minimal/PRD.md" }],
      retrievedAt,
    },
    {
      id: "rich-project",
      name: "Rich project",
      description: { status: "available", value: "A project with planning and design records.", source: "README.md" },
      lifecycle: { status: "available", value: "In progress", source: "PRD.md" },
      progress: { status: "available", value: 0.42, source: "plans/mvp.md" },
      nextAction: { status: "available", value: "Connect the source adapter.", source: "plans/mvp.md" },
      concerns: { status: "available", value: [{ id: "C-001", status: "investigating", area: "runtime", source: "concerns/README.md" }], source: "concerns/README.md" },
      designs: { status: "available", value: [{ component: "webapp", status: "draft", source: "implementation/webapp/README.md" }, { component: "api", status: "accepted", source: "implementation/api/README.md" }], source: "implementation/README.md" },
      documents: [{ label: "README", href: "https://example.test/rich/README.md" }, { label: "Plan", href: "https://example.test/rich/plans/mvp.md" }],
      retrievedAt,
    },
  ],
};

export const invalidPortfolioFixture = { projects: [{ id: "missing-name" }], retrievedAt };
