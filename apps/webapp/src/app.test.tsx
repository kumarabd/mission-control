import { render, screen } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { MemoryRouter } from "react-router";
import { describe, expect, it } from "vitest";
import { App } from "./app";

function renderApp(initialEntry = "/") {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={[initialEntry]}>
        <App />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe("App", () => {
  it("renders the portfolio route", () => {
    renderApp();

    expect(screen.getByRole("heading", { name: "Projects at a glance" })).toBeInTheDocument();
  });

  it("renders a URL-selected project detail", () => {
    renderApp("/projects/mission-control");

    expect(screen.getByRole("heading", { name: "mission-control" })).toBeInTheDocument();
  });
});
