import { describe, expect, it } from "vitest";
import { invalidPortfolioFixture, representativePortfolio } from "./fixtures";
import { AdapterNotFoundError, AdapterValidationError, FixtureProjectAdapter } from "./project-adapter";

const scope = { sourceId: "fixture", accessScope: "test" };

describe("FixtureProjectAdapter", () => {
  it("validates and returns minimal and rich projects", async () => {
    const adapter = new FixtureProjectAdapter(representativePortfolio);

    const portfolio = await adapter.listProjects(scope);

    expect(portfolio.projects).toHaveLength(2);
    expect(portfolio.projects[0]?.progress.status).toBe("unavailable");
    expect(portfolio.projects[1]?.designs.status).toBe("available");
  });

  it("rejects malformed responses", async () => {
    const adapter = new FixtureProjectAdapter(invalidPortfolioFixture);

    await expect(adapter.listProjects(scope)).rejects.toBeInstanceOf(AdapterValidationError);
  });

  it("propagates cancellation and not-found reads", async () => {
    const adapter = new FixtureProjectAdapter(representativePortfolio);
    const controller = new AbortController();
    controller.abort();

    await expect(adapter.listProjects(scope, controller.signal)).rejects.toMatchObject({ name: "AbortError" });
    await expect(adapter.getProject(scope, "unknown")).rejects.toBeInstanceOf(AdapterNotFoundError);
  });
});
